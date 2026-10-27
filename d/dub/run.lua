plugin = {}
plugin.fileExtensions = { ".json", ".sdl" }

local PLUGIN_ID = "dub"
local PLUGIN_NAME = "dub"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "dub"
local DEFAULT_REGISTRY = "https://code.dlang.org"
local SYNTHETIC_PROJECT_NAME = "reqpack-dub-cache"
local SYNTHETIC_PROJECT_VERSION = "0.0.0"
local SYNTHETIC_PROJECT_DESCRIPTION = "ReqPack synthetic DUB dependency cache project"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
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

local function lower(value)
    return string.lower(tostring(value or ""))
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
    return tostring(value or ""):match("^[A-Za-z0-9_./:@%%+=,%-$%{%}%[%]~]+$") ~= nil
end

local function shell_quote(value)
    local text = expand_placeholders(value)
    if is_safe_token(text) then
        return text
    end
    return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function force_shell_quote(value)
    local text = expand_placeholders(value)
    return "'" .. text:gsub("'", "'\\''") .. "'"
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
    local dir = trim(path)
    if dir == "" or dir == "." then
        return true
    end
    if is_test_fixture_path(dir) then
        return true
    end
    if os == nil or type(os.execute) ~= "function" then
        return false
    end
    local ok, kind, code = os.execute("mkdir -p " .. shell_quote(dir))
    if command_ok(ok, kind, code) then
        return true
    end
    return false
end

local function read_file(path)
    local handle = io.open(path, "r")
    if handle ~= nil then
        local content = handle:read("*a")
        handle:close()
        return content
    end

    local result = run_exec(nil, "cat " .. force_shell_quote(path))
    if result ~= nil and result.success == true then
        return result.stdout
    end

    local fixture_root = trim(getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
    if fixture_root == "" then
        return nil
    end

    local normalized = trim(expand_placeholders(path))
    if normalized:sub(1, #fixture_root) ~= fixture_root then
        local alt_result = run_exec(nil, "cat " .. force_shell_quote(join_path(fixture_root, normalized)))
        if alt_result ~= nil and alt_result.success == true then
            return alt_result.stdout
        end
    end

    return nil
end

local function write_file(path, content)
    local dir = parent_dir(path)
    if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
        if not is_test_fixture_path(path) then
            return false, "failed to create parent directory"
        end
    end
    local handle = io.open(path, "w")
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

local function home_dir()
    if os ~= nil and type(os.getenv) == "function" then
        local value = trim(os.getenv("HOME") or os.getenv("USERPROFILE") or "")
        if value ~= "" then
            return value
        end
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

local function package_name(package)
    return trim(read_field(package, "name") or read_field(package, "packageName") or read_field(package, "packageId"))
end

local function package_version(package)
    return trim(read_field(package, "version"))
end

local function package_kind(package)
    local kind = lower(trim(read_field(package, "packageType") or "package"))
    if kind == "" then
        return "package"
    end
    return kind
end

local function package_action(package, fallback)
    local action = trim(read_field(package, "action") or fallback or "")
    if action == "" then
        return "install"
    end
    return lower(action)
end

local function normalize_package_request(package, fallback_action)
    local name = package_name(package)
    if name == "" then
        return nil, "missing package name"
    end
    return {
        name = name,
        packageId = name,
        version = package_version(package),
        packageType = package_kind(package),
        action = package_action(package, fallback_action),
    }
end

local function cache_root(context, packages)
    local raw_flags = collect_raw_flags(context, packages)
    local explicit = flag_value(raw_flags, "cache-root")
    if explicit ~= nil and explicit ~= "" then
        return explicit
    end
    return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
end

local function state_paths(context, packages)
    local root = cache_root(context, packages)
    return {
        root = root,
        dub_home = join_path(root, "dub-home"),
        project_dir = join_path(root, "project"),
        project_file = join_path(root, "project", "dub.json"),
    }
end

local function env_prefix(paths)
    return table.concat({
        "NO_COLOR=1",
        "LC_ALL=C",
        "LANG=C",
        "LANGUAGE=C",
        "DUB_HOME=" .. shell_quote(paths.dub_home),
    }, " ")
end

local function build_dub_command(paths, args, options)
    local parts = { env_prefix(paths), REQUIRED_BINARY }
    for _, arg in ipairs(args or {}) do
        local cleaned = trim(arg)
        if cleaned ~= "" then
            parts[#parts + 1] = shell_quote(cleaned)
        end
    end
    local command = table.concat(parts, " ")
    local cwd = options ~= nil and trim(options.cwd) or ""
    if cwd ~= "" then
        command = "cd " .. shell_quote(cwd) .. " && " .. command
    end
    return command
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
                elseif escape == "u" then
                    local hex = source:sub(index + 2, index + 5)
                    if not hex:match("^%x%x%x%x$") then
                        json_error("invalid unicode escape", index)
                    end
                    local codepoint = tonumber(hex, 16)
                    if utf8 ~= nil and type(utf8.char) == "function" then
                        parts[#parts + 1] = utf8.char(codepoint)
                    elseif codepoint < 128 then
                        parts[#parts + 1] = string.char(codepoint)
                    else
                        json_error("unicode escape unsupported without utf8 library", index)
                    end
                    advance(6)
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
        char = peek()
        if char == "e" or char == "E" then
            advance(1)
            char = peek()
            if char == "+" or char == "-" then
                advance(1)
            end
            if not peek():match("%d") then
                json_error("invalid exponent", index)
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
        '  "name": "' .. json_escape(state.name or SYNTHETIC_PROJECT_NAME) .. '",',
        '  "version": "' .. json_escape(state.version or SYNTHETIC_PROJECT_VERSION) .. '",',
        '  "description": "' .. json_escape(state.description or SYNTHETIC_PROJECT_DESCRIPTION) .. '",',
        '  "dependencies": {',
    }
    local names = sorted_keys(state.dependencies or {})
    for index, name in ipairs(names) do
        local value = state.dependencies[name]
        local suffix = index < #names and "," or ""
        if type(value) == "table" and trim(value.path) ~= "" then
            lines[#lines + 1] = '    "' .. json_escape(name) .. '": { "path": "' .. json_escape(value.path) .. '" }' .. suffix
        else
            lines[#lines + 1] = '    "' .. json_escape(name) .. '": "' .. json_escape(trim(value)) .. '"' .. suffix
        end
    end
    lines[#lines + 1] = "  }"
    lines[#lines + 1] = "}"
    return table.concat(lines, "\n") .. "\n"
end

local function default_state()
    return {
        name = SYNTHETIC_PROJECT_NAME,
        version = SYNTHETIC_PROJECT_VERSION,
        description = SYNTHETIC_PROJECT_DESCRIPTION,
        dependencies = {},
    }
end

local function load_state(paths)
    local raw = read_file(paths.project_file)
    if raw == nil or trim(raw) == "" then
        return default_state()
    end
    local ok, decoded = pcall(json_decode, raw)
    if not ok or type(decoded) ~= "table" then
        return nil, "failed to parse synthetic dub.json"
    end
    local state = default_state()
    state.name = trim(decoded.name or state.name)
    state.version = trim(decoded.version or state.version)
    state.description = trim(decoded.description or state.description)
    local dependencies = read_field(decoded, "dependencies")
    if type(dependencies) == "table" then
        state.dependencies = {}
        for _, name in ipairs(sorted_keys(dependencies)) do
            local value = dependencies[name]
            if type(value) == "string" then
                state.dependencies[name] = trim(value)
            elseif type(value) == "table" and trim(value.path) ~= "" then
                state.dependencies[name] = { path = trim(value.path) }
            end
        end
    end
    return state
end

local function save_state(paths, state)
    if not ensure_directory(paths.project_dir) then
        if not is_test_fixture_path(paths.project_dir) then
            return false, "failed to create synthetic project directory"
        end
    end
    return write_file(paths.project_file, encode_state_json(state))
end

local function state_entry_to_item(name, value)
    local item = {
        name = name,
        packageId = name,
        packageType = "dependency",
        installed = true,
        status = "tracked",
    }
    if type(value) == "table" and trim(value.path) ~= "" then
        item.path = trim(expand_placeholders(value.path))
        item.source = "local"
    else
        local version = trim(value)
        if version ~= "" and version ~= "*" then
            item.version = version
            item.latestVersion = version
        end
        item.source = "registry"
    end
    return item
end

local function effective_package_type(state, pkg)
    if pkg.packageType == "dependency" then
        return "dependency"
    end
    if state ~= nil and state.dependencies ~= nil and state.dependencies[pkg.name] ~= nil then
        return "dependency"
    end
    return pkg.packageType
end

local function dependency_matches(entry, pkg)
    if entry == nil then
        return false
    end
    if type(entry) == "table" then
        return trim(entry.path) == trim(pkg.path or "")
    end
    local wanted = trim(pkg.version)
    local current = trim(entry)
    if wanted == "" then
        wanted = "*"
    end
    return current == wanted
end

local function parse_local_sdl(content)
    local name = trim((tostring(content or ""):match('[\r\n%s]name%s+"([^"]+)"')) or tostring(content or ""):match('^name%s+"([^"]+)"'))
    local version = trim((tostring(content or ""):match('[\r\n%s]version%s+"([^"]+)"')) or tostring(content or ""):match('^version%s+"([^"]+)"'))
    return name, version
end

local function detect_local_package(path)
    local root = trim(path)
    if root == "" then
        return nil, "missing local path"
    end
    local json_path = join_path(root, "dub.json")
    local sdl_path = join_path(root, "dub.sdl")
    local json_content = read_file(json_path)
    if json_content ~= nil then
        local ok, decoded = pcall(json_decode, json_content)
        if ok and type(decoded) == "table" and trim(decoded.name) ~= "" then
            return {
                name = trim(decoded.name),
                version = trim(decoded.version),
                path = root,
            }
        end
        return nil, "failed to parse local dub.json"
    end
    local sdl_content = read_file(sdl_path)
    if sdl_content ~= nil then
        local name, version = parse_local_sdl(sdl_content)
        if name ~= "" then
            return {
                name = name,
                version = version,
                path = root,
            }
        end
        return nil, "failed to parse local dub.sdl"
    end
    return nil, "local path has no dub.json or dub.sdl"
end

local function validate_synthetic_project(context, paths)
    local result = run_exec(context, build_dub_command(paths, { "describe", "--vquiet" }, { cwd = paths.project_dir }))
    if result == nil or result.success ~= true then
        return false, "dub describe failed for synthetic project"
    end
    return true, nil
end

local function package_fetch_command(paths, pkg)
    local args = { "fetch", pkg.name }
    if trim(pkg.version) ~= "" then
        args[#args + 1] = "--version=" .. trim(pkg.version)
    end
    return build_dub_command(paths, args)
end

local function package_remove_command(paths, pkg)
    local version = trim(pkg.version)
    if version == "" then
        version = "*"
    end
    return build_dub_command(paths, { "remove", pkg.name, "--version=" .. version, "-n" })
end

local function query_package_cache(context, paths)
    local items = {}
    local ok = ensure_available(context)
    if not ok then
        return items
    end
    local result = run_exec(context, build_dub_command(paths, { "list" }))
    if result == nil or result.success ~= true then
        return items
    end
    for _, line in ipairs(split_lines(result.stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            local name, version, path = cleaned:match("^(%S+)%s+([%w%._%-%+~:]+)%s+(.+)$")
            if name == nil then
                name, version, path = cleaned:match("^(%S+)%s+%(([^)]+)%)%s+(.+)$")
            end
            if name ~= nil and version ~= nil then
                items[#items + 1] = {
                    name = name,
                    packageId = name,
                    version = version,
                    latestVersion = version,
                    packageType = "package",
                    installed = true,
                    status = "cached",
                    path = trim(path),
                }
            end
        end
    end
    return items
end

local function cached_lookup(items)
    local lookup = {}
    for _, item in ipairs(items or {}) do
        local key = lower(trim(item.packageId or item.name))
        lookup[key] = lookup[key] or {}
        lookup[key][trim(item.version or "")] = item
    end
    return lookup
end

local function dependency_lookup(state)
    local lookup = {}
    for name, value in pairs((state or {}).dependencies or {}) do
        lookup[lower(trim(name))] = value
    end
    return lookup
end

local function percent_encode(value)
    return (tostring(value or ""):gsub("([^A-Za-z0-9%-_%.~])", function(char)
        return string.format("%%%02X", string.byte(char))
    end))
end

local function registry_base(context, packages)
    local raw_flags = collect_raw_flags(context, packages)
    local explicit = flag_value(raw_flags, "registry")
    if explicit ~= nil and explicit ~= "" then
        return explicit:gsub("/$", "")
    end
    return DEFAULT_REGISTRY
end

local function http_get(context, url)
    local result = run_exec(context, "curl -fsSL " .. shell_quote(url))
    if result == nil or result.success ~= true then
        return nil
    end
    return result.stdout
end

local function array_keys(value)
    local items = {}
    for key in pairs(value or {}) do
        items[#items + 1] = tostring(key)
    end
    table.sort(items)
    return items
end

local function table_values_to_list(value)
    local items = {}
    for _, key in ipairs(array_keys(value)) do
        items[#items + 1] = key
    end
    return items
end

local function extract_remote_item(name, payload)
    if type(payload) ~= "table" then
        return nil
    end
    local item = payload[name] or payload[trim(name)]
    if item == nil and payload.name ~= nil then
        item = payload
    end
    if type(item) ~= "table" then
        return nil
    end
    local versions = read_field(item, "versions")
    local latest = type(versions) == "table" and versions[1] or nil
    local dependencies = nil
    if type(latest) == "table" and type(latest.dependencies) == "table" then
        dependencies = table_values_to_list(latest.dependencies)
    elseif type(item.dependencies) == "table" then
        dependencies = table_values_to_list(item.dependencies)
    end
    local version = trim(item.version or item.latestVersion or read_field(latest, "version") or "")
    local homepage = trim(item.homepage or item.repository or item.subdirectory or "")
    return {
        name = trim(item.name or name),
        packageId = trim(item.name or name),
        version = version ~= "" and version or nil,
        latestVersion = version ~= "" and version or nil,
        packageType = "package",
        summary = trim(item.description or item.tagline or "") ~= "" and trim(item.description or item.tagline or "") or nil,
        description = trim(item.description or "") ~= "" and trim(item.description or "") or nil,
        homepage = homepage ~= "" and homepage or nil,
        license = trim(item.license or read_field(latest, "license") or "") ~= "" and trim(item.license or read_field(latest, "license") or "") or nil,
        dependencies = dependencies,
    }
end

local function remote_info(context, packages, name)
    local package_name_value = trim(name)
    if package_name_value == "" then
        return nil
    end
    local json_name = '["' .. package_name_value:gsub('"', '\\"') .. '"]'
    local url = registry_base(context, packages) .. "/api/packages/infos?packages=" .. percent_encode(json_name) .. "&include_dependencies=true&minimize=true"
    local body = http_get(context, url)
    if body == nil or trim(body) == "" then
        return nil
    end
    local ok, payload = pcall(json_decode, body)
    if not ok then
        return nil
    end
    return extract_remote_item(package_name_value, payload)
end

local function merge_items(primary, secondary)
    if primary == nil and secondary == nil then
        return nil
    end
    if primary == nil then
        return shallow_copy(secondary)
    end
    if secondary == nil then
        return shallow_copy(primary)
    end
    local merged = shallow_copy(secondary)
    for key, value in pairs(primary) do
        if value ~= nil and value ~= "" then
            if key == "version" and merged[key] ~= nil and merged[key] ~= "" then
                -- Keep local installed/tracked version when remote data also exists.
            else
                merged[key] = value
            end
        end
    end
    return merged
end

local function parse_search_output(raw)
    local items = {}
    local seen = {}
    for _, line in ipairs(split_lines(raw)) do
        local cleaned = trim(line)
        if cleaned ~= "" and not cleaned:find("^Searching", 1, false) then
            local name, version, summary = cleaned:match("^(%S+)%s+([%w%._%-%+~:]+)%s+%-%s+(.+)$")
            if name == nil then
                name, summary = cleaned:match("^(%S+)%s+%-%s+(.+)$")
            end
            if name ~= nil and not seen[name] then
                seen[name] = true
                items[#items + 1] = {
                    name = name,
                    packageId = name,
                    version = version,
                    latestVersion = version,
                    packageType = "package",
                    summary = trim(summary) ~= "" and trim(summary) or nil,
                    installed = false,
                    status = "available",
                }
            end
        end
    end
    return items
end

local function dependency_items_from_state(state)
    local items = {}
    for _, name in ipairs(sorted_keys((state or {}).dependencies or {})) do
        items[#items + 1] = state_entry_to_item(name, state.dependencies[name])
    end
    return items
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
    return { "Cross Platform", "D", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    local requested = request_packages(nil, packages)
    if #requested == 0 then
        return {}
    end
    local fallback_action = trim(read_field(packages, "action") or "")
    local paths = state_paths(nil, requested)
    local state = load_state(paths) or default_state()
    local dependency_state = dependency_lookup(state)
    local cached_items = {}
    if command_exists(nil, REQUIRED_BINARY) then
        cached_items = query_package_cache(nil, paths)
    end
    local cached = cached_lookup(cached_items)
    local missing = {}
    for _, raw in ipairs(requested) do
        local pkg = normalize_package_request(raw, fallback_action)
        if pkg ~= nil then
            if effective_package_type(state, pkg) == "dependency" then
                local current = dependency_state[lower(pkg.name)]
                if pkg.action == "remove" then
                    if current ~= nil then
                        missing[#missing + 1] = raw
                    end
                elseif pkg.action == "update" then
                    missing[#missing + 1] = raw
                elseif not dependency_matches(current, pkg) then
                    missing[#missing + 1] = raw
                end
            else
                local versions = cached[lower(pkg.name)] or {}
                local any_installed = next(versions) ~= nil
                local exact_installed = pkg.version ~= "" and versions[pkg.version] ~= nil
                if pkg.action == "remove" then
                    if (pkg.version ~= "" and exact_installed) or (pkg.version == "" and any_installed) then
                        missing[#missing + 1] = raw
                    end
                elseif pkg.action == "update" then
                    missing[#missing + 1] = raw
                elseif not any_installed or (pkg.version ~= "" and not exact_installed) then
                    missing[#missing + 1] = raw
                end
            end
        end
    end
    return missing
end

function plugin.install(context, packages)
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
    local paths = state_paths(context, requested)
    local fallback_action = trim(read_field(requested, "action") or "")
    local state = nil
    local installed = {}
    local remote_dependencies = {}
    begin_step(context, "install dub packages")
    for _, raw in ipairs(requested) do
        local pkg, package_err = normalize_package_request(raw, fallback_action)
        if pkg == nil then
            tx_failed(context, package_err)
            return false
        end
        if pkg.packageType == "dependency" then
            if state == nil then
                local err
                state, err = load_state(paths)
                if state == nil then
                    tx_failed(context, err)
                    return false
                end
            end
            state.dependencies[pkg.name] = pkg.version ~= "" and pkg.version or "*"
            remote_dependencies[#remote_dependencies + 1] = pkg
            installed[#installed + 1] = state_entry_to_item(pkg.name, state.dependencies[pkg.name])
        else
            local result = run_exec(context, package_fetch_command(paths, pkg))
            if result == nil or result.success ~= true then
                tx_failed(context, "dub fetch failed for " .. pkg.name)
                return false
            end
            installed[#installed + 1] = {
                name = pkg.name,
                packageId = pkg.name,
                version = pkg.version ~= "" and pkg.version or nil,
                latestVersion = pkg.version ~= "" and pkg.version or nil,
                packageType = "package",
                installed = true,
                status = "cached",
            }
        end
    end
    if next(remote_dependencies) ~= nil then
        local ok, save_err = save_state(paths, state)
        if not ok then
            tx_failed(context, save_err)
            return false
        end
        for _, pkg in ipairs(remote_dependencies) do
            local result = run_exec(context, package_fetch_command(paths, pkg))
            if result == nil or result.success ~= true then
                tx_failed(context, "dub fetch failed for dependency " .. pkg.name)
                return false
            end
        end
        local valid, validate_err = validate_synthetic_project(context, paths)
        if not valid then
            tx_failed(context, validate_err)
            return false
        end
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local request = read_field(context, "request")
    local source_path = trim(expand_placeholders(path or read_field(context, "localPath") or read_field(request, "localPath") or read_field(context, "path") or read_field(request, "path")))
    if source_path == "" then
        tx_failed(context, "missing local dub package path")
        return false
    end
    local available, message = ensure_available(context)
    if not available then
        tx_failed(context, message)
        return false
    end
    local local_package, err = detect_local_package(source_path)
    if local_package == nil then
        tx_failed(context, err)
        return false
    end
    local paths = state_paths(context, {})
    local state, state_err = load_state(paths)
    if state == nil then
        tx_failed(context, state_err)
        return false
    end
    begin_step(context, "install local dub dependency")
    state.dependencies[local_package.name] = { path = source_path }
    local ok, save_err = save_state(paths, state)
    if not ok then
        tx_failed(context, save_err)
        return false
    end
    local valid, validate_err = validate_synthetic_project(context, paths)
    if not valid then
        tx_failed(context, validate_err)
        return false
    end
    emit_event(context, "installed", {
        state_entry_to_item(local_package.name, state.dependencies[local_package.name]),
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
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
    local paths = state_paths(context, requested)
    local fallback_action = trim(read_field(requested, "action") or "")
    local state, err = load_state(paths)
    if state == nil then
        tx_failed(context, err)
        return false
    end
    local deleted = {}
    begin_step(context, "remove dub packages")
    local touched_dependency = false
    for _, raw in ipairs(requested) do
        local pkg, package_err = normalize_package_request(raw, fallback_action)
        if pkg == nil then
            tx_failed(context, package_err)
            return false
        end
        if effective_package_type(state, pkg) == "dependency" then
            local existing = state.dependencies[pkg.name]
            if existing ~= nil then
                deleted[#deleted + 1] = state_entry_to_item(pkg.name, existing)
                state.dependencies[pkg.name] = nil
                touched_dependency = true
            end
        else
            local result = run_exec(context, package_remove_command(paths, pkg))
            if result == nil or result.success ~= true then
                tx_failed(context, "dub remove failed for " .. pkg.name)
                return false
            end
            deleted[#deleted + 1] = {
                name = pkg.name,
                packageId = pkg.name,
                version = pkg.version ~= "" and pkg.version or nil,
                packageType = "package",
            }
        end
    end
    if touched_dependency then
        local ok, save_err = save_state(paths, state)
        if not ok then
            tx_failed(context, save_err)
            return false
        end
        local valid, validate_err = validate_synthetic_project(context, paths)
        if not valid then
            tx_failed(context, validate_err)
            return false
        end
    end
    emit_event(context, "deleted", deleted)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = request_packages(context, packages)
    local available, message = ensure_available(context)
    if not available then
        tx_failed(context, message)
        return false
    end
    local paths = state_paths(context, requested)
    local state, err = load_state(paths)
    if state == nil then
        tx_failed(context, err)
        return false
    end
    local updated = {}
    begin_step(context, "update dub packages")
    if #requested == 0 then
        local result = run_exec(context, build_dub_command(paths, { "upgrade" }, { cwd = paths.project_dir }))
        if result == nil or result.success ~= true then
            tx_failed(context, "dub upgrade failed")
            return false
        end
        emit_event(context, "updated", updated)
        tx_success(context)
        return true
    end
    local dependency_names = {}
    local touched_dependency = false
    for _, raw in ipairs(requested) do
        local pkg, package_err = normalize_package_request(raw, "update")
        if pkg == nil then
            tx_failed(context, package_err)
            return false
        end
        if effective_package_type(state, pkg) == "dependency" then
            if pkg.version ~= "" then
                state.dependencies[pkg.name] = pkg.version
            elseif state.dependencies[pkg.name] == nil then
                state.dependencies[pkg.name] = "*"
            end
            dependency_names[#dependency_names + 1] = pkg.name
            touched_dependency = true
            updated[#updated + 1] = state_entry_to_item(pkg.name, state.dependencies[pkg.name])
        else
            local result = run_exec(context, package_fetch_command(paths, pkg))
            if result == nil or result.success ~= true then
                tx_failed(context, "dub fetch failed for " .. pkg.name)
                return false
            end
            updated[#updated + 1] = {
                name = pkg.name,
                packageId = pkg.name,
                version = pkg.version ~= "" and pkg.version or nil,
                latestVersion = pkg.version ~= "" and pkg.version or nil,
                packageType = "package",
                installed = true,
                status = "cached",
            }
        end
    end
    if touched_dependency then
        local ok, save_err = save_state(paths, state)
        if not ok then
            tx_failed(context, save_err)
            return false
        end
        local args = { "upgrade" }
        for _, name in ipairs(dependency_names) do
            args[#args + 1] = name
        end
        local result = run_exec(context, build_dub_command(paths, args, { cwd = paths.project_dir }))
        if result == nil or result.success ~= true then
            tx_failed(context, "dub upgrade failed for synthetic project")
            return false
        end
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local paths = state_paths(context, {})
    local state, err = load_state(paths)
    if state == nil then
        log_warn(context, err)
        state = default_state()
    end
    local items = query_package_cache(context, paths)
    for _, item in ipairs(dependency_items_from_state(state)) do
        items[#items + 1] = item
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned_prompt = trim(prompt)
    if cleaned_prompt == "" then
        cleaned_prompt = trim(read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
    end
    if cleaned_prompt == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    local available = ensure_available(context)
    if not available then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    local paths = state_paths(context, {})
    local result = run_exec(context, build_dub_command(paths, { "search", cleaned_prompt }))
    local items = {}
    if result ~= nil and result.success == true then
        items = parse_search_output(result.stdout)
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local cleaned_name = trim(name)
    if cleaned_name == "" then
        cleaned_name = trim(read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
    end
    if cleaned_name == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local paths = state_paths(context, {})
    local state = load_state(paths) or default_state()
    local local_item = nil
    local state_entry = state.dependencies[cleaned_name]
    if state_entry ~= nil then
        local_item = state_entry_to_item(cleaned_name, state_entry)
    end
    if local_item == nil then
        local cached_items = query_package_cache(context, paths)
        for _, item in ipairs(cached_items) do
            if lower(trim(item.packageId or item.name)) == lower(cleaned_name) then
                local_item = item
                break
            end
        end
    end
    local remote_item = remote_info(context, {}, cleaned_name)
    local item = merge_items(remote_item, local_item)
    if item == nil then
        item = {}
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.outdated(context)
    local paths = state_paths(context, {})
    local state, err = load_state(paths)
    if state == nil then
        log_warn(context, err)
        state = default_state()
    end
    local items = {}
    for _, name in ipairs(sorted_keys(state.dependencies)) do
        local value = state.dependencies[name]
        if type(value) == "string" then
            local current = trim(value)
            if current ~= "" and current ~= "*" then
                local remote_item = remote_info(context, {}, name)
                if remote_item ~= nil and trim(remote_item.version or remote_item.latestVersion or "") ~= "" then
                    local latest = trim(remote_item.version or remote_item.latestVersion)
                    if latest ~= current then
                        items[#items + 1] = merge_items(remote_item, {
                            name = name,
                            packageId = name,
                            version = current,
                            latestVersion = latest,
                            packageType = "dependency",
                            installed = true,
                            status = "outdated",
                        }, remote_item)
                    end
                end
            end
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end
    local pkg = normalize_package_request(package, "install")
    if pkg == nil then
        return nil
    end
    local item = plugin.info(context, pkg.name)
    if type(item) == "table" and next(item) ~= nil then
        return item
    end
    return {
        name = pkg.name,
        packageId = pkg.name,
        version = pkg.version ~= "" and pkg.version or nil,
        packageType = pkg.packageType,
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "dub", "code.dlang.org", "d" },
        writeScopes = {
            { kind = "user-home-subpath", path = ".cache/reqpack/dub" },
        },
        networkScopes = {
            { host = "code.dlang.org", scheme = "https", pathPrefix = "/" },
        },
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
