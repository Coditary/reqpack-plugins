plugin = {}

local PLUGIN_NAME = "Pinokio"
local PLUGIN_VERSION = "0.1.0"
local APP_PACKAGE_NAME = "app:pinokio"
local RELEASES_URL = "https://github.com/pinokiocomputer/pinokio/releases"
local RELEASES_API_URL = "https://api.github.com/repos/pinokiocomputer/pinokio/releases/latest"
local JSON_NULL = {}
local cached_json_decoder = nil

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function starts_with(value, prefix)
    local text = tostring(value or "")
    local expected = tostring(prefix or "")
    return text:sub(1, #expected) == expected
end

local function ends_with(value, suffix)
    local text = tostring(value or "")
    local expected = tostring(suffix or "")
    return expected == "" or text:sub(-#expected) == expected
end

local function strip_trailing_slashes(value)
    return tostring(value or ""):gsub("/+$", "")
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil and value ~= JSON_NULL then
            if type(value) == "string" then
                local text = trim(value)
                if text ~= "" then
                    return text
                end
            else
                return value
            end
        end
    end
    return nil
end

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
end

local function merge_extra_fields(left, right)
    local merged = shallow_copy(type(left) == "table" and left or {})
    for key, value in pairs(type(right) == "table" and right or {}) do
        merged[key] = value
    end
    return merged
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

local function read_nested_field(value, ...)
    local current = value
    for _, key in ipairs({ ... }) do
        current = read_field(current, key)
        if current == nil then
            return nil
        end
    end
    return current
end

local function path_basename(path)
    local text = strip_trailing_slashes(path)
    return text:match("([^/]+)$") or text
end

local function path_dirname(path)
    local text = strip_trailing_slashes(path)
    local dir = text:match("^(.*)/[^/]+$")
    if dir ~= nil and dir ~= "" then
        return dir
    end
    if starts_with(text, "/") then
        return "/"
    end
    return "."
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local raw = tostring(select(index, ...) or "")
        if raw ~= "" then
            if #parts == 0 then
                parts[#parts + 1] = strip_trailing_slashes(raw)
            else
                parts[#parts + 1] = strip_trailing_slashes(raw:gsub("^/+", ""))
            end
        end
    end
    return table.concat(parts, "/")
end

local function get_reqpack_path(name)
    local paths = type(reqpack) == "table" and read_field(reqpack, "paths") or nil
    if type(paths) ~= "table" then return nil end
    return first_nonempty(read_field(paths, name))
end

local function read_proc_environ_value(name)
    if os ~= nil and type(os.getenv) == "function" then
        local current = os.getenv(tostring(name or ""))
        if current ~= nil and current ~= "" then return trim(current) end
    end

    local handle = io.open("/proc/self/environ", "rb")
    if handle == nil then return nil end
    local payload = handle:read("*a")
    handle:close()
    if payload == nil or payload == "" then return nil end

    local prefix = tostring(name or "") .. "="
    for entry in tostring(payload):gmatch("[^%z]+") do
        if starts_with(entry, prefix) then return trim(entry:sub(#prefix + 1)) end
    end
    return nil
end

local function normalize_token(value)
    local text = trim(value)
    if text == "" then return "artifact" end
    text = text:gsub("[^%w._-]+", "_")
    text = text:gsub("_+", "_")
    text = text:gsub("^_+", "")
    text = text:gsub("_+$", "")
    return text ~= "" and text or "artifact"
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

local function normalize_run_result(first, second, third, fourth, fifth)
    if type(first) == "table" and first.success ~= nil then
        return first
    end
    local result = {}
    local function merge_exec_like(value)
        local probes = { "success", "ok", "stdout", "stderr", "exitCode", "exit_code", "code", "status" }
        for _, key in ipairs(probes) do
            local ok, item = pcall(function()
                return value[key]
            end)
            if ok and item ~= nil and result[key] == nil then
                result[key] = item
            end
        end
    end
    local function merge_table(value)
        for key, item in pairs(value or {}) do
            result[key] = item
        end
    end
    local function apply_scalar(value)
        local value_type = type(value)
        if value_type == "table" then
            merge_table(value)
        elseif value_type == "userdata" then
            merge_exec_like(value)
        elseif value_type == "boolean" then
            if result.success == nil then result.success = value end
        elseif value_type == "number" then
            if result.exitCode == nil then result.exitCode = value end
        elseif value_type == "string" then
            if result.stdout == nil then result.stdout = value elseif result.stderr == nil then result.stderr = value end
        end
    end
    apply_scalar(first)
    apply_scalar(second)
    apply_scalar(third)
    apply_scalar(fourth)
    apply_scalar(fifth)
    if result.exitCode == nil then result.exitCode = result.exit_code or result.code or result.status end
    if result.success == nil and result.ok ~= nil then result.success = result.ok end
    if result.success == nil and result.exitCode ~= nil then result.success = result.exitCode == 0 end
    return result
end

local function is_command_success(result)
    if type(result) ~= "table" then return false end
    if result.success or result.ok then return true end
    local exit_code = result.exitCode or result.exit_code or result.code or result.status
    return exit_code == 0
end

local function run_command(context, command)
    local first, second, third, fourth, fifth
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        first, second, third, fourth, fifth = context.exec.run(command)
        return normalize_run_result(first, second, third, fourth, fifth)
    end
    first, second, third, fourth, fifth = reqpack.exec.run(command)
    return normalize_run_result(first, second, third, fourth, fifth)
end

local function ensure_directory(context, path)
    local result = run_command(context, "mkdir -p " .. shell_quote(path))
    if is_command_success(result) then return true, nil end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to create directory: " .. tostring(path))
end

local function path_exists(context, path)
    local result = run_command(context, "test -e " .. shell_quote(path))
    return is_command_success(result)
end

local function directory_exists(context, path)
    local result = run_command(context, "test -d " .. shell_quote(path))
    return is_command_success(result)
end

local function file_exists(context, path)
    local result = run_command(context, "test -f " .. shell_quote(path))
    return is_command_success(result)
end

local function remove_path_if_exists(context, path)
    if not path_exists(context, path) then return true, nil end
    local result = run_command(context, "rm -rf " .. shell_quote(path))
    if is_command_success(result) then return true, nil end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to remove path: " .. tostring(path))
end

local function copy_path(context, source_path, target_path, source_kind)
    local parent = path_dirname(target_path)
    local ok, err = ensure_directory(context, parent)
    if not ok then return nil, err end
    local command = source_kind == "directory"
        and ("cp -R " .. shell_quote(source_path) .. " " .. shell_quote(target_path))
        or ("cp " .. shell_quote(source_path) .. " " .. shell_quote(target_path))
    local result = run_command(context, command)
    if is_command_success(result) then return true, nil end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to copy path")
end

local function read_text_file(path)
    local handle = io.open(path, "rb")
    if handle == nil then return nil end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_text_file(context, path, content)
    local parent = path_dirname(path)
    if parent ~= nil and trim(parent) ~= "" then
        local ok, err = ensure_directory(context, parent)
        if not ok then return nil, err end
    end
    local handle = io.open(path, "wb")
    if handle == nil then return nil, "failed to open file for write: " .. tostring(path) end
    local ok, err = handle:write(content)
    handle:close()
    if not ok then return nil, err end
    return true, nil
end

local function codepoint_to_utf8(codepoint)
    if codepoint <= 0x7F then
        return string.char(codepoint)
    elseif codepoint <= 0x7FF then
        return string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + (codepoint % 0x40))
    elseif codepoint <= 0xFFFF then
        return string.char(0xE0 + math.floor(codepoint / 0x1000), 0x80 + (math.floor(codepoint / 0x40) % 0x40), 0x80 + (codepoint % 0x40))
    end
    return string.char(0xF0 + math.floor(codepoint / 0x40000), 0x80 + (math.floor(codepoint / 0x1000) % 0x40), 0x80 + (math.floor(codepoint / 0x40) % 0x40), 0x80 + (codepoint % 0x40))
end

local function normalize_json_tree(value, null_sentinel, seen)
    if value == nil then return nil end
    if null_sentinel ~= nil and value == null_sentinel then return JSON_NULL end
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] ~= nil then return seen[value] end
    local normalized = {}
    seen[value] = normalized
    for key, item in pairs(value) do normalized[key] = normalize_json_tree(item, null_sentinel, seen) end
    return normalized
end

local function decode_json_internal(raw)
    local text = tostring(raw or "")
    local length = #text
    local index = 1
    local function decode_error(message) error(message .. " at byte " .. tostring(index), 0) end
    local function peek() return text:sub(index, index) end
    local function skip_whitespace()
        while index <= length do
            local byte = text:byte(index)
            if byte == 32 or byte == 9 or byte == 10 or byte == 13 then index = index + 1 else break end
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
            elseif current == "\\" then
                parts[#parts + 1] = text:sub(segment_start, index - 1)
                index = index + 1
                if index > length then decode_error("unterminated escape sequence") end
                local escape = text:sub(index, index)
                if escape == '"' or escape == "\\" or escape == "/" then parts[#parts + 1] = escape index = index + 1
                elseif escape == "b" then parts[#parts + 1] = "\b" index = index + 1
                elseif escape == "f" then parts[#parts + 1] = "\f" index = index + 1
                elseif escape == "n" then parts[#parts + 1] = "\n" index = index + 1
                elseif escape == "r" then parts[#parts + 1] = "\r" index = index + 1
                elseif escape == "t" then parts[#parts + 1] = "\t" index = index + 1
                elseif escape == "u" then
                    local hex = text:sub(index + 1, index + 4)
                    if #hex ~= 4 or hex:match("^[0-9a-fA-F]+$") == nil then decode_error("invalid unicode escape") end
                    parts[#parts + 1] = codepoint_to_utf8(tonumber(hex, 16))
                    index = index + 5
                else decode_error("unsupported escape sequence") end
                segment_start = index
            else
                local byte = text:byte(index)
                if byte ~= nil and byte < 32 then decode_error("control character in string") end
                index = index + 1
            end
        end
        decode_error("unterminated string")
    end
    local function parse_number()
        local start_index = index
        if peek() == "-" then index = index + 1 end
        if peek() == "0" then index = index + 1 else
            if peek():match("%d") == nil then decode_error("invalid number") end
            repeat index = index + 1 until index > length or text:sub(index, index):match("%d") == nil
        end
        if peek() == "." then
            index = index + 1
            if peek():match("%d") == nil then decode_error("invalid number") end
            repeat index = index + 1 until index > length or text:sub(index, index):match("%d") == nil
        end
        local exponent = peek()
        if exponent == "e" or exponent == "E" then
            index = index + 1
            local sign = peek()
            if sign == "+" or sign == "-" then index = index + 1 end
            if peek():match("%d") == nil then decode_error("invalid number") end
            repeat index = index + 1 until index > length or text:sub(index, index):match("%d") == nil
        end
        local number = tonumber(text:sub(start_index, index - 1))
        if number == nil then decode_error("invalid number") end
        return number
    end
    local function parse_array()
        index = index + 1
        skip_whitespace()
        local array = {}
        if peek() == "]" then index = index + 1 return array end
        while true do
            array[#array + 1] = parse_value()
            skip_whitespace()
            local current = peek()
            if current == "]" then index = index + 1 return array end
            if current ~= "," then decode_error("expected ',' or ']' in array") end
            index = index + 1
            skip_whitespace()
        end
    end
    local function parse_object()
        index = index + 1
        skip_whitespace()
        local object = {}
        if peek() == "}" then index = index + 1 return object end
        while true do
            if peek() ~= '"' then decode_error("expected string key") end
            local key = parse_string()
            skip_whitespace()
            if peek() ~= ":" then decode_error("expected ':' after object key") end
            index = index + 1
            skip_whitespace()
            object[key] = parse_value()
            skip_whitespace()
            local current = peek()
            if current == "}" then index = index + 1 return object end
            if current ~= "," then decode_error("expected ',' or '}' in object") end
            index = index + 1
            skip_whitespace()
        end
    end
    parse_value = function()
        skip_whitespace()
        local current = peek()
        if current == '"' then return parse_string()
        elseif current == "{" then return parse_object()
        elseif current == "[" then return parse_array()
        elseif current == "-" or (current ~= "" and current:match("%d") ~= nil) then return parse_number()
        elseif text:sub(index, index + 3) == "true" then index = index + 4 return true
        elseif text:sub(index, index + 4) == "false" then index = index + 5 return false
        elseif text:sub(index, index + 3) == "null" then index = index + 4 return JSON_NULL end
        decode_error("unexpected token")
    end
    local value = parse_value()
    skip_whitespace()
    if index <= length then decode_error("trailing content") end
    return value
end

local function load_json_decoder()
    if cached_json_decoder ~= nil then return cached_json_decoder end
    local candidates = {
        function()
            local ok, module = pcall(require, "cjson.safe")
            if ok and module ~= nil and type(module.decode) == "function" then
                return function(raw)
                    local value, err = module.decode(raw)
                    if err ~= nil then error(err, 0) end
                    return normalize_json_tree(value, module.null)
                end
            end
        end,
        function()
            local ok, module = pcall(require, "cjson")
            if ok and module ~= nil and type(module.decode) == "function" then
                return function(raw) return normalize_json_tree(module.decode(raw), module.null) end
            end
        end,
        function()
            local ok, module = pcall(require, "dkjson")
            if ok and module ~= nil and type(module.decode) == "function" then
                return function(raw)
                    local value, _, err = module.decode(raw, 1, nil)
                    if err ~= nil then error(err, 0) end
                    return normalize_json_tree(value, module.null)
                end
            end
        end,
    }
    for _, candidate in ipairs(candidates) do
        local ok, decoder = pcall(candidate)
        if ok and type(decoder) == "function" then cached_json_decoder = decoder return cached_json_decoder end
    end
    cached_json_decoder = decode_json_internal
    return cached_json_decoder
end

local function decode_json(raw)
    local decoder = load_json_decoder()
    local ok, value = pcall(decoder, raw)
    if not ok then return nil, tostring(value) end
    return value, nil
end

local function encode_json_string(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\")
    text = text:gsub('"', '\\"')
    text = text:gsub("\b", "\\b")
    text = text:gsub("\f", "\\f")
    text = text:gsub("\n", "\\n")
    text = text:gsub("\r", "\\r")
    text = text:gsub("\t", "\\t")
    return '"' .. text .. '"'
end

local function is_array_table(value)
    if type(value) ~= "table" then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key <= 0 or key % 1 ~= 0 then return false end
        if key > count then count = key end
    end
    for index = 1, count do if value[index] == nil then return false end end
    return true
end

local function encode_json(value)
    local value_type = type(value)
    if value == nil or value == JSON_NULL then return "null" end
    if value_type == "string" then return encode_json_string(value) end
    if value_type == "number" or value_type == "boolean" then return tostring(value) end
    if value_type ~= "table" then return encode_json_string(tostring(value)) end
    if is_array_table(value) then
        local parts = {}
        for _, item in ipairs(value) do parts[#parts + 1] = encode_json(item) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(left, right) return tostring(left) < tostring(right) end)
    local parts = {}
    for _, key in ipairs(keys) do parts[#parts + 1] = encode_json_string(tostring(key)) .. ":" .. encode_json(value[key]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function decode_json_file(path)
    local content = read_text_file(path)
    if content == nil then return nil, "failed to read file: " .. tostring(path) end
    return decode_json(content)
end

local function host_os_family(context)
    return lower(first_nonempty(read_nested_field(context, "host", "platform", "osFamily"), read_nested_field(reqpack, "host", "platform", "osFamily"), "unknown"))
end

local function host_architecture(context)
    return lower(first_nonempty(read_nested_field(context, "host", "cpu", "arch"), read_nested_field(reqpack, "host", "cpu", "arch"), "unknown"))
end

local function aicache_root()
    local data_root = get_reqpack_path("dataRoot")
    if data_root ~= nil then return join_path(data_root, "aicache") end

    local xdg_data_home = read_proc_environ_value("XDG_DATA_HOME")
    if xdg_data_home ~= nil and xdg_data_home ~= "" then return join_path(xdg_data_home, "aicache") end

    local home = read_proc_environ_value("HOME")
    if home ~= nil and home ~= "" then return join_path(home, ".local", "share", "aicache") end
    return nil
end

local function pinokio_home()
    local home = os.getenv("HOME")
    if home == nil or trim(home) == "" then return nil end
    return join_path(home, "pinokio")
end

local function pinokio_api_root()
    local home = pinokio_home()
    return home ~= nil and join_path(home, "api") or nil
end

local function pinokio_reqpack_root()
    local home = pinokio_home()
    return home ~= nil and join_path(home, "reqpack") or nil
end

local function pinokio_app_root()
    local home = pinokio_home()
    return home ~= nil and join_path(home, "app") or nil
end

local function pinokio_drive_root()
    local home = pinokio_home()
    return home ~= nil and join_path(home, "drive") or nil
end

local function pinokio_artifact_root()
    local drive = pinokio_drive_root()
    return drive ~= nil and join_path(drive, "reqpack", "artifacts") or nil
end

local function app_install_path(context)
    local root = pinokio_app_root()
    if root == nil then return nil end
    if host_os_family(context) == "macos" then return join_path(root, "Pinokio.app") end
    return join_path(root, "Pinokio.AppImage")
end

local function app_metadata_path()
    local root = pinokio_reqpack_root()
    return root ~= nil and join_path(root, "app.json") or nil
end

local function artifacts_metadata_path()
    local root = pinokio_reqpack_root()
    return root ~= nil and join_path(root, "artifacts.json") or nil
end

local function ensure_pinokio_roots(context)
    local home = pinokio_home()
    local api = pinokio_api_root()
    local reqpack_root = pinokio_reqpack_root()
    local app_root = pinokio_app_root()
    local drive_root = pinokio_drive_root()
    local artifact_root = pinokio_artifact_root()
    local install = app_install_path(context)
    local metadata = app_metadata_path()
    local artifacts_metadata = artifacts_metadata_path()
    if home == nil or api == nil or reqpack_root == nil or app_root == nil or drive_root == nil or artifact_root == nil or install == nil or metadata == nil or artifacts_metadata == nil then
        return nil, "pinokio home unavailable"
    end
    for _, path in ipairs({ home, api, reqpack_root, app_root, drive_root, artifact_root }) do
        local ok, err = ensure_directory(context, path)
        if not ok then return nil, err end
    end
    return {
        home = home,
        api = api,
        reqpack = reqpack_root,
        appRoot = app_root,
        drive = drive_root,
        artifacts = artifact_root,
        install = install,
        metadata = metadata,
        artifactsMetadata = artifacts_metadata,
    }, nil
end

local function load_app_metadata()
    local path = app_metadata_path()
    if path == nil or read_text_file(path) == nil then return nil, nil end
    return decode_json_file(path)
end

local function save_app_metadata(context, metadata)
    local path = app_metadata_path()
    local root = pinokio_reqpack_root()
    if path == nil or root == nil then return nil, "pinokio app metadata path unavailable" end
    local ok, err = ensure_directory(context, root)
    if not ok then return nil, err end
    return write_text_file(context, path, encode_json(metadata))
end

local function empty_artifacts_payload()
    return { artifacts = {} }
end

local function load_artifacts_payload()
    local path = artifacts_metadata_path()
    if path == nil or read_text_file(path) == nil then return empty_artifacts_payload(), nil end
    local payload, err = decode_json_file(path)
    if payload == nil then return nil, err end
    if type(payload) ~= "table" or type(payload.artifacts) ~= "table" then return empty_artifacts_payload(), nil end
    return payload, nil
end

local function save_artifacts_payload(context, payload)
    local path = artifacts_metadata_path()
    local root = pinokio_reqpack_root()
    if path == nil or root == nil then return nil, "pinokio artifacts metadata path unavailable" end
    local ok, err = ensure_directory(context, root)
    if not ok then return nil, err end
    return write_text_file(context, path, encode_json(payload))
end

local function current_timestamp_utc(context)
    local result = run_command(context, "date -u +%Y-%m-%dT%H:%M:%SZ")
    if result == nil or not is_command_success(result) then return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to capture timestamp") end
    return trim(result.stdout), nil
end

local function package_name(package)
    local name = read_field(package, "name")
    return trim(name ~= nil and name or package)
end

local function is_app_package_name(name)
    return lower(trim(name)) == APP_PACKAGE_NAME
end

local function is_artifact_package_name(name)
    return starts_with(lower(trim(name)), "artifact:")
end

local function normalize_release_version(version)
    local text = trim(version)
    if text == "" then return nil end
    return starts_with(lower(text), "v") and text:sub(2) or text
end

local function read_release_tag_from_json(text)
    local decoded, err = decode_json(text)
    if decoded == nil then return nil, err end
    return first_nonempty(read_field(decoded, "tag_name")), nil
end

local function pinokio_asset_name_for_version(context, version)
    local normalized = normalize_release_version(version)
    if normalized == nil then return nil, "pinokio version missing" end
    local os_family = host_os_family(context)
    local arch = host_architecture(context)
    if os_family == "linux" then
        if arch == "arm64" or arch == "aarch64" then return "Pinokio-" .. normalized .. "-arm64.AppImage", nil end
        return "Pinokio-" .. normalized .. ".AppImage", nil
    elseif os_family == "macos" then
        if arch == "arm64" or arch == "aarch64" then return "Pinokio-" .. normalized .. "-arm64-mac.zip", nil end
        return "Pinokio-" .. normalized .. "-mac.zip", nil
    end
    return nil, "pinokio app unsupported on this OS"
end

local function resolve_app_download(context, package)
    local explicit_source = trim(read_field(package, "sourcePath") or "")
    local version = normalize_release_version(read_field(package, "version"))
    if version == nil then
        local temp_dir = context ~= nil and context.fs ~= nil and type(context.fs.get_tmp_dir) == "function" and context.fs.get_tmp_dir() or ""
        if trim(temp_dir) == "" then return nil, "temporary directory unavailable" end
        local latest_path = join_path(temp_dir, "pinokio-latest.json")
        if context == nil or context.net == nil or type(context.net.download) ~= "function" then return nil, "network download unavailable" end
        if not context.net.download(RELEASES_API_URL, latest_path) then return nil, "failed to resolve latest pinokio release" end
        local tag_name, tag_error = read_release_tag_from_json(read_text_file(latest_path) or "")
        if tag_name == nil then return nil, first_nonempty(tag_error, "failed to parse latest pinokio release") end
        version = normalize_release_version(tag_name)
    end
    local asset_name, asset_error = pinokio_asset_name_for_version(context, version)
    if asset_name == nil then return nil, asset_error end
    local url = explicit_source ~= "" and explicit_source or (RELEASES_URL .. "/download/v" .. version .. "/" .. asset_name)
    return { version = version, assetName = asset_name, assetUrl = url }, nil
end

local function detect_downloaded_app_root(context, path)
    if directory_exists(context, join_path(path, "Pinokio.app")) then return join_path(path, "Pinokio.app"), nil end
    if file_exists(context, join_path(path, "Pinokio.AppImage")) then return join_path(path, "Pinokio.AppImage"), nil end
    if file_exists(context, path) or directory_exists(context, path) then return path, nil end
    local result = run_command(context, "find " .. shell_quote(path) .. " -mindepth 1 -maxdepth 2 | LC_ALL=C sort")
    if result == nil or not is_command_success(result) then return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to inspect downloaded pinokio tree") end
    for line in tostring(result.stdout or ""):gmatch("[^\r\n]+") do
        local candidate = trim(line)
        if ends_with(candidate, ".app") and directory_exists(context, candidate) then return candidate, nil end
        if ends_with(candidate, ".AppImage") and file_exists(context, candidate) then return candidate, nil end
    end
    return nil, "failed to detect pinokio app root in downloaded asset"
end

local function static_app_search_item(version)
    return {
        name = APP_PACKAGE_NAME,
        packageId = APP_PACKAGE_NAME,
        version = version,
        latestVersion = version,
        summary = "Pinokio desktop app",
        description = "Pinokio desktop app",
        homepage = RELEASES_URL,
        sourceUrl = RELEASES_URL,
        packageType = "app",
        type = "package",
    }
end

local function app_item_from_metadata(metadata)
    local item = static_app_search_item(first_nonempty(read_field(metadata, "version")))
    item.extraFields = {
        installRoot = read_field(metadata, "install_root"),
        assetName = read_field(metadata, "asset_name"),
        assetUrl = read_field(metadata, "asset_url"),
        installedAt = read_field(metadata, "installed_at"),
    }
    return item
end

local function make_artifact_package_id(artifact_id)
    return "artifact:" .. tostring(artifact_id or "")
end

local function artifact_target_name(artifact_id)
    return normalize_token(artifact_id)
end

local function parse_artifact_package(name)
    local text = trim(name)
    if not is_artifact_package_name(text) then return nil, "pinokio shared artifact package must use artifact:<artifact-id>" end
    local artifact_id = trim(text:sub(#"artifact:" + 1))
    if artifact_id == "" then return nil, "pinokio shared artifact package missing artifact id" end
    local target_name = artifact_target_name(artifact_id)
    return {
        packageId = make_artifact_package_id(artifact_id),
        artifactId = artifact_id,
        targetName = target_name,
        targetPath = join_path(pinokio_artifact_root() or "", target_name),
    }, nil
end

local function parse_script_package(name)
    local text = trim(name)
    if not starts_with(lower(text), "script:") then return nil, "pinokio script package must use script:<git-url-or-owner-repo>" end
    local raw = text:sub(#"script:" + 1)
    if trim(raw) == "" then return nil, "pinokio script package missing repository spec" end
    local remote_url
    local canonical_spec
    if starts_with(lower(raw), "https://") then
        remote_url = raw
        canonical_spec = raw
    elseif raw:match("^[A-Za-z0-9_.%-]+/[A-Za-z0-9_.%-]+$") then
        remote_url = "https://github.com/" .. raw .. ".git"
        canonical_spec = raw
    else
        return nil, "pinokio script package must be owner/repo or https git URL"
    end
    local target_name = path_basename(raw)
    return {
        packageId = "script:" .. canonical_spec,
        remoteUrl = remote_url,
        localPath = join_path(pinokio_api_root() or "", target_name),
        targetName = target_name,
    }, nil
end

local function find_artifact_record_by_package_id(payload, package_id)
    for index, artifact in ipairs(type(payload) == "table" and payload.artifacts or {}) do
        if trim(read_field(artifact, "package_id") or "") == trim(package_id) then return artifact, index end
    end
    return nil, nil
end

local function find_artifact_record_by_target_name(payload, target_name)
    for index, artifact in ipairs(type(payload) == "table" and payload.artifacts or {}) do
        if trim(read_field(artifact, "target_name") or "") == trim(target_name) then return artifact, index end
    end
    return nil, nil
end

local function digest_hex(digest)
    local text = lower(trim(digest or ""))
    local hex = text:match("^sha256:(%x+)$")
    if hex ~= nil then return lower(hex) end
    if text:match("^%x+$") ~= nil then return lower(text) end
    return nil
end

local function read_aicache_artifact(context, artifact_id)
    local root = aicache_root()
    if root == nil or root == "" then return nil, "pinokio aicache root unavailable" end

    local artifact_path = join_path(root, "artifacts", artifact_id)
    if not path_exists(context, artifact_path) then return nil, nil end

    local manifest, manifest_error = decode_json_file(join_path(artifact_path, "manifest.json"))
    if manifest == nil then return nil, manifest_error end
    local files_payload, files_error = decode_json_file(join_path(artifact_path, "files.json"))
    if files_payload == nil then return nil, files_error end
    local files = read_field(files_payload, "files")
    if type(files) ~= "table" then return nil, "invalid aicache files manifest" end

    local source_metadata = {}
    local source_path = join_path(artifact_path, "source.json")
    if file_exists(context, source_path) then
        local payload, payload_error = decode_json_file(source_path)
        if payload == nil then return nil, payload_error end
        if type(payload) == "table" then source_metadata = payload end
    end

    local source = type(read_field(manifest, "source")) == "table" and read_field(manifest, "source") or {}
    local revision = trim(first_nonempty(read_field(source, "revision"), artifact_id:match("@([^@]+)$"), read_field(manifest, "created_at")) or "")
    return {
        root = root,
        artifactId = artifact_id,
        artifactPath = artifact_path,
        manifest = manifest,
        files = files,
        source = source,
        sourceMetadata = source_metadata,
        revision = revision,
    }, nil
end

local function artifact_blob_path(layout, entry)
    local digest = digest_hex(read_field(entry, "blob_id"))
    if digest == nil then return nil, "invalid aicache blob id" end
    return join_path(layout.root, "blobs", "sha256", digest:sub(1, 2), digest), nil
end

local function export_aicache_artifact(context, layout, target_path)
    local ok, err = ensure_directory(context, target_path)
    if not ok then return nil, err end
    for _, entry in ipairs(layout.files or {}) do
        if type(entry) == "table" then
            local logical_path = trim(read_field(entry, "logical_path") or "")
            if logical_path ~= "" then
                local blob_path, blob_error = artifact_blob_path(layout, entry)
                if blob_path == nil then return nil, blob_error end
                if not path_exists(context, blob_path) then return nil, "pinokio aicache blob missing: " .. blob_path end
                local copy_ok, copy_error = copy_path(context, blob_path, join_path(target_path, logical_path), "file")
                if not copy_ok then return nil, copy_error end
            end
        end
    end
    return true, nil
end

local function artifact_item_from_record(record, layout)
    if type(record) ~= "table" then return nil end
    local artifact_id = trim(read_field(record, "artifact_id") or "")
    if artifact_id == "" then return nil end
    local source = type(layout and layout.source) == "table" and layout.source or {}
    local source_metadata = type(layout and layout.sourceMetadata) == "table" and layout.sourceMetadata or {}
    local upstream = type(read_field(source_metadata, "upstream_metadata")) == "table" and read_field(source_metadata, "upstream_metadata") or {}
    local version = trim(first_nonempty(read_field(record, "installed_revision"), read_field(source, "revision"), layout and layout.revision, read_field(record, "installed_at")) or "")
    local installed = trim(read_field(record, "target_path") or "") ~= ""
    local summary = installed and "Shared AICache artifact projected into Pinokio home" or "Shared AICache artifact available for Pinokio"
    return {
        name = make_artifact_package_id(artifact_id),
        packageId = make_artifact_package_id(artifact_id),
        version = version,
        latestVersion = version,
        summary = summary,
        description = summary,
        homepage = first_nonempty(read_field(upstream, "homepage"), read_field(upstream, "source_url")),
        sourceUrl = first_nonempty(read_field(upstream, "source_url"), read_field(upstream, "homepage")),
        packageType = "artifact",
        type = "package",
        extraFields = {
            runtime = "pinokio",
            artifactId = artifact_id,
            artifactPath = first_nonempty(read_field(record, "artifact_path"), layout and layout.artifactPath),
            artifactKind = layout and read_field(layout.manifest, "kind") or nil,
            projectionMode = first_nonempty(read_field(record, "projection_mode"), "workspace-export"),
            targetName = read_field(record, "target_name"),
            targetPath = read_field(record, "target_path"),
            installedAt = read_field(record, "installed_at"),
        },
    }
end

local function detect_script_revision(context, path)
    local result = run_command(context, "git -C " .. shell_quote(path) .. " rev-parse --short HEAD")
    if result == nil or not is_command_success(result) then return nil end
    return trim(result.stdout)
end

local function detect_script_remote_url(context, path)
    local result = run_command(context, "git -C " .. shell_quote(path) .. " remote get-url origin")
    if result == nil or not is_command_success(result) then return nil end
    return trim(result.stdout)
end

local function script_record_from_spec(context, spec)
    return {
        packageId = spec.packageId,
        remoteUrl = detect_script_remote_url(context, spec.localPath) or spec.remoteUrl,
        localPath = spec.localPath,
        revision = detect_script_revision(context, spec.localPath),
    }
end

local function script_item_from_record(record)
    if type(record) ~= "table" then return nil end
    local package_id = trim(read_field(record, "packageId") or "")
    if package_id == "" then return nil end
    return {
        name = package_id,
        packageId = package_id,
        version = first_nonempty(read_field(record, "revision")),
        latestVersion = first_nonempty(read_field(record, "revision")),
        summary = "Pinokio script repository",
        description = "Pinokio script repository",
        sourceUrl = read_field(record, "remoteUrl"),
        packageType = "script",
        type = "package",
        extraFields = {
            remoteUrl = read_field(record, "remoteUrl"),
            localPath = read_field(record, "localPath"),
            revision = read_field(record, "revision"),
        },
    }
end

local function install_app(context, package)
    local roots, root_error = ensure_pinokio_roots(context)
    if roots == nil then return nil, root_error end
    local download, download_error = resolve_app_download(context, package)
    if download == nil then return nil, download_error end
    local temp_dir = context ~= nil and context.fs ~= nil and type(context.fs.get_tmp_dir) == "function" and context.fs.get_tmp_dir() or ""
    if trim(temp_dir) == "" then return nil, "temporary directory unavailable" end
    local download_root = join_path(temp_dir, "pinokio-asset")
    local ok = context ~= nil and context.net ~= nil and type(context.net.download) == "function" and context.net.download(download.assetUrl, download_root)
    if not ok then return nil, "failed to download pinokio asset" end
    local actual_root, detect_error = detect_downloaded_app_root(context, download_root)
    if actual_root == nil then return nil, detect_error end
    local remove_ok, remove_error = remove_path_if_exists(context, roots.install)
    if not remove_ok then return nil, remove_error end
    local source_kind = directory_exists(context, actual_root) and "directory" or "file"
    local copy_ok, copy_error = copy_path(context, actual_root, roots.install, source_kind)
    if not copy_ok then return nil, copy_error end
    if source_kind == "file" then
        local chmod_result = run_command(context, "chmod +x " .. shell_quote(roots.install))
        if not is_command_success(chmod_result) then
            return nil, first_nonempty(chmod_result and chmod_result.stderr, chmod_result and chmod_result.stdout, "failed to chmod Pinokio app")
        end
    end
    local installed_at, time_error = current_timestamp_utc(context)
    if installed_at == nil then return nil, time_error end
    local metadata = {
        version = download.version,
        asset_name = download.assetName,
        asset_url = download.assetUrl,
        install_root = roots.install,
        installed_at = installed_at,
    }
    local save_ok, save_error = save_app_metadata(context, metadata)
    if not save_ok then return nil, save_error end
    return app_item_from_metadata(metadata), nil
end

local function install_script_repo(context, package)
    local roots, root_error = ensure_pinokio_roots(context)
    if roots == nil then return nil, root_error end
    local spec, spec_error = parse_script_package(package_name(package))
    if spec == nil then return nil, spec_error end
    if path_exists(context, spec.localPath) then return script_item_from_record(script_record_from_spec(context, spec)), nil end
    local result = run_command(context, "git clone " .. shell_quote(spec.remoteUrl) .. " " .. shell_quote(spec.localPath))
    if result == nil or not is_command_success(result) then return nil, first_nonempty(result and result.stderr, result and result.stdout, "pinokio script clone failed") end
    return script_item_from_record(script_record_from_spec(context, spec)), nil
end

local function install_artifact_projection(context, package)
    local roots, root_error = ensure_pinokio_roots(context)
    if roots == nil then return nil, root_error end
    local spec, spec_error = parse_artifact_package(package_name(package))
    if spec == nil then return nil, spec_error end

    local layout, layout_error = read_aicache_artifact(context, spec.artifactId)
    if layout == nil then return nil, first_nonempty(layout_error, "pinokio shared artifact not found: " .. spec.artifactId) end

    local payload, payload_error = load_artifacts_payload()
    if payload == nil then return nil, payload_error end
    local existing_target = find_artifact_record_by_target_name(payload, spec.targetName)
    if existing_target ~= nil and trim(read_field(existing_target, "package_id") or "") ~= spec.packageId then
        return nil, "pinokio artifact target already managed by different package: " .. spec.targetName
    end
    local existing_record, existing_index = find_artifact_record_by_package_id(payload, spec.packageId)
    if existing_target == nil and path_exists(context, spec.targetPath) then
        return nil, "pinokio artifact target already exists and is not managed by reqpack: " .. spec.targetName
    end

    local remove_ok, remove_error = remove_path_if_exists(context, spec.targetPath)
    if not remove_ok then return nil, remove_error end
    local export_ok, export_error = export_aicache_artifact(context, layout, spec.targetPath)
    if not export_ok then return nil, export_error end

    local installed_at, time_error = current_timestamp_utc(context)
    if installed_at == nil then return nil, time_error end
    local record = {
        package_id = spec.packageId,
        artifact_id = spec.artifactId,
        artifact_path = layout.artifactPath,
        target_name = spec.targetName,
        target_path = spec.targetPath,
        installed_at = installed_at,
        installed_revision = layout.revision,
        projection_mode = "workspace-export",
    }
    if existing_record ~= nil and existing_index ~= nil then
        payload.artifacts[existing_index] = record
    else
        payload.artifacts[#payload.artifacts + 1] = record
    end
    local save_ok, save_error = save_artifacts_payload(context, payload)
    if not save_ok then return nil, save_error end
    return artifact_item_from_record(record, layout), nil
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
    return { "AI", "Package Manager", "Pinokio" }
end

function plugin.getMissingPackages(packages)
    local missing = {}
    local app_metadata = select(1, load_app_metadata())
    local artifact_payload = select(1, load_artifacts_payload()) or empty_artifacts_payload()
    for _, package in ipairs(packages or {}) do
        local name = package_name(package)
        if is_app_package_name(name) then
            if app_metadata == nil then missing[#missing + 1] = package end
        elseif is_artifact_package_name(name) then
            local spec = select(1, parse_artifact_package(name))
            local record = spec ~= nil and find_artifact_record_by_package_id(artifact_payload, spec.packageId) or nil
            if record == nil or not path_exists(nil, read_field(record, "target_path")) then missing[#missing + 1] = package end
        else
            local spec = select(1, parse_script_package(name))
            if spec == nil or not path_exists(nil, spec.localPath) then missing[#missing + 1] = package end
        end
    end
    return missing
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then return true end
    local installed = {}
    for _, package in ipairs(requested) do
        local name = package_name(package)
        if is_app_package_name(name) then
            begin_step(context, "install pinokio app")
            local item, err = install_app(context, package)
            if item == nil then tx_failed(context, err) return false end
            installed[#installed + 1] = item
        elseif is_artifact_package_name(name) then
            begin_step(context, "install pinokio shared artifact")
            local item, err = install_artifact_projection(context, package)
            if item == nil then tx_failed(context, err) return false end
            installed[#installed + 1] = item
        else
            begin_step(context, "install pinokio script repo")
            local item, err = install_script_repo(context, package)
            if item == nil then tx_failed(context, err) return false end
            installed[#installed + 1] = item
        end
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    tx_failed(context, "pinokio plugin does not support installLocal()")
    emit_event(context, "unavailable", { path = path, reason = "local-install-unsupported" })
    return false
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then return true end
    local removed = {}
    local artifact_payload = nil
    local artifact_dirty = false
    for _, package in ipairs(requested) do
        local name = package_name(package)
        if is_app_package_name(name) then
            begin_step(context, "remove pinokio app")
            local roots, root_error = ensure_pinokio_roots(context)
            if roots == nil then tx_failed(context, root_error) return false end
            local ok, err = remove_path_if_exists(context, roots.install)
            if not ok then tx_failed(context, err) return false end
            ok, err = remove_path_if_exists(context, roots.metadata)
            if not ok then tx_failed(context, err) return false end
            removed[#removed + 1] = static_app_search_item(nil)
        elseif is_artifact_package_name(name) then
            begin_step(context, "remove pinokio shared artifact")
            if artifact_payload == nil then
                local artifact_error
                artifact_payload, artifact_error = load_artifacts_payload()
                if artifact_payload == nil then tx_failed(context, artifact_error) return false end
            end
            local spec, spec_error = parse_artifact_package(name)
            if spec == nil then tx_failed(context, spec_error) return false end
            local record, index = find_artifact_record_by_package_id(artifact_payload, spec.packageId)
            if record ~= nil then
                local ok, err = remove_path_if_exists(context, read_field(record, "target_path"))
                if not ok then tx_failed(context, err) return false end
                table.remove(artifact_payload.artifacts, index)
                artifact_dirty = true
                removed[#removed + 1] = artifact_item_from_record(record, nil)
            end
        else
            begin_step(context, "remove pinokio script repo")
            local spec, spec_error = parse_script_package(name)
            if spec == nil then tx_failed(context, spec_error) return false end
            local ok, err = remove_path_if_exists(context, spec.localPath)
            if not ok then tx_failed(context, err) return false end
            removed[#removed + 1] = script_item_from_record(script_record_from_spec(context, spec))
        end
    end
    if artifact_dirty then
        local save_ok, save_error = save_artifacts_payload(context, artifact_payload)
        if not save_ok then tx_failed(context, save_error) return false end
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    if #requested == 0 then return true end
    local updated = {}
    for _, package in ipairs(requested) do
        local name = package_name(package)
        if is_app_package_name(name) then
            begin_step(context, "update pinokio app")
            local item, err = install_app(context, package)
            if item == nil then tx_failed(context, err) return false end
            updated[#updated + 1] = item
        elseif is_artifact_package_name(name) then
            begin_step(context, "update pinokio shared artifact")
            local item, err = install_artifact_projection(context, package)
            if item == nil then tx_failed(context, err) return false end
            updated[#updated + 1] = item
        else
            begin_step(context, "update pinokio script repo")
            local spec, spec_error = parse_script_package(name)
            if spec == nil then tx_failed(context, spec_error) return false end
            if not path_exists(context, spec.localPath) then tx_failed(context, "pinokio script repo not installed: " .. spec.localPath) return false end
            local result = run_command(context, "git -C " .. shell_quote(spec.localPath) .. " pull --ff-only")
            if result == nil or not is_command_success(result) then
                tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "pinokio script update failed"))
                return false
            end
            updated[#updated + 1] = script_item_from_record(script_record_from_spec(context, spec))
        end
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = {}
    local app_metadata = select(1, load_app_metadata())
    if app_metadata ~= nil then items[#items + 1] = app_item_from_metadata(app_metadata) end
    local api_root = pinokio_api_root()
    if api_root ~= nil and directory_exists(context, api_root) then
        local result = run_command(context, "find " .. shell_quote(api_root) .. " -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort")
        if result ~= nil and is_command_success(result) then
            for line in tostring(result.stdout or ""):gmatch("[^\r\n]+") do
                local path = trim(line)
                local remote_url = detect_script_remote_url(context, path)
                local package_id = remote_url ~= nil and (starts_with(remote_url, "https://github.com/") and ("script:" .. remote_url:gsub("^https://github.com/", ""):gsub("%.git$", "")) or ("script:" .. remote_url)) or ("script:" .. path_basename(path))
                items[#items + 1] = script_item_from_record({ packageId = package_id, remoteUrl = remote_url, localPath = path, revision = detect_script_revision(context, path) })
            end
        end
    end
    local artifact_payload = select(1, load_artifacts_payload()) or empty_artifacts_payload()
    for _, record in ipairs(artifact_payload.artifacts or {}) do
        local item = artifact_item_from_record(record, select(1, read_aicache_artifact(context, read_field(record, "artifact_id"))))
        if item ~= nil then items[#items + 1] = item end
    end
    table.sort(items, function(left, right) return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "") end)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    emit_event(context, "outdated", {})
    return {}
end

function plugin.search(context, prompt)
    local query = lower(trim(prompt))
    local results = {}
    if query == "" or query:find("pinokio", 1, true) ~= nil or query == APP_PACKAGE_NAME then results[#results + 1] = static_app_search_item(nil) end
    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local requested = trim(name)
    if requested == "" then return {} end
    if is_app_package_name(requested) then
        local metadata = select(1, load_app_metadata())
        local item = metadata ~= nil and app_item_from_metadata(metadata) or static_app_search_item(nil)
        emit_event(context, "informed", item)
        return item
    end
    if is_artifact_package_name(requested) then
        local payload = select(1, load_artifacts_payload()) or empty_artifacts_payload()
        local spec = select(1, parse_artifact_package(requested))
        local record = spec ~= nil and find_artifact_record_by_package_id(payload, spec.packageId) or nil
        if record ~= nil then
            local item = artifact_item_from_record(record, select(1, read_aicache_artifact(context, read_field(record, "artifact_id"))))
            emit_event(context, "informed", item)
            return item
        end
        if spec ~= nil then
            local layout = select(1, read_aicache_artifact(context, spec.artifactId))
            if layout ~= nil then
                local item = artifact_item_from_record({ artifact_id = spec.artifactId }, layout)
                emit_event(context, "informed", item)
                return item
            end
        end
        return {}
    end
    local spec = select(1, parse_script_package(requested))
    if spec ~= nil then
        local item = script_item_from_record(path_exists(context, spec.localPath) and script_record_from_spec(context, spec) or { packageId = spec.packageId, remoteUrl = spec.remoteUrl, localPath = spec.localPath, revision = nil })
        emit_event(context, "informed", item)
        return item
    end
    return {}
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == "" then return nil end
    if is_app_package_name(name) then return static_app_search_item(nil) end
    return plugin.info(context, name)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "pinokio" },
        writeScopes = {
            { kind = "temp" },
            { kind = "user-home-subpath", value = "pinokio" },
        },
        networkScopes = {
            { host = "github.com", scheme = "https" },
            { host = "api.github.com", scheme = "https" },
        },
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
