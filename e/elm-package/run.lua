plugin = {}

local PLUGIN_ID = "elm-package"
local PLUGIN_NAME = "Elm Package"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "elm-package"
local LEGACY_REGISTRY_HOST = "package.elm-lang.org"
local LEGACY_REGISTRY_VERSION = "0.18"
local JSON_NULL = {}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
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
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,]+$") then
        return text
    end
    return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil and value ~= JSON_NULL then
            local cleaned = trim(value)
            if cleaned ~= "" then
                return cleaned
            end
        end
    end
    return nil
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

local function sequence_values(value)
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local items = {}
    local ok = pcall(function()
        for _, item in ipairs(value) do
            items[#items + 1] = item
        end
    end)
    if not ok then
        return {}
    end
    return items
end

local function list_flags(object)
    local items = {}
    for _, item in ipairs(sequence_values(read_field(object, "flags"))) do
        local cleaned = trim(item)
        if cleaned ~= "" then
            items[#items + 1] = cleaned
        end
    end
    return items
end

local function append_unique(list, seen, value)
    local cleaned = trim(value)
    if cleaned == "" or seen[cleaned] then
        return
    end
    seen[cleaned] = true
    list[#list + 1] = cleaned
end

local function request_object(context)
    return read_field(context, "request")
end

local function request_packages(context, fallback)
    return sequence_values(read_field(request_object(context), "packages") or read_field(context, "packages") or fallback or {})
end

local function request_prompt(context, fallback)
    return first_nonempty(fallback, read_field(request_object(context), "prompt"), read_field(context, "prompt")) or ""
end

local function request_local_path(context, fallback)
    return first_nonempty(fallback, read_field(request_object(context), "localPath"), read_field(request_object(context), "path"), read_field(context, "localPath"), read_field(context, "path"))
end

local function collect_flags(context, packages)
    local result = {}
    local seen = {}
    local function add_from(object)
        for _, flag in ipairs(list_flags(object)) do
            append_unique(result, seen, flag)
        end
    end
    add_from(context)
    add_from(request_object(context))
    for _, package in ipairs(packages or {}) do
        add_from(package)
    end
    return result
end

local function has_flag(flags, key)
    local wanted = lower(trim(key))
    for _, flag in ipairs(flags or {}) do
        if lower(trim(flag)) == wanted then
            return true
        end
    end
    return false
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

local function is_success(result)
    return type(result) == "table" and (result.success == true or result.exitCode == 0)
end

local function read_file(context, path)
    return exec_run(context, "cat " .. shell_quote(path))
end

local function write_file(context, path, content)
    local dir = parent_dir(path) or "."
    return exec_run(context, "mkdir -p " .. shell_quote(dir) .. " && printf %s " .. shell_quote(content or "") .. " > " .. shell_quote(path))
end

local function remove_path(context, path)
    return exec_run(context, "rm -rf " .. shell_quote(path))
end

local function command_exists(binary)
    return is_success(exec_run(nil, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function home_dir()
    local getenv = os ~= nil and type(os.getenv) == "function" and os.getenv or nil
    return first_nonempty(getenv and getenv("HOME") or nil, "/home/test")
end

local function project_root(flags)
    return first_nonempty(flag_value(flags, "cwd"), flag_value(flags, "project-root"), ".")
end

local function cache_root(flags)
    return first_nonempty(flag_value(flags, "cache-root"), join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID))
end

local function manifest_path(flags)
    return join_path(project_root(flags), "elm-package.json")
end

local function exact_dependencies_path(flags)
    return join_path(project_root(flags), "elm-stuff", "exact-dependencies.json")
end

local function cache_file_for_package(base, name, version)
    local safe_name = trim(name):gsub("[^A-Za-z0-9._/-]", "_"):gsub("/", "__")
    return join_path(base, safe_name .. "@" .. trim(version) .. ".json")
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
            current = peek()
        end
        if current == "0" then
            index = index + 1
        elseif current:match("%d") then
            repeat
                index = index + 1
                current = peek()
            until current == "" or not current:match("%d")
        else
            decode_error("invalid number")
        end
        current = peek()
        if current == "." then
            index = index + 1
            if not peek():match("%d") then
                decode_error("invalid number fraction")
            end
            repeat
                index = index + 1
                current = peek()
            until current == "" or not current:match("%d")
        end
        current = peek()
        if current == "e" or current == "E" then
            index = index + 1
            current = peek()
            if current == "+" or current == "-" then
                index = index + 1
            end
            if not peek():match("%d") then
                decode_error("invalid number exponent")
            end
            repeat
                index = index + 1
                current = peek()
            until current == "" or not current:match("%d")
        end
        return tonumber(text:sub(start_index, index - 1))
    end

    local function parse_array()
        index = index + 1
        skip_whitespace()
        local array = {}
        if peek() == "]" then
            index = index + 1
            return array
        end
        while true do
            array[#array + 1] = parse_value()
            skip_whitespace()
            local current = peek()
            if current == "]" then
                index = index + 1
                return array
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
        local object = {}
        if peek() == "}" then
            index = index + 1
            return object
        end
        while true do
            if peek() ~= '"' then
                decode_error("expected string key")
            end
            local key = parse_string()
            skip_whitespace()
            if peek() ~= ":" then
                decode_error("expected ':' after key")
            end
            index = index + 1
            skip_whitespace()
            object[key] = parse_value()
            skip_whitespace()
            local current = peek()
            if current == "}" then
                index = index + 1
                return object
            end
            if current ~= "," then
                decode_error("expected ',' or '}' in object")
            end
            index = index + 1
            skip_whitespace()
        end
    end

    function parse_value()
        skip_whitespace()
        local current = peek()
        if current == '"' then
            return parse_string()
        elseif current == "{" then
            return parse_object()
        elseif current == "[" then
            return parse_array()
        elseif current == "-" or current:match("%d") then
            return parse_number()
        elseif text:sub(index, index + 3) == "true" then
            index = index + 4
            return true
        elseif text:sub(index, index + 4) == "false" then
            index = index + 5
            return false
        elseif text:sub(index, index + 3) == "null" then
            index = index + 4
            return JSON_NULL
        end
        decode_error("unexpected character")
    end

    local value = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("unexpected trailing characters")
    end
    return value
end

local function decode_json(raw)
    local ok, value = pcall(decode_json_internal, raw)
    if ok then
        return value, nil
    end
    return nil, value
end

local function encode_json_string(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\b", "\\b")
        :gsub("\f", "\\f")
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
    return '"' .. text .. '"'
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
        if key <= 0 or math.floor(key) ~= key then
            return false
        end
        if key > count then
            count = key
        end
    end
    for index = 1, count do
        if value[index] == nil then
            return false
        end
    end
    return true
end

local function encode_json(value)
    local value_type = type(value)
    if value == JSON_NULL then
        return "null"
    elseif value_type == "nil" then
        return "null"
    elseif value_type == "string" then
        return encode_json_string(value)
    elseif value_type == "number" or value_type == "boolean" then
        return tostring(value)
    elseif value_type == "table" then
        if is_array(value) then
            local items = {}
            for index = 1, #value do
                items[#items + 1] = encode_json(value[index])
            end
            return "[" .. table.concat(items, ",") .. "]"
        end
        local keys = {}
        for key in pairs(value) do
            keys[#keys + 1] = key
        end
        table.sort(keys, function(left, right)
            return tostring(left) < tostring(right)
        end)
        local items = {}
        for _, key in ipairs(keys) do
            items[#items + 1] = encode_json_string(key) .. ":" .. encode_json(value[key])
        end
        return "{" .. table.concat(items, ",") .. "}"
    end
    return "null"
end

local function package_name(pkg)
    return first_nonempty(read_field(pkg, "name"), read_field(pkg, "packageName"), read_field(pkg, "packageId"))
end

local function package_version(pkg)
    return first_nonempty(read_field(pkg, "version"), read_field(pkg, "requestedVersion"))
end

local function sort_items_by_name(items)
    table.sort(items, function(left, right)
        local left_name = lower(left.name or "")
        local right_name = lower(right.name or "")
        if left_name == right_name then
            return tostring(left.version or "") < tostring(right.version or "")
        end
        return left_name < right_name
    end)
end

local function compare_version_parts(left, right)
    local left_parts = {}
    local right_parts = {}
    for part in tostring(left or ""):gmatch("[^%.]+") do
        left_parts[#left_parts + 1] = tonumber(part) or 0
    end
    for part in tostring(right or ""):gmatch("[^%.]+") do
        right_parts[#right_parts + 1] = tonumber(part) or 0
    end
    local length = #left_parts
    if #right_parts > length then
        length = #right_parts
    end
    for index = 1, length do
        local left_value = left_parts[index] or 0
        local right_value = right_parts[index] or 0
        if left_value ~= right_value then
            return left_value < right_value
        end
    end
    return false
end

local function max_version(versions)
    local best = nil
    for _, version in ipairs(versions or {}) do
        if best == nil or compare_version_parts(best, version) then
            best = version
        end
    end
    return best
end

local function build_registry_url(path)
    return "https://" .. LEGACY_REGISTRY_HOST .. path
end

local function fetch_url(context, url)
    return exec_run(context, "curl -fsSL " .. shell_quote(url))
end

local function load_cached_json(context, path)
    local result = read_file(context, path)
    if not is_success(result) then
        return nil
    end
    return decode_json(result.stdout or "")
end

local function save_cached_json(context, path, payload)
    return write_file(context, path, encode_json(payload))
end

local function registry_index_cache_path(flags)
    return join_path(cache_root(flags), "registry", "all-packages.json")
end

local function ensure_registry_index(context, flags)
    local cache_path = registry_index_cache_path(flags)
    if not has_flag(flags, "refresh") then
        local cached = load_cached_json(context, cache_path)
        if type(cached) == "table" then
            return cached
        end
    end
    local url = build_registry_url("/all-packages?elm-package-version=" .. LEGACY_REGISTRY_VERSION)
    local result = fetch_url(context, url)
    if is_success(result) then
        local decoded, err = decode_json(result.stdout or "")
        if type(decoded) == "table" then
            save_cached_json(context, cache_path, decoded)
            return decoded
        end
        log_warn(context, "failed to decode Elm registry index: " .. tostring(err or "unknown decode error"))
    else
        log_warn(context, first_nonempty(result.stderr, result.stdout, "failed to fetch Elm registry index"))
    end
    local cached = load_cached_json(context, cache_path)
    if type(cached) == "table" then
        return cached
    end
    return {}
end

local function registry_summary_by_name(context, flags)
    local index = ensure_registry_index(context, flags)
    local result = {}
    for _, item in ipairs(index or {}) do
        local name = trim(read_field(item, "name"))
        if name ~= "" then
            result[name] = item
        end
    end
    return result
end

local function fetch_package_json(context, flags, kind, name, version)
    local cache_dir = join_path(cache_root(flags), "registry", kind)
    local cache_path = cache_file_for_package(cache_dir, name, version)
    if not has_flag(flags, "refresh") then
        local cached = load_cached_json(context, cache_path)
        if type(cached) == "table" then
            return cached
        end
    end

    local encoded_name = tostring(name or ""):gsub("/", "%%2F")
    local encoded_version = tostring(version or "")
    local url = build_registry_url("/" .. kind .. "?elm-package-version=" .. LEGACY_REGISTRY_VERSION .. "&name=" .. encoded_name .. "&version=" .. encoded_version)
    local result = fetch_url(context, url)
    if is_success(result) then
        local decoded = select(1, decode_json(result.stdout or ""))
        if type(decoded) == "table" then
            save_cached_json(context, cache_path, decoded)
            return decoded
        end
    end
    local cached = load_cached_json(context, cache_path)
    if type(cached) == "table" then
        return cached
    end
    return nil
end

local function make_registry_item(summary, version, extra)
    local item = {
        name = trim(read_field(summary, "name")),
        version = version,
        summary = first_nonempty(read_field(summary, "summary"), read_field(summary, "description")),
        description = first_nonempty(read_field(summary, "summary"), read_field(summary, "description")),
        installed = false,
        status = "available",
        packageType = PLUGIN_ID,
        extraFields = {},
    }
    for key, value in pairs(extra or {}) do
        item[key] = value
    end
    if type(item.extraFields) ~= "table" then
        item.extraFields = {}
    end
    return item
end

local function enrich_with_description(context, flags, item)
    if type(item) ~= "table" or trim(item.name) == "" or trim(item.version) == "" then
        return item
    end
    local description = fetch_package_json(context, flags, "description", item.name, item.version)
    if type(description) == "table" then
        item.summary = first_nonempty(item.summary, read_field(description, "summary"))
        item.description = first_nonempty(read_field(description, "summary"), read_field(description, "description"), item.description)
        item.license = first_nonempty(read_field(description, "license"), item.license)
        item.repository = first_nonempty(read_field(description, "repository"), item.repository)
        item.homepage = first_nonempty(read_field(description, "repository"), item.homepage)
        local extra = item.extraFields or {}
        extra.elmVersion = read_field(description, "elm-version")
        extra.sourceDirectories = read_field(description, "source-directories")
        extra.exposedModules = read_field(description, "exposed-modules")
        extra.dependencies = read_field(description, "dependencies")
        item.extraFields = extra
    end
    local documentation = fetch_package_json(context, flags, "documentation", item.name, item.version)
    if type(documentation) == "table" then
        local extra = item.extraFields or {}
        local module_count = #documentation
        extra.documentationModules = module_count
        item.extraFields = extra
    end
    return item
end

local function read_json_file(context, path)
    local result = read_file(context, path)
    if not is_success(result) then
        return nil
    end
    return decode_json(result.stdout or "")
end

local function write_json_file(context, path, payload)
    return write_file(context, path, encode_json(payload))
end

local function ensure_available(context)
    if command_exists(REQUIRED_BINARY) then
        return true, nil
    end
    return false, REQUIRED_BINARY .. " binary not found"
end

local function package_error(context, message, unavailable_payload)
    tx_failed(context, message)
    emit_event(context, "failed", message)
    if unavailable_payload ~= nil then
        emit_event(context, "unavailable", unavailable_payload)
    end
    return false
end

local function ensure_manifest(context, flags)
    local path = manifest_path(flags)
    local manifest = read_json_file(context, path)
    if type(manifest) ~= "table" then
        return nil, "elm-package.json not found in project root"
    end
    return manifest, nil
end

local function dependency_map_to_items(context, flags, dependency_map, installed)
    local summary_map = registry_summary_by_name(context, flags)
    local items = {}
    for name, version in pairs(dependency_map or {}) do
        local version_text = trim(version)
        local summary = summary_map[name] or { name = name }
        items[#items + 1] = make_registry_item(summary, version_text, {
            installed = installed,
            status = installed and "installed" or "declared",
            extraFields = {
                projectRoot = project_root(flags),
                cacheRoot = cache_root(flags),
            },
        })
    end
    sort_items_by_name(items)
    return items
end

local function exact_dependencies_items(context, flags)
    local exact = read_json_file(context, exact_dependencies_path(flags))
    if type(exact) == "table" then
        return dependency_map_to_items(context, flags, exact, true)
    end
    return nil
end

local function manifest_dependency_items(context, flags)
    local manifest = read_json_file(context, manifest_path(flags))
    if type(manifest) ~= "table" then
        return {}
    end
    local dependencies = read_field(manifest, "dependencies")
    if type(dependencies) ~= "table" then
        return {}
    end
    return dependency_map_to_items(context, flags, dependencies, false)
end

plugin.fileExtensions = {}

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
    return { "Development", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    packages = packages or {}
    if #packages == 0 then
        return {}
    end
    local flags = collect_flags(nil, packages)
    local installed = exact_dependencies_items(nil, flags) or manifest_dependency_items(nil, flags)
    local installed_map = {}
    for _, item in ipairs(installed or {}) do
        installed_map[item.name] = item.version or true
    end
    local missing = {}
    for _, package in ipairs(packages) do
        local action = lower(read_field(package, "action") or "install")
        local name = package_name(package)
        local version = package_version(package)
        if action == "remove" then
            if name ~= nil and installed_map[name] ~= nil then
                missing[#missing + 1] = package
            end
        elseif action == "update" then
            missing[#missing + 1] = package
        elseif request_local_path(package) ~= nil then
            missing[#missing + 1] = package
        elseif name ~= nil and (installed_map[name] == nil or (version ~= nil and installed_map[name] ~= version)) then
            missing[#missing + 1] = package
        end
    end
    return missing
end

function plugin.install(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "elm-package-not-installed" })
    end

    packages = request_packages(context, packages)
    local local_path = request_local_path(context, packages and packages[1] and packages[1].path)
    if local_path ~= nil then
        return plugin.installLocal(context, local_path)
    end

    local flags = collect_flags(context, packages)
    local manifest, manifest_error = ensure_manifest(context, flags)
    if manifest == nil then
        return package_error(context, manifest_error, { reason = "missing-project-manifest" })
    end

    if packages == nil or #packages == 0 then
        begin_step(context, "install Elm project dependencies")
        local result = exec_run(context, "elm-package install --yes")
        if not is_success(result) then
            return package_error(context, first_nonempty(result.stderr, result.stdout, "elm-package install failed"))
        end
        emit_event(context, "installed", { projectRoot = project_root(flags), manifest = manifest_path(flags) })
        tx_success(context)
        emit_event(context, "success", result.stdout or "")
        return true
    end

    begin_step(context, "install Elm packages")
    for _, package in ipairs(packages) do
        local name = package_name(package)
        if name == nil then
            return package_error(context, "install requires package name")
        end
        local version = package_version(package)
        local command = "elm-package install --yes " .. shell_quote(name)
        if version ~= nil then
            command = command .. " " .. shell_quote(version)
        end
        local result = exec_run(context, command)
        if not is_success(result) then
            return package_error(context, first_nonempty(result.stderr, result.stdout, "elm-package install failed"))
        end
        emit_event(context, "installed", {
            name = name,
            version = version,
            projectRoot = project_root(flags),
        })
    end
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.installLocal(context, path)
    local cleaned_path = trim(path)
    return package_error(context, "installLocal is not supported for elm-package; use published registry packages", { path = cleaned_path, reason = "local-install-unsupported" })
end

function plugin.remove(context, packages)
    local flags = collect_flags(context, packages)
    local manifest, manifest_error = ensure_manifest(context, flags)
    if manifest == nil then
        return package_error(context, manifest_error, { reason = "missing-project-manifest" })
    end
    packages = request_packages(context, packages)
    if packages == nil or #packages == 0 then
        tx_success(context)
        emit_event(context, "success", "")
        return true
    end
    local dependencies = read_field(manifest, "dependencies")
    if type(dependencies) ~= "table" then
        dependencies = {}
        manifest.dependencies = dependencies
    end

    begin_step(context, "remove Elm dependencies from manifest")
    local removed = {}
    for _, package in ipairs(packages) do
        local name = package_name(package)
        if name ~= nil and dependencies[name] ~= nil then
            dependencies[name] = nil
            removed[#removed + 1] = { name = name }
        end
    end
    local write_result = write_json_file(context, manifest_path(flags), manifest)
    if not is_success(write_result) then
        return package_error(context, first_nonempty(write_result.stderr, write_result.stdout, "failed to update elm-package.json"))
    end
    remove_path(context, exact_dependencies_path(flags))
    if #removed == 1 then
        emit_event(context, "deleted", removed[1])
    else
        emit_event(context, "deleted", removed)
    end
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.update(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "elm-package-not-installed" })
    end

    packages = request_packages(context, packages)
    local flags = collect_flags(context, packages)
    local manifest, manifest_error = ensure_manifest(context, flags)
    if manifest == nil then
        return package_error(context, manifest_error, { reason = "missing-project-manifest" })
    end

    begin_step(context, "update Elm dependencies")
    if packages == nil or #packages == 0 then
        local result = exec_run(context, "elm-package install --yes")
        if not is_success(result) then
            return package_error(context, first_nonempty(result.stderr, result.stdout, "elm-package update failed"))
        end
        emit_event(context, "updated", { projectRoot = project_root(flags) })
        tx_success(context)
        emit_event(context, "success", result.stdout or "")
        return true
    end

    local updated = {}
    for _, package in ipairs(packages) do
        local name = package_name(package)
        if name == nil then
            return package_error(context, "update requires package name")
        end
        local command = "elm-package install --yes " .. shell_quote(name)
        local result = exec_run(context, command)
        if not is_success(result) then
            return package_error(context, first_nonempty(result.stderr, result.stdout, "elm-package update failed"))
        end
        updated[#updated + 1] = { name = name }
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.list(context)
    local flags = collect_flags(context, nil)
    local items = exact_dependencies_items(context, flags)
    if items == nil or #items == 0 then
        items = manifest_dependency_items(context, flags)
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local flags = collect_flags(context, nil)
    local items = plugin.list(context) or {}
    local summary_map = registry_summary_by_name(context, flags)
    local outdated = {}
    for _, item in ipairs(items) do
        local summary = summary_map[item.name]
        local latest = max_version(type(summary) == "table" and read_field(summary, "versions") or {})
        if latest ~= nil and trim(item.version) ~= "" and trim(item.version) ~= latest then
            outdated[#outdated + 1] = {
                name = item.name,
                version = item.version,
                latestVersion = latest,
                summary = item.summary,
                installed = item.installed,
                status = "outdated",
                packageType = PLUGIN_ID,
            }
        end
    end
    sort_items_by_name(outdated)
    emit_event(context, "outdated", outdated)
    return outdated
end

function plugin.search(context, prompt)
    local flags = collect_flags(context, nil)
    local query = lower(trim(request_prompt(context, prompt)))
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end
    local index = ensure_registry_index(context, flags)
    local items = {}
    for _, summary in ipairs(index or {}) do
        local name = trim(read_field(summary, "name"))
        local text = lower(name .. " " .. tostring(read_field(summary, "summary") or ""))
        if text:find(query, 1, true) ~= nil then
            local latest = max_version(read_field(summary, "versions") or {})
            items[#items + 1] = make_registry_item(summary, latest, {})
        end
    end
    sort_items_by_name(items)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local flags = collect_flags(context, nil)
    local query = trim(request_prompt(context, name))
    if query == "" then
        emit_event(context, "informed", {})
        return {}
    end
    local summary = registry_summary_by_name(context, flags)[query]
    if type(summary) ~= "table" then
        emit_event(context, "informed", {})
        return {}
    end
    local latest = max_version(read_field(summary, "versions") or {})
    local item = make_registry_item(summary, latest, {})
    enrich_with_description(context, flags, item)

    local listed = plugin.list(context)
    for _, installed in ipairs(listed or {}) do
        if installed.name == item.name then
            item.installed = true
            item.status = installed.version ~= item.version and "installed" or "installed-latest"
            item.installedVersion = installed.version
            break
        end
    end

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == nil then
        return nil
    end
    local item = plugin.info(context, name)
    if type(item) ~= "table" or next(item) == nil then
        return nil
    end
    return item
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "elm" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".elm" },
            { kind = "user-home-subpath", value = ".cache/reqpack/elm-package" },
        },
        networkScopes = {
            { host = LEGACY_REGISTRY_HOST, scheme = "https", pathPrefix = "/" },
        },
        privilegeLevel = "user",
        versionComparatorProfile = "semver",
        purlType = "elm",
    }
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

return plugin
