plugin = {}

local PLUGIN_ID = "rebar3"
local PLUGIN_NAME = "rebar3"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "rebar3"

local path_exists

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return trim(value):lower()
end

local function split_lines(value)
    local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = {}
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function is_safe_token(value)
    return tostring(value or ""):match("^[A-Za-z0-9_./:@%%+=,%-%[%]]+$") ~= nil
end

local function command_quote(value)
    local text = tostring(value or "")
    if is_safe_token(text) then
        return text
    end
    return shell_quote(text)
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(select(index, ...))
        if part ~= "" then
            if #parts == 0 then
                parts[#parts + 1] = part:gsub("[/\\]+$", "")
            else
                parts[#parts + 1] = part:gsub("^[/\\]+", ""):gsub("[/\\]+$", "")
            end
        end
    end
    if #parts == 0 then
        return "."
    end
    return table.concat(parts, "/")
end

local function parent_dir(path)
    return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
end

local function basename(path)
    local cleaned = trim(path):gsub("[/\\]+$", "")
    return cleaned:match("[^/\\]+$") or cleaned
end

local function read_field(value, key)
    if value == nil then
        return nil
    end
    local ok, result = pcall(function()
        return value[key]
    end)
    if ok then
        return result
    end
    return nil
end

local function normalize_run_result(first, second, third, fourth, fifth)
    if type(first) == "table" then
        if first.stdout == nil then
            first.stdout = first.stdoutText or ""
        end
        if first.stderr == nil then
            first.stderr = first.stderrText or ""
        end
        if first.exitCode == nil then
            first.exitCode = first.exit_code or first.code or first.status
        end
        if first.success == nil and first.ok ~= nil then
            first.success = first.ok
        end
        if first.success == nil and first.exitCode ~= nil then
            first.success = first.exitCode == 0
        end
        return first
    end

    local result = {}
    local function merge_exec_like(value)
        for _, key in ipairs({ "success", "ok", "stdout", "stderr", "exitCode", "exit_code", "code", "status", "stdoutText", "stderrText" }) do
            local ok, item = pcall(function()
                return value[key]
            end)
            if ok and item ~= nil and result[key] == nil then
                result[key] = item
            end
        end
    end
    local function apply_scalar(value)
        local value_type = type(value)
        if value_type == "table" then
            for key, item in pairs(value or {}) do
                result[key] = item
            end
        elseif value_type == "userdata" then
            merge_exec_like(value)
        elseif value_type == "boolean" then
            if result.success == nil then
                result.success = value
            end
        elseif value_type == "number" then
            if result.exitCode == nil then
                result.exitCode = value
            end
        elseif value_type == "string" then
            if result.stdout == nil then
                result.stdout = value
            elseif result.stderr == nil then
                result.stderr = value
            end
        end
    end
    apply_scalar(first)
    apply_scalar(second)
    apply_scalar(third)
    apply_scalar(fourth)
    apply_scalar(fifth)
    if result.stdout == nil then
        result.stdout = result.stdoutText or ""
    end
    if result.stderr == nil then
        result.stderr = result.stderrText or ""
    end
    if result.exitCode == nil then
        result.exitCode = result.exit_code or result.code or result.status
    end
    if result.success == nil and result.ok ~= nil then
        result.success = result.ok
    end
    if result.success == nil and result.exitCode ~= nil then
        result.success = result.exitCode == 0
    end
    return result
end

local function exec_run(context, command)
    local first, second, third, fourth, fifth
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        first, second, third, fourth, fifth = context.exec.run(command)
    elseif reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
        first, second, third, fourth, fifth = reqpack.exec.run(command)
    else
        first = {
            success = false,
            stdout = "",
            stderr = "missing ReqPack exec runner",
            exitCode = 127,
        }
    end
    return normalize_run_result(first, second, third, fourth, fifth)
end

local function is_command_success(result)
    if type(result) ~= "table" then
        return false
    end
    if result.success == true or result.ok == true then
        return true
    end
    return (result.exitCode or result.exit_code or result.code or result.status) == 0
end

local function emit_event(context, name, payload)
    if context == nil or context.events == nil then
        return
    end
    local fn = context.events[name]
    if type(fn) == "function" then
        fn(payload)
    end
end

local function begin_step(context, label)
    if context == nil or context.tx == nil then
        return
    end
    local fn = context.tx.begin_step
    if type(fn) == "function" then
        fn(label)
    end
end

local function tx_success(context)
    if context == nil or context.tx == nil then
        return
    end
    local fn = context.tx.success
    if type(fn) == "function" then
        fn()
    end
end

local function tx_failed(context, message)
    if context == nil or context.tx == nil then
        return
    end
    local fn = context.tx.failed
    if type(fn) == "function" then
        fn(message)
    end
end

local function log_warn(context, message)
    if context == nil or context.log == nil then
        return
    end
    local fn = context.log.warn
    if type(fn) == "function" then
        fn(message)
    end
end

local function ensure_directory(path)
    local dir = trim(path)
    if dir == "" or dir == "." then
        return true
    end
    if path_exists(nil, dir) then
        return true
    end
    if os == nil or type(os.execute) ~= "function" then
        return is_command_success(exec_run(nil, "mkdir -p " .. shell_quote(dir)))
    end
    local ok, kind, code = os.execute("mkdir -p " .. shell_quote(dir))
    if ok == true then
        return true
    end
    if type(ok) == "number" then
        return ok == 0
    end
    if code == 0 or kind == "exit" then
        return true
    end
    return is_command_success(exec_run(nil, "mkdir -p " .. shell_quote(dir)))
end

local function read_file(path)
    local handle = io.open(path, "r")
    if handle == nil then
        local result = exec_run(nil, "cat " .. shell_quote(path))
        if is_command_success(result) then
            return result.stdout
        end
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(path, content)
    local dir = parent_dir(path)
    local command = "mkdir -p " .. shell_quote(dir or ".") .. " && printf %s " .. shell_quote(content) .. " > " .. shell_quote(path)
    local result = exec_run(nil, command)
    return is_command_success(result)
end

path_exists = function(context, path)
    return is_command_success(exec_run(context, "test -e " .. shell_quote(path)))
end

local function command_exists(context, binary)
    return is_command_success(exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function object_flags(object)
    local value = read_field(object, "flags")
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local flags = {}
    local ok = pcall(function()
        for _, item in ipairs(value) do
            local cleaned = trim(item)
            if cleaned ~= "" then
                flags[#flags + 1] = cleaned
            end
        end
    end)
    if not ok then
        return {}
    end
    return flags
end

local function append_unique(list, value, seen)
    local text = trim(value)
    if text == "" or seen[text] then
        return
    end
    seen[text] = true
    list[#list + 1] = text
end

local function collect_raw_flags(context, packages)
    local flags = {}
    local seen = {}
    local function collect_from(object)
        for _, flag in ipairs(object_flags(object)) do
            append_unique(flags, flag, seen)
        end
    end
    collect_from(context)
    collect_from(read_field(context, "request"))
    for _, package in ipairs(packages or {}) do
        collect_from(package)
    end
    return flags
end

local function flag_value(flags, key)
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            return trim(cleaned:sub(#prefix + 1))
        end
    end
    return nil
end

local function home_dir()
    if os ~= nil and type(os.getenv) == "function" then
        local value = trim(os.getenv("HOME") or os.getenv("USERPROFILE") or "")
        if value ~= "" then
            return value
        end
    end
    return "/home/test"
end

local function cache_root()
    return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
end

local function rebar_cache_dir()
    return join_path(cache_root(), "cache")
end

local function rebar_config_dir()
    return join_path(cache_root(), "config")
end

local function synthetic_project_dir()
    return join_path(cache_root(), "project")
end

local function synthetic_rebar_config_path()
    return join_path(synthetic_project_dir(), "rebar.config")
end

local function normalize_package_list(value)
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local list = {}
    local ok = pcall(function()
        for _, item in ipairs(value) do
            list[#list + 1] = item
        end
    end)
    if ok and #list > 0 then
        return list
    end
    return {}
end

local function request_packages(context, packages)
    local direct = normalize_package_list(packages)
    if #direct > 0 then
        return direct
    end
    local request = read_field(context, "request")
    local embedded = normalize_package_list(read_field(request, "packages"))
    if #embedded > 0 then
        return embedded
    end
    return {}
end

local function package_name(package)
    return trim(read_field(package, "name") or read_field(package, "packageName") or read_field(package, "packageId"))
end

local function package_version(package)
    return trim(read_field(package, "version"))
end

local function package_action(package)
    local action = lower(read_field(package, "action"))
    if action == "" then
        return "install"
    end
    return action
end

local function info_prompt(context, name)
    return trim(name or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
end

local function env_prefix()
    return table.concat({
        "REBAR_CACHE_DIR=" .. shell_quote(rebar_cache_dir()),
        "REBAR_GLOBAL_CONFIG_DIR=" .. shell_quote(rebar_config_dir()),
        "REBAR_COLOR='low'",
        "NO_COLOR='1'",
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
    }, " ")
end

local function join_command_args(args)
    local parts = {}
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = command_quote(arg)
    end
    return table.concat(parts, " ")
end

local function build_global_command(args)
    return env_prefix() .. " " .. REQUIRED_BINARY .. " " .. join_command_args(args)
end

local function build_project_command(dir, args)
    return "cd " .. shell_quote(dir) .. " && " .. env_prefix() .. " " .. REQUIRED_BINARY .. " " .. join_command_args(args)
end

local function default_rebar_config()
    return "{erl_opts, [debug_info]}.\n{deps, [\n]}.\n"
end

local function ensure_synthetic_project()
    if read_file(synthetic_rebar_config_path()) ~= nil then
        return true
    end
    if not write_file(synthetic_rebar_config_path(), default_rebar_config()) then
        return false, "failed to write synthetic rebar.config"
    end
    return true
end

local function target_dir_from_context(context, packages)
    local flags = collect_raw_flags(context, packages)
    local explicit = flag_value(flags, "dir")
    if explicit ~= nil and explicit ~= "" then
        return explicit
    end
    local request = read_field(context, "request")
    return trim(read_field(context, "dir") or read_field(request, "dir") or "")
end

local function ensure_project_ready(context, packages, create_if_missing)
    local explicit_dir = target_dir_from_context(context, packages)
    if explicit_dir ~= "" then
        local config_path = join_path(explicit_dir, "rebar.config")
        if not path_exists(context, explicit_dir) then
            return nil, "rebar3 project directory missing"
        end
        if read_file(config_path) == nil then
            return nil, "rebar.config missing"
        end
        return {
            dir = explicit_dir,
            rebar_config = config_path,
            synthetic = false,
        }, nil
    end
    if read_file(synthetic_rebar_config_path()) == nil then
        if not create_if_missing then
            return nil, "synthetic rebar3 project missing"
        end
        local ok, err = ensure_synthetic_project()
        if not ok then
            return nil, err
        end
    end
    return {
        dir = synthetic_project_dir(),
        rebar_config = synthetic_rebar_config_path(),
        synthetic = true,
    }, nil
end

local function is_exact_version(value)
    local cleaned = trim(value)
    if cleaned == "" then
        return false
    end
    return cleaned:match("^[0-9A-Za-z][0-9A-Za-z%._%-]*$") ~= nil and cleaned:find(" ", 1, true) == nil and cleaned:find("~", 1, true) == nil and cleaned:find(">", 1, true) == nil and cleaned:find("<", 1, true) == nil and cleaned:find("=", 1, true) == nil and cleaned:find("*", 1, true) == nil
end

local function compare_versions(left, right)
    local a = trim(left)
    local b = trim(right)
    if a == b then
        return 0
    end
    local function tokenize(value)
        local tokens = {}
        for token in tostring(value or ""):gmatch("[^%.%-_]+") do
            tokens[#tokens + 1] = token
        end
        return tokens
    end
    local left_tokens = tokenize(a)
    local right_tokens = tokenize(b)
    local count = math.max(#left_tokens, #right_tokens)
    for index = 1, count do
        local lt = left_tokens[index] or "0"
        local rt = right_tokens[index] or "0"
        local ln = tonumber(lt)
        local rn = tonumber(rt)
        if ln ~= nil and rn ~= nil then
            if ln < rn then
                return -1
            elseif ln > rn then
                return 1
            end
        else
            if lt < rt then
                return -1
            elseif lt > rt then
                return 1
            end
        end
    end
    if a < b then
        return -1
    end
    return 1
end

local function split_top_level(text)
    local entries = {}
    local current = {}
    local brace_depth = 0
    local bracket_depth = 0
    local paren_depth = 0
    local in_single = false
    local in_double = false
    local escaped = false
    local function flush()
        local value = trim(table.concat(current))
        if value ~= "" then
            entries[#entries + 1] = value
        end
        current = {}
    end
    for index = 1, #text do
        local ch = text:sub(index, index)
        current[#current + 1] = ch
        if escaped then
            escaped = false
        elseif ch == "\\" and (in_single or in_double) then
            escaped = true
        elseif in_single then
            if ch == "'" then
                in_single = false
            end
        elseif in_double then
            if ch == '"' then
                in_double = false
            end
        else
            if ch == "'" then
                in_single = true
            elseif ch == '"' then
                in_double = true
            elseif ch == "{" then
                brace_depth = brace_depth + 1
            elseif ch == "}" then
                brace_depth = math.max(0, brace_depth - 1)
            elseif ch == "[" then
                bracket_depth = bracket_depth + 1
            elseif ch == "]" then
                bracket_depth = math.max(0, bracket_depth - 1)
            elseif ch == "(" then
                paren_depth = paren_depth + 1
            elseif ch == ")" then
                paren_depth = math.max(0, paren_depth - 1)
            elseif ch == "," and brace_depth == 0 and bracket_depth == 0 and paren_depth == 0 then
                current[#current] = nil
                flush()
            end
        end
    end
    flush()
    return entries
end

local function decode_atom(token)
    local cleaned = trim(token)
    if cleaned:sub(1, 1) == "'" and cleaned:sub(-1) == "'" and #cleaned >= 2 then
        return cleaned:sub(2, -2):gsub("\\'", "'")
    end
    return cleaned
end

local function encode_atom(value)
    local text = trim(value)
    if text:match("^[a-z][a-z0-9_@]*$") then
        return text
    end
    return "'" .. text:gsub("'", "\\'") .. "'"
end

local function parse_dep_entry(raw)
    local cleaned = trim(raw)
    if cleaned == "" then
        return nil
    end
    if cleaned:sub(1, 1) ~= "{" then
        local name = decode_atom(cleaned:gsub(",$", ""))
        return {
            name = name,
            version = nil,
            packageType = "package",
            raw = cleaned,
        }
    end
    local inner = cleaned:sub(2, -2)
    local parts = split_top_level(inner)
    if #parts == 0 then
        return nil
    end
    local entry = {
        name = decode_atom(parts[1]),
        version = nil,
        packageType = "package",
        raw = cleaned,
    }
    local second = trim(parts[2] or "")
    if second:sub(1, 1) == '"' and second:sub(-1) == '"' then
        entry.version = second:sub(2, -2)
        entry.packageType = "package"
    elseif second:match("^%{git[,}]") or second:match("^%{hg[,}]") then
        entry.packageType = "source"
    elseif second:match("^%{pkg[,}]") then
        if #parts >= 3 then
            local third = trim(parts[3])
            if third:sub(1, 1) == '"' and third:sub(-1) == '"' then
                entry.version = third:sub(2, -2)
            end
        end
        entry.packageType = "package"
    elseif second ~= "" then
        entry.packageType = "source"
    end
    return entry
end

local function find_deps_bounds(text)
    local start_pos = text:find("{deps", 1, true)
    if start_pos == nil then
        return nil
    end
    local open_pos = text:find("[", start_pos, true)
    if open_pos == nil then
        return nil
    end
    local depth = 0
    for index = open_pos, #text do
        local ch = text:sub(index, index)
        if ch == "[" then
            depth = depth + 1
        elseif ch == "]" then
            depth = depth - 1
            if depth == 0 then
                return {
                    decl_start = start_pos,
                    list_open = open_pos,
                    list_close = index,
                }
            end
        end
    end
    return nil
end

local function parse_declared_dependencies(config_text)
    local text = tostring(config_text or "")
    local bounds = find_deps_bounds(text)
    if bounds == nil then
        return {}, nil
    end
    local inner = text:sub(bounds.list_open + 1, bounds.list_close - 1)
    local entries = {}
    for _, raw in ipairs(split_top_level(inner)) do
        local item = parse_dep_entry(raw)
        if item ~= nil and trim(item.name) ~= "" then
            entries[#entries + 1] = item
        end
    end
    return entries, bounds
end

local function dependency_lookup(entries)
    local lookup = {}
    for _, entry in ipairs(entries or {}) do
        lookup[lower(entry.name)] = entry
    end
    return lookup
end

local function render_package_entry(name, version)
    if trim(version) == "" then
        return encode_atom(name)
    end
    return "{" .. encode_atom(name) .. ", \"" .. tostring(version) .. "\"}"
end

local function render_local_git_entry(name, path)
    return "{" .. encode_atom(name) .. ", {git, \"" .. tostring(path) .. "\"}}"
end

local function rewrite_dependencies(config_path, updates, removals)
    local original = read_file(config_path) or default_rebar_config()
    local entries, bounds = parse_declared_dependencies(original)
    local ordered = {}
    local seen = {}
    for _, entry in ipairs(entries) do
        local key = lower(entry.name)
        if removals[key] ~= true then
            if updates[key] ~= nil then
                ordered[#ordered + 1] = updates[key]
                seen[key] = true
            else
                ordered[#ordered + 1] = entry.raw
                seen[key] = true
            end
        else
            seen[key] = true
        end
    end
    for key, value in pairs(updates or {}) do
        if not seen[key] then
            ordered[#ordered + 1] = value
        end
    end

    table.sort(ordered, function(left, right)
        local li = parse_dep_entry(left)
        local ri = parse_dep_entry(right)
        return lower(li and li.name or left) < lower(ri and ri.name or right)
    end)

    local rendered = "{deps, [\n"
    for index, entry in ipairs(ordered) do
        rendered = rendered .. "    " .. entry
        if index < #ordered then
            rendered = rendered .. ","
        end
        rendered = rendered .. "\n"
    end
    rendered = rendered .. "]}.\n"

    local final
    if bounds == nil then
        local prefix = original
        if prefix ~= "" and prefix:sub(-1) ~= "\n" then
            prefix = prefix .. "\n"
        end
        final = prefix .. rendered
    else
        local suffix_start = bounds.list_close + 1
        local suffix = original:sub(suffix_start)
        local closing = suffix:match("^%s*%}%.?")
        if closing ~= nil then
            suffix = suffix:sub(#closing + 1)
        end
        final = original:sub(1, bounds.decl_start - 1) .. rendered .. suffix
    end
    return write_file(config_path, final)
end

local function sort_items(items)
    table.sort(items, function(left, right)
        local lname = lower(left.name or left.packageId or "")
        local rname = lower(right.name or right.packageId or "")
        if lname == rname then
            return trim(left.version or "") < trim(right.version or "")
        end
        return lname < rname
    end)
end

local function remote_info(context, name)
    if trim(name) == "" then
        return nil
    end
    if not command_exists(context, REQUIRED_BINARY) then
        return nil
    end
    local result = exec_run(context, build_global_command({ "pkgs", name }))
    if not is_command_success(result) then
        return nil
    end
    local item = {
        name = name,
        packageId = name,
        packageType = "package",
    }
    for _, line in ipairs(split_lines(result.stdout)) do
        local cleaned = trim(line)
        local value = cleaned:match("^Name:%s+(.+)$")
        if value ~= nil then
            item.name = trim(value)
            item.packageId = trim(value)
        end
        value = cleaned:match("^Description:%s+(.+)$")
        if value ~= nil then
            item.description = trim(value)
        end
        value = cleaned:match("^Licenses:%s+(.+)$")
        if value ~= nil then
            item.license = trim(value)
        end
        value = cleaned:match("^Versions:%s+(.+)$")
        if value ~= nil then
            local latest = nil
            for version in value:gmatch("[^,]+") do
                local cleaned_version = trim(version)
                if latest == nil or compare_versions(cleaned_version, latest) > 0 then
                    latest = cleaned_version
                end
            end
            item.latestVersion = latest
            if item.version == nil or item.version == "" then
                item.version = latest
            end
        end
        value = cleaned:match("^[A-Za-z0-9_%-]+:%s+(https?://.+)$")
        if value ~= nil and item.homepage == nil then
            item.homepage = trim(value)
        end
    end
    if item.latestVersion == nil and item.description == nil and item.license == nil and item.homepage == nil then
        return nil
    end
    return item
end

local function direct_dependency_items(config_path)
    local entries = parse_declared_dependencies(read_file(config_path) or "")
    local items = {}
    for _, entry in ipairs(entries) do
        items[#items + 1] = {
            name = entry.name,
            packageId = entry.name,
            version = entry.version,
            packageType = entry.packageType,
            installed = true,
            status = "declared",
        }
    end
    sort_items(items)
    return items
end

local function detect_local_name(path, packages)
    local requested = packages or {}
    if #requested > 0 then
        local explicit = package_name(requested[1])
        if explicit ~= "" then
            return explicit
        end
    end
    return basename(path)
end

local function names_argument(packages)
    local names = {}
    for _, package in ipairs(packages or {}) do
        local name = package_name(package)
        if name ~= "" then
            names[#names + 1] = name
        end
    end
    return table.concat(names, ",")
end

function plugin.getName()
    return PLUGIN_NAME
end

function plugin.getVersion()
    return PLUGIN_VERSION
end

function plugin.getRequirements()
    return {}
end

function plugin.getCategories()
    return { "Erlang", "rebar3", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end
    local target = ensure_project_ready(nil, requested, false)
    if target == nil then
        return requested
    end
    local entries = direct_dependency_items(target.rebar_config)
    local lookup = {}
    for _, entry in ipairs(entries) do
        lookup[lower(entry.name)] = entry
    end
    local missing = {}
    for _, package in ipairs(requested) do
        local name = package_name(package)
        local action = package_action(package)
        local current = lookup[lower(name)]
        if action == "remove" then
            if current ~= nil then
                missing[#missing + 1] = package
            end
        elseif action == "update" then
            if current ~= nil then
                missing[#missing + 1] = package
            end
        elseif current == nil then
            missing[#missing + 1] = package
        else
            local version = package_version(package)
            if version ~= "" and trim(current.version or "") ~= version then
                missing[#missing + 1] = package
            end
        end
    end
    return missing
end

function plugin.install(context, packages)
    local requested = request_packages(context, packages)
    local local_path = trim(read_field(context, "localPath") or read_field(read_field(context, "request"), "localPath") or "")
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end
    if #requested == 0 then
        tx_success(context)
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end
    local target, err = ensure_project_ready(context, requested, true)
    if target == nil then
        tx_failed(context, err)
        return false
    end
    begin_step(context, "install rebar3 dependencies")
    local updates = {}
    for _, package in ipairs(requested) do
        local name = package_name(package)
        if name == "" then
            tx_failed(context, "rebar3 package name missing")
            return false
        end
        updates[lower(name)] = render_package_entry(name, package_version(package))
    end
    if not rewrite_dependencies(target.rebar_config, updates, {}) then
        tx_failed(context, "failed to update rebar.config")
        return false
    end
    local update_result = exec_run(context, build_global_command({ "update" }))
    if not is_command_success(update_result) then
        tx_failed(context, trim(update_result.stderr) ~= "" and trim(update_result.stderr) or "rebar3 update failed")
        return false
    end
    local deps_result = exec_run(context, build_project_command(target.dir, { "get-deps" }))
    if not is_command_success(deps_result) then
        tx_failed(context, trim(deps_result.stderr) ~= "" and trim(deps_result.stderr) or "rebar3 get-deps failed")
        return false
    end
    emit_event(context, "installed", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path or read_field(context, "localPath") or read_field(read_field(context, "request"), "localPath") or "")
    if local_path == "" then
        tx_failed(context, "missing local rebar3 dependency path")
        return false
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end
    if not is_command_success(exec_run(context, "test -d " .. shell_quote(join_path(local_path, ".git")))) then
        tx_failed(context, "installLocal supports local git repositories only")
        return false
    end
    local requested = request_packages(context, nil)
    local target, err = ensure_project_ready(context, requested, true)
    if target == nil then
        tx_failed(context, err)
        return false
    end
    begin_step(context, "install local rebar3 dependency")
    local name = detect_local_name(local_path, requested)
    local updates = {
        [lower(name)] = render_local_git_entry(name, local_path),
    }
    if not rewrite_dependencies(target.rebar_config, updates, {}) then
        tx_failed(context, "failed to update rebar.config")
        return false
    end
    local result = exec_run(context, build_project_command(target.dir, { "get-deps" }))
    if not is_command_success(result) then
        tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "rebar3 get-deps failed")
        return false
    end
    emit_event(context, "installed", {
        {
            name = name,
            packageId = name,
            packageType = "source",
            installed = true,
            status = "declared",
            path = local_path,
        },
    })
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.remove(context, packages)
    local requested = request_packages(context, packages)
    if #requested == 0 then
        tx_success(context)
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end
    local target, err = ensure_project_ready(context, requested, true)
    if target == nil then
        tx_failed(context, err)
        return false
    end
    begin_step(context, "remove rebar3 dependencies")
    local removals = {}
    for _, package in ipairs(requested) do
        local name = package_name(package)
        if name ~= "" then
            removals[lower(name)] = true
        end
    end
    if not rewrite_dependencies(target.rebar_config, {}, removals) then
        tx_failed(context, "failed to update rebar.config")
        return false
    end
    local names = names_argument(requested)
    if names ~= "" then
        local result = exec_run(context, build_project_command(target.dir, { "unlock", names }))
        if not is_command_success(result) then
            tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "rebar3 unlock failed")
            return false
        end
    end
    emit_event(context, "deleted", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.update(context, packages)
    local requested = request_packages(context, packages)
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end
    local target, err = ensure_project_ready(context, requested, true)
    if target == nil then
        tx_failed(context, err)
        return false
    end
    begin_step(context, "update rebar3 dependencies")
    local updates = {}
    for _, package in ipairs(requested) do
        local name = package_name(package)
        local version = package_version(package)
        if name ~= "" and version ~= "" then
            updates[lower(name)] = render_package_entry(name, version)
        end
    end
    if next(updates) ~= nil then
        if not rewrite_dependencies(target.rebar_config, updates, {}) then
            tx_failed(context, "failed to update rebar.config")
            return false
        end
    end
    local update_result = exec_run(context, build_global_command({ "update" }))
    if not is_command_success(update_result) then
        tx_failed(context, trim(update_result.stderr) ~= "" and trim(update_result.stderr) or "rebar3 update failed")
        return false
    end
    local args = { "upgrade" }
    local names = names_argument(requested)
    if names ~= "" then
        args[#args + 1] = names
    end
    local result = exec_run(context, build_project_command(target.dir, args))
    if not is_command_success(result) then
        tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "rebar3 upgrade failed")
        return false
    end
    emit_event(context, "updated", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.list(context)
    local target, err = ensure_project_ready(context, {}, false)
    if target == nil then
        log_warn(context, err)
        local empty = {}
        emit_event(context, "listed", empty)
        return empty
    end
    local items = direct_dependency_items(target.rebar_config)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local target, err = ensure_project_ready(context, {}, false)
    if target == nil then
        log_warn(context, err)
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end
    if not command_exists(context, REQUIRED_BINARY) then
        log_warn(context, REQUIRED_BINARY .. " binary not available")
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end
    local update_result = exec_run(context, build_global_command({ "update" }))
    if not is_command_success(update_result) then
        log_warn(context, trim(update_result.stderr) ~= "" and trim(update_result.stderr) or "rebar3 update failed")
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end
    local items = {}
    for _, item in ipairs(direct_dependency_items(target.rebar_config)) do
        if item.packageType == "package" and is_exact_version(item.version or "") then
            local remote = remote_info(context, item.name)
            if remote ~= nil and trim(remote.latestVersion or "") ~= "" and compare_versions(item.version, remote.latestVersion) < 0 then
                item.latestVersion = remote.latestVersion
                item.description = remote.description
                item.license = remote.license
                item.homepage = remote.homepage
                item.status = "outdated"
                items[#items + 1] = item
            end
        end
    end
    sort_items(items)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
    if query == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    local item = remote_info(context, query)
    local items = {}
    if item ~= nil then
        item.version = item.latestVersion or item.version
        item.installed = false
        item.status = "available"
        items[1] = item
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = info_prompt(context, name)
    if query == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local target = ensure_project_ready(context, {}, false)
    local local_item = nil
    if target ~= nil then
        for _, item in ipairs(direct_dependency_items(target.rebar_config)) do
            if lower(item.name) == lower(query) then
                local_item = item
                break
            end
        end
    end
    local remote = remote_info(context, query)
    if local_item == nil and remote == nil then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local item = local_item or {
        name = query,
        packageId = query,
    }
    if remote ~= nil then
        for key, value in pairs(remote) do
            if value ~= nil and value ~= "" then
                if key ~= "version" or local_item == nil then
                    item[key] = value
                end
            end
        end
    end
    if local_item ~= nil then
        item.installed = true
        item.status = item.status or "declared"
        if trim(item.version or "") == "" then
            item.version = local_item.version
        end
    else
        item.installed = false
        item.status = item.status or "available"
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "dependency-install", "dependency-remove", "dependency-update", "dependency-query", "project-manifest-edit" },
        ecosystemScopes = { "erlang", "rebar3", "hexpm" },
        writeScopes = {
            "user-home-subpath:.cache/reqpack/rebar3",
            "project-file:rebar.config",
            "project-file:rebar.lock",
            "project-subpath:_build",
        },
        networkScopes = { "repo.hex.pm", "hex.pm" },
        privilegeLevel = "none",
        osvEcosystem = "Hex",
        purlType = "hex",
    }
end

return plugin
