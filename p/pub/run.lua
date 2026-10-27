plugin = {}

local PLUGIN_ID = "pub"
local PLUGIN_NAME = "Dart pub"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "dart"
local COMPLETION_URL = "https://pub.dev/api/package-name-completion-data"
local PACKAGE_URL_PREFIX = "https://pub.dev/api/packages/"
local CACHE_TTL_COMPLETION = 8 * 60 * 60
local CACHE_TTL_PACKAGE = 120
local CACHE_TTL_SCORE = 120
local CACHE_TTL_PUBLISHER = 120
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

local function is_array(value)
    if type(value) ~= "table" then
        return false
    end
    local max_index = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or math.floor(key) ~= key then
            return false
        end
        if key > max_index then
            max_index = key
        end
    end
    for index = 1, max_index do
        if value[index] == nil then
            return false
        end
    end
    return true
end

local function split_lines(value)
    local lines = {}
    for line in tostring(value or ""):gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end
    return lines
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
    local handle = io.open(path, "r")
    if handle == nil then
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(path, content)
    local dir = parent_dir(path)
    local tmp_path = path .. ".tmp"
    local handle = io.open(tmp_path, "w")
    if handle == nil then
        if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
            return false
        end
        handle = io.open(tmp_path, "w")
    end
    if handle == nil then
        return false
    end
    handle:write(content)
    handle:close()

    if os == nil or type(os.remove) ~= "function" or type(os.rename) ~= "function" then
        local direct = io.open(path, "w")
        if direct == nil then
            return false
        end
        direct:write(content)
        direct:close()
        return true
    end

    os.remove(path)
    local ok = os.rename(tmp_path, path)
    if not ok then
        os.remove(tmp_path)
        return false
    end
    return true
end

local function home_dir()
    if os ~= nil and type(os.getenv) == "function" then
        return first_nonempty(os.getenv("HOME"), os.getenv("USERPROFILE"), "/home/test", ".")
    end
    return "/home/test"
end

local function epoch_now()
    if os ~= nil and type(os.time) == "function" then
        return os.time()
    end
    return 0
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

local function exec_run(context, command)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return context.exec.run(command)
    end
    return reqpack.exec.run(command)
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
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

local function object_flags(object)
    local flags = read_field(object, "flags")
    if type(flags) ~= "table" and type(flags) ~= "userdata" then
        return {}
    end
    local result = {}
    for _, flag in ipairs(flags) do
        result[#result + 1] = trim(flag)
    end
    return result
end

local function collect_raw_flags(context, packages, package)
    local flags = {}
    local function collect_from(value)
        for _, flag in ipairs(object_flags(value)) do
            flags[#flags + 1] = flag
        end
    end
    collect_from(context)
    local request = read_field(context, "request")
    collect_from(request)
    collect_from(package)
    for _, pkg in ipairs(packages or {}) do
        if pkg ~= package then
            collect_from(pkg)
        end
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
        local lowered = lower(trim(flag))
        if lowered:sub(1, #prefix) == prefix then
            return trim(flag:sub(#prefix + 1))
        end
    end
    return nil
end

local function flag_values(flags, key)
    local prefix = lower(trim(key)) .. "="
    local values = {}
    for _, flag in ipairs(flags or {}) do
        local lowered = lower(trim(flag))
        if lowered:sub(1, #prefix) == prefix then
            local value = trim(flag:sub(#prefix + 1))
            if value ~= "" then
                values[#values + 1] = value
            end
        end
    end
    return values
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageId") or "")
end

local function package_version(pkg)
    return trim(read_field(pkg, "version") or "")
end

local function package_action(pkg)
    return lower(trim(read_field(pkg, "action") or "install"))
end

local function local_path_from_context(context, path)
    local request = read_field(context, "request") or {}
    return trim(path or read_field(context, "localPath") or read_field(request, "localPath") or "")
end

local function cache_root(context, packages)
    local flags = collect_raw_flags(context, packages)
    local explicit = flag_value(flags, "cache-root")
    if explicit ~= nil and explicit ~= "" then
        return explicit
    end
    return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
end

local function shared_paths(context, packages)
    local root = cache_root(context, packages)
    local query = join_path(root, "query")
    return {
        root = root,
        pub_cache = join_path(root, "pub-cache"),
        bin = join_path(root, "pub-cache", "bin"),
        query = query,
        completion = join_path(query, "completion-data.json"),
        completion_ts = join_path(query, "completion-data.ts"),
        package_dir = join_path(query, "packages"),
    }
end

local function env_prefix(paths)
    return table.concat({
        "PUB_CACHE=" .. shell_quote(paths.pub_cache),
        "NO_COLOR='1'",
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
    }, " ")
end

local function build_dart_pub_command(context, packages, args)
    local paths = shared_paths(context, packages)
    local parts = { env_prefix(paths), REQUIRED_BINARY }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = shell_quote(arg)
    end
    return table.concat(parts, " "), paths
end

local function cache_key(name)
    local normalized = lower(trim(name))
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

local function persist_cache(base_path, ts_path, body)
    write_file(base_path, body)
    write_file(ts_path, tostring(epoch_now()))
end

local function fetch_url(context, url)
    local result = exec_run(context, "curl -fsSL " .. shell_quote(url))
    if result == nil or result.success ~= true then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "request failed")
    end
    return result.stdout, nil
end

local function cached_fetch(context, body_path, ts_path, url, ttl)
    local cached = read_file(body_path)
    if cached ~= nil and is_cache_fresh(ts_path, ttl) then
        return cached, nil
    end
    local body, err = fetch_url(context, url)
    if body ~= nil then
        persist_cache(body_path, ts_path, body)
        return body, nil
    end
    if cached ~= nil then
        return cached, nil
    end
    return nil, err
end

local function list_directory(context, path)
    local result = exec_run(context, "ls -1A " .. shell_quote(path))
    if result == nil or result.success ~= true then
        return {}
    end
    local entries = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local text = trim(line)
        if text ~= "" then
            entries[#entries + 1] = text
        end
    end
    table.sort(entries)
    return entries
end

local function map_keys(value)
    if type(value) ~= "table" then
        return {}
    end
    local keys = {}
    for key in pairs(value) do
        local text = trim(key)
        if text ~= "" then
            keys[#keys + 1] = text
        end
    end
    table.sort(keys)
    return keys
end

local function map_dependency_keys(pubspec)
    local deps = read_field(pubspec, "dependencies")
    if type(deps) ~= "table" then
        return nil
    end
    local names = map_keys(deps)
    if #names == 0 then
        return nil
    end
    return names
end

local function join_tags(tags)
    if type(tags) ~= "table" then
        return nil
    end
    local values = {}
    for _, tag in ipairs(tags) do
        local text = trim(tag)
        if text ~= "" then
            values[#values + 1] = text
        end
    end
    if #values == 0 then
        return nil
    end
    return table.concat(values, ", ")
end

local function normalize_license(value)
    if type(value) == "table" and is_array(value) then
        local parts = {}
        for _, item in ipairs(value) do
            local text = trim(item)
            if text ~= "" then
                parts[#parts + 1] = text
            end
        end
        if #parts > 0 then
            return table.concat(parts, ", ")
        end
    end
    return first_nonempty(value)
end

local function package_cache_paths(paths, name, suffix)
    local key = cache_key(name)
    local body = join_path(paths.package_dir, key .. suffix .. ".json")
    return body, body .. ".ts"
end

local function fetch_completion_dataset(context, paths)
    local raw, err = cached_fetch(context, paths.completion, paths.completion_ts, COMPLETION_URL, CACHE_TTL_COMPLETION)
    if raw == nil then
        return nil, err
    end
    local payload, decode_err = decode_json(raw)
    if payload == nil then
        return nil, decode_err
    end
    local packages = read_field(payload, "packages")
    if type(packages) ~= "table" then
        return {}, nil
    end
    return packages, nil
end

local function fetch_package_payload(context, paths, name)
    local body_path, ts_path = package_cache_paths(paths, name, "")
    local raw, err = cached_fetch(context, body_path, ts_path, PACKAGE_URL_PREFIX .. name, CACHE_TTL_PACKAGE)
    if raw == nil then
        return nil, err
    end
    return decode_json(raw)
end

local function fetch_score_payload(context, paths, name)
    local body_path, ts_path = package_cache_paths(paths, name, ".score")
    local raw, err = cached_fetch(context, body_path, ts_path, PACKAGE_URL_PREFIX .. name .. "/score", CACHE_TTL_SCORE)
    if raw == nil then
        return nil, err
    end
    return decode_json(raw)
end

local function fetch_publisher_payload(context, paths, name)
    local body_path, ts_path = package_cache_paths(paths, name, ".publisher")
    local raw, err = cached_fetch(context, body_path, ts_path, PACKAGE_URL_PREFIX .. name .. "/publisher", CACHE_TTL_PUBLISHER)
    if raw == nil then
        return nil, err
    end
    return decode_json(raw)
end

local function parse_global_list(raw)
    local items = {}
    for _, line in ipairs(split_lines(raw)) do
        local name, version = line:match("^(%S+)%s+(%S+)%s*$")
        if name ~= nil and version ~= nil then
            items[#items + 1] = {
                name = trim(name),
                packageId = trim(name),
                version = trim(version),
                installed = true,
                status = "installed",
                packageType = "dart-pub",
            }
        end
    end
    table.sort(items, function(left, right)
        return left.name < right.name
    end)
    return items
end

local function contains_value(values, wanted)
    for _, value in ipairs(values or {}) do
        if value == wanted then
            return true
        end
    end
    return false
end

local function infer_binaries(bin_entries, package_name_value, remote_execs)
    local binaries = {}
    local exact = {}
    for _, entry in ipairs(bin_entries or {}) do
        exact[entry] = true
    end
    for _, executable in ipairs(remote_execs or {}) do
        if exact[executable] then
            binaries[#binaries + 1] = executable
        end
    end
    if #binaries > 0 then
        table.sort(binaries)
        return binaries
    end
    local prefix = trim(package_name_value)
    if prefix == "" then
        return {}
    end
    for _, entry in ipairs(bin_entries or {}) do
        if entry == prefix or entry:sub(1, #prefix + 1) == prefix .. "-" or entry:sub(1, #prefix + 1) == prefix .. "_" then
            binaries[#binaries + 1] = entry
        end
    end
    table.sort(binaries)
    return binaries
end

local function map_remote_item(name, package_payload, score_payload, publisher_payload)
    if type(package_payload) ~= "table" then
        return nil
    end
    local latest = read_field(package_payload, "latest") or {}
    local pubspec = read_field(latest, "pubspec") or {}
    local version = first_nonempty(read_field(latest, "version"), read_field(package_payload, "version"))
    local executables = map_keys(read_field(pubspec, "executables"))
    local tags = json_value(read_field(score_payload or {}, "tags"))
    local extra = {
        publisher = first_nonempty(read_field(publisher_payload or {}, "publisherId")),
        archiveUrl = first_nonempty(read_field(latest, "archive_url")),
        archiveSha256 = first_nonempty(read_field(latest, "archive_sha256")),
        sdk = first_nonempty(read_field(read_field(pubspec, "environment") or {}, "sdk")),
        executables = #executables > 0 and executables or nil,
        downloadCount30Days = json_value(read_field(score_payload or {}, "downloadCount30Days")),
        likeCount = json_value(read_field(score_payload or {}, "likeCount")),
        grantedPoints = json_value(read_field(score_payload or {}, "grantedPoints")),
        maxPoints = json_value(read_field(score_payload or {}, "maxPoints")),
        tags = tags,
    }
    if next(extra) == nil then
        extra = nil
    end
    return {
        name = first_nonempty(read_field(package_payload, "name"), read_field(pubspec, "name"), name),
        packageId = first_nonempty(read_field(package_payload, "name"), read_field(pubspec, "name"), name),
        version = version,
        latestVersion = version,
        installed = false,
        status = "available",
        type = "package",
        packageType = "dart-pub",
        summary = first_nonempty(read_field(pubspec, "description"), name),
        description = first_nonempty(read_field(pubspec, "description")),
        homepage = first_nonempty(read_field(pubspec, "homepage"), read_field(pubspec, "repository")),
        repository = first_nonempty(read_field(pubspec, "repository"), read_field(pubspec, "homepage")),
        license = normalize_license(read_field(pubspec, "license")),
        dependencies = map_dependency_keys(pubspec),
        binaries = #executables > 0 and shallow_copy(executables) or nil,
        extraFields = extra,
        score = json_value(read_field(score_payload or {}, "grantedPoints")),
        popularity = json_value(read_field(score_payload or {}, "downloadCount30Days")),
        tags = join_tags(tags),
    }
end

local function fetch_remote_item(context, paths, name)
    local package_payload = select(1, fetch_package_payload(context, paths, name))
    if package_payload == nil then
        return nil
    end
    local score_payload = select(1, fetch_score_payload(context, paths, name))
    local publisher_payload = select(1, fetch_publisher_payload(context, paths, name))
    return map_remote_item(name, package_payload, score_payload, publisher_payload)
end

local function merge_installed_with_remote(installed_item, remote_item, bin_entries)
    if remote_item == nil then
        local copy = shallow_copy(installed_item or {})
        copy.binaries = infer_binaries(bin_entries, copy.name, {})
        if #copy.binaries == 0 then
            copy.binaries = nil
        end
        if copy.extraFields == nil and copy.binaries ~= nil then
            copy.extraFields = { executables = shallow_copy(copy.binaries) }
        elseif copy.extraFields ~= nil and copy.binaries ~= nil then
            copy.extraFields = shallow_copy(copy.extraFields)
            copy.extraFields.executables = shallow_copy(copy.binaries)
        end
        copy.type = copy.type or "package"
        copy.packageType = copy.packageType or "dart-pub"
        return copy
    end
    local merged = shallow_copy(remote_item)
    merged.installed = installed_item ~= nil
    merged.status = installed_item ~= nil and "installed" or merged.status
    if installed_item ~= nil then
        merged.version = first_nonempty(installed_item.version, remote_item.version)
    end
    local remote_execs = read_field(read_field(remote_item, "extraFields") or {}, "executables")
    local binaries = infer_binaries(bin_entries, merged.name, type(remote_execs) == "table" and remote_execs or {})
    if #binaries > 0 then
        merged.binaries = binaries
        merged.extraFields = shallow_copy(merged.extraFields or {})
        merged.extraFields.executables = shallow_copy(binaries)
    end
    return merged
end

local function installed_lookup(context, packages)
    local lookup = {}
    if not command_exists(context, REQUIRED_BINARY) then
        return lookup, shared_paths(context, packages), {}
    end
    local command, paths = build_dart_pub_command(context, packages, { "pub", "global", "list" })
    local result = exec_run(context, command)
    if result == nil or result.success ~= true then
        return lookup, paths, {}
    end
    local items = parse_global_list(result.stdout)
    for _, item in ipairs(items) do
        lookup[item.name] = item
    end
    local bin_entries = list_directory(context, paths.bin)
    return lookup, paths, bin_entries
end

local function build_installed_items(context, packages)
    local lookup, paths, bin_entries = installed_lookup(context, packages)
    local items = {}
    for _, installed_item in pairs(lookup) do
        local remote_item = fetch_remote_item(context, paths, installed_item.name)
        items[#items + 1] = merge_installed_with_remote(installed_item, remote_item, bin_entries)
    end
    table.sort(items, function(left, right)
        return tostring(left.name or "") < tostring(right.name or "")
    end)
    return items, lookup, paths, bin_entries
end

local function compare_tokens(left, right)
    if left == right then
        return 0
    end
    local left_number = tonumber(left)
    local right_number = tonumber(right)
    if left_number ~= nil and right_number ~= nil then
        if left_number < right_number then
            return -1
        end
        return 1
    end
    if left_number ~= nil then
        return 1
    end
    if right_number ~= nil then
        return -1
    end
    if tostring(left) < tostring(right) then
        return -1
    end
    return 1
end

local function version_tokens(value)
    local tokens = {}
    for token in tostring(value or ""):gmatch("([0-9A-Za-z]+)") do
        tokens[#tokens + 1] = token
    end
    return tokens
end

local function compare_versions(left, right)
    local left_tokens = version_tokens(left)
    local right_tokens = version_tokens(right)
    local max_count = math.max(#left_tokens, #right_tokens)
    for index = 1, max_count do
        local left_token = left_tokens[index] or "0"
        local right_token = right_tokens[index] or "0"
        local cmp = compare_tokens(left_token, right_token)
        if cmp ~= 0 then
            return cmp
        end
    end
    return 0
end

local function request_packages(context, packages)
    if (type(packages) == "table" or type(packages) == "userdata") and #packages > 0 then
        return packages
    end
    local request = read_field(context, "request") or {}
    local request_packages_value = read_field(request, "packages")
    if type(request_packages_value) == "table" or type(request_packages_value) == "userdata" then
        return request_packages_value
    end
    return {}
end

local function activate_args_for_package(context, packages, package, local_path)
    local flags = collect_raw_flags(context, packages, package)
    local args = { "pub", "global", "activate" }
    if local_path ~= nil and local_path ~= "" then
        args[#args + 1] = "--source"
        args[#args + 1] = "path"
    end
    if has_flag(flags, "overwrite") then
        args[#args + 1] = "--overwrite"
    end
    if has_flag(flags, "no-executables") then
        args[#args + 1] = "--no-executables"
    end
    for _, executable in ipairs(flag_values(flags, "executable")) do
        args[#args + 1] = "--executable=" .. executable
    end
    if local_path ~= nil and local_path ~= "" then
        args[#args + 1] = local_path
    else
        local name = package_name(package)
        if name ~= "" then
            args[#args + 1] = name
        end
        local version = package_version(package)
        if version ~= "" then
            args[#args + 1] = version
        end
    end
    return args
end

local function run_mutation(context, packages, package, args, fallback_error)
    local command = build_dart_pub_command(context, packages, args)
    local result = exec_run(context, command)
    if result == nil or result.success ~= true then
        return false, first_nonempty(result and result.stderr, result and result.stdout, fallback_error)
    end
    return true, nil
end

local function ranked_candidates(prompt, packages)
    local query = lower(trim(prompt))
    local ranked = {}
    for _, name in ipairs(packages or {}) do
        local text = trim(name)
        local lowered = lower(text)
        if text ~= "" and lowered:find(query, 1, true) ~= nil then
            local score = 100
            if lowered == query then
                score = 1000
            elseif lowered:sub(1, #query) == query then
                score = 500
            end
            ranked[#ranked + 1] = { name = text, score = score }
        end
    end
    table.sort(ranked, function(left, right)
        if left.score == right.score then
            if #left.name ~= #right.name then
                return #left.name < #right.name
            end
            return left.name < right.name
        end
        return left.score > right.score
    end)
    return ranked
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
    return { "Dart", "Flutter", "pub", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end
    local action = package_action(requested[1])
    if not command_exists(nil, REQUIRED_BINARY) then
        if action == "install" then
            return requested
        end
        return {}
    end
    local lookup = select(1, installed_lookup(nil, requested))
    local missing = {}
    for _, package in ipairs(requested) do
        local name = package_name(package)
        local installed = lookup[name] ~= nil
        local current_action = package_action(package)
        if current_action == "remove" then
            if installed then
                missing[#missing + 1] = package
            end
        elseif current_action == "update" then
            local remote_item = fetch_remote_item(nil, shared_paths(nil, requested), name)
            if remote_item == nil or not installed then
                missing[#missing + 1] = package
            elseif compare_versions(lookup[name].version, remote_item.latestVersion or remote_item.version) < 0 then
                missing[#missing + 1] = package
            end
        elseif not installed then
            missing[#missing + 1] = package
        end
    end
    return missing
end

function plugin.install(context, packages)
    local local_path = local_path_from_context(context)
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end
    local requested = request_packages(context, packages)
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end
    begin_step(context, "install pub packages")
    for _, package in ipairs(requested) do
        local name = package_name(package)
        if name == "" then
            tx_failed(context, "pub package name missing")
            return false
        end
        local ok, err = run_mutation(context, requested, package, activate_args_for_package(context, requested, package, nil), "pub install failed")
        if not ok then
            tx_failed(context, err)
            return false
        end
    end
    emit_event(context, "installed", requested)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local target = local_path_from_context(context, path)
    if target == "" then
        tx_failed(context, "pub local install path missing")
        return false
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end
    begin_step(context, "install local pub package")
    local requested = request_packages(context, nil)
    local ok, err = run_mutation(context, requested, nil, activate_args_for_package(context, requested, nil, target), "pub local install failed")
    if not ok then
        tx_failed(context, err)
        return false
    end
    emit_event(context, "installed", { path = target, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = request_packages(context, packages)
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end
    begin_step(context, "remove pub packages")
    for _, package in ipairs(requested) do
        local name = package_name(package)
        if name == "" then
            tx_failed(context, "pub package name missing")
            return false
        end
        local ok, err = run_mutation(context, requested, package, { "pub", "global", "deactivate", name }, "pub remove failed")
        if not ok then
            tx_failed(context, err)
            return false
        end
    end
    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = request_packages(context, packages)
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end
    begin_step(context, "update pub packages")
    for _, package in ipairs(requested) do
        local name = package_name(package)
        if name == "" then
            tx_failed(context, "pub package name missing")
            return false
        end
        local ok, err = run_mutation(context, requested, package, activate_args_for_package(context, requested, package, nil), "pub update failed")
        if not ok then
            tx_failed(context, err)
            return false
        end
    end
    emit_event(context, "updated", requested)
    tx_success(context)
    return true
end

function plugin.list(context)
    if not command_exists(context, REQUIRED_BINARY) then
        log_warn(context, REQUIRED_BINARY .. " binary not available")
        emit_event(context, "listed", {})
        return {}
    end
    local items = build_installed_items(context, nil)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    if not command_exists(context, REQUIRED_BINARY) then
        log_warn(context, REQUIRED_BINARY .. " binary not available")
        emit_event(context, "outdated", {})
        return {}
    end
    local items = build_installed_items(context, nil)
    local outdated = {}
    for _, item in ipairs(items) do
        local latest = first_nonempty(item.latestVersion, item.version)
        if latest ~= nil and item.version ~= nil and compare_versions(item.version, latest) < 0 then
            outdated[#outdated + 1] = item
        end
    end
    emit_event(context, "outdated", outdated)
    return outdated
end

function plugin.search(context, prompt)
    local query = trim(prompt)
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end
    local paths = shared_paths(context, nil)
    local names, err = fetch_completion_dataset(context, paths)
    if names == nil then
        log_warn(context, err)
        emit_event(context, "searched", {})
        return {}
    end
    local ranked = ranked_candidates(query, names)
    local results = {}
    local limit = math.min(#ranked, 10)
    for index = 1, limit do
        local item = fetch_remote_item(context, paths, ranked[index].name)
        if item ~= nil then
            results[#results + 1] = item
        end
    end
    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local package_name_value = trim(name or read_field(read_field(context, "request") or {}, "prompt") or "")
    if package_name_value == "" then
        emit_event(context, "informed", {})
        return {}
    end
    local lookup, paths, bin_entries = installed_lookup(context, nil)
    local installed_item = lookup[package_name_value]
    local remote_item = fetch_remote_item(context, paths, package_name_value)
    local item = nil
    if installed_item ~= nil or remote_item ~= nil then
        item = merge_installed_with_remote(installed_item, remote_item, bin_entries)
    else
        item = {}
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end
    local name = package_name(package)
    if name == "" then
        return nil
    end
    local item = plugin.info(context, name)
    if type(item) ~= "table" or next(item) == nil then
        return nil
    end
    local resolved = {
        name = item.name,
        packageId = item.packageId,
        packageType = item.packageType,
        version = package_version(package) ~= "" and package_version(package) or first_nonempty(item.version, item.latestVersion),
        latestVersion = first_nonempty(item.latestVersion, item.version),
        extraFields = shallow_copy(item.extraFields or {}),
    }
    return resolved
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "pub.dev", "dart" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".cache/reqpack/pub" },
        },
        networkScopes = {
            { host = "pub.dev", scheme = "https", pathPrefix = "/" },
            { host = "storage.googleapis.com", scheme = "https", pathPrefix = "/" },
        },
        privilegeLevel = "user",
        osvEcosystem = "Pub",
        purlType = "pub",
    }
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

return plugin
