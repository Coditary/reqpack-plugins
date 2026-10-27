plugin = {}
plugin.fileExtensions = { ".tar.gz", ".tgz", ".zip" }

local PLUGIN_ID = "octave-forge"
local PLUGIN_NAME = "Octave Forge"
local PLUGIN_VERSION = "0.1.0"
local PRIMARY_INDEX_URL = "https://packages.octave.org/packages.json"
local FALLBACK_INDEX_URL = "https://gnu-octave.github.io/packages/packages.json"
local JSON_NULL = {}
local cached_json_decoder = nil

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(trim(value))
end

local function split_lines(value)
    local text = tostring(value or ""):gsub("\r\n", "\n")
    local lines = {}
    if text == "" then
        return lines
    end

    for line in (text .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then
            lines[#lines + 1] = line
        end
    end
    return lines
end

local function split_tabs(line)
    local fields = {}
    for field in (tostring(line or "") .. "\t"):gmatch("(.-)\t") do
        fields[#fields + 1] = field
    end
    return fields
end

local function split_csv(value)
    local items = {}
    for item in tostring(value or ""):gmatch("([^,]+)") do
        local cleaned = trim(item)
        if cleaned ~= "" then
            items[#items + 1] = cleaned
        end
    end
    return items
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
    return table.concat(parts, "/")
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function octave_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
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

local function object_flags(value)
    local raw = read_field(value, "flags")
    if type(raw) ~= "table" and type(raw) ~= "userdata" then
        return {}
    end

    local flags = {}
    local ok = pcall(function()
        for _, item in ipairs(raw) do
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

local function has_flag(flags, name)
    for _, flag in ipairs(flags or {}) do
        if trim(flag) == name then
            return true
        end
    end
    return false
end

local function flag_value(flags, prefix)
    local needle = trim(prefix)
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if cleaned:sub(1, #needle) == needle then
            return trim(cleaned:sub(#needle + 1))
        end
    end
    return ""
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

    if type(result) == "userdata" then
        local normalized = {}
        for _, key in ipairs({ "success", "ok", "exitCode", "exit_code", "code", "status", "stdout", "stdoutText", "stderr", "stderrText" }) do
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

local function failure(context, message)
    tx_failed(context, message)
    return false
end

local function get_plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR)
    if dir ~= "" then
        return dir
    end
    return "."
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageName") or read_field(pkg, "packageId"))
end

local function package_version(pkg)
    return trim(read_field(pkg, "version"))
end

local function package_action(pkg)
    return lower(read_field(pkg, "action") or read_field(pkg, "requestedAction"))
end

local function looks_like_url(value)
    return tostring(value or ""):match("^%a[%w+.-]*://") ~= nil
end

local function parse_name_and_version(value)
    local text = trim(value)
    local name, version = text:match("^([A-Za-z0-9_.-]+)@([^/@][^@]*)$")
    if name ~= nil then
        return name, trim(version)
    end
    return text, ""
end

local function guess_name_and_version_from_path(path)
    local base = trim(path):gsub("^.*[/\\]", "")
    base = base:gsub("%.tar%.gz$", "")
    base = base:gsub("%.tgz$", "")
    base = base:gsub("%.zip$", "")
    local name, version = base:match("^(.+)-([0-9][A-Za-z0-9._-]*)$")
    if name ~= nil then
        return name, version
    end
    return base, ""
end

local function normalize_package(pkg)
    local raw_name = package_name(pkg)
    if raw_name == "" then
        return nil, "missing Octave Forge package name"
    end

    local source = trim(read_field(pkg, "path") or read_field(pkg, "localPath") or read_field(pkg, "source"))
    local flags = object_flags(pkg)
    local local_hint = has_flag(flags, "local")
    local is_local = local_hint or source ~= "" or looks_like_url(raw_name) or raw_name:match("^%.?[/\\]") ~= nil
    if source == "" and is_local then
        source = raw_name
    end

    local name = raw_name
    local inferred_version = package_version(pkg)
    if is_local then
        name, inferred_version = guess_name_and_version_from_path(source ~= "" and source or raw_name)
    else
        name, inferred_version = parse_name_and_version(raw_name)
        if package_version(pkg) ~= "" then
            inferred_version = package_version(pkg)
        end
    end

    return {
        name = trim(name),
        requestedVersion = trim(inferred_version),
        source = source,
        localInstall = is_local,
        raw = pkg,
    }, nil
end

local function combined_flags(context, packages)
    local all = {}
    for _, item in ipairs(context and context.flags or {}) do
        all[#all + 1] = trim(item)
    end
    for _, pkg in ipairs(packages or {}) do
        for _, item in ipairs(object_flags(pkg)) do
            all[#all + 1] = trim(item)
        end
    end
    return all
end

local function refresh_requested(context, packages)
    return has_flag(combined_flags(context, packages), "refresh")
end

local function nodeps_requested(context, packages)
    return has_flag(combined_flags(context, packages), "nodeps")
end

local function verbose_requested(context, packages)
    return has_flag(combined_flags(context, packages), "verbose")
end

local function resolve_scope(context, packages)
    local flags = combined_flags(context, packages)
    local has_local = has_flag(flags, "local")
    local has_global = has_flag(flags, "global")
    if has_local and has_global then
        return nil, "cannot combine local and global flags"
    end
    if has_global then
        return "global"
    end
    return "local"
end

local function data_root_from_context(context, packages)
    local from_context = flag_value(context and context.flags or {}, "data-root=")
    if from_context ~= "" then
        return from_context
    end

    for _, pkg in ipairs(packages or {}) do
        local from_package = flag_value(object_flags(pkg), "data-root=")
        if from_package ~= "" then
            return from_package
        end
    end

    local fixture_root = os ~= nil and type(os.getenv) == "function" and trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT")) or ""
    if fixture_root ~= "" then
        return join_path(fixture_root, ".reqpack-data")
    end

    return join_path(get_plugin_dir(), ".reqpack-data")
end

local function state_paths(root)
    local base = trim(root)
    if base == "" then
        base = join_path(get_plugin_dir(), ".reqpack-data")
    end

    return {
        root = base,
        home = join_path(base, "home"),
        prefix = join_path(base, "prefix"),
        archPrefix = join_path(base, "arch-prefix"),
        localList = join_path(base, "local", "octave_packages"),
        globalList = join_path(base, "global", "octave_packages"),
        cache = join_path(base, "cache"),
        config = join_path(base, "config"),
        tmp = join_path(base, "tmp"),
        indexCache = join_path(base, "cache", "packages.json"),
    }
end

local function detect_octave_binary(context)
    local result = run_exec(context, "command -v 'octave-cli' 2>/dev/null || command -v 'octave' 2>/dev/null")
    if result == nil or result.success ~= true then
        return nil
    end

    local binary = trim(result.stdout)
    if binary == "" then
        return nil
    end
    return binary
end

local function env_prefix(paths)
    return table.concat({
        "HOME=" .. shell_quote(paths.home),
        "XDG_CONFIG_HOME=" .. shell_quote(paths.config),
        "XDG_CACHE_HOME=" .. shell_quote(paths.cache),
        "TMPDIR=" .. shell_quote(paths.tmp),
        "LC_ALL=C",
        "LANG=C",
        "LANGUAGE=C",
        "NO_COLOR=1",
    }, " ")
end

local function driver_script_dir()
    return join_path(get_plugin_dir(), "scripts")
end

local function build_driver_command(binary, paths, extra_env)
    local parts = { env_prefix(paths) }
    for _, item in ipairs(extra_env or {}) do
        parts[#parts + 1] = item
    end
    parts[#parts + 1] = shell_quote(binary)
    parts[#parts + 1] = "--quiet --no-init-file --eval"
    parts[#parts + 1] = shell_quote("addpath(" .. octave_quote(driver_script_dir()) .. "); reqpack_driver()")
    return table.concat(parts, " ")
end

local function mutation_args(context, scope, packages)
    local args = {}
    if scope == "global" then
        args[#args + 1] = "-global"
    else
        args[#args + 1] = "-local"
    end
    if nodeps_requested(context, packages) then
        args[#args + 1] = "-nodeps"
    end
    if verbose_requested(context, packages) then
        args[#args + 1] = "-verbose"
    end
    return args
end

local function mutation_command(context, binary, paths, action, scope, pkg)
    local env = {
        "REQPACK_STATE_ROOT=" .. shell_quote(paths.root),
        "REQPACK_ACTION=" .. shell_quote(action),
        "REQPACK_SCOPE=" .. shell_quote(scope),
        "REQPACK_PACKAGE=" .. shell_quote(pkg.localInstall and pkg.source or pkg.name),
        "REQPACK_LOCAL_INSTALL=" .. shell_quote(pkg.localInstall and "1" or "0"),
        "REQPACK_NODEPS=" .. shell_quote(nodeps_requested(context, { pkg.raw }) and "1" or "0"),
        "REQPACK_VERBOSE=" .. shell_quote(verbose_requested(context, { pkg.raw }) and "1" or "0"),
    }
    return build_driver_command(binary, paths, env)
end

local function parse_list_output(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local fields = split_tabs(line)
        if #fields >= 12 then
            local loaded = lower(fields[4]) == "loaded" or lower(fields[5]) == "true"
            items[#items + 1] = {
                name = fields[2],
                packageId = fields[2],
                version = fields[3],
                latestVersion = fields[3],
                installed = true,
                status = loaded and "loaded" or "installed",
                summary = fields[9],
                description = fields[9],
                homepage = fields[10],
                repository = fields[10],
                dependencies = split_csv(fields[12]),
                packageType = "octave-package",
                extraFields = {
                    scope = fields[1],
                    loaded = loaded,
                    installDir = fields[6],
                    archPrefix = fields[7],
                    date = fields[8],
                    tracker = fields[11],
                },
            }
        end
    end
    return items
end

local function query_installed(context, paths, binary)
    local result = run_exec(context, build_driver_command(binary, paths, {
        "REQPACK_STATE_ROOT=" .. shell_quote(paths.root),
        "REQPACK_ACTION='list'",
    }))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_list_output(result.stdout)
end

local function installed_lookup(items)
    local lookup = {}
    for _, item in ipairs(items or {}) do
        lookup[lower(item.name)] = item
    end
    return lookup
end

local function codepoint_to_utf8(codepoint)
    if codepoint <= 0x7F then
        return string.char(codepoint)
    end
    if codepoint <= 0x7FF then
        return string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + (codepoint % 0x40))
    end
    if codepoint <= 0xFFFF then
        return string.char(0xE0 + math.floor(codepoint / 0x1000), 0x80 + (math.floor(codepoint / 0x40) % 0x40), 0x80 + (codepoint % 0x40))
    end
    return string.char(0xF0 + math.floor(codepoint / 0x40000), 0x80 + (math.floor(codepoint / 0x1000) % 0x40), 0x80 + (math.floor(codepoint / 0x40) % 0x40), 0x80 + (codepoint % 0x40))
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
        local item_index = 1
        while true do
            result[item_index] = parse_value()
            item_index = item_index + 1
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
                decode_error("expected ':' after object key")
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
            return JSON_NULL
        end
        decode_error("unexpected token")
    end

    local value = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("trailing data")
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
    cached_json_decoder = decode_json_internal
    return cached_json_decoder
end

local function decode_json(raw)
    local decoder = load_json_decoder()
    local ok, value, err = pcall(decoder, raw)
    if not ok then
        return nil, trim(value)
    end
    if value == nil then
        return nil, first_nonempty(err, "json decode returned nil")
    end
    return value, nil
end

local function read_cache_text(context, paths)
    local result = run_exec(context, "cat " .. shell_quote(paths.indexCache))
    if result ~= nil then
        local text = tostring(result.stdout or "")
        if text ~= "" then
            return text
        end
    end
    return nil
end

local function ensure_index_cache(context, paths, force_refresh)
    if not force_refresh then
        local cached = read_cache_text(context, paths)
        if cached ~= nil then
            return cached
        end
    end

    local curl_check = run_exec(context, "command -v 'curl' >/dev/null 2>&1")
    if curl_check == nil or curl_check.success ~= true then
        return read_cache_text(context, paths)
    end

    local mkdir_result = run_exec(context, "mkdir -p " .. shell_quote(paths.cache))
    if mkdir_result == nil or mkdir_result.success ~= true then
        return read_cache_text(context, paths)
    end

    local download = run_exec(context, "curl -fsSL " .. shell_quote(PRIMARY_INDEX_URL) .. " -o " .. shell_quote(paths.indexCache))
    if download == nil or download.success ~= true then
        download = run_exec(context, "curl -fsSL " .. shell_quote(FALLBACK_INDEX_URL) .. " -o " .. shell_quote(paths.indexCache))
    end
    if download == nil or download.success ~= true then
        return read_cache_text(context, paths)
    end

    return read_cache_text(context, paths)
end

local function load_index(context, paths, force_refresh)
    local text = ensure_index_cache(context, paths, force_refresh)
    if text == nil then
        return nil, "Octave package index unavailable"
    end
    return decode_json(text)
end

local function index_keys(index)
    local keys = {}
    for key, _ in pairs(index or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function json_to_nil(value)
    if value == JSON_NULL then
        return nil
    end
    return value
end

local function remote_versions(pkg)
    local versions = json_to_nil(read_field(pkg, "versions"))
    if type(versions) == "table" then
        return versions
    end
    return {}
end

local function latest_remote_version(pkg)
    local versions = remote_versions(pkg)
    return json_to_nil(versions[1])
end

local function link_url(pkg, label)
    local links = json_to_nil(read_field(pkg, "links"))
    if type(links) ~= "table" then
        return nil
    end
    for _, link in ipairs(links) do
        if lower(read_field(link, "label")) == lower(label) then
            return json_to_nil(read_field(link, "url"))
        end
    end
    return nil
end

local function homepage_url(pkg)
    for _, label in ipairs({ "package documentation", "function reference", "documentation", "repository" }) do
        local url = link_url(pkg, label)
        if trim(url) ~= "" then
            return url
        end
    end
    return nil
end

local function license_label(pkg)
    local skip = {
        repository = true,
        ["function reference"] = true,
        ["package documentation"] = true,
        documentation = true,
        news = true,
        ["report a problem"] = true,
    }
    local links = json_to_nil(read_field(pkg, "links"))
    if type(links) ~= "table" then
        return nil
    end
    for _, link in ipairs(links) do
        local label = trim(read_field(link, "label"))
        if label ~= "" and skip[lower(label)] ~= true then
            return label
        end
    end
    return nil
end

local function maintainers_list(pkg)
    local maintainers = json_to_nil(read_field(pkg, "maintainers"))
    if type(maintainers) ~= "table" then
        return {}
    end
    local items = {}
    for _, maintainer in ipairs(maintainers) do
        local name = trim(json_to_nil(read_field(maintainer, "name")) or "")
        local contact = trim(json_to_nil(read_field(maintainer, "contact")) or "")
        if name ~= "" and contact ~= "" then
            items[#items + 1] = name .. " <" .. contact .. ">"
        elseif name ~= "" then
            items[#items + 1] = name
        end
    end
    return items
end

local function dependency_list(version)
    local depends = json_to_nil(read_field(version, "depends"))
    if type(depends) ~= "table" then
        return {}
    end
    local items = {}
    for _, item in ipairs(depends) do
        local cleaned = trim(item)
        if cleaned ~= "" then
            items[#items + 1] = cleaned
        end
    end
    return items
end

local function version_tokens(value)
    local tokens = {}
    for token in tostring(value or ""):gmatch("[A-Za-z0-9]+") do
        if token:match("^%d+$") then
            tokens[#tokens + 1] = tonumber(token)
        else
            tokens[#tokens + 1] = lower(token)
        end
    end
    return tokens
end

local function compare_versions(left, right)
    local left_tokens = version_tokens(left)
    local right_tokens = version_tokens(right)
    local count = math.max(#left_tokens, #right_tokens)
    for index = 1, count do
        local a = left_tokens[index]
        local b = right_tokens[index]
        if a == nil and b == nil then
            return 0
        end
        if a == nil then
            if type(b) == "number" and b == 0 then
            else
                return -1
            end
        elseif b == nil then
            if type(a) == "number" and a == 0 then
            else
                return 1
            end
        elseif type(a) == "number" and type(b) == "number" then
            if a < b then
                return -1
            elseif a > b then
                return 1
            end
        else
            local sa = tostring(a)
            local sb = tostring(b)
            if sa < sb then
                return -1
            elseif sa > sb then
                return 1
            end
        end
    end
    return 0
end

local function map_remote_package(key, pkg, installed)
    local latest = latest_remote_version(pkg)
    local name = trim(json_to_nil(read_field(pkg, "name")) or key)
    local item = shallow_copy(installed or {})
    item.name = name
    item.packageId = name
    item.latestVersion = trim(json_to_nil(read_field(latest, "id")) or item.latestVersion or "")
    item.summary = trim(json_to_nil(read_field(pkg, "description")) or item.summary or "")
    item.description = item.summary
    item.license = first_nonempty(item.license, license_label(pkg))
    item.homepage = first_nonempty(item.homepage, homepage_url(pkg))
    item.repository = first_nonempty(item.repository, link_url(pkg, "repository"))
    item.maintainers = maintainers_list(pkg)
    item.dependencies = dependency_list(latest)
    item.packageType = "octave-package"
    item.extraFields = shallow_copy(item.extraFields or {})
    item.extraFields.releaseDate = trim(json_to_nil(read_field(latest, "date")) or item.extraFields.releaseDate or "")
    item.extraFields.downloadUrl = trim(json_to_nil(read_field(latest, "url")) or item.extraFields.downloadUrl or "")
    item.extraFields.sha256 = trim(json_to_nil(read_field(latest, "sha256")) or item.extraFields.sha256 or "")
    if item.installed ~= true then
        item.installed = false
        item.status = "available"
        item.version = item.version or ""
    end
    return item
end

local function action_items_payload(items)
    local payload = {}
    for _, item in ipairs(items or {}) do
        payload[#payload + 1] = {
            name = item.name,
            packageId = item.name,
            version = item.requestedVersion ~= "" and item.requestedVersion or nil,
            packageType = "octave-package",
            localTarget = item.localInstall or nil,
            source = item.localInstall and item.source or nil,
        }
    end
    return payload
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
    return { "GNU Octave", "Package Manager" }
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
        ecosystemScopes = { PLUGIN_ID },
        writeScopes = {},
        networkScopes = { PRIMARY_INDEX_URL, FALLBACK_INDEX_URL },
        privilegeLevel = "none",
    }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end

    local binary = detect_octave_binary(nil)
    if binary == nil then
        local filtered = {}
        for _, pkg in ipairs(requested) do
            local action = package_action(pkg)
            if action ~= "remove" and action ~= "update" then
                filtered[#filtered + 1] = pkg
            end
        end
        return filtered
    end

    local paths = state_paths(data_root_from_context(nil, requested))
    local installed = query_installed(nil, paths, binary)
    if installed == nil then
        return requested
    end

    local installed_map = installed_lookup(installed)
    local outdated_map = {}
    local need_outdated = false
    for _, pkg in ipairs(requested) do
        if package_action(pkg) == "update" then
            need_outdated = true
            break
        end
    end
    if need_outdated then
        local outdated = plugin.outdated({ flags = { "data-root=" .. paths.root } })
        for _, item in ipairs(outdated or {}) do
            outdated_map[lower(item.name)] = true
        end
    end

    local filtered = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg = normalize_package(raw_pkg)
        local action = package_action(raw_pkg)
        local name = pkg and lower(pkg.name) or ""
        if action == "remove" then
            if installed_map[name] ~= nil then
                filtered[#filtered + 1] = raw_pkg
            end
        elseif action == "update" then
            if outdated_map[name] == true then
                filtered[#filtered + 1] = raw_pkg
            end
        elseif installed_map[name] == nil then
            filtered[#filtered + 1] = raw_pkg
        end
    end
    return filtered
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        emit_event(context, "success", "")
        return true
    end

    local binary = detect_octave_binary(context)
    if binary == nil then
        return failure(context, "GNU Octave not installed")
    end

    local scope, scope_error = resolve_scope(context, requested)
    if scope == nil then
        return failure(context, scope_error)
    end

    local normalized = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return failure(context, err)
        end
        if not pkg.localInstall and pkg.requestedVersion ~= "" then
            return failure(context, "Octave Forge remote version pinning is not supported")
        end
        normalized[#normalized + 1] = pkg
    end

    begin_step(context, "install Octave Forge packages")
    local paths = state_paths(data_root_from_context(context, requested))
    for _, pkg in ipairs(normalized) do
        local result = run_exec(context, mutation_command(context, binary, paths, "install", scope, pkg))
        if result == nil or result.success ~= true then
            return failure(context, "Octave Forge install failed")
        end
    end

    emit_event(context, "installed", action_items_payload(normalized))
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.installLocal(context, path)
    local source_path = trim(path or read_field(context, "localPath") or read_field(context, "path"))
    if source_path == "" then
        return failure(context, "missing local Octave Forge package path")
    end

    local binary = detect_octave_binary(context)
    if binary == nil then
        return failure(context, "GNU Octave not installed")
    end

    local scope, scope_error = resolve_scope(context, {})
    if scope == nil then
        return failure(context, scope_error)
    end

    local guessed_name, guessed_version = guess_name_and_version_from_path(source_path)
    local pkg = {
        name = guessed_name,
        requestedVersion = guessed_version,
        source = source_path,
        localInstall = true,
        raw = { name = source_path },
    }

    begin_step(context, "install local Octave Forge package")
    local paths = state_paths(data_root_from_context(context, {}))
    local result = run_exec(context, mutation_command(context, binary, paths, "install", scope, pkg))
    if result == nil or result.success ~= true then
        return failure(context, "Octave Forge local install failed")
    end

    emit_event(context, "installed", action_items_payload({ pkg }))
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        emit_event(context, "success", "")
        return true
    end

    local binary = detect_octave_binary(context)
    if binary == nil then
        return failure(context, "GNU Octave not installed")
    end

    local scope, scope_error = resolve_scope(context, requested)
    if scope == nil then
        return failure(context, scope_error)
    end

    local normalized = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return failure(context, err)
        end
        normalized[#normalized + 1] = pkg
    end

    begin_step(context, "remove Octave Forge packages")
    local paths = state_paths(data_root_from_context(context, requested))
    for _, pkg in ipairs(normalized) do
        local result = run_exec(context, mutation_command(context, binary, paths, "remove", scope, pkg))
        if result == nil or result.success ~= true then
            return failure(context, "Octave Forge remove failed")
        end
    end

    emit_event(context, "deleted", action_items_payload(normalized))
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    local binary = detect_octave_binary(context)
    if binary == nil then
        return failure(context, "GNU Octave not installed")
    end

    local scope, scope_error = resolve_scope(context, requested)
    if scope == nil then
        return failure(context, scope_error)
    end

    local normalized = {}
    if #requested == 0 then
        local installed = query_installed(context, state_paths(data_root_from_context(context, {})), binary) or {}
        for _, item in ipairs(installed) do
            normalized[#normalized + 1] = {
                name = item.name,
                requestedVersion = "",
                source = "",
                localInstall = false,
                raw = { name = item.name },
            }
        end
    else
        for _, raw_pkg in ipairs(requested) do
            local pkg, err = normalize_package(raw_pkg)
            if pkg == nil then
                return failure(context, err)
            end
            if pkg.localInstall then
                return failure(context, "Octave Forge update requires installed package names")
            end
            if pkg.requestedVersion ~= "" then
                return failure(context, "Octave Forge remote version pinning is not supported")
            end
            normalized[#normalized + 1] = pkg
        end
    end

    if #normalized == 0 then
        tx_success(context)
        emit_event(context, "success", "")
        return true
    end

    begin_step(context, "update Octave Forge packages")
    local paths = state_paths(data_root_from_context(context, requested))
    for _, pkg in ipairs(normalized) do
        local result = run_exec(context, mutation_command(context, binary, paths, "update", scope, pkg))
        if result == nil or result.success ~= true then
            return failure(context, "Octave Forge update failed")
        end
    end

    emit_event(context, "updated", action_items_payload(normalized))
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.list(context)
    local binary = detect_octave_binary(context)
    if binary == nil then
        log_warn(context, "GNU Octave not installed")
        emit_event(context, "listed", {})
        return {}
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local items = query_installed(context, paths, binary)
    if items == nil then
        log_warn(context, "Octave Forge list failed")
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local paths = state_paths(data_root_from_context(context, {}))
    local installed = {}
    local binary = detect_octave_binary(context)
    if binary ~= nil then
        installed = query_installed(context, paths, binary) or {}
    end

    local index, err = load_index(context, paths, refresh_requested(context, {}))
    if index == nil then
        if err ~= nil then
            log_warn(context, err)
        end
        emit_event(context, "outdated", {})
        return {}
    end

    local items = {}
    for _, installed_item in ipairs(installed) do
        local pkg = read_field(index, lower(installed_item.name))
        if pkg ~= nil then
            local remote = map_remote_package(lower(installed_item.name), pkg, installed_item)
            if remote.latestVersion ~= "" and compare_versions(remote.latestVersion, installed_item.version) > 0 then
                remote.status = "outdated"
                items[#items + 1] = remote
            end
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned_prompt = trim(prompt)
    if cleaned_prompt == "" and context ~= nil then
        cleaned_prompt = trim(context.prompt)
    end
    if cleaned_prompt == "" then
        emit_event(context, "searched", {})
        return {}
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local index, err = load_index(context, paths, refresh_requested(context, {}))
    if index == nil then
        if err ~= nil then
            log_warn(context, err)
        end
        emit_event(context, "searched", {})
        return {}
    end

    local installed = {}
    local binary = detect_octave_binary(context)
    if binary ~= nil then
        installed = query_installed(context, paths, binary) or {}
    end
    local installed_map = installed_lookup(installed)

    local target = lower(cleaned_prompt)
    local items = {}
    for _, key in ipairs(index_keys(index)) do
        local pkg = read_field(index, key)
        local name = trim(json_to_nil(read_field(pkg, "name")) or key)
        local description = trim(json_to_nil(read_field(pkg, "description")) or "")
        if lower(name):find(target, 1, true) ~= nil or lower(description):find(target, 1, true) ~= nil then
            items[#items + 1] = map_remote_package(key, pkg, installed_map[lower(name)])
        end
    end

    table.sort(items, function(left, right)
        local left_name = lower(left.name)
        local right_name = lower(right.name)
        local left_rank = left_name == target and 0 or (left_name:sub(1, #target) == target and 1 or 2)
        local right_rank = right_name == target and 0 or (right_name:sub(1, #target) == target and 1 or 2)
        if left_rank ~= right_rank then
            return left_rank < right_rank
        end
        return left_name < right_name
    end)
    while #items > 50 do
        items[#items] = nil
    end

    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local cleaned_name = trim(name)
    if cleaned_name == "" and context ~= nil then
        cleaned_name = trim(context.prompt)
    end
    if cleaned_name == "" then
        emit_event(context, "informed", {})
        return {}
    end

    local resolved_name = parse_name_and_version(cleaned_name)
    local paths = state_paths(data_root_from_context(context, {}))
    local installed_item = nil
    local binary = detect_octave_binary(context)
    if binary ~= nil then
        local installed = query_installed(context, paths, binary) or {}
        installed_item = installed_lookup(installed)[lower(resolved_name)]
    end

    local index = nil
    local item = installed_item and shallow_copy(installed_item) or {}
    index = select(1, load_index(context, paths, refresh_requested(context, {})))
    if index ~= nil then
        local pkg = read_field(index, lower(resolved_name))
        if pkg ~= nil then
            item = map_remote_package(lower(resolved_name), pkg, installed_item)
        end
    end

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end

    local pkg, err = normalize_package(package)
    if pkg == nil then
        return nil, err
    end

    if pkg.localInstall then
        return {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.requestedVersion ~= "" and pkg.requestedVersion or nil,
            packageType = "octave-package",
            extraFields = {
                localTarget = true,
                source = pkg.source,
            },
        }
    end

    local item = plugin.info({
        flags = combined_flags(context, { package }),
        prompt = pkg.name,
        exec = context and context.exec or nil,
        events = {},
        tx = {},
        log = {},
    }, pkg.name)
    if item == nil or next(item) == nil then
        return {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.requestedVersion ~= "" and pkg.requestedVersion or nil,
            packageType = "octave-package",
        }
    end
    if pkg.requestedVersion ~= "" and trim(item.version or "") == "" then
        item.version = pkg.requestedVersion
    end
    return item
end

return plugin
