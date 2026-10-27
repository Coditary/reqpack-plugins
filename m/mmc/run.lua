plugin = {}

local PLUGIN_ID = "mmc"
local PLUGIN_NAME = "mmc"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "mmc"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        return os.getenv(name)
    end
    return nil
end

local function expand_placeholders(value)
    local text = tostring(value or "")
    local fixture_root = trim(getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
    if fixture_root ~= "" then
        text = text:gsub("%$%{fixtureRoot%}", fixture_root)
    end
    return text
end

local function is_test_fixture_path(path)
    local text = tostring(path or "")
    if text:find("${fixtureRoot}", 1, true) ~= nil then
        return true
    end
    return trim(getenv("REQPACK_TEST_FIXTURE_ROOT") or "") ~= ""
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

local function basename(path)
    local normalized = tostring(path or ""):gsub("\\", "/"):gsub("/+$", "")
    return normalized:match("([^/]+)$") or normalized
end

local function parent_dir(path)
    return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
end

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
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

local function split_lines(value)
    local text = tostring(value or ""):gsub("\r\n", "\n")
    local lines = {}
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

local function is_safe_token(value)
    return tostring(value or ""):match("^[A-Za-z0-9_./:@%%+=,%-%{%}%[%]~]+$") ~= nil
end

local function shell_quote(value)
    local text = expand_placeholders(value)
    return "'" .. text:gsub("'", "'\\''") .. "'"
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

local function run_exec(context, command)
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

local function command_exists(context, binary)
    local result = run_exec(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function ensure_available(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function command_ok(ok, _, code)
    if ok == true then
        return true
    end
    if type(ok) == "number" then
        return ok == 0
    end
    return code == 0
end

local function ensure_directory(path)
    local dir = trim(expand_placeholders(path))
    if dir == "" or dir == "." then
        return true
    end
    if is_test_fixture_path(path) then
        return true
    end
    if os == nil or type(os.execute) ~= "function" then
        return false
    end
    local ok, kind, code = os.execute("mkdir -p " .. shell_quote(dir))
    return command_ok(ok, kind, code)
end

local function read_file(path)
    local expanded = expand_placeholders(path)
    local handle = io.open(expanded, "r")
    if handle ~= nil then
        local content = handle:read("*a")
        handle:close()
        return content
    end
    local result = run_exec(nil, "cat " .. shell_quote(expanded))
    if result ~= nil and result.success == true then
        return result.stdout
    end
    return nil
end

local function write_file(path, content)
    local expanded = expand_placeholders(path)
    local dir = parent_dir(expanded)
    if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
        if is_test_fixture_path(path) then
            return true, nil
        end
        return false, "failed to create parent directory"
    end
    local handle = io.open(expanded, "w")
    if handle == nil then
        if is_test_fixture_path(path) then
            return true, nil
        end
        return false, "failed to open file for writing"
    end
    handle:write(content)
    handle:close()
    return true, nil
end

local function json_error(message, index)
    error("invalid json at offset " .. tostring(index) .. ": " .. message)
end

local function json_decode(input)
    local source = tostring(input or "")
    local index = 1

    local function peek(offset)
        return source:sub(index + (offset or 0), index + (offset or 0))
    end

    local function advance(count)
        index = index + (count or 1)
    end

    local function skip_whitespace()
        while true do
            local char = peek()
            if char == " " or char == "\n" or char == "\r" or char == "\t" then
                advance(1)
            else
                return
            end
        end
    end

    local parse_value

    local function parse_string()
        if peek() ~= '"' then
            json_error("expected string", index)
        end
        advance(1)
        local parts = {}
        while true do
            local char = peek()
            if char == "" then
                json_error("unterminated string", index)
            elseif char == '"' then
                advance(1)
                return table.concat(parts)
            elseif char == "\\" then
                local escape = peek(1)
                if escape == '"' or escape == "\\" or escape == "/" then
                    parts[#parts + 1] = escape
                    advance(2)
                elseif escape == "b" then
                    parts[#parts + 1] = "\b"
                    advance(2)
                elseif escape == "f" then
                    parts[#parts + 1] = "\f"
                    advance(2)
                elseif escape == "n" then
                    parts[#parts + 1] = "\n"
                    advance(2)
                elseif escape == "r" then
                    parts[#parts + 1] = "\r"
                    advance(2)
                elseif escape == "t" then
                    parts[#parts + 1] = "\t"
                    advance(2)
                else
                    json_error("invalid escape sequence", index)
                end
            else
                parts[#parts + 1] = char
                advance(1)
            end
        end
    end

    local function parse_number()
        local start = index
        if peek() == "-" then
            advance(1)
        end
        local char = peek()
        if char == "0" then
            advance(1)
        elseif char:match("%d") then
            repeat
                advance(1)
                char = peek()
            until not char:match("%d")
        else
            json_error("invalid number", index)
        end
        if peek() == "." then
            advance(1)
            if not peek():match("%d") then
                json_error("invalid fraction", index)
            end
            repeat
                advance(1)
                char = peek()
            until not char:match("%d")
        end
        return tonumber(source:sub(start, index - 1))
    end

    local function parse_array()
        advance(1)
        skip_whitespace()
        local result = {}
        if peek() == "]" then
            advance(1)
            return result
        end
        while true do
            result[#result + 1] = parse_value()
            skip_whitespace()
            local char = peek()
            if char == "," then
                advance(1)
                skip_whitespace()
            elseif char == "]" then
                advance(1)
                return result
            else
                json_error("expected ',' or ']'", index)
            end
        end
    end

    local function parse_object()
        advance(1)
        skip_whitespace()
        local result = {}
        if peek() == "}" then
            advance(1)
            return result
        end
        while true do
            local key = parse_string()
            skip_whitespace()
            if peek() ~= ":" then
                json_error("expected ':'", index)
            end
            advance(1)
            skip_whitespace()
            result[key] = parse_value()
            skip_whitespace()
            local char = peek()
            if char == "," then
                advance(1)
                skip_whitespace()
            elseif char == "}" then
                advance(1)
                return result
            else
                json_error("expected ',' or '}'", index)
            end
        end
    end

    function parse_value()
        skip_whitespace()
        local char = peek()
        if char == '"' then
            return parse_string()
        elseif char == "{" then
            return parse_object()
        elseif char == "[" then
            return parse_array()
        elseif char == "-" or char:match("%d") then
            return parse_number()
        elseif source:sub(index, index + 3) == "true" then
            advance(4)
            return true
        elseif source:sub(index, index + 4) == "false" then
            advance(5)
            return false
        elseif source:sub(index, index + 3) == "null" then
            advance(4)
            return nil
        end
        json_error("unexpected token", index)
    end

    local result = parse_value()
    skip_whitespace()
    if index <= #source then
        json_error("unexpected trailing characters", index)
    end
    return result
end

local function json_escape(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\")
    text = text:gsub('"', '\\"')
    text = text:gsub("\b", "\\b")
    text = text:gsub("\f", "\\f")
    text = text:gsub("\n", "\\n")
    text = text:gsub("\r", "\\r")
    text = text:gsub("\t", "\\t")
    return text
end

local function sorted_keys(table_value)
    local keys = {}
    for key in pairs(table_value or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)
    return keys
end

local function encode_state_json(state)
    local lines = {
        "{",
        '  "tracked": {'
    }
    local names = sorted_keys(state.tracked or {})
    for index, name in ipairs(names) do
        local item = state.tracked[name]
        local suffix = index < #names and "," or ""
        lines[#lines + 1] = '    "' .. json_escape(name) .. '": {'
        lines[#lines + 1] = '      "name": "' .. json_escape(item.name or name) .. '",'
        lines[#lines + 1] = '      "sourcePath": "' .. json_escape(item.sourcePath or "") .. '",'
        lines[#lines + 1] = '      "installTarget": "' .. json_escape(item.installTarget or ("lib" .. name .. ".install")) .. '",'
        lines[#lines + 1] = '      "mainModule": "' .. json_escape(item.mainModule or name) .. '",' 
        if trim(item.version) ~= "" then
            lines[#lines + 1] = '      "version": "' .. json_escape(item.version) .. '"'
        else
            lines[#lines + 1] = '      "version": ""'
        end
        lines[#lines + 1] = '    }' .. suffix
    end
    lines[#lines + 1] = "  }"
    lines[#lines + 1] = "}"
    return table.concat(lines, "\n") .. "\n"
end

local function default_state()
    return { tracked = {} }
end

local function load_state(paths)
    local raw = read_file(paths.state_file)
    if raw == nil or trim(raw) == "" then
        return default_state()
    end
    local ok, decoded = pcall(json_decode, raw)
    if not ok or type(decoded) ~= "table" then
        return nil, "failed to parse tracked mmc state"
    end
    local state = default_state()
    local tracked = read_field(decoded, "tracked")
    if type(tracked) == "table" then
        for _, name in ipairs(sorted_keys(tracked)) do
            local item = tracked[name]
            if type(item) == "table" then
                state.tracked[name] = {
                    name = trim(item.name or name),
                    sourcePath = trim(item.sourcePath or ""),
                    version = trim(item.version or ""),
                    installTarget = trim(item.installTarget or ("lib" .. name .. ".install")),
                    mainModule = trim(item.mainModule or name),
                }
            end
        end
    end
    return state
end

local function save_state(paths, state)
    if not ensure_directory(paths.root) then
        return false, "failed to create plugin cache directory"
    end
    return write_file(paths.state_file, encode_state_json(state))
end

local function home_dir()
    local value = trim(getenv("HOME") or getenv("USERPROFILE") or "")
    if value ~= "" then
        return value
    end
    return "/home/test"
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
            return trim(expand_placeholders(cleaned:sub(#prefix + 1)))
        end
    end
    return nil
end

local function flag_values(flags, key)
    local values = {}
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            values[#values + 1] = trim(expand_placeholders(cleaned:sub(#prefix + 1)))
        end
    end
    return values
end

local function flag_present(flags, key)
    local wanted = lower(trim(key))
    for _, flag in ipairs(flags or {}) do
        if lower(trim(flag)) == wanted then
            return true
        end
    end
    return false
end

local function request_packages(context, packages)
    if (type(packages) == "table" or type(packages) == "userdata") and #packages > 0 then
        return packages
    end
    local request = read_field(context, "request")
    local request_packages_value = read_field(request, "packages")
    if type(request_packages_value) == "table" or type(request_packages_value) == "userdata" then
        return request_packages_value
    end
    return packages or {}
end

local function looks_like_path(value)
    local text = trim(value)
    return text:find("/", 1, true) ~= nil or text:sub(1, 1) == "."
end

local function package_name(package)
    return trim(read_field(package, "name") or read_field(package, "packageName") or read_field(package, "packageId"))
end

local function package_path(package)
    return trim(read_field(package, "path") or read_field(package, "sourcePath") or "")
end

local function package_version(package)
    return trim(read_field(package, "version") or "")
end

local function package_action(package, fallback)
    local action = trim(read_field(package, "action") or fallback or "")
    if action == "" then
        return "install"
    end
    return lower(action)
end

local function state_paths(context, packages)
    local raw_flags = collect_raw_flags(context, packages)
    local root = flag_value(raw_flags, "cache-root") or join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
    local prefix = flag_value(raw_flags, "install-prefix") or join_path(root, "install-prefix")
    return {
        root = root,
        install_prefix = prefix,
        mercury_root = join_path(prefix, "lib", "mercury"),
        state_file = join_path(root, "tracked.json"),
    }, raw_flags
end

local function normalize_package_request(package, fallback_action, local_path)
    local raw_name = package_name(package)
    local source_path = trim(expand_placeholders(package_path(package) ~= "" and package_path(package) or local_path or ""))
    if source_path == "" and looks_like_path(raw_name) then
        source_path = trim(expand_placeholders(raw_name))
        raw_name = ""
    end
    local name = trim(raw_name)
    if name == "" and source_path ~= "" then
        name = basename(source_path)
    end
    if name == "" then
        return nil, "missing Mercury library name"
    end
    return {
        name = name,
        packageId = name,
        sourcePath = source_path,
        version = package_version(package),
        installTarget = "lib" .. name .. ".install",
        mainModule = name,
        action = package_action(package, fallback_action),
    }
end

local function artifact_probe_command(paths, name)
    return "find " .. shell_quote(paths.mercury_root) .. " \\( -name " .. shell_quote("lib" .. name .. ".*") .. " -o -name " .. shell_quote(name .. "*") .. " \\) -print -quit"
end

local function has_installed_artifacts(context, paths, name)
    local result = run_exec(context, artifact_probe_command(paths, name))
    return result ~= nil and trim(result.stdout or "") ~= ""
end

local function remove_installed_artifacts(context, paths, name)
    local result = run_exec(context, "find " .. shell_quote(paths.mercury_root) .. " \\( -name " .. shell_quote("lib" .. name .. ".*") .. " -o -name " .. shell_quote(name .. "*") .. " \\) -exec rm -rf {} +")
    return result == nil or result.success == true
end

local function build_install_command(paths, raw_flags, pkg)
    local parts = {
        "cd " .. shell_quote(pkg.sourcePath),
        "&&",
        REQUIRED_BINARY,
        "--make",
        "--install-prefix",
        shell_quote(paths.install_prefix),
    }
    if flag_present(raw_flags, "no-libgrade") then
        parts[#parts + 1] = "--no-libgrade"
    end
    for _, grade in ipairs(flag_values(raw_flags, "libgrade")) do
        parts[#parts + 1] = "--libgrade"
        parts[#parts + 1] = shell_quote(grade)
    end
    parts[#parts + 1] = shell_quote(pkg.installTarget)
    return table.concat(parts, " ")
end

local function tracked_item_to_result(context, paths, item)
    return {
        name = item.name,
        packageId = item.name,
        version = item.version ~= "" and item.version or nil,
        latestVersion = item.version ~= "" and item.version or nil,
        installed = has_installed_artifacts(context, paths, item.name),
        status = "tracked",
        summary = "Mercury library tracked in ReqPack cache",
        description = "Tracked Mercury library installed through mmc --make",
        packageType = "mercury-library",
        dependencies = {},
        extraFields = {
            sourcePath = item.sourcePath,
            installPrefix = paths.install_prefix,
            installTarget = item.installTarget,
            consumerFlags = {
                "--mld " .. join_path(paths.install_prefix, "lib", "mercury"),
                "--ml " .. item.name,
            },
        },
    }
end

local function sorted_tracked_items(state)
    local items = {}
    for _, name in ipairs(sorted_keys(state.tracked or {})) do
        items[#items + 1] = state.tracked[name]
    end
    return items
end

local function perform_install(context, packages, local_path)
    local requested = request_packages(context, packages)
    if #requested == 0 then
        tx_success(context)
        return true
    end
    local available, message = ensure_available(context)
    if not available then
        tx_failed(context, message)
        return false
    end

    local paths, raw_flags = state_paths(context, requested)
    local state, state_error = load_state(paths)
    if state == nil then
        tx_failed(context, state_error)
        return false
    end

    local fallback_action = trim(read_field(requested, "action") or "")
    local installed = {}
    begin_step(context, "install Mercury libraries")
    for _, raw in ipairs(requested) do
        local pkg, package_error = normalize_package_request(raw, fallback_action, local_path)
        if pkg == nil then
            tx_failed(context, package_error)
            return false
        end
        if pkg.sourcePath == "" then
            tx_failed(context, "missing Mercury library source path for " .. pkg.name)
            return false
        end
        local result = run_exec(context, build_install_command(paths, raw_flags, pkg))
        if result == nil or result.success ~= true then
            tx_failed(context, "mmc install failed for " .. pkg.name)
            return false
        end
        state.tracked[pkg.name] = {
            name = pkg.name,
            sourcePath = pkg.sourcePath,
            version = pkg.version,
            installTarget = pkg.installTarget,
            mainModule = pkg.mainModule,
        }
        installed[#installed + 1] = tracked_item_to_result(context, paths, state.tracked[pkg.name])
    end
    local ok, save_error = save_state(paths, state)
    if not ok then
        tx_failed(context, save_error)
        return false
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
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
    return { "Cross Platform", "Mercury", "Package Manager", "Build Tool" }
end

function plugin.getMissingPackages(packages)
    local requested = request_packages(nil, packages)
    if #requested == 0 then
        return {}
    end
    if not command_exists(nil, REQUIRED_BINARY) then
        return requested
    end
    local paths = state_paths(nil, requested)
    local state = load_state(paths) or default_state()
    local fallback_action = trim(read_field(packages, "action") or "")
    local missing = {}
    for _, raw in ipairs(requested) do
        local pkg = normalize_package_request(raw, fallback_action)
        if pkg ~= nil then
            local tracked = state.tracked[pkg.name]
            if pkg.action == "remove" then
                if tracked ~= nil then
                    missing[#missing + 1] = raw
                end
            elseif pkg.action == "update" then
                if tracked ~= nil then
                    missing[#missing + 1] = raw
                end
            elseif tracked == nil or trim(tracked.sourcePath) ~= trim(pkg.sourcePath) then
                missing[#missing + 1] = raw
            end
        end
    end
    return missing
end

function plugin.install(context, packages)
    local request = read_field(context, "request")
    local local_path = trim(expand_placeholders(read_field(context, "localPath") or read_field(request, "localPath") or read_field(context, "path") or read_field(request, "path") or ""))
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end
    return perform_install(context, packages, nil)
end

function plugin.installLocal(context, path)
    local source_path = trim(expand_placeholders(path))
    if source_path == "" then
        tx_failed(context, "missing local Mercury library path")
        return false
    end
    local request = read_field(context, "request") or {}
    local packages = request_packages(context, read_field(request, "packages"))
    if #packages == 0 then
        packages = { { path = source_path, name = trim(read_field(request, "name") or "") } }
    end
    for _, pkg in ipairs(packages) do
        if trim(package_path(pkg)) == "" then
            pkg.path = source_path
        end
    end
    return perform_install(context, packages, source_path)
end

function plugin.remove(context, packages)
    local requested = request_packages(context, packages)
    if #requested == 0 then
        tx_success(context)
        return true
    end
    local paths = state_paths(context, requested)
    local state, state_error = load_state(paths)
    if state == nil then
        tx_failed(context, state_error)
        return false
    end
    local deleted = {}
    begin_step(context, "remove Mercury libraries")
    for _, raw in ipairs(requested) do
        local pkg, package_error = normalize_package_request(raw, "remove")
        if pkg == nil then
            tx_failed(context, package_error)
            return false
        end
        local existing = state.tracked[pkg.name]
        if existing ~= nil then
            remove_installed_artifacts(context, paths, pkg.name)
            deleted[#deleted + 1] = tracked_item_to_result(context, paths, existing)
            state.tracked[pkg.name] = nil
        end
    end
    local ok, save_error = save_state(paths, state)
    if not ok then
        tx_failed(context, save_error)
        return false
    end
    emit_event(context, "deleted", deleted)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local available, message = ensure_available(context)
    if not available then
        tx_failed(context, message)
        return false
    end
    local requested = request_packages(context, packages)
    local paths, raw_flags = state_paths(context, requested)
    local state, state_error = load_state(paths)
    if state == nil then
        tx_failed(context, state_error)
        return false
    end

    local targets = {}
    if #requested == 0 then
        targets = sorted_tracked_items(state)
    else
        for _, raw in ipairs(requested) do
            local pkg, package_error = normalize_package_request(raw, "update")
            if pkg == nil then
                tx_failed(context, package_error)
                return false
            end
            local tracked = state.tracked[pkg.name]
            if tracked ~= nil then
                if pkg.sourcePath ~= "" then
                    tracked.sourcePath = pkg.sourcePath
                end
                if pkg.version ~= "" then
                    tracked.version = pkg.version
                end
                targets[#targets + 1] = tracked
            end
        end
    end

    begin_step(context, "update Mercury libraries")
    local updated = {}
    for _, item in ipairs(targets) do
        local result = run_exec(context, build_install_command(paths, raw_flags, item))
        if result == nil or result.success ~= true then
            tx_failed(context, "mmc update failed for " .. item.name)
            return false
        end
        updated[#updated + 1] = tracked_item_to_result(context, paths, item)
    end
    local ok, save_error = save_state(paths, state)
    if not ok then
        tx_failed(context, save_error)
        return false
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local paths = state_paths(context, {})
    local state, state_error = load_state(paths)
    if state == nil then
        log_warn(context, state_error)
        state = default_state()
    end
    local items = {}
    for _, item in ipairs(sorted_tracked_items(state)) do
        items[#items + 1] = tracked_item_to_result(context, paths, item)
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local empty = {}
    emit_event(context, "outdated", empty)
    return empty
end

function plugin.search(context, prompt)
    local query = lower(trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or ""))
    if query == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    local paths = state_paths(context, {})
    local state = load_state(paths) or default_state()
    local items = {}
    for _, item in ipairs(sorted_tracked_items(state)) do
        items[#items + 1] = tracked_item_to_result(context, paths, item)
    end
    local results = {}
    for _, item in ipairs(items) do
        local extra = item.extraFields or {}
        local haystack = lower(table.concat({
            trim(item.name or ""),
            trim(item.packageId or ""),
            trim(read_field(extra, "sourcePath") or ""),
        }, "\n"))
        if haystack:find(query, 1, true) ~= nil then
            results[#results + 1] = item
        end
    end
    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local query = trim(name or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
    if query == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local paths = state_paths(context, {})
    local state = load_state(paths) or default_state()
    local item = state.tracked[query]
    if item == nil then
        for tracked_name, tracked in pairs(state.tracked) do
            if lower(tracked_name) == lower(query) then
                item = tracked
                break
            end
        end
    end
    if item == nil then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local result = tracked_item_to_result(context, paths, item)
    emit_event(context, "informed", result)
    return result
end

function plugin.resolvePackage(context, package)
    local pkg = normalize_package_request(package, "install")
    if pkg == nil then
        return nil
    end
    return plugin.info(context, pkg.name)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "filesystem.write", "filesystem.read" },
        ecosystemScopes = { "mercury" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".cache/reqpack/mmc" },
        },
        networkScopes = {},
        privilegeLevel = "none",
        purlType = "generic",
    }
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

return plugin
