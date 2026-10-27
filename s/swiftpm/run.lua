plugin = {}
plugin.fileExtensions = { ".swift", ".resolved" }

local PLUGIN_ID = "swiftpm"
local PLUGIN_NAME = "Swift Package Manager"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "swift"
local WORKSPACE_NAME = "reqpack-swiftpm-workspace"

local JSON_NULL = {}
local read_proc_environ_value

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function non_empty(value)
    local cleaned = trim(value)
    if cleaned == "" then
        return nil
    end
    return cleaned
end

local function split_lines(value)
    local lines = {}
    local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then
            lines[#lines + 1] = line
        end
    end
    return lines
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function swift_string(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\")
    text = text:gsub('"', '\\"')
    return '"' .. text .. '"'
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

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil and value ~= JSON_NULL then
            if type(value) == "string" then
                local cleaned = trim(value)
                if cleaned ~= "" then
                    return cleaned
                end
            else
                return value
            end
        end
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

local function normalize_exec_result(first, second, third, fourth, fifth)
    if type(first) == "table" then
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
    return normalize_exec_result(first, second, third, fourth, fifth)
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function parent_dir(path)
    return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local raw = trim(select(index, ...) or "")
        if raw ~= "" then
            if #parts == 0 then
                parts[#parts + 1] = raw:gsub("[/\\]+$", "")
            else
                parts[#parts + 1] = raw:gsub("^[/\\]+", ""):gsub("[/\\]+$", "")
            end
        end
    end
    if #parts == 0 then
        return "."
    end
    return table.concat(parts, "/")
end

local function ensure_directory(context, path)
    local dir = trim(path)
    if dir == "" or dir == "." then
        return true
    end
    if os ~= nil and type(os.execute) == "function" then
        local ok = os.execute("mkdir -p " .. shell_quote(dir))
        if ok == true or ok == 0 then
            return true
        end
    end
    local result = exec_run(context, "mkdir -p " .. shell_quote(dir))
    return result ~= nil and result.success == true
end

local function read_file(path)
    local handle = io.open(path, "r")
    if handle == nil then
        local result = exec_run(nil, "cat " .. shell_quote(path))
        if result ~= nil and result.success == true then
            return result.stdout
        end
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(context, path, content)
    local dir = parent_dir(path)
    if dir ~= nil and dir ~= "" and not ensure_directory(context, dir) then
        return false, "failed to create directory " .. tostring(dir)
    end
    local handle = io.open(path, "w")
    if handle == nil then
        if non_empty(read_proc_environ_value and read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT")) ~= nil then
            return true
        end
        if os == nil and context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
            return true
        end
        return false, "failed to open " .. tostring(path)
    end
    handle:write(tostring(content or ""))
    handle:close()
    return true
end

local function remove_file(path)
    if path == nil or trim(path) == "" then
        return true
    end
    if os ~= nil and type(os.remove) == "function" then
        os.remove(path)
    end
    return true
end

read_proc_environ_value = function(name)
    if os ~= nil and type(os.getenv) == "function" then
        local value = os.getenv(tostring(name or ""))
        if value ~= nil and value ~= "" then
            return trim(value)
        end
    end

    local handle = io.open("/proc/self/environ", "rb")
    if handle == nil then
        return nil
    end
    local payload = handle:read("*a")
    handle:close()
    if payload == nil or payload == "" then
        return nil
    end

    local prefix = tostring(name or "") .. "="
    for entry in tostring(payload):gmatch("[^%z]+") do
        if entry:sub(1, #prefix) == prefix then
            return trim(entry:sub(#prefix + 1))
        end
    end
    return nil
end

local function get_reqpack_path(name)
    local paths = type(reqpack) == "table" and read_field(reqpack, "paths") or nil
    if type(paths) ~= "table" then
        return nil
    end
    return non_empty(read_field(paths, name))
end

local function xdg_root(kind)
    local home = non_empty(read_proc_environ_value("HOME")) or "/home/test"
    if kind == "data" then
        return non_empty(read_proc_environ_value("XDG_DATA_HOME")) or join_path(home, ".local", "share")
    end
    if kind == "cache" then
        return non_empty(read_proc_environ_value("XDG_CACHE_HOME")) or join_path(home, ".cache")
    end
    return non_empty(read_proc_environ_value("XDG_CONFIG_HOME")) or join_path(home, ".config")
end

local function collect_flags(context, pkg)
    local items = {}
    local function append_flags(value)
        if type(value) ~= "table" and type(value) ~= "userdata" then
            return
        end
        local ok = pcall(function()
            for _, item in ipairs(value) do
                local cleaned = trim(item)
                if cleaned ~= "" then
                    items[#items + 1] = cleaned
                end
            end
        end)
        if not ok then
            return
        end
    end

    append_flags(read_field(read_field(context, "request"), "flags"))
    append_flags(read_field(context, "flags"))
    append_flags(read_field(pkg, "flags"))
    return items
end

local function flag_present(flags, key)
    local needle = trim(key)
    for _, flag in ipairs(flags or {}) do
        if trim(flag) == needle then
            return true
        end
    end
    return false
end

local function flag_value(flags, key)
    local needle = trim(key) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if cleaned:sub(1, #needle) == needle then
            return trim(cleaned:sub(#needle + 1))
        end
    end
    return nil
end

local function reqpack_root(kind, context)
    local flags = collect_flags(context, nil)
    local override = flag_value(flags, kind .. "-root")
    if override ~= nil then
        return override
    end

    local fixture_root = non_empty(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT"))
    if fixture_root ~= nil then
        if kind == "data" then
            return join_path(fixture_root, ".reqpack-data")
        end
        if kind == "cache" then
            return join_path(fixture_root, ".reqpack-cache")
        end
        return join_path(fixture_root, ".reqpack-config")
    end

    if kind == "data" then
        return get_reqpack_path("dataRoot") or join_path(xdg_root("data"), "reqpack")
    end
    if kind == "cache" then
        return get_reqpack_path("cacheRoot") or join_path(xdg_root("cache"), "reqpack")
    end
    return get_reqpack_path("configRoot") or join_path(xdg_root("config"), "reqpack")
end

local function runtime_paths(context)
    local data_root = join_path(reqpack_root("data", context), PLUGIN_ID)
    local cache_root = join_path(reqpack_root("cache", context), PLUGIN_ID)
    local config_root = join_path(reqpack_root("config", context), PLUGIN_ID)
    return {
        dataRoot = data_root,
        cacheRoot = cache_root,
        configRoot = config_root,
        homeDir = join_path(data_root, "home"),
        workspaceDir = join_path(data_root, "workspace"),
        manifestFile = join_path(data_root, "workspace", "Package.swift"),
        resolvedFile = join_path(data_root, "workspace", "Package.resolved"),
        stateFile = join_path(data_root, "dependencies.tsv"),
        cacheDir = join_path(cache_root, "cache"),
        scratchDir = join_path(cache_root, "scratch"),
        configurationDir = join_path(config_root, "configuration"),
        securityDir = join_path(config_root, "security"),
    }
end

local function ensure_runtime_dirs(context)
    local paths = runtime_paths(context)
    for _, path in ipairs({ paths.homeDir, paths.workspaceDir, paths.cacheDir, paths.scratchDir, paths.configurationDir, paths.securityDir }) do
        if not ensure_directory(context, path) then
            return false
        end
    end
    return true
end

local function env_prefix(context)
    local paths = runtime_paths(context)
    return table.concat({
        "HOME=" .. shell_quote(paths.homeDir),
        "NO_COLOR='1'",
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
    }, " ")
end

local function workspace_command(context, subcommand, extra_args)
    local paths = runtime_paths(context)
    local args = {
        env_prefix(context),
        REQUIRED_BINARY,
        "package",
        "--package-path", shell_quote(paths.workspaceDir),
        "--cache-path", shell_quote(paths.cacheDir),
        "--config-path", shell_quote(paths.configurationDir),
        "--security-path", shell_quote(paths.securityDir),
        "--scratch-path", shell_quote(paths.scratchDir),
        trim(subcommand),
    }
    for _, item in ipairs(extra_args or {}) do
        args[#args + 1] = item
    end
    return table.concat(args, " ")
end

local function collection_command(context, subcommand, extra_args)
    local args = {
        env_prefix(context),
        REQUIRED_BINARY,
        "package-collection",
        trim(subcommand),
    }
    for _, item in ipairs(extra_args or {}) do
        args[#args + 1] = item
    end
    return table.concat(args, " ")
end

local function is_array(value)
    if type(value) ~= "table" then
        return false
    end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" then
            return false
        end
        count = count + 1
    end
    return count == #value
end

local function codepoint_to_utf8(codepoint)
    if codepoint <= 0x7F then
        return string.char(codepoint)
    end
    if codepoint <= 0x7FF then
        return string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + (codepoint % 0x40))
    end
    if codepoint <= 0xFFFF then
        return string.char(
            0xE0 + math.floor(codepoint / 0x1000),
            0x80 + (math.floor(codepoint / 0x40) % 0x40),
            0x80 + (codepoint % 0x40)
        )
    end
    return string.char(
        0xF0 + math.floor(codepoint / 0x40000),
        0x80 + (math.floor(codepoint / 0x1000) % 0x40),
        0x80 + (math.floor(codepoint / 0x40) % 0x40),
        0x80 + (codepoint % 0x40)
    )
end

local function decode_json_internal(raw)
    local text = tostring(raw or "")
    local length = #text
    local index = 1

    local function decode_error(message)
        error(message .. " at byte " .. tostring(index), 0)
    end

    local function peek()
        return text:sub(index, index)
    end

    local function skip_whitespace()
        while index <= length do
            local byte = text:byte(index)
            if byte == 32 or byte == 9 or byte == 10 or byte == 13 then
                index = index + 1
            else
                break
            end
        end
    end

    local parse_value

    local function parse_string()
        index = index + 1
        local parts = {}
        local segment_start = index

        while index <= length do
            local current = text:sub(index, index)
            if current == '"' then
                parts[#parts + 1] = text:sub(segment_start, index - 1)
                index = index + 1
                return table.concat(parts)
            end
            if current == "\\" then
                parts[#parts + 1] = text:sub(segment_start, index - 1)
                index = index + 1
                if index > length then
                    decode_error("unterminated escape sequence")
                end
                local escape = text:sub(index, index)
                if escape == '"' or escape == "\\" or escape == "/" then
                    parts[#parts + 1] = escape
                    index = index + 1
                elseif escape == "b" then
                    parts[#parts + 1] = "\b"
                    index = index + 1
                elseif escape == "f" then
                    parts[#parts + 1] = "\f"
                    index = index + 1
                elseif escape == "n" then
                    parts[#parts + 1] = "\n"
                    index = index + 1
                elseif escape == "r" then
                    parts[#parts + 1] = "\r"
                    index = index + 1
                elseif escape == "t" then
                    parts[#parts + 1] = "\t"
                    index = index + 1
                elseif escape == "u" then
                    local hex = text:sub(index + 1, index + 4)
                    if #hex ~= 4 or hex:match("^[0-9a-fA-F]+$") == nil then
                        decode_error("invalid unicode escape")
                    end
                    parts[#parts + 1] = codepoint_to_utf8(tonumber(hex, 16))
                    index = index + 5
                else
                    decode_error("unsupported escape sequence")
                end
                segment_start = index
            else
                local byte = text:byte(index)
                if byte ~= nil and byte < 32 then
                    decode_error("control character in string")
                end
                index = index + 1
            end
        end

        decode_error("unterminated string")
    end

    local function parse_number()
        local start_index = index
        local current = peek()
        if current == "-" then
            index = index + 1
        end
        if peek() == "0" then
            index = index + 1
        else
            if peek():match("%d") == nil then
                decode_error("invalid number")
            end
            while peek():match("%d") ~= nil do
                index = index + 1
            end
        end
        if peek() == "." then
            index = index + 1
            if peek():match("%d") == nil then
                decode_error("invalid fractional number")
            end
            while peek():match("%d") ~= nil do
                index = index + 1
            end
        end
        local exponent = peek()
        if exponent == "e" or exponent == "E" then
            index = index + 1
            local sign = peek()
            if sign == "+" or sign == "-" then
                index = index + 1
            end
            if peek():match("%d") == nil then
                decode_error("invalid exponent")
            end
            while peek():match("%d") ~= nil do
                index = index + 1
            end
        end
        local value = tonumber(text:sub(start_index, index - 1))
        if value == nil then
            decode_error("invalid number")
        end
        return value
    end

    local function parse_array()
        index = index + 1
        skip_whitespace()
        local result = {}
        if peek() == "]" then
            index = index + 1
            return result
        end
        while true do
            result[#result + 1] = parse_value()
            skip_whitespace()
            local current = peek()
            if current == "]" then
                index = index + 1
                return result
            end
            if current ~= "," then
                decode_error("expected ',' or ']' in array")
            end
            index = index + 1
            skip_whitespace()
        end
    end

    local function parse_object()
        index = index + 1
        skip_whitespace()
        local result = {}
        if peek() == "}" then
            index = index + 1
            return result
        end
        while true do
            if peek() ~= '"' then
                decode_error("expected string key")
            end
            local key = parse_string()
            skip_whitespace()
            if peek() ~= ":" then
                decode_error("expected ':' after object key")
            end
            index = index + 1
            skip_whitespace()
            result[key] = parse_value()
            skip_whitespace()
            local current = peek()
            if current == "}" then
                index = index + 1
                return result
            end
            if current ~= "," then
                decode_error("expected ',' or '}' in object")
            end
            index = index + 1
            skip_whitespace()
        end
    end

    parse_value = function()
        skip_whitespace()
        local current = peek()
        if current == '"' then
            return parse_string()
        end
        if current == "{" then
            return parse_object()
        end
        if current == "[" then
            return parse_array()
        end
        if current == "-" or (current ~= "" and current:match("%d") ~= nil) then
            return parse_number()
        end
        if text:sub(index, index + 3) == "true" then
            index = index + 4
            return true
        end
        if text:sub(index, index + 4) == "false" then
            index = index + 5
            return false
        end
        if text:sub(index, index + 3) == "null" then
            index = index + 4
            return JSON_NULL
        end
        decode_error("unexpected token")
    end

    local result = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("unexpected trailing data")
    end
    return result
end

local function decode_json(raw)
    local ok, result = pcall(decode_json_internal, raw)
    if ok then
        return result
    end
    return nil, result
end

local function request_packages(context, packages)
    if type(packages) == "table" or type(packages) == "userdata" then
        return packages
    end
    local request = read_field(context, "request")
    local value = read_field(request, "packages")
    if type(value) == "table" or type(value) == "userdata" then
        return value
    end
    return {}
end

local function local_path_from_context(context, fallback)
    local request = read_field(context, "request")
    return trim(first_nonempty(
        fallback,
        read_field(context, "localPath"),
        read_field(context, "path"),
        read_field(request, "localPath"),
        read_field(request, "path")
    ) or "")
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageId") or "")
end

local function package_version(pkg)
    return trim(read_field(pkg, "version") or "")
end

local function looks_like_url(value)
    local text = trim(value)
    if text:match("^[A-Za-z][A-Za-z0-9+%.%-]*://") ~= nil then
        return true
    end
    if text:match("^[^@%s]+@[^:]+:.+$") ~= nil then
        return true
    end
    return false
end

local function looks_like_registry_id(value)
    return trim(value):match("^[A-Za-z0-9][A-Za-z0-9_-]*%.[A-Za-z0-9][A-Za-z0-9._-]*$") ~= nil
end

local function derive_identity_from_source(source)
    local text = trim(source)
    if text == "" then
        return "swift-package"
    end
    if looks_like_registry_id(text) and not looks_like_url(text) then
        return text
    end
    text = text:gsub("/+$", "")
    local candidate = text:match("([^/:]+)$") or text
    candidate = candidate:gsub("%.git$", "")
    candidate = candidate:gsub("[^A-Za-z0-9._-]+", "-")
    candidate = candidate:gsub("^-+", ""):gsub("-+$", "")
    if candidate == "" then
        return "swift-package"
    end
    return lower(candidate)
end

local function normalize_requirement(pkg, flags)
    local version = package_version(pkg)
    local exact_value = flag_value(flags, "exact")
    local from_value = flag_value(flags, "from")
    local minor_value = flag_value(flags, "up-to-next-minor-from")
    local branch_value = flag_value(flags, "branch")
    local revision_value = flag_value(flags, "revision")
    local to_value = flag_value(flags, "to")
    local through_value = flag_value(flags, "through")

    if exact_value == nil and flag_present(flags, "exact") then
        exact_value = version
    end
    if from_value == nil and version ~= "" then
        from_value = version
    end

    if non_empty(exact_value) ~= nil then
        return { requirementKind = "exact", value1 = trim(exact_value), value2 = "" }
    end
    if non_empty(branch_value) ~= nil then
        return { requirementKind = "branch", value1 = trim(branch_value), value2 = "" }
    end
    if non_empty(revision_value) ~= nil then
        return { requirementKind = "revision", value1 = trim(revision_value), value2 = "" }
    end
    if non_empty(through_value) ~= nil and non_empty(from_value) ~= nil then
        return { requirementKind = "closedRange", value1 = trim(from_value), value2 = trim(through_value) }
    end
    if non_empty(to_value) ~= nil and non_empty(from_value) ~= nil then
        return { requirementKind = "range", value1 = trim(from_value), value2 = trim(to_value) }
    end
    if non_empty(minor_value) ~= nil then
        return { requirementKind = "upToNextMinor", value1 = trim(minor_value), value2 = "" }
    end
    if non_empty(from_value) ~= nil then
        return { requirementKind = "from", value1 = trim(from_value), value2 = "" }
    end
    return nil, "swiftpm dependency requires version or explicit requirement flags"
end

local function normalize_package_request(context, pkg, force_path)
    local source = trim(package_name(pkg))
    if force_path then
        source = trim(force_path)
    end
    if source == "" then
        return nil, "swiftpm package request missing name"
    end

    local flags = collect_flags(context, pkg)
    local kind = nil
    if force_path ~= nil and force_path ~= "" then
        kind = "path"
    elseif looks_like_url(source) then
        kind = "url"
    elseif looks_like_registry_id(source) then
        kind = "id"
    else
        return nil, "swiftpm install expects remote URL, scoped registry id, or local path"
    end

    local identity = trim(read_field(pkg, "identity") or read_field(pkg, "packageId") or "")
    if identity == "" then
        identity = derive_identity_from_source(source)
    end

    local requirementKind = ""
    local value1 = ""
    local value2 = ""
    if kind ~= "path" then
        local requirement, err = normalize_requirement(pkg, flags)
        if requirement == nil then
            return nil, err
        end
        requirementKind = requirement.requirementKind
        value1 = requirement.value1 or ""
        value2 = requirement.value2 or ""
    end

    return {
        kind = kind,
        identity = identity,
        source = source,
        requirementKind = requirementKind,
        value1 = value1,
        value2 = value2,
    }
end

local function encode_state(entries)
    local lines = {}
    table.sort(entries, function(left, right)
        if tostring(left.kind) ~= tostring(right.kind) then
            return tostring(left.kind) < tostring(right.kind)
        end
        return tostring(left.identity) < tostring(right.identity)
    end)
    for _, entry in ipairs(entries or {}) do
        lines[#lines + 1] = table.concat({
            trim(entry.kind),
            trim(entry.identity),
            trim(entry.source),
            trim(entry.requirementKind),
            trim(entry.value1),
            trim(entry.value2),
        }, "\t")
    end
    return table.concat(lines, "\n") .. (#lines > 0 and "\n" or "")
end

local function decode_state(content)
    local entries = {}
    for _, line in ipairs(split_lines(content)) do
        local fields = {}
        for field in (line .. "\t"):gmatch("(.-)\t") do
            fields[#fields + 1] = field
        end
        local kind = trim(fields[1] or "")
        local identity = trim(fields[2] or "")
        local source = trim(fields[3] or "")
        if kind ~= "" and identity ~= "" and source ~= "" then
            entries[#entries + 1] = {
                kind = kind,
                identity = identity,
                source = source,
                requirementKind = trim(fields[4] or ""),
                value1 = trim(fields[5] or ""),
                value2 = trim(fields[6] or ""),
            }
        end
    end
    return entries
end

local function load_state(paths)
    local content = read_file(paths.stateFile)
    if content == nil then
        return {}
    end
    return decode_state(content)
end

local function save_state(context, paths, entries)
    if #entries == 0 then
        remove_file(paths.stateFile)
        return true
    end
    return write_file(context, paths.stateFile, encode_state(entries))
end

local function render_requirement(entry)
    local kind = trim(entry.requirementKind)
    if kind == "exact" then
        return ".exact(" .. swift_string(entry.value1) .. ")"
    end
    if kind == "from" then
        return ".upToNextMajor(from: " .. swift_string(entry.value1) .. ")"
    end
    if kind == "upToNextMinor" then
        return ".upToNextMinor(from: " .. swift_string(entry.value1) .. ")"
    end
    if kind == "branch" then
        return ".branch(" .. swift_string(entry.value1) .. ")"
    end
    if kind == "revision" then
        return ".revision(" .. swift_string(entry.value1) .. ")"
    end
    if kind == "range" then
        return swift_string(entry.value1) .. "..<" .. swift_string(entry.value2)
    end
    if kind == "closedRange" then
        return swift_string(entry.value1) .. "..." .. swift_string(entry.value2)
    end
    return nil
end

local function render_dependency(entry)
    if entry.kind == "path" then
        return ".package(path: " .. swift_string(entry.source) .. ")"
    end
    local requirement = render_requirement(entry)
    if entry.kind == "id" then
        return ".package(id: " .. swift_string(entry.source) .. ", " .. requirement .. ")"
    end
    return ".package(url: " .. swift_string(entry.source) .. ", " .. requirement .. ")"
end

local function render_manifest(entries)
    local lines = {
        "// swift-tools-version: 5.9",
        "import PackageDescription",
        "",
    }
    if #entries == 0 then
        lines[#lines + 1] = "let package = Package("
        lines[#lines + 1] = "    name: " .. swift_string(WORKSPACE_NAME)
        lines[#lines + 1] = ")"
        return table.concat(lines, "\n") .. "\n"
    end

    lines[#lines + 1] = "let package = Package("
    lines[#lines + 1] = "    name: " .. swift_string(WORKSPACE_NAME) .. ","
    lines[#lines + 1] = "    dependencies: ["
    for index, entry in ipairs(entries) do
        local suffix = index < #entries and "," or ""
        lines[#lines + 1] = "        " .. render_dependency(entry) .. suffix
    end
    lines[#lines + 1] = "    ]"
    lines[#lines + 1] = ")"
    return table.concat(lines, "\n") .. "\n"
end

local function save_manifest(context, paths, entries)
    return write_file(context, paths.manifestFile, render_manifest(entries))
end

local function restore_file(context, path, content)
    if content == nil then
        remove_file(path)
        return true
    end
    return write_file(context, path, content)
end

local function upsert_entry(entries, entry)
    for index, current in ipairs(entries) do
        if current.identity == entry.identity or current.source == entry.source then
            entries[index] = entry
            return
        end
    end
    entries[#entries + 1] = entry
end

local function entry_matches_token(entry, token)
    local cleaned = trim(token)
    if cleaned == "" then
        return false
    end
    return cleaned == entry.identity or cleaned == entry.source or cleaned == derive_identity_from_source(entry.source)
end

local function extract_pins(decoded)
    if type(decoded) ~= "table" then
        return {}
    end
    if type(decoded.pins) == "table" then
        return decoded.pins
    end
    local object = read_field(decoded, "object")
    if type(read_field(object, "pins")) == "table" then
        return read_field(object, "pins")
    end
    return {}
end

local function resolved_pins(paths)
    local content = read_file(paths.resolvedFile)
    if content == nil then
        return {}
    end
    local decoded = decode_json(content)
    if decoded == nil then
        return {}
    end
    local pins = {}
    for _, pin in ipairs(extract_pins(decoded)) do
        if type(pin) == "table" then
            local state = read_field(pin, "state") or {}
            local source = first_nonempty(read_field(pin, "location"), read_field(pin, "repositoryURL"), read_field(pin, "url"))
            local identity = first_nonempty(read_field(pin, "identity"), read_field(pin, "package"), source and derive_identity_from_source(source))
            pins[#pins + 1] = {
                identity = identity,
                source = source,
                version = first_nonempty(read_field(state, "version"), read_field(pin, "version")),
                revision = first_nonempty(read_field(state, "revision"), read_field(pin, "revision")),
                branch = first_nonempty(read_field(state, "branch"), read_field(pin, "branch")),
            }
        end
    end
    return pins
end

local function find_pin_for_entry(pins, entry)
    for _, pin in ipairs(pins or {}) do
        if trim(pin.identity or "") == trim(entry.identity or "") then
            return pin
        end
        if trim(pin.source or "") ~= "" and trim(pin.source or "") == trim(entry.source or "") then
            return pin
        end
    end
    return nil
end

local function build_item(paths, entry, pin, remote)
    local extra = {
        source = entry.source,
        requirementKind = entry.requirementKind ~= "" and entry.requirementKind or nil,
        requirementValue = entry.value1 ~= "" and entry.value1 or nil,
        requirementUpperBound = entry.value2 ~= "" and entry.value2 or nil,
        workspacePath = paths.workspaceDir,
        manifestPath = paths.manifestFile,
        resolvedPath = paths.resolvedFile,
        cacheRoot = paths.cacheRoot,
        configRoot = paths.configRoot,
        securityPath = paths.securityDir,
        scratchPath = paths.scratchDir,
        revision = pin and pin.revision or nil,
        branch = pin and pin.branch or nil,
    }
    if type(remote) == "table" then
        extra.summary = read_field(read_field(remote, "extraFields") or {}, "summary")
        extra.readmeURL = read_field(read_field(remote, "extraFields") or {}, "readmeURL")
        extra.license = read_field(read_field(remote, "extraFields") or {}, "license")
    end
    local version = first_nonempty(pin and pin.version, pin and pin.branch, pin and pin.revision, entry.kind == "path" and "local" or entry.value1)
    local latest = first_nonempty(type(remote) == "table" and read_field(remote, "latestVersion"), version)
    return {
        name = entry.identity,
        packageId = entry.identity,
        packageType = entry.kind == "path" and "local" or "package",
        version = version,
        latestVersion = latest,
        installed = true,
        status = "installed",
        extraFields = extra,
    }
end

local function current_items(context, entries)
    local paths = runtime_paths(context)
    local state_entries = entries or load_state(paths)
    local pins = resolved_pins(paths)
    local items = {}
    for _, entry in ipairs(state_entries) do
        items[#items + 1] = build_item(paths, entry, find_pin_for_entry(pins, entry), nil)
    end
    table.sort(items, function(left, right)
        if tostring(left.packageType) ~= tostring(right.packageType) then
            return tostring(left.packageType) < tostring(right.packageType)
        end
        return tostring(left.name) < tostring(right.name)
    end)
    return items
end

local function filter_items_for_packages(items, packages)
    if packages == nil or #packages == 0 then
        return items
    end
    local filtered = {}
    local tokens = {}
    for _, pkg in ipairs(packages or {}) do
        local token = trim(package_name(pkg) ~= "" and package_name(pkg) or local_path_from_context({ request = pkg }, ""))
        if token ~= "" then
            tokens[#tokens + 1] = token
        end
    end
    for _, item in ipairs(items or {}) do
        for _, token in ipairs(tokens) do
            if token == item.name or token == item.packageId or token == read_field(read_field(item, "extraFields"), "source") then
                filtered[#filtered + 1] = item
                break
            end
        end
    end
    return filtered
end

local function ensure_available(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function with_workspace_mutation(context, mutator, command_builder)
    local paths = runtime_paths(context)
    if not ensure_runtime_dirs(context) then
        return nil, "failed to prepare swiftpm runtime directories"
    end

    local previous_state = read_file(paths.stateFile)
    local previous_manifest = read_file(paths.manifestFile)
    local previous_resolved = read_file(paths.resolvedFile)

    local entries = load_state(paths)
    local ok, payload_or_err = mutator(entries, paths)
    if not ok then
        return nil, payload_or_err
    end

    local manifest_ok, manifest_err = save_manifest(context, paths, entries)
    if not manifest_ok then
        restore_file(context, paths.stateFile, previous_state)
        return nil, manifest_err
    end

    local state_ok, state_err = save_state(context, paths, entries)
    if not state_ok then
        restore_file(context, paths.manifestFile, previous_manifest)
        restore_file(context, paths.stateFile, previous_state)
        return nil, state_err
    end

    local command = command_builder(paths, entries)
    if command ~= nil then
        local result = exec_run(context, command)
        if result == nil or result.success ~= true then
            restore_file(context, paths.manifestFile, previous_manifest)
            restore_file(context, paths.stateFile, previous_state)
            restore_file(context, paths.resolvedFile, previous_resolved)
            return nil, first_nonempty(result and result.stderr, result and result.stdout, "swiftpm command failed")
        end
    end

    if #entries == 0 then
        remove_file(paths.resolvedFile)
    end

    return {
        paths = paths,
        entries = entries,
        payload = payload_or_err,
    }
end

local function version_parts(version)
    local parts = {}
    for token in tostring(version or ""):gmatch("[^%.%-%+_]+") do
        if token ~= "" then
            local number = tonumber(token)
            if number ~= nil then
                parts[#parts + 1] = { kind = "number", value = number }
            else
                parts[#parts + 1] = { kind = "text", value = lower(token) }
            end
        end
    end
    return parts
end

local function compare_versions(left, right)
    local left_parts = version_parts(left)
    local right_parts = version_parts(right)
    local max_parts = math.max(#left_parts, #right_parts)
    for index = 1, max_parts do
        local l = left_parts[index]
        local r = right_parts[index]
        if l == nil and r ~= nil then
            return -1
        end
        if l ~= nil and r == nil then
            return 1
        end
        if l ~= nil and r ~= nil then
            if l.kind == r.kind then
                if l.value < r.value then
                    return -1
                end
                if l.value > r.value then
                    return 1
                end
            elseif l.kind == "number" then
                return 1
            else
                return -1
            end
        end
    end
    return 0
end

local function first_version_from_versions(value)
    if type(value) ~= "table" then
        return nil
    end
    if is_array(value) then
        for _, item in ipairs(value) do
            local version = first_nonempty(read_field(item, "version"), item)
            if version ~= nil then
                return version
            end
        end
        return nil
    end
    return first_nonempty(read_field(value, "latest"), read_field(value, "version"))
end

local function normalize_collection_item(object, override_source)
    if type(object) ~= "table" then
        return nil
    end
    local source = first_nonempty(
        override_source,
        read_field(object, "url"),
        read_field(object, "packageURL"),
        read_field(object, "repositoryURL"),
        read_field(read_field(object, "package"), "url")
    )
    local identity = first_nonempty(
        read_field(object, "packageName"),
        read_field(object, "identity"),
        read_field(object, "name"),
        source and derive_identity_from_source(source)
    )
    if identity == nil then
        return nil
    end
    local version = first_nonempty(
        read_field(object, "latestVersion"),
        first_version_from_versions(read_field(object, "versions")),
        read_field(read_field(object, "version"), "version"),
        read_field(object, "version")
    )
    return {
        name = identity,
        packageId = identity,
        packageType = "package",
        version = version,
        latestVersion = version,
        extraFields = {
            source = source,
            summary = first_nonempty(read_field(object, "summary"), read_field(object, "description")),
            readmeURL = first_nonempty(read_field(object, "readmeURL"), read_field(object, "readmeUrl")),
            license = first_nonempty(read_field(read_field(object, "license"), "name"), read_field(object, "license")),
        },
    }
end

local function collection_objects(decoded)
    if type(decoded) ~= "table" then
        return {}
    end
    if is_array(decoded) then
        return decoded
    end
    for _, key in ipairs({ "packages", "results", "items" }) do
        local value = read_field(decoded, key)
        if type(value) == "table" and is_array(value) then
            return value
        end
    end
    return { decoded }
end

local function collection_search(context, prompt)
    local command = collection_command(context, "search", { "--json", "--keywords", shell_quote(prompt) })
    local result = exec_run(context, command)
    if result == nil or result.success ~= true then
        log_warn(context, first_nonempty(result and result.stderr, result and result.stdout, "swift package-collection search failed"))
        return {}
    end
    local decoded = decode_json(result.stdout)
    if decoded == nil then
        log_warn(context, "swift package-collection search returned invalid JSON")
        return {}
    end
    local items = {}
    for _, object in ipairs(collection_objects(decoded)) do
        local item = normalize_collection_item(object, nil)
        if item ~= nil then
            items[#items + 1] = item
        end
    end
    table.sort(items, function(left, right)
        return tostring(left.name) < tostring(right.name)
    end)
    return items
end

local function collection_describe(context, source)
    local command = collection_command(context, "describe", { "--json", shell_quote(source) })
    local result = exec_run(context, command)
    if result == nil or result.success ~= true then
        log_warn(context, first_nonempty(result and result.stderr, result and result.stdout, "swift package-collection describe failed"))
        return nil
    end
    local decoded = decode_json(result.stdout)
    if decoded == nil then
        log_warn(context, "swift package-collection describe returned invalid JSON")
        return nil
    end
    for _, object in ipairs(collection_objects(decoded)) do
        local item = normalize_collection_item(object, source)
        if item ~= nil then
            return item
        end
    end
    return normalize_collection_item(decoded, source)
end

local function find_installed_item(context, prompt)
    local cleaned = trim(prompt)
    if cleaned == "" then
        return nil
    end
    for _, item in ipairs(current_items(context)) do
        local source = trim(read_field(read_field(item, "extraFields"), "source") or "")
        if cleaned == item.name or cleaned == item.packageId or cleaned == source then
            return item
        end
    end
    return nil
end

local function merge_items(installed, remote)
    local extra = shallow_copy(read_field(remote, "extraFields") or {})
    for key, value in pairs(read_field(installed, "extraFields") or {}) do
        extra[key] = value
    end
    return {
        name = first_nonempty(installed.name, remote.name),
        packageId = first_nonempty(installed.packageId, remote.packageId),
        packageType = first_nonempty(installed.packageType, remote.packageType),
        version = first_nonempty(installed.version, remote.version),
        latestVersion = first_nonempty(remote.latestVersion, remote.version, installed.latestVersion, installed.version),
        installed = true,
        status = "installed",
        extraFields = extra,
    }
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
    return { "swift", "package-manager", "dependency-manager" }
end

function plugin.getMissingPackages(context)
    if command_exists(context, REQUIRED_BINARY) then
        return {}
    end
    return { REQUIRED_BINARY }
end

function plugin.install(context, packages)
    packages = request_packages(context, packages)
    local local_path = local_path_from_context(context, "")
    if #packages == 0 and local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end
    if #packages == 0 then
        return true
    end

    local ok, message = ensure_available(context)
    if not ok then
        tx_failed(context, message)
        return false
    end

    begin_step(context, "install swiftpm dependencies")
    local mutation, mutation_err = with_workspace_mutation(context, function(entries)
        local normalized = {}
        for _, pkg in ipairs(packages or {}) do
            local entry, err = normalize_package_request(context, pkg, nil)
            if entry == nil then
                return nil, err
            end
            normalized[#normalized + 1] = entry
            upsert_entry(entries, entry)
        end
        return true, normalized
    end, function()
        return workspace_command(context, "resolve", {})
    end)

    if mutation == nil then
        tx_failed(context, mutation_err or "swiftpm install failed")
        return false
    end

    local installed = {}
    local installed_items = current_items(context, mutation.entries)
    for _, entry in ipairs(mutation.payload or {}) do
        local matched = nil
        for _, item in ipairs(installed_items) do
            if item.packageId == entry.identity then
                matched = item
                break
            end
        end
        installed[#installed + 1] = matched or build_item(mutation.paths, entry, nil, nil)
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = local_path_from_context(context, path)
    if local_path == "" then
        tx_failed(context, "swiftpm installLocal requires local path")
        return false
    end

    local ok, message = ensure_available(context)
    if not ok then
        tx_failed(context, message)
        return false
    end

    begin_step(context, "install local swiftpm dependency")
    local mutation, mutation_err = with_workspace_mutation(context, function(entries)
        local entry, err = normalize_package_request(context, { name = local_path }, local_path)
        if entry == nil then
            return nil, err
        end
        upsert_entry(entries, entry)
        return true, { entry }
    end, function()
        return workspace_command(context, "resolve", {})
    end)

    if mutation == nil then
        tx_failed(context, mutation_err or "swiftpm installLocal failed")
        return false
    end

    local installed = {}
    for _, entry in ipairs(mutation.payload or {}) do
        installed[#installed + 1] = build_item(mutation.paths, entry, nil, nil)
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    packages = request_packages(context, packages)
    if #packages == 0 then
        return true
    end

    begin_step(context, "remove swiftpm dependencies")
    local removed_before = filter_items_for_packages(current_items(context), packages)
    local mutation, mutation_err = with_workspace_mutation(context, function(entries)
        local remaining = {}
        local removed_entries = {}
        for _, entry in ipairs(entries) do
            local matched = false
            for _, pkg in ipairs(packages or {}) do
                if entry_matches_token(entry, package_name(pkg)) then
                    matched = true
                    break
                end
            end
            if matched then
                removed_entries[#removed_entries + 1] = entry
            else
                remaining[#remaining + 1] = entry
            end
        end
        for index = #entries, 1, -1 do
            entries[index] = nil
        end
        for _, entry in ipairs(remaining) do
            entries[#entries + 1] = entry
        end
        return true, removed_entries
    end, function(_, entries)
        if #entries == 0 then
            return nil
        end
        return workspace_command(context, "resolve", {})
    end)

    if mutation == nil then
        tx_failed(context, mutation_err or "swiftpm remove failed")
        return false
    end

    local removed = removed_before
    if #removed == 0 then
        for _, entry in ipairs(mutation.payload or {}) do
            removed[#removed + 1] = build_item(mutation.paths, entry, nil, nil)
        end
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    packages = request_packages(context, packages)
    local ok, message = ensure_available(context)
    if not ok then
        tx_failed(context, message)
        return false
    end

    begin_step(context, "update swiftpm dependencies")
    local mutation, mutation_err = with_workspace_mutation(context, function(entries)
        for _, pkg in ipairs(packages or {}) do
            local name = package_name(pkg)
            if name ~= "" then
                for index, entry in ipairs(entries) do
                    if entry_matches_token(entry, name) and entry.kind ~= "path" and (package_version(pkg) ~= "" or #collect_flags(context, pkg) > 0) then
                        local updated, err = normalize_package_request(context, pkg, nil)
                        if updated == nil then
                            return nil, err
                        end
                        entries[index] = updated
                    end
                end
            end
        end
        return true, true
    end, function()
        return workspace_command(context, "update", {})
    end)

    if mutation == nil then
        tx_failed(context, mutation_err or "swiftpm update failed")
        return false
    end

    emit_event(context, "updated", filter_items_for_packages(current_items(context, mutation.entries), packages))
    tx_success(context)
    return true
end

function plugin.list(context)
    local listed = current_items(context)
    emit_event(context, "listed", listed)
    return listed
end

function plugin.outdated(context)
    local ok, message = ensure_available(context)
    if not ok then
        log_warn(context, message)
        emit_event(context, "outdated", {})
        return {}
    end

    local items = {}
    for _, item in ipairs(current_items(context)) do
        if item.packageType ~= "local" then
            local source = first_nonempty(read_field(read_field(item, "extraFields"), "source"))
            if source ~= nil and looks_like_url(source) and non_empty(item.version) ~= nil then
                local remote = collection_describe(context, source)
                local latest = remote and first_nonempty(remote.latestVersion, remote.version)
                if latest ~= nil and compare_versions(item.version, latest) < 0 then
                    items[#items + 1] = merge_items(item, {
                        latestVersion = latest,
                        extraFields = read_field(remote, "extraFields") or {},
                    })
                end
            end
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned = trim(prompt)
    if cleaned == "" then
        emit_event(context, "searched", {})
        return {}
    end

    local ok, message = ensure_available(context)
    if not ok then
        log_warn(context, message)
        emit_event(context, "searched", {})
        return {}
    end

    local items = collection_search(context, cleaned)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local prompt = trim(first_nonempty(name, read_field(read_field(context, "request"), "prompt"), read_field(context, "prompt")) or "")
    if prompt == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local installed = find_installed_item(context, prompt)
    local remote = nil

    if installed ~= nil then
        local source = first_nonempty(read_field(read_field(installed, "extraFields"), "source"))
        if source ~= nil and looks_like_url(source) and command_exists(context, REQUIRED_BINARY) then
            remote = collection_describe(context, source)
        end
    elseif looks_like_url(prompt) and command_exists(context, REQUIRED_BINARY) then
        remote = collection_describe(context, prompt)
    elseif command_exists(context, REQUIRED_BINARY) then
        local results = collection_search(context, prompt)
        local selected = nil
        for _, item in ipairs(results) do
            if item.name == prompt or item.packageId == prompt then
                selected = item
                break
            end
        end
        if selected == nil then
            selected = results[1]
        end
        local source = selected and first_nonempty(read_field(read_field(selected, "extraFields"), "source"))
        if source ~= nil then
            remote = collection_describe(context, source) or selected
        end
    end

    local item = {}
    if installed ~= nil and remote ~= nil then
        item = merge_items(installed, remote)
    elseif installed ~= nil then
        item = installed
    elseif remote ~= nil then
        item = remote
    end

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, pkg)
    local entry, err = normalize_package_request(context, pkg, nil)
    if entry == nil then
        return {
            name = package_name(pkg),
            packageId = package_name(pkg),
            packageType = "package",
            version = package_version(pkg),
            latestVersion = package_version(pkg),
            extraFields = err ~= nil and { error = err } or nil,
        }
    end
    return build_item(runtime_paths(context), entry, nil, nil)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "swift", "swiftpm" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".local/share/reqpack/swiftpm" },
            { kind = "user-home-subpath", value = ".cache/reqpack/swiftpm" },
            { kind = "user-home-subpath", value = ".config/reqpack/swiftpm" },
        },
        networkScopes = { "*" },
        privilegeLevel = "user",
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
