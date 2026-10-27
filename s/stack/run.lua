plugin = {}

local PLUGIN_ID = "stack"
local PLUGIN_NAME = "stack"
local PLUGIN_VERSION = "0.1.0"
local STACK_BINARY = "stack"
local CURL_BINARY = "curl"
local JSON_NULL = {}
local SEARCH_TTL = 120
local PACKAGE_TTL = 300
local DEFAULT_SEARCH_LIMIT = 10
local expand_runtime_placeholders

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
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

local function command_quote(value)
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,%[%]]+$") ~= nil then
        return text
    end
    return shell_quote(text)
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
    if text == "" then
        return
    end
    if seen[text] then
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
    return (result.exitCode or result.exit_code or result.code or result.status) == 0
end

local function command_exists(context, binary)
    return is_command_success(exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
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
    if os == nil or type(os.execute) ~= "function" then
        return false
    end
    local ok, kind, code = os.execute("mkdir -p " .. shell_quote(dir))
    return command_ok(ok, kind, code)
end

local function read_file(path)
    path = expand_runtime_placeholders(path)
    local handle = io.open(path, "r")
    if handle == nil then
        if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
            local result = normalize_run_result(reqpack.exec.run("cat " .. shell_quote(path)))
            if is_command_success(result) then
                return result.stdout or ""
            end
        end
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(path, content)
    path = expand_runtime_placeholders(path)
    local dir = parent_dir(path)
    if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
        return false
    end
    local handle = io.open(path, "w")
    if handle == nil then
        return false
    end
    handle:write(content)
    handle:close()
    return true
end

local function remove_file(path)
    if os ~= nil and type(os.remove) == "function" then
        os.remove(expand_runtime_placeholders(path))
    end
end

local function home_dir()
    if os ~= nil and type(os.getenv) == "function" then
        return first_nonempty(os.getenv("HOME"), os.getenv("USERPROFILE"), "/home/test", ".")
    end
    return "/home/test"
end

local function fixture_root()
    if os ~= nil and type(os.getenv) == "function" then
        return trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
    end
    return ""
end

function expand_runtime_placeholders(value)
    local text = tostring(value or "")
    local root = fixture_root()
    if root ~= "" then
        text = text:gsub("%$%{fixtureRoot%}", root)
    end
    return text
end

local function expand_fixture_path(path)
    local text = trim(expand_runtime_placeholders(path))
    if text == "" then
        return text
    end
    if text:match("^[/~]") ~= nil or text:match("^[A-Za-z]:[/\\]") ~= nil then
        return text
    end
    local root = fixture_root()
    if root ~= "" and (text == "." or text:sub(1, 2) == "./" or text:sub(1, 3) == "../") then
        if text == "." then
            return root
        end
        if text:sub(1, 2) == "./" then
            return join_path(root, text:sub(3))
        end
        return join_path(root, text)
    end
    return text
end

local function epoch_now()
    if os ~= nil and type(os.time) == "function" then
        return os.time()
    end
    return 0
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
        local start = index
        local current = peek()
        if current == "-" then
            index = index + 1
        end
        current = peek()
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
        return tonumber(text:sub(start, index - 1))
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
            return nil
        end
        decode_error("unexpected token")
    end

    local decoded = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("trailing characters")
    end
    return decoded
end

local function decode_json(raw)
    local ok, result = pcall(decode_json_internal, raw)
    if ok then
        return result, nil
    end
    return nil, tostring(result)
end

local function package_name(package)
    return trim(read_field(package, "name") or read_field(package, "packageName") or read_field(package, "packageId") or "")
end

local function package_version(package)
    return trim(read_field(package, "version") or "")
end

local function cache_root(context, packages)
    local raw_flags = collect_raw_flags(context, packages)
    local explicit = flag_value(raw_flags, "cache-root")
    if explicit ~= nil and explicit ~= "" then
        return expand_fixture_path(explicit)
    end
    return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
end

local function shared_paths(context, packages)
    local root = cache_root(context, packages)
    return {
        root = root,
        stack_root = join_path(root, "stack-root"),
        bin = join_path(root, "bin"),
        state_file = join_path(root, "state", "installed.tsv"),
        search_dir = join_path(root, "query", "search"),
        versions_dir = join_path(root, "query", "versions"),
        cabal_dir = join_path(root, "query", "cabal"),
    }
end

local function env_prefix(paths)
    return table.concat({
        "STACK_ROOT=" .. shell_quote(paths.stack_root),
        "NO_COLOR='1'",
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
    }, " ")
end

local function build_stack_command(context, packages, args, options)
    local paths = shared_paths(context, packages)
    local parts = { env_prefix(paths), STACK_BINARY, "--color", "never" }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = command_quote(arg)
    end
    local command = table.concat(parts, " ")
    local dir = trim(options and options.dir or "")
    if dir ~= "" then
        command = "cd " .. shell_quote(dir) .. " && " .. command
    end
    return command, paths
end

local function cache_key(value)
    local normalized = lower(trim(value))
    if normalized == "" then
        normalized = "unknown"
    end
    return (normalized:gsub("[^%w%.%-_]+", "_"))
end

local function read_timestamp(path)
    local raw = trim(read_file(path) or "")
    local value = tonumber(raw)
    if value == nil then
        return 0
    end
    return value
end

local function is_cache_fresh(ts_path, ttl)
    local timestamp = read_timestamp(ts_path)
    if timestamp <= 0 then
        return false
    end
    return (epoch_now() - timestamp) < ttl
end

local function persist_cache(body_path, ts_path, body)
    write_file(body_path, body)
    write_file(ts_path, tostring(epoch_now()))
end

local function fetch_url(context, url, accept)
    local args = { "-fsSL" }
    if trim(accept or "") ~= "" then
        args[#args + 1] = "-H"
        args[#args + 1] = "Accept: " .. accept
    end
    local parts = { CURL_BINARY }
    for _, arg in ipairs(args) do
        parts[#parts + 1] = command_quote(arg)
    end
    parts[#parts + 1] = shell_quote(url)
    local result = exec_run(context, table.concat(parts, " "))
    if not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "request failed")
    end
    return result.stdout or "", nil
end

local function cached_fetch(context, body_path, ts_path, url, ttl, accept)
    local cached = read_file(body_path)
    if cached ~= nil and is_cache_fresh(ts_path, ttl) then
        return cached, nil
    end
    local body, err = fetch_url(context, url, accept)
    if body ~= nil then
        persist_cache(body_path, ts_path, body)
        return body, nil
    end
    if cached ~= nil then
        return cached, nil
    end
    return nil, err
end

local function version_tokens(value)
    local tokens = {}
    local text = tostring(value or "")
    for token in text:gmatch("[A-Za-z0-9]+") do
        if token:match("^%d+$") then
            tokens[#tokens + 1] = { numeric = true, value = tonumber(token) }
        else
            tokens[#tokens + 1] = { numeric = false, value = lower(token) }
        end
    end
    return tokens
end

local function compare_versions(left, right)
    local a = version_tokens(left)
    local b = version_tokens(right)
    local max_len = math.max(#a, #b)
    for index = 1, max_len do
        local x = a[index]
        local y = b[index]
        if x == nil and y == nil then
            return 0
        elseif x == nil then
            if y.numeric and y.value == 0 then
            else
                return -1
            end
        elseif y == nil then
            if x.numeric and x.value == 0 then
            else
                return 1
            end
        elseif x.numeric and y.numeric then
            if x.value < y.value then
                return -1
            elseif x.value > y.value then
                return 1
            end
        elseif x.numeric ~= y.numeric then
            return x.numeric and 1 or -1
        else
            if x.value < y.value then
                return -1
            elseif x.value > y.value then
                return 1
            end
        end
    end
    return 0
end

local function sanitize_state_field(value)
    return trim(tostring(value or ""):gsub("[\r\n\t]", " "))
end

local function split_tabs(line)
    local fields = {}
    for field in (tostring(line or "") .. "\t"):gmatch("(.-)\t") do
        fields[#fields + 1] = field
    end
    return fields
end

local function parse_csv_list(value)
    local items = {}
    local seen = {}
    for item in tostring(value or ""):gmatch("([^,]+)") do
        append_unique(items, trim(item), seen)
    end
    return items
end

local function join_csv_list(items)
    local values = {}
    local seen = {}
    for _, item in ipairs(items or {}) do
        append_unique(values, item, seen)
    end
    table.sort(values)
    return table.concat(values, ",")
end

local function load_state(paths)
    local items = {}
    local raw = read_file(paths.state_file)
    if raw == nil then
        return items
    end
    for _, line in ipairs(split_lines(raw)) do
        local text = trim(line)
        if text ~= "" then
            local fields = split_tabs(text)
            items[#items + 1] = {
                name = trim(fields[1]),
                version = trim(fields[2]),
                sourceKind = trim(fields[3]),
                sourceRef = trim(fields[4]),
                binaries = parse_csv_list(fields[5]),
                summary = trim(fields[6]),
                license = trim(fields[7]),
                homepage = trim(fields[8]),
            }
        end
    end
    return items
end

local function save_state(paths, items)
    local lines = {}
    table.sort(items, function(left, right)
        return trim(left.name) < trim(right.name)
    end)
    for _, item in ipairs(items or {}) do
        lines[#lines + 1] = table.concat({
            sanitize_state_field(item.name),
            sanitize_state_field(item.version),
            sanitize_state_field(item.sourceKind),
            sanitize_state_field(item.sourceRef),
            sanitize_state_field(join_csv_list(item.binaries)),
            sanitize_state_field(item.summary),
            sanitize_state_field(item.license),
            sanitize_state_field(item.homepage),
        }, "\t")
    end
    return write_file(paths.state_file, (#lines > 0 and table.concat(lines, "\n") .. "\n") or "")
end

local function find_state_index(items, name)
    local wanted = lower(trim(name))
    for index, item in ipairs(items or {}) do
        if lower(trim(item.name)) == wanted then
            return index
        end
    end
    return nil
end

local function binary_owned_elsewhere(items, current_name, binary)
    local wanted_name = lower(trim(current_name))
    local wanted_binary = trim(binary)
    for _, item in ipairs(items or {}) do
        if lower(trim(item.name)) ~= wanted_name then
            for _, owned in ipairs(item.binaries or {}) do
                if trim(owned) == wanted_binary then
                    return true
                end
            end
        end
    end
    return false
end

local function cleanup_unowned_binaries(paths, items, current_name, binaries)
    for _, binary in ipairs(binaries or {}) do
        if not binary_owned_elsewhere(items, current_name, binary) then
            remove_file(join_path(paths.bin, binary))
        end
    end
end

local function ensure_command(context, binary)
    if not command_exists(context, binary) then
        return false, binary .. " binary not available"
    end
    return true, nil
end

local function package_versions_paths(paths, name)
    local base = join_path(paths.versions_dir, cache_key(name) .. ".json")
    return base, base .. ".ts"
end

local function package_cabal_paths(paths, name, version)
    local base = join_path(paths.cabal_dir, cache_key(name .. "-" .. version) .. ".cabal")
    return base, base .. ".ts"
end

local function search_paths(paths, prompt)
    local base = join_path(paths.search_dir, cache_key(prompt) .. ".json")
    return base, base .. ".ts"
end

local function latest_version_from_map(map, allow_deprecated)
    local latest = nil
    for version, status in pairs(map or {}) do
        local current_status = trim(status)
        if allow_deprecated or current_status ~= "deprecated" then
            if latest == nil or compare_versions(version, latest) > 0 then
                latest = version
            end
        end
    end
    if latest ~= nil then
        return latest
    end
    for version in pairs(map or {}) do
        if latest == nil or compare_versions(version, latest) > 0 then
            latest = version
        end
    end
    return latest
end

local function parse_dependency_names(value)
    local names = {}
    local seen = {}
    for token in tostring(value or ""):gmatch("([A-Za-z0-9][A-Za-z0-9%._%-]*)") do
        local lowered = lower(token)
        if lowered ~= "if" and lowered ~= "else" and lowered ~= "true" and lowered ~= "false" then
            append_unique(names, token, seen)
        end
    end
    table.sort(names)
    return names
end

local function parse_cabal_file(raw)
    local item = {
        binaries = {},
        dependencies = {},
    }
    local current_field = nil
    local current_section = nil
    local dependency_seen = {}
    local binary_seen = {}
    local function append_field(field, value)
        local text = trim(value)
        if text == "" then
            return
        end
        if field == "description" then
            if trim(item.description or "") == "" then
                item.description = text
            else
                item.description = trim(item.description) .. " " .. text
            end
        elseif field == "build-depends" then
            for _, name in ipairs(parse_dependency_names(text)) do
                append_unique(item.dependencies, name, dependency_seen)
            end
        elseif field == "location" and current_section == "source-repository head" then
            item.repository = text
        elseif field == "homepage" then
            item.homepage = text
        elseif field == "license" then
            item.license = text
        elseif field == "synopsis" then
            item.summary = text
        elseif field == "name" then
            item.name = text
        elseif field == "version" then
            item.version = text
        elseif field == "author" then
            item.author = text
        elseif field == "maintainer" then
            item.maintainer = text
        elseif field == "category" then
            item.category = text
        elseif field == "bug-reports" then
            item.bugReports = text
        end
    end
    for _, line in ipairs(split_lines(raw)) do
        local indent = line:match("^(%s*)") or ""
        local trimmed = trim(line)
        if trimmed == "" or trimmed:sub(1, 2) == "--" then
        elseif #indent == 0 then
            local executable_name = trimmed:match("^executable%s+(.+)$")
            if executable_name ~= nil then
                current_section = "executable"
                current_field = nil
                append_unique(item.binaries, executable_name, binary_seen)
            else
                local test_name = trimmed:match("^test%-suite%s+(.+)$")
                local bench_name = trimmed:match("^benchmark%s+(.+)$")
                local source_repo = trimmed:match("^source%-repository%s+(.+)$")
                if test_name ~= nil then
                    current_section = "test-suite"
                    current_field = nil
                elseif bench_name ~= nil then
                    current_section = "benchmark"
                    current_field = nil
                elseif source_repo ~= nil then
                    current_section = "source-repository " .. trim(source_repo)
                    current_field = nil
                else
                    local key, value = trimmed:match("^([%w%-]+):%s*(.*)$")
                    if key ~= nil then
                        current_field = lower(key)
                        append_field(current_field, value)
                    else
                        current_field = nil
                        current_section = trimmed
                    end
                end
            end
        else
            local key, value = trimmed:match("^([%w%-]+):%s*(.*)$")
            if key ~= nil then
                current_field = lower(key)
                append_field(current_field, value)
            elseif current_field ~= nil then
                append_field(current_field, trimmed)
            end
        end
    end
    item.summary = trim(item.summary or "")
    item.description = trim(item.description or item.summary or "")
    table.sort(item.binaries)
    table.sort(item.dependencies)
    return item
end

local function fetch_versions_map(context, paths, name)
    local body_path, ts_path = package_versions_paths(paths, name)
    local raw, err = cached_fetch(context, body_path, ts_path, "https://hackage.haskell.org/package/" .. name, PACKAGE_TTL, "application/json")
    if raw == nil then
        return nil, err
    end
    local payload, decode_err = decode_json(raw)
    if payload == nil then
        return nil, decode_err
    end
    return payload, nil
end

local function fetch_cabal_text(context, paths, name, version)
    local body_path, ts_path = package_cabal_paths(paths, name, version)
    return cached_fetch(context, body_path, ts_path, "https://hackage.haskell.org/package/" .. name .. "-" .. version .. "/" .. name .. ".cabal", PACKAGE_TTL, nil)
end

local function fetch_package_info(context, packages, name, requested_version)
    local package_name_value = trim(name)
    if package_name_value == "" then
        return nil, "stack package name missing"
    end
    local paths = shared_paths(context, packages)
    local versions_map, version_err = fetch_versions_map(context, paths, package_name_value)
    if versions_map == nil then
        return nil, version_err
    end
    local resolved_version = trim(requested_version or "")
    if resolved_version == "" or lower(resolved_version) == "latest" then
        resolved_version = latest_version_from_map(versions_map, false)
    end
    if resolved_version == nil or resolved_version == "" then
        return nil, "failed to resolve Hackage version for " .. package_name_value
    end
    if versions_map[resolved_version] == nil and versions_map[tostring(resolved_version)] == nil then
        return nil, "requested Hackage version not found: " .. resolved_version
    end
    local cabal_text, cabal_err = fetch_cabal_text(context, paths, package_name_value, resolved_version)
    if cabal_text == nil then
        return nil, cabal_err
    end
    local parsed = parse_cabal_file(cabal_text)
    local latest_version = latest_version_from_map(versions_map, true) or resolved_version
    return {
        name = trim(parsed.name or package_name_value),
        packageId = trim(parsed.name or package_name_value),
        version = resolved_version,
        latestVersion = latest_version,
        summary = trim(parsed.summary),
        description = trim(parsed.description),
        license = trim(parsed.license),
        homepage = trim(parsed.homepage),
        repository = trim(parsed.repository),
        author = trim(parsed.author),
        maintainer = trim(parsed.maintainer),
        category = trim(parsed.category),
        dependencies = parsed.dependencies,
        binaries = parsed.binaries,
        sourceUrl = "https://hackage.haskell.org/package/" .. package_name_value .. "-" .. resolved_version,
        packageType = "hackage",
        installed = false,
        status = "available",
        extraFields = {
            bugReports = trim(parsed.bugReports),
            hackageStatus = trim(versions_map[resolved_version] or "normal"),
        },
    }, nil
end

local function search_limit(context)
    local limit = tonumber(flag_value(collect_raw_flags(context, {}), "limit") or "")
    if limit == nil or limit < 1 then
        return DEFAULT_SEARCH_LIMIT
    end
    if limit > 25 then
        return 25
    end
    return math.floor(limit)
end

local function fetch_search_names(context, prompt)
    local query = trim(prompt)
    if query == "" then
        return {}, nil
    end
    local paths = shared_paths(context, {})
    local body_path, ts_path = search_paths(paths, query)
    local raw, fetch_err = cached_fetch(context, body_path, ts_path, "https://hackage.haskell.org/packages/search?terms=" .. query, SEARCH_TTL, "application/json")
    if raw == nil then
        return nil, fetch_err
    end
    local payload, decode_err = decode_json(raw)
    if payload == nil then
        return nil, decode_err
    end
    return payload, nil
end

local function list_entry_from_state(item)
    return {
        name = item.name,
        packageId = item.name,
        version = item.version,
        latestVersion = item.version,
        summary = item.summary,
        license = item.license,
        homepage = item.homepage,
        binaries = item.binaries,
        installed = true,
        status = "installed",
        packageType = "hackage",
        extraFields = {
            sourceKind = item.sourceKind,
            sourceRef = item.sourceRef,
            managedBinDir = shared_paths(nil, {}).bin,
        },
    }
end

local function normalize_local_install_target(path)
    local raw = expand_fixture_path(path)
    if raw == "" then
        return nil, nil, "missing local path"
    end
    if raw:sub(-6) == ".cabal" then
        return parent_dir(raw) or ".", raw, nil
    end
    return raw, nil, nil
end

local function find_local_cabal_path(context, dir)
    local listing = exec_run(context, "ls -1A " .. shell_quote(dir))
    if not is_command_success(listing) then
        return nil, "failed to inspect local Stack project"
    end
    local cabal_files = {}
    for _, line in ipairs(split_lines(listing.stdout)) do
        local entry = trim(line)
        if entry:sub(-6) == ".cabal" then
            cabal_files[#cabal_files + 1] = join_path(dir, entry)
        end
    end
    table.sort(cabal_files)
    if #cabal_files == 0 then
        return nil, "no .cabal file found in " .. dir
    end
    return cabal_files[1], nil
end

local function local_project_info(context, path)
    local project_dir, cabal_path, err = normalize_local_install_target(path)
    if err ~= nil then
        return nil, err
    end
    if cabal_path == nil then
        cabal_path, err = find_local_cabal_path(context, project_dir)
        if cabal_path == nil then
            return nil, err
        end
    end
    local raw = read_file(cabal_path)
    if raw == nil then
        return nil, "failed to read local .cabal file"
    end
    local parsed = parse_cabal_file(raw)
    local stack_yaml = join_path(project_dir, "stack.yaml")
    if read_file(stack_yaml) == nil then
        return nil, "stack.yaml not found in " .. project_dir
    end
    local name = trim(parsed.name or "")
    if name == "" then
        return nil, "local package name missing in .cabal file"
    end
    return {
        projectDir = project_dir,
        cabalPath = cabal_path,
        name = name,
        version = trim(parsed.version or "0.0.0"),
        summary = trim(parsed.summary),
        description = trim(parsed.description),
        license = trim(parsed.license),
        homepage = trim(parsed.homepage),
        repository = trim(parsed.repository),
        binaries = parsed.binaries,
        dependencies = parsed.dependencies,
    }, nil
end

local function ensure_state_parent(paths)
    return ensure_directory(parent_dir(paths.state_file) or paths.root)
end

local function make_state_entry(source_kind, source_ref, info)
    return {
        name = trim(info.name),
        version = trim(info.version),
        sourceKind = trim(source_kind),
        sourceRef = trim(source_ref),
        binaries = info.binaries or {},
        summary = trim(info.summary),
        license = trim(info.license),
        homepage = trim(info.homepage),
    }
end

local function install_remote_package(context, paths, state_items, package)
    local name = package_name(package)
    if name == "" then
        return false, "stack package name missing"
    end
    local info, info_err = fetch_package_info(context, { package }, name, package_version(package))
    if info == nil then
        return false, info_err
    end
    local command = build_stack_command(context, { package }, { "--local-bin-path", paths.bin, "install", info.name .. "-" .. info.version })
    local result = exec_run(context, command)
    if not is_command_success(result) then
        return false, first_nonempty(result and result.stderr, result and result.stdout, "stack install failed")
    end
    local index = find_state_index(state_items, info.name)
    local previous = index ~= nil and state_items[index] or nil
    local new_entry = make_state_entry("remote", info.name, info)
    if index ~= nil then
        state_items[index] = new_entry
    else
        state_items[#state_items + 1] = new_entry
    end
    if previous ~= nil then
        local stale = {}
        local current = {}
        for _, binary in ipairs(new_entry.binaries or {}) do
            current[trim(binary)] = true
        end
        for _, binary in ipairs(previous.binaries or {}) do
            if not current[trim(binary)] then
                stale[#stale + 1] = binary
            end
        end
        cleanup_unowned_binaries(paths, state_items, previous.name, stale)
    end
    return true, info
end

local function install_local_package(context, paths, state_items, path)
    local info, info_err = local_project_info(context, path)
    if info == nil then
        return false, info_err
    end
    local command = build_stack_command(context, {}, { "--local-bin-path", paths.bin, "install" }, { dir = info.projectDir })
    local result = exec_run(context, command)
    if not is_command_success(result) then
        return false, first_nonempty(result and result.stderr, result and result.stdout, "stack local install failed")
    end
    local index = find_state_index(state_items, info.name)
    local previous = index ~= nil and state_items[index] or nil
    local new_entry = make_state_entry("local", info.projectDir, info)
    if index ~= nil then
        state_items[index] = new_entry
    else
        state_items[#state_items + 1] = new_entry
    end
    if previous ~= nil then
        local stale = {}
        local current = {}
        for _, binary in ipairs(new_entry.binaries or {}) do
            current[trim(binary)] = true
        end
        for _, binary in ipairs(previous.binaries or {}) do
            if not current[trim(binary)] then
                stale[#stale + 1] = binary
            end
        end
        cleanup_unowned_binaries(paths, state_items, previous.name, stale)
    end
    return true, info
end

local function remove_state_packages(paths, state_items, packages)
    local removed = {}
    local wanted = {}
    for _, package in ipairs(packages or {}) do
        local name = lower(package_name(package))
        if name ~= "" then
            wanted[name] = true
        end
    end
    local kept = {}
    for _, item in ipairs(state_items or {}) do
        if wanted[lower(trim(item.name))] then
            removed[#removed + 1] = item
        else
            kept[#kept + 1] = item
        end
    end
    for _, item in ipairs(removed) do
        cleanup_unowned_binaries(paths, kept, item.name, item.binaries)
    end
    return kept, removed
end

local function update_targets_from_state(state_items, packages)
    if packages == nil or #packages == 0 then
        local all = {}
        for _, item in ipairs(state_items or {}) do
            all[#all + 1] = { state = item, request = nil }
        end
        return all
    end
    local wanted = {}
    for _, package in ipairs(packages) do
        local name = lower(package_name(package))
        if name ~= "" then
            wanted[name] = package
        end
    end
    local selected = {}
    for _, item in ipairs(state_items or {}) do
        if wanted[lower(trim(item.name))] ~= nil then
            selected[#selected + 1] = { state = item, request = wanted[lower(trim(item.name))] }
        end
    end
    return selected
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
    return { "haskell", "package-manager" }
end

function plugin.getMissingPackages()
    local missing = {}
    if not command_exists(nil, STACK_BINARY) then
        missing[#missing + 1] = STACK_BINARY
    end
    if not command_exists(nil, CURL_BINARY) then
        missing[#missing + 1] = CURL_BINARY
    end
    return missing
end

function plugin.install(context, packages)
    local local_path = trim(read_field(context, "localPath") or read_field(read_field(context, "request"), "localPath") or "")
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    begin_step(context, "install Stack packages")
    local ok, err = ensure_command(context, STACK_BINARY)
    if not ok then
        tx_failed(context, err)
        return false
    end
    ok, err = ensure_command(context, CURL_BINARY)
    if not ok then
        tx_failed(context, err)
        return false
    end
    local paths = shared_paths(context, requested)
    ensure_directory(paths.bin)
    ensure_directory(paths.stack_root)
    ensure_state_parent(paths)
    local state_items = load_state(paths)
    local installed = {}
    for _, package in ipairs(requested) do
        local success, result = install_remote_package(context, paths, state_items, package)
        if not success then
            tx_failed(context, result)
            return false
        end
        installed[#installed + 1] = result
    end
    save_state(paths, state_items)
    emit_event(context, "installed", installed)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.installLocal(context, path)
    local target = trim(expand_runtime_placeholders(path))
    if target == "" then
        tx_failed(context, "missing local path")
        return false
    end
    begin_step(context, "install local Stack project")
    local ok, err = ensure_command(context, STACK_BINARY)
    if not ok then
        tx_failed(context, err)
        return false
    end
    local paths = shared_paths(context, {})
    ensure_directory(paths.bin)
    ensure_directory(paths.stack_root)
    ensure_state_parent(paths)
    local state_items = load_state(paths)
    local success, result = install_local_package(context, paths, state_items, target)
    if not success then
        tx_failed(context, result)
        return false
    end
    save_state(paths, state_items)
    emit_event(context, "installed", { result })
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    begin_step(context, "remove Stack packages")
    local paths = shared_paths(context, requested)
    local state_items = load_state(paths)
    local kept, removed = remove_state_packages(paths, state_items, requested)
    save_state(paths, kept)
    emit_event(context, "deleted", removed)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.update(context, packages)
    local paths = shared_paths(context, packages)
    local state_items = load_state(paths)
    local selected = update_targets_from_state(state_items, packages)
    if #selected == 0 then
        return true
    end
    begin_step(context, "update Stack packages")
    local ok, err = ensure_command(context, STACK_BINARY)
    if not ok then
        tx_failed(context, err)
        return false
    end
    ok, err = ensure_command(context, CURL_BINARY)
    if not ok then
        tx_failed(context, err)
        return false
    end
    local updated = {}
    for _, target in ipairs(selected) do
        if target.state.sourceKind == "local" then
            local success, result = install_local_package(context, paths, state_items, target.state.sourceRef)
            if not success then
                tx_failed(context, result)
                return false
            end
            updated[#updated + 1] = result
        else
            local request = target.request or { name = target.state.name }
            if trim(package_name(request)) == "" then
                request.name = target.state.name
            end
            local success, result = install_remote_package(context, paths, state_items, request)
            if not success then
                tx_failed(context, result)
                return false
            end
            updated[#updated + 1] = result
        end
    end
    save_state(paths, state_items)
    emit_event(context, "updated", updated)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.list(context)
    local paths = shared_paths(context, {})
    local state_items = load_state(paths)
    local items = {}
    for _, item in ipairs(state_items) do
        items[#items + 1] = list_entry_from_state(item)
    end
    table.sort(items, function(left, right)
        return trim(left.name) < trim(right.name)
    end)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local paths = shared_paths(context, {})
    local state_items = load_state(paths)
    local items = {}
    if #state_items == 0 then
        emit_event(context, "outdated", items)
        return items
    end
    local ok, err = ensure_command(context, CURL_BINARY)
    if not ok then
        log_warn(context, err)
        emit_event(context, "outdated", items)
        return items
    end
    for _, state_item in ipairs(state_items) do
        if state_item.sourceKind == "remote" then
            local info = fetch_package_info(context, {}, state_item.name, nil)
            if info ~= nil and compare_versions(state_item.version, info.latestVersion or info.version) < 0 then
                items[#items + 1] = {
                    name = state_item.name,
                    packageId = state_item.name,
                    version = state_item.version,
                    latestVersion = info.latestVersion or info.version,
                    installed = true,
                    status = "outdated",
                    packageType = "hackage",
                    summary = state_item.summary,
                    binaries = state_item.binaries,
                }
            end
        end
    end
    table.sort(items, function(left, right)
        return trim(left.name) < trim(right.name)
    end)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end
    local ok, err = ensure_command(context, CURL_BINARY)
    if not ok then
        log_warn(context, err)
        emit_event(context, "searched", {})
        return {}
    end
    local payload, search_err = fetch_search_names(context, query)
    if payload == nil then
        log_warn(context, search_err)
        emit_event(context, "searched", {})
        return {}
    end
    local limit = search_limit(context)
    local items = {}
    for index, entry in ipairs(payload or {}) do
        if index > limit then
            break
        end
        local name = trim(read_field(entry, "name"))
        if name ~= "" then
            local info = fetch_package_info(context, {}, name, nil)
            if info ~= nil then
                items[#items + 1] = {
                    name = info.name,
                    packageId = info.packageId,
                    version = info.version,
                    latestVersion = info.latestVersion,
                    summary = info.summary,
                    description = info.summary,
                    homepage = info.homepage,
                    license = info.license,
                    packageType = "hackage",
                    installed = false,
                    status = "available",
                }
            else
                items[#items + 1] = {
                    name = name,
                    packageId = name,
                    installed = false,
                    status = "available",
                    packageType = "hackage",
                }
            end
        end
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = trim(name or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
    if query == "" then
        emit_event(context, "informed", {})
        return {}
    end
    local version = trim(flag_value(collect_raw_flags(context, {}), "version") or "")
    local info, err = fetch_package_info(context, {}, query, version)
    if info == nil then
        log_warn(context, err)
        emit_event(context, "informed", {})
        return {}
    end
    local item = {
        name = info.name,
        packageId = info.packageId,
        version = info.version,
        latestVersion = info.latestVersion,
        summary = info.summary,
        description = info.description,
        license = info.license,
        homepage = info.homepage,
        repository = info.repository,
        author = info.author,
        maintainer = info.maintainer,
        dependencies = info.dependencies,
        binaries = info.binaries,
        installed = false,
        status = "available",
        packageType = "hackage",
        sourceUrl = info.sourceUrl,
        extraFields = info.extraFields,
    }
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == "" then
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
        ecosystemScopes = { "hackage", "haskell", "stack" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".cache/reqpack/stack" },
            { kind = "project-subpath", value = ".stack-work" },
        },
        networkScopes = {
            { host = "hackage.haskell.org", scheme = "https", pathPrefix = "/" },
        },
        privilegeLevel = "user",
        purlType = "hackage",
    }
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

return plugin
