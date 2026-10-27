plugin = {}
plugin.fileExtensions = {}

local PLUGIN_ID = "gh"
local PLUGIN_NAME = "GitHub CLI"
local PLUGIN_VERSION = "0.1.0"
local APP_PACKAGE_NAME = "app:gh"
local CODEQL_PACKAGE_NAME = "codeql"
local CODEQL_EXTENSION_REPO = "github/gh-codeql"
local JSON_NULL = {}

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

local function split_tabular_line(line)
    local fields = {}
    for part in tostring(line or ""):gmatch("[^%s].-[^%s]") do
        fields[#fields + 1] = trim(part)
    end
    if #fields <= 1 then
        fields = {}
        for part in tostring(line or ""):gmatch("[^%s][^%s]*") do
            fields[#fields + 1] = trim(part)
        end
    end
    return fields
end

local function split_by_multi_space(line)
    local result = {}
    local text = tostring(line or "")
    local last = 1
    while true do
        local start_index, end_index = text:find("%s%s+", last)
        if start_index == nil then
            local tail = trim(text:sub(last))
            if tail ~= "" then
                result[#result + 1] = tail
            end
            break
        end
        local segment = trim(text:sub(last, start_index - 1))
        if segment ~= "" then
            result[#result + 1] = segment
        end
        last = end_index + 1
    end
    return result
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

local function merge_tables(left, right)
    local merged = shallow_copy(type(left) == "table" and left or {})
    for key, item in pairs(type(right) == "table" and right or {}) do
        merged[key] = item
    end
    return merged
end

local function shell_quote(value)
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,]+$") ~= nil then
        return text
    end
    return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function strict_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local raw = tostring(select(index, ...) or "")
        if raw ~= "" then
            raw = raw:gsub("/+$", "")
            if #parts > 0 then
                raw = raw:gsub("^/+", "")
            end
            parts[#parts + 1] = raw
        end
    end
    return table.concat(parts, "/")
end

local function parent_dir(path)
    local text = tostring(path or "")
    local match = text:match("^(.*)/[^/]+$")
    if match ~= nil and match ~= "" then
        return match
    end
    if starts_with(text, "/") then
        return "/"
    end
    return "."
end

local function final_path_segment(path)
    local text = tostring(path or ""):gsub("/+$", "")
    local segment = text:match("([^/]+)$")
    return trim(segment)
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
    if type(first) == "table" and first.success ~= nil then
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
            for key, item in pairs(value) do
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
    if next(result) == nil then
        return {
            success = false,
            stdout = "",
            stderr = "command execution failed",
            exitCode = 1,
        }
    end
    return result
end

local function run_command(context, command)
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

local function is_command_success(result)
    if type(result) ~= "table" then
        return false
    end
    if result.success or result.ok then
        return true
    end
    local exit_code = result.exitCode or result.exit_code or result.code or result.status
    return exit_code == 0
end

local function safe_getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        return os.getenv(name)
    end
    return nil
end

local function home_dir()
    return first_nonempty(safe_getenv("HOME"), "/home/test")
end

local function shared_root()
    local cache_home = first_nonempty(safe_getenv("XDG_CACHE_HOME"), join_path(home_dir(), ".cache"))
    return join_path(cache_home, "reqpack", PLUGIN_ID)
end

local function state_root()
    return join_path(shared_root(), "state")
end

local function skills_root()
    return join_path(shared_root(), "skills")
end

local function managed_skill_dir()
    return join_path(skills_root(), "managed")
end

local function skills_manifest_path()
    return join_path(state_root(), "skills-manifest.json")
end

local function codeql_state_path()
    return join_path(state_root(), "codeql-state.json")
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

local function ensure_directory(context, path)
    local result = run_command(context, "mkdir -p " .. strict_quote(path))
    if is_command_success(result) then
        return true, nil
    end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to create directory")
end

local function write_text_file(context, path, content)
    local ok, err = ensure_directory(context, parent_dir(path))
    if not ok then
        return nil, err
    end
    local handle = io.open(path, "wb")
    if handle == nil then
        return nil, "failed to open file for write: " .. tostring(path)
    end
    local write_ok, write_err = handle:write(content)
    handle:close()
    if not write_ok then
        return nil, tostring(write_err or "write failed")
    end
    return true, nil
end

local function path_exists(context, path)
    local result = run_command(context, "test -e " .. shell_quote(path))
    return is_command_success(result)
end

local function remove_path_if_exists(context, path)
    if not path_exists(context, path) then
        return true, nil
    end
    local result = run_command(context, "rm -rf " .. shell_quote(path))
    if is_command_success(result) then
        return true, nil
    end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to remove path")
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
            elseif current == "\\" then
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
        if peek() == "-" then
            index = index + 1
        end
        if peek() == "0" then
            index = index + 1
        else
            if peek():match("%d") == nil then
                decode_error("invalid number")
            end
            repeat
                index = index + 1
            until index > length or text:sub(index, index):match("%d") == nil
        end
        if peek() == "." then
            index = index + 1
            if peek():match("%d") == nil then
                decode_error("invalid number")
            end
            repeat
                index = index + 1
            until index > length or text:sub(index, index):match("%d") == nil
        end
        local exponent = peek()
        if exponent == "e" or exponent == "E" then
            index = index + 1
            local sign = peek()
            if sign == "+" or sign == "-" then
                index = index + 1
            end
            if peek():match("%d") == nil then
                decode_error("invalid number")
            end
            repeat
                index = index + 1
            until index > length or text:sub(index, index):match("%d") == nil
        end
        local number = tonumber(text:sub(start_index, index - 1))
        if number == nil then
            decode_error("invalid number")
        end
        return number
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
        elseif current == "-" or current:match("%d") ~= nil then
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

local function decode_json(raw)
    if trim(raw) == "" then
        return nil, "empty json"
    end
    local ok, value = pcall(decode_json_internal, raw)
    if not ok then
        return nil, value
    end
    return value, nil
end

local function encode_json_string(value)
    local replacements = {
        ["\\"] = "\\\\",
        ['"'] = '\\"',
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
    }
    return '"' .. tostring(value or ""):gsub('[%z\1-\31\\"]', function(char)
        return replacements[char] or string.format("\\u%04x", char:byte())
    end) .. '"'
end

local function is_array_table(value)
    if type(value) ~= "table" then
        return false
    end
    local count = 0
    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
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

local function encode_json(value)
    local value_type = type(value)
    if value == nil or value == JSON_NULL then
        return "null"
    elseif value_type == "string" then
        return encode_json_string(value)
    elseif value_type == "number" or value_type == "boolean" then
        return tostring(value)
    elseif value_type == "table" then
        if is_array_table(value) then
            local parts = {}
            for _, item in ipairs(value) do
                parts[#parts + 1] = encode_json(item)
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
            parts[#parts + 1] = encode_json_string(key) .. ":" .. encode_json(value[key])
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return encode_json_string(tostring(value))
end

local function load_json_file(path, default_value)
    local content = read_text_file(path)
    if content == nil then
        return shallow_copy(default_value or {})
    end
    local decoded = select(1, decode_json(content))
    if type(decoded) ~= "table" then
        return shallow_copy(default_value or {})
    end
    return decoded
end

local function save_json_file(context, path, value)
    return write_text_file(context, path, encode_json(value) .. "\n")
end

local function parse_frontmatter(content)
    local text = tostring(content or "")
    if not starts_with(text, "---\n") then
        return nil
    end
    local close_index = text:find("\n---\n", 5, true)
    if close_index == nil then
        return nil
    end
    local body = text:sub(5, close_index - 1)
    local parsed = {}
    local current_parent = nil
    for _, line in ipairs(split_lines(body)) do
        if trim(line) ~= "" then
            local indent, key, value = line:match("^(%s*)([^:]+):%s*(.-)%s*$")
            if key ~= nil then
                local clean_key = trim(key)
                local clean_value = trim(value)
                if indent == "" or indent == nil then
                    current_parent = nil
                    if clean_value == "" then
                        parsed[clean_key] = {}
                        current_parent = clean_key
                    else
                        parsed[clean_key] = clean_value
                    end
                elseif current_parent ~= nil and type(parsed[current_parent]) == "table" then
                    parsed[current_parent][clean_key] = clean_value
                end
            end
        end
    end
    return parsed
end

local function gh_env_prefix()
    local root = shared_root()
    return table.concat({
        "GH_CONFIG_DIR=" .. strict_quote(join_path(root, "config")),
        "XDG_CACHE_HOME=" .. strict_quote(join_path(root, "xdg-cache")),
        "XDG_STATE_HOME=" .. strict_quote(join_path(root, "xdg-state")),
        "NO_COLOR='1'",
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
    }, " ")
end

local function gh_command(...)
    local args = { ... }
    return gh_env_prefix() .. " gh " .. table.concat(args, " ")
end

local function detect_gh_version(context)
    local result = run_command(context, "gh --version")
    if result == nil or not is_command_success(result) then
        return nil
    end
    local version = trim((result.stdout or ""):match("gh version ([^%s]+)"))
    if version == "" then
        return nil
    end
    return version
end

local function ensure_gh_available(context)
    local version = detect_gh_version(context)
    if version == nil then
        return nil, "gh binary not available"
    end
    return version, nil
end

local function package_name(package)
    return trim(read_field(package, "name") or package or "")
end

local function package_version(package)
    return trim(read_field(package, "version") or "")
end

local function package_flags(package)
    local flags = read_field(package, "flags")
    if type(flags) ~= "table" then
        return {}
    end
    return flags
end

local function infer_package_kind(name, explicit_type)
    local package_type = lower(trim(explicit_type))
    if package_type ~= "" then
        return package_type
    end
    local text = trim(name)
    if lower(text) == APP_PACKAGE_NAME then
        return "app"
    end
    if lower(text) == CODEQL_PACKAGE_NAME or starts_with(lower(text), CODEQL_PACKAGE_NAME .. "@") then
        return "codeql"
    end
    local slash_count = 0
    for _ in text:gmatch("/") do
        slash_count = slash_count + 1
    end
    if slash_count >= 2 then
        return "skill"
    end
    if slash_count == 1 then
        local repo = text:match("^[^/]+/(.+)$") or ""
        if starts_with(repo, "gh-") then
            return "extension"
        end
    end
    return "unknown"
end

local function flag_value(package, prefix)
    for _, flag in ipairs(package_flags(package)) do
        local text = trim(flag)
        if starts_with(text, prefix .. "=") then
            return trim(text:sub(#prefix + 2))
        end
    end
    return nil
end

local function has_flag(package, flag_name)
    for _, flag in ipairs(package_flags(package)) do
        if trim(flag) == flag_name then
            return true
        end
    end
    return false
end

local function parse_extension_package(package)
    local repo = package_name(package)
    local owner, name = repo:match("^([^/]+)/([^/]+)$")
    if owner == nil or name == nil then
        return nil, "invalid gh extension package: " .. repo
    end
    local command_name = name:gsub("^gh%-", "")
    return {
        kind = "extension",
        repo = repo,
        owner = owner,
        repoName = name,
        commandName = command_name,
        packageId = repo,
    }, nil
end

local function parse_skill_package(package)
    local raw = package_name(package)
    local parts = {}
    for segment in raw:gmatch("[^/]+") do
        parts[#parts + 1] = segment
    end
    if #parts < 3 then
        return nil, "invalid gh skill package: " .. raw
    end
    local repo = parts[1] .. "/" .. parts[2]
    local selector_parts = {}
    for index = 3, #parts do
        selector_parts[#selector_parts + 1] = parts[index]
    end
    local selector = table.concat(selector_parts, "/")
    local skill_name = final_path_segment(selector)
    local requested_version = package_version(package)
    if requested_version ~= "" then
        selector = selector .. "@" .. requested_version
    end
    return {
        kind = "skill",
        repo = repo,
        selector = selector,
        selectorPath = table.concat(selector_parts, "/"),
        skillName = skill_name,
        packageId = repo .. "/" .. table.concat(selector_parts, "/"),
        requestedVersion = requested_version,
    }, nil
end

local function parse_codeql_package(package)
    local raw_name = package_name(package)
    local version = package_version(package)
    if starts_with(lower(raw_name), CODEQL_PACKAGE_NAME .. "@") then
        version = trim(raw_name:sub(#CODEQL_PACKAGE_NAME + 2))
    end
    local channel = first_nonempty(flag_value(package, "channel"), "release")
    return {
        kind = "codeql",
        name = CODEQL_PACKAGE_NAME,
        packageId = CODEQL_PACKAGE_NAME,
        version = version,
        channel = channel,
    }
end

local function parse_requested_package(package)
    local name = package_name(package)
    local kind = infer_package_kind(name, read_field(package, "packageType"))
    if kind == "app" then
        return { kind = "app", name = APP_PACKAGE_NAME, packageId = APP_PACKAGE_NAME }, nil
    elseif kind == "extension" then
        return parse_extension_package(package)
    elseif kind == "skill" then
        return parse_skill_package(package)
    elseif kind == "codeql" then
        return parse_codeql_package(package), nil
    end
    return nil, "unsupported gh package: " .. tostring(name)
end

local function build_app_item(version)
    return {
        name = APP_PACKAGE_NAME,
        packageId = APP_PACKAGE_NAME,
        packageType = "app",
        version = version,
        latestVersion = version,
        installed = version ~= nil,
        status = version ~= nil and "installed" or "available",
        summary = "GitHub CLI launcher",
        description = "GitHub CLI launcher",
        homepage = "https://cli.github.com/manual",
        sourceUrl = "https://cli.github.com/manual",
    }
end

local function build_extension_item(spec, installed_record, search_record)
    local description = first_nonempty(
        search_record and read_field(search_record, "description"),
        installed_record and read_field(installed_record, "description"),
        "GitHub CLI extension"
    )
    local version = first_nonempty(
        installed_record and read_field(installed_record, "version"),
        read_field(spec, "version")
    )
    local repo = first_nonempty(
        search_record and read_field(search_record, "fullName"),
        installed_record and read_field(installed_record, "repo"),
        spec.repo
    )
    return {
        name = repo,
        packageId = repo,
        packageType = "extension",
        version = version,
        latestVersion = version,
        installed = installed_record ~= nil,
        status = installed_record ~= nil and "installed" or "available",
        summary = description,
        description = description,
        homepage = first_nonempty(search_record and read_field(search_record, "url"), "https://github.com/" .. repo),
        sourceUrl = first_nonempty(search_record and read_field(search_record, "url"), "https://github.com/" .. repo),
        repository = repo,
        extraFields = {
            commandName = spec.commandName,
            stars = search_record and read_field(search_record, "stargazersCount") or nil,
        },
    }
end

local function build_skill_item(record)
    local item = {
        name = read_field(record, "packageId") or read_field(record, "package_id"),
        packageId = read_field(record, "packageId") or read_field(record, "package_id"),
        packageType = "skill",
        version = first_nonempty(read_field(record, "version"), read_field(record, "requestedVersion")),
        latestVersion = first_nonempty(read_field(record, "version"), read_field(record, "requestedVersion")),
        installed = true,
        status = "installed",
        summary = first_nonempty(read_field(record, "summary"), "GitHub skill"),
        description = first_nonempty(read_field(record, "description"), "GitHub skill"),
        homepage = "https://github.com/" .. tostring(read_field(record, "repo") or ""),
        sourceUrl = "https://github.com/" .. tostring(read_field(record, "repo") or ""),
        repository = read_field(record, "repo"),
        extraFields = {
            repo = read_field(record, "repo"),
            selector = read_field(record, "selectorPath") or read_field(record, "selector"),
            skillName = read_field(record, "skillName") or read_field(record, "skill_name"),
            installedPath = read_field(record, "installedPath") or read_field(record, "installed_path"),
            requestedVersion = read_field(record, "requestedVersion"),
        },
    }
    return item
end

local function build_search_skill_item(entry)
    local repo = trim(read_field(entry, "repo") or "")
    local skill_name = trim(read_field(entry, "skillName") or "")
    local namespace = trim(read_field(entry, "namespace") or "")
    local path = trim(read_field(entry, "path") or "")
    local selector = skill_name
    if path ~= "" and starts_with(path, "skills/") then
        selector = path:gsub("^skills/", ""):gsub("/SKILL%.md$", "")
    elseif namespace ~= "" then
        selector = namespace .. "/" .. skill_name
    end
    return {
        name = repo .. "/" .. skill_name,
        packageId = repo .. "/" .. selector,
        packageType = "skill",
        version = nil,
        latestVersion = nil,
        installed = false,
        status = "available",
        summary = first_nonempty(read_field(entry, "description"), "GitHub skill"),
        description = first_nonempty(read_field(entry, "description"), "GitHub skill"),
        homepage = "https://github.com/" .. repo,
        sourceUrl = "https://github.com/" .. repo,
        repository = repo,
        extraFields = {
            selector = selector,
            skillName = skill_name,
            namespace = namespace,
            path = path,
            stars = read_field(entry, "stars"),
        },
    }
end

local function build_codeql_item(state, latest_version)
    local installed_versions = type(read_field(state, "installedVersions")) == "table" and read_field(state, "installedVersions") or {}
    local current_version = first_nonempty(read_field(state, "currentVersion"), installed_versions[1])
    return {
        name = CODEQL_PACKAGE_NAME,
        packageId = CODEQL_PACKAGE_NAME,
        packageType = "codeql",
        version = current_version,
        latestVersion = first_nonempty(latest_version, current_version),
        installed = #installed_versions > 0,
        status = #installed_versions > 0 and "installed" or "available",
        summary = "CodeQL CLI managed through gh-codeql",
        description = "CodeQL CLI managed through GitHub CLI gh-codeql extension",
        homepage = "https://github.com/github/gh-codeql",
        sourceUrl = "https://github.com/github/gh-codeql",
        repository = CODEQL_EXTENSION_REPO,
        extraFields = {
            channel = read_field(state, "channel") or "release",
            installedVersions = installed_versions,
            ghCodeqlInstalled = read_field(state, "ghCodeqlInstalled") == true,
        },
    }
end

local function extension_records_from_list_output(output)
    local items = {}
    for _, line in ipairs(split_lines(output)) do
        local text = trim(line)
        if text ~= "" then
            local command_name, repo, version = text:match("^(.-)%s+([%w_.-]+/[%w_.-]+)%s+([^%s]+)%s*$")
            if command_name ~= nil and repo ~= nil and lower(trim(command_name)) ~= "name" then
                items[#items + 1] = {
                    command = trim(command_name),
                    repo = trim(repo),
                    version = trim(version),
                }
            else
                command_name, repo = text:match("^(.-)%s+([%w_.-]+/[%w_.-]+)%s*$")
                if command_name ~= nil and repo ~= nil and lower(trim(command_name)) ~= "name" then
                    items[#items + 1] = {
                        command = trim(command_name),
                        repo = trim(repo),
                        version = nil,
                    }
                end
            end
        end
    end
    return items
end

local function installed_extensions(context)
    local version = detect_gh_version(context)
    if version == nil then
        return {}
    end
    local result = run_command(context, gh_command("extension", "list"))
    if result == nil or not is_command_success(result) then
        return {}
    end
    return extension_records_from_list_output(result.stdout or "")
end

local function installed_extensions_map(context)
    local map = {}
    for _, item in ipairs(installed_extensions(context)) do
        map[item.repo] = item
    end
    return map
end

local function search_extensions(context, prompt)
    local result = run_command(context, gh_command("extension", "search", shell_quote(prompt), "--json", "fullName,description,url,stargazersCount", "--limit", "30"))
    if result == nil or not is_command_success(result) then
        return {}
    end
    local decoded = select(1, decode_json(result.stdout or "[]"))
    if type(decoded) ~= "table" then
        return {}
    end
    return decoded
end

local function load_skills_manifest()
    local payload = load_json_file(skills_manifest_path(), { skills = {} })
    if type(payload.skills) ~= "table" then
        payload.skills = {}
    end
    return payload
end

local function save_skills_manifest(context, payload)
    payload = type(payload) == "table" and payload or { skills = {} }
    if type(payload.skills) ~= "table" then
        payload.skills = {}
    end
    return save_json_file(context, skills_manifest_path(), payload)
end

local function find_skill_record(payload, package_id)
    for index, record in ipairs(payload.skills or {}) do
        if trim(read_field(record, "packageId") or "") == package_id then
            return record, index
        end
    end
    return nil, nil
end

local function load_codeql_state()
    local payload = load_json_file(codeql_state_path(), { channel = "release", installedVersions = {}, currentVersion = nil, ghCodeqlInstalled = false })
    if type(payload.installedVersions) ~= "table" then
        payload.installedVersions = {}
    end
    if trim(read_field(payload, "channel") or "") == "" then
        payload.channel = "release"
    end
    return payload
end

local function save_codeql_state(context, payload)
    payload = type(payload) == "table" and payload or {}
    if type(payload.installedVersions) ~= "table" then
        payload.installedVersions = {}
    end
    if trim(read_field(payload, "channel") or "") == "" then
        payload.channel = "release"
    end
    return save_json_file(context, codeql_state_path(), payload)
end

local function read_skill_frontmatter(record)
    local installed_path = read_field(record, "installedPath")
    if trim(installed_path or "") == "" then
        return nil, nil
    end
    local content = read_text_file(join_path(installed_path, "SKILL.md"))
    if content == nil then
        return nil, nil
    end
    return parse_frontmatter(content), join_path(installed_path, "SKILL.md")
end

local function apply_frontmatter(item, parsed, skill_path)
    if item == nil or type(parsed) ~= "table" then
        return item
    end
    item.summary = first_nonempty(read_field(parsed, "description"), read_field(parsed, "name"), item.summary)
    item.description = first_nonempty(read_field(parsed, "description"), item.description)
    item.homepage = first_nonempty(read_field(parsed, "homepage"), item.homepage)
    item.sourceUrl = first_nonempty(read_field(parsed, "homepage"), item.sourceUrl)
    item.extraFields = type(item.extraFields) == "table" and item.extraFields or {}
    local metadata = type(read_field(parsed, "metadata")) == "table" and read_field(parsed, "metadata") or {}
    item.extraFields.frontmatterName = read_field(parsed, "name")
    item.extraFields.frontmatterDescription = read_field(parsed, "description")
    item.extraFields.githubRepo = read_field(metadata, "github-repo")
    item.extraFields.githubRef = read_field(metadata, "github-ref")
    item.extraFields.githubTreeSha = read_field(metadata, "github-tree-sha")
    item.extraFields.githubPath = read_field(metadata, "github-path")
    item.extraFields.githubPinned = read_field(metadata, "github-pinned")
    item.extraFields.skillMarkdownPath = skill_path
    item.version = first_nonempty(read_field(metadata, "github-tree-sha"), read_field(metadata, "github-ref"), item.version)
    item.latestVersion = item.version
    return item
end

local function ensure_codeql_extension(context)
    local extensions = installed_extensions_map(context)
    if extensions[CODEQL_EXTENSION_REPO] ~= nil then
        return true, nil
    end
    local result = run_command(context, gh_command("extension", "install", CODEQL_EXTENSION_REPO))
    if result == nil or not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to install gh-codeql extension")
    end
    return true, nil
end

local function codeql_versions_from_output(output)
    local versions = {}
    for _, line in ipairs(split_lines(output)) do
        local text = trim(line)
        if text ~= "" then
            versions[#versions + 1] = text
        end
    end
    return versions
end

local function refresh_codeql_state(context, state)
    state = type(state) == "table" and state or load_codeql_state()
    local installed_result = run_command(context, gh_command("codeql", "list-installed"))
    if installed_result ~= nil and is_command_success(installed_result) then
        state.installedVersions = codeql_versions_from_output(installed_result.stdout or "")
        state.ghCodeqlInstalled = true
    end
    local status_result = run_command(context, gh_command("codeql"))
    if status_result ~= nil and is_command_success(status_result) then
        local status_output = status_result.stdout or ""
        local channel = trim(status_output:match("Current channel:%s*([^.\n]+)"))
        local version = trim(status_output:match("Current version:%s*([^.\n]+)"))
        if channel ~= "" then
            state.channel = channel
        end
        if version ~= "" and lower(version) ~= "not specified" then
            state.currentVersion = version
        end
    end
    return state
end

local function codeql_latest_version(context)
    local result = run_command(context, gh_command("codeql", "list-versions"))
    if result == nil or not is_command_success(result) then
        return nil
    end
    local versions = codeql_versions_from_output(result.stdout or "")
    return versions[1]
end

local function install_app(context)
    local version, err = ensure_gh_available(context)
    if version == nil then
        return nil, err
    end
    return build_app_item(version), nil
end

local function install_extension(context, package)
    local spec, err = parse_extension_package(package)
    if spec == nil then
        return nil, err
    end
    local version = detect_gh_version(context)
    if version == nil then
        return nil, "gh binary not available"
    end
    local result = run_command(context, gh_command("extension", "install", spec.repo))
    if result == nil or not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "gh extension install failed")
    end
    local installed = installed_extensions_map(context)[spec.repo]
    return build_extension_item(spec, installed, nil), nil
end

local function remove_extension(context, package)
    local spec, err = parse_extension_package(package)
    if spec == nil then
        return nil, err
    end
    local result = run_command(context, gh_command("extension", "remove", spec.commandName))
    if result == nil or not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "gh extension remove failed")
    end
    return build_extension_item(spec, nil, nil), nil
end

local function update_extension(context, package)
    local spec, err = parse_extension_package(package)
    if spec == nil then
        return nil, err
    end
    local installed = installed_extensions_map(context)[spec.repo]
    if installed ~= nil then
        local remove_result = run_command(context, gh_command("extension", "remove", spec.commandName))
        if remove_result == nil or not is_command_success(remove_result) then
            return nil, first_nonempty(remove_result and remove_result.stderr, remove_result and remove_result.stdout, "gh extension remove failed")
        end
    end
    local install_result = run_command(context, gh_command("extension", "install", spec.repo))
    if install_result == nil or not is_command_success(install_result) then
        return nil, first_nonempty(install_result and install_result.stderr, install_result and install_result.stdout, "gh extension install failed")
    end
    return build_extension_item(spec, installed_extensions_map(context)[spec.repo], nil), nil
end

local function install_skill(context, package, is_update)
    local spec, err = parse_skill_package(package)
    if spec == nil then
        return nil, err
    end
    local args = { "skill", "install", shell_quote(spec.repo), shell_quote(spec.selector), "--dir", managed_skill_dir() }
    if is_update or has_flag(package, "force") then
        args[#args + 1] = "--force"
    end
    if has_flag(package, "upstream") then
        args[#args + 1] = "--upstream"
    end
    local result = run_command(context, gh_command(table.unpack(args)))
    if result == nil or not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "gh skill install failed")
    end
    local manifest = load_skills_manifest()
    local record = {
        packageId = spec.packageId,
        repo = spec.repo,
        selector = spec.selector,
        selectorPath = spec.selectorPath,
        skillName = spec.skillName,
        requestedVersion = spec.requestedVersion,
        installedPath = join_path(managed_skill_dir(), spec.skillName),
    }
    local _, existing_index = find_skill_record(manifest, spec.packageId)
    if existing_index ~= nil then
        manifest.skills[existing_index] = record
    else
        manifest.skills[#manifest.skills + 1] = record
    end
    local ok, write_err = save_skills_manifest(context, manifest)
    if not ok then
        log_warn(context, write_err)
    end
    local item = build_skill_item(record)
    local parsed, skill_path = read_skill_frontmatter(record)
    return apply_frontmatter(item, parsed, skill_path), nil
end

local function remove_skill(context, package)
    local spec, err = parse_skill_package(package)
    if spec == nil then
        return nil, err
    end
    local manifest = load_skills_manifest()
    local record, index = find_skill_record(manifest, spec.packageId)
    if record == nil then
        return build_skill_item({ packageId = spec.packageId, repo = spec.repo, selectorPath = spec.selectorPath, skillName = spec.skillName }), nil
    end
    local ok, remove_err = remove_path_if_exists(context, read_field(record, "installedPath"))
    if not ok then
        return nil, remove_err
    end
    table.remove(manifest.skills, index)
    local saved, save_err = save_skills_manifest(context, manifest)
    if not saved then
        log_warn(context, save_err)
    end
    return build_skill_item(record), nil
end

local function update_skill(context, package)
    return install_skill(context, package, true)
end

local function install_codeql(context, package, is_update)
    local spec = parse_codeql_package(package)
    local version = detect_gh_version(context)
    if version == nil then
        return nil, "gh binary not available"
    end
    local ok, err = ensure_codeql_extension(context)
    if not ok then
        return nil, err
    end
    local state = load_codeql_state()
    if trim(spec.channel or "") ~= "" and trim(spec.channel or "") ~= trim(state.channel or "release") then
        local channel_result = run_command(context, gh_command("codeql", "set-channel", spec.channel))
        if channel_result == nil or not is_command_success(channel_result) then
            return nil, first_nonempty(channel_result and channel_result.stderr, channel_result and channel_result.stdout, "gh codeql set-channel failed")
        end
        state.channel = spec.channel
    end
    local download_result
    if trim(spec.version or "") ~= "" then
        download_result = run_command(context, gh_command("codeql", "download", spec.version))
    else
        download_result = run_command(context, gh_command("codeql", "download"))
    end
    if download_result == nil or not is_command_success(download_result) then
        return nil, first_nonempty(download_result and download_result.stderr, download_result and download_result.stdout, "gh codeql download failed")
    end
    local set_version_result
    if trim(spec.version or "") ~= "" then
        set_version_result = run_command(context, gh_command("codeql", "set-version", spec.version))
    elseif is_update then
        set_version_result = run_command(context, gh_command("codeql", "set-version", "latest"))
    else
        set_version_result = run_command(context, gh_command("codeql", "set-version", "latest"))
    end
    if set_version_result == nil or not is_command_success(set_version_result) then
        return nil, first_nonempty(set_version_result and set_version_result.stderr, set_version_result and set_version_result.stdout, "gh codeql set-version failed")
    end
    state.ghCodeqlInstalled = true
    state = refresh_codeql_state(context, state)
    if trim(spec.version or "") ~= "" and trim(state.currentVersion or "") == "" then
        state.currentVersion = spec.version
    end
    if trim(state.currentVersion or "") ~= "" then
        local found = false
        for _, item in ipairs(state.installedVersions or {}) do
            if trim(item) == trim(state.currentVersion) then
                found = true
                break
            end
        end
        if not found then
            state.installedVersions[#state.installedVersions + 1] = state.currentVersion
        end
    end
    local saved, save_err = save_codeql_state(context, state)
    if not saved then
        log_warn(context, save_err)
    end
    return build_codeql_item(state, codeql_latest_version(context)), nil
end

local function remove_codeql(context, package)
    local spec = parse_codeql_package(package)
    local state = load_codeql_state()
    if trim(spec.version or "") ~= "" then
        local result = run_command(context, gh_command("codeql", "cleanup", spec.version))
        if result == nil or not is_command_success(result) then
            return nil, first_nonempty(result and result.stderr, result and result.stdout, "gh codeql cleanup failed")
        end
        local filtered = {}
        for _, item in ipairs(state.installedVersions or {}) do
            if trim(item) ~= trim(spec.version) then
                filtered[#filtered + 1] = item
            end
        end
        state.installedVersions = filtered
        if trim(state.currentVersion or "") == trim(spec.version) then
            state.currentVersion = filtered[1]
        end
    else
        local result = run_command(context, gh_command("codeql", "cleanup-all"))
        if result == nil or not is_command_success(result) then
            return nil, first_nonempty(result and result.stderr, result and result.stdout, "gh codeql cleanup-all failed")
        end
        state.installedVersions = {}
        state.currentVersion = nil
    end
    local saved, save_err = save_codeql_state(context, state)
    if not saved then
        log_warn(context, save_err)
    end
    return build_codeql_item(state, nil), nil
end

local function update_codeql(context, package)
    return install_codeql(context, package, true)
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
    return { "GitHub", "Package Manager", "CLI" }
end

function plugin.getMissingPackages(packages)
    local missing = {}
    local gh_version = detect_gh_version(nil)
    local extension_map = installed_extensions_map(nil)
    local skill_manifest = load_skills_manifest()
    local codeql_state = load_codeql_state()
    for _, package in ipairs(packages or {}) do
        local spec = parse_requested_package(package)
        if spec ~= nil then
            if spec.kind == "app" then
                if gh_version == nil then
                    missing[#missing + 1] = package
                end
            elseif spec.kind == "extension" then
                if extension_map[spec.repo] == nil then
                    missing[#missing + 1] = package
                end
            elseif spec.kind == "skill" then
                if find_skill_record(skill_manifest, spec.packageId) == nil then
                    missing[#missing + 1] = package
                end
            elseif spec.kind == "codeql" then
                if trim(spec.version or "") == "" then
                    if #(codeql_state.installedVersions or {}) == 0 then
                        missing[#missing + 1] = package
                    end
                else
                    local found = false
                    for _, item in ipairs(codeql_state.installedVersions or {}) do
                        if trim(item) == trim(spec.version) then
                            found = true
                            break
                        end
                    end
                    if not found then
                        missing[#missing + 1] = package
                    end
                end
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
    local installed = {}
    for _, package in ipairs(requested) do
        local spec, err = parse_requested_package(package)
        if spec == nil then
            tx_failed(context, err)
            return false
        end
        local item
        if spec.kind == "app" then
            begin_step(context, "Installing gh launcher package")
            item, err = install_app(context)
        elseif spec.kind == "extension" then
            begin_step(context, "Installing gh extension")
            item, err = install_extension(context, package)
        elseif spec.kind == "skill" then
            begin_step(context, "Installing gh skill")
            item, err = install_skill(context, package, false)
        elseif spec.kind == "codeql" then
            begin_step(context, "Installing gh codeql")
            item, err = install_codeql(context, package, false)
        end
        if item == nil then
            tx_failed(context, err)
            return false
        end
        installed[#installed + 1] = item
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    tx_failed(context, "gh plugin does not support installLocal()")
    emit_event(context, "unavailable", { path = path, reason = "local-install-unsupported" })
    return false
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    local removed = {}
    for _, package in ipairs(requested) do
        local spec, err = parse_requested_package(package)
        if spec == nil then
            tx_failed(context, err)
            return false
        end
        local item
        if spec.kind == "app" then
            tx_failed(context, "app:gh removal is unsupported")
            return false
        elseif spec.kind == "extension" then
            begin_step(context, "Removing gh extension")
            item, err = remove_extension(context, package)
        elseif spec.kind == "skill" then
            begin_step(context, "Removing gh skill")
            item, err = remove_skill(context, package)
        elseif spec.kind == "codeql" then
            begin_step(context, "Removing gh codeql")
            item, err = remove_codeql(context, package)
        end
        if item == nil then
            tx_failed(context, err)
            return false
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
    local updated = {}
    for _, package in ipairs(requested) do
        local spec, err = parse_requested_package(package)
        if spec == nil then
            tx_failed(context, err)
            return false
        end
        local item
        if spec.kind == "app" then
            begin_step(context, "Updating gh launcher package")
            item, err = install_app(context)
        elseif spec.kind == "extension" then
            begin_step(context, "Updating gh extension")
            item, err = update_extension(context, package)
        elseif spec.kind == "skill" then
            begin_step(context, "Updating gh skill")
            item, err = update_skill(context, package)
        elseif spec.kind == "codeql" then
            begin_step(context, "Updating gh codeql")
            item, err = update_codeql(context, package)
        end
        if item == nil then
            tx_failed(context, err)
            return false
        end
        updated[#updated + 1] = item
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = {}
    local version = detect_gh_version(context)
    if version ~= nil then
        items[#items + 1] = build_app_item(version)
    end
    local installed_map = installed_extensions_map(context)
    for repo, record in pairs(installed_map) do
        local spec = {
            repo = repo,
            commandName = (repo:match("/([^/]+)$") or repo):gsub("^gh%-", ""),
        }
        items[#items + 1] = build_extension_item(spec, record, nil)
    end
    local manifest = load_skills_manifest()
    for _, record in ipairs(manifest.skills or {}) do
        local item = build_skill_item(record)
        local parsed, skill_path = read_skill_frontmatter(record)
        items[#items + 1] = apply_frontmatter(item, parsed, skill_path)
    end
    local codeql_state = load_codeql_state()
    if installed_map[CODEQL_EXTENSION_REPO] ~= nil or #(codeql_state.installedVersions or {}) > 0 then
        codeql_state = refresh_codeql_state(context, codeql_state)
        local saved, save_err = save_codeql_state(context, codeql_state)
        if not saved then
            log_warn(context, save_err)
        end
        items[#items + 1] = build_codeql_item(codeql_state, codeql_latest_version(context))
    end
    table.sort(items, function(left, right)
        return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "")
    end)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items = {}
    local manifest = load_skills_manifest()
    for _, record in ipairs(manifest.skills or {}) do
        local skill_name = trim(read_field(record, "skillName") or "")
        if skill_name ~= "" then
            local result = run_command(context, gh_command("skill", "update", shell_quote(skill_name), "--dry-run", "--dir", managed_skill_dir()))
            local output = lower(trim(first_nonempty(result and result.stdout, result and result.stderr, "") or ""))
            if result ~= nil and is_command_success(result) and output ~= "" and output:find("up to date", 1, true) == nil and output:find("pinned", 1, true) == nil then
                local item = build_skill_item(record)
                item.extraFields = merge_tables(item.extraFields, { updateCheckOutput = trim(first_nonempty(result.stdout, result.stderr, "")) })
                items[#items + 1] = item
            end
        end
    end
    local codeql_state = refresh_codeql_state(context, load_codeql_state())
    local latest = codeql_latest_version(context)
    local current = trim(codeql_state.currentVersion or "")
    if latest ~= nil and current ~= "" and latest ~= current then
        items[#items + 1] = build_codeql_item(codeql_state, latest)
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt)
    local results = {}
    if query == "" then
        emit_event(context, "searched", results)
        return results
    end
    for _, entry in ipairs(search_extensions(context, query)) do
        local repo = trim(read_field(entry, "fullName") or "")
        if repo ~= "" then
            local spec = {
                repo = repo,
                commandName = (repo:match("/([^/]+)$") or repo):gsub("^gh%-", ""),
            }
            results[#results + 1] = build_extension_item(spec, nil, entry)
        end
    end
    local skill_result = run_command(context, gh_command("skill", "search", shell_quote(query), "--json", "description,namespace,path,repo,skillName,stars", "--limit", "15"))
    if skill_result ~= nil and is_command_success(skill_result) then
        local decoded = select(1, decode_json(skill_result.stdout or "[]"))
        if type(decoded) == "table" then
            for _, entry in ipairs(decoded) do
                results[#results + 1] = build_search_skill_item(entry)
            end
        end
    end
    if lower(query):find("codeql", 1, true) ~= nil then
        results[#results + 1] = build_codeql_item(load_codeql_state(), nil)
    end
    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local requested = trim(name)
    if requested == "" then
        return {}
    end
    local kind = infer_package_kind(requested, nil)
    if kind == "app" then
        local item = build_app_item(detect_gh_version(context))
        emit_event(context, "informed", item)
        return item
    elseif kind == "codeql" then
        local state = refresh_codeql_state(context, load_codeql_state())
        local saved, save_err = save_codeql_state(context, state)
        if not saved then
            log_warn(context, save_err)
        end
        local item = build_codeql_item(state, codeql_latest_version(context))
        emit_event(context, "informed", item)
        return item
    elseif kind == "extension" then
        local spec = parse_extension_package({ name = requested })
        local installed = installed_extensions_map(context)[spec.repo]
        local search_results = search_extensions(context, requested)
        local matched = nil
        for _, entry in ipairs(search_results) do
            if trim(read_field(entry, "fullName") or "") == spec.repo then
                matched = entry
                break
            end
        end
        local item = build_extension_item(spec, installed, matched)
        emit_event(context, "informed", item)
        return item
    elseif kind == "skill" then
        local spec = parse_skill_package({ name = requested })
        local manifest = load_skills_manifest()
        local record = find_skill_record(manifest, spec.packageId)
        if record ~= nil then
            local item = build_skill_item(record)
            local parsed, skill_path = read_skill_frontmatter(record)
            item = apply_frontmatter(item, parsed, skill_path)
            emit_event(context, "informed", item)
            return item
        end
        local skill_result = run_command(context, gh_command("skill", "search", shell_quote(final_path_segment(requested)), "--json", "description,namespace,path,repo,skillName,stars", "--limit", "15"))
        if skill_result ~= nil and is_command_success(skill_result) then
            local decoded = select(1, decode_json(skill_result.stdout or "[]"))
            if type(decoded) == "table" then
                for _, entry in ipairs(decoded) do
                    local item = build_search_skill_item(entry)
                    if item.packageId == spec.packageId or item.name == requested then
                        emit_event(context, "informed", item)
                        return item
                    end
                end
            end
        end
        emit_event(context, "informed", {})
        return {}
    end
    emit_event(context, "informed", {})
    return {}
end

function plugin.resolvePackage(context, package)
    local spec, err = parse_requested_package(package)
    if spec == nil then
        return nil, err
    end
    if spec.kind == "app" then
        return build_app_item(detect_gh_version(context))
    elseif spec.kind == "codeql" then
        local item = build_codeql_item(load_codeql_state(), nil)
        if trim(spec.version or "") ~= "" then
            item.version = spec.version
            item.latestVersion = spec.version
        end
        item.extraFields = merge_tables(item.extraFields, { channel = spec.channel })
        return item
    end
    return plugin.info(context, spec.packageId)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "github-cli", "gh-extension", "gh-skill", "codeql" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".cache/reqpack/gh" },
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
