plugin = {}

local PLUGIN_NAME = "Hugging Face"
local PLUGIN_VERSION = "0.1.0"
local JSON_NULL = {}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
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

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
end

local lookup_info
local run_info_command
local repo_type_label
local repo_web_url

local function merge_extra_fields(left, right)
    local merged = shallow_copy(type(left) == "table" and left or {})
    for key, value in pairs(type(right) == "table" and right or {}) do
        merged[key] = value
    end
    return merged
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

local function exec_run(context, command)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return context.exec.run(command)
    end
    return reqpack.exec.run(command)
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

local function starts_with(value, prefix)
    local text = tostring(value or "")
    local expected = tostring(prefix or "")
    return expected == "" or text:sub(1, #expected) == expected
end

local function ends_with(value, suffix)
    local text = tostring(value or "")
    local expected = tostring(suffix or "")
    return expected == "" or text:sub(-#expected) == expected
end

local function strip_trailing_slashes(value)
    return tostring(value or ""):gsub("/+$", "")
end

local function path_basename(path)
    local text = tostring(path or "")
    return text:match("([^/]+)$") or text
end

local function path_dirname(path)
    local text = tostring(path or "")
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
    if type(paths) ~= "table" then
        return nil
    end
    return first_nonempty(read_field(paths, name))
end

local function read_proc_environ_value(name)
    if os ~= nil and type(os.getenv) == "function" then
        local current = os.getenv(tostring(name or ""))
        if current ~= nil and current ~= "" then
            return trim(current)
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
        if starts_with(entry, prefix) then
            return trim(entry:sub(#prefix + 1))
        end
    end
    return nil
end

local function path_exists(context, path)
    local text = tostring(path or "")
    if text == "" then
        return false
    end

    if context ~= nil and context.fs ~= nil and type(context.fs.exists) == "function" then
        local ok, exists = pcall(context.fs.exists, text)
        if ok then
            return exists == true
        end
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

local function path_is_dir(context, path)
    local text = tostring(path or "")
    if text == "" then
        return false
    end

    if context ~= nil and context.fs ~= nil and type(context.fs.is_dir) == "function" then
        local ok, is_dir = pcall(context.fs.is_dir, text)
        if ok then
            return is_dir == true
        end
    end

    local handle = io.open(join_path(text, "."), "rb")
    if handle ~= nil then
        handle:close()
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
    local result = exec_run(context, "mkdir -p " .. shell_quote(path))
    if result ~= nil and result.success then
        return true, nil
    end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to create directory: " .. tostring(path))
end

local function normalize_token(value)
    return tostring(value or ""):gsub("/", "__"):gsub("[^%w%._%-]+", "_")
end

local function split_lines(value)
    local lines = {}
    for line in tostring(value or ""):gmatch("[^\r\n]+") do
        local text = trim(line)
        if text ~= "" then
            lines[#lines + 1] = text
        end
    end
    return lines
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

local function infer_revision_from_path(path)
    local text = tostring(path or "")
    return text:match("/snapshots/([^/]+)")
end

local function resolve_downloaded_path(context, output)
    local candidate = nil
    for _, line in ipairs(split_lines(output)) do
        if starts_with(line, "/") or starts_with(line, "./") or starts_with(line, "../") then
            candidate = line
            if path_exists(context, line) then
                return line
            end
        end
    end
    if candidate ~= nil and path_exists(context, candidate) then
        return candidate
    end
    return nil
end

local function aicache_root(resolved_path)
    local data_root = get_reqpack_path("dataRoot")
    if data_root ~= nil then
        return join_path(data_root, "aicache")
    end

    local path = tostring(resolved_path or "")
    local home = path:match("^(.-)/%.cache/huggingface/")
    if home ~= nil and home ~= "" then
        return join_path(home, ".local", "share", "aicache")
    end

    local xdg_data_home = read_proc_environ_value("XDG_DATA_HOME")
    if xdg_data_home ~= nil and xdg_data_home ~= "" then
        return join_path(xdg_data_home, "aicache")
    end

    local env_home = read_proc_environ_value("HOME")
    if env_home ~= nil and env_home ~= "" then
        return join_path(env_home, ".local", "share", "aicache")
    end

    return nil
end

local function capture_command_output(context, command, output_path)
    local result = exec_run(context, command .. " > " .. shell_quote(output_path))
    if result == nil or not result.success then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "command failed")
    end

    local content = read_text_file(output_path)
    if content == nil then
        return nil, "failed to read command output from " .. output_path
    end
    return trim(content), nil
end

local function current_timestamp_utc(context, temp_dir)
    return capture_command_output(context, "date -u +%Y-%m-%dT%H:%M:%SZ", join_path(temp_dir, "timestamp.txt"))
end

local function sha256_digest_for_file(context, file_path, temp_dir)
    local output_path = join_path(temp_dir, normalize_token(file_path) .. ".sha256")
    local content, capture_error = capture_command_output(context, "sha256sum " .. shell_quote(file_path), output_path)
    if content == nil then
        return nil, capture_error
    end

    local digest = trim(content):match("^([0-9a-fA-F]+)")
    if digest == nil or digest == "" then
        return nil, "failed to parse sha256 for " .. file_path
    end
    return lower(digest), nil
end

local function file_size_for_path(context, file_path, temp_dir)
    local output_path = join_path(temp_dir, normalize_token(file_path) .. ".size")
    local content, capture_error = capture_command_output(context, "stat -c %s " .. shell_quote(file_path), output_path)
    if content == nil then
        return nil, capture_error
    end

    local size = tonumber(trim(content))
    if size == nil then
        return nil, "failed to parse file size for " .. file_path
    end
    return size, nil
end

local function detect_storage_format(logical_path)
    local path = lower(logical_path)
    if ends_with(path, ".jsonl") then
        return "jsonl"
    end
    if ends_with(path, ".safetensors") then
        return "safetensors"
    end
    if ends_with(path, ".gguf") then
        return "gguf"
    end
    if ends_with(path, ".exl2") then
        return "exl2"
    end
    if ends_with(path, ".onnx") then
        return "onnx"
    end
    if ends_with(path, ".openvino") then
        return "openvino"
    end
    if ends_with(path, ".coreml") then
        return "coreml"
    end
    if ends_with(path, ".engine") then
        return "engine"
    end
    if ends_with(path, ".trt") then
        return "trt"
    end
    if ends_with(path, ".parquet") then
        return "parquet"
    end
    if ends_with(path, ".arrow") then
        return "arrow"
    end
    if ends_with(path, ".tar") then
        return "tar"
    end
    if ends_with(path, ".zip") then
        return "zip"
    end
    if ends_with(path, ".wav") then
        return "wav"
    end
    if ends_with(path, ".flac") then
        return "flac"
    end
    if ends_with(path, ".mp3") then
        return "mp3"
    end
    if ends_with(path, ".png") then
        return "png"
    end
    if ends_with(path, ".jpeg") or ends_with(path, ".jpg") then
        return "jpg"
    end
    if ends_with(path, ".webp") then
        return "webp"
    end
    if ends_with(path, ".mp4") then
        return "mp4"
    end
    if ends_with(path, ".webm") then
        return "webm"
    end
    if ends_with(path, ".pth") then
        return "pth"
    end
    if ends_with(path, ".pt") then
        return "pt"
    end
    if ends_with(path, ".ckpt") then
        return "ckpt"
    end
    if ends_with(path, ".bin") then
        return "bin"
    end
    if ends_with(path, ".json") then
        return "json"
    end
    return "unknown"
end

local function detect_component_role(logical_path, format)
    local path = lower(logical_path)
    if path == "config.json" or ends_with(path, "/config.json") then
        return "config"
    end
    if path == "tokenizer.json" or path == "tokenizer_config.json" or ends_with(path, "/tokenizer.json") or ends_with(path, "/tokenizer_config.json") then
        return "tokenizer"
    end
    if path == "generation_config.json" or ends_with(path, "/generation_config.json") then
        return "generation-config"
    end
    if path == "model.safetensors.index.json" or ends_with(path, "/model.safetensors.index.json") then
        return "index"
    end
    if starts_with(path, "vae/") or path:find("/vae/", 1, true) ~= nil then
        return "vae"
    end
    if starts_with(path, "unet/") or path:find("/unet/", 1, true) ~= nil then
        return "unet"
    end
    if starts_with(path, "transformer/") or path:find("/transformer/", 1, true) ~= nil then
        return "transformer"
    end
    if starts_with(path, "scheduler/") or path:find("/scheduler/", 1, true) ~= nil then
        return "scheduler"
    end
    if starts_with(path, "text_encoder/") or starts_with(path, "text_encoder_2/") or path:find("/text_encoder/", 1, true) ~= nil or path:find("/text_encoder_2/", 1, true) ~= nil then
        return "text-encoder"
    end
    if format == "safetensors" or format == "gguf" or format == "exl2" or format == "bin" or format == "pt" or format == "pth" or format == "ckpt" then
        return "weights"
    end
    return "unknown"
end

local function classify_artifact(spec, files)
    if spec.kind == "dataset" then
        return "dataset", nil, {}
    end
    if spec.kind == "space" then
        return "space", nil, {}
    end

    for _, entry in ipairs(files or {}) do
        local logical_path = lower(entry.logical_path or "")
        if starts_with(logical_path, "vae/") or logical_path:find("/vae/", 1, true) ~= nil or
           starts_with(logical_path, "unet/") or logical_path:find("/unet/", 1, true) ~= nil or
           starts_with(logical_path, "scheduler/") or logical_path:find("/scheduler/", 1, true) ~= nil or
           ends_with(logical_path, ".ckpt") then
            return "model-image", "text-to-image", { "text-to-image" }
        end
    end

    return "model-llm", "causal-lm", { "causal-lm" }
end

local function collect_downloaded_files(context, source_path, logical_prefix, temp_dir)
    local prefix = strip_trailing_slashes(logical_prefix)
    if path_is_dir(context, source_path) then
        local inventory_path = join_path(temp_dir, "inventory.txt")
        local command = "find " .. shell_quote(source_path) .. " -type f -printf '%P\\n' | LC_ALL=C sort > " .. shell_quote(inventory_path)
        local result = exec_run(context, command)
        if result == nil or not result.success then
            return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to inventory downloaded files")
        end

        local inventory = read_text_file(inventory_path)
        if inventory == nil then
            return nil, "failed to read downloaded file inventory"
        end

        local files = {}
        for _, relative_path in ipairs(split_lines(inventory)) do
            local logical_path = prefix ~= "" and join_path(prefix, relative_path) or relative_path
            files[#files + 1] = {
                source_path = join_path(source_path, relative_path),
                logical_path = logical_path,
            }
        end
        return files, nil
    end

    local logical_path = prefix ~= "" and prefix or path_basename(source_path)
    return {
        {
            source_path = source_path,
            logical_path = logical_path,
        }
    }, nil
end

local function adopt_blob(context, source_path, blob_path)
    if path_exists(context, blob_path) then
        return true, nil
    end

    local ensure_ok, ensure_error = ensure_directory(context, path_dirname(blob_path))
    if not ensure_ok then
        return nil, ensure_error
    end

    local link_result = exec_run(context, "ln " .. shell_quote(source_path) .. " " .. shell_quote(blob_path))
    if link_result ~= nil and link_result.success then
        return true, nil
    end

    local copy_result = exec_run(context, "cp " .. shell_quote(source_path) .. " " .. shell_quote(blob_path))
    if copy_result ~= nil and copy_result.success then
        return true, nil
    end

    return nil, first_nonempty(
        copy_result and copy_result.stderr,
        copy_result and copy_result.stdout,
        link_result and link_result.stderr,
        link_result and link_result.stdout,
        "failed to adopt blob"
    )
end

local function materialize_view_file(context, blob_path, target_path)
    local ensure_ok, ensure_error = ensure_directory(context, path_dirname(target_path))
    if not ensure_ok then
        return nil, ensure_error
    end

    if path_exists(context, target_path) then
        local remove_result = exec_run(context, "rm -f " .. shell_quote(target_path))
        if remove_result == nil or not remove_result.success then
            return nil, first_nonempty(remove_result and remove_result.stderr, remove_result and remove_result.stdout, "failed to replace existing view file")
        end
    end

    local link_result = exec_run(context, "ln " .. shell_quote(blob_path) .. " " .. shell_quote(target_path))
    if link_result ~= nil and link_result.success then
        return true, nil
    end

    local copy_result = exec_run(context, "cp " .. shell_quote(blob_path) .. " " .. shell_quote(target_path))
    if copy_result ~= nil and copy_result.success then
        return true, nil
    end

    return nil, first_nonempty(
        copy_result and copy_result.stderr,
        copy_result and copy_result.stdout,
        link_result and link_result.stderr,
        link_result and link_result.stdout,
        "failed to materialize view file"
    )
end

local function build_artifact_id(spec, artifact_kind, revision)
    local base = join_path("huggingface", artifact_kind, spec.repoId) .. "@" .. revision
    if spec.filePath ~= "" then
        return base .. "+path=" .. normalize_token(spec.filePath)
    end
    return base
end

local function artifact_view_paths(root, spec, artifact_kind, artifact_id, revision, logical_path, format)
    return {
        join_path(root, "views", "by-kind", artifact_kind, artifact_id, logical_path),
        join_path(root, "views", "by-format", format, artifact_id, logical_path),
        join_path(root, "views", "by-source", "huggingface", spec.kind, normalize_token(spec.repoId), revision, logical_path),
    }
end

local function aicache_current_path(root, spec)
    return join_path(root, "views", "by-source", "huggingface", spec.kind, normalize_token(spec.repoId), "current.json")
end

local function annotate_aicache_fields(item, aicache)
    if type(item) ~= "table" or type(aicache) ~= "table" then
        return item
    end

    item.extraFields = merge_extra_fields(item.extraFields, {
        aicacheArtifactId = aicache.artifactId,
        aicacheArtifactPath = aicache.artifactPath,
        aicacheSourcePath = aicache.sourcePath,
    })
    return item
end

local function sync_aicache_for_download(context, spec, info, download_output)
    local resolved_path = resolve_downloaded_path(context, download_output)
    if resolved_path == nil or not path_exists(context, resolved_path) then
        return nil, "downloaded Hugging Face path unavailable locally; skipping ai cache ingest"
    end

    local root = aicache_root(resolved_path)
    if root == nil then
        return nil, "aicache root unavailable; skipping ai cache ingest"
    end

    local temp_dir = context ~= nil and context.fs ~= nil and type(context.fs.get_tmp_dir) == "function" and context.fs.get_tmp_dir() or ""
    if trim(temp_dir) == "" then
        return nil, "temporary directory unavailable; skipping ai cache ingest"
    end

    local scaffold_paths = {
        join_path(root, "blobs", "sha256"),
        join_path(root, "artifacts"),
        join_path(root, "views", "by-kind"),
        join_path(root, "views", "by-format"),
        join_path(root, "views", "by-source"),
        join_path(root, "index"),
        join_path(root, "pins"),
        join_path(root, "staging"),
        join_path(root, "gc"),
    }
    for _, directory in ipairs(scaffold_paths) do
        local ok, directory_error = ensure_directory(context, directory)
        if not ok then
            return nil, directory_error
        end
    end

    local extra = type(info) == "table" and type(info.extraFields) == "table" and info.extraFields or {}
    local revision = trim(first_nonempty(extra.sha, spec.revision, infer_revision_from_path(resolved_path), read_field(info, "version"), "unknown"))
    local created_at, timestamp_error = current_timestamp_utc(context, temp_dir)
    if created_at == nil then
        return nil, timestamp_error
    end

    local files, files_error = collect_downloaded_files(context, resolved_path, spec.filePath, temp_dir)
    if files == nil then
        return nil, files_error
    end
    if #files == 0 then
        return nil, "downloaded Hugging Face artifact is empty"
    end

    local file_entries = {}
    local blob_paths = {}
    for _, file in ipairs(files) do
        local digest, digest_error = sha256_digest_for_file(context, file.source_path, temp_dir)
        if digest == nil then
            return nil, digest_error
        end

        local size, size_error = file_size_for_path(context, file.source_path, temp_dir)
        if size == nil then
            return nil, size_error
        end

        local format = detect_storage_format(file.logical_path)
        file_entries[#file_entries + 1] = {
            logical_path = file.logical_path,
            role = detect_component_role(file.logical_path, format),
            format = format,
            blob_id = "sha256:" .. digest,
            size = size,
        }
        blob_paths[file.logical_path] = join_path(root, "blobs", "sha256", digest:sub(1, 2), digest)

        local adopt_ok, adopt_error = adopt_blob(context, file.source_path, blob_paths[file.logical_path])
        if not adopt_ok then
            return nil, adopt_error
        end
    end

    local artifact_kind, subtype, tasks = classify_artifact(spec, file_entries)
    local artifact_id = build_artifact_id(spec, artifact_kind, revision)
    local artifact_path = join_path(root, "artifacts", artifact_id)
    local ensure_ok, ensure_error = ensure_directory(context, artifact_path)
    if not ensure_ok then
        return nil, ensure_error
    end

    for _, entry in ipairs(file_entries) do
        local blob_path = blob_paths[entry.logical_path]
        local by_kind, by_format, by_source = table.unpack(artifact_view_paths(root, spec, artifact_kind, artifact_id, revision, entry.logical_path, entry.format))

        local ok, view_error = materialize_view_file(context, blob_path, by_kind)
        if not ok then
            return nil, view_error
        end
        ok, view_error = materialize_view_file(context, blob_path, by_format)
        if not ok then
            return nil, view_error
        end
        ok, view_error = materialize_view_file(context, blob_path, by_source)
        if not ok then
            return nil, view_error
        end
    end

    local refs = {}
    if spec.revision ~= "" then
        refs[#refs + 1] = spec.revision
    end

    local manifest = {
        artifact_id = artifact_id,
        kind = artifact_kind,
        tasks = tasks,
        source = {
            registry = "huggingface",
            repo_type = spec.kind,
            repo_id = spec.repoId,
            revision = revision,
            refs = refs,
        },
        tags = {},
        base_artifact_ids = {},
        created_at = created_at,
    }
    if subtype ~= nil then
        manifest.subtype = subtype
    end

    local source_metadata = {
        ingest_mode = "adopted-from-hf",
        source_cache_paths = { resolved_path },
        managed_source_cache = false,
        fetched_at = created_at,
        upstream_metadata = {
            package_id = type(info) == "table" and read_field(info, "packageId") or nil,
            version = type(info) == "table" and read_field(info, "version") or nil,
            homepage = type(info) == "table" and read_field(info, "homepage") or nil,
            source_url = type(info) == "table" and read_field(info, "sourceUrl") or nil,
            description = type(info) == "table" and read_field(info, "description") or nil,
            updated_at = type(info) == "table" and read_field(info, "updatedAt") or nil,
        },
    }
    if spec.filePath ~= "" then
        source_metadata.source_subpath = spec.filePath
    end

    local manifest_ok, manifest_error = write_text_file(join_path(artifact_path, "manifest.json"), encode_json(manifest))
    if not manifest_ok then
        return nil, manifest_error
    end

    local files_ok, files_write_error = write_text_file(join_path(artifact_path, "files.json"), encode_json({ files = file_entries }))
    if not files_ok then
        return nil, files_write_error
    end

    local source_ok, source_write_error = write_text_file(join_path(artifact_path, "source.json"), encode_json(source_metadata))
    if not source_ok then
        return nil, source_write_error
    end

    local current_path = aicache_current_path(root, spec)
    local current_dir_ok, current_dir_error = ensure_directory(context, path_dirname(current_path))
    if not current_dir_ok then
        return nil, current_dir_error
    end

    local current_ok, current_error = write_text_file(current_path, encode_json({
        artifact_id = artifact_id,
        artifact_path = artifact_path,
        revision = revision,
    }))
    if not current_ok then
        return nil, current_error
    end

    return {
        artifactId = artifact_id,
        artifactPath = artifact_path,
        sourcePath = resolved_path,
    }, nil
end

local function remove_path_if_exists(context, path)
    if not path_exists(context, path) then
        return true, nil
    end

    local result = exec_run(context, "rm -rf " .. shell_quote(path))
    if result ~= nil and result.success then
        return true, nil
    end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to remove path: " .. path)
end

local function file_link_count(context, path, temp_dir)
    if not path_exists(context, path) then
        return 0, nil
    end

    local output_path = join_path(temp_dir, normalize_token(path) .. ".links")
    local content, capture_error = capture_command_output(context, "stat -c %h " .. shell_quote(path), output_path)
    if content == nil then
        return nil, capture_error
    end

    local count = tonumber(trim(content))
    if count == nil then
        return nil, "failed to parse link count for " .. path
    end
    return count, nil
end

local function decode_json_file(path)
    local content = read_text_file(path)
    if content == nil then
        return nil, "failed to read file: " .. path
    end
    return decode_json(content)
end

local function parse_artifact_layout(root, artifact_path)
    local manifest, manifest_error = decode_json_file(join_path(artifact_path, "manifest.json"))
    if manifest == nil then
        return nil, manifest_error
    end

    local files_payload, files_error = decode_json_file(join_path(artifact_path, "files.json"))
    if files_payload == nil then
        return nil, files_error
    end

    local source_payload, source_error = decode_json_file(join_path(artifact_path, "source.json"))
    if source_payload == nil then
        return nil, source_error
    end

    local files = read_field(files_payload, "files")
    if type(files) ~= "table" then
        return nil, "invalid artifact files manifest"
    end

    local source = read_field(manifest, "source")
    local artifact_id = trim(read_field(manifest, "artifact_id") or path_basename(artifact_path))
    local artifact_kind = trim(read_field(manifest, "kind") or "unknown-ai-artifact")
    local revision = trim(type(source) == "table" and read_field(source, "revision") or "")
    local repo_type = trim(type(source) == "table" and read_field(source, "repo_type") or "model")
    local repo_id = trim(type(source) == "table" and read_field(source, "repo_id") or "")

    if revision == "" then
        revision = artifact_id:match("@([^@+]+)") or "unknown"
    end

    local spec = {
        kind = repo_type ~= "" and repo_type or "model",
        repoId = repo_id,
        filePath = artifact_id:match("%+path=(.+)$") or "",
    }

    local blob_paths = {}
    local view_paths = {}
    for _, entry in ipairs(files) do
        if type(entry) == "table" then
            local blob_id = trim(read_field(entry, "blob_id") or "")
            local digest = blob_id:match("^sha256:(.+)$")
            local logical_path = trim(read_field(entry, "logical_path") or "")
            local format = trim(read_field(entry, "format") or "unknown")
            if digest ~= nil and logical_path ~= "" then
                blob_paths[#blob_paths + 1] = join_path(root, "blobs", "sha256", digest:sub(1, 2), digest)
                local paths = artifact_view_paths(root, spec, artifact_kind, artifact_id, revision, logical_path, format)
                for _, path in ipairs(paths) do
                    view_paths[#view_paths + 1] = path
                end
            end
        end
    end

    return {
        artifactId = artifact_id,
        artifactKind = artifact_kind,
        artifactPath = artifact_path,
        manifest = manifest,
        sourceMetadata = source_payload,
        spec = spec,
        revision = revision,
        fileCount = #files,
        blobPaths = blob_paths,
        viewPaths = view_paths,
    }, nil
end

local function model_artifact_kind_candidates()
    return { "model-llm", "model-image" }
end

local function aicache_artifact_candidate_paths(root, spec, revision)
    local candidates = {}
    if spec.kind == "dataset" then
        candidates[#candidates + 1] = join_path(root, "artifacts", build_artifact_id(spec, "dataset", revision))
        return candidates
    end
    if spec.kind == "space" then
        candidates[#candidates + 1] = join_path(root, "artifacts", build_artifact_id(spec, "space", revision))
        return candidates
    end

    for _, artifact_kind in ipairs(model_artifact_kind_candidates()) do
        candidates[#candidates + 1] = join_path(root, "artifacts", build_artifact_id(spec, artifact_kind, revision))
    end
    return candidates
end

local function build_info_from_aicache_layout(layout)
    if type(layout) ~= "table" then
        return nil
    end

    local manifest = type(layout.manifest) == "table" and layout.manifest or {}
    local source = type(read_field(manifest, "source")) == "table" and read_field(manifest, "source") or {}
    local source_metadata = type(layout.sourceMetadata) == "table" and layout.sourceMetadata or {}
    local upstream = type(read_field(source_metadata, "upstream_metadata")) == "table" and read_field(source_metadata, "upstream_metadata") or {}
    local repo_type = trim(read_field(source, "repo_type") or layout.spec and layout.spec.kind or "model")
    local repo_id = trim(read_field(source, "repo_id") or layout.spec and layout.spec.repoId or "")
    local source_subpath = trim(read_field(source_metadata, "source_subpath") or "")
    local name = repo_id:match("([^/]+)$") or repo_id
    if source_subpath ~= "" then
        name = path_basename(source_subpath)
    end

    local description = first_nonempty(
        read_field(upstream, "description"),
        repo_type_label(repo_type) .. " stored in AICache"
    )
    local version = trim(first_nonempty(read_field(source, "revision"), layout.revision, read_field(upstream, "version"), "unknown"))

    return {
        name = name,
        packageId = repo_id,
        version = version,
        latestVersion = version,
        summary = description,
        description = description,
        homepage = first_nonempty(read_field(upstream, "homepage"), repo_web_url(repo_type, repo_id)),
        sourceUrl = first_nonempty(read_field(upstream, "source_url"), repo_web_url(repo_type, repo_id)),
        packageType = repo_type_label(repo_type),
        type = "package",
        updatedAt = first_nonempty(read_field(upstream, "updated_at"), read_field(source_metadata, "fetched_at")),
        extraFields = {
            repoId = repo_id,
            repoType = repo_type,
            cacheId = repo_type_label(repo_type) .. "/" .. repo_id,
            revision = version,
            artifactKind = layout.artifactKind,
            aicacheArtifactId = layout.artifactId,
            aicacheArtifactPath = layout.artifactPath,
            aicacheFileCount = tostring(layout.fileCount or 0),
        },
    }
end

local function list_aicache_current_paths(context)
    local root = aicache_root("")
    if root == nil or root == "" then
        return {}, nil
    end

    local source_root = join_path(root, "views", "by-source", "huggingface")
    if not path_exists(context, source_root) then
        return {}, nil
    end

    local command = "find " .. shell_quote(source_root) .. " -type f -name 'current.json' | LC_ALL=C sort"
    local result = exec_run(context, command)
    if result == nil or not result.success then
        return {}, first_nonempty(result and result.stderr, result and result.stdout, "failed to list aicache current pointers")
    end

    return split_lines(result.stdout), nil
end

local function read_aicache_layout_from_current_path(context, current_path)
    local current, current_error = decode_json_file(current_path)
    if current == nil then
        return nil, current_error
    end

    local artifact_path = trim(read_field(current, "artifact_path") or "")
    local root = current_path:match("^(.*)/views/")
    if root == nil or root == "" then
        return nil, "failed to derive aicache root from current pointer"
    end

    if artifact_path == "" then
        local artifact_id = trim(read_field(current, "artifact_id") or "")
        if artifact_id == "" then
            return nil, "invalid aicache current pointer"
        end
        artifact_path = join_path(root, "artifacts", artifact_id)
    end
    if not path_exists(context, artifact_path) then
        return nil, nil
    end

    return parse_artifact_layout(root, artifact_path)
end

local function list_aicache(context)
    local current_paths, current_error = list_aicache_current_paths(context)
    if current_paths == nil then
        return {}, current_error
    end

    local items = {}
    for _, current_path in ipairs(current_paths or {}) do
        local layout = select(1, read_aicache_layout_from_current_path(context, current_path))
        local item = build_info_from_aicache_layout(layout)
        if item ~= nil then
            items[#items + 1] = item
        end
    end

    table.sort(items, function(left, right)
        return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "")
    end)
    return items, current_error
end

local function lookup_aicache_layout(context, spec)
    local root = aicache_root("")
    if root == nil or root == "" then
        return nil, nil
    end

    local current_path = aicache_current_path(root, spec)
    if path_exists(context, current_path) then
        local layout, current_error = read_aicache_layout_from_current_path(context, current_path)
        if layout ~= nil then
            local current_revision = trim(read_field(layout.manifest and read_field(layout.manifest, "source") or {}, "revision") or layout.revision or "")
            local current_subpath = trim(type(layout.sourceMetadata) == "table" and read_field(layout.sourceMetadata, "source_subpath") or "")
            local revision_matches = spec.revision == "" or current_revision == spec.revision
            local path_matches = spec.filePath == "" or current_subpath == spec.filePath
            if revision_matches and path_matches then
                return layout, nil
            end
        elseif current_error ~= nil then
            return nil, current_error
        end
    end

    if spec.revision ~= "" then
        for _, candidate in ipairs(aicache_artifact_candidate_paths(root, spec, spec.revision)) do
            if path_exists(context, candidate) then
                return parse_artifact_layout(root, candidate)
            end
        end
    end

    return nil, nil
end

local function lookup_aicache_info(context, spec)
    local layout, layout_error = lookup_aicache_layout(context, spec)
    if layout == nil then
        return nil, layout_error
    end
    return build_info_from_aicache_layout(layout), nil
end

local function locate_aicache_artifact(context, spec)
    local root = aicache_root("")
    if root == nil or root == "" then
        return nil, nil
    end

    local current_path = aicache_current_path(root, spec)
    if not path_exists(context, current_path) then
        return nil, nil
    end

    local current, current_error = decode_json_file(current_path)
    if current == nil then
        return nil, current_error
    end

    local artifact_path = trim(read_field(current, "artifact_path") or "")
    if artifact_path ~= "" and path_exists(context, artifact_path) then
        return artifact_path, nil
    end

    local artifact_id = trim(read_field(current, "artifact_id") or "")
    if artifact_id ~= "" then
        local candidate = join_path(root, "artifacts", artifact_id)
        if path_exists(context, candidate) then
            return candidate, nil
        end
    end

    return nil, nil
end

local function cleanup_aicache_artifact(context, spec)
    local artifact_path, locate_error = locate_aicache_artifact(context, spec)
    if locate_error ~= nil then
        return nil, locate_error
    end
    if artifact_path == nil or not path_exists(context, artifact_path) then
        return false, nil
    end

    local root = artifact_path:match("^(.*)/artifacts/")
    if root == nil or root == "" then
        return nil, "failed to derive aicache root from artifact path"
    end

    local temp_dir = context ~= nil and context.fs ~= nil and type(context.fs.get_tmp_dir) == "function" and context.fs.get_tmp_dir() or ""
    if trim(temp_dir) == "" then
        return nil, "temporary directory unavailable; skipping ai cache cleanup"
    end

    local layout, layout_error = parse_artifact_layout(root, artifact_path)
    if layout == nil then
        return nil, layout_error
    end

    for _, path in ipairs(layout.viewPaths) do
        local ok, remove_error = remove_path_if_exists(context, path)
        if not ok then
            return nil, remove_error
        end
    end

    local ok, remove_error = remove_path_if_exists(context, layout.artifactPath)
    if not ok then
        return nil, remove_error
    end

    ok, remove_error = remove_path_if_exists(context, aicache_current_path(root, {
        kind = spec.kind,
        repoId = spec.repoId,
    }))
    if not ok then
        return nil, remove_error
    end

    for _, blob_path in ipairs(layout.blobPaths) do
        local link_count, link_error = file_link_count(context, blob_path, temp_dir)
        if link_count == nil then
            return nil, link_error
        end
        if link_count <= 1 then
            local removed, blob_remove_error = remove_path_if_exists(context, blob_path)
            if not removed then
                return nil, blob_remove_error
            end
        end
    end

    return true, nil
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function detect_cli_binary(context)
    if command_exists(context, "hf") then
        return "hf"
    end
    if command_exists(context, "huggingface-cli") then
        return "huggingface-cli"
    end
    return nil
end

local function join_command(parts)
    return table.concat(parts, " ")
end

local function append_command_arg(parts, value)
    local text = trim(value)
    if text ~= "" then
        parts[#parts + 1] = shell_quote(text)
    end
end

repo_type_label = function(kind)
    if kind == "dataset" then
        return "dataset"
    end
    if kind == "space" then
        return "space"
    end
    return "model"
end

local function cache_type_label(kind)
    if kind == "dataset" then
        return "dataset"
    end
    if kind == "space" then
        return "space"
    end
    return "model"
end

repo_web_url = function(kind, repo_id)
    local normalized_repo_id = trim(repo_id)
    if normalized_repo_id == "" then
        return nil
    end
    if kind == "dataset" then
        return "https://huggingface.co/datasets/" .. normalized_repo_id
    end
    if kind == "space" then
        return "https://huggingface.co/spaces/" .. normalized_repo_id
    end
    return "https://huggingface.co/" .. normalized_repo_id
end

local function normalize_cache_id(kind, repo_id)
    return cache_type_label(kind) .. "/" .. repo_id
end

local function parse_package_spec(raw_name, raw_version)
    local spec = trim(raw_name)
    local requested_version = trim(raw_version)
    if spec == "" then
        return nil, "package name missing"
    end

    local revision = requested_version
    local file_path = ""
    local path_index = spec:find("//", 1, true)
    if path_index ~= nil then
        file_path = trim(spec:sub(path_index + 2))
        spec = trim(spec:sub(1, path_index - 1))
    end

    local at_index = spec:match("^.*()@")
    if at_index ~= nil and at_index > 1 and at_index < #spec then
        if revision == "" then
            revision = trim(spec:sub(at_index + 1))
        end
        spec = trim(spec:sub(1, at_index - 1))
    end

    local kind = "model"
    local repo_id = spec
    local separator = spec:find(":", 1, true)
    if separator ~= nil then
        local maybe_kind = lower(trim(spec:sub(1, separator - 1)))
        local rest = trim(spec:sub(separator + 1))
        if (maybe_kind == "dataset" or maybe_kind == "space" or maybe_kind == "model") and rest ~= "" then
            kind = maybe_kind
            repo_id = rest
        end
    end

    if repo_id == "" or repo_id:find("/", 1, true) == nil then
        return nil, "expected Hugging Face repo id like owner/name"
    end

    local target_name = repo_id:match("([^/]+)$") or repo_id
    if file_path ~= "" then
        local leaf = file_path:match("([^/]+)$")
        if leaf ~= nil and leaf ~= "" then
            target_name = leaf
        end
    end

    return {
        kind = kind,
        repoId = repo_id,
        revision = revision,
        filePath = file_path,
        name = target_name,
        packageId = repo_id,
        cacheId = normalize_cache_id(kind, repo_id),
        displaySpec = raw_version ~= nil and trim(raw_version) ~= "" and (raw_name .. "@" .. raw_version) or raw_name,
    }, nil
end

local function append_package_flags(parts, package, extra_flags)
    local flags = read_field(package, "flags")
    if type(flags) == "table" then
        for _, flag in ipairs(flags) do
            local text = trim(flag)
            if text ~= "" then
                parts[#parts + 1] = text
            end
        end
    end

    for _, flag in ipairs(extra_flags or {}) do
        local text = trim(flag)
        if text ~= "" then
            parts[#parts + 1] = text
        end
    end
end

local function build_download_command(cli_binary, spec, package, extra_flags)
    local parts = { cli_binary, "download" }
    append_command_arg(parts, spec.repoId)
    if spec.filePath ~= "" then
        append_command_arg(parts, spec.filePath)
    end
    if spec.kind ~= "model" then
        parts[#parts + 1] = "--repo-type"
        parts[#parts + 1] = spec.kind
    end
    if spec.revision ~= "" then
        parts[#parts + 1] = "--revision"
        append_command_arg(parts, spec.revision)
    end

    append_package_flags(parts, package, extra_flags)

    return join_command(parts)
end

local function parse_cache_entries(raw)
    local decoded, decode_error = decode_json(raw)
    if decoded == nil then
        return nil, decode_error or "failed to parse Hugging Face cache JSON"
    end
    if type(decoded) ~= "table" then
        return nil, "unexpected Hugging Face cache JSON shape"
    end
    return decoded, nil
end

local function cache_entry_to_info(entry)
    local repo_id = trim(json_value(entry.repo_id) or "")
    local repo_type = trim(json_value(entry.repo_type) or "model")
    local cache_id = trim(json_value(entry.id) or normalize_cache_id(repo_type, repo_id))
    local refs = json_value(entry.refs)
    local revision = trim(json_value(entry.revision) or "")
    local latest_ref = ""
    if type(refs) == "table" and #refs > 0 then
        latest_ref = trim(refs[1])
    end

    local extra = {
        repoId = repo_id,
        repoType = repo_type,
        cacheId = cache_id,
    }
    if revision ~= "" then
        extra.revision = revision
    end

    return {
        name = repo_id:match("([^/]+)$") or repo_id,
        packageId = repo_id,
        version = first_nonempty(latest_ref, revision),
        summary = repo_type_label(repo_type) .. " cached from Hugging Face Hub",
        description = repo_type_label(repo_type) .. " cached from Hugging Face Hub",
        packageType = repo_type_label(repo_type),
        type = "package",
        sourceUrl = repo_web_url(repo_type, repo_id),
        extraFields = extra,
    }
end

local function list_cache(context)
    local cli_binary = detect_cli_binary(context)
    if cli_binary == nil then
        return {}, nil
    end

    local result = exec_run(context, cli_binary .. " cache ls --format json")
    if result == nil or not result.success then
        return {}, first_nonempty(result and result.stderr, result and result.stdout, "huggingface cache ls failed")
    end

    local entries, parse_error = parse_cache_entries(result.stdout)
    if entries == nil then
        return {}, parse_error
    end

    local items = {}
    for _, entry in ipairs(entries) do
        if type(entry) == "table" then
            items[#items + 1] = cache_entry_to_info(entry)
        end
    end

    table.sort(items, function(left, right)
        return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "")
    end)
    return items, nil
end

local function list_cache_revisions(context)
    local cli_binary = detect_cli_binary(context)
    if cli_binary == nil then
        return {}, nil
    end

    local result = exec_run(context, cli_binary .. " cache ls --format json --revisions")
    if result == nil or not result.success then
        return {}, first_nonempty(result and result.stderr, result and result.stdout, "huggingface cache ls --revisions failed")
    end

    local entries, parse_error = parse_cache_entries(result.stdout)
    if entries == nil then
        return {}, parse_error
    end

    return entries, nil
end

local function find_cached_match(items, spec)
    local wanted_cache_id = normalize_cache_id(spec.kind, spec.repoId)
    for _, item in ipairs(items or {}) do
        local extra = type(item.extraFields) == "table" and item.extraFields or {}
        if trim(extra.cacheId) == wanted_cache_id then
            return item
        end
        if trim(extra.repoId) == spec.repoId and trim(extra.repoType) == spec.kind then
            return item
        end
    end
    return nil
end

local function matches_outdated_spec(item, spec)
    local extra = type(item.extraFields) == "table" and item.extraFields or {}
    return trim(extra.repoId) == spec.repoId and trim(extra.repoType) == spec.kind
end

local function cache_revision_to_spec(entry)
    local repo_id = trim(json_value(entry.repo_id) or "")
    local repo_type = trim(json_value(entry.repo_type) or "model")
    local revision = trim(json_value(entry.revision) or "")
    local refs = json_value(entry.refs)
    local ref_name = ""
    if type(refs) == "table" and #refs > 0 then
        ref_name = trim(refs[1])
    end

    if repo_id == "" then
        return nil
    end

    return {
        kind = repo_type ~= "" and repo_type or "model",
        repoId = repo_id,
        revision = ref_name,
        cachedRevision = revision,
        refName = ref_name,
        filePath = "",
        name = repo_id:match("([^/]+)$") or repo_id,
        packageId = repo_id,
        cacheId = trim(json_value(entry.id) or normalize_cache_id(repo_type, repo_id)),
    }
end

local function outdated_item_from_cache_entry(context, cli_binary, entry)
    local spec = cache_revision_to_spec(entry)
    if spec == nil then
        return nil
    end

    if spec.refName == "" then
        return nil
    end

    local item, info_error = run_info_command(context, cli_binary, spec)
    if item == nil then
        return nil, info_error
    end

    local latest_version = trim(item.version)
    local cached_revision = trim(spec.cachedRevision)
    if latest_version == "" or cached_revision == "" or latest_version == cached_revision then
        return nil
    end

    item.version = cached_revision
    item.latestVersion = latest_version
    item.status = "outdated"
    item.installed = true
    item.extraFields = merge_extra_fields(item.extraFields, {
        repoId = spec.repoId,
        repoType = spec.kind,
        cacheId = spec.cacheId,
        cachedRevision = cached_revision,
        ref = spec.refName,
    })
    return item, nil
end

local function build_info_from_json(data, kind)
    if type(data) ~= "table" then
        return {}
    end

    local repo_id = first_nonempty(json_value(data.id), json_value(data.repo_id))
    local sha = first_nonempty(json_value(data.sha), json_value(data.revision))
    local downloads = json_value(data.downloads)
    local likes = json_value(data.likes)
    local private = json_value(data.private)
    local gated = json_value(data.gated)
    local last_modified = first_nonempty(json_value(data.lastModified), json_value(data.last_modified), json_value(data.updatedAt))

    local extra = {
        repoId = repo_id,
        repoType = kind,
        cacheId = repo_id and normalize_cache_id(kind, repo_id) or nil,
    }
    if sha ~= nil then
        extra.sha = sha
    end
    if downloads ~= nil then
        extra.downloads = tostring(downloads)
    end
    if likes ~= nil then
        extra.likes = tostring(likes)
    end
    if private ~= nil then
        extra.private = tostring(private)
    end
    if gated ~= nil then
        extra.gated = tostring(gated)
    end

    local author = nil
    local card_data = json_value(data.cardData)
    if type(card_data) == "table" then
        author = first_nonempty(json_value(card_data.author), json_value(card_data.model_creator))
    end

    return {
        name = first_nonempty(repo_id and repo_id:match("([^/]+)$"), repo_id),
        packageId = repo_id,
        version = first_nonempty(sha, last_modified),
        latestVersion = first_nonempty(sha, last_modified),
        summary = first_nonempty(json_value(data.description), json_value(data.summary), repo_type_label(kind) .. " on Hugging Face Hub"),
        description = first_nonempty(json_value(data.description), json_value(data.summary), repo_type_label(kind) .. " on Hugging Face Hub"),
        homepage = repo_web_url(kind, repo_id),
        sourceUrl = repo_web_url(kind, repo_id),
        packageType = repo_type_label(kind),
        type = "package",
        author = author,
        updatedAt = last_modified,
        extraFields = extra,
    }
end

function run_info_command(context, cli_binary, spec)
    local parts = { cli_binary }
    if spec.kind == "dataset" then
        parts[#parts + 1] = "datasets"
        parts[#parts + 1] = "info"
    elseif spec.kind == "space" then
        parts[#parts + 1] = "spaces"
        parts[#parts + 1] = "info"
    else
        parts[#parts + 1] = "models"
        parts[#parts + 1] = "info"
    end

    append_command_arg(parts, spec.repoId)
    if spec.revision ~= "" then
        parts[#parts + 1] = "--revision"
        append_command_arg(parts, spec.revision)
    end
    parts[#parts + 1] = "--format"
    parts[#parts + 1] = "json"

    local result = exec_run(context, join_command(parts))
    if result == nil or not result.success then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "huggingface info failed")
    end

    local decoded, decode_error = decode_json(result.stdout)
    if decoded == nil then
        return nil, decode_error or "failed to parse Hugging Face info JSON"
    end

    return build_info_from_json(decoded, spec.kind), nil
end

local function normalize_search_row(item, kind)
    local repo_id = first_nonempty(json_value(item.id), json_value(item.repo_id))
    return {
        name = first_nonempty(repo_id and repo_id:match("([^/]+)$"), repo_id),
        packageId = repo_id,
        version = first_nonempty(json_value(item.sha), json_value(item.lastModified), json_value(item.last_modified)),
        summary = first_nonempty(json_value(item.description), repo_type_label(kind) .. " on Hugging Face Hub"),
        description = first_nonempty(json_value(item.description), repo_type_label(kind) .. " on Hugging Face Hub"),
        homepage = repo_web_url(kind, repo_id),
        sourceUrl = repo_web_url(kind, repo_id),
        packageType = repo_type_label(kind),
        type = "package",
        extraFields = {
            repoId = repo_id,
            repoType = kind,
            cacheId = repo_id and normalize_cache_id(kind, repo_id) or nil,
        },
    }
end

local function run_search_command(context, cli_binary, kind, query)
    local parts = { cli_binary }
    if kind == "dataset" then
        parts[#parts + 1] = "datasets"
        parts[#parts + 1] = "ls"
    elseif kind == "space" then
        parts[#parts + 1] = "spaces"
        parts[#parts + 1] = "ls"
    else
        parts[#parts + 1] = "models"
        parts[#parts + 1] = "ls"
    end
    parts[#parts + 1] = "--search"
    append_command_arg(parts, query)
    parts[#parts + 1] = "--limit"
    parts[#parts + 1] = "10"
    parts[#parts + 1] = "--format"
    parts[#parts + 1] = "json"

    local result = exec_run(context, join_command(parts))
    if result == nil or not result.success then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "huggingface search failed")
    end

    local decoded, decode_error = decode_json(result.stdout)
    if decoded == nil then
        return nil, decode_error or "failed to parse Hugging Face search JSON"
    end
    if type(decoded) ~= "table" then
        return {}, nil
    end

    local items = {}
    for _, item in ipairs(decoded) do
        if type(item) == "table" then
            items[#items + 1] = normalize_search_row(item, kind)
        end
    end
    return items, nil
end

local function parse_search_prompt(prompt)
    local text = trim(prompt)
    if text == "" then
        return "model", ""
    end

    local separator = text:find(":", 1, true)
    if separator ~= nil then
        local maybe_kind = lower(trim(text:sub(1, separator - 1)))
        local rest = trim(text:sub(separator + 1))
        if maybe_kind == "dataset" or maybe_kind == "space" or maybe_kind == "model" then
            return maybe_kind, rest
        end
    end

    return "model", text
end

local function ensure_cli_available(context)
    local cli_binary = detect_cli_binary(context)
    if cli_binary ~= nil then
        return cli_binary, nil
    end
    return nil, "huggingface cli missing; install dependency via ReqPack plugin dependencies"
end

function lookup_info(context, spec)
    local cli_binary, cli_error = ensure_cli_available(context)
    if cli_binary == nil then
        return nil, cli_error
    end
    return run_info_command(context, cli_binary, spec)
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
    return { "AI", "Package Manager", "Hugging Face" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end

    local cached_items = plugin.list(nil)
    local missing = {}
    for _, package in ipairs(requested) do
        local spec = parse_package_spec(package.name, package.version)
        if spec == nil then
            missing[#missing + 1] = package
        else
            local action = lower(read_field(package, "action") or "")
            local cached = find_cached_match(cached_items, spec)
            if action == "remove" then
                if cached ~= nil then
                    missing[#missing + 1] = package
                end
            elseif action == "update" then
                if cached ~= nil then
                    missing[#missing + 1] = package
                end
            elseif cached == nil then
                missing[#missing + 1] = package
            end
        end
    end
    return missing
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    local cli_binary, cli_error = ensure_cli_available(context)
    if cli_binary == nil then
        tx_failed(context, cli_error)
        return false
    end

    local installed = {}
    for _, package in ipairs(requested) do
        local spec, spec_error = parse_package_spec(package.name, package.version)
        if spec == nil then
            tx_failed(context, spec_error)
            return false
        end

        begin_step(context, "download huggingface " .. repo_type_label(spec.kind))
        local command = build_download_command(cli_binary, spec, package)
        local result = exec_run(context, command)
        if result == nil or not result.success then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "huggingface download failed"))
            return false
        end

        local info = run_info_command(context, cli_binary, spec)
        local aicache, aicache_error = sync_aicache_for_download(context, spec, info, result.stdout)
        if aicache_error ~= nil then
            log_message(context, "warn", aicache_error)
        end
        if info ~= nil and info ~= {} and type(info) == "table" then
            annotate_aicache_fields(info, aicache)
            installed[#installed + 1] = info
        else
            local item = {
                name = spec.name,
                packageId = spec.repoId,
                version = spec.revision ~= "" and spec.revision or nil,
                packageType = repo_type_label(spec.kind),
                type = "package",
                sourceUrl = repo_web_url(spec.kind, spec.repoId),
                extraFields = {
                    repoId = spec.repoId,
                    repoType = spec.kind,
                    cacheId = spec.cacheId,
                },
            }
            annotate_aicache_fields(item, aicache)
            installed[#installed + 1] = item
        end
    end

    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local spec, spec_error = parse_package_spec(path, nil)
    if spec == nil then
        tx_failed(context, first_nonempty(spec_error, "huggingface local install path missing"))
        return false
    end
    return plugin.install(context, { { name = path, action = "install" } })
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    local cli_binary, cli_error = ensure_cli_available(context)
    if cli_binary == nil then
        tx_failed(context, cli_error)
        return false
    end

    local targets = {}
    local removed = {}
    for _, package in ipairs(requested) do
        local spec, spec_error = parse_package_spec(package.name, package.version)
        if spec == nil then
            tx_failed(context, spec_error)
            return false
        end
        targets[#targets + 1] = spec.cacheId
        removed[#removed + 1] = {
            name = spec.name,
            packageId = spec.repoId,
            packageType = repo_type_label(spec.kind),
            type = "package",
            extraFields = {
                repoId = spec.repoId,
                repoType = spec.kind,
                cacheId = spec.cacheId,
            },
        }
    end

    begin_step(context, "remove huggingface cache entries")
    local parts = { cli_binary, "cache", "rm" }
    for _, target in ipairs(targets) do
        append_command_arg(parts, target)
    end
    parts[#parts + 1] = "--yes"

    local result = exec_run(context, join_command(parts))
    if result == nil or not result.success then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "huggingface remove failed"))
        return false
    end

    for _, package in ipairs(requested) do
        local spec = parse_package_spec(package.name, package.version)
        if spec ~= nil then
            local cleaned, cleanup_error = cleanup_aicache_artifact(context, spec)
            if cleanup_error ~= nil then
                log_message(context, "warn", cleanup_error)
            elseif cleaned then
                log_message(context, "info", "removed aicache artifact for " .. spec.repoId)
            end
        end
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

    local cli_binary, cli_error = ensure_cli_available(context)
    if cli_binary == nil then
        tx_failed(context, cli_error)
        return false
    end

    local updated = {}
    for _, package in ipairs(requested) do
        local spec, spec_error = parse_package_spec(package.name, package.version)
        if spec == nil then
            tx_failed(context, spec_error)
            return false
        end

        begin_step(context, "refresh huggingface " .. repo_type_label(spec.kind))
        local command = build_download_command(cli_binary, spec, package, { "--force-download" })
        local result = exec_run(context, command)
        if result == nil or not result.success then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "huggingface update failed"))
            return false
        end

        local info = run_info_command(context, cli_binary, spec)
        local aicache, aicache_error = sync_aicache_for_download(context, spec, info, result.stdout)
        if aicache_error ~= nil then
            log_message(context, "warn", aicache_error)
        end
        if info ~= nil and type(info) == "table" then
            annotate_aicache_fields(info, aicache)
            updated[#updated + 1] = info
        else
            local item = {
                name = spec.name,
                packageId = spec.repoId,
                version = spec.revision ~= "" and spec.revision or nil,
                packageType = repo_type_label(spec.kind),
                type = "package",
            }
            annotate_aicache_fields(item, aicache)
            updated[#updated + 1] = item
        end
    end

    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local aicache_items, aicache_error = list_aicache(context)
    if aicache_items ~= nil and #aicache_items > 0 then
        emit_event(context, "listed", aicache_items)
        return aicache_items
    end

    local items, list_error = list_cache(context)
    if items == nil then
        items = {}
    end
    if aicache_error ~= nil then
        log_message(context, "warn", aicache_error)
    end
    if list_error ~= nil then
        log_message(context, "warn", list_error)
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local cli_binary, cli_error = ensure_cli_available(context)
    if cli_binary == nil then
        log_message(context, "warn", cli_error)
        emit_event(context, "outdated", {})
        return {}
    end

    local result = exec_run(context, cli_binary .. " cache ls --format json --revisions")
    if result == nil or not result.success then
        log_message(context, "warn", first_nonempty(result and result.stderr, result and result.stdout, "huggingface cache ls --revisions failed"))
        emit_event(context, "outdated", {})
        return {}
    end

    local entries, list_error = parse_cache_entries(result.stdout)
    if entries == nil then
        log_message(context, "warn", list_error)
        emit_event(context, "outdated", {})
        return {}
    end

    local outdated = {}
    for _, entry in ipairs(entries) do
        if type(entry) == "table" then
            local item, item_error = outdated_item_from_cache_entry(context, cli_binary, entry)
            if item ~= nil then
                outdated[#outdated + 1] = item
            elseif item_error ~= nil then
                log_message(context, "warn", item_error)
            end
        end
    end

    table.sort(outdated, function(left, right)
        return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "")
    end)
    emit_event(context, "outdated", outdated)
    return outdated
end

function plugin.search(context, prompt)
    local query_kind, query_text = parse_search_prompt(prompt)
    if query_text == "" then
        emit_event(context, "searched", {})
        return {}
    end

    local cli_binary, cli_error = ensure_cli_available(context)
    if cli_binary == nil then
        log_message(context, "warn", cli_error)
        emit_event(context, "searched", {})
        return {}
    end

    local items, search_error = run_search_command(context, cli_binary, query_kind, query_text)
    if items == nil then
        log_message(context, "warn", search_error)
        emit_event(context, "searched", {})
        return {}
    end

    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local spec, spec_error = parse_package_spec(name, nil)
    if spec == nil then
        log_message(context, "warn", spec_error)
        emit_event(context, "informed", {})
        return {}
    end

    local cached_item, cached_error = lookup_aicache_info(context, spec)
    if cached_item ~= nil then
        emit_event(context, "informed", cached_item)
        return cached_item
    end

    local cli_binary, cli_error = ensure_cli_available(context)
    if cli_binary == nil then
        if cached_error ~= nil then
            log_message(context, "warn", cached_error)
        end
        log_message(context, "warn", cli_error)
        emit_event(context, "informed", {})
        return {}
    end

    local item, info_error = run_info_command(context, cli_binary, spec)
    if item == nil then
        if cached_error ~= nil then
            log_message(context, "warn", cached_error)
        end
        log_message(context, "warn", info_error)
        emit_event(context, "informed", {})
        return {}
    end

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local spec = parse_package_spec(package.name, package.version)
    if spec == nil then
        return nil
    end

    local item = select(1, lookup_info(context, spec))
    if type(item) == "table" and first_nonempty(item.packageId, item.name, item.description) ~= nil then
        return {
            name = item.name,
            packageId = item.packageId,
            version = item.version,
            homepage = item.homepage,
            sourceUrl = item.sourceUrl,
            extraFields = merge_extra_fields(item.extraFields, {
                repoId = spec.repoId,
                repoType = spec.kind,
            }),
        }
    end

    return {
        name = spec.name,
        packageId = spec.repoId,
        version = spec.revision ~= "" and spec.revision or nil,
        extraFields = {
            repoId = spec.repoId,
            repoType = spec.kind,
            cacheId = spec.cacheId,
        },
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "huggingface", "model", "dataset", "space" },
        writeScopes = {
            { kind = "temp" },
            { kind = "user-home-subpath", value = ".cache/huggingface" },
            { kind = "user-home-subpath", value = ".local/share/aicache" },
        },
        privilegeLevel = "user",
        purlType = "generic",
        versionTokenPattern = "[A-Za-z0-9._/%-]+",
        versionCaseInsensitive = false,
    }
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

return plugin
