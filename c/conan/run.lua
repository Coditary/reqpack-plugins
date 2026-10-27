plugin = {}

local PLUGIN_ID = "conan"
local PLUGIN_NAME = "Conan"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "conan"
local JSON_NULL = {}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function non_empty(value)
    local text = trim(value)
    if text == "" then
        return nil
    end
    return text
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
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
        if value ~= JSON_NULL and value ~= nil then
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

local function json_value(value)
    if value == JSON_NULL then
        return nil
    end
    return value
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

local function is_benign_cppcache_warning(message)
    local text = tostring(message or "")
    if text == "" then return false end
    if not text:find("/cppcache/artifacts/", 1, true) then return false end
    if not text:find(": No such file or directory", 1, true) then return false end
    return text:find("/manifest.json", 1, true) ~= nil
        or text:find("/files.json", 1, true) ~= nil
        or text:find("/source.json", 1, true) ~= nil
end

local function split_lines(value)
    local lines = {}
    for line in tostring(value or ""):gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end
    return lines
end

local function normalize_run_result(first, second, third, fourth, fifth)
    if type(first) == "table" then
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

local function run_command(context, command)
    local first, second, third, fourth, fifth
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        first, second, third, fourth, fifth = context.exec.run(command)
    else
        first, second, third, fourth, fifth = reqpack.exec.run(command)
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
    local exit_code = result.exitCode or result.exit_code or result.code or result.status
    return exit_code == 0
end

local function command_exists(context, binary)
    return is_command_success(run_command(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function build_command(binary, args)
    local parts = { shell_quote(binary) }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = shell_quote(arg)
    end
    return table.concat(parts, " ")
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
        local result = {}
        if peek() == "]" then
            index = index + 1
            return result
        end
        while true do
            result[#result + 1] = parse_value()
            skip_whitespace()
            local current = peek()
            if current == "," then
                index = index + 1
                skip_whitespace()
            elseif current == "]" then
                index = index + 1
                return result
            else
                decode_error("expected ',' or ']' ")
            end
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
                decode_error("expected ':'")
            end
            index = index + 1
            skip_whitespace()
            local value = parse_value()
            if value == nil then
                result[key] = JSON_NULL
            else
                result[key] = value
            end
            skip_whitespace()
            local current = peek()
            if current == "," then
                index = index + 1
                skip_whitespace()
            elseif current == "}" then
                index = index + 1
                return result
            else
                decode_error("expected ',' or '}'")
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
        if current == "-" or current:match("%d") then
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
            return nil
        end
        decode_error("unexpected token")
    end

    local parsed = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("trailing data")
    end
    return parsed
end

local function decode_json(raw)
    local ok, value = pcall(decode_json_internal, raw)
    if not ok then
        return nil, value
    end
    return value, nil
end

local function decode_json_output(raw)
    local text = trim(raw)
    if text == "" then
        return nil, "empty output"
    end

    local decoded, err = decode_json(text)
    if decoded ~= nil then
        return decoded, nil
    end

    local last_nonempty = nil
    for _, line in ipairs(split_lines(text)) do
        local current = trim(line)
        if current ~= "" then
            last_nonempty = current
        end
    end
    if last_nonempty ~= nil then
        return decode_json(last_nonempty)
    end
    return nil, err
end

local function sorted_keys(value)
    local keys = {}
    for key in pairs(value or {}) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)
    return keys
end

local function append_all(target, items)
    for _, item in ipairs(items or {}) do
        target[#target + 1] = item
    end
end

local function has_entries(value)
    if type(value) ~= "table" then
        return false
    end
    return next(value) ~= nil
end

local function reference_base(reference)
    return trim(tostring(reference or ""):match("^([^#]+)") or reference)
end

local function parse_reference(reference)
    local base = reference_base(reference)
    local no_user_channel = base:match("^([^@]+)") or base
    local name, version = no_user_channel:match("^([^/]+)/(.+)$")
    return trim(name), trim(version)
end

local function dirname(path)
    local text = tostring(path or "")
    local dir = text:match("^(.*)/[^/]+$")
    if dir ~= nil and dir ~= "" then
        return dir
    end
    return "."
end

local function path_exists(path)
    local text = trim(path)
    if text == "" then
        return false
    end
    local handle = io.open(text, "rb")
    if handle ~= nil then
        handle:close()
        return true
    end
    local dir_handle = io.open((text:gsub("/+$", "")) .. "/.", "rb")
    if dir_handle ~= nil then
        dir_handle:close()
        return true
    end
    return false
end

local function read_text_file(path)
    local handle = io.open(path, "rb")
    if handle == nil then
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_text_file(context, path, content)
    local handle, open_error = io.open(path, "wb")
    if handle == nil then
        local parent = dirname(path)
        if parent ~= nil and trim(parent) ~= "" then
            run_command(context, "mkdir -p " .. shell_quote(parent))
            if os ~= nil and type(os.execute) == "function" then
                os.execute("mkdir -p " .. shell_quote(parent))
            end
        end
        handle, open_error = io.open(path, "wb")
        if handle == nil then
            return nil, open_error
        end
    end
    local ok, write_error = handle:write(content)
    handle:close()
    if not ok then
        return nil, write_error
    end
    return true, nil
end

local function ensure_directory(context, path)
    local result = run_command(context, "mkdir -p " .. shell_quote(path))
    if is_command_success(result) then
        if path_exists(path) then
            return true, nil
        end
        if os ~= nil and type(os.execute) == "function" then
            local exec_ok = os.execute("mkdir -p " .. shell_quote(path))
            if exec_ok == true or exec_ok == 0 then
                return true, nil
            end
        end
        return true, nil
    end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to create directory: " .. tostring(path))
end

local function remove_path_if_exists(context, path)
    if not path_exists(path) then
        return true, nil
    end
    local result = run_command(context, "rm -rf " .. shell_quote(path))
    if is_command_success(result) then
        return true, nil
    end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to remove path: " .. tostring(path))
end

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        local value = non_empty(os.getenv(name))
        if value ~= nil then
            return value
        end
    end
    local handle = io.open("/proc/self/environ", "rb")
    if handle == nil then
        return nil
    end
    local payload = handle:read("*a")
    handle:close()
    if payload == nil then
        return nil
    end
    local prefix = tostring(name or "") .. "="
    for entry in tostring(payload):gmatch("[^%z]+") do
        if entry:sub(1, #prefix) == prefix then
            return non_empty(entry:sub(#prefix + 1))
        end
    end
    return nil
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local raw = trim(select(index, ...) or "")
        if raw ~= "" then
            if #parts == 0 then
                parts[#parts + 1] = raw:gsub("/+$", "")
            else
                parts[#parts + 1] = raw:gsub("^/+", ""):gsub("/+$", "")
            end
        end
    end
    return table.concat(parts, "/")
end

local function sorted_string_keys(value)
    local keys = {}
    for key in pairs(value or {}) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)
    return keys
end

local function is_array_table(value)
    local max_index = 0
    local count = 0
    for key in pairs(value or {}) do
        if type(key) ~= "number" or key < 1 or math.floor(key) ~= key then
            return false
        end
        if key > max_index then
            max_index = key
        end
        count = count + 1
    end
    return max_index == count
end

local function encode_json_string(value)
    local text = tostring(value or "")
    local replacements = {
        ["\\"] = "\\\\",
        ["\""] = "\\\"",
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
    }
    return '"' .. text:gsub('[%z\1-\31\\"]', function(char)
        return replacements[char] or string.format("\\u%04x", string.byte(char))
    end) .. '"'
end

local function encode_json(value)
    local value_type = type(value)
    if value == nil or value == JSON_NULL then
        return "null"
    end
    if value_type == "string" then
        return encode_json_string(value)
    end
    if value_type == "number" or value_type == "boolean" then
        return tostring(value)
    end
    if value_type ~= "table" then
        return encode_json_string(tostring(value))
    end
    if is_array_table(value) then
        local items = {}
        for index = 1, #value do
            items[#items + 1] = encode_json(value[index])
        end
        return "[" .. table.concat(items, ",") .. "]"
    end
    local items = {}
    for _, key in ipairs(sorted_string_keys(value)) do
        items[#items + 1] = encode_json_string(key) .. ":" .. encode_json(value[key])
    end
    return "{" .. table.concat(items, ",") .. "}"
end

local function normalize_token(value)
    return tostring(value or ""):gsub("/", "__"):gsub("[^%w%._%-+:]+", "_")
end

local function cppcache_root()
    local fixture_root = getenv("REQPACK_TEST_FIXTURE_ROOT")
    if fixture_root ~= nil and fixture_root ~= "" then
        local xdg = getenv("XDG_DATA_HOME")
        if xdg ~= nil and xdg ~= "" then
            return join_path(xdg, "cppcache")
        end
        local home = getenv("HOME")
        if home ~= nil and home ~= "" then
            return join_path(home, ".local", "share", "cppcache")
        end
    end
    local data_root = type(reqpack) == "table" and type(reqpack.paths) == "table" and trim(reqpack.paths.dataRoot or "") or ""
    if data_root ~= "" then
        return join_path(data_root, "cppcache")
    end
    local xdg = getenv("XDG_DATA_HOME")
    if xdg ~= nil and xdg ~= "" then
        return join_path(xdg, "cppcache")
    end
    local home = getenv("HOME")
    if home ~= nil and home ~= "" then
        return join_path(home, ".local", "share", "cppcache")
    end
    return nil
end

local function cppcache_current_path(root, registry, key)
    return join_path(root, "views", "by-source", registry, normalize_token(key), "current.json")
end

local function annotate_cppcache_fields(item, pointer)
    if type(item) ~= "table" or type(pointer) ~= "table" then
        return item
    end
    item.extraFields = shallow_copy(item.extraFields)
    item.extraFields.cppcacheArtifactId = read_field(pointer, "artifact_id")
    item.extraFields.cppcacheArtifactPath = read_field(pointer, "artifact_path")
    item.extraFields.cppcachePrefixPath = read_field(pointer, "prefix_path")
    item.extraFields.cppcacheSourcePath = read_field(pointer, "source_path")
    item.extraFields.cppcacheRoot = cppcache_root()
    return item
end

local function lookup_cppcache_pointer(registry, key)
    local root = cppcache_root()
    if root == nil then
        return nil, nil
    end
    local content = read_text_file(cppcache_current_path(root, registry, key))
    if content == nil then
        return nil, nil
    end
    return decode_json(content)
end

local function decode_json_file(path)
    local content = read_text_file(path)
    if content == nil then
        return nil, "failed to read file: " .. tostring(path)
    end
    return decode_json(content)
end

local function cppcache_artifact_paths(root, artifact_id, format, logical_path)
    return {
        kind = join_path(root, "views", "by-kind", "cpp-package", artifact_id, logical_path),
        format = join_path(root, "views", "by-format", format, artifact_id, logical_path),
    }
end

local function build_cppcache_item_from_pointer(pointer)
    if type(pointer) ~= "table" then return nil end
    local artifact_path = trim(read_field(pointer, "artifact_path") or "")
    if artifact_path == "" then return nil end
    local manifest = select(1, decode_json_file(join_path(artifact_path, "manifest.json"))) or {}
    local source = type(read_field(manifest, "source")) == "table" and read_field(manifest, "source") or {}
    local package_id = first_nonempty(read_field(source, "package_id"))
    local name, version = parse_reference(package_id or "")
    local item = {
        name = name ~= "" and name or package_id,
        packageId = package_id,
        version = first_nonempty(read_field(source, "version"), version),
        latestVersion = first_nonempty(read_field(source, "version"), version),
        installed = true,
        status = "installed",
        packageType = "package",
        type = "package",
        extraFields = { reference = package_id },
    }
    annotate_cppcache_fields(item, pointer)
    return item
end

local function write_cppcache_pointer(context, root, registry, key, payload)
    local path = cppcache_current_path(root, registry, key)
    local ok, err = ensure_directory(context, dirname(path))
    if not ok then
        return nil, err
    end
    return write_text_file(context, path, encode_json(payload))
end

local function current_timestamp_utc(context)
    local result = run_command(context, "date -u +%Y-%m-%dT%H:%M:%SZ")
    if not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to capture timestamp")
    end
    return trim(result.stdout), nil
end

local function sha256_digest_for_file(context, file_path)
    local result = run_command(context, "sha256sum " .. shell_quote(file_path))
    if not is_command_success(result) then
        result = run_command(context, "shasum -a 256 " .. shell_quote(file_path))
    end
    if not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to hash file: " .. file_path)
    end
    local digest = trim(result.stdout):match("^([0-9a-fA-F]+)")
    if digest == nil or #digest ~= 64 then
        return nil, "failed to parse sha256 for " .. file_path
    end
    return lower(digest), nil
end

local function file_size_for_path(context, file_path)
    local result = run_command(context, "stat -c %s " .. shell_quote(file_path))
    if not is_command_success(result) then
        result = run_command(context, "stat -f %z " .. shell_quote(file_path))
    end
    if not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to stat file: " .. file_path)
    end
    local size = tonumber(trim(result.stdout))
    if size == nil then
        return nil, "failed to parse file size for " .. file_path
    end
    return size, nil
end

local function file_link_count(context, file_path)
    if not path_exists(file_path) then return 0, nil end
    local result = run_command(context, "stat -c %h " .. shell_quote(file_path))
    if not is_command_success(result) then
        result = run_command(context, "stat -f %l " .. shell_quote(file_path))
    end
    if not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to stat link count")
    end
    return tonumber(trim(result.stdout)), nil
end

local function adopt_blob(context, source_path, blob_path)
    if path_exists(blob_path) then return true, nil end
    local ok, err = ensure_directory(context, dirname(blob_path))
    if not ok then return nil, err end
    local result = run_command(context, "ln " .. shell_quote(source_path) .. " " .. shell_quote(blob_path))
    if is_command_success(result) then
        return true, nil
    end
    result = run_command(context, "cp " .. shell_quote(source_path) .. " " .. shell_quote(blob_path))
    if is_command_success(result) then
        return true, nil
    end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to adopt blob")
end

local function materialize_file(context, source_path, target_path)
    local ok, err = ensure_directory(context, dirname(target_path))
    if not ok then
        return nil, err
    end
    if path_exists(target_path) then
        local removed, remove_error = remove_path_if_exists(context, target_path)
        if not removed then
            return nil, remove_error
        end
    end
    local result = run_command(context, "ln " .. shell_quote(source_path) .. " " .. shell_quote(target_path))
    if is_command_success(result) then
        return true, nil
    end
    result = run_command(context, "cp " .. shell_quote(source_path) .. " " .. shell_quote(target_path))
    if is_command_success(result) then
        return true, nil
    end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to materialize file")
end

local function detect_cppcache_format(logical_path)
    local path = lower(logical_path)
    if path:find("/include/", 1, true) ~= nil or path:match("^include/") then return "include" end
    if path:find("/pkgconfig/", 1, true) ~= nil or path:match("%.pc$") then return "pkgconfig" end
    if path:find("/cmake/", 1, true) ~= nil or path:match("config%.cmake$") or path:match("targets%.cmake$") then return "cmake" end
    if path:match("^bin/") or path:find("/bin/", 1, true) ~= nil then return "bin" end
    if path:match("^lib/") or path:find("/lib/", 1, true) ~= nil then return "lib" end
    return "metadata"
end

local function sync_cppcache_artifact(context, registry, package_key, artifact_id, source_path, logical_files, source_metadata)
    local root = cppcache_root()
    if root == nil then return nil, "cppcache root unavailable" end
    if source_path == nil or source_path == "" then return nil, "cppcache source path unavailable" end
    if type(logical_files) ~= "table" or #logical_files == 0 then return nil, "cppcache file inventory empty" end

    local artifact_path = join_path(root, "artifacts", artifact_id)
    local prefix_path = join_path(root, "prefixes", artifact_id)
    local blobs_root = join_path(root, "blobs", "sha256")
    for _, path in ipairs({ root, join_path(root, "artifacts"), join_path(root, "prefixes"), join_path(root, "views"), join_path(root, "views", "by-source"), join_path(root, "views", "by-source", registry), join_path(root, "views", "by-kind"), join_path(root, "views", "by-format"), blobs_root, artifact_path, prefix_path }) do
        local ok, err = ensure_directory(context, path)
        if not ok then return nil, err end
    end

    local created_at, timestamp_error = current_timestamp_utc(context)
    if created_at == nil then return nil, timestamp_error end

    local files = {}
    for _, entry in ipairs(logical_files) do
        local source_file = join_path(source_path, entry.source_relative_path)
        local digest, digest_error = sha256_digest_for_file(context, source_file)
        if digest == nil then return nil, digest_error end
        local size, size_error = file_size_for_path(context, source_file)
        if size == nil then return nil, size_error end
        local format = detect_cppcache_format(entry.logical_path)
        local blob_path = join_path(blobs_root, digest:sub(1, 2), digest)
        local ok, err = adopt_blob(context, source_file, blob_path)
        if not ok then return nil, err end
        local target_file = join_path(prefix_path, entry.logical_path)
        ok, err = materialize_file(context, blob_path, target_file)
        if not ok then return nil, err end
        local view_paths = cppcache_artifact_paths(root, artifact_id, format, entry.logical_path)
        ok, err = materialize_file(context, blob_path, view_paths.kind)
        if not ok then return nil, err end
        ok, err = materialize_file(context, blob_path, view_paths.format)
        if not ok then return nil, err end
        files[#files + 1] = {
            logical_path = entry.logical_path,
            source_relative_path = entry.source_relative_path,
            format = format,
            blob_id = "sha256:" .. digest,
            blob_path = blob_path,
            kind_view_path = view_paths.kind,
            format_view_path = view_paths.format,
            size = size,
        }
    end

    local ok, err = ensure_directory(context, dirname(join_path(artifact_path, "manifest.json")))
    if not ok then return nil, err end
    ok, err = write_text_file(context, join_path(artifact_path, "manifest.json"), encode_json({
        artifact_id = artifact_id,
        kind = "cpp-package",
        source = {
            registry = registry,
            package_id = package_key,
            version = read_field(source_metadata, "version"),
            revision = read_field(source_metadata, "revision"),
        },
        created_at = created_at,
    }))
    if not ok then return nil, err end
    ok, err = write_text_file(context, join_path(artifact_path, "files.json"), encode_json({ files = files }))
    if not ok then return nil, err end
    ok, err = write_text_file(context, join_path(artifact_path, "source.json"), encode_json({
        fetched_at = created_at,
        source_cache_paths = { source_path },
        managed_source_cache = false,
        version = read_field(source_metadata, "version"),
        revision = read_field(source_metadata, "revision"),
    }))
    if not ok then return nil, err end

    local pointer = {
        artifact_id = artifact_id,
        artifact_path = artifact_path,
        prefix_path = prefix_path,
        source_path = source_path,
    }
    ok, err = write_cppcache_pointer(context, root, registry, package_key, pointer)
    if not ok then return nil, err end
    return pointer, nil
end

local function cleanup_cppcache_artifact(context, registry, package_key)
    local pointer = select(1, lookup_cppcache_pointer(registry, package_key))
    if type(pointer) ~= "table" then return true, nil end
    local artifact_path = trim(read_field(pointer, "artifact_path") or "")
    local files_payload = artifact_path ~= "" and select(1, decode_json_file(join_path(artifact_path, "files.json"))) or nil
    local ok, err = remove_path_if_exists(context, cppcache_current_path(cppcache_root() or "", registry, package_key))
    if not ok then return nil, err end
    for _, entry in ipairs(type(files_payload) == "table" and (read_field(files_payload, "files") or {}) or {}) do
        local kind_view = trim(read_field(entry, "kind_view_path") or "")
        local format_view = trim(read_field(entry, "format_view_path") or "")
        local blob_path = trim(read_field(entry, "blob_path") or "")
        if kind_view ~= "" then ok, err = remove_path_if_exists(context, kind_view); if not ok then return nil, err end end
        if format_view ~= "" then ok, err = remove_path_if_exists(context, format_view); if not ok then return nil, err end end
        if blob_path ~= "" then
            local count, count_error = file_link_count(context, blob_path)
            if count == nil then return nil, count_error end
            if count <= 1 then ok, err = remove_path_if_exists(context, blob_path); if not ok then return nil, err end end
        end
    end
    ok, err = remove_path_if_exists(context, artifact_path)
    if not ok then return nil, err end
    ok, err = remove_path_if_exists(context, trim(read_field(pointer, "prefix_path") or ""))
    if not ok then return nil, err end
    return true, nil
end

local function package_name_value(package)
    return trim(first_nonempty(read_field(package, "name"), read_field(package, "packageId"), package))
end

local function package_version_value(package)
    return trim(read_field(package, "version") or "")
end

local function flags_table(package)
    local flags = read_field(package, "flags")
    if type(flags) == "table" then
        return flags
    end
    return {}
end

local function flags_values(package)
    local values = {}
    local flags = flags_table(package)
    for _, value in ipairs(flags) do
        values[#values + 1] = value
    end
    for key, value in pairs(flags) do
        if type(key) == "string" then
            if type(value) == "boolean" then
                if value then
                    values[#values + 1] = key
                end
            elseif value ~= nil then
                values[#values + 1] = key .. "=" .. tostring(value)
            end
        end
    end
    return values
end

local function extra_fields_table(package)
    local extra = read_field(package, "extraFields")
    if type(extra) == "table" then
        return extra
    end
    return {}
end

local function flag_token_value(package, key)
    local direct = first_nonempty(read_field(package, key), read_field(extra_fields_table(package), key), read_field(flags_table(package), key))
    if direct ~= nil then
        if type(direct) == "boolean" then
            return direct and "true" or nil
        end
        return tostring(direct)
    end

    for _, token in ipairs(flags_values(package)) do
        local text = trim(token)
        local prefix = tostring(key) .. "="
        if text == key then
            return "true"
        end
        if text:sub(1, #prefix) == prefix then
            return trim(text:sub(#prefix + 1))
        end
    end
    return nil
end

local function has_flag(package, key)
    local direct = first_nonempty(read_field(package, key), read_field(extra_fields_table(package), key), read_field(flags_table(package), key))
    if type(direct) == "boolean" then
        return direct
    end
    if type(direct) == "string" then
        local text = lower(trim(direct))
        return text == "true" or text == "1" or text == key
    end
    for _, token in ipairs(flags_values(package)) do
        if trim(token) == key then
            return true
        end
    end
    return false
end

local function parse_prompt_options(prompt)
    local remote = nil
    local parts = {}
    for token in tostring(prompt or ""):gmatch("%S+") do
        local text = trim(token)
        if text:sub(1, 7) == "remote=" then
            remote = trim(text:sub(8))
        else
            parts[#parts + 1] = text
        end
    end
    return table.concat(parts, " "), remote
end

local function normalize_reference(package)
    local name = package_name_value(package)
    if name == "" then
        return ""
    end
    if name:find("/", 1, true) ~= nil then
        return name
    end
    local version = package_version_value(package)
    if version ~= "" then
        return name .. "/" .. version
    end
    return name
end

local function query_pattern_for_lookup(raw)
    local text = trim(raw)
    if text == "" then
        return "*"
    end
    if text:find("*", 1, true) ~= nil or text:find("#", 1, true) ~= nil or text:find(":", 1, true) ~= nil then
        return text
    end
    if text:find("/", 1, true) ~= nil then
        return text
    end
    return text .. "/*"
end

local function search_pattern_for_prompt(raw)
    local text = trim(raw)
    if text == "" then
        return ""
    end
    if text:find("*", 1, true) ~= nil or text:find("/", 1, true) ~= nil then
        return text
    end
    return text .. "*"
end

local function exact_match(query, item)
    local text = trim(query)
    if text == "" or type(item) ~= "table" then
        return false
    end
    if trim(read_field(item, "packageId") or "") == text then
        return true
    end
    if trim(read_field(item, "name") or "") == text then
        return true
    end
    local extra = extra_fields_table(item)
    return trim(read_field(extra, "reference") or "") == text
end

local function exact_or_first(items, query)
    for _, item in ipairs(items or {}) do
        if exact_match(query, item) then
            return item
        end
    end
    return items ~= nil and items[1] or nil
end

local function run_conan_json(context, args)
    local result = run_command(context, build_command(REQUIRED_BINARY, args))
    if not is_command_success(result) then
        return nil, first_nonempty(result.stderr, result.stdout, "conan command failed"), result
    end

    local decoded, decode_error = decode_json_output(result.stdout)
    if decoded == nil then
        return nil, first_nonempty(decode_error, "failed to decode conan json output"), result
    end
    return decoded, nil, result
end

local function run_conan(context, args)
    local result = run_command(context, build_command(REQUIRED_BINARY, args))
    if not is_command_success(result) then
        return nil, first_nonempty(result.stderr, result.stdout, "conan command failed"), result
    end
    return result, nil, result
end

local function remote_list(context)
    local decoded, err = run_conan_json(context, { "remote", "list", "--format=json" })
    if decoded == nil then
        return {}, err
    end
    if type(decoded) ~= "table" then
        return {}, "invalid conan remote list payload"
    end
    return decoded, nil
end

local function default_remote_name(context)
    local remotes = remote_list(context)
    for _, remote in ipairs(remotes or {}) do
        if type(remote) == "table" and read_field(remote, "enabled") ~= false then
            local name = trim(read_field(remote, "name") or "")
            if name ~= "" then
                return name
            end
        end
    end
    return nil
end

local function flatten_info_map(prefix, info_map, target)
    for _, key in ipairs(sorted_keys(info_map)) do
        local value = json_value(read_field(info_map, key))
        if value ~= nil then
            target[prefix .. key] = tostring(value)
        end
    end
end

local function build_recipe_item(reference, recipe_revision, location, revision_data)
    local name, version = parse_reference(reference)
    local item = {
        name = name ~= "" and name or reference,
        packageId = recipe_revision ~= nil and recipe_revision ~= "" and (reference .. "#" .. recipe_revision) or reference,
        version = version ~= "" and version or nil,
        latestVersion = version ~= "" and version or nil,
        summary = "Conan recipe " .. reference,
        description = "Conan recipe " .. reference,
        installed = location == "Local Cache",
        status = location == "Local Cache" and "installed" or "available",
        packageType = "recipe",
        type = "package",
        repository = location ~= "Local Cache" and location or nil,
        extraFields = {
            reference = reference,
            recipeRevision = recipe_revision,
            location = location,
            timestamp = tostring(read_field(revision_data or {}, "timestamp") or ""),
        },
    }
    return item
end

local function build_package_item(reference, recipe_revision, package_id, package_revision, location, package_data, package_revision_data)
    local name, version = parse_reference(reference)
    local full_reference = reference
    if recipe_revision ~= nil and recipe_revision ~= "" then
        full_reference = full_reference .. "#" .. recipe_revision
    end
    full_reference = full_reference .. ":" .. package_id
    if package_revision ~= nil and package_revision ~= "" then
        full_reference = full_reference .. "#" .. package_revision
    end

    local extra = {
        reference = reference,
        recipeRevision = recipe_revision,
        packageId = package_id,
        packageRevision = package_revision,
        location = location,
        timestamp = tostring(read_field(package_revision_data or {}, "timestamp") or ""),
    }
    local info = json_value(read_field(package_data, "info"))
    if type(info) == "table" then
        local settings = json_value(read_field(info, "settings"))
        local options = json_value(read_field(info, "options"))
        if type(settings) == "table" then
            flatten_info_map("setting.", settings, extra)
        end
        if type(options) == "table" then
            flatten_info_map("option.", options, extra)
        end
    end

    local arch = extra["setting.arch"]
    return {
        name = name ~= "" and name or reference,
        packageId = full_reference,
        version = version ~= "" and version or nil,
        latestVersion = version ~= "" and version or nil,
        summary = "Conan package " .. reference,
        description = "Conan package " .. reference,
        installed = location == "Local Cache",
        status = location == "Local Cache" and "installed" or "available",
        packageType = "package",
        type = "package",
        architecture = arch,
        repository = location ~= "Local Cache" and location or nil,
        extraFields = extra,
    }
end

local function flatten_list_payload(decoded)
    local items = {}
    for _, location in ipairs(sorted_keys(decoded)) do
        local recipes = json_value(read_field(decoded, location))
        if type(recipes) == "table" then
            for _, reference in ipairs(sorted_keys(recipes)) do
                local recipe_data = json_value(read_field(recipes, reference))
                local revisions = type(recipe_data) == "table" and json_value(read_field(recipe_data, "revisions")) or nil
                if type(revisions) == "table" and has_entries(revisions) then
                    for _, recipe_revision in ipairs(sorted_keys(revisions)) do
                        local revision_data = json_value(read_field(revisions, recipe_revision)) or {}
                        items[#items + 1] = build_recipe_item(reference, recipe_revision, location, revision_data)

                        local packages = json_value(read_field(revision_data, "packages"))
                        if type(packages) == "table" and has_entries(packages) then
                            for _, package_id in ipairs(sorted_keys(packages)) do
                                local package_data = json_value(read_field(packages, package_id)) or {}
                                local package_revisions = json_value(read_field(package_data, "revisions"))
                                if type(package_revisions) == "table" and has_entries(package_revisions) then
                                    for _, package_revision in ipairs(sorted_keys(package_revisions)) do
                                        local package_revision_data = json_value(read_field(package_revisions, package_revision)) or {}
                                        items[#items + 1] = build_package_item(reference, recipe_revision, package_id, package_revision, location, package_data, package_revision_data)
                                    end
                                else
                                    items[#items + 1] = build_package_item(reference, recipe_revision, package_id, nil, location, package_data, {})
                                end
                            end
                        end
                    end
                else
                    items[#items + 1] = build_recipe_item(reference, nil, location, recipe_data or {})
                end
            end
        end
    end

    table.sort(items, function(left, right)
        return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "")
    end)
    return items
end

local function flatten_search_payload(decoded)
    local items = {}
    for _, remote in ipairs(sorted_keys(decoded)) do
        local recipes = json_value(read_field(decoded, remote))
        if type(recipes) == "table" then
            for _, reference in ipairs(sorted_keys(recipes)) do
                items[#items + 1] = build_recipe_item(reference, nil, remote, {})
            end
        end
    end
    table.sort(items, function(left, right)
        return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "")
    end)
    return items
end

local function list_local_items(context, pattern)
    local decoded, err = run_conan_json(context, { "list", "--format=json", "-c", pattern })
    if decoded == nil then
        return nil, err
    end
    return flatten_list_payload(decoded), nil
end

local function search_remote_items(context, pattern, remote)
    local args = { "search", "--format=json" }
    if trim(remote or "") ~= "" then
        args[#args + 1] = "-r"
        args[#args + 1] = trim(remote)
    end
    args[#args + 1] = pattern
    local decoded, err = run_conan_json(context, args)
    if decoded == nil then
        return nil, err
    end
    return flatten_search_payload(decoded), nil
end

local function enrich_with_cache_path(context, item)
    if type(item) ~= "table" or item.installed ~= true then
        return item
    end

    local reference = trim(read_field(item, "packageId") or "")
    if reference == "" then
        return item
    end

    local decoded = select(1, run_conan_json(context, { "cache", "path", "--format=json", reference }))
    if type(decoded) ~= "table" then
        return item
    end

    item.extraFields = shallow_copy(item.extraFields)
    item.extraFields.cachePath = trim(read_field(decoded, "cache_path") or "")
    annotate_cppcache_fields(item, select(1, lookup_cppcache_pointer("conan", item.packageId or item.name)))
    return item
end

local function classify_conan_logical_path(relative_path)
    local cleaned = trim(relative_path)
    if cleaned == "" or cleaned:sub(-1) == "/" then
        return nil
    end
    if cleaned:match("^include/") or cleaned:match("^lib/") or cleaned:match("^bin/") or cleaned:match("^share/") then
        return {
            source_relative_path = cleaned,
            logical_path = cleaned,
        }
    end
    if cleaned:match("/cmake/") or cleaned:match("config%.cmake$") or cleaned:match("targets%.cmake$") then
        return {
            source_relative_path = cleaned,
            logical_path = join_path("share", cleaned),
        }
    end
    return {
        source_relative_path = cleaned,
        logical_path = join_path("share", "misc", cleaned),
    }
end

local function collect_conan_files(context, source_path)
    local result = run_command(context, "find " .. shell_quote(source_path) .. " -type f -printf '%P\\n'")
    if not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to inventory conan files")
    end
    local items = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local mapped = classify_conan_logical_path(line)
        if mapped ~= nil then
            items[#items + 1] = mapped
        end
    end
    return items, nil
end

local function sync_conan_cppcache(context, item)
    if type(item) ~= "table" or item.installed ~= true then
        return nil, nil
    end
    local reference = trim(read_field(item, "packageId") or read_field(item.extraFields or {}, "reference") or "")
    if reference == "" then
        return nil, nil
    end
    local decoded = select(1, run_conan_json(context, { "cache", "path", "--format=json", reference }))
    if type(decoded) ~= "table" then
        return nil, "conan cache path unavailable"
    end
    local source_path = trim(read_field(decoded, "cache_path") or "")
    if source_path == "" then
        return nil, "conan cache path empty"
    end
    local logical_files, files_error = collect_conan_files(context, source_path)
    if logical_files == nil then
        return nil, files_error
    end
    if #logical_files == 0 then
        return nil, "conan cache files unavailable"
    end
    local artifact_id = "conan/cpp-package/" .. normalize_token(reference) .. "@" .. normalize_token(first_nonempty(read_field(item.extraFields or {}, "packageRevision"), read_field(item.extraFields or {}, "recipeRevision"), item.version, "latest"))
    local pointer, err = sync_cppcache_artifact(context, "conan", reference, artifact_id, source_path, logical_files, {
        version = item.version,
        revision = first_nonempty(read_field(item.extraFields or {}, "packageRevision"), read_field(item.extraFields or {}, "recipeRevision")),
    })
    if pointer ~= nil then
        annotate_cppcache_fields(item, pointer)
    end
    return pointer, err
end

local function installed_matches(context, package)
    local reference = normalize_reference(package)
    if reference == "" then
        return false
    end
    local items = select(1, list_local_items(context, query_pattern_for_lookup(reference)))
    return type(items) == "table" and #items > 0
end

local function select_remote_for_package(context, package)
    local requested = trim(first_nonempty(flag_token_value(package, "remote"), read_field(package, "remote")))
    if requested ~= "" then
        return requested
    end
    return default_remote_name(context)
end

local function requested_query(package)
    return trim(first_nonempty(flag_token_value(package, "query"), read_field(package, "query")) or "")
end

local function requested_recipe_only(package)
    return has_flag(package, "recipe-only") or has_flag(package, "recipeOnly")
end

local function build_requested_item(package, remote)
    local reference = normalize_reference(package)
    local name, version = parse_reference(reference)
    return {
        name = name ~= "" and name or reference,
        packageId = reference,
        version = version ~= "" and version or nil,
        latestVersion = version ~= "" and version or nil,
        installed = true,
        status = "installed",
        packageType = "recipe",
        type = "package",
        repository = trim(remote or "") ~= "" and remote or nil,
        extraFields = {
            reference = reference,
            remote = remote,
            query = requested_query(package),
            recipeOnly = requested_recipe_only(package) and "true" or nil,
        },
    }
end

plugin.fileExtensions = { ".py" }

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
    return { "Package Manager", "Conan", "Wrapper" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if not command_exists(nil, REQUIRED_BINARY) then
        local missing = {}
        for _, package in ipairs(requested) do
            if lower(read_field(package, "action") or "") ~= "remove" and lower(read_field(package, "action") or "") ~= "update" then
                missing[#missing + 1] = package
            end
        end
        return missing
    end

    local pending = {}
    for _, package in ipairs(requested) do
        local action = lower(read_field(package, "action") or "install")
        local installed = installed_matches(nil, package)
        if action == "remove" then
            if installed then
                pending[#pending + 1] = package
            end
        elseif action == "update" then
        elseif not installed then
            pending[#pending + 1] = package
        end
    end
    return pending
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "conan not installed")
        emit_event(context, "unavailable", { reason = "conan-not-installed" })
        return false
    end

    local installed = {}
    for _, package in ipairs(requested) do
        local reference = normalize_reference(package)
        if reference == "" then
            tx_failed(context, "missing conan reference")
            return false
        end
        local remote = select_remote_for_package(context, package)
        if trim(remote or "") == "" then
            tx_failed(context, "no enabled Conan remote available")
            return false
        end

        local args = { "download", "--format=json", "-r", remote }
        local query = requested_query(package)
        if query ~= "" then
            args[#args + 1] = "--package-query=" .. query
        end
        if requested_recipe_only(package) then
            args[#args + 1] = "--only-recipe"
        end
        args[#args + 1] = reference

        begin_step(context, "download conan package")
        local _, err = run_conan(context, args)
        if err ~= nil then
            tx_failed(context, err)
            return false
        end
        local item = build_requested_item(package, remote)
        local _, cache_error = sync_conan_cppcache(context, item)
        if cache_error ~= nil and not is_benign_cppcache_warning(cache_error) then
            log_warn(context, cache_error)
        end
        installed[#installed + 1] = item
    end

    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local target = trim(path or "")
    if target == "" then
        tx_failed(context, "missing local Conan recipe path")
        return false
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "conan not installed")
        emit_event(context, "unavailable", { reason = "conan-not-installed" })
        return false
    end

    if lower(target):match("/conanfile%.py$") then
        target = dirname(target)
    end

    begin_step(context, "export local conan recipe")
    local decoded, err = run_conan_json(context, { "export", "--format=json", target })
    if decoded == nil then
        tx_failed(context, err)
        return false
    end

    local reference = trim(read_field(decoded, "reference") or "")
    local name, version = parse_reference(reference)
    local item = {
        name = name ~= "" and name or target,
        packageId = reference ~= "" and reference or target,
        version = version ~= "" and version or nil,
        latestVersion = version ~= "" and version or nil,
        installed = true,
        status = "installed",
        packageType = "recipe",
        type = "package",
        extraFields = {
            reference = reference,
            localTarget = "true",
            sourcePath = target,
        },
    }
    local logical_files, files_error = collect_conan_files(context, target)
    if logical_files == nil then
        tx_failed(context, files_error)
        return false
    end
    local _, cache_error = sync_cppcache_artifact(context, "conan", item.packageId, "conan/cpp-package/" .. normalize_token(item.packageId) .. "@exported", target, logical_files, {
        version = item.version,
        revision = "exported",
    })
    if cache_error ~= nil and not is_benign_cppcache_warning(cache_error) then
        log_warn(context, cache_error)
    end
    annotate_cppcache_fields(item, select(1, lookup_cppcache_pointer("conan", item.packageId)))
    emit_event(context, "installed", { item })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "conan not installed")
        emit_event(context, "unavailable", { reason = "conan-not-installed" })
        return false
    end

    local removed = {}
    for _, package in ipairs(requested) do
        local reference = normalize_reference(package)
        if reference == "" then
            tx_failed(context, "missing conan reference")
            return false
        end
        local args = { "remove", "--confirm" }
        local query = requested_query(package)
        if query ~= "" then
            args[#args + 1] = "--package-query=" .. query
        end
        args[#args + 1] = reference

        begin_step(context, "remove conan package")
        local _, err = run_conan(context, args)
        if err ~= nil then
            tx_failed(context, err)
            return false
        end
        local item = build_requested_item(package, nil)
        local _, cleanup_error = cleanup_cppcache_artifact(context, "conan", item.packageId)
        if cleanup_error ~= nil and not is_benign_cppcache_warning(cleanup_error) then
            log_warn(context, cleanup_error)
        end
        removed[#removed + 1] = item
    end

    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "conan not installed")
        emit_event(context, "unavailable", { reason = "conan-not-installed" })
        return false
    end

    local updated = {}
    for _, package in ipairs(requested) do
        local reference = normalize_reference(package)
        if reference == "" then
            tx_failed(context, "missing conan reference")
            return false
        end
        local remote = select_remote_for_package(context, package)
        if trim(remote or "") == "" then
            tx_failed(context, "no enabled Conan remote available")
            return false
        end

        local args = { "download", "--format=json", "-r", remote }
        local query = requested_query(package)
        if query ~= "" then
            args[#args + 1] = "--package-query=" .. query
        end
        if requested_recipe_only(package) then
            args[#args + 1] = "--only-recipe"
        end
        args[#args + 1] = reference

        begin_step(context, "update conan package")
        local _, err = run_conan(context, args)
        if err ~= nil then
            tx_failed(context, err)
            return false
        end
        local item = build_requested_item(package, remote)
        local _, cache_error = sync_conan_cppcache(context, item)
        if cache_error ~= nil and not is_benign_cppcache_warning(cache_error) then
            log_warn(context, cache_error)
        end
        updated[#updated + 1] = item
    end

    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    if not command_exists(context, REQUIRED_BINARY) then
        local cached = {}
        local root = cppcache_root()
        if root ~= nil then
            local result = run_command(context, "find " .. shell_quote(join_path(root, "views", "by-source", "conan")) .. " -type f -name current.json | LC_ALL=C sort")
            if is_command_success(result) then
                for _, line in ipairs(split_lines(result.stdout)) do
                    local pointer = select(1, decode_json_file(trim(line)))
                    local item = build_cppcache_item_from_pointer(pointer)
                    if item ~= nil then cached[#cached + 1] = item end
                end
            end
        end
        if #cached == 0 then
            emit_event(context, "unavailable", { reason = "conan-not-installed" })
        else
            emit_event(context, "listed", cached)
        end
        return cached
    end

    local items, err = list_local_items(context, "*")
    if items == nil then
        log_warn(context, err)
        return {}
    end
    for _, item in ipairs(items) do
        annotate_cppcache_fields(item, select(1, lookup_cppcache_pointer("conan", item.packageId or item.name)))
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    if command_exists(context, REQUIRED_BINARY) then
        log_warn(context, "Conan plugin v1 has no generic remote-aware outdated concept")
    else
        emit_event(context, "unavailable", { reason = "conan-not-installed" })
    end
    local items = {}
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned_prompt, remote = parse_prompt_options(prompt)
    local pattern = search_pattern_for_prompt(cleaned_prompt)
    if pattern == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    if not command_exists(context, REQUIRED_BINARY) then
        local cached = build_cppcache_item_from_pointer(select(1, lookup_cppcache_pointer("conan", cleaned_prompt)))
        if cached ~= nil then
            emit_event(context, "informed", cached)
            return cached
        end
        emit_event(context, "unavailable", { reason = "conan-not-installed" })
        return {}
    end

    local items, err = search_remote_items(context, pattern, remote)
    if items == nil then
        log_warn(context, err)
        return {}
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local cleaned_prompt, remote = parse_prompt_options(name)
    local pattern = query_pattern_for_lookup(cleaned_prompt)
    if cleaned_prompt == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    if not command_exists(context, REQUIRED_BINARY) then
        emit_event(context, "unavailable", { reason = "conan-not-installed" })
        return {}
    end

    local local_items = select(1, list_local_items(context, pattern)) or {}
    local local_item = exact_or_first(local_items, cleaned_prompt)
    if local_item ~= nil then
        local_item = enrich_with_cache_path(context, local_item)
        annotate_cppcache_fields(local_item, select(1, lookup_cppcache_pointer("conan", local_item.packageId or local_item.name)))
        emit_event(context, "informed", local_item)
        return local_item
    end

    local remote_items = select(1, search_remote_items(context, search_pattern_for_prompt(cleaned_prompt), remote)) or {}
    local remote_item = exact_or_first(remote_items, cleaned_prompt)
    if remote_item == nil then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    emit_event(context, "informed", remote_item)
    return remote_item
end

function plugin.resolvePackage(context, package)
    local reference = normalize_reference(package)
    if reference == "" then
        return nil
    end

    local local_item = exact_or_first(select(1, list_local_items(context, query_pattern_for_lookup(reference))) or {}, reference)
    if local_item ~= nil then
        return local_item
    end

    local remote = trim(flag_token_value(package, "remote") or "")
    local remote_item = exact_or_first(select(1, search_remote_items(context, search_pattern_for_prompt(reference), remote)) or {}, reference)
    if remote_item ~= nil then
        return remote_item
    end

    local name, version = parse_reference(reference)
    if name == "" then
        return nil
    end
    return {
        name = name,
        packageId = reference,
        version = version ~= "" and version or nil,
        latestVersion = version ~= "" and version or nil,
        packageType = "recipe",
        type = "package",
        extraFields = {
            reference = reference,
        },
    }
end

function plugin.init()
    return command_exists(nil, REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "conan", "cpp" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".conan2" },
        },
        networkScopes = {
            { scheme = "https" },
            { scheme = "http" },
        },
        privilegeLevel = "user",
        purlType = "conan",
        versionTokenPattern = "[A-Za-z0-9._+:-]+",
        versionCaseInsensitive = false,
    }
end

return plugin
