plugin = {}

local PLUGIN_ID = "vcpkg"
local PLUGIN_NAME = "vcpkg"
local PLUGIN_VERSION = "0.1.0"
local ENV_PREFIX = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C"
local JSON_NULL = {}
local unpack_values = table.unpack or unpack

local cached_json_decoder = nil

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function non_empty(value)
    local text = trim(value)
    if text == "" then
        return nil
    end
    return text
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

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function is_safe_token(value)
    return tostring(value or ""):match("^[A-Za-z0-9_./:@%%+=,-]+$") ~= nil
end

local function shell_arg(value)
    local text = tostring(value or "")
    if is_safe_token(text) then
        return text
    end
    return shell_quote(text)
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

local function log_message(context, level, message)
    if context == nil or context.log == nil then
        return
    end

    local fn = context.log[level]
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

local function run_global(command)
    if reqpack == nil or reqpack.exec == nil or type(reqpack.exec.run) ~= "function" then
        return {
            success = false,
            stdout = "",
            stderr = "reqpack.exec.run unavailable",
        }
    end

    return reqpack.exec.run(command)
end

local function make_exec_runner(context)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return function(command)
            return context.exec.run(command)
        end
    end
    return run_global
end

local function codepoint_to_utf8(codepoint)
    if codepoint <= 0x7F then
        return string.char(codepoint)
    end
    if codepoint <= 0x7FF then
        return string.char(
            0xC0 + math.floor(codepoint / 0x40),
            0x80 + (codepoint % 0x40)
        )
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
        elseif current:match("%d") ~= nil then
            repeat
                index = index + 1
                current = peek()
            until current == "" or current:match("%d") == nil
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

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        return non_empty(os.getenv(name))
    end
    return nil
end

local function dirname(path)
    local text = trim(path)
    if text == "" then
        return nil
    end
    return text:match("^(.*)/[^/]+$")
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

    local dir_handle = io.open(join_path(text, "."), "rb")
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

local function decode_json_file(path)
    local content = read_text_file(path)
    if content == nil then
        return nil, "failed to read file: " .. tostring(path)
    end
    return decode_json(content)
end

local function write_text_file(path, content)
    local handle, open_error = io.open(path, "wb")
    if handle == nil then
        return nil, open_error
    end
    local ok, write_error = handle:write(content)
    handle:close()
    if not ok then
        return nil, write_error
    end
    return true, nil
end

local function ensure_directory(context, path)
    local result = make_exec_runner(context)("mkdir -p " .. shell_quote(path))
    if result ~= nil and result.success then
        return true, nil
    end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to create directory: " .. tostring(path))
end

local function remove_path_if_exists(context, path)
    if not path_exists(path) then
        return true, nil
    end
    local result = make_exec_runner(context)("rm -rf " .. shell_quote(path))
    if result ~= nil and result.success then
        return true, nil
    end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to remove path: " .. tostring(path))
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
    local pairs_json = {}
    for _, key in ipairs(sorted_string_keys(value)) do
        pairs_json[#pairs_json + 1] = encode_json_string(key) .. ":" .. encode_json(value[key])
    end
    return "{" .. table.concat(pairs_json, ",") .. "}"
end

local function normalize_token(value)
    return tostring(value or ""):gsub("/", "__"):gsub("[^%w%._%-+:]+", "_")
end

local function detect_cppcache_format(logical_path)
    local path = lower(logical_path)
    if path:find("/include/", 1, true) ~= nil or path:match("^include/") then
        return "include"
    end
    if path:find("/pkgconfig/", 1, true) ~= nil or path:match("^lib/pkgconfig/") or path:match("^share/pkgconfig/") or path:match("%.pc$") then
        return "pkgconfig"
    end
    if path:find("/cmake/", 1, true) ~= nil or path:match("cmakelists%.txt$") or path:match("config%.cmake$") or path:match("targets%.cmake$") then
        return "cmake"
    end
    if path:match("^bin/") or path:find("/bin/", 1, true) ~= nil then
        return "bin"
    end
    if path:match("^lib/") or path:find("/lib/", 1, true) ~= nil then
        return "lib"
    end
    return "metadata"
end

local function current_timestamp_utc(context)
    local result = make_exec_runner(context)("date -u +%Y-%m-%dT%H:%M:%SZ")
    if result ~= nil and result.success then
        return trim(result.stdout), nil
    end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to capture timestamp")
end

local function sha256_digest_for_file(context, file_path)
    local exec_runner = make_exec_runner(context)
    local result = exec_runner("sha256sum " .. shell_quote(file_path))
    if result == nil or not result.success then
        result = exec_runner("shasum -a 256 " .. shell_quote(file_path))
    end
    if result == nil or not result.success then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to hash file: " .. file_path)
    end
    local digest = trim(result.stdout):match("^([0-9a-fA-F]+)")
    if digest == nil or #digest ~= 64 then
        return nil, "failed to parse sha256 for " .. file_path
    end
    return lower(digest), nil
end

local function file_size_for_path(context, file_path)
    local exec_runner = make_exec_runner(context)
    local result = exec_runner("stat -c %s " .. shell_quote(file_path))
    if result == nil or not result.success then
        result = exec_runner("stat -f %z " .. shell_quote(file_path))
    end
    if result == nil or not result.success then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to stat file: " .. file_path)
    end
    local size = tonumber(trim(result.stdout))
    if size == nil then
        return nil, "failed to parse file size for " .. file_path
    end
    return size, nil
end

local function file_link_count(context, file_path)
    if not path_exists(file_path) then
        return 0, nil
    end
    local exec_runner = make_exec_runner(context)
    local result = exec_runner("stat -c %h " .. shell_quote(file_path))
    if result == nil or not result.success then
        result = exec_runner("stat -f %l " .. shell_quote(file_path))
    end
    if result == nil or not result.success then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to stat link count: " .. file_path)
    end
    local count = tonumber(trim(result.stdout))
    if count == nil then
        return nil, "failed to parse link count for " .. file_path
    end
    return count, nil
end

local function adopt_blob(context, source_path, blob_path)
    if path_exists(blob_path) then
        return true, nil
    end
    local ok, err = ensure_directory(context, dirname(blob_path) or ".")
    if not ok then
        return nil, err
    end
    return materialize_file(context, source_path, blob_path)
end

local function materialize_file(context, source_path, target_path)
    local ok, err = ensure_directory(context, dirname(target_path) or ".")
    if not ok then
        return nil, err
    end
    if path_exists(target_path) then
        local removed, remove_error = remove_path_if_exists(context, target_path)
        if not removed then
            return nil, remove_error
        end
    end

    local exec_runner = make_exec_runner(context)
    local result = exec_runner("ln " .. shell_quote(source_path) .. " " .. shell_quote(target_path))
    if result ~= nil and result.success then
        return true, nil
    end
    result = exec_runner("cp " .. shell_quote(source_path) .. " " .. shell_quote(target_path))
    if result ~= nil and result.success then
        return true, nil
    end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to materialize file")
end

local function cppcache_root()
    local data_root = type(reqpack) == "table" and type(reqpack.paths) == "table" and non_empty(reqpack.paths.dataRoot) or nil
    if data_root ~= nil then
        return join_path(data_root, "cppcache")
    end
    local xdg_data_home = getenv("XDG_DATA_HOME")
    if xdg_data_home ~= nil then
        return join_path(xdg_data_home, "cppcache")
    end
    local home = getenv("HOME")
    if home ~= nil then
        return join_path(home, ".local", "share", "cppcache")
    end
    return nil
end

local function cppcache_current_path(root, registry, key)
    return join_path(root, "views", "by-source", registry, normalize_token(key), "current.json")
end

local function lookup_cppcache_pointer(registry, key)
    local root = cppcache_root()
    if root == nil then
        return nil, nil
    end
    local current_path = cppcache_current_path(root, registry, key)
    local content = read_text_file(current_path)
    if content == nil then
        return nil, nil
    end
    local decoded, err = decode_json(content)
    if decoded == nil then
        return nil, err
    end
    return decoded, nil
end

local function cppcache_artifact_paths(root, artifact_id, format, logical_path)
    return {
        kind = join_path(root, "views", "by-kind", "cpp-package", artifact_id, logical_path),
        format = join_path(root, "views", "by-format", format, artifact_id, logical_path),
    }
end

local function build_cppcache_item_from_pointer(registry, key, pointer)
    if type(pointer) ~= "table" then
        return nil
    end
    local artifact_path = trim(read_field(pointer, "artifact_path") or "")
    if artifact_path == "" then
        return nil
    end

    local manifest = select(1, decode_json_file(join_path(artifact_path, "manifest.json"))) or {}
    local source = type(read_field(manifest, "source")) == "table" and read_field(manifest, "source") or {}
    local source_meta = select(1, decode_json_file(join_path(artifact_path, "source.json"))) or {}
    local package_id = first_nonempty(read_field(source, "package_id"), key)
    local spec = parse_spec(package_id or "")

    local item = {
        name = first_nonempty(spec and spec.name, package_name_from_spec_text(package_id), package_id),
        packageId = package_id,
        version = first_nonempty(read_field(source, "version"), read_field(source_meta, "version")),
        latestVersion = first_nonempty(read_field(source, "version"), read_field(source_meta, "version")),
        installed = true,
        status = "installed",
        packageType = "port",
        type = "package",
        extraFields = {},
    }
    if spec ~= nil and spec.triplet ~= nil then
        item.extraFields.triplet = spec.triplet
    end
    annotate_cppcache_fields(item, pointer)
    return item
end

local function list_cppcache_items(registry)
    local root = cppcache_root()
    if root == nil then
        return {}, nil
    end
    local base = join_path(root, "views", "by-source", registry)
    if not path_exists(base) then
        return {}, nil
    end

    local result = make_exec_runner(nil)("find " .. shell_quote(base) .. " -type f -name current.json | LC_ALL=C sort")
    if result == nil or not result.success then
        return {}, first_nonempty(result and result.stderr, result and result.stdout, "failed to list cppcache pointers")
    end

    local items = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local pointer = select(1, decode_json_file(trim(line)))
        local item = build_cppcache_item_from_pointer(registry, nil, pointer)
        if item ~= nil then
            items[#items + 1] = item
        end
    end
    return items, nil
end

local function annotate_cppcache_fields(item, pointer)
    if type(item) ~= "table" or type(pointer) ~= "table" then
        return item
    end
    item.extraFields = merge_extra_fields(item.extraFields, {
        cppcacheArtifactId = read_field(pointer, "artifact_id"),
        cppcacheArtifactPath = read_field(pointer, "artifact_path"),
        cppcachePrefixPath = read_field(pointer, "prefix_path"),
        cppcacheSourcePath = read_field(pointer, "source_path"),
        cppcacheRoot = cppcache_root(),
    })
    return item
end

local function write_cppcache_pointer(context, root, registry, key, payload)
    local path = cppcache_current_path(root, registry, key)
    local ok, err = ensure_directory(context, dirname(path) or ".")
    if not ok then
        return nil, err
    end
    return write_text_file(path, encode_json(payload))
end

local function sync_cppcache_artifact(context, registry, package_key, artifact_id, source_path, logical_files, source_metadata)
    local root = cppcache_root()
    if root == nil then
        return nil, "cppcache root unavailable"
    end
    if source_path == nil or source_path == "" then
        return nil, "cppcache source path unavailable"
    end
    if type(logical_files) ~= "table" or #logical_files == 0 then
        return nil, "cppcache file inventory empty"
    end

    local artifact_path = join_path(root, "artifacts", artifact_id)
    local prefix_path = join_path(root, "prefixes", artifact_id)
    local blobs_root = join_path(root, "blobs", "sha256")
    for _, path in ipairs({ root, join_path(root, "artifacts"), join_path(root, "prefixes"), join_path(root, "views"), join_path(root, "views", "by-source"), join_path(root, "views", "by-source", registry), join_path(root, "views", "by-kind"), join_path(root, "views", "by-format"), blobs_root, artifact_path, prefix_path }) do
        local ok, err = ensure_directory(context, path)
        if not ok then
            return nil, err
        end
    end

    local created_at, timestamp_error = current_timestamp_utc(context)
    if created_at == nil then
        return nil, timestamp_error
    end

    local files = {}
    for _, entry in ipairs(logical_files) do
        local source_file = join_path(source_path, entry.source_relative_path)
        local digest, digest_error = sha256_digest_for_file(context, source_file)
        if digest == nil then
            return nil, digest_error
        end
        local size, size_error = file_size_for_path(context, source_file)
        if size == nil then
            return nil, size_error
        end
        local format = detect_cppcache_format(entry.logical_path)
        local blob_path = join_path(blobs_root, digest:sub(1, 2), digest)
        local ok, err = adopt_blob(context, source_file, blob_path)
        if not ok then
            return nil, err
        end
        local prefix_file = join_path(prefix_path, entry.logical_path)
        ok, err = materialize_file(context, blob_path, prefix_file)
        if not ok then
            return nil, err
        end
        local view_paths = cppcache_artifact_paths(root, artifact_id, format, entry.logical_path)
        ok, err = materialize_file(context, blob_path, view_paths.kind)
        if not ok then
            return nil, err
        end
        ok, err = materialize_file(context, blob_path, view_paths.format)
        if not ok then
            return nil, err
        end
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

    local manifest = {
        artifact_id = artifact_id,
        kind = "cpp-package",
        source = {
            registry = registry,
            package_id = package_key,
            version = read_field(source_metadata, "version"),
            revision = read_field(source_metadata, "revision"),
        },
        created_at = created_at,
    }
    local source_json = merge_extra_fields(source_metadata, {
        fetched_at = created_at,
        source_cache_paths = { source_path },
        managed_source_cache = false,
    })

    local ok, err = ensure_directory(context, dirname(join_path(artifact_path, "manifest.json")) or ".")
    if not ok then
        return nil, err
    end
    ok, err = write_text_file(join_path(artifact_path, "manifest.json"), encode_json(manifest))
    if not ok then
        return nil, err
    end
    ok, err = write_text_file(join_path(artifact_path, "files.json"), encode_json({ files = files }))
    if not ok then
        return nil, err
    end
    ok, err = write_text_file(join_path(artifact_path, "source.json"), encode_json(source_json))
    if not ok then
        return nil, err
    end

    local pointer = {
        artifact_id = artifact_id,
        artifact_path = artifact_path,
        prefix_path = prefix_path,
        source_path = source_path,
    }
    ok, err = write_cppcache_pointer(context, root, registry, package_key, pointer)
    if not ok then
        return nil, err
    end
    return pointer, nil
end

local function cleanup_cppcache_artifact(context, registry, package_key)
    local pointer = select(1, lookup_cppcache_pointer(registry, package_key))
    if type(pointer) ~= "table" then
        return true, nil
    end
    local root = cppcache_root() or ""
    local current_path = cppcache_current_path(root, registry, package_key)
    local artifact_path = read_field(pointer, "artifact_path") or ""
    local files_payload = artifact_path ~= "" and select(1, decode_json_file(join_path(artifact_path, "files.json"))) or nil
    local ok, err = remove_path_if_exists(context, current_path)
    if not ok then
        return nil, err
    end
    local format_dirs = {}
    for _, entry in ipairs(type(files_payload) == "table" and (read_field(files_payload, "files") or {}) or {}) do
        local kind_view = trim(read_field(entry, "kind_view_path") or "")
        local format_view = trim(read_field(entry, "format_view_path") or "")
        local blob_path = trim(read_field(entry, "blob_path") or "")
        if kind_view ~= "" then
            ok, err = remove_path_if_exists(context, kind_view)
            if not ok then return nil, err end
        end
        if format_view ~= "" then
            ok, err = remove_path_if_exists(context, format_view)
            if not ok then return nil, err end
            format_dirs[dirname(format_view)] = true
        end
        if blob_path ~= "" then
            local count, count_error = file_link_count(context, blob_path)
            if count == nil then
                return nil, count_error
            end
            if count <= 1 then
                ok, err = remove_path_if_exists(context, blob_path)
                if not ok then return nil, err end
            end
        end
    end
    ok, err = remove_path_if_exists(context, artifact_path)
    if not ok then
        return nil, err
    end
    ok, err = remove_path_if_exists(context, read_field(pointer, "prefix_path") or "")
    if not ok then
        return nil, err
    end
    return true, nil
end

local function split_lines(value)
    local lines = {}
    for line in tostring(value or ""):gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end
    return lines
end

local function split_csv(value)
    local items = {}
    for token in tostring(value or ""):gmatch("[^,]+") do
        local text = trim(token)
        if text ~= "" then
            items[#items + 1] = text
        end
    end
    return items
end

local function unique_strings(values)
    local items = {}
    local seen = {}
    for _, value in ipairs(values or {}) do
        local text = trim(value)
        if text ~= "" and not seen[text] then
            seen[text] = true
            items[#items + 1] = text
        end
    end
    return items
end

local function build_command(binary, args)
    local parts = { ENV_PREFIX, shell_arg(binary) }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = shell_arg(arg)
    end
    return table.concat(parts, " ")
end

local function detect_vcpkg_binary(exec_runner)
    local result = exec_runner("command -v vcpkg 2>/dev/null")
    if result ~= nil and result.success then
        local binary = trim(result.stdout)
        if binary ~= "" then
            return binary
        end
    end
    return nil
end

local function run_vcpkg(context, args, options)
    options = options or {}
    local exec_runner = options.exec_runner or make_exec_runner(context)
    local binary = options.binary or detect_vcpkg_binary(exec_runner)
    if binary == nil then
        return nil, "vcpkg not installed", nil
    end

    local command = build_command(binary, args)
    return exec_runner(command), nil, command
end

local function parse_spec(text)
    local cleaned = trim(text)
    if cleaned == "" then
        return nil
    end

    local spec = {
        raw = cleaned,
        name = cleaned,
        features = {},
        triplet = nil,
        host = false,
    }

    local base, suffix = cleaned:match("^(.-):([^:]+)$")
    if base ~= nil and suffix ~= nil and base ~= "" then
        cleaned = base
        if suffix == "host" then
            spec.host = true
        else
            spec.triplet = suffix
        end
    end

    local name, features = cleaned:match("^(.-)%[([^%]]+)%]$")
    if name ~= nil then
        spec.name = trim(name)
        spec.features = split_csv(features)
    else
        spec.name = trim(cleaned)
    end

    if spec.name == "" then
        return nil
    end
    return spec
end

local function render_spec(spec)
    if spec == nil or non_empty(spec.name) == nil then
        return nil
    end

    local rendered = spec.name
    if type(spec.features) == "table" and #spec.features > 0 then
        rendered = rendered .. "[" .. table.concat(spec.features, ",") .. "]"
    end
    if spec.host then
        rendered = rendered .. ":host"
    elseif non_empty(spec.triplet) ~= nil then
        rendered = rendered .. ":" .. spec.triplet
    end
    return rendered
end

local function parse_package_request(pkg)
    local identifier = first_nonempty(read_field(pkg, "packageId"), read_field(pkg, "name"))
    local spec = parse_spec(identifier or "") or {
        name = trim(identifier or ""),
        features = {},
        triplet = nil,
        host = false,
    }

    spec.head = false
    spec.recurse = false
    spec.editable = false
    spec.allow_unsupported = false

    local flags = read_field(pkg, "flags")
    if type(flags) == "table" then
        for _, flag in ipairs(flags) do
            local text = trim(flag)
            local key, value = text:match("^([%w%-_]+)=(.+)$")
            if key == "triplet" then
                spec.triplet = trim(value)
                spec.host = false
            elseif key == "features" then
                spec.features = split_csv(value)
            elseif text == "host" then
                spec.host = true
                spec.triplet = nil
            elseif text == "head" then
                spec.head = true
            elseif text == "recurse" then
                spec.recurse = true
            elseif text == "editable" then
                spec.editable = true
            elseif text == "allow-unsupported" then
                spec.allow_unsupported = true
            end
        end
    end

    spec.name = trim(spec.name or "")
    spec.packageId = render_spec(spec)
    return spec
end

local function package_name_from_spec_text(spec_text)
    local spec = parse_spec(spec_text or "")
    if spec == nil then
        return nil
    end
    return spec.name
end

local function compose_version(record)
    local version = first_nonempty(
        json_value(read_field(record, "version")),
        json_value(read_field(record, "version-string")),
        json_value(read_field(record, "version-semver")),
        json_value(read_field(record, "version-date"))
    )
    local port_version = tonumber(read_field(record, "port-version"))
    if version ~= nil and port_version ~= nil and port_version > 0 and not tostring(version):find("#", 1, true) then
        return tostring(version) .. "#" .. tostring(port_version)
    end
    return version
end

local function to_string_array(value)
    local items = {}
    if type(value) ~= "table" then
        return items
    end
    for _, item in ipairs(value) do
        if type(item) == "string" then
            local text = trim(item)
            if text ~= "" then
                items[#items + 1] = text
            end
        elseif type(item) == "table" then
            local text = first_nonempty(read_field(item, "name"), read_field(item, "package"), read_field(item, "dependency"))
            if text ~= nil then
                items[#items + 1] = text
            end
        end
    end
    return unique_strings(items)
end

local function description_text(value)
    if type(value) == "string" then
        return non_empty(value)
    end
    if type(value) ~= "table" then
        return nil
    end

    local parts = {}
    for _, item in ipairs(value) do
        local text = non_empty(item)
        if text ~= nil then
            parts[#parts + 1] = text
        end
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, " ")
end

local function infer_shared_paths(binary)
    local root = getenv("VCPKG_ROOT")
    local downloads = getenv("VCPKG_DOWNLOADS")
    local binary_cache = getenv("VCPKG_DEFAULT_BINARY_CACHE")
    local xdg_cache_home = getenv("XDG_CACHE_HOME")
    local home = getenv("HOME")

    if downloads == nil and root ~= nil then
        downloads = join_path(root, "downloads")
    end
    if binary_cache == nil then
        if xdg_cache_home ~= nil then
            binary_cache = join_path(xdg_cache_home, "vcpkg", "archives")
        elseif home ~= nil then
            binary_cache = join_path(home, ".cache", "vcpkg", "archives")
        end
    end

    return {
        binary = binary,
        vcpkgRoot = root,
        downloadsRoot = downloads,
        binaryCacheRoot = binary_cache,
        installRoot = root ~= nil and join_path(root, "installed") or nil,
    }
end

local function classify_vcpkg_owned_path(path)
    local cleaned = trim(path)
    if cleaned == "" or cleaned:sub(-1) == "/" then
        return nil
    end

    local relative = cleaned:gsub("^[^/]+/", "", 1)
    if relative == "" or relative:match("^debug/") then
        return nil
    end
    if relative:match("^tools/") then
        return {
            source_relative_path = cleaned,
            logical_path = join_path("bin", relative:gsub("^tools/[^/]+/?", "")),
        }
    end
    if relative:match("^include/") or relative:match("^lib/") or relative:match("^bin/") or relative:match("^share/") then
        return {
            source_relative_path = cleaned,
            logical_path = relative,
        }
    end
    return {
        source_relative_path = cleaned,
        logical_path = join_path("share", "misc", relative),
    }
end

local function sync_vcpkg_cppcache(context, item, binary)
    if type(item) ~= "table" or item.installed ~= true then
        return nil, nil
    end

    local package_id = trim(item.packageId or "")
    local cache_paths = infer_shared_paths(binary)
    if package_id == "" or cache_paths.installRoot == nil then
        return nil, nil
    end

    local info_map, info_error = query_package_info(context, { package_id }, { binary = binary, installed = true })
    if info_map == nil then
        return nil, info_error
    end
    local info_item = info_map[package_id]
    local owns = type(info_item) == "table" and type(info_item.extraFields) == "table" and info_item.extraFields.owns or nil
    if type(owns) ~= "table" then
        return nil, "vcpkg owned files unavailable"
    end

    local logical_files = {}
    for _, owned in ipairs(owns) do
        local mapped = classify_vcpkg_owned_path(owned)
        if mapped ~= nil and path_exists(join_path(cache_paths.installRoot, mapped.source_relative_path)) then
            logical_files[#logical_files + 1] = mapped
        end
    end
    if #logical_files == 0 then
        return nil, "vcpkg owned files not present in install tree"
    end

    local artifact_id = "vcpkg/cpp-package/" .. normalize_token(package_id) .. "@" .. normalize_token(first_nonempty(item.extraFields and item.extraFields.abi, item.latestVersion, item.version, "unknown"))
    local pointer, err = sync_cppcache_artifact(context, "vcpkg", package_id, artifact_id, cache_paths.installRoot, logical_files, {
        version = first_nonempty(item.latestVersion, item.version),
        revision = item.extraFields and item.extraFields.abi or nil,
    })
    if pointer ~= nil then
        annotate_cppcache_fields(item, pointer)
    end
    return pointer, err
end

local function attach_common_metadata(item, cache_paths)
    if type(item) ~= "table" then
        return item
    end

    local extra = merge_extra_fields(item.extraFields, {
        installMode = "classic",
        cacheId = first_nonempty(item.packageId, item.name),
    })

    if type(cache_paths) == "table" then
        if cache_paths.binary ~= nil then
            extra.vcpkgBinary = cache_paths.binary
        end
        if cache_paths.vcpkgRoot ~= nil then
            extra.vcpkgRoot = cache_paths.vcpkgRoot
        end
        if cache_paths.downloadsRoot ~= nil then
            extra.downloadsRoot = cache_paths.downloadsRoot
        end
        if cache_paths.binaryCacheRoot ~= nil then
            extra.binaryCacheRoot = cache_paths.binaryCacheRoot
        end
        if cache_paths.installRoot ~= nil then
            extra.installRoot = cache_paths.installRoot
        end
    end

    item.extraFields = extra
    return item
end

local function map_package_info_record(key, record, cache_paths)
    local spec = parse_spec(key or "") or parse_spec(first_nonempty(read_field(record, "name"), key) or "")
    local package_id = key
    if spec ~= nil and (package_id == nil or trim(package_id) == "") then
        package_id = render_spec(spec)
    end

    local item = {
        name = first_nonempty(read_field(record, "name"), spec and spec.name or nil),
        packageId = package_id,
        version = compose_version(record),
        latestVersion = compose_version(record),
        summary = first_nonempty(description_text(read_field(record, "summary")), description_text(read_field(record, "description"))),
        description = description_text(read_field(record, "description")) or description_text(read_field(record, "summary")),
        homepage = first_nonempty(read_field(record, "homepage"), read_field(record, "documentation")),
        dependencies = to_string_array(read_field(record, "dependencies")),
        packageType = "port",
        type = "package",
        installed = non_empty(read_field(record, "triplet")) ~= nil,
        status = non_empty(read_field(record, "triplet")) ~= nil and "installed" or "available",
        extraFields = {},
    }

    local triplet = first_nonempty(read_field(record, "triplet"), spec and spec.triplet or nil)
    if triplet ~= nil then
        item.extraFields.triplet = triplet
        item.packageId = (spec and spec.name or item.name) .. ":" .. triplet
    end
    if spec ~= nil and #spec.features > 0 then
        item.extraFields.features = table.concat(spec.features, ",")
    end
    if spec ~= nil and spec.host then
        item.extraFields.host = "true"
    end
    if read_field(record, "license") ~= nil then
        item.license = description_text(read_field(record, "license")) or first_nonempty(read_field(record, "license"))
    end
    if read_field(record, "abi") ~= nil then
        item.extraFields.abi = trim(read_field(record, "abi"))
    end
    local owns = to_string_array(read_field(record, "owns"))
    if #owns > 0 then
        item.extraFields.owns = owns
    end

    return attach_common_metadata(item, cache_paths)
end

local function query_package_info(context, identifiers, options)
    options = options or {}
    if identifiers == nil or #identifiers == 0 then
        return {}, nil
    end

    local args = { "x-package-info", "--x-json" }
    if options.installed then
        args[#args + 1] = "--x-installed"
    end
    for _, identifier in ipairs(identifiers) do
        args[#args + 1] = identifier
    end

    local result, err, _ = run_vcpkg(context, args, options)
    if result == nil then
        return nil, err
    end
    if not result.success then
        return nil, first_nonempty(result.stderr, result.stdout, "vcpkg x-package-info failed")
    end

    local payload, decode_error = decode_json(result.stdout)
    if payload == nil then
        return nil, decode_error
    end

    local mapped = {}
    local results = json_value(read_field(payload, "results"))
    local cache_paths = infer_shared_paths(options.binary)
    if type(results) ~= "table" then
        return mapped, nil
    end

    for key, record in pairs(results) do
        if type(record) == "table" then
            mapped[tostring(key)] = map_package_info_record(tostring(key), record, cache_paths)
        end
    end
    return mapped, nil
end

local function parse_search_line(line, cache_paths)
    local name, version, description = line:match("^(%S+)%s+(%S+)%s+(.+)$")
    if name == nil then
        name, version = line:match("^(%S+)%s+(%S+)$")
    end
    if name == nil or version == nil then
        return nil
    end

    return attach_common_metadata({
        name = name,
        packageId = name,
        version = version,
        latestVersion = version,
        installed = false,
        status = "available",
        summary = description,
        description = description,
        packageType = "port",
        type = "package",
        extraFields = {},
    }, cache_paths)
end

local function parse_list_line(line, cache_paths)
    local spec_text, version, description = line:match("^(%S+)%s+(%S+)%s+(.+)$")
    if spec_text == nil then
        spec_text, version = line:match("^(%S+)%s+(%S+)$")
    end
    if spec_text == nil or version == nil then
        return nil
    end

    local spec = parse_spec(spec_text)
    local item = {
        name = spec and spec.name or spec_text,
        packageId = spec_text,
        version = version,
        latestVersion = version,
        installed = true,
        status = "installed",
        summary = description,
        description = description,
        packageType = "port",
        type = "package",
        extraFields = {},
    }
    if spec ~= nil then
        if spec.triplet ~= nil then
            item.extraFields.triplet = spec.triplet
        end
        if spec.host then
            item.extraFields.host = "true"
        end
        if #spec.features > 0 then
            item.extraFields.features = table.concat(spec.features, ",")
        end
    end

    return attach_common_metadata(item, cache_paths)
end

local function parse_update_line(line, cache_paths)
    local spec_text, version, latest_version, description = line:match("^%s*(%S+)%s+(%S+)%s+%-%>%s+(%S+)%s*(.*)$")
    if spec_text == nil or version == nil or latest_version == nil then
        return nil
    end

    local spec = parse_spec(spec_text)
    local item = {
        name = spec and spec.name or spec_text,
        packageId = spec_text,
        version = version,
        latestVersion = latest_version,
        installed = true,
        status = "outdated",
        summary = non_empty(description),
        description = non_empty(description),
        packageType = "port",
        type = "package",
        extraFields = {},
    }
    if spec ~= nil and spec.triplet ~= nil then
        item.extraFields.triplet = spec.triplet
    end

    return attach_common_metadata(item, cache_paths)
end

local function merge_items(base, enrich)
    if base == nil then
        return enrich
    end
    if enrich == nil then
        return base
    end

    local merged = shallow_copy(base)
    for key, value in pairs(enrich) do
        if key ~= "installed" and key ~= "status" and key ~= "version" and key ~= "latestVersion" and key ~= "packageId" then
            if value ~= nil and value ~= "" and value ~= JSON_NULL then
                merged[key] = value
            end
        end
    end

    merged.version = first_nonempty(base.version, enrich.version)
    merged.latestVersion = first_nonempty(base.latestVersion, enrich.latestVersion, enrich.version)
    merged.packageId = first_nonempty(base.packageId, enrich.packageId)
    merged.installed = base.installed == true or enrich.installed == true
    merged.status = base.status or enrich.status
    if merged.installed and merged.latestVersion ~= nil and merged.version ~= nil and merged.latestVersion ~= merged.version then
        merged.status = "outdated"
    elseif merged.installed then
        merged.status = "installed"
    else
        merged.status = merged.status or "available"
    end
    merged.extraFields = merge_extra_fields(base.extraFields, enrich.extraFields)
    return merged
end

local function enrich_by_name(context, items, options)
    if items == nil or #items == 0 then
        return items
    end

    local names = {}
    for _, item in ipairs(items) do
        if non_empty(item.name) ~= nil then
            names[#names + 1] = item.name
        end
    end
    names = unique_strings(names)
    if #names == 0 then
        return items
    end

    local info_map, err = query_package_info(context, names, options)
    if info_map == nil then
        log_message(context, "warn", "vcpkg metadata enrichment failed: " .. tostring(err))
        return items
    end

    local enriched = {}
    for _, item in ipairs(items) do
        local merged = merge_items(item, info_map[item.name])
        annotate_cppcache_fields(merged, select(1, lookup_cppcache_pointer("vcpkg", merged.packageId or merged.name)))
        enriched[#enriched + 1] = merged
    end
    return enriched
end

local function query_text_items(context, args, parser)
    local result, err, _ = run_vcpkg(context, args)
    if result == nil then
        return nil, err
    end
    if not result.success then
        return nil, first_nonempty(result.stderr, result.stdout, "vcpkg command failed")
    end

    local binary = detect_vcpkg_binary(make_exec_runner(context))
    local cache_paths = infer_shared_paths(binary)
    local items = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local item = parser(line, cache_paths)
        if item ~= nil then
            items[#items + 1] = item
        end
    end
    return items, nil
end

local function query_list_items(context)
    local items, err = query_text_items(context, { "list", "--classic", "--x-full-desc" }, parse_list_line)
    if items == nil then
        return nil, err
    end
    return enrich_by_name(context, items), nil
end

local function query_outdated_items(context)
    local items, err = query_text_items(context, { "update", "--classic" }, parse_update_line)
    if items == nil then
        return nil, err
    end
    return enrich_by_name(context, items), nil
end

local function query_search_items(context, prompt)
    local items, err = query_text_items(context, { "search", "--x-full-desc", prompt }, parse_search_line)
    if items == nil then
        return nil, err
    end
    return enrich_by_name(context, items), nil
end

local function matches_request(item, request)
    if item == nil or request == nil then
        return false
    end
    if request.triplet ~= nil or request.host then
        return item.packageId == request.packageId
    end
    return item.name == request.name
end

local function find_matching_item(items, request)
    for _, item in ipairs(items or {}) do
        if matches_request(item, request) then
            return item
        end
    end
    return nil
end

local function mutation_args(command, request)
    local args = { command, "--classic" }
    if command == "install" then
        args[#args + 1] = "--recurse"
    elseif command == "remove" then
        args[#args + 1] = "--recurse"
    end
    if request.allow_unsupported then
        args[#args + 1] = "--allow-unsupported"
    end
    if request.head then
        args[#args + 1] = "--head"
    end
    if request.editable then
        args[#args + 1] = "--editable"
    end
    args[#args + 1] = request.packageId or request.name
    return args
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
    return { "Package Manager", "C++", "Wrapper" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    local exec_runner = run_global
    local binary = detect_vcpkg_binary(exec_runner)
    if binary == nil then
        local missing = {}
        for _, pkg in ipairs(requested) do
            local action = lower(read_field(pkg, "action") or "")
            if action ~= "remove" and action ~= "update" then
                missing[#missing + 1] = pkg
            end
        end
        return missing
    end

    local installed_items = query_list_items(nil) or {}
    local outdated_items = query_outdated_items(nil) or {}
    local missing = {}

    for _, pkg in ipairs(requested) do
        local request = parse_package_request(pkg)
        local action = lower(read_field(pkg, "action") or "install")
        local is_installed = false
        local is_outdated = false

        for _, item in ipairs(installed_items) do
            if matches_request(item, request) then
                is_installed = true
                break
            end
        end
        for _, item in ipairs(outdated_items) do
            if matches_request(item, request) then
                is_outdated = true
                break
            end
        end

        if action == "remove" then
            if is_installed then
                missing[#missing + 1] = pkg
            end
        elseif action == "update" then
            if is_outdated then
                missing[#missing + 1] = pkg
            end
        elseif not is_installed then
            missing[#missing + 1] = pkg
        end
    end

    return missing
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    local binary = detect_vcpkg_binary(make_exec_runner(context))
    if binary == nil then
        tx_failed(context, "vcpkg not installed")
        emit_event(context, "unavailable", { reason = "vcpkg-not-installed" })
        return false
    end

    begin_step(context, "install vcpkg packages")
    for _, pkg in ipairs(requested) do
        local request = parse_package_request(pkg)
        local result, err = run_vcpkg(context, mutation_args("install", request), { binary = binary })
        if result == nil or not result.success then
            local message = first_nonempty(err, result and result.stderr, result and result.stdout, "vcpkg install failed")
            tx_failed(context, message)
            return false
        end

        local installed_item = find_matching_item(query_list_items(context) or {}, request)
        if type(installed_item) == "table" and non_empty(installed_item.name) ~= nil then
            local _, cache_error = sync_vcpkg_cppcache(context, installed_item, binary)
            if cache_error ~= nil and not is_benign_cppcache_warning(cache_error) then
                log_message(context, "warn", cache_error)
            end
        end
    end

    emit_event(context, "installed", requested)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    begin_step(context, "install local vcpkg artifact")
    tx_failed(context, "vcpkg local installs are not supported")
    emit_event(context, "unavailable", {
        path = path,
        reason = "local-install-unsupported",
    })
    return false
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    local binary = detect_vcpkg_binary(make_exec_runner(context))
    if binary == nil then
        tx_failed(context, "vcpkg not installed")
        emit_event(context, "unavailable", { reason = "vcpkg-not-installed" })
        return false
    end

    begin_step(context, "remove vcpkg packages")
    for _, pkg in ipairs(requested) do
        local request = parse_package_request(pkg)
        local removed_item = find_matching_item(query_list_items(context) or {}, request)
        local result, err = run_vcpkg(context, mutation_args("remove", request), { binary = binary })
        if result == nil or not result.success then
            local message = first_nonempty(err, result and result.stderr, result and result.stdout, "vcpkg remove failed")
            tx_failed(context, message)
            return false
        end

        if type(removed_item) == "table" and non_empty(removed_item.name) ~= nil then
            local _, cleanup_error = cleanup_cppcache_artifact(context, "vcpkg", removed_item.packageId or removed_item.name)
            if cleanup_error ~= nil and not is_benign_cppcache_warning(cleanup_error) then
                log_message(context, "warn", cleanup_error)
            end
        end
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    local binary = detect_vcpkg_binary(make_exec_runner(context))
    if binary == nil then
        tx_failed(context, "vcpkg not installed")
        emit_event(context, "unavailable", { reason = "vcpkg-not-installed" })
        return false
    end

    begin_step(context, "update vcpkg packages")
    if #requested == 0 then
        local result, err = run_vcpkg(context, { "upgrade", "--classic", "--no-dry-run" }, { binary = binary })
        if result == nil or not result.success then
            local message = first_nonempty(err, result and result.stderr, result and result.stdout, "vcpkg upgrade failed")
            tx_failed(context, message)
            return false
        end
        emit_event(context, "updated", {})
        tx_success(context)
        return true
    end

    for _, pkg in ipairs(requested) do
        local request = parse_package_request(pkg)
        local result, err = run_vcpkg(context, mutation_args("install", request), { binary = binary })
        if result == nil or not result.success then
            local message = first_nonempty(err, result and result.stderr, result and result.stdout, "vcpkg targeted update failed")
            tx_failed(context, message)
            return false
        end

        local installed_item = find_matching_item(query_list_items(context) or {}, request)
        if type(installed_item) == "table" and non_empty(installed_item.name) ~= nil then
            local _, cache_error = sync_vcpkg_cppcache(context, installed_item, binary)
            if cache_error ~= nil and not is_benign_cppcache_warning(cache_error) then
                log_message(context, "warn", cache_error)
            end
        end
    end

    emit_event(context, "updated", requested)
    tx_success(context)
    return true
end

function plugin.list(context)
    local binary = detect_vcpkg_binary(make_exec_runner(context))
    if binary == nil then
        local cached = select(1, list_cppcache_items("vcpkg")) or {}
        if #cached == 0 then
            emit_event(context, "unavailable", { reason = "vcpkg-not-installed" })
        else
            emit_event(context, "listed", cached)
        end
        return cached
    end

    local items, err = query_list_items(context)
    if items == nil then
        log_message(context, "warn", "vcpkg list failed: " .. tostring(err))
        emit_event(context, "unavailable", { reason = err })
        return {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local binary = detect_vcpkg_binary(make_exec_runner(context))
    if binary == nil then
        local pointer = select(1, lookup_cppcache_pointer("vcpkg", requested))
        local cached = build_cppcache_item_from_pointer("vcpkg", requested, pointer)
        if cached ~= nil then
            emit_event(context, "informed", cached)
            return cached
        end
        emit_event(context, "unavailable", { reason = "vcpkg-not-installed" })
        return {}
    end

    local items, err = query_outdated_items(context)
    if items == nil then
        log_message(context, "warn", "vcpkg update query failed: " .. tostring(err))
        emit_event(context, "unavailable", { reason = err })
        return {}
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    if non_empty(prompt) == nil then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local binary = detect_vcpkg_binary(make_exec_runner(context))
    if binary == nil then
        emit_event(context, "unavailable", { reason = "vcpkg-not-installed" })
        return {}
    end

    local items, err = query_search_items(context, trim(prompt))
    if items == nil then
        log_message(context, "warn", "vcpkg search failed: " .. tostring(err))
        emit_event(context, "unavailable", { reason = err })
        return {}
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local requested = trim(name)
    if requested == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local binary = detect_vcpkg_binary(make_exec_runner(context))
    if binary == nil then
        emit_event(context, "unavailable", { reason = "vcpkg-not-installed" })
        return {}
    end

    local spec = parse_spec(requested)
    local info_map, err = nil, nil
    if spec ~= nil and (spec.triplet ~= nil or spec.host) then
        info_map, err = query_package_info(context, { render_spec(spec) }, { binary = binary, installed = true })
    else
        info_map, err = query_package_info(context, { spec and spec.name or requested }, { binary = binary })
    end

    if info_map == nil then
        emit_event(context, "unavailable", { reason = err, name = requested })
        return {}
    end

    local item = info_map[requested]
    if item == nil and spec ~= nil then
        item = info_map[render_spec(spec)] or info_map[spec.name]
    end
    if item == nil then
        emit_event(context, "unavailable", { reason = "package-not-found", name = requested })
        return {}
    end

    if spec ~= nil and spec.triplet == nil and not spec.host then
        local listed = query_list_items(context)
        if type(listed) == "table" then
            for _, installed_item in ipairs(listed) do
                if installed_item.name == item.name then
                    item = merge_items(installed_item, item)
                    break
                end
            end
        end
    end

    annotate_cppcache_fields(item, select(1, lookup_cppcache_pointer("vcpkg", item.packageId or item.name)))

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if package == nil or read_field(package, "localTarget") == true or non_empty(read_field(package, "sourcePath")) ~= nil then
        return nil
    end

    local request = parse_package_request(package)
    if request == nil or non_empty(request.name) == nil then
        return nil
    end

    local item = plugin.info(context, request.packageId or request.name)
    if type(item) ~= "table" or non_empty(item.name) == nil then
        return nil
    end

    return {
        action = read_field(package, "action"),
        system = read_field(package, "system"),
        name = first_nonempty(item.packageId, item.name),
        version = first_nonempty(item.version, item.latestVersion),
        extraFields = shallow_copy(item.extraFields),
    }
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
        capabilities = { "exec", "network" },
        ecosystemScopes = { "vcpkg" },
        writeScopes = {
            { kind = "temp" },
            { kind = "user-home-subpath", value = ".cache/vcpkg" },
            { kind = "user-home-subpath", value = ".local/share/vcpkg" },
            { kind = "user-home-subpath", value = ".vcpkg" },
        },
        networkScopes = {},
        privilegeLevel = "user",
        osvEcosystem = "Generic",
        purlType = "generic",
    }
end

return plugin
