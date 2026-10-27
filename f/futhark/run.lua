plugin = {}

local PLUGIN_ID = "futhark"
local PLUGIN_NAME = "Futhark"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "futhark"
local REQUIRED_GIT = "git"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return trim(value):lower()
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function split_lines(value)
    local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
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

local function sequence_values(value)
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local items = {}
    local ok = pcall(function()
        for _, item in ipairs(value) do
            items[#items + 1] = item
        end
    end)
    if not ok then
        return {}
    end
    return items
end

local function list_flags(object)
    local result = {}
    for _, item in ipairs(sequence_values(read_field(object, "flags"))) do
        local cleaned = trim(item)
        if cleaned ~= "" then
            result[#result + 1] = cleaned
        end
    end
    return result
end

local function append_unique(list, seen, value)
    local cleaned = trim(value)
    if cleaned == "" or seen[cleaned] then
        return
    end
    seen[cleaned] = true
    list[#list + 1] = cleaned
end

local function collect_flags(context, packages)
    local result = {}
    local seen = {}
    local function add_from(object)
        for _, flag in ipairs(list_flags(object)) do
            append_unique(result, seen, flag)
        end
    end
    add_from(context)
    add_from(read_field(context, "request"))
    for _, pkg in ipairs(packages or {}) do
        add_from(pkg)
    end
    return result
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

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = trim(select(index, ...) or "")
        if value ~= "" then
            return value
        end
    end
    return nil
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

local function is_success(result)
    return type(result) == "table" and (result.success == true or result.ok == true or result.exitCode == 0)
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

local function command_exists(binary)
    return is_success(exec_run(nil, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function package_name(package)
    return first_nonempty(read_field(package, "name"), read_field(package, "packageId"), read_field(package, "prompt"))
end

local function package_version(package)
    return first_nonempty(read_field(package, "version"), read_field(read_field(package, "extraFields"), "version"))
end

local function project_root(flags)
    return first_nonempty(flag_value(flags, "cwd"), ".")
end

local function cache_root(flags)
    return first_nonempty(flag_value(flags, "cache-root"), join_path(project_root(flags), ".reqpack-data", PLUGIN_ID))
end

local function metadata_dir(flags)
    return join_path(cache_root(flags), "metadata")
end

local function manifest_path(flags)
    return join_path(project_root(flags), "futhark.pkg")
end

local function install_root(flags)
    return join_path(project_root(flags), "lib")
end

local function source_url(name)
    local pkg = trim(name or "")
    local bare = pkg:gsub("@%d+$", "")
    if bare == "" then
        return nil
    end
    return "https://" .. bare
end

local function package_basename(name)
    local cleaned = trim(name)
    if cleaned == "" then
        return ""
    end
    local base = cleaned:match("([^/]+)$") or cleaned
    return trim(base:gsub("@%d+$", ""))
end

local function looks_like_package_path(value)
    local cleaned = trim(value)
    if cleaned == "" then
        return false
    end
    if cleaned:match("^[%w%._%-]+/[%w%._%-]+/[%w%._%-@]+$") ~= nil then
        return true
    end
    if cleaned:match("^[%w%._%-]+://") ~= nil then
        return true
    end
    return false
end

local function utc_timestamp()
    return "1970-01-01T00:00:00Z"
end

local function cache_key(name)
    local cleaned = trim(name)
    if cleaned == "" then
        return nil
    end
    local safe = cleaned:gsub("[^%w%._%-]", "_")
    return safe .. ".json"
end

local function metadata_path(flags, name)
    local key = cache_key(name)
    if key == nil then
        return nil
    end
    return join_path(metadata_dir(flags), key)
end

local function read_text_file(context, path)
    local result = exec_run(context, "cat " .. shell_quote(path))
    if is_success(result) then
        return result.stdout
    end
    return nil
end

local function ensure_directory(context, path)
    return is_success(exec_run(context, "mkdir -p " .. shell_quote(path)))
end

local function write_text_file(context, path, content)
    local dir = parent_dir(path) or "."
    if not ensure_directory(context, dir) then
        return false
    end
    local result = exec_run(context, "printf %s " .. shell_quote(content or "") .. " > " .. shell_quote(path))
    return is_success(result)
end

local function directory_exists(context, path)
    return is_success(exec_run(context, "test -d " .. shell_quote(path)))
end

local function file_exists(context, path)
    return is_success(exec_run(context, "test -f " .. shell_quote(path)))
end

local function split_version(version)
    local major, minor, patch = tostring(version or ""):match("^(%d+)%.(%d+)%.(%d+)$")
    if major == nil then
        return nil
    end
    return { tonumber(major), tonumber(minor), tonumber(patch) }
end

local function compare_versions(left, right)
    local a = split_version(left)
    local b = split_version(right)
    if a == nil and b == nil then
        return trim(left) < trim(right)
    elseif a == nil then
        return true
    elseif b == nil then
        return false
    end
    for i = 1, 3 do
        if a[i] ~= b[i] then
            return a[i] < b[i]
        end
    end
    return false
end

local function max_version(versions)
    local best = nil
    for _, version in ipairs(versions or {}) do
        local cleaned = trim(version)
        if cleaned ~= "" and (best == nil or compare_versions(best, cleaned)) then
            best = cleaned
        end
    end
    return best
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

local function encode_string(value)
    return '"' .. json_escape(value) .. '"'
end

local function json_encode(value)
    local kind = type(value)
    if kind == "nil" then
        return "null"
    elseif kind == "boolean" then
        return value and "true" or "false"
    elseif kind == "number" then
        return tostring(value)
    elseif kind == "string" then
        return encode_string(value)
    elseif kind == "table" then
        local is_array = true
        local count = 0
        for key, _ in pairs(value) do
            count = count + 1
            if type(key) ~= "number" then
                is_array = false
                break
            end
        end
        if is_array then
            for index = 1, count do
                if value[index] == nil then
                    is_array = false
                    break
                end
            end
        end
        local parts = {}
        if is_array then
            for index = 1, #value do
                parts[#parts + 1] = json_encode(value[index])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for key, _ in pairs(value) do
            keys[#keys + 1] = key
        end
        table.sort(keys, function(left, right)
            return tostring(left) < tostring(right)
        end)
        for _, key in ipairs(keys) do
            parts[#parts + 1] = encode_string(key) .. ":" .. json_encode(value[key])
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

local function json_decode(input)
    local source = tostring(input or "")
    local index = 1

    local function peek(offset)
        return source:sub(index + (offset or 0), index + (offset or 0))
    end

    local function advance(count)
        index = index + (count or 1)
    end

    local function skip_whitespace()
        while true do
            local char = peek()
            if char == " " or char == "\n" or char == "\r" or char == "\t" then
                advance(1)
            else
                return
            end
        end
    end

    local parse_value

    local function parse_string()
        advance(1)
        local parts = {}
        while true do
            local char = peek()
            if char == "" then
                error("unterminated string")
            elseif char == '"' then
                advance(1)
                return table.concat(parts)
            elseif char == "\\" then
                local esc = peek(1)
                if esc == '"' or esc == "\\" or esc == "/" then
                    parts[#parts + 1] = esc
                    advance(2)
                elseif esc == "n" then
                    parts[#parts + 1] = "\n"
                    advance(2)
                elseif esc == "r" then
                    parts[#parts + 1] = "\r"
                    advance(2)
                elseif esc == "t" then
                    parts[#parts + 1] = "\t"
                    advance(2)
                else
                    error("unsupported escape")
                end
            else
                parts[#parts + 1] = char
                advance(1)
            end
        end
    end

    local function parse_number()
        local start = index
        if peek() == "-" then
            advance(1)
        end
        while peek():match("%d") do
            advance(1)
        end
        if peek() == "." then
            advance(1)
            while peek():match("%d") do
                advance(1)
            end
        end
        return tonumber(source:sub(start, index - 1))
    end

    local function parse_array()
        advance(1)
        skip_whitespace()
        local result = {}
        if peek() == "]" then
            advance(1)
            return result
        end
        while true do
            result[#result + 1] = parse_value()
            skip_whitespace()
            local char = peek()
            if char == "," then
                advance(1)
                skip_whitespace()
            elseif char == "]" then
                advance(1)
                return result
            else
                error("expected array separator")
            end
        end
    end

    local function parse_object()
        advance(1)
        skip_whitespace()
        local result = {}
        if peek() == "}" then
            advance(1)
            return result
        end
        while true do
            local key = parse_string()
            skip_whitespace()
            if peek() ~= ":" then
                error("expected object colon")
            end
            advance(1)
            skip_whitespace()
            result[key] = parse_value()
            skip_whitespace()
            local char = peek()
            if char == "," then
                advance(1)
                skip_whitespace()
            elseif char == "}" then
                advance(1)
                return result
            else
                error("expected object separator")
            end
        end
    end

    function parse_value()
        skip_whitespace()
        local char = peek()
        if char == '"' then
            return parse_string()
        elseif char == "{" then
            return parse_object()
        elseif char == "[" then
            return parse_array()
        elseif char == "-" or char:match("%d") then
            return parse_number()
        elseif source:sub(index, index + 3) == "true" then
            advance(4)
            return true
        elseif source:sub(index, index + 4) == "false" then
            advance(5)
            return false
        elseif source:sub(index, index + 3) == "null" then
            advance(4)
            return nil
        end
        error("invalid json")
    end

    local ok, value = pcall(parse_value)
    if not ok then
        return nil
    end
    return value
end

local function parse_manifest(stdout)
    local items = {}
    local in_require = false
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned == "" or cleaned:match("^%-%-") then
        elseif cleaned == "require {" then
            in_require = true
        elseif cleaned == "}" then
            in_require = false
        elseif in_require then
            local body = trim(cleaned:gsub("%-%-.*$", ""))
            local name, version, hash = body:match("^(%S+)%s+(%S+)%s+#([%w]+)%s*$")
            if name == nil then
                name, version = body:match("^(%S+)%s+(%S+)%s*$")
            end
            if name ~= nil and version ~= nil then
                items[#items + 1] = {
                    name = name,
                    packageId = name,
                    version = version,
                    packageType = "library",
                    installed = true,
                    status = "installed",
                    extraFields = {
                        hash = hash,
                    },
                }
            end
        end
    end
    table.sort(items, function(left, right)
        return trim(left.name) < trim(right.name)
    end)
    return items
end

local function load_manifest_items(context, flags)
    local text = read_text_file(context, manifest_path(flags))
    if text == nil then
        return {}
    end
    local items = parse_manifest(text)
    for _, item in ipairs(items) do
        local install_path = join_path(install_root(flags), item.name)
        item.extraFields.manifestPath = manifest_path(flags)
        item.extraFields.installPath = directory_exists(context, install_path) and install_path or nil
        item.summary = "Futhark package dependency"
        item.description = "Dependency declared in futhark.pkg"
    end
    return items
end

local function manifest_item_map(context, flags)
    local map = {}
    for _, item in ipairs(load_manifest_items(context, flags)) do
        map[item.name] = item
    end
    return map
end

local function metadata_records_from_cache(context, flags)
    local dir = metadata_dir(flags)
    local list_result = exec_run(context, "ls -1A " .. shell_quote(dir))
    if not is_success(list_result) then
        return {}
    end
    local records = {}
    for _, file in ipairs(split_lines(list_result.stdout)) do
        local path = join_path(dir, trim(file))
        local raw = read_text_file(context, path)
        local metadata = raw ~= nil and json_decode(raw) or nil
        if type(metadata) == "table" then
            metadata.cachePath = metadata.cachePath or path
            records[#records + 1] = metadata
        end
    end
    return records
end

local function parse_versions_from_refs(stdout)
    local versions = {}
    local seen = {}
    for _, line in ipairs(split_lines(stdout)) do
        local ref = trim(line):match("refs/tags/(v[%w%._%-%+]+)$")
        if ref ~= nil then
            local version = ref:match("^v(%d+%.%d+%.%d+)$")
            if version ~= nil and not seen[version] then
                seen[version] = true
                versions[#versions + 1] = version
            end
        end
    end
    table.sort(versions, compare_versions)
    return versions
end

local function load_cached_metadata(context, flags, name)
    local path = metadata_path(flags, name)
    if path == nil then
        return nil
    end
    local raw = read_text_file(context, path)
    if raw == nil then
        return nil
    end
    return json_decode(raw)
end

local function save_cached_metadata(context, flags, metadata)
    local name = trim(read_field(metadata, "name") or "")
    local path = metadata_path(flags, name)
    if path == nil then
        return false
    end
    metadata.cachePath = path
    return write_text_file(context, path, json_encode(metadata))
end

local function refresh_metadata(context, flags, name)
    local url = source_url(name)
    if url == nil or not command_exists(REQUIRED_GIT) then
        return load_cached_metadata(context, flags, name)
    end
    local result = exec_run(context, REQUIRED_GIT .. " ls-remote --tags --refs " .. shell_quote(url))
    if not is_success(result) then
        log_warn(context, "git ls-remote failed for " .. trim(name))
        return load_cached_metadata(context, flags, name)
    end
    local versions = parse_versions_from_refs(result.stdout)
    local metadata = {
        name = trim(name),
        sourceUrl = url,
        versions = versions,
        latestVersion = max_version(versions),
        lastRefreshed = utc_timestamp(),
        versionSource = #versions > 0 and "git-tags" or "none",
        outdatedCheck = #versions > 0 and "supported" or "unsupported-no-tags",
    }
    save_cached_metadata(context, flags, metadata)
    return metadata
end

local function metadata_to_item(context, flags, name, installed_item)
    local metadata = refresh_metadata(context, flags, name) or load_cached_metadata(context, flags, name) or { name = name, versions = {} }
    local install_path = join_path(install_root(flags), name)
    local installed_version = type(installed_item) == "table" and installed_item.version or installed_item
    local manifest_hash = type(installed_item) == "table" and read_field(read_field(installed_item, "extraFields"), "hash") or nil
    local versions = metadata.versions or {}
    local release_count = #versions
    local latest_version = metadata.latestVersion
    local item = {
        name = name,
        packageId = name,
        version = installed_version or latest_version,
        latestVersion = latest_version,
        packageType = "library",
        installed = installed_version ~= nil,
        summary = package_basename(name) ~= "" and ("Futhark package " .. package_basename(name)) or ("Futhark package " .. name),
        description = release_count > 0 and ("Futhark package resolved from git tags with " .. tostring(release_count) .. " known release(s)") or "Futhark package with no tagged releases discovered",
        extraFields = {
            cachePath = metadata.cachePath or metadata_path(flags, name),
            installPath = directory_exists(context, install_path) and install_path or nil,
            manifestPath = manifest_path(flags),
            sourceUrl = metadata.sourceUrl or source_url(name),
            versions = versions,
            latestCommit = metadata.latestCommit,
            manifestHash = manifest_hash,
            installedVersion = installed_version,
            versionSource = metadata.versionSource,
            outdatedCheck = metadata.outdatedCheck,
        },
    }
    return item
end

local function choose_candidate_name(query, manifest_map, cached_metadata)
    local cleaned = trim(query)
    if cleaned == "" then
        return nil
    end
    if manifest_map[cleaned] ~= nil then
        return cleaned
    end
    for name, _ in pairs(manifest_map) do
        if lower(package_basename(name)) == lower(cleaned) then
            return name
        end
    end
    for _, metadata in ipairs(cached_metadata or {}) do
        local name = trim(read_field(metadata, "name") or "")
        if lower(name) == lower(cleaned) or lower(package_basename(name)) == lower(cleaned) then
            return name
        end
    end
    local substring_match = nil
    for name, _ in pairs(manifest_map) do
        local haystack = lower(name .. "\n" .. package_basename(name))
        if haystack:find(lower(cleaned), 1, true) ~= nil then
            if substring_match ~= nil then
                substring_match = nil
                break
            end
            substring_match = name
        end
    end
    if substring_match ~= nil then
        return substring_match
    end
    return looks_like_package_path(cleaned) and cleaned or nil
end

local function package_error(context, message)
    tx_failed(context, message)
    return false
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
    return { "Futhark", "Package Manager", "Language" }
end

function plugin.init()
    return command_exists(REQUIRED_BINARY)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "futhark" },
        writeScopes = {},
        networkScopes = { "https://github.com/" },
        privilegeLevel = "none",
        purlType = "generic",
    }
end

function plugin.getMissingPackages(packages)
    local flags = collect_flags(nil, packages)
    local installed = load_manifest_items(nil, flags)
    local installed_map = {}
    for _, item in ipairs(installed) do
        installed_map[item.name] = item.version or true
    end
    local missing = {}
    for _, package in ipairs(packages or {}) do
        local action = lower(read_field(package, "action") or "install")
        local name = package_name(package)
        local version = package_version(package)
        local current = name ~= nil and installed_map[name] or nil
        if action == "remove" then
            if current ~= nil then
                missing[#missing + 1] = package
            end
        elseif action == "update" then
            missing[#missing + 1] = package
        elseif name ~= nil and (current == nil or (version ~= nil and current ~= version)) then
            missing[#missing + 1] = package
        end
    end
    return missing
end

function plugin.install(context, packages)
    if not command_exists(REQUIRED_BINARY) then
        return package_error(context, "futhark binary not available")
    end
    packages = packages or sequence_values(read_field(read_field(context, "request"), "packages"))
    local flags = collect_flags(context, packages)
    if packages == nil or #packages == 0 then
        begin_step(context, "sync Futhark dependencies")
        local sync_result = exec_run(context, REQUIRED_BINARY .. " pkg sync")
        if not is_success(sync_result) then
            return package_error(context, first_nonempty(sync_result.stderr, sync_result.stdout, "futhark pkg sync failed"))
        end
        emit_event(context, "installed", { manifest = manifest_path(flags) })
        tx_success(context)
        return true
    end
    for _, package in ipairs(packages) do
        local name = package_name(package)
        if name == nil then
            return package_error(context, "install requires package name")
        end
        local version = package_version(package)
        begin_step(context, "add Futhark package " .. name)
        local command = REQUIRED_BINARY .. " pkg add " .. shell_quote(name)
        if version ~= nil then
            command = command .. " " .. shell_quote(version)
        end
        local result = exec_run(context, command)
        if not is_success(result) then
            return package_error(context, first_nonempty(result.stderr, result.stdout, "futhark pkg add failed"))
        end
    end
    begin_step(context, "sync Futhark dependencies")
    local sync_result = exec_run(context, REQUIRED_BINARY .. " pkg sync")
    if not is_success(sync_result) then
        return package_error(context, first_nonempty(sync_result.stderr, sync_result.stdout, "futhark pkg sync failed"))
    end
    emit_event(context, "installed", packages)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local cleaned = trim(path)
    return package_error(context, "installLocal not supported for futhark pkg: " .. cleaned)
end

function plugin.remove(context, packages)
    if not command_exists(REQUIRED_BINARY) then
        return package_error(context, "futhark binary not available")
    end
    packages = packages or {}
    local flags = collect_flags(context, packages)
    for _, package in ipairs(packages) do
        local name = package_name(package)
        if name == nil then
            return package_error(context, "remove requires package name")
        end
        begin_step(context, "remove Futhark package " .. name)
        local result = exec_run(context, REQUIRED_BINARY .. " pkg remove " .. shell_quote(name))
        if not is_success(result) then
            return package_error(context, first_nonempty(result.stderr, result.stdout, "futhark pkg remove failed"))
        end
    end
    begin_step(context, "sync Futhark dependencies")
    local sync_result = exec_run(context, REQUIRED_BINARY .. " pkg sync")
    if not is_success(sync_result) then
        return package_error(context, first_nonempty(sync_result.stderr, sync_result.stdout, "futhark pkg sync failed"))
    end
    emit_event(context, "deleted", packages)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    if not command_exists(REQUIRED_BINARY) then
        return package_error(context, "futhark binary not available")
    end
    local flags = collect_flags(context, packages)
    begin_step(context, "upgrade Futhark dependencies")
    local upgrade_result = exec_run(context, REQUIRED_BINARY .. " pkg upgrade")
    if not is_success(upgrade_result) then
        return package_error(context, first_nonempty(upgrade_result.stderr, upgrade_result.stdout, "futhark pkg upgrade failed"))
    end
    begin_step(context, "sync Futhark dependencies")
    local sync_result = exec_run(context, REQUIRED_BINARY .. " pkg sync")
    if not is_success(sync_result) then
        return package_error(context, first_nonempty(sync_result.stderr, sync_result.stdout, "futhark pkg sync failed"))
    end
    emit_event(context, "updated", packages or { manifest = manifest_path(flags) })
    tx_success(context)
    return true
end

function plugin.list(context)
    local flags = collect_flags(context, nil)
    local items = load_manifest_items(context, flags)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local flags = collect_flags(context, nil)
    local installed = load_manifest_items(context, flags)
    local outdated = {}
    for _, item in ipairs(installed) do
        local enriched = metadata_to_item(context, flags, item.name, item)
        local latest = trim(enriched.latestVersion or "")
        local current = trim(item.version or "")
        local version_source = trim(read_field(enriched.extraFields, "versionSource") or "")
        if latest ~= "" and current ~= "" and current ~= latest then
            enriched.status = "outdated"
            outdated[#outdated + 1] = enriched
        elseif latest == "" or version_source ~= "git-tags" then
            enriched.status = "installed"
            enriched.extraFields.outdatedCheck = read_field(enriched.extraFields, "outdatedCheck") or "unsupported-no-tags"
        end
    end
    emit_event(context, "outdated", outdated)
    return outdated
end

function plugin.search(context, prompt)
    local flags = collect_flags(context, nil)
    local search_prompt = lower(first_nonempty(prompt, read_field(context, "prompt"), read_field(read_field(context, "request"), "prompt")) or "")
    if search_prompt == "" then
        emit_event(context, "searched", {})
        return {}
    end
    local cached_metadata = metadata_records_from_cache(context, flags)
    local manifest_map = manifest_item_map(context, flags)
    local items = {}
    local seen = {}
    local function add_item(item)
        if type(item) ~= "table" then
            return
        end
        local name = trim(read_field(item, "name") or "")
        if name == "" or seen[name] then
            return
        end
        seen[name] = true
        items[#items + 1] = item
    end
    for _, metadata in ipairs(cached_metadata) do
        if type(metadata) == "table" then
            local name = trim(read_field(metadata, "name") or "")
            local haystack = lower(table.concat({
                name,
                package_basename(name),
                trim(read_field(metadata, "sourceUrl") or ""),
                table.concat(read_field(metadata, "versions") or {}, " "),
            }, "\n"))
            if name ~= "" and haystack:find(search_prompt, 1, true) ~= nil then
                add_item(metadata_to_item(context, flags, name, manifest_map[name]))
            end
        end
    end
    for name, manifest_item in pairs(manifest_map) do
        local haystack = lower(table.concat({
            name,
            package_basename(name),
            trim(manifest_item.version or ""),
        }, "\n"))
        if haystack:find(search_prompt, 1, true) ~= nil then
            add_item(metadata_to_item(context, flags, name, manifest_item))
        end
    end
    if #items == 0 and looks_like_package_path(search_prompt) then
        add_item(metadata_to_item(context, flags, search_prompt, manifest_map[search_prompt]))
    end
    table.sort(items, function(left, right)
        return trim(left.name) < trim(right.name)
    end)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local flags = collect_flags(context, nil)
    local query = first_nonempty(name, read_field(context, "prompt"), read_field(read_field(context, "request"), "prompt"), read_field(read_field(context, "request"), "name"))
    if query == nil then
        emit_event(context, "informed", {})
        return {}
    end
    local manifest_map = manifest_item_map(context, flags)
    local cached_metadata = metadata_records_from_cache(context, flags)
    local resolved_name = choose_candidate_name(query, manifest_map, cached_metadata)
    if resolved_name == nil then
        emit_event(context, "informed", {})
        return {}
    end
    local item = metadata_to_item(context, flags, resolved_name, manifest_map[resolved_name])
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local flags = collect_flags(context, { package })
    local name = package_name(package)
    if name == nil then
        return nil
    end
    return metadata_to_item(context, flags, name, {
        name = name,
        version = package_version(package),
        extraFields = read_field(package, "extraFields"),
    })
end

function plugin.shutdown()
end

return plugin
