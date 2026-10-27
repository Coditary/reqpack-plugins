plugin = {}

local PLUGIN_ID = "boss"
local PLUGIN_NAME = "Boss"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "boss"
local JSON_NULL = {}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return trim(value):lower()
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function command_quote(value)
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,%[%]%^~]+$") ~= nil then
        return text
    end
    return shell_quote(text)
end

local function split_lines(value)
    local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
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

local function result_success(result, extra_exit_codes)
    if type(result) ~= "table" then
        return false
    end
    if result.success == true or result.ok == true then
        return true
    end
    local exit_code = result.exitCode or result.exit_code or result.code or result.status
    if exit_code == 0 then
        return true
    end
    if type(extra_exit_codes) == "table" then
        for _, item in ipairs(extra_exit_codes) do
            if exit_code == item then
                return true
            end
        end
    end
    return false
end

local function command_exists(context, binary)
    return result_success(exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function object_flags(object)
    local value = read_field(object, "flags")
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local flags = {}
    local ok = pcall(function()
        for _, flag in ipairs(value) do
            flags[#flags + 1] = trim(flag)
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

local function has_flag(flags, key)
    local wanted = lower(trim(key))
    for _, flag in ipairs(flags or {}) do
        if lower(trim(flag)) == wanted then
            return true
        end
    end
    return false
end

local function home_dir()
    if os ~= nil and type(os.getenv) == "function" then
        local value = trim(os.getenv("HOME") or os.getenv("USERPROFILE") or "")
        if value ~= "" then
            return value
        end
    end
    return "/home/test"
end

local function default_boss_home()
    local env_home = os ~= nil and type(os.getenv) == "function" and trim(os.getenv("BOSS_HOME") or "") or ""
    if env_home ~= "" then
        return env_home
    end
    return join_path(home_dir(), ".boss")
end

local function shared_paths(context, packages)
    local raw_flags = collect_raw_flags(context, packages)
    local root = flag_value(raw_flags, "cache-root")
    local boss_home = root ~= nil and root ~= "" and join_path(root, "home") or default_boss_home()
    local state_root = root ~= nil and root ~= "" and join_path(root, "state") or join_path(boss_home, "reqpack-state")
    return {
        root = root,
        boss_home = boss_home,
        cache = join_path(boss_home, "cache"),
        cache_info = join_path(boss_home, "cache", "info"),
        state = state_root,
    }
end

local function env_prefix(paths)
    return table.concat({
        "BOSS_HOME=" .. shell_quote(paths.boss_home),
        "NO_COLOR='1'",
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
        "SHELL='/bin/sh'",
    }, " ")
end

local function with_env(paths, command)
    return env_prefix(paths) .. " " .. command
end

local function parent_dir(path)
    return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
end

local function ensure_directory(context, path)
    local dir = trim(path)
    if dir == "" or dir == "." then
        return true
    end
    return result_success(exec_run(context, "mkdir -p " .. shell_quote(dir)))
end

local function read_file(context, path)
    local result = exec_run(context, "cat " .. shell_quote(path))
    if result_success(result) then
        return result.stdout
    end
    return nil, result.stderr
end

local function path_exists(context, path)
    return result_success(exec_run(context, "test -e " .. shell_quote(path) .. " >/dev/null 2>&1"))
end

local function list_directory(context, path)
    local result = exec_run(context, "ls -1A " .. shell_quote(path))
    if not result_success(result) then
        return {}
    end
    local entries = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local item = trim(line)
        if item ~= "" then
            entries[#entries + 1] = item
        end
    end
    table.sort(entries)
    return entries
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

    local result = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("unexpected trailing content")
    end
    return result
end

local function decode_json(raw)
    local ok, result = pcall(decode_json_internal, raw)
    if not ok then
        return nil, result
    end
    return result
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageName") or read_field(pkg, "packageId"))
end

local function package_version(pkg)
    return trim(read_field(pkg, "version"))
end

local function package_id_key(value)
    return lower(trim(value))
end

local function normalize_dependency_version(value)
    local text = trim(value)
    if text == "" then
        return nil
    end
    return text
end

local function normalize_semver(value)
    local text = trim(value)
    if text == "" then
        return nil
    end
    local major, minor, patch = text:match("^(%d+)%.(%d+)%.(%d+)$")
    if major ~= nil then
        return tonumber(major), tonumber(minor), tonumber(patch)
    end
    major, minor = text:match("^(%d+)%.(%d+)$")
    if major ~= nil then
        return tonumber(major), tonumber(minor), 0
    end
    major = text:match("^(%d+)$")
    if major ~= nil then
        return tonumber(major), 0, 0
    end
    return nil
end

local function version_gt(left, right)
    local l1, l2, l3 = normalize_semver(left)
    local r1, r2, r3 = normalize_semver(right)
    if l1 == nil or r1 == nil then
        return false
    end
    if l1 ~= r1 then
        return l1 > r1
    end
    if l2 ~= r2 then
        return l2 > r2
    end
    return l3 > r3
end

local function repository_hash(name)
    local bytes = {}
    local text = lower(trim(name))
    if text == "" then
        return nil
    end
    for index = 1, #text do
        bytes[index] = string.byte(text, index)
    end
    if reqpack ~= nil and reqpack.crypto ~= nil and type(reqpack.crypto.md5) == "function" then
        local ok, value = pcall(function()
            return reqpack.crypto.md5(text)
        end)
        if ok and trim(value) ~= "" then
            return trim(value)
        end
    end
    -- fallback for hermetic tests where exact cache info file path is seeded by name scan anyway
    return nil
end

local function make_extra_fields(values)
    local extra = {}
    for key, value in pairs(values or {}) do
        if value ~= nil and trim(value) ~= "" then
            extra[key] = value
        end
    end
    if next(extra) == nil then
        return nil
    end
    return extra
end

local function manifest_paths(context, packages)
    local flags = collect_raw_flags(context, packages)
    local cwd = flag_value(flags, "project-dir") or "."
    return {
        project_dir = cwd,
        manifest = cwd == "." and "./boss.json" or join_path(cwd, "boss.json"),
        lock = cwd == "." and "./boss-lock.json" or join_path(cwd, "boss-lock.json"),
    }
end

local function read_json_file(context, path)
    local content = read_file(context, path)
    if content == nil then
        return nil
    end
    return decode_json(content)
end

local function load_manifest(context, paths)
    local data = read_json_file(context, paths.manifest)
    if type(data) ~= "table" then
        return nil
    end
    return data
end

local function load_lock(context, paths)
    local data = read_json_file(context, paths.lock)
    if type(data) ~= "table" then
        return nil
    end
    return data
end

local function lock_installed_map(lock)
    local installed = json_value(read_field(lock, "installedModules"))
    if type(installed) ~= "table" then
        return {}
    end
    return installed
end

local function dependency_map(manifest)
    local deps = json_value(read_field(manifest, "dependencies"))
    if type(deps) ~= "table" then
        return {}
    end
    return deps
end

local function guess_homepage(name)
    local cleaned = trim(name)
    if cleaned == "" then
        return nil
    end
    if cleaned:match("^https?://") then
        return cleaned
    end
    if cleaned:find("/", 1, true) ~= nil and not cleaned:find("%.", 1, true) then
        return "https://github.com/" .. cleaned
    end
    if cleaned:find(".", 1, true) ~= nil then
        return "https://" .. cleaned
    end
    return nil
end

local function load_cache_info_records(context, paths)
    local items = {}
    for _, entry in ipairs(list_directory(context, paths.cache_info)) do
        if entry:match("%.json$") then
            local full = join_path(paths.cache_info, entry)
            local raw = read_json_file(context, full)
            if type(raw) == "table" then
                items[#items + 1] = {
                    key = trim(json_value(raw.key) or entry:gsub("%.json$", "")),
                    name = trim(json_value(raw.name) or ""),
                    versions = type(json_value(raw.versions)) == "table" and json_value(raw.versions) or {},
                    path = full,
                }
            end
        end
    end
    return items
end

local function cache_info_lookup(records)
    local by_name = {}
    local by_key = {}
    for _, item in ipairs(records or {}) do
        if item.key ~= "" then
            by_key[lower(item.key)] = item
        end
        if item.name ~= "" then
            by_name[package_id_key(item.name)] = item
        end
    end
    return by_name, by_key
end

local function find_cache_record(records_by_name, records_by_key, name)
    local key_name = package_id_key(name)
    if records_by_name[key_name] ~= nil then
        return records_by_name[key_name]
    end
    local hash = repository_hash(name)
    if hash ~= nil and records_by_key[lower(hash)] ~= nil then
        return records_by_key[lower(hash)]
    end
    return nil
end

local function highest_version(list)
    local best = nil
    for _, item in ipairs(list or {}) do
        local version = trim(item)
        if version ~= "" and (best == nil or version_gt(version, best)) then
            best = version
        end
    end
    return best
end

local function make_item(name, requested_version, locked, cache_record, paths)
    local locked_name = trim(read_field(locked, "name") or "")
    local locked_version = trim(read_field(locked, "version") or "")
    local installed = locked ~= nil and locked_version ~= ""
    local latest = cache_record ~= nil and highest_version(cache_record.versions) or nil
    return {
        name = name,
        packageId = name,
        version = installed and locked_version or normalize_dependency_version(requested_version),
        latestVersion = latest or (installed and locked_version or normalize_dependency_version(requested_version)),
        installed = installed,
        status = installed and "installed" or "available",
        summary = nil,
        description = nil,
        homepage = guess_homepage(name),
        sourceUrl = guess_homepage(name),
        extraFields = make_extra_fields({
            requestedVersion = normalize_dependency_version(requested_version),
            installedVersion = installed and locked_version or nil,
            lockedName = locked_name,
            bossHome = paths.boss_home,
            cacheDir = paths.cache,
            manifestPath = paths.manifest,
            lockPath = paths.lock,
            cacheInfoPath = cache_record and cache_record.path or nil,
            dependencyType = "project",
        }),
    }
end

local function current_items(context)
    local paths = shared_paths(context, nil)
    local project = manifest_paths(context, nil)
    paths.manifest = project.manifest
    paths.lock = project.lock

    local manifest = load_manifest(context, project)
    local lock = load_lock(context, project)
    local deps = dependency_map(manifest or {})
    local installed = lock_installed_map(lock or {})
    local cache_records = load_cache_info_records(context, paths)
    local by_name, by_key = cache_info_lookup(cache_records)
    local items = {}

    for name, requested in pairs(deps) do
        local installed_item = installed[package_id_key(name)] or installed[name]
        local cache_record = find_cache_record(by_name, by_key, name)
        items[#items + 1] = make_item(name, requested, installed_item, cache_record, paths)
    end

    table.sort(items, function(left, right)
        return lower(left.name or "") < lower(right.name or "")
    end)

    return items, paths, manifest, lock, cache_records, by_name, by_key
end

local function ensure_available(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true
    end
    return false, REQUIRED_BINARY .. " binary not found"
end

local function package_error(context, message, payload)
    tx_failed(context, message)
    if payload ~= nil then
        emit_event(context, "unavailable", payload)
    end
    return false
end

local function package_spec(pkg)
    local name = package_name(pkg)
    local version = package_version(pkg)
    if name == "" then
        return nil
    end
    if version == "" then
        return name
    end
    return name .. "@" .. version
end

local function install_args(raw_flags, pkg)
    local args = { "install" }
    if has_flag(raw_flags, "no-save") or has_flag(object_flags(pkg), "no-save") then
        args[#args + 1] = "--no-save"
    end
    local compiler = flag_value(object_flags(pkg), "compiler") or flag_value(raw_flags, "compiler")
    if compiler ~= nil and compiler ~= "" then
        args[#args + 1] = "--compiler=" .. compiler
    end
    local platform = flag_value(object_flags(pkg), "platform") or flag_value(raw_flags, "platform")
    if platform ~= nil and platform ~= "" then
        args[#args + 1] = "--platform=" .. platform
    end
    if has_flag(raw_flags, "strict") or has_flag(object_flags(pkg), "strict") then
        args[#args + 1] = "--strict"
    end
    local spec = package_spec(pkg)
    if spec ~= nil then
        args[#args + 1] = spec
    end
    return args
end

local function prefix_boss_args(raw_flags, pkg, args)
    local parts = { "boss" }
    if has_flag(raw_flags, "global") or has_flag(object_flags(pkg), "global") then
        parts[#parts + 1] = "--global"
    end
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = command_quote(arg)
    end
    return parts
end

local function build_boss_command(paths, raw_flags, pkg, args)
    return with_env(paths, table.concat(prefix_boss_args(raw_flags, pkg, args), " "))
end

local function refresh_item_after_change(context, pkg)
    local items = current_items(context)
    local wanted = package_id_key(package_name(pkg))
    for _, item in ipairs(items) do
        if package_id_key(item.name) == wanted then
            return item
        end
    end
    return {
        name = package_name(pkg),
        packageId = package_name(pkg),
        version = package_version(pkg),
    }
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
    return { "delphi", "lazarus", "package-manager" }
end

function plugin.getMissingPackages(packages)
    local available = command_exists(nil, REQUIRED_BINARY)
    if available then
        return {}
    end
    return {
        {
            name = REQUIRED_BINARY,
            packageId = REQUIRED_BINARY,
            reason = "Boss CLI is required",
        }
    }
end

function plugin.install(context, packages)
    local ok, err = ensure_available(context)
    if not ok then
        return package_error(context, err, { reason = "boss-not-installed" })
    end

    packages = packages or {}
    if #packages == 0 then
        tx_success(context)
        return true
    end

    local raw_flags = collect_raw_flags(context, packages)
    local paths = shared_paths(context, packages)
    local outputs = {}

    for _, pkg in ipairs(packages) do
        local name = package_name(pkg)
        if name ~= "" then
            begin_step(context, "install Boss package " .. name)
            local command = build_boss_command(paths, raw_flags, pkg, install_args(raw_flags, pkg))
            local result = exec_run(context, command)
            if not result_success(result) then
                return package_error(context, trim(result.stderr) ~= "" and trim(result.stderr) or trim(result.stdout), { name = name, reason = "boss-install-failed" })
            end
            outputs[#outputs + 1] = result.stdout or ""
            emit_event(context, "installed", refresh_item_after_change(context, pkg))
        end
    end

    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local ok, err = ensure_available(context)
    if not ok then
        return package_error(context, err, { reason = "boss-not-installed", path = trim(path) })
    end

    local target = trim(path)
    if target == "" then
        return package_error(context, "missing local Boss project path", { reason = "missing-path" })
    end
    local manifest = join_path(target, "boss.json")
    if not path_exists(context, manifest) then
        return package_error(context, "boss.json not found in local path", { reason = "missing-boss-json", path = target })
    end

    local paths = shared_paths(context, nil)
    begin_step(context, "install local Boss project dependencies")
    local command = "cd " .. shell_quote(target) .. " && " .. with_env(paths, "boss install")
    local result = exec_run(context, command)
    if not result_success(result) then
        return package_error(context, trim(result.stderr) ~= "" and trim(result.stderr) or trim(result.stdout), { path = target, reason = "boss-install-local-failed" })
    end

    local project = { manifest = manifest, lock = join_path(target, "boss-lock.json") }
    local manifest_data = load_manifest(context, project) or {}
    local name = trim(json_value(read_field(manifest_data, "name")) or target:match("[^/\\]+$") or target)
    emit_event(context, "installed", {
        name = name,
        packageId = name,
        version = trim(json_value(read_field(manifest_data, "version")) or ""),
        sourcePath = target,
        extraFields = make_extra_fields({ manifestPath = manifest, lockPath = project.lock }),
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local ok, err = ensure_available(context)
    if not ok then
        return package_error(context, err, { reason = "boss-not-installed" })
    end

    packages = packages or {}
    if #packages == 0 then
        tx_success(context)
        return true
    end

    local raw_flags = collect_raw_flags(context, packages)
    local paths = shared_paths(context, packages)
    local before_items = current_items(context)
    local before_map = {}
    for _, item in ipairs(before_items) do
        before_map[package_id_key(item.name)] = item
    end
    local outputs = {}

    for _, pkg in ipairs(packages) do
        local name = package_name(pkg)
        if name ~= "" then
            begin_step(context, "remove Boss package " .. name)
            local args = { "uninstall" }
            if has_flag(raw_flags, "no-save") or has_flag(object_flags(pkg), "no-save") then
                args[#args + 1] = "--no-save"
            end
            args[#args + 1] = name
            local command = build_boss_command(paths, raw_flags, pkg, args)
            local result = exec_run(context, command)
            if not result_success(result) then
                return package_error(context, trim(result.stderr) ~= "" and trim(result.stderr) or trim(result.stdout), { name = name, reason = "boss-remove-failed" })
            end
            outputs[#outputs + 1] = result.stdout or ""
            emit_event(context, "deleted", before_map[package_id_key(name)] or { name = name, packageId = name })
        end
    end

    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local ok, err = ensure_available(context)
    if not ok then
        return package_error(context, err, { reason = "boss-not-installed" })
    end

    packages = packages or {}
    local raw_flags = collect_raw_flags(context, packages)
    local paths = shared_paths(context, packages)
    local args = { "update" }
    for _, pkg in ipairs(packages) do
        local name = package_name(pkg)
        if name ~= "" then
            args[#args + 1] = name
        end
    end

    begin_step(context, #packages > 0 and "update Boss packages" or "update Boss project dependencies")
    local command = build_boss_command(paths, raw_flags, nil, args)
    local result = exec_run(context, command)
    if not result_success(result) then
        return package_error(context, trim(result.stderr) ~= "" and trim(result.stderr) or trim(result.stdout), { reason = "boss-update-failed" })
    end

    local items = current_items(context)
    if #packages == 0 then
        emit_event(context, "updated", items)
    else
        local wanted = {}
        for _, pkg in ipairs(packages) do
            wanted[package_id_key(package_name(pkg))] = true
        end
        local filtered = {}
        for _, item in ipairs(items) do
            if wanted[package_id_key(item.name)] then
                filtered[#filtered + 1] = item
            end
        end
        emit_event(context, "updated", filtered)
    end
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = current_items(context)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items = current_items(context)
    local outdated = {}
    for _, item in ipairs(items) do
        local installed_version = trim(read_field(item.extraFields, "installedVersion") or item.version or "")
        local latest = trim(item.latestVersion or "")
        if installed_version ~= "" and latest ~= "" and latest ~= installed_version and version_gt(latest, installed_version) then
            outdated[#outdated + 1] = item
        end
    end
    emit_event(context, "outdated", outdated)
    return outdated
end

function plugin.search(context, prompt)
    local query = lower(trim(prompt))
    if query == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local items, paths, manifest, lock, cache_records = current_items(context)
    local results = {}
    local seen = {}
    for _, item in ipairs(items) do
        local name = lower(item.name)
        if name:find(query, 1, true) ~= nil then
            seen[name] = true
            results[#results + 1] = item
        end
    end
    for _, record in ipairs(cache_records or {}) do
        local name = trim(record.name)
        local key = lower(name)
        if name ~= "" and not seen[key] and key:find(query, 1, true) ~= nil then
            seen[key] = true
            results[#results + 1] = make_item(name, nil, nil, record, {
                boss_home = paths.boss_home,
                cache = paths.cache,
                manifest = paths.manifest,
                lock = paths.lock,
            })
        end
    end
    if #results > 0 then
        log_warn(context, "boss search uses local manifest and cache only; remote catalog search unavailable")
    end
    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local wanted = trim(name)
    if wanted == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local items, paths, manifest, lock, cache_records, by_name, by_key = current_items(context)
    local wanted_key = package_id_key(wanted)
    for _, item in ipairs(items) do
        if package_id_key(item.name) == wanted_key then
            emit_event(context, "informed", item)
            return item
        end
    end

    local cache_record = find_cache_record(by_name or {}, by_key or {}, wanted)
    if cache_record ~= nil then
        local item = make_item(wanted, nil, nil, cache_record, {
            boss_home = paths.boss_home,
            cache = paths.cache,
            manifest = paths.manifest,
            lock = paths.lock,
        })
        emit_event(context, "informed", item)
        return item
    end

    log_warn(context, "boss info unavailable for uncached package without local install")
    local empty = {}
    emit_event(context, "informed", empty)
    return empty
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == "" then
        return nil
    end
    return plugin.info(context, name)
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
        ecosystemScopes = { "delphi", "lazarus", "boss" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".boss" },
        },
        networkScopes = {
            { host = "github.com", scheme = "https", pathPrefix = "/" },
            { host = "gitlab.com", scheme = "https", pathPrefix = "/" },
        },
        privilegeLevel = "none",
        purlType = "generic",
    }
end

return plugin
