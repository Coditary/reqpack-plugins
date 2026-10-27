plugin = {}

local PLUGIN_ID = "clasp"
local PLUGIN_NAME = "clasp"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "clasp"
local JSON_NULL = {}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
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

local function exec_run(context, command)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return context.exec.run(command)
    end
    if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
        return reqpack.exec.run(command)
    end
    return {
        success = false,
        stdout = "",
        stderr = "reqpack.exec.run unavailable",
    }
end

local function result_stdout(result)
    return trim(read_field(result, "stdout") or "")
end

local function result_stderr(result)
    return trim(read_field(result, "stderr") or "")
end

local function result_exit_code(result)
    return tonumber(read_field(result, "exitCode"))
end

local function result_success_flag(result)
    return read_field(result, "success") == true
end

local function is_success(result)
    return result ~= nil and result_stderr(result) == ""
end

local function command_failed(result)
    if result == nil then
        return true
    end
    local code = result_exit_code(result)
    if code ~= nil then
        return code ~= 0
    end
    if result_success_flag(result) then
        return false
    end
    return result_stderr(result) ~= "" and result_stdout(result) == ""
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function shell_arg(value)
    local text = tostring(value or "")
    if text:match("^[A-Za-z0-9_./:@%%+=,-]+$") ~= nil then
        return text
    end
    return shell_quote(text)
end

local function join_path(...)
    local parts = { ... }
    local cleaned = {}
    for _, part in ipairs(parts) do
        local text = trim(part)
        if text ~= "" then
            text = text:gsub("/+$", "")
            if #cleaned == 0 then
                cleaned[#cleaned + 1] = text
            else
                cleaned[#cleaned + 1] = text:gsub("^/+", "")
            end
        end
    end
    return table.concat(cleaned, "/")
end

local function dirname(path)
    local text = trim(path)
    if text == "" then
        return nil
    end
    local normalized = text:gsub("/+$", "")
    local dir = normalized:match("^(.*)/[^/]+$")
    if dir == nil or dir == "" then
        return "."
    end
    return dir
end

local function directory_exists(context, path)
    local result = exec_run(context, "test -d " .. shell_quote(path))
    return is_success(result)
end

local function ensure_directory(context, path)
    local cleaned = trim(path)
    if cleaned == "" then
        return false
    end
    local result = exec_run(context, "mkdir -p " .. shell_quote(cleaned))
    return is_success(result)
end

local function read_text_file(context, path)
    local result = exec_run(context, "cat " .. shell_quote(path))
    if not is_success(result) then
        return nil
    end
    return read_field(result, "stdout")
end

local function write_text_file(context, path, content)
    local dir = dirname(path)
    if dir ~= nil and dir ~= "." and not ensure_directory(context, dir) then
        return false
    end
    local command = "printf %s " .. shell_quote(content or "") .. " > " .. shell_quote(path)
    local result = exec_run(context, command)
    return is_success(result)
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
                decode_error("expected ':' after key")
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
        decode_error("unexpected token")
    end

    local value = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("unexpected trailing content")
    end
    return value
end

local function parse_json(raw)
    local ok, result = pcall(decode_json_internal, raw)
    if ok then
        return result, nil
    end
    return nil, result
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
    return '"' .. text .. '"'
end

local function is_array(value)
    if type(value) ~= "table" then
        return false
    end
    local count = 0
    for key, _ in pairs(value) do
        if type(key) ~= "number" then
            return false
        end
        count = count + 1
    end
    for index = 1, count do
        if value[index] == nil then
            return false
        end
    end
    return true
end

local function json_encode(value)
    local value_type = type(value)
    if value == nil or value == JSON_NULL then
        return "null"
    end
    if value_type == "string" then
        return json_escape(value)
    end
    if value_type == "number" or value_type == "boolean" then
        return tostring(value)
    end
    if value_type ~= "table" then
        return json_escape(tostring(value))
    end
    if is_array(value) then
        local parts = {}
        for _, item in ipairs(value) do
            parts[#parts + 1] = json_encode(item)
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for key, _ in pairs(value) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = json_escape(key) .. ":" .. json_encode(value[key])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function sequence_values(value)
    local items = {}
    if type(value) == "table" then
        for _, item in ipairs(value) do
            items[#items + 1] = item
        end
    end
    return items
end

local function flag_map(context, packages)
    local map = {}
    local function add_flags(values)
        for _, raw in ipairs(sequence_values(values)) do
            local text = trim(raw)
            if text ~= "" then
                local key, value = text:match("^([^=]+)=(.*)$")
                if key ~= nil then
                    map[trim(key)] = value
                else
                    map[text] = true
                end
            end
        end
    end
    add_flags(read_field(context, "flags"))
    add_flags(read_field(read_field(context, "request"), "flags"))
    for _, package in ipairs(packages or {}) do
        add_flags(read_field(package, "flags"))
    end
    return map
end

local function flag_value(flags, key)
    local value = flags[key]
    if value == true then
        return key
    end
    return value
end

local function plugin_dir(context)
    local explicit = read_field(read_field(context, "plugin"), "dir")
    if explicit ~= nil then
        return trim(explicit)
    end
    return "."
end

local function current_workdir(context)
    local request = read_field(context, "request")
    local flags = flag_map(context, request and read_field(request, "packages") or nil)
    return first_nonempty(flag_value(flags, "cwd"), flag_value(flags, "project-root"), ".")
end

local function cache_root(context, flags)
    local override = trim(flag_value(flags, "cache-root") or "")
    if override ~= "" then
        return join_path(override, PLUGIN_ID)
    end
    return join_path(plugin_dir(context), ".reqpack-data", "cache")
end

local function sanitize_key(text)
    local key = lower(trim(text))
    key = key:gsub("https://script%.google%.com/d/", "")
    key = key:gsub("[^%w%._%-]", "-")
    key = key:gsub("%-+", "-")
    key = key:gsub("^%-+", "")
    key = key:gsub("%-+$", "")
    if key == "" then
        return "default"
    end
    return key
end

local function project_hash(path)
    return sanitize_key(trim(path):gsub("/", "__"))
end

local function auth_cache_path(context, flags)
    return join_path(cache_root(context, flags), "auth.json")
end

local function scripts_cache_path(context, flags)
    return join_path(cache_root(context, flags), "scripts.json")
end

local function deployments_cache_path(context, flags, script_id)
    return join_path(cache_root(context, flags), "scripts", sanitize_key(script_id), "deployments.json")
end

local function versions_cache_path(context, flags, script_id)
    return join_path(cache_root(context, flags), "scripts", sanitize_key(script_id), "versions.json")
end

local function project_cache_path(context, flags, path)
    return join_path(cache_root(context, flags), "projects", project_hash(path), "project.json")
end

local function status_cache_path(context, flags, path)
    return join_path(cache_root(context, flags), "projects", project_hash(path), "status.json")
end

local function load_json_cache(context, path)
    local raw = read_text_file(context, path)
    if raw == nil or trim(raw) == "" then
        return nil
    end
    local decoded = parse_json(raw)
    return decoded
end

local function save_json_cache(context, path, value)
    return write_text_file(context, path, json_encode(value))
end

local function append_global_options(parts, flags)
    if flags["user"] ~= nil then
        parts[#parts + 1] = "--user"
        parts[#parts + 1] = shell_arg(flag_value(flags, "user"))
    end
    if flags["project"] ~= nil then
        parts[#parts + 1] = "--project"
        parts[#parts + 1] = shell_arg(flag_value(flags, "project"))
    end
    if flags["auth"] ~= nil then
        parts[#parts + 1] = "--auth"
        parts[#parts + 1] = shell_arg(flag_value(flags, "auth"))
    end
    if flags["adc"] ~= nil then
        parts[#parts + 1] = "--adc"
    end
    if flags["json"] ~= nil then
        parts[#parts + 1] = "--json"
    end
end

local function clasp_command(flags, args)
    local parts = { REQUIRED_BINARY }
    append_global_options(parts, flags or {})
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = arg
    end
    return table.concat(parts, " ")
end

local function in_directory(path, command)
    local target = trim(path or "")
    if target == "" or target == "." then
        return command
    end
    return "cd " .. shell_quote(target) .. " && " .. command
end

local function package_name(package)
    return first_nonempty(read_field(package, "name"), read_field(package, "packageId"), read_field(package, "id"))
end

local function package_version(package)
    return first_nonempty(read_field(package, "version"), read_field(package, "latestVersion"))
end

local function parse_target(raw)
    local text = trim(raw)
    if text == "" then
        return nil, nil
    end
    local prefix, value = text:match("^([a-zA-Z0-9_%-]+):(.*)$")
    if prefix ~= nil then
        return lower(prefix), trim(value)
    end
    return "script", text
end

local function normalize_script_id(raw)
    local value = trim(raw)
    local from_url = value:match("https://script%.google%.com/d/([^/]+)/")
    return trim(from_url or value)
end

local function package_target(package)
    local kind, value = parse_target(package_name(package))
    if kind == nil or value == nil or value == "" then
        return nil
    end
    if kind == "script" then
        return {
            kind = kind,
            value = value,
            scriptId = normalize_script_id(value),
            package = package,
        }
    end
    if kind == "project" then
        return {
            kind = kind,
            value = value,
            path = value,
            package = package,
        }
    end
    if kind == "deployment" then
        return {
            kind = kind,
            value = value,
            deploymentId = value,
            package = package,
        }
    end
    return {
        kind = kind,
        value = value,
        package = package,
    }
end

local function current_project_file(context, path)
    return join_path(path or current_workdir(context), ".clasp.json")
end

local function read_project_json(context, path)
    local raw = read_text_file(context, current_project_file(context, path))
    if raw == nil or trim(raw) == "" then
        return nil
    end
    local decoded = parse_json(raw)
    return decoded
end

local function build_script_url(script_id)
    if script_id == nil or trim(script_id) == "" then
        return nil
    end
    return "https://script.google.com/d/" .. trim(script_id) .. "/edit"
end

local function normalize_auth_info(decoded)
    if type(decoded) ~= "table" then
        return nil
    end
    return {
        loggedIn = json_value(read_field(decoded, "loggedIn")) == true,
        email = json_value(read_field(decoded, "email")),
        clientId = json_value(read_field(decoded, "clientId")),
        clientType = json_value(read_field(decoded, "clientType")),
    }
end

local function query_json_command(context, command, cache_path)
    local result = exec_run(context, command)
    if command_failed(result) then
        return nil, first_nonempty(result_stderr(result), result_stdout(result), "command failed")
    end
    local decoded, err = parse_json(read_field(result, "stdout"))
    if decoded == nil then
        return nil, err or "json parse failed"
    end
    if cache_path ~= nil then
        save_json_cache(context, cache_path, decoded)
    end
    return decoded, nil
end

local function cached_or_query_auth(context, flags)
    local decoded = select(1, query_json_command(context, clasp_command(flags, { "show-authorized-user", "--json" }), auth_cache_path(context, flags)))
    if decoded ~= nil then
        return normalize_auth_info(decoded)
    end
    return normalize_auth_info(load_json_cache(context, auth_cache_path(context, flags)))
end

local function normalize_script_record(value)
    if type(value) ~= "table" then
        return nil
    end
    local script_id = first_nonempty(json_value(read_field(value, "id")), json_value(read_field(value, "scriptId")))
    if script_id == nil then
        return nil
    end
    return {
        id = script_id,
        name = first_nonempty(json_value(read_field(value, "name")), script_id),
    }
end

local function cached_or_query_scripts(context, flags)
    local decoded = select(1, query_json_command(context, clasp_command(flags, { "list-scripts", "--json" }), scripts_cache_path(context, flags)))
    if type(decoded) == "table" then
        local items = {}
        for _, record in ipairs(decoded) do
            local normalized = normalize_script_record(record)
            if normalized ~= nil then
                items[#items + 1] = normalized
            end
        end
        return items
    end
    local cached = load_json_cache(context, scripts_cache_path(context, flags))
    local items = {}
    for _, record in ipairs(cached or {}) do
        local normalized = normalize_script_record(record)
        if normalized ~= nil then
            items[#items + 1] = normalized
        end
    end
    return items
end

local function normalize_deployments(decoded)
    local items = {}
    for _, entry in ipairs(decoded or {}) do
        if type(entry) == "table" then
            items[#items + 1] = {
                deploymentId = json_value(read_field(entry, "deploymentId")),
                versionNumber = json_value(read_field(entry, "versionNumber")),
                description = json_value(read_field(entry, "description")),
            }
        end
    end
    return items
end

local function normalize_versions(decoded)
    local items = {}
    for _, entry in ipairs(decoded or {}) do
        if type(entry) == "table" then
            items[#items + 1] = {
                versionNumber = json_value(read_field(entry, "versionNumber")),
                description = json_value(read_field(entry, "description")),
            }
        end
    end
    return items
end

local function normalize_status(decoded)
    if type(decoded) ~= "table" then
        return { filesToPush = {}, untrackedFiles = {} }
    end
    return {
        filesToPush = sequence_values(json_value(read_field(decoded, "filesToPush"))),
        untrackedFiles = sequence_values(json_value(read_field(decoded, "untrackedFiles"))),
    }
end

local function cached_or_query_deployments(context, flags, script_id)
    if script_id == nil or script_id == "" then
        return {}
    end
    local cache_path = deployments_cache_path(context, flags, script_id)
    local decoded = select(1, query_json_command(context, clasp_command(flags, { "list-deployments", shell_arg(script_id), "--json" }), cache_path))
    if type(decoded) == "table" then
        return normalize_deployments(decoded)
    end
    return normalize_deployments(load_json_cache(context, cache_path))
end

local function cached_or_query_versions(context, flags, script_id)
    if script_id == nil or script_id == "" then
        return {}
    end
    local cache_path = versions_cache_path(context, flags, script_id)
    local decoded = select(1, query_json_command(context, clasp_command(flags, { "list-versions", shell_arg(script_id), "--json" }), cache_path))
    if type(decoded) == "table" then
        return normalize_versions(decoded)
    end
    return normalize_versions(load_json_cache(context, cache_path))
end

local function cached_or_query_status(context, flags, path)
    if path == nil or trim(path) == "" then
        return { filesToPush = {}, untrackedFiles = {} }
    end
    local cache_path = status_cache_path(context, flags, path)
    if read_project_json(context, path) ~= nil then
        local decoded = select(1, query_json_command(context, in_directory(path, clasp_command(flags, { "show-file-status", "--json" })), cache_path))
        if decoded ~= nil then
            return normalize_status(decoded)
        end
    end
    return normalize_status(load_json_cache(context, cache_path))
end

local function load_project_cache(context, flags, path)
    if path == nil or trim(path) == "" then
        return nil
    end
    return load_json_cache(context, project_cache_path(context, flags, path))
end

local function latest_version_number(versions)
    local last = nil
    for _, version in ipairs(versions or {}) do
        local current = tonumber(version.versionNumber)
        local prior = last and tonumber(last.versionNumber) or nil
        if current ~= nil and (prior == nil or current > prior) then
            last = version
        end
    end
    return last
end

local function join_lines(items)
    local values = {}
    for _, item in ipairs(items or {}) do
        local text = trim(item)
        if text ~= "" then
            values[#values + 1] = text
        end
    end
    return table.concat(values, ", ")
end

local function make_item(base)
    local item = shallow_copy(base or {})
    item.type = item.type or "package"
    item.extraFields = shallow_copy(item.extraFields)
    return item
end

local function fallback_item(base, extras)
    local item = make_item(base)
    for key, value in pairs(extras or {}) do
        item.extraFields[key] = value
    end
    return item
end

local function project_item_from_state(state, auth)
    if type(state) ~= "table" then
        return nil
    end
    local script_id = first_nonempty(state.scriptId, read_field(read_field(state, "project"), "scriptId"))
    local path = first_nonempty(state.projectPath, read_field(read_field(state, "project"), "projectPath"))
    local deployments = sequence_values(state.deployments)
    local versions = sequence_values(state.versions)
    local status = normalize_status(state.status)
    local latest_version = latest_version_number(versions)
    local name = first_nonempty(state.name, read_field(read_field(state, "project"), "name"), script_id, path)
    local package_id = script_id ~= nil and ("script:" .. script_id) or (path ~= nil and ("project:" .. path) or name)
    local summary_parts = {}
    if path ~= nil then
        summary_parts[#summary_parts + 1] = path
    end
    if script_id ~= nil then
        summary_parts[#summary_parts + 1] = script_id
    end
    local item = make_item({
        name = name,
        packageId = package_id,
        version = latest_version and tostring(latest_version.versionNumber) or first_nonempty(state.version, "local"),
        latestVersion = latest_version and tostring(latest_version.versionNumber) or first_nonempty(state.latestVersion, "local"),
        installed = script_id ~= nil or (path ~= nil and trim(path) ~= ""),
        status = path ~= nil and "local" or "installed",
        summary = join_lines(summary_parts),
        description = join_lines({
            name,
            path and ("path: " .. path) or nil,
            script_id and ("scriptId: " .. script_id) or nil,
            (#deployments > 0) and (tostring(#deployments) .. " deployments") or nil,
            (#versions > 0) and (tostring(#versions) .. " versions") or nil,
        }),
        homepage = build_script_url(script_id),
        packageType = path ~= nil and "project" or "script",
        extraFields = {
            scriptId = script_id,
            projectPath = path,
            rootDir = read_field(read_field(state, "project"), "rootDir"),
            projectId = read_field(read_field(state, "project"), "projectId"),
            deployments = deployments,
            versions = versions,
            fileStatus = status,
            auth = auth,
            cachePath = state.cachePath,
        },
    })
    return item
end

local function load_local_project_state(context, flags, path, auth)
    local project = read_project_json(context, path)
    if type(project) ~= "table" then
        return load_project_cache(context, flags, path)
    end
    local script_id = json_value(read_field(project, "scriptId"))
    local state = {
        name = trim(path):match("([^/]+)$") or trim(path),
        scriptId = script_id,
        projectPath = path,
        project = {
            scriptId = script_id,
            rootDir = json_value(read_field(project, "rootDir")),
            projectId = json_value(read_field(project, "projectId")),
            projectPath = path,
            name = trim(path):match("([^/]+)$") or trim(path),
        },
        deployments = cached_or_query_deployments(context, flags, script_id),
        versions = cached_or_query_versions(context, flags, script_id),
        status = cached_or_query_status(context, flags, path),
        cachePath = project_cache_path(context, flags, path),
        auth = auth,
    }
    return state
end

local function item_for_script_record(context, flags, record, auth)
    local script_id = record.id
    local state = {
        name = record.name,
        scriptId = script_id,
        deployments = cached_or_query_deployments(context, flags, script_id),
        versions = cached_or_query_versions(context, flags, script_id),
        cachePath = scripts_cache_path(context, flags),
        auth = auth,
    }
    return project_item_from_state(state, auth)
end

local function resolve_item(context, flags, target)
    local auth = cached_or_query_auth(context, flags)
    if target.kind == "project" then
        local state = load_local_project_state(context, flags, target.path, auth)
        return project_item_from_state(state, auth)
    end
    if target.kind == "script" then
        local scripts = cached_or_query_scripts(context, flags)
        for _, record in ipairs(scripts) do
            if trim(record.id) == trim(target.scriptId) or lower(record.name) == lower(target.value) then
                return item_for_script_record(context, flags, record, auth)
            end
        end
        return project_item_from_state({
            name = target.scriptId,
            scriptId = target.scriptId,
            deployments = cached_or_query_deployments(context, flags, target.scriptId),
            versions = cached_or_query_versions(context, flags, target.scriptId),
            auth = auth,
            cachePath = scripts_cache_path(context, flags),
        }, auth)
    end
    if target.kind == "deployment" then
        return fallback_item({
            name = target.deploymentId,
            packageId = "deployment:" .. target.deploymentId,
            version = nil,
            latestVersion = nil,
            installed = true,
            status = "installed",
            summary = "deployment " .. target.deploymentId,
            description = "clasp deployment " .. target.deploymentId,
            packageType = "deployment",
        }, {
            deploymentId = target.deploymentId,
            auth = auth,
        })
    end
    return nil
end

local function maybe_target_path(target, flags, context)
    if target ~= nil and target.path ~= nil then
        return target.path
    end
    return first_nonempty(flag_value(flags, "cwd"), flag_value(flags, "project-root"), current_workdir(context))
end

local function install_clone(context, flags, target)
    begin_step(context, "clone clasp script " .. target.scriptId)
    local args = { "clone-script", shell_arg(target.value) }
    if flags["versionNumber"] ~= nil then
        args[#args + 1] = shell_arg(flag_value(flags, "versionNumber"))
    end
    if flags["rootDir"] ~= nil then
        args[#args + 1] = "--rootDir"
        args[#args + 1] = shell_arg(flag_value(flags, "rootDir"))
    end
    local result = exec_run(context, clasp_command(flags, args))
    if command_failed(result) then
        tx_failed(context, first_nonempty(result_stderr(result), result_stdout(result), "clasp clone-script failed"))
        return nil
    end
    local item = resolve_item(context, flags, target)
    if item ~= nil then
        return item
    end
    return fallback_item({
        name = target.scriptId,
        packageId = "script:" .. target.scriptId,
        version = package_version(target.package),
        latestVersion = package_version(target.package),
        installed = true,
        status = "installed",
        homepage = build_script_url(target.scriptId),
        packageType = "script",
    }, { scriptId = target.scriptId })
end

local function install_create(context, flags, target)
    local path = target.path
    if path == nil or trim(path) == "" then
        tx_failed(context, "project path required")
        return nil
    end
    if not ensure_directory(context, path) then
        tx_failed(context, "unable to create project directory")
        return nil
    end
    begin_step(context, "create clasp script in " .. path)
    local args = { "create-script" }
    if flags["title"] ~= nil then
        args[#args + 1] = "--title"
        args[#args + 1] = shell_arg(flag_value(flags, "title"))
    end
    if flags["type"] ~= nil then
        args[#args + 1] = "--type"
        args[#args + 1] = shell_arg(flag_value(flags, "type"))
    end
    if flags["parentId"] ~= nil then
        args[#args + 1] = "--parentId"
        args[#args + 1] = shell_arg(flag_value(flags, "parentId"))
    end
    if flags["rootDir"] ~= nil then
        args[#args + 1] = "--rootDir"
        args[#args + 1] = shell_arg(flag_value(flags, "rootDir"))
    end
    local result = exec_run(context, in_directory(path, clasp_command(flags, args)))
    if command_failed(result) then
        tx_failed(context, first_nonempty(result_stderr(result), result_stdout(result), "clasp create-script failed"))
        return nil
    end
    local item = resolve_item(context, flags, target)
    if item ~= nil then
        return item
    end
    return fallback_item({
        name = trim(path):match("([^/]+)$") or trim(path),
        packageId = "project:" .. path,
        version = "local",
        latestVersion = "local",
        installed = true,
        status = "local",
        summary = path,
        description = "clasp project " .. path,
        packageType = "project",
    }, { projectPath = path })
end

local function remove_deployment(context, flags, target)
    begin_step(context, "delete clasp deployment " .. target.deploymentId)
    local args = { "delete-deployment", shell_arg(target.deploymentId) }
    if flags["all"] ~= nil then
        args[#args + 1] = "--all"
    end
    local result = exec_run(context, clasp_command(flags, args))
    if command_failed(result) then
        tx_failed(context, first_nonempty(result_stderr(result), result_stdout(result), "clasp delete-deployment failed"))
        return nil
    end
    local item = resolve_item(context, flags, target)
    if item ~= nil then
        return item
    end
    return fallback_item({
        name = target.deploymentId,
        packageId = "deployment:" .. target.deploymentId,
        installed = true,
        status = "installed",
        packageType = "deployment",
    }, { deploymentId = target.deploymentId })
end

local function remove_script(context, flags, path)
    begin_step(context, "delete clasp script")
    local result = exec_run(context, in_directory(path, clasp_command(flags, { "delete-script", "--force" })))
    if command_failed(result) then
        tx_failed(context, first_nonempty(result_stderr(result), result_stdout(result), "clasp delete-script failed"))
        return false
    end
    return true
end

local function update_project(context, flags, path, target)
    local updated = {}
    local function run_step(label, args)
        begin_step(context, label)
        local result = exec_run(context, in_directory(path, clasp_command(flags, args)))
        if command_failed(result) then
            tx_failed(context, first_nonempty(result_stderr(result), result_stdout(result), label .. " failed"))
            return nil
        end
        updated[#updated + 1] = label
        return result
    end

    if flags["pull"] ~= nil then
        if run_step("pull clasp project", { "pull" }) == nil then
            return nil
        end
    end
    if flags["push"] ~= nil or flags["pull"] == nil then
        local args = { "push" }
        if flags["force"] ~= nil then
            args[#args + 1] = "--force"
        end
        if run_step("push clasp project", args) == nil then
            return nil
        end
    end
    if flags["version-description"] ~= nil then
        if run_step("create clasp version", { "create-version", shell_arg(flag_value(flags, "version-description")) }) == nil then
            return nil
        end
    end
    if flags["deployment-description"] ~= nil or flags["deploymentId"] ~= nil or flags["versionNumber"] ~= nil then
        local args = { "create-deployment" }
        if flags["versionNumber"] ~= nil then
            args[#args + 1] = "--versionNumber"
            args[#args + 1] = shell_arg(flag_value(flags, "versionNumber"))
        end
        if flags["deployment-description"] ~= nil then
            args[#args + 1] = "--description"
            args[#args + 1] = shell_arg(flag_value(flags, "deployment-description"))
        end
        if flags["deploymentId"] ~= nil then
            args[#args + 1] = "--deploymentId"
            args[#args + 1] = shell_arg(flag_value(flags, "deploymentId"))
        end
        if run_step("create clasp deployment", args) == nil then
            return nil
        end
    end
    local item = resolve_item(context, flags, target or { kind = "project", path = path })
    if item ~= nil then
        item.extraFields.updateSteps = updated
        return item
    end
    return fallback_item({
        name = trim(path):match("([^/]+)$") or trim(path),
        packageId = "project:" .. path,
        version = flag_value(flags, "versionNumber") or "local",
        latestVersion = flag_value(flags, "versionNumber") or "local",
        installed = true,
        status = "local",
        packageType = "project",
    }, { projectPath = path, updateSteps = updated })
end

local function installed_lookup(context, flags)
    local local_items = {}
    local remote_items = {}
    local local_path = current_workdir(context)
    local auth = cached_or_query_auth(context, flags)
    local local_state = load_local_project_state(context, flags, local_path, auth)
    local local_item = project_item_from_state(local_state, auth)
    if local_item ~= nil then
        local_items[#local_items + 1] = local_item
    end
    local scripts = cached_or_query_scripts(context, flags)
    local seen = {}
    for _, item in ipairs(local_items) do
        seen[item.packageId] = true
        local script_id = read_field(item.extraFields, "scriptId")
        if script_id ~= nil then
            seen["script:" .. script_id] = true
        end
    end
    for _, record in ipairs(scripts) do
        local item = item_for_script_record(context, flags, record, auth)
        if item ~= nil and not seen[item.packageId] then
            seen[item.packageId] = true
            remote_items[#remote_items + 1] = item
        end
    end
    table.sort(remote_items, function(left, right)
        return lower(left.name or left.packageId or "") < lower(right.name or right.packageId or "")
    end)
    local items = {}
    for _, item in ipairs(local_items) do
        items[#items + 1] = item
    end
    for _, item in ipairs(remote_items) do
        items[#items + 1] = item
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
    return { "Google", "Apps Script", "Package Manager", "Project Manager" }
end

function plugin.init()
    return true
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network", "filesystem.read", "filesystem.write" },
        ecosystemScopes = { "google-apps-script", "google-drive" },
        writeScopes = {
            {
                path = join_path(plugin_dir(nil), ".reqpack-data"),
                reason = "ReqPack-managed clasp shared cache and cached project metadata",
            },
            { kind = "user-home-subpath", value = ".clasprc.json" },
        },
        networkScopes = {
            { host = "script.google.com", scheme = "https", pathPrefix = "/" },
            { host = "script.googleapis.com", scheme = "https", pathPrefix = "/" },
            { host = "www.googleapis.com", scheme = "https", pathPrefix = "/" },
            { host = "oauth2.googleapis.com", scheme = "https", pathPrefix = "/" },
            { host = "accounts.google.com", scheme = "https", pathPrefix = "/" },
        },
        privilegeLevel = "none",
    }
end

function plugin.getMissingPackages(packages)
    packages = packages or {}
    local missing = {}
    for _, package in ipairs(packages) do
        missing[#missing + 1] = package
    end
    return missing
end

function plugin.install(context, packages)
    local local_path = first_nonempty(read_field(read_field(context, "request"), "localPath"), read_field(context, "localPath"))
    if local_path ~= nil then
        return plugin.installLocal(context, local_path)
    end
    packages = packages or sequence_values(read_field(read_field(context, "request"), "packages"))
    if packages == nil or #packages == 0 then
        return true
    end
    local flags = flag_map(context, packages)
    local installed = {}
    for _, package in ipairs(packages) do
        local target = package_target(package)
        if target == nil then
            tx_failed(context, "install requires package name")
            return false
        end
        local item = nil
        if target.kind == "script" then
            item = install_clone(context, flags, target)
        elseif target.kind == "project" then
            item = install_create(context, flags, target)
        else
            tx_failed(context, "unsupported install target: " .. tostring(target.kind))
            return false
        end
        if item == nil then
            return false
        end
        installed[#installed + 1] = item
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" then
        tx_failed(context, "installLocal requires project path")
        return false
    end
    local flags = flag_map(context, nil)
    begin_step(context, "push local clasp project")
    local args = { "push" }
    if flags["force"] ~= nil then
        args[#args + 1] = "--force"
    end
    local result = exec_run(context, in_directory(local_path, clasp_command(flags, args)))
    if command_failed(result) then
        tx_failed(context, first_nonempty(result_stderr(result), result_stdout(result), "clasp push failed"))
        return false
    end
    emit_event(context, "installed", { path = local_path, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    packages = packages or {}
    if #packages == 0 then
        return true
    end
    local flags = flag_map(context, packages)
    local removed = {}
    for _, package in ipairs(packages) do
        local target = package_target(package)
        if target == nil then
            tx_failed(context, "remove requires package name")
            return false
        end
        if target.kind == "deployment" then
            local item = remove_deployment(context, flags, target)
            if item == nil then
                return false
            end
            removed[#removed + 1] = item
        elseif target.kind == "project" or target.kind == "script" then
            if flags["delete-script"] == nil then
                tx_failed(context, "set delete-script flag to remove Apps Script project")
                return false
            end
            local path = maybe_target_path(target, flags, context)
            if path == nil or trim(path) == "" then
                tx_failed(context, "project path required for delete-script")
                return false
            end
            if not remove_script(context, flags, path) then
                return false
            end
            local item = resolve_item(context, flags, target)
            removed[#removed + 1] = item or make_item({ name = package_name(package), packageId = package_name(package), packageType = target.kind })
        else
            tx_failed(context, "unsupported remove target: " .. tostring(target.kind))
            return false
        end
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    packages = packages or sequence_values(read_field(read_field(context, "request"), "packages"))
    local flags = flag_map(context, packages)
    if packages == nil or #packages == 0 then
        local path = maybe_target_path(nil, flags, context)
        local item = update_project(context, flags, path, { kind = "project", path = path })
        if item == nil then
            return false
        end
        emit_event(context, "updated", { item })
        tx_success(context)
        return true
    end
    local updated = {}
    for _, package in ipairs(packages) do
        local target = package_target(package)
        if target == nil then
            tx_failed(context, "update requires package name")
            return false
        end
        local path = maybe_target_path(target, flags, context)
        local item = update_project(context, flags, path, target)
        if item == nil then
            return false
        end
        updated[#updated + 1] = item
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local flags = flag_map(context, nil)
    local items = installed_lookup(context, flags)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local empty = {}
    emit_event(context, "outdated", empty)
    return empty
end

function plugin.search(context, prompt)
    local flags = flag_map(context, nil)
    local query = lower(first_nonempty(prompt, read_field(context, "prompt"), read_field(read_field(context, "request"), "prompt")) or "")
    if query == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    local items = installed_lookup(context, flags)
    local results = {}
    local seen = {}
    for _, item in ipairs(items) do
        local extra = item.extraFields or {}
        local haystack = lower(table.concat({
            trim(item.name or ""),
            trim(item.packageId or ""),
            trim(item.homepage or ""),
            trim(read_field(extra, "scriptId") or ""),
            trim(read_field(extra, "projectPath") or ""),
        }, "\n"))
        if haystack:find(query, 1, true) ~= nil and not seen[item.packageId] then
            seen[item.packageId] = true
            results[#results + 1] = item
        end
    end
    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local flags = flag_map(context, nil)
    local query = first_nonempty(name, read_field(context, "prompt"), read_field(read_field(context, "request"), "prompt"), read_field(read_field(context, "request"), "name"))
    if query == nil then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local target = package_target({ name = query })
    local item = target and resolve_item(context, flags, target) or nil
    if item == nil then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local target = package_target(package)
    if target == nil then
        return nil
    end
    return resolve_item(context, flag_map(context, { package }), target)
end

function plugin.shutdown()
    return true
end

return plugin
