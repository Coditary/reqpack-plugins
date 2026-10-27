plugin = {}

local PLUGIN_ID = "spago"
local PLUGIN_NAME = "Spago"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "spago"
local JSON_NULL = {}

local cached_json_decoder = nil

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
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

local function split_lines(value)
    local lines = {}
    for line in tostring(value or ""):gmatch("[^\r\n]+") do
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

local function merge_extra_fields(existing, additions)
    local merged = shallow_copy(type(existing) == "table" and existing or {})
    for key, value in pairs(additions or {}) do
        merged[key] = value
    end
    if next(merged) == nil then
        return nil
    end
    return merged
end

local function json_value(value)
    if value == JSON_NULL then
        return nil
    end
    return value
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

local function as_string_array(value)
    local items = {}
    if type(value) ~= "table" then
        return items
    end

    for _, item in ipairs(value) do
        local text = first_nonempty(item)
        if text ~= nil then
            items[#items + 1] = tostring(text)
        end
    end
    return items
end

local function sorted_keys(value)
    local keys = {}
    for key in pairs(value or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)
    return keys
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

local function call_logger(context, level, message)
    if context == nil or context.log == nil then
        return
    end

    local fn = context.log[level]
    if type(fn) == "function" then
        fn(message)
    end
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

local function command_exists(context, binary)
    local exec_runner = make_exec_runner(context)
    local result = exec_runner("command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function build_command(parts)
    local args = {}
    for _, part in ipairs(parts or {}) do
        args[#args + 1] = shell_arg(part)
    end
    return table.concat(args, " ")
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
        end
        current = peek()
        if current == "0" then
            index = index + 1
        elseif current:match("%d") ~= nil then
            while peek():match("%d") ~= nil do
                index = index + 1
            end
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
        function()
            local ok, module = pcall(require, "json")
            if ok and module ~= nil then
                local decode = module.decode or module.Decode
                if type(decode) == "function" then
                    return function(raw)
                        return normalize_json_tree(decode(raw), module.null)
                    end
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

local function run_json_command(context, parts)
    local exec_runner = make_exec_runner(context)
    local command = build_command(parts)
    local result = exec_runner(command)
    if result == nil then
        return nil, "command failed", command, nil
    end
    if not result.success then
        return nil, first_nonempty(result.stderr, result.stdout, "command failed"), command, result
    end

    local decoded, err = decode_json(result.stdout)
    if decoded == nil then
        return nil, first_nonempty(err, "failed to decode JSON"), command, result
    end
    return decoded, nil, command, result
end

local function package_name_from_request(pkg)
    return first_nonempty(read_field(pkg, "name"), read_field(pkg, "packageId"), read_field(pkg, "packageName"))
end

local function package_version_from_request(pkg)
    return first_nonempty(read_field(pkg, "version"), read_field(pkg, "latestVersion"))
end

local function compiler_list_string(value)
    local items = as_string_array(value)
    if #items == 0 then
        return nil
    end
    return table.concat(items, ",")
end

local function extract_location_urls(location)
    if type(location) ~= "table" then
        return nil, nil
    end

    local repository = first_nonempty(read_field(location, "url"))
    if repository ~= nil then
        return repository, repository
    end

    local owner = first_nonempty(read_field(location, "githubOwner"))
    local repo = first_nonempty(read_field(location, "githubRepo"))
    if owner ~= nil and repo ~= nil then
        local url = "https://github.com/" .. owner .. "/" .. repo
        return url, url
    end

    return nil, nil
end

local function highest_version_key(map)
    local keys = sorted_keys(map)
    return keys[#keys]
end

local function latest_published_entry(metadata)
    local published = json_value(read_field(metadata, "published"))
    if type(published) ~= "table" then
        return nil, nil
    end

    local version = highest_version_key(published)
    if version == nil then
        return nil, nil
    end
    return version, json_value(published[version])
end

local function package_sets_for_version(package_sets_payload, version)
    if type(package_sets_payload) ~= "table" or trim(version) == "" then
        return nil
    end

    local matches = {}
    for _, item in ipairs(package_sets_payload) do
        if type(item) == "table" then
            local set_version = first_nonempty(read_field(item, "version"))
            local packages = json_value(read_field(item, "packages"))
            if set_version ~= nil and type(packages) == "table" then
                for package_name, package_version in pairs(packages) do
                    if trim(package_name) ~= "" and trim(package_version) == trim(version) then
                        matches[#matches + 1] = tostring(set_version)
                    end
                end
            end
        end
    end

    if #matches == 0 then
        return nil
    end
    table.sort(matches)
    return table.concat(matches, ",")
end

local function map_metadata_to_package_info(name, metadata, options)
    options = options or {}
    local location = json_value(read_field(metadata, "location"))
    local repository, homepage = extract_location_urls(location)
    local version, published = latest_published_entry(metadata)
    local package_sets = package_sets_for_version(options.packageSets, version)
    local path_info = type(options.paths) == "table" and options.paths or nil

    local item = {
        name = name,
        packageId = name,
        version = version,
        latestVersion = version,
        installed = options.installed == true,
        status = options.status or (options.installed == true and "installed" or "available"),
        summary = first_nonempty(options.summary, "PureScript package"),
        description = first_nonempty(options.description, "PureScript package metadata from Spago Registry"),
        homepage = homepage,
        repository = repository,
        packageType = options.packageType or "registry-package",
        type = "package",
        extraFields = nil,
    }

    local extra = {}
    if published ~= nil then
        local published_time = first_nonempty(read_field(published, "publishedTime"))
        local compilers = compiler_list_string(read_field(published, "compilers"))
        local ref = first_nonempty(read_field(published, "ref"))
        local hash = first_nonempty(read_field(published, "hash"))
        if published_time ~= nil then
            extra.publishedAt = published_time
        end
        if compilers ~= nil then
            extra.compilerRange = compilers
        end
        if ref ~= nil then
            extra.sourceRef = ref
        end
        if hash ~= nil then
            extra.integrity = hash
        end
    end

    local published_versions = json_value(read_field(metadata, "published"))
    if type(published_versions) == "table" then
        extra.registryVersions = table.concat(sorted_keys(published_versions), ",")
    end
    if package_sets ~= nil then
        extra.packageSets = package_sets
    end
    if path_info ~= nil then
        extra.globalCachePath = first_nonempty(read_field(path_info, "Global cache path"))
        extra.globalRegistryPath = first_nonempty(read_field(path_info, "Global registry path"))
        extra.localCachePath = first_nonempty(read_field(path_info, "Local cache path"))
        extra.localCachePackagesPath = first_nonempty(read_field(path_info, "Local cache packages path"))
    end

    item.extraFields = next(extra) ~= nil and extra or nil
    return item
end

local function package_type_and_location(entry)
    local package_type = first_nonempty(read_field(entry, "type"))
    local value = json_value(read_field(entry, "value"))

    if package_type == "registry" then
        local version = first_nonempty(type(value) == "table" and read_field(value, "version") or value)
        return "registry-package", version, nil
    end
    if package_type == "git" then
        return "git-package", first_nonempty(type(value) == "table" and read_field(value, "ref")), type(value) == "table" and read_field(value, "git") or nil
    end
    if package_type == "local" then
        return "local-package", "local", type(value) == "table" and read_field(value, "path") or nil
    end
    if package_type == "workspace" then
        return "workspace-package", "workspace", type(value) == "table" and read_field(value, "path") or nil
    end

    return first_nonempty(package_type, "package"), nil, nil
end

local function map_ls_entry_to_package_info(name, entry, paths)
    local package_type, version, location = package_type_and_location(entry)
    local item = {
        name = name,
        packageId = name,
        version = version,
        latestVersion = version,
        installed = true,
        status = "installed",
        summary = first_nonempty(name .. " dependency"),
        description = "Spago workspace dependency",
        repository = location,
        packageType = package_type,
        type = "package",
        extraFields = nil,
    }

    local extra = {}
    if type(paths) == "table" then
        extra.globalCachePath = first_nonempty(read_field(paths, "Global cache path"))
        extra.globalRegistryPath = first_nonempty(read_field(paths, "Global registry path"))
        extra.localCachePath = first_nonempty(read_field(paths, "Local cache path"))
        extra.localCachePackagesPath = first_nonempty(read_field(paths, "Local cache packages path"))
    end
    if location ~= nil then
        extra.location = location
    end
    item.extraFields = next(extra) ~= nil and extra or nil
    return item
end

local function decode_map_entries(decoded)
    local items = {}
    if type(decoded) ~= "table" then
        return items
    end
    for _, key in ipairs(sorted_keys(decoded)) do
        items[#items + 1] = { name = tostring(key), value = decoded[key] }
    end
    return items
end

local function get_paths(context)
    local decoded = select(1, run_json_command(context, { REQUIRED_BINARY, "ls", "paths", "--json" }))
    if type(decoded) == "table" then
        return decoded
    end
    return nil
end

local function get_dependency_entries(context)
    local decoded, err = run_json_command(context, { REQUIRED_BINARY, "ls", "deps", "--json", "--transitive" })
    if decoded ~= nil then
        return decode_map_entries(decoded), nil
    end

    decoded = select(1, run_json_command(context, { REQUIRED_BINARY, "ls", "packages", "--json" }))
    if decoded ~= nil then
        return decode_map_entries(decoded), nil
    end

    return {}, err
end

local function registry_search(context, prompt)
    local decoded, err = run_json_command(context, { REQUIRED_BINARY, "registry", "search", "--json", prompt })
    if decoded == nil then
        return {}, err
    end

    local items = {}
    for _, entry in ipairs(decode_map_entries(decoded)) do
        local name = entry.name
        local value = json_value(entry.value)
        local version = first_nonempty(type(value) == "table" and read_field(value, "version") or nil)
        local published = first_nonempty(type(value) == "table" and read_field(value, "publishedTime") or nil)
        items[#items + 1] = {
            name = name,
            packageId = name,
            version = version,
            latestVersion = version,
            installed = false,
            status = "available",
            summary = "PureScript registry package",
            description = "PureScript registry package",
            packageType = "registry-package",
            type = "package",
            extraFields = published ~= nil and { publishedAt = published } or nil,
        }
    end
    return items, nil
end

local function registry_info(context, name)
    local decoded, err = run_json_command(context, { REQUIRED_BINARY, "registry", "info", "--json", name })
    if decoded == nil then
        return nil, err
    end

    local paths = get_paths(context)
    local package_sets = select(1, run_json_command(context, { REQUIRED_BINARY, "registry", "package-sets", "--json" }))
    return map_metadata_to_package_info(name, decoded, {
        installed = false,
        status = "available",
        summary = "PureScript registry package",
        description = "PureScript package metadata from Spago Registry",
        packageType = "registry-package",
        paths = paths,
        packageSets = package_sets,
    }), nil
end

local function request_action(pkg)
    return lower(first_nonempty(read_field(pkg, "action"), "install"))
end

local function missing_due_to_action(pkg, installed_lookup)
    local name = package_name_from_request(pkg)
    local version = package_version_from_request(pkg)
    local action = request_action(pkg)
    local installed = installed_lookup[name]
    if action == "remove" then
        return installed ~= nil
    end
    if action == "update" then
        return true
    end
    if installed == nil then
        return true
    end
    if version ~= nil and trim(installed.version) ~= trim(version) then
        return true
    end
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
    return { "PureScript", "Package Manager", "Wrapper" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end

    if not command_exists(nil, REQUIRED_BINARY) then
        local missing = {}
        for _, pkg in ipairs(requested) do
            local action = request_action(pkg)
            if action ~= "remove" then
                missing[#missing + 1] = pkg
            end
        end
        return missing
    end

    local entries = select(1, get_dependency_entries(nil))
    local installed_lookup = {}
    for _, entry in ipairs(entries) do
        installed_lookup[entry.name] = map_ls_entry_to_package_info(entry.name, entry.value)
    end

    local missing = {}
    for _, pkg in ipairs(requested) do
        if missing_due_to_action(pkg, installed_lookup) then
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
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "spago not installed")
        emit_event(context, "unavailable", { reason = "spago-not-installed" })
        return false
    end

    local parts = { REQUIRED_BINARY, "install" }
    for _, pkg in ipairs(requested) do
        local name = package_name_from_request(pkg)
        if name ~= nil then
            parts[#parts + 1] = name
        end
    end

    begin_step(context, "install spago dependencies")
    local result = make_exec_runner(context)(build_command(parts))
    if result == nil or not result.success then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "spago install failed"))
        return false
    end

    emit_event(context, "installed", requested)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    begin_step(context, "install local spago artifact")
    tx_failed(context, "spago local installs are not supported")
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
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "spago not installed")
        emit_event(context, "unavailable", { reason = "spago-not-installed" })
        return false
    end

    local parts = { REQUIRED_BINARY, "uninstall" }
    for _, pkg in ipairs(requested) do
        local name = package_name_from_request(pkg)
        if name ~= nil then
            parts[#parts + 1] = name
        end
    end

    begin_step(context, "remove spago dependencies")
    local result = make_exec_runner(context)(build_command(parts))
    if result == nil or not result.success then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "spago uninstall failed"))
        return false
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "spago not installed")
        emit_event(context, "unavailable", { reason = "spago-not-installed" })
        return false
    end

    begin_step(context, "upgrade spago workspace")
    local result = make_exec_runner(context)(build_command({ REQUIRED_BINARY, "upgrade" }))
    if result == nil or not result.success then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "spago upgrade failed"))
        return false
    end

    emit_event(context, "updated", packages or {})
    tx_success(context)
    return true
end

function plugin.list(context)
    if not command_exists(context, REQUIRED_BINARY) then
        emit_event(context, "unavailable", { reason = "spago-not-installed" })
        return {}
    end

    local paths = get_paths(context)
    local entries, err = get_dependency_entries(context)
    if err ~= nil and #entries == 0 then
        call_logger(context, "warn", err)
    end

    local items = {}
    for _, entry in ipairs(entries) do
        items[#items + 1] = map_ls_entry_to_package_info(entry.name, entry.value, paths)
    end
    table.sort(items, function(left, right)
        return trim(left.name) < trim(right.name)
    end)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items = {}
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local search_prompt = trim(prompt)
    if search_prompt == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    if not command_exists(context, REQUIRED_BINARY) then
        emit_event(context, "unavailable", { reason = "spago-not-installed" })
        return {}
    end

    local items, err = registry_search(context, search_prompt)
    if err ~= nil then
        call_logger(context, "warn", err)
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local package_name = trim(name)
    if package_name == "" then
        emit_event(context, "unavailable", { reason = "missing-package-name" })
        return {}
    end
    if not command_exists(context, REQUIRED_BINARY) then
        emit_event(context, "unavailable", { reason = "spago-not-installed" })
        return {}
    end

    local item, err = registry_info(context, package_name)
    if item == nil then
        emit_event(context, "unavailable", {
            name = package_name,
            reason = err,
        })
        return {}
    end

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local name = package_name_from_request(package)
    if name == nil then
        return nil
    end

    local item = plugin.info(context, name)
    if type(item) ~= "table" or next(item) == nil then
        return nil
    end

    local resolved = shallow_copy(package)
    for key, value in pairs(item) do
        resolved[key] = value
    end
    resolved.extraFields = merge_extra_fields(read_field(package, "extraFields"), item.extraFields)
    return resolved
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "purescript", "spago" },
        writeScopes = {
            { kind = "project-subpath", value = ".spago" },
            { kind = "project-subpath", value = "spago.lock" },
            { kind = "project-subpath", value = "spago.yaml" },
            { kind = "user-home-subpath", value = ".cache/spago-nodejs" },
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
