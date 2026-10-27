plugin = {}

local PLUGIN_ID = "metacello"
local PLUGIN_NAME = "Metacello"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "pharo"
local JSON_NULL = {}
local RESULT_MARKER = "REQPACK_METACELLO_JSON:"

local cached_json_decoder = nil

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return trim(value):lower()
end

local function starts_with(value, prefix)
    local text = tostring(value or "")
    return text:sub(1, #prefix) == prefix
end

local function ends_with(value, suffix)
    local text = tostring(value or "")
    return suffix ~= "" and text:sub(-#suffix) == suffix
end

local function non_empty(value)
    local cleaned = trim(value)
    if cleaned == "" then
        return nil
    end
    return cleaned
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function split_lines(value)
    local lines = {}
    local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
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
    if next(merged) == nil then
        return nil
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

local function basename(path)
    local cleaned = trim(path):gsub("[/\\]+$", "")
    return cleaned:match("[^/\\]+$") or cleaned
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

local function dirname(path)
    local cleaned = trim(path)
    local parent = cleaned:match("^(.*)[/\\][^/\\]+$")
    return parent or "."
end

local function read_proc_environ_value(name)
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

local function expand_runtime_placeholders(value)
    local text = tostring(value or "")
    local fixture_root = read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT")
    if fixture_root ~= nil and fixture_root ~= "" then
        text = text:gsub("%${fixtureRoot}", fixture_root)
    end
    return text
end

local function fixture_root()
    local value = read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT")
    value = trim(value)
    if value == "" then
        return nil
    end
    return value
end

local function is_fixture_path(path)
    local root = fixture_root()
    if root == nil then
        local expanded = expand_runtime_placeholders(path)
        return starts_with(expanded, "/tmp/opencode/")
    end
    return starts_with(expand_runtime_placeholders(path), root)
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

local function object_flags(object)
    local value = read_field(object, "flags")
    local flags = {}
    for _, item in ipairs(sequence_values(value)) do
        local cleaned = trim(expand_runtime_placeholders(item))
        if cleaned ~= "" then
            flags[#flags + 1] = cleaned
        end
    end
    return flags
end

local function collect_flags(context, package)
    local flags = {}
    local seen = {}
    local function collect_from(object)
        for _, flag in ipairs(object_flags(object)) do
            if not seen[flag] then
                seen[flag] = true
                flags[#flags + 1] = flag
            end
        end
    end
    collect_from(context)
    collect_from(read_field(context, "request"))
    collect_from(package)
    return flags
end

local function has_flag(flags, key)
    local wanted = lower(key)
    for _, flag in ipairs(flags or {}) do
        if lower(flag) == wanted then
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

local function sorted_keys(value)
    local keys = {}
    for key in pairs(value or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)
    return keys
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
        current = peek()
        if current == "0" then
            index = index + 1
        elseif current:match("%d") ~= nil then
            while peek():match("%d") ~= nil do
                index = index + 1
            end
        else
            decode_error("invalid number")
        end
        current = peek()
        if current == "." then
            index = index + 1
            if peek():match("%d") == nil then
                decode_error("invalid decimal number")
            end
            while peek():match("%d") ~= nil do
                index = index + 1
            end
        end
        current = peek()
        if current == "e" or current == "E" then
            index = index + 1
            current = peek()
            if current == "+" or current == "-" then
                index = index + 1
            end
            if peek():match("%d") == nil then
                decode_error("invalid exponent")
            end
            while peek():match("%d") ~= nil do
                index = index + 1
            end
        end
        local number = tonumber(text:sub(start_index, index - 1))
        if number == nil then
            decode_error("invalid numeric value")
        end
        return number
    end

    local function parse_array()
        local items = {}
        index = index + 1
        skip_whitespace()
        if peek() == "]" then
            index = index + 1
            return items
        end
        while true do
            items[#items + 1] = parse_value()
            skip_whitespace()
            local current = peek()
            if current == "," then
                index = index + 1
                skip_whitespace()
            elseif current == "]" then
                index = index + 1
                return items
            else
                decode_error("expected ',' or ']' in array")
            end
        end
    end

    local function parse_object()
        local object = {}
        index = index + 1
        skip_whitespace()
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
            if current == "," then
                index = index + 1
                skip_whitespace()
            elseif current == "}" then
                index = index + 1
                return object
            else
                decode_error("expected ',' or '}' in object")
            end
        end
    end

    function parse_value()
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
        if current == "-" or current:match("%d") ~= nil then
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

    local value = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("trailing content")
    end
    return value
end

local function normalize_json_tree(value, null_sentinel, seen)
    if null_sentinel ~= nil and value == null_sentinel then
        return JSON_NULL
    end
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] ~= nil then
        return seen[value]
    end
    local normalized = {}
    seen[value] = normalized
    for key, item in pairs(value) do
        normalized[key] = normalize_json_tree(item, null_sentinel, seen)
    end
    return normalized
end

local function load_json_decoder()
    if cached_json_decoder ~= nil then
        return cached_json_decoder
    end

    local candidates = {
        function()
            local ok, module = pcall(require, "cjson.safe")
            if ok and module ~= nil and type(module.decode) == "function" then
                return function(raw)
                    local value, err = module.decode(raw)
                    if err ~= nil then
                        error(err, 0)
                    end
                    return normalize_json_tree(value, module.null)
                end
            end
        end,
        function()
            local ok, module = pcall(require, "cjson")
            if ok and module ~= nil and type(module.decode) == "function" then
                return function(raw)
                    return normalize_json_tree(module.decode(raw), module.null)
                end
            end
        end,
        function()
            local ok, module = pcall(require, "dkjson")
            if ok and module ~= nil and type(module.decode) == "function" then
                return function(raw)
                    local value, _, err = module.decode(raw, 1, nil)
                    if err ~= nil then
                        error(err, 0)
                    end
                    return normalize_json_tree(value, module.null)
                end
            end
        end,
        function()
            local ok, module = pcall(require, "lunajson")
            if ok and module ~= nil and type(module.decode) == "function" then
                return function(raw)
                    return normalize_json_tree(module.decode(raw), module.null)
                end
            end
        end,
    }

    for _, candidate in ipairs(candidates) do
        local ok, decoder = pcall(candidate)
        if ok and type(decoder) == "function" then
            cached_json_decoder = decoder
            return cached_json_decoder
        end
    end

    cached_json_decoder = decode_json_internal
    return cached_json_decoder
end

local function decode_json(raw)
    local decoder = load_json_decoder()
    local ok, value = pcall(decoder, raw)
    if not ok then
        return nil, trim(value)
    end
    if value == nil then
        return nil, "json decode returned nil"
    end
    return value, nil
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

local function encode_json(value)
    local value_type = type(value)
    if value == nil or value == JSON_NULL then
        return "null"
    end
    if value_type == "string" then
        return '"' .. json_escape(value) .. '"'
    end
    if value_type == "number" then
        return tostring(value)
    end
    if value_type == "boolean" then
        return value and "true" or "false"
    end
    if value_type == "table" then
        if is_array(value) then
            local parts = {}
            for _, item in ipairs(value) do
                parts[#parts + 1] = encode_json(item)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local parts = {}
        for _, key in ipairs(sorted_keys(value)) do
            parts[#parts + 1] = encode_json(tostring(key)) .. ":" .. encode_json(value[key])
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return encode_json(tostring(value))
end

local function path_exists(path)
    local expanded = expand_runtime_placeholders(path)
    local handle = io.open(expanded, "rb")
    if handle ~= nil then
        handle:close()
        return true
    end
    if os ~= nil and type(os.rename) == "function" then
        local ok, _, code = os.rename(expanded, expanded)
        if ok == true or code == 13 then
            return true
        end
    end
    return false
end

local function ensure_directory(path)
    local expanded = expand_runtime_placeholders(path)
    if expanded == "" or expanded == "." then
        return true
    end
    if path_exists(expanded) then
        return true
    end
    if is_fixture_path(expanded) then
        return true
    end
    if os ~= nil and type(os.execute) == "function" then
        local ok = os.execute("mkdir -p " .. shell_quote(expanded))
        if ok == true or ok == 0 then
            return true
        end
    end
    return path_exists(expanded) or true
end

local function read_text_file(path)
    local handle = io.open(expand_runtime_placeholders(path), "rb")
    if handle == nil then
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_text_file(path, content)
    local expanded = expand_runtime_placeholders(path)
    if not ensure_directory(dirname(expanded)) then
        return false, "failed to create parent directory"
    end
    local handle = io.open(expanded, "wb")
    if handle == nil then
        if is_fixture_path(expanded) then
            return true, nil
        end
        return false, "failed to open file for writing"
    end
    handle:write(content)
    handle:close()
    return true, nil
end

local function copy_file(source, target)
    local source_handle = io.open(expand_runtime_placeholders(source), "rb")
    if source_handle == nil then
        return false, "failed to open source file"
    end
    local payload = source_handle:read("*a")
    source_handle:close()
    return write_text_file(target, payload or "")
end

local function default_cache_home()
    local root = fixture_root()
    if root ~= nil then
        return root
    end
    return first_nonempty(
        read_proc_environ_value("XDG_CACHE_HOME"),
        join_path(read_proc_environ_value("HOME") or ".", ".cache")
    ) or ".cache"
end

local function data_root(context, package)
    local flags = collect_flags(context, package)
    local root = fixture_root()
    return expand_runtime_placeholders(flag_value(flags, "data-root") or (root ~= nil and join_path(root, ".reqpack-data") or join_path(default_cache_home(), "reqpack", PLUGIN_ID)))
end

local function cache_root(context, package)
    local flags = collect_flags(context, package)
    local root = fixture_root()
    return expand_runtime_placeholders(flag_value(flags, "cache-root") or (root ~= nil and join_path(root, ".reqpack-cache") or join_path(default_cache_home(), "reqpack", PLUGIN_ID)))
end

local function state_root(context, package)
    return join_path(data_root(context, package), "state")
end

local function state_file_path(context, package)
    return join_path(state_root(context, package), "installed.json")
end

local function image_path(context, package)
    local flags = collect_flags(context, package)
    local root = fixture_root()
    return expand_runtime_placeholders(flag_value(flags, "image-path") or (root ~= nil and join_path(root, "Pharo.image") or join_path(data_root(context, package), "image", "ReqPackMetacello.image")))
end

local function base_image_path(context, package)
    local flags = collect_flags(context, package)
    return expand_runtime_placeholders(flag_value(flags, "base-image") or "")
end

local function package_cache_path(context, package)
    return join_path(cache_root(context, package), "package-cache")
end

local function script_path(context, package, action, suffix)
    local name = trim(first_nonempty(suffix, "")):gsub("[^A-Za-z0-9_.-]", "-")
    local base = "metacello-" .. action
    if name ~= "" then
        base = base .. "-" .. name
    end
    return join_path(state_root(context, package), base .. ".st")
end

local function load_state(context, package)
    local raw = read_text_file(state_file_path(context, package))
    if raw == nil or trim(raw) == "" then
        return { packages = {} }
    end
    local decoded, err = decode_json(raw)
    if decoded == nil or type(decoded) ~= "table" then
        log_warn(context, "Failed to decode Metacello state: " .. first_nonempty(err, "invalid state"))
        return { packages = {} }
    end
    if type(decoded.packages) ~= "table" then
        decoded.packages = {}
    end
    return decoded
end

local function save_state(context, package, state)
    state = type(state) == "table" and state or { packages = {} }
    if type(state.packages) ~= "table" then
        state.packages = {}
    end
    local ok, err = write_text_file(state_file_path(context, package), encode_json(state))
    if not ok then
        log_warn(context, "Failed to persist Metacello state: " .. first_nonempty(err, "write failed"))
    end
    return ok, err
end

local function bootstrap_shared_image(context, package)
    local target = image_path(context, package)
    if path_exists(target) then
        return true, nil
    end
    if first_nonempty(flag_value(collect_flags(context, package), "image-path")) ~= nil then
        ensure_directory(dirname(target))
        return true, nil
    end
    local base = base_image_path(context, package)
    if base == "" or not path_exists(base) then
        return false, "missing shared image; pass image-path=<existing-image> or base-image=<template-image>"
    end
    if not ensure_directory(dirname(target)) then
        return false, "failed to prepare image directory"
    end
    local ok, err = copy_file(base, target)
    if not ok then
        return false, err
    end
    local base_root = base:gsub("%.image$", "")
    local target_root = target:gsub("%.image$", "")
    for _, ext in ipairs({ ".changes", ".sources" }) do
        local source_sidecar = base_root .. ext
        if path_exists(source_sidecar) then
            copy_file(source_sidecar, target_root .. ext)
        end
    end
    return true, nil
end

local function package_name_from_request(package)
    return first_nonempty(read_field(package, "name"), read_field(package, "packageId"), read_field(package, "packageName"))
end

local function context_request_field(context, key)
    return first_nonempty(read_field(context, key), read_field(read_field(context, "request"), key))
end

local function context_packages(context)
    local direct = read_field(context, "packages")
    if type(direct) == "table" or type(direct) == "userdata" then
        local items = sequence_values(direct)
        if #items > 0 then
            return items
        end
    end
    local nested = read_field(read_field(context, "request"), "packages")
    if type(nested) == "table" or type(nested) == "userdata" then
        return sequence_values(nested)
    end
    return {}
end

local function as_string_list(value)
    local items = {}
    if type(value) == "string" then
        local cleaned = trim(value)
        if cleaned ~= "" then
            items[#items + 1] = cleaned
        end
        return items
    end
    for _, item in ipairs(sequence_values(value)) do
        local cleaned = trim(item)
        if cleaned ~= "" then
            items[#items + 1] = cleaned
        end
    end
    return items
end

local function resolve_request(context, package, local_path)
    local flags = collect_flags(context, package)
    local name = first_nonempty(package_name_from_request(package), context_request_field(context, "package"), context_request_field(context, "name"), context_request_field(context, "prompt"))
    local version = first_nonempty(read_field(package, "version"), read_field(package, "latestVersion"))
    local repository = first_nonempty(read_field(package, "repository"), flag_value(flags, "repository"))
    local loads = first_nonempty(read_field(package, "loads"), flag_value(flags, "loads"))
    local cache_repository = first_nonempty(read_field(package, "cacheRepository"), flag_value(flags, "cache-repository"))
    local project_type = has_flag(flags, "configuration") and "configuration" or "baseline"
    local local_target = local_path ~= nil and trim(local_path) ~= ""
    if local_target then
        repository = "filetree://" .. expand_runtime_placeholders(local_path)
        name = first_nonempty(name, basename(local_path))
    end
    return {
        name = name,
        version = version,
        repositorySpec = repository,
        loads = loads,
        cacheRepository = cache_repository,
        projectType = project_type,
        localTarget = local_target,
        localPath = local_target and expand_runtime_placeholders(local_path) or nil,
        ignoreImage = has_flag(flags, "ignore-image"),
        onConflict = flag_value(flags, "on-conflict"),
        onUpgrade = flag_value(flags, "on-upgrade"),
        onDowngrade = flag_value(flags, "on-downgrade"),
        onWarning = flag_value(flags, "on-warning"),
    }
end

local function smalltalk_string(value)
    return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

local function smalltalk_put_field(lines, dict_name, key, value, raw)
    if value == nil then
        return
    end
    if raw then
        lines[#lines + 1] = dict_name .. " at: " .. smalltalk_string(key) .. " put: " .. value .. "."
    else
        lines[#lines + 1] = dict_name .. " at: " .. smalltalk_string(key) .. " put: " .. smalltalk_string(value) .. "."
    end
end

local function append_metacello_lines(lines, request, action)
    local project_selector = request.projectType == "configuration" and "configuration:" or "baseline:"
    lines[#lines + 1] = "metacello := Metacello new."
    lines[#lines + 1] = "metacello " .. project_selector .. " " .. smalltalk_string(request.name) .. "."
    if request.repositorySpec ~= nil then
        lines[#lines + 1] = "metacello repository: " .. smalltalk_string(request.repositorySpec) .. "."
    end
    if request.version ~= nil then
        lines[#lines + 1] = "metacello version: " .. smalltalk_string(request.version) .. "."
    end
    if request.cacheRepository ~= nil then
        lines[#lines + 1] = "metacello cacheRepository: " .. smalltalk_string(request.cacheRepository) .. "."
    end
    if request.ignoreImage then
        lines[#lines + 1] = "metacello ignoreImage."
    end
    if request.onConflict == "use-incoming" then
        lines[#lines + 1] = "metacello onConflictUseIncoming."
    elseif request.onConflict == "use-loaded" then
        lines[#lines + 1] = "metacello onConflictUseLoaded."
    end
    if request.onUpgrade == "use-incoming" then
        lines[#lines + 1] = "metacello onUpgrade: [ :ex :loaded :incoming | ex useIncoming ]."
    elseif request.onUpgrade == "use-loaded" then
        lines[#lines + 1] = "metacello onUpgradeUseLoaded."
    end
    if request.onDowngrade == "use-incoming" then
        lines[#lines + 1] = "metacello onDowngradeUseIncoming."
    elseif request.onDowngrade == "use-loaded" then
        lines[#lines + 1] = "metacello onDowngrade: [ :ex :loaded :incoming | ex useLoaded ]."
    end
    if request.onWarning == "log" then
        lines[#lines + 1] = "metacello onWarningLog."
    end
    if action == "install" or action == "update" then
        if request.loads ~= nil then
            lines[#lines + 1] = "directive := metacello load: " .. smalltalk_string(request.loads) .. "."
        else
            lines[#lines + 1] = "directive := metacello load."
        end
    elseif action == "search" then
        lines[#lines + 1] = "directive := metacello " .. project_selector .. " [ :spec | true ]; list."
    elseif action == "info" or action == "outdated" then
        lines[#lines + 1] = "directive := metacello get."
    elseif action == "remove" then
        lines[#lines + 1] = "directive := metacello unlock."
    elseif action == "list" then
        lines[#lines + 1] = "directive := true."
    end
end

local function build_script(action, request)
    local lines = {
        "| response item items warnings metacello directive |",
        "response := Dictionary new.",
        "warnings := OrderedCollection new.",
        "[",
    }

    if action == "list" then
        lines[#lines + 1] = "items := OrderedCollection new."
        lines[#lines + 1] = "[ (Metacello image baseline: [ :spec | true ]; list) do: [ :spec | item := Dictionary new. item at: 'name' put: spec name asString. item at: 'projectType' put: 'baseline'. item at: 'version' put: (spec respondsTo: #versionString) ifTrue: [ spec versionString asString ] ifFalse: [ '' ]. item at: 'loaded' put: true. item at: 'registered' put: true. items add: item ] ] on: Error do: [ :ex | warnings add: ex description ]."
        lines[#lines + 1] = "[ (Metacello image configuration: [ :spec | true ]; list) do: [ :spec | item := Dictionary new. item at: 'name' put: spec name asString. item at: 'projectType' put: 'configuration'. item at: 'version' put: (spec respondsTo: #versionString) ifTrue: [ spec versionString asString ] ifFalse: [ '' ]. item at: 'loaded' put: true. item at: 'registered' put: true. items add: item ] ] on: Error do: [ :ex | warnings add: ex description ]."
        lines[#lines + 1] = "response at: 'ok' put: true."
        lines[#lines + 1] = "response at: 'items' put: items asArray."
    else
        append_metacello_lines(lines, request, action)
        lines[#lines + 1] = "item := Dictionary new."
        smalltalk_put_field(lines, "item", "name", request.name)
        smalltalk_put_field(lines, "item", "projectType", request.projectType)
        smalltalk_put_field(lines, "item", "version", request.version or "")
        smalltalk_put_field(lines, "item", "latestVersion", request.version or "")
        smalltalk_put_field(lines, "item", "repositorySpec", request.repositorySpec)
        smalltalk_put_field(lines, "item", "loaded", "true", true)
        smalltalk_put_field(lines, "item", "registered", "true", true)
        if action == "search" then
            lines[#lines + 1] = "items := Array with: item."
            lines[#lines + 1] = "response at: 'ok' put: true."
            lines[#lines + 1] = "response at: 'items' put: items."
        elseif action == "remove" then
            lines[#lines + 1] = "response at: 'ok' put: true."
            lines[#lines + 1] = "response at: 'removed' put: true."
            lines[#lines + 1] = "response at: 'item' put: item."
        else
            lines[#lines + 1] = "response at: 'ok' put: true."
            lines[#lines + 1] = "response at: 'item' put: item."
        end
    end

    lines[#lines + 1] = "] on: Error do: [ :ex | response := Dictionary new. response at: 'ok' put: false. response at: 'error' put: ex description ]."
    lines[#lines + 1] = "response at: 'warnings' put: warnings asArray."
    lines[#lines + 1] = "(Smalltalk at: #Stdio ifAbsent: [ nil ])"
    lines[#lines + 1] = "  ifNotNil: [ :stdio | stdio stdout nextPutAll: " .. smalltalk_string(RESULT_MARKER) .. "; nextPutAll: (NeoJSONWriter toString: response); lf ]."
    lines[#lines + 1] = "Smalltalk snapshot: true andQuit: true."
    return table.concat(lines, "\n") .. "\n"
end

local function run_pharo_script(context, package, action, request, suffix)
    local bootstrapped, boot_error = bootstrap_shared_image(context, package)
    if not bootstrapped then
        return nil, boot_error, nil
    end
    if not ensure_directory(state_root(context, package)) then
        return nil, "failed to prepare state directory", nil
    end
    if not ensure_directory(package_cache_path(context, package)) then
        return nil, "failed to prepare package cache directory", nil
    end

    local path = script_path(context, package, action, suffix)
    local script = build_script(action, request)
    local ok, err = write_text_file(path, script)
    if not ok then
        return nil, err, nil
    end

    local command = "XDG_CACHE_HOME=" .. shell_quote(cache_root(context, package))
        .. " PHARO_CACHE_DIR=" .. shell_quote(package_cache_path(context, package))
        .. " " .. REQUIRED_BINARY
        .. " --headless " .. shell_quote(image_path(context, package))
        .. " " .. shell_quote(path)

    local result = exec_run(context, command)
    if not result.success then
        return nil, first_nonempty(result.stderr, result.stdout, "Metacello command failed"), command
    end

    local payload = nil
    for _, line in ipairs(split_lines(result.stdout or "")) do
        if starts_with(line, RESULT_MARKER) then
            payload = line:sub(#RESULT_MARKER + 1)
        end
    end
    if payload == nil then
        payload = trim(result.stdout or "")
    end

    local decoded, decode_error = decode_json(payload)
    if decoded == nil then
        return nil, first_nonempty(decode_error, "failed to parse Metacello response"), command
    end
    if decoded.ok == false then
        return nil, first_nonempty(decoded.error, "Metacello action failed"), command
    end
    return decoded, nil, command
end

local function package_record_from_entry(entry, state_entry, context, package)
    local name = first_nonempty(read_field(entry, "name"), read_field(state_entry, "name")) or ""
    local repository = first_nonempty(read_field(entry, "repositorySpec"), read_field(state_entry, "repositorySpec"))
    local version = first_nonempty(read_field(entry, "version"), read_field(state_entry, "version")) or ""
    local latest_version = first_nonempty(read_field(entry, "latestVersion"), read_field(state_entry, "latestVersion")) or ""
    local installed = read_field(entry, "installed")
    if installed == nil then
        installed = read_field(state_entry, "installed")
    end
    if installed == nil then
        installed = true
    end
    local extra = merge_extra_fields(read_field(entry, "extraFields"), {
        projectType = first_nonempty(read_field(entry, "projectType"), read_field(state_entry, "projectType")),
        repositorySpec = repository,
        loads = first_nonempty(read_field(entry, "loads"), read_field(state_entry, "loads")),
        locked = read_field(entry, "locked"),
        loaded = read_field(entry, "loaded"),
        registered = read_field(entry, "registered"),
        imagePath = image_path(context, package),
        packageCachePath = package_cache_path(context, package),
        sourceState = state_entry,
    })
    return {
        name = name,
        packageId = name,
        packageType = "library",
        version = version,
        latestVersion = latest_version,
        installed = installed,
        status = installed and "installed" or "available",
        summary = first_nonempty(read_field(entry, "summary"), read_field(state_entry, "summary")),
        description = first_nonempty(read_field(entry, "description"), read_field(state_entry, "description")),
        homepage = first_nonempty(read_field(entry, "homepage"), read_field(state_entry, "homepage")),
        repository = repository,
        extraFields = extra,
    }
end

local function upsert_state_entry(state, request, response_item)
    state.packages = type(state.packages) == "table" and state.packages or {}
    local name = first_nonempty(request.name, read_field(response_item, "name"))
    if name == nil then
        return
    end
    state.packages[name] = {
        name = name,
        projectType = request.projectType,
        repositorySpec = request.repositorySpec,
        version = first_nonempty(read_field(response_item, "version"), request.version) or "",
        latestVersion = first_nonempty(read_field(response_item, "latestVersion"), request.version) or "",
        loads = request.loads,
        installed = true,
        localTarget = request.localTarget == true,
        localPath = request.localPath,
        updatedAt = os ~= nil and type(os.time) == "function" and os.time() or 0,
    }
end

local function remove_state_entry(state, name)
    state.packages = type(state.packages) == "table" and state.packages or {}
    state.packages[name] = nil
end

local function merged_items_from_state_and_payload(context, package, state, payload_items)
    local merged = {}
    local seen = {}
    for _, item in ipairs(payload_items or {}) do
        local name = first_nonempty(read_field(item, "name"))
        if name ~= nil then
            merged[#merged + 1] = package_record_from_entry(item, read_field(state.packages, name), context, package)
            seen[name] = true
        end
    end
    for _, key in ipairs(sorted_keys(state.packages or {})) do
        if not seen[key] then
            merged[#merged + 1] = package_record_from_entry({}, state.packages[key], context, package)
        end
    end
    table.sort(merged, function(left, right)
        return tostring(left.name or "") < tostring(right.name or "")
    end)
    return merged
end

local function query_payload_items(context, package, action, request, suffix)
    local decoded, err = run_pharo_script(context, package, action, request, suffix)
    if decoded == nil then
        log_warn(context, first_nonempty(err, "query failed"))
        return {}, err
    end
    local items = read_field(decoded, "items")
    if type(items) ~= "table" then
        local item = read_field(decoded, "item")
        if item ~= nil then
            return { item }, nil
        end
        return {}, nil
    end
    return items, nil
end

local function ensure_binary(context)
    local result = exec_run(context, "command -v " .. shell_quote(REQUIRED_BINARY) .. " >/dev/null 2>&1")
    return result.success == true
end

function plugin.getName()
    return PLUGIN_ID
end

function plugin.getVersion()
    return PLUGIN_VERSION
end

function plugin.getRequirements()
    return {}
end

function plugin.getCategories()
    return { "package-manager", "smalltalk", "pharo" }
end

function plugin.getMissingPackages(context)
    if ensure_binary(context) then
        return {}
    end
    return { REQUIRED_BINARY }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = {},
        ecosystemScopes = { "pharo", "smalltalk", "metacello" },
        writeScopes = {},
        networkScopes = {},
        privilegeLevel = "none",
    }
end

function plugin.init(context)
    return true
end

function plugin.install(context, packages)
    local local_path = first_nonempty(context_request_field(context, "localPath"), context_request_field(context, "path"))
    if local_path ~= nil and trim(local_path) ~= "" then
        return plugin.installLocal(context, local_path)
    end
    for _, package in ipairs(packages or {}) do
        local request = resolve_request(context, package, nil)
        if request.name == nil then
            tx_failed(context, "Metacello install requires package name")
            return false
        end
        if request.repositorySpec == nil then
            tx_failed(context, "Metacello install requires repository=<spec>")
            return false
        end

        begin_step(context, "Install " .. request.name)
        local decoded, err = run_pharo_script(context, package, "install", request, request.name)
        if decoded == nil then
            tx_failed(context, first_nonempty(err, "Metacello install failed"))
            return false
        end

        local state = load_state(context, package)
        upsert_state_entry(state, request, read_field(decoded, "item") or {})
        save_state(context, package, state)

        local item = package_record_from_entry(read_field(decoded, "item") or {}, state.packages[request.name], context, package)
        emit_event(context, "installed", item)
        tx_success(context)
    end
    return true
end

function plugin.installLocal(context, path)
    local local_path = expand_runtime_placeholders(path)
    local package = context_packages(context)[1] or {}
    if package_name_from_request(package) == nil then
        package = {
            name = basename(local_path),
            flags = object_flags(context),
        }
    end
    local request = resolve_request(context, package, local_path)
    local package_for_paths = package_name_from_request(package) ~= nil and package or { name = request.name, flags = object_flags(context) }
    if request.name == nil then
        tx_failed(context, "Metacello installLocal requires package name")
        return false
    end
    begin_step(context, "Install local " .. request.name)
    local decoded, err = run_pharo_script(context, package_for_paths, "install-local", request, request.name)
    if decoded == nil then
        tx_failed(context, first_nonempty(err, "Metacello local install failed"))
        return false
    end

    local state = load_state(context, package)
    upsert_state_entry(state, request, read_field(decoded, "item") or {})
    save_state(context, package, state)

    local item = package_record_from_entry(read_field(decoded, "item") or {}, state.packages[request.name], context, package)
    item.localTarget = true
    item.path = local_path
    emit_event(context, "installed", item)
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    for _, package in ipairs(packages or {}) do
        local state = load_state(context, package)
        local name = first_nonempty(package_name_from_request(package))
        if name == nil then
            tx_failed(context, "Metacello remove requires package name")
            return false
        end
        local existing = read_field(state.packages, name)
        local request = resolve_request(context, merge_extra_fields(existing, package), nil)

        begin_step(context, "Remove " .. name)
        local decoded, err = run_pharo_script(context, package, "remove", request, name)
        if decoded == nil then
            tx_failed(context, first_nonempty(err, "Metacello remove failed"))
            return false
        end

        remove_state_entry(state, name)
        save_state(context, package, state)
        emit_event(context, "deleted", { name = name, packageId = name })
        tx_success(context)
    end
    return true
end

function plugin.update(context, packages)
    for _, package in ipairs(packages or {}) do
        local state = load_state(context, package)
        local name = first_nonempty(package_name_from_request(package))
        if name == nil then
            tx_failed(context, "Metacello update requires package name")
            return false
        end
        local existing = read_field(state.packages, name)
        local request = resolve_request(context, merge_extra_fields(existing, package), nil)

        begin_step(context, "Update " .. name)
        local decoded, err = run_pharo_script(context, package, "update", request, name)
        if decoded == nil then
            tx_failed(context, first_nonempty(err, "Metacello update failed"))
            return false
        end

        upsert_state_entry(state, request, read_field(decoded, "item") or {})
        save_state(context, package, state)
        emit_event(context, "updated", package_record_from_entry(read_field(decoded, "item") or {}, state.packages[name], context, package))
        tx_success(context)
    end
    return true
end

function plugin.list(context)
    local state = load_state(context, nil)
    local items = query_payload_items(context, nil, "list", { name = "list", projectType = "baseline" }, nil)
    local results = merged_items_from_state_and_payload(context, nil, state, items)
    emit_event(context, "listed", results)
    return results
end

function plugin.outdated(context)
    local state = load_state(context, nil)
    local results = {}
    for _, name in ipairs(sorted_keys(state.packages or {})) do
        local entry = state.packages[name]
        if first_nonempty(read_field(entry, "repositorySpec")) ~= nil then
            local request = resolve_request(context, entry, nil)
            local decoded_items = query_payload_items(context, entry, "outdated", request, name)
            local item = decoded_items[1]
            local version = first_nonempty(read_field(item, "version"), read_field(entry, "version"))
            local latest = first_nonempty(read_field(item, "latestVersion"), read_field(entry, "latestVersion"))
            if version ~= nil and latest ~= nil and version ~= latest then
                results[#results + 1] = package_record_from_entry(item or {}, entry, context, entry)
            end
        end
    end
    emit_event(context, "outdated", results[1] or results)
    return results
end

function plugin.search(context, prompt)
    local query = trim(prompt)
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end
    local request = resolve_request(context, {}, nil)
    if request.repositorySpec == nil then
        log_warn(context, "Metacello search requires repository=<spec>")
        emit_event(context, "searched", {})
        return {}
    end
    local items = query_payload_items(context, nil, "search", request, nil)
    local results = {}
    for _, item in ipairs(items or {}) do
        local name = lower(first_nonempty(read_field(item, "name"), ""))
        if name:find(lower(query), 1, true) ~= nil then
            results[#results + 1] = package_record_from_entry(item, nil, context, nil)
        end
    end
    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local package_name = first_nonempty(name, context_request_field(context, "package"), context_request_field(context, "name"), context_request_field(context, "prompt"))
    if package_name == nil then
        emit_event(context, "unavailable", { name = "" })
        return {}
    end

    local state = load_state(context, nil)
    local existing = read_field(state.packages, package_name)
    local request = resolve_request(context, merge_extra_fields(existing, { name = package_name }), nil)
    local items = query_payload_items(context, existing or {}, "info", request, package_name)
    local item = items[1]
    if item == nil and existing == nil then
        emit_event(context, "unavailable", { name = package_name })
        return {}
    end
    local record = package_record_from_entry(item or {}, existing, context, existing or {})
    emit_event(context, "informed", record)
    return record
end

function plugin.resolvePackage(context, package)
    local state = load_state(context, package)
    local name = package_name_from_request(package)
    local existing = name ~= nil and read_field(state.packages, name) or nil
    if existing == nil then
        return package
    end
    return merge_extra_fields(package, existing)
end

function plugin.shutdown()
    return true
end

return plugin
