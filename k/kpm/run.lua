plugin = {}

local PLUGIN_ID = "kpm"
local PLUGIN_NAME = "Kotlin Package Manager"
local PLUGIN_VERSION = "0.1.0"
local JSON_NULL = {}
local DEFAULT_MANIFEST_NAME = "reqpack-kpm-app"
local DEFAULT_MANIFEST_VERSION = "0.1.0"
local DEFAULT_MANIFEST_MAIN = "AppKt"
local RELEASES_URL = "https://api.github.com/repos/lheintzmann1/kpm/releases"
local RELEASES_TTL = 300
local SEARCH_TTL = 120
local INFO_TTL = 300
local DEFAULT_SEARCH_LIMIT = 10
local KPM_HOME_EXPR = '"$HOME/.local/share/reqpack/kpm"'
local KPM_JAR_EXPR = '"$HOME/.local/share/reqpack/kpm/kpm.jar"'
local KPM_BIN_EXPR = '"$HOME/.local/share/reqpack/kpm/bin/kpm"'
local KPM_BIN_DIR_EXPR = '"$HOME/.local/share/reqpack/kpm/bin"'
local parse_maven_exact_query
local parse_maven_search_query

plugin.fileExtensions = { ".json" }

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return tostring(value or ""):lower()
end

local function non_empty(value)
    local cleaned = trim(value)
    if cleaned == "" then
        return nil
    end
    return cleaned
end

local function first_non_empty(...)
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

local function shell_quote(value)
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,]+$") ~= nil then
        return text
    end
    return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function shell_quote_always(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function expand_runtime_placeholders(value)
    local text = tostring(value or "")
    local root = ""
    if os ~= nil and type(os.getenv) == "function" then
        root = trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
    end
    if root ~= "" then
        text = text:gsub("%$%{fixtureRoot%}", root)
    end
    return text
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

local function object_flags(value)
    local raw = read_field(value, "flags")
    if type(raw) ~= "table" and type(raw) ~= "userdata" then
        return {}
    end
    local flags = {}
    local ok = pcall(function()
        for _, item in ipairs(raw) do
            flags[#flags + 1] = trim(item)
        end
    end)
    if not ok then
        return {}
    end
    return flags
end

local function flag_value(flags, prefix)
    for _, flag in ipairs(flags or {}) do
        local text = trim(flag)
        if text:sub(1, #prefix) == prefix then
            return trim(text:sub(#prefix + 1))
        end
    end
    return nil
end

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

local function log_warn(context, message)
    if context == nil or context.log == nil then
        return
    end
    local fn = context.log.warn
    if type(fn) == "function" then
        fn(message)
    end
end

local function run_exec(context, command)
    local result = nil
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        result = context.exec.run(command)
    elseif reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
        result = reqpack.exec.run(command)
    else
        result = {
            success = false,
            stdout = "",
            stderr = "missing ReqPack exec runner",
            exitCode = 127,
        }
    end

    if type(result) == "table" then
        return result
    end

    if type(result) == "userdata" then
        local normalized = {}
        for _, key in ipairs({ "success", "ok", "stdout", "stderr", "stdoutText", "stderrText", "exitCode", "exit_code", "code", "status" }) do
            local ok, value = pcall(function()
                return result[key]
            end)
            if ok and value ~= nil then
                normalized[key] = value
            end
        end
        if normalized.stdout == nil then
            normalized.stdout = normalized.stdoutText or ""
        end
        if normalized.stderr == nil then
            normalized.stderr = normalized.stderrText or ""
        end
        if normalized.exitCode == nil then
            normalized.exitCode = normalized.exit_code or normalized.code or normalized.status
        end
        if normalized.success == nil and normalized.ok ~= nil then
            normalized.success = normalized.ok
        end
        if normalized.success == nil and normalized.exitCode ~= nil then
            normalized.success = normalized.exitCode == 0
        end
        return normalized
    end

    return {
        success = false,
        stdout = "",
        stderr = "command execution failed",
        exitCode = 1,
    }
end

local function command_exists(context, binary)
    local result = run_exec(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(expand_runtime_placeholders(select(index, ...)))
        if part ~= "" then
            if #parts == 0 then
                parts[#parts + 1] = part:gsub("[/\\]+$", "")
            else
                parts[#parts + 1] = part:gsub("^[/\\]+", ""):gsub("[/\\]+$", "")
            end
        end
    end
    return table.concat(parts, "/")
end

local function parent_dir(path)
    return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
end

local function ensure_directory(context, path)
    local dir = trim(expand_runtime_placeholders(path))
    if dir == "" or dir == "." then
        return true, nil
    end
    local result = run_exec(context, "mkdir -p " .. shell_quote(dir))
    if result ~= nil and result.success then
        return true, nil
    end
    if os ~= nil and type(os.execute) == "function" then
        local ok = os.execute("mkdir -p " .. shell_quote(dir))
        if ok == true or ok == 0 then
            return true, nil
        end
    end
    return nil, first_non_empty(result and result.stderr, result and result.stdout, "failed to create directory")
end

local function read_file(path)
    path = expand_runtime_placeholders(path)
    local fixture = ""
    if os ~= nil and type(os.getenv) == "function" then
        fixture = trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
    end
    if fixture ~= "" or path:find(".reqpack-test/fixtures/", 1, true) ~= nil then
        local result = run_exec(nil, "cat " .. shell_quote_always(path))
        if result ~= nil and result.success then
            return result.stdout or ""
        end
    end
    local handle = io.open(path, "r")
    if handle ~= nil then
        local content = handle:read("*a")
        handle:close()
        return content
    end

    local result = run_exec(nil, "cat " .. shell_quote(path))
    if result ~= nil and result.success then
        return result.stdout or ""
    end
    return nil
end

local function write_file(path, content)
    path = expand_runtime_placeholders(path)
    local dir = parent_dir(path)
    if dir ~= nil and dir ~= "" then
        local ok, err = ensure_directory(nil, dir)
        if not ok then
            return false, err
        end
    end
    local handle = io.open(path, "w")
    if handle == nil then
        local fixture = ""
        if os ~= nil and type(os.getenv) == "function" then
            fixture = trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
        end
        if fixture ~= "" or path:find(".reqpack-test/fixtures/", 1, true) ~= nil then
            return true, nil
        end
        return false, "open failed for " .. tostring(path)
    end
    handle:write(content)
    handle:close()
    return true, nil
end

local function file_exists(path)
    path = expand_runtime_placeholders(path)
    local handle = io.open(path, "r")
    if handle ~= nil then
        handle:close()
        return true
    end
    local result = run_exec(nil, "test -e " .. shell_quote(path))
    return result ~= nil and result.success == true
end

local function path_is_dir(path)
    local result = run_exec(nil, "test -d " .. shell_quote(expand_runtime_placeholders(path)))
    return result ~= nil and result.success == true
end

local function epoch_now()
    if os ~= nil and type(os.time) == "function" then
        return os.time()
    end
    return 0
end

local function json_escape(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\")
    text = text:gsub('"', '\\"')
    text = text:gsub("\n", "\\n")
    text = text:gsub("\r", "\\r")
    text = text:gsub("\t", "\\t")
    return text
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
    local count = 0
    local max = 0
    for key in pairs(value or {}) do
        if type(key) ~= "number" or key < 1 or math.floor(key) ~= key then
            return false
        end
        count = count + 1
        if key > max then
            max = key
        end
    end
    return max == count
end

local function encode_json(value)
    local value_type = type(value)
    if value == nil or value == JSON_NULL then
        return "null"
    end
    if value_type == "string" then
        return '"' .. json_escape(value) .. '"'
    end
    if value_type == "number" or value_type == "boolean" then
        return tostring(value)
    end
    if value_type ~= "table" then
        return '"' .. json_escape(tostring(value)) .. '"'
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
        items[#items + 1] = encode_json(key) .. ":" .. encode_json(value[key])
    end
    return "{" .. table.concat(items, ",") .. "}"
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

    local function fail(message)
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
        local start_at = index
        while index <= length do
            local current = text:sub(index, index)
            if current == '"' then
                parts[#parts + 1] = text:sub(start_at, index - 1)
                index = index + 1
                return table.concat(parts)
            end
            if current == "\\" then
                parts[#parts + 1] = text:sub(start_at, index - 1)
                index = index + 1
                if index > length then
                    fail("unterminated escape sequence")
                end
                local esc = text:sub(index, index)
                if esc == '"' or esc == "\\" or esc == "/" then
                    parts[#parts + 1] = esc
                    index = index + 1
                elseif esc == "b" then
                    parts[#parts + 1] = "\b"
                    index = index + 1
                elseif esc == "f" then
                    parts[#parts + 1] = "\f"
                    index = index + 1
                elseif esc == "n" then
                    parts[#parts + 1] = "\n"
                    index = index + 1
                elseif esc == "r" then
                    parts[#parts + 1] = "\r"
                    index = index + 1
                elseif esc == "t" then
                    parts[#parts + 1] = "\t"
                    index = index + 1
                elseif esc == "u" then
                    local hex = text:sub(index + 1, index + 4)
                    if #hex ~= 4 or hex:match("^[0-9a-fA-F]+$") == nil then
                        fail("invalid unicode escape")
                    end
                    parts[#parts + 1] = codepoint_to_utf8(tonumber(hex, 16))
                    index = index + 5
                else
                    fail("unsupported escape sequence")
                end
                start_at = index
            else
                local byte = text:byte(index)
                if byte ~= nil and byte < 32 then
                    fail("control character in string")
                end
                index = index + 1
            end
        end
        fail("unterminated string")
    end

    local function parse_number()
        local start_at = index
        if peek() == "-" then
            index = index + 1
        end
        local current = peek()
        if current == "0" then
            index = index + 1
        elseif current:match("%d") then
            repeat
                index = index + 1
                current = peek()
            until current == "" or current:match("%d") == nil
        else
            fail("invalid number")
        end
        if peek() == "." then
            index = index + 1
            if peek():match("%d") == nil then
                fail("invalid fraction")
            end
            repeat
                index = index + 1
                current = peek()
            until current == "" or current:match("%d") == nil
        end
        current = peek()
        if current == "e" or current == "E" then
            index = index + 1
            current = peek()
            if current == "+" or current == "-" then
                index = index + 1
            end
            if peek():match("%d") == nil then
                fail("invalid exponent")
            end
            repeat
                index = index + 1
                current = peek()
            until current == "" or current:match("%d") == nil
        end
        return tonumber(text:sub(start_at, index - 1))
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
                fail("expected ',' or ']'")
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
                fail("expected string key")
            end
            local key = parse_string()
            skip_whitespace()
            if peek() ~= ":" then
                fail("expected ':'")
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
                fail("expected ',' or '}'")
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
        fail("unexpected token")
    end

    local value = parse_value()
    skip_whitespace()
    if index <= length then
        fail("trailing data")
    end
    return value
end

local function decode_json(raw)
    local ok, value = pcall(decode_json_internal, raw)
    if not ok then
        return nil, value
    end
    return value, nil
end

local function manifest_path(root)
    return join_path(root, "kpm.json")
end

local function lock_path(root)
    return join_path(root, "kpm-lock.json")
end

local function plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR)
    if dir ~= "" then
        return dir
    end
    return "."
end

local function fixture_root()
    if os ~= nil and type(os.getenv) == "function" then
        return trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
    end
    return ""
end

local function data_root()
    local root = fixture_root()
    if root ~= "" then
        return join_path(root, ".reqpack-data", PLUGIN_ID)
    end
    return join_path(".reqpack-data", PLUGIN_ID)
end

local function state_paths()
    local root = data_root()
    return {
        root = root,
        releases = join_path(root, "releases.json"),
        search = join_path(root, "search"),
        info = join_path(root, "info"),
    }
end

local function current_project_root(context)
    local request = read_field(context, "request") or {}
    local from_flag = first_non_empty(
        flag_value(object_flags(context), "project-root="),
        flag_value(object_flags(request), "project-root=")
    )
    local value = first_non_empty(
        from_flag,
        read_field(context, "projectRoot"),
        read_field(request, "projectRoot")
    )
    if value ~= nil then
        return expand_runtime_placeholders(value)
    end
    return "."
end

local function normalize_coordinate_parts(name, version)
    local raw_name = trim(name)
    local raw_version = trim(version)
    if raw_name == "" then
        return nil, "expected Maven coordinate group:artifact[:version]"
    end

    local first, second, third = raw_name:match("^([^:]+):([^:]+):([^:]+)$")
    if first ~= nil then
        return {
            group = trim(first),
            artifact = trim(second),
            version = raw_version ~= "" and raw_version or trim(third),
        }, nil
    end

    first, second = raw_name:match("^([^:]+):([^:]+)$")
    if first ~= nil then
        return {
            group = trim(first),
            artifact = trim(second),
            version = trim(raw_version),
        }, nil
    end

    return nil, "expected Maven coordinate group:artifact[:version]"
end

local function coordinate_name(entry)
    return entry.group .. ":" .. entry.artifact
end

local function coordinate_string(entry)
    return entry.group .. ":" .. entry.artifact .. ":" .. entry.version
end

local function sort_entries(entries)
    table.sort(entries, function(left, right)
        return lower(coordinate_name(left)) < lower(coordinate_name(right))
    end)
end

local function parse_manifest(root)
    local path = manifest_path(root)
    local raw = read_file(path)
    if raw == nil or trim(raw) == "" then
        return nil, nil
    end

    local decoded, err = decode_json(raw)
    if decoded == nil or type(decoded) ~= "table" then
        return nil, first_non_empty(err, "failed to parse kpm.json")
    end

    local manifest = {
        name = first_non_empty(read_field(decoded, "name"), DEFAULT_MANIFEST_NAME),
        version = first_non_empty(read_field(decoded, "version"), DEFAULT_MANIFEST_VERSION),
        main = first_non_empty(read_field(decoded, "main"), DEFAULT_MANIFEST_MAIN),
        dependencies = {},
    }

    for _, item in ipairs(type(decoded.dependencies) == "table" and decoded.dependencies or {}) do
        local coord, coord_err = normalize_coordinate_parts(item, "")
        if coord == nil then
            return nil, coord_err
        end
        if trim(coord.version) == "" then
            return nil, "manifest dependency missing version: " .. tostring(item)
        end
        manifest.dependencies[#manifest.dependencies + 1] = coord
    end
    sort_entries(manifest.dependencies)
    return manifest, nil
end

local function render_manifest(manifest)
    local dependencies = {}
    sort_entries(manifest.dependencies)
    for _, entry in ipairs(manifest.dependencies or {}) do
        dependencies[#dependencies + 1] = coordinate_string(entry)
    end
    return encode_json({
        name = manifest.name or DEFAULT_MANIFEST_NAME,
        version = manifest.version or DEFAULT_MANIFEST_VERSION,
        main = manifest.main or DEFAULT_MANIFEST_MAIN,
        dependencies = dependencies,
    }) .. "\n"
end

local function write_manifest(root, manifest)
    return write_file(manifest_path(root), render_manifest(manifest))
end

local function parse_lock(root)
    local path = lock_path(root)
    local raw = read_file(path)
    if raw == nil or trim(raw) == "" then
        return {
            version = "1.0",
            dependencies = {},
        }, nil
    end

    local decoded, err = decode_json(raw)
    if decoded == nil or type(decoded) ~= "table" then
        return nil, first_non_empty(err, "failed to parse kpm-lock.json")
    end

    local lock = {
        version = first_non_empty(read_field(decoded, "version"), "1.0"),
        dependencies = type(decoded.dependencies) == "table" and decoded.dependencies or {},
    }
    return lock, nil
end

local function render_lock(lock)
    return encode_json({
        version = lock.version or "1.0",
        dependencies = lock.dependencies or {},
    }) .. "\n"
end

local function write_lock(root, lock)
    return write_file(lock_path(root), render_lock(lock))
end

local function ensure_manifest(root)
    local manifest, err = parse_manifest(root)
    if manifest ~= nil then
        return manifest, nil
    end
    if err ~= nil then
        return nil, err
    end
    manifest = {
        name = DEFAULT_MANIFEST_NAME,
        version = DEFAULT_MANIFEST_VERSION,
        main = DEFAULT_MANIFEST_MAIN,
        dependencies = {},
    }
    local ok, write_err = write_manifest(root, manifest)
    if not ok then
        return nil, write_err
    end
    return manifest, nil
end

local function index_manifest_dependencies(entries)
    local indexed = {}
    for index, entry in ipairs(entries or {}) do
        indexed[lower(coordinate_name(entry))] = index
    end
    return indexed
end

local function request_to_coordinate(pkg)
    return normalize_coordinate_parts(
        first_non_empty(read_field(pkg, "name"), read_field(pkg, "packageId")),
        first_non_empty(read_field(pkg, "version"), "")
    )
end

local function cache_file_name(name)
    return tostring(name or ""):gsub("[^%w%._%-]+", "_")
end

local function cache_is_fresh(path, ttl)
    local result = run_exec(nil, "test -f " .. shell_quote(path) .. " && stat -c %Y " .. shell_quote(path))
    if result == nil or not result.success then
        return false
    end
    local modified = tonumber(trim(result.stdout))
    if modified == nil then
        return false
    end
    return epoch_now() - modified <= tonumber(ttl or 0)
end

local function read_cached_json(path, ttl)
    if cache_is_fresh(path, ttl) then
        local raw = read_file(path)
        if raw ~= nil and trim(raw) ~= "" then
            return decode_json(raw)
        end
    end
    return nil, nil
end

local function fetch_json_to_cache(context, url, output_path, headers)
    local parts = { "curl", "-fsSL" }
    for _, header in ipairs(headers or {}) do
        parts[#parts + 1] = "-H"
        parts[#parts + 1] = shell_quote(header)
    end
    parts[#parts + 1] = shell_quote(url)
    parts[#parts + 1] = "-o"
    parts[#parts + 1] = shell_quote_always(output_path)
    local command = table.concat(parts, " ")
    local result = run_exec(context, command)
    if result == nil or not result.success then
        return nil, first_non_empty(result and result.stderr, result and result.stdout, "fetch failed")
    end
    local raw = read_file(output_path)
    if raw == nil or trim(raw) == "" then
        raw = result.stdout
    end
    if raw == nil then
        return nil, "failed to read fetched JSON"
    end
    return decode_json(raw)
end

local function cached_fetch_json(context, path, url, ttl, headers)
    local cached, cached_err = read_cached_json(path, ttl)
    if cached ~= nil then
        return cached, nil
    end
    ensure_directory(context, parent_dir(path))
    return fetch_json_to_cache(context, url, path, headers)
end

local function fetch_exact_maven_doc(context, group, artifact)
    local paths = state_paths()
    local key = group .. "__" .. artifact
    local path = join_path(paths.info, cache_file_name(key) .. ".json")
    local query = parse_maven_exact_query(group, artifact)
    local url = "https://search.maven.org/solrsearch/select?rows=1&wt=json&q=" .. query
    local payload, fetch_err = cached_fetch_json(context, path, url, INFO_TTL, {
        "Accept: application/json",
    })
    if payload == nil then
        return nil, fetch_err
    end
    local docs = type(payload.response) == "table" and payload.response.docs or {}
    local doc = type(docs) == "table" and docs[1] or nil
    if type(doc) ~= "table" then
        return nil, "package not found"
    end
    return doc, nil
end

parse_maven_exact_query = function(group, artifact)
    return "g:%22" .. group .. "%22%20AND%20a:%22" .. artifact .. "%22"
end

parse_maven_search_query = function(prompt)
    local value = trim(prompt)
    value = value:gsub(" ", "+")
    value = value:gsub(":", "%%3A")
    value = value:gsub("/", "%%2F")
    value = value:gsub('"', "%%22")
    return value
end

local function maven_doc_to_item(doc, local_item)
    local group = first_non_empty(read_field(doc, "g"), type(local_item) == "table" and local_item.group or nil)
    local artifact = first_non_empty(read_field(doc, "a"), type(local_item) == "table" and local_item.artifact or nil)
    if group == nil or artifact == nil then
        return nil
    end

    local latest = first_non_empty(read_field(doc, "latestVersion"), type(local_item) == "table" and local_item.version or nil)
    local version = first_non_empty(type(local_item) == "table" and local_item.version or nil, latest)
    local extra = {
        coordinate = group .. ":" .. artifact .. ":" .. tostring(version or latest or ""),
        group = group,
        artifact = artifact,
        repository = "maven-central",
        kpmStore = "$HOME/.kpm/store",
        kpmGcRoots = "$HOME/.kpm/gcroots",
        kpmProfiles = "$HOME/.kpm/profiles",
    }
    if type(local_item) == "table" then
        extra = merge_extra_fields(extra, local_item.extraFields)
    end
    return {
        name = group .. ":" .. artifact,
        packageId = group .. ":" .. artifact,
        version = version,
        latestVersion = latest,
        summary = group .. ":" .. artifact,
        description = group .. ":" .. artifact,
        repository = "maven-central",
        installed = type(local_item) == "table" and local_item.installed == true or false,
        status = type(local_item) == "table" and (local_item.status or "available") or "available",
        packageType = "maven-coordinate",
        type = "package",
        extraFields = extra,
    }
end

local function local_items_by_name(root)
    local manifest = select(1, parse_manifest(root))
    if manifest == nil then
        return {}
    end
    local lock = select(1, parse_lock(root)) or { dependencies = {} }
    local items = {}

    for _, dep in ipairs(manifest.dependencies or {}) do
        local locked_key = nil
        local locked_entry = nil
        for key, entry in pairs(lock.dependencies or {}) do
            local coord = select(1, normalize_coordinate_parts(key, ""))
            if coord ~= nil and lower(coordinate_name(coord)) == lower(coordinate_name(dep)) then
                locked_key = key
                locked_entry = entry
                break
            end
        end

        local version = first_non_empty(type(locked_entry) == "table" and read_field(locked_entry, "version") or nil, dep.version)
        local extra = {
            coordinate = coordinate_string({ group = dep.group, artifact = dep.artifact, version = version }),
            group = dep.group,
            artifact = dep.artifact,
            manifestVersion = dep.version,
            lockKey = locked_key,
            kpmStore = "$HOME/.kpm/store",
            kpmGcRoots = "$HOME/.kpm/gcroots",
            kpmProfiles = "$HOME/.kpm/profiles",
        }
        if type(locked_entry) == "table" then
            extra.storePath = read_field(locked_entry, "storePath")
            extra.hash = read_field(locked_entry, "hash")
            extra.transitiveDependencies = read_field(locked_entry, "transitiveDependencies") or {}
        end

        local package_name = dep.group .. ":" .. dep.artifact
        items[lower(package_name)] = {
            name = package_name,
            packageId = package_name,
            group = dep.group,
            artifact = dep.artifact,
            version = version,
            latestVersion = version,
            installed = true,
            status = "installed",
            packageType = "maven-coordinate",
            type = "package",
            summary = package_name,
            description = package_name,
            extraFields = extra,
        }
    end
    return items
end

local function ensure_kpm_launcher(context)
    if not command_exists(context, "java") then
        return nil, "java binary not available"
    end

    local existing = run_exec(context, "test -x " .. KPM_BIN_EXPR)
    if existing ~= nil and existing.success then
        return KPM_BIN_EXPR, nil
    end

    begin_step(context, "bootstrap kpm launcher")
    local paths = state_paths()
    local releases, err = cached_fetch_json(context, paths.releases, RELEASES_URL, RELEASES_TTL, {
        "Accept: application/vnd.github+json",
    })
    if releases == nil or type(releases) ~= "table" then
        return nil, first_non_empty(err, "failed to query kpm releases")
    end

    local jar_url = nil
    for _, release in ipairs(releases) do
        for _, asset in ipairs(type(release.assets) == "table" and release.assets or {}) do
            local name = trim(read_field(asset, "name") or "")
            if name:match("^kpm%-.+%.jar$") ~= nil then
                jar_url = first_non_empty(read_field(asset, "browser_download_url"))
                break
            end
        end
        if jar_url ~= nil then
            break
        end
    end
    if jar_url == nil then
        return nil, "kpm release jar not found"
    end

    local exists_after = run_exec(context, "mkdir -p " .. KPM_BIN_DIR_EXPR)
    if exists_after == nil or not exists_after.success then
        return nil, first_non_empty(exists_after and exists_after.stderr, exists_after and exists_after.stdout, "failed to create kpm bin dir")
    end

    local download = run_exec(context, "curl -fsSL " .. shell_quote_always(jar_url) .. " -o " .. KPM_JAR_EXPR)
    if download == nil or not download.success then
        return nil, first_non_empty(download and download.stderr, download and download.stdout, "failed to download kpm jar")
    end

    local launcher_script = "#!/bin/sh\nexec java -jar \"$HOME/.local/share/reqpack/kpm/kpm.jar\" \"$@\"\n"
    local home_dir = os ~= nil and type(os.getenv) == "function" and os.getenv("HOME") or nil
    if trim(home_dir) ~= "" then
        local launcher_path = tostring(home_dir) .. "/.local/share/reqpack/kpm/bin/kpm"
        local handle = io.open(launcher_path, "w")
        if handle == nil then
            return nil, "open failed for " .. tostring(launcher_path)
        end
        handle:write(launcher_script)
        handle:close()
    end
    local chmod = run_exec(context, "chmod +x " .. KPM_BIN_EXPR)
    if chmod == nil or not chmod.success then
        return nil, first_non_empty(chmod and chmod.stderr, chmod and chmod.stdout, "failed to chmod kpm launcher")
    end
    return KPM_BIN_EXPR, nil
end

local function kpm_install_command(launcher)
    return launcher .. " install"
end

local function normalize_packages(packages)
    local normalized = {}
    for _, pkg in ipairs(packages or {}) do
        local coord, err = request_to_coordinate(pkg)
        if coord == nil then
            return nil, err
        end
        if trim(coord.version) == "" then
            return nil, "kpm package version required"
        end
        normalized[#normalized + 1] = coord
    end
    return normalized, nil
end

local function merge_dependencies(existing, additions)
    local merged = {}
    for _, item in ipairs(existing or {}) do
        merged[#merged + 1] = shallow_copy(item)
    end
    local indexed = index_manifest_dependencies(merged)
    for _, item in ipairs(additions or {}) do
        local key = lower(coordinate_name(item))
        local index = indexed[key]
        if index ~= nil then
            merged[index].version = item.version
        else
            merged[#merged + 1] = shallow_copy(item)
        end
        indexed = index_manifest_dependencies(merged)
    end
    sort_entries(merged)
    return merged
end

local function remove_dependencies(existing, removals)
    local remove_set = {}
    for _, item in ipairs(removals or {}) do
        remove_set[lower(coordinate_name(item))] = true
    end
    local kept = {}
    for _, item in ipairs(existing or {}) do
        if not remove_set[lower(coordinate_name(item))] then
            kept[#kept + 1] = shallow_copy(item)
        end
    end
    sort_entries(kept)
    return kept
end

local function prune_lock(lock, removals)
    local remove_set = {}
    for _, item in ipairs(removals or {}) do
        remove_set[lower(coordinate_name(item))] = true
    end
    local kept = {}
    for key, value in pairs(lock.dependencies or {}) do
        local coord = select(1, normalize_coordinate_parts(key, ""))
        if coord == nil or not remove_set[lower(coordinate_name(coord))] then
            kept[key] = value
        end
    end
    lock.dependencies = kept
    return lock
end

local function read_local_manifest_from_path(path)
    local target = trim(path)
    if target == "" then
        return nil, "local kpm path required"
    end
    if path_is_dir(target) then
        target = join_path(target, "kpm.json")
    end
    local raw = read_file(target)
    if raw == nil or trim(raw) == "" then
        return nil, "local kpm manifest not found"
    end
    local decoded, decode_err = decode_json(raw)
    if decoded == nil or type(decoded) ~= "table" then
        return nil, first_non_empty(decode_err, "failed to parse local kpm manifest")
    end
    local manifest = {
        name = first_non_empty(read_field(decoded, "name"), DEFAULT_MANIFEST_NAME),
        version = first_non_empty(read_field(decoded, "version"), DEFAULT_MANIFEST_VERSION),
        main = first_non_empty(read_field(decoded, "main"), DEFAULT_MANIFEST_MAIN),
        dependencies = {},
    }
    for _, item in ipairs(type(decoded.dependencies) == "table" and decoded.dependencies or {}) do
        local coord, coord_err = normalize_coordinate_parts(item, "")
        if coord == nil then
            return nil, coord_err
        end
        if trim(coord.version) == "" then
            return nil, "manifest dependency missing version: " .. tostring(item)
        end
        manifest.dependencies[#manifest.dependencies + 1] = coord
    end
    sort_entries(manifest.dependencies)
    return manifest, nil
end

local function run_kpm_install(context, launcher)
    local result = run_exec(context, kpm_install_command(launcher))
    if result == nil or not result.success then
        return nil, first_non_empty(result and result.stderr, result and result.stdout, "kpm install failed")
    end
    return result.stdout or "", nil
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
    return { "Kotlin", "JVM", "Package Manager", "Wrapper" }
end

function plugin.getMissingPackages(packages)
    local root = current_project_root(nil)
    local manifest = select(1, parse_manifest(root))
    if manifest == nil then
        local missing = {}
        for _, pkg in ipairs(packages or {}) do
            local action = lower(read_field(pkg, "action") or "install")
            if action ~= "remove" then
                missing[#missing + 1] = pkg
            end
        end
        return missing
    end

    local indexed = index_manifest_dependencies(manifest.dependencies)
    local missing = {}
    for _, pkg in ipairs(packages or {}) do
        local coord = select(1, request_to_coordinate(pkg))
        if coord ~= nil then
            local current = manifest.dependencies[indexed[lower(coordinate_name(coord))] or 0]
            local action = lower(read_field(pkg, "action") or "install")
            if action == "remove" then
                if current ~= nil then
                    missing[#missing + 1] = pkg
                end
            elseif action == "update" then
                if current ~= nil and trim(current.version) ~= trim(coord.version) then
                    missing[#missing + 1] = pkg
                end
            else
                if current == nil or trim(current.version) ~= trim(coord.version) then
                    missing[#missing + 1] = pkg
                end
            end
        end
    end
    return missing
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end

    local root = current_project_root(context)
    local manifest, err = ensure_manifest(root)
    if manifest == nil then
        tx_failed(context, err)
        return false
    end

    local normalized, normalize_err = normalize_packages(requested)
    if normalized == nil then
        tx_failed(context, normalize_err)
        return false
    end

    manifest.dependencies = merge_dependencies(manifest.dependencies, normalized)
    local ok, write_err = write_manifest(root, manifest)
    if not ok then
        tx_failed(context, write_err)
        return false
    end

    local launcher, launcher_err = ensure_kpm_launcher(context)
    if launcher == nil then
        tx_failed(context, launcher_err)
        return false
    end

    begin_step(context, "install kpm dependencies")
    local _, install_err = run_kpm_install(context, launcher)
    if install_err ~= nil then
        tx_failed(context, install_err)
        return false
    end

    emit_event(context, "installed", requested)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    path = first_non_empty(path, read_field(read_field(context, "request") or {}, "localPath"), read_field(context, "localPath"))
    local root = current_project_root(context)
    local manifest, err = ensure_manifest(root)
    if manifest == nil then
        tx_failed(context, err)
        return false
    end

    local external_manifest, external_err = read_local_manifest_from_path(path)
    if external_manifest == nil then
        tx_failed(context, external_err)
        return false
    end

    manifest.dependencies = merge_dependencies(manifest.dependencies, external_manifest.dependencies)
    local ok, write_err = write_manifest(root, manifest)
    if not ok then
        tx_failed(context, write_err)
        return false
    end

    local launcher, launcher_err = ensure_kpm_launcher(context)
    if launcher == nil then
        tx_failed(context, launcher_err)
        return false
    end

    begin_step(context, "install local kpm manifest")
    local _, install_err = run_kpm_install(context, launcher)
    if install_err ~= nil then
        tx_failed(context, install_err)
        return false
    end

    emit_event(context, "installed", { path = path, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end

    local root = current_project_root(context)
    local manifest, err = parse_manifest(root)
    if manifest == nil then
        tx_failed(context, first_non_empty(err, "kpm.json not found"))
        return false
    end

    local normalized = {}
    for _, pkg in ipairs(requested) do
        local coord, coord_err = request_to_coordinate(pkg)
        if coord == nil then
            tx_failed(context, coord_err)
            return false
        end
        normalized[#normalized + 1] = coord
    end

    manifest.dependencies = remove_dependencies(manifest.dependencies, normalized)
    local ok, write_err = write_manifest(root, manifest)
    if not ok then
        tx_failed(context, write_err)
        return false
    end

    local lock = select(1, parse_lock(root)) or { version = "1.0", dependencies = {} }
    lock = prune_lock(lock, normalized)
    local lock_ok, lock_err = write_lock(root, lock)
    if not lock_ok then
        tx_failed(context, lock_err)
        return false
    end

    local launcher, launcher_err = ensure_kpm_launcher(context)
    if launcher == nil then
        tx_failed(context, launcher_err)
        return false
    end

    begin_step(context, "remove kpm dependencies")
    local _, install_err = run_kpm_install(context, launcher)
    if install_err ~= nil then
        tx_failed(context, install_err)
        return false
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end

    local root = current_project_root(context)
    local manifest, err = parse_manifest(root)
    if manifest == nil then
        tx_failed(context, first_non_empty(err, "kpm.json not found"))
        return false
    end

    local normalized, normalize_err = normalize_packages(requested)
    if normalized == nil then
        tx_failed(context, normalize_err)
        return false
    end

    manifest.dependencies = merge_dependencies(manifest.dependencies, normalized)
    local ok, write_err = write_manifest(root, manifest)
    if not ok then
        tx_failed(context, write_err)
        return false
    end

    local launcher, launcher_err = ensure_kpm_launcher(context)
    if launcher == nil then
        tx_failed(context, launcher_err)
        return false
    end

    begin_step(context, "update kpm dependencies")
    local _, install_err = run_kpm_install(context, launcher)
    if install_err ~= nil then
        tx_failed(context, install_err)
        return false
    end

    emit_event(context, "updated", requested)
    tx_success(context)
    return true
end

function plugin.list(context)
    local root = current_project_root(context)
    local local_items = local_items_by_name(root)
    local items = {}
    for _, item in pairs(local_items) do
        items[#items + 1] = {
            name = item.name,
            packageId = item.packageId,
            version = item.version,
            latestVersion = item.latestVersion,
            installed = item.installed,
            status = item.status,
            summary = item.summary,
            description = item.description,
            packageType = item.packageType,
            type = item.type,
            extraFields = item.extraFields,
        }
    end
    table.sort(items, function(left, right)
        return lower(left.name or "") < lower(right.name or "")
    end)
    emit_event(context, "listed", items)
    return items
end

function plugin.search(context, prompt)
    prompt = first_non_empty(prompt, read_field(read_field(context, "request") or {}, "prompt"))
    local cleaned = trim(prompt)
    if cleaned == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local paths = state_paths()
    local query = parse_maven_search_query(cleaned)
    local path = join_path(paths.search, cache_file_name(query) .. ".json")
    local url = "https://search.maven.org/solrsearch/select?rows=" .. tostring(DEFAULT_SEARCH_LIMIT) .. "&wt=json&q=" .. query
    local payload, err = cached_fetch_json(context, path, url, SEARCH_TTL, {
        "Accept: application/json",
    })
    if payload == nil then
        log_warn(context, first_non_empty(err, "maven search failed"))
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local docs = type(payload.response) == "table" and payload.response.docs or {}
    local items = {}
    for _, doc in ipairs(type(docs) == "table" and docs or {}) do
        local item = maven_doc_to_item(doc, nil)
        if item ~= nil then
            items[#items + 1] = item
        end
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local request = read_field(context, "request") or {}
    local request_packages = type(read_field(request, "packages")) == "table" and read_field(request, "packages") or {}
    local request_first = request_packages[1] or {}
    name = first_non_empty(
        name,
        read_field(context, "package"),
        read_field(context, "packageId"),
        read_field(context, "name"),
        read_field(request, "package"),
        read_field(request, "packageId"),
        read_field(request, "name"),
        read_field(request_first, "name"),
        read_field(request_first, "packageId"),
        read_field(request_first, "package")
    )
    local coord, err = normalize_coordinate_parts(name, "")
    if coord == nil then
        log_warn(context, err)
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local doc, fetch_err = fetch_exact_maven_doc(context, coord.group, coord.artifact)
    if doc == nil then
        log_warn(context, first_non_empty(fetch_err, "maven info lookup failed"))
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local local_item = local_items_by_name(current_project_root(context))[lower(coord.group .. ":" .. coord.artifact)]
    local item = maven_doc_to_item(doc, local_item)
    if item ~= nil and local_item ~= nil then
        item.installed = true
        item.status = "installed"
        item.extraFields = merge_extra_fields(item.extraFields, local_item.extraFields)
        item.version = first_non_empty(local_item.version, item.version)
    end
    emit_event(context, "informed", item or {})
    return item or {}
end

function plugin.outdated(context)
    local root = current_project_root(context)
    local local_items = local_items_by_name(root)
    local items = {}

    for _, local_item in pairs(local_items) do
        local doc = fetch_exact_maven_doc(context, local_item.group, local_item.artifact)
        local info = type(doc) == "table" and maven_doc_to_item(doc, local_item) or nil
        if type(info) == "table" and first_non_empty(info.latestVersion) ~= nil and trim(info.latestVersion) ~= trim(local_item.version) then
            local outdated_item = shallow_copy(local_item)
            outdated_item.latestVersion = info.latestVersion
            outdated_item.status = "outdated"
            outdated_item.installed = true
            items[#items + 1] = outdated_item
        end
    end

    table.sort(items, function(left, right)
        return lower(left.name or "") < lower(right.name or "")
    end)
    emit_event(context, "outdated", items)
    return items
end

function plugin.resolvePackage(context, package)
    local coord = select(1, request_to_coordinate(package))
    if coord == nil then
        return nil
    end
    local local_item = local_items_by_name(current_project_root(context))[lower(coord.group .. ":" .. coord.artifact)]
    if local_item ~= nil then
        return local_item
    end
    return plugin.info(context, coord.group .. ":" .. coord.artifact)
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
        ecosystemScopes = { "kpm", "kotlin", "jvm", "maven" },
        writeScopes = {
            { kind = "plugin-subpath", path = ".reqpack-data" },
            { kind = "user-home-subpath", value = ".kpm" },
            { kind = "user-home-subpath", value = ".local/share/reqpack/kpm" },
        },
        networkScopes = {
            "api.github.com",
            "github.com",
            "search.maven.org",
            "repo1.maven.org",
            "repo.maven.apache.org",
        },
        privilegeLevel = "user",
        osvEcosystem = "Maven",
        purlType = "maven",
    }
end

return plugin
