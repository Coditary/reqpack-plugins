plugin = {}

local PLUGIN_ID = "yarn"
local PLUGIN_NAME = "Yarn"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "yarn"
local SEARCH_LIMIT = 20
local JSON_NULL = {}
local cached_json_decoder = nil

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
        table.insert(lines, line)
    end
    return lines
end

local function shell_quote(value)
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,]+$") then
        return text
    end
    return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function starts_with(value, prefix)
    local text = tostring(value or "")
    local expected = tostring(prefix or "")
    return text:sub(1, #expected) == expected
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

local function run_exec(context, command)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return context.exec.run(command)
    end

    if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
        return reqpack.exec.run(command)
    end

    return {
        success = false,
        stdout = "",
        stderr = "missing ReqPack exec runner",
        exitCode = 127,
    }
end

local function command_exists(binary)
    local result = run_exec(nil, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
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

local function nonempty(value)
    local text = trim(value)
    if text == "" then
        return nil
    end
    return text
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageName") or read_field(pkg, "packageId"))
end

local function package_version(pkg)
    return trim(read_field(pkg, "version"))
end

local function package_id_with_version(pkg)
    local name = package_name(pkg)
    local version = package_version(pkg)
    if name == "" then
        return nil
    end
    if version ~= "" and not starts_with(version, "^") and not starts_with(version, "~") then
        return name .. "@" .. version
    end
    return name
end

local function sort_items_by_name(items)
    table.sort(items, function(left, right)
        return lower(left.name or left.packageId or "") < lower(right.name or right.packageId or "")
    end)
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
        decode_error("trailing content")
    end
    return value
end

local function decode_json(raw)
    if cached_json_decoder == nil then
        cached_json_decoder = decode_json_internal
    end

    local ok, value = pcall(cached_json_decoder, raw)
    if not ok then
        return nil, value
    end
    return value
end

local function runtime_state(context)
    local state = {
        available = command_exists(REQUIRED_BINARY),
        version = nil,
        major = nil,
        isClassic = false,
        globalDir = nil,
        binDir = nil,
        cacheDir = nil,
    }

    if state.available then
        local version_result = run_exec(context, REQUIRED_BINARY .. " --version")
        state.version = trim(version_result and version_result.stdout)
        state.major = tonumber((state.version or ""):match("^(%d+)"))
        state.isClassic = state.major == 1

        local global_dir_result = run_exec(context, REQUIRED_BINARY .. " global dir")
        if global_dir_result ~= nil and global_dir_result.success == true then
            state.globalDir = nonempty(global_dir_result.stdout)
        end

        local bin_dir_result = run_exec(context, REQUIRED_BINARY .. " global bin")
        if bin_dir_result ~= nil and bin_dir_result.success == true then
            state.binDir = nonempty(bin_dir_result.stdout)
        end

        local cache_dir_result = run_exec(context, REQUIRED_BINARY .. " cache dir")
        if cache_dir_result ~= nil and cache_dir_result.success == true then
            state.cacheDir = nonempty(cache_dir_result.stdout)
        end
    end

    return state
end

local function require_classic_for_write(context)
    local state = runtime_state(context)
    if not state.available then
        tx_failed(context, "yarn binary not available")
        return nil
    end
    if state.isClassic then
        return state
    end

    tx_failed(context, "ReqPack yarn plugin currently supports Yarn Classic 1.x for install/remove/update actions")
    return nil
end

local function package_request_string(pkg)
    local name = package_name(pkg)
    local version = package_version(pkg)
    if name == "" then
        return nil
    end
    if version ~= "" then
        return name .. "@" .. version
    end
    return name
end

local function manifest_path(global_dir)
    local root = trim(global_dir)
    if root == "" then
        return nil
    end
    return root .. "/package.json"
end

local function parse_manifest_dependencies(raw)
    local decoded, decode_error = decode_json(raw)
    if decoded == nil then
        return {}, decode_error
    end

    local deps = read_field(decoded, "dependencies")
    if type(deps) ~= "table" then
        return {}, nil
    end

    local result = {}
    for name, range in pairs(deps) do
        local cleaned_name = trim(name)
        if cleaned_name ~= "" then
            result[cleaned_name] = trim(range)
        end
    end
    return result, nil
end

local function parse_json_lines(raw)
    local entries = {}
    for _, line in ipairs(split_lines(raw)) do
        local text = trim(line)
        if text ~= "" and starts_with(text, "{") then
            local decoded = select(1, decode_json(text))
            if decoded ~= nil then
                entries[#entries + 1] = decoded
            end
        end
    end
    return entries
end

local function parse_installed_spec(text)
    local cleaned = trim(text)
    local name, version = cleaned:match('^([^@%s]+)@(.+)$')
    if name == nil then
        return nil, nil
    end
    return trim(name), trim(version)
end

local function parse_global_list_versions(raw)
    local installed = {}

    for _, entry in ipairs(parse_json_lines(raw)) do
        local entry_type = trim(read_field(entry, "type"))
        local data = read_field(entry, "data")
        if entry_type == "info" and type(data) == "string" then
            local name, version = parse_installed_spec(data:match('"([^"]+)"') or "")
            if name ~= nil and version ~= nil then
                installed[name] = {
                    version = version,
                    bin = trim(data:match("has binaries:%s*(.*)$")),
                }
            end
        end
    end

    return installed
end

local function path_fields(context)
    local state = runtime_state(context)
    return {
        globalDir = state.globalDir,
        binDir = state.binDir,
        cacheDir = state.cacheDir,
    }
end

local function merge_extra_fields(base, additions)
    local merged = {}
    for key, value in pairs(base or {}) do
        merged[key] = value
    end
    for key, value in pairs(additions or {}) do
        if value ~= nil then
            merged[key] = value
        end
    end
    if next(merged) == nil then
        return nil
    end
    return merged
end

local function list_installed_items(context)
    local state = runtime_state(context)
    local requested = {}
    local manifest = manifest_path(state.globalDir)
    if manifest ~= nil then
        local raw = read_file(manifest)
        if raw ~= nil then
            requested = select(1, parse_manifest_dependencies(raw)) or {}
        end
    end

    local installed_versions = {}
    if state.available and state.isClassic then
        local list_result = run_exec(context, REQUIRED_BINARY .. " global list --depth=0 --json")
        if list_result ~= nil and trim(list_result.stdout) ~= "" then
            installed_versions = parse_global_list_versions(list_result.stdout)
        end
    end

    local names = {}
    for name in pairs(requested) do
        names[name] = true
    end
    for name in pairs(installed_versions) do
        names[name] = true
    end

    local items = {}
    local common = path_fields(context)
    for name in pairs(names) do
        local requested_range = nonempty(requested[name])
        local installed_info = installed_versions[name] or {}
        items[#items + 1] = {
            name = name,
            packageId = name,
            version = nonempty(installed_info.version) or requested_range,
            latestVersion = nonempty(installed_info.version) or requested_range,
            installed = true,
            status = "installed",
            type = "package",
            packageType = "package",
            extraFields = merge_extra_fields(common, {
                requestedRange = requested_range,
                binaries = nonempty(installed_info.bin),
            }),
        }
    end

    sort_items_by_name(items)
    return items
end

local function installed_item_map(context)
    local mapped = {}
    for _, item in ipairs(list_installed_items(context)) do
        mapped[item.packageId] = item
    end
    return mapped
end

local function parse_outdated_items(raw, context)
    for _, entry in ipairs(parse_json_lines(raw)) do
        if trim(read_field(entry, "type")) == "table" then
            local data = read_field(entry, "data")
            local body = read_field(data, "body")
            if type(body) ~= "table" then
                return {}
            end

            local items = {}
            for _, row in ipairs(body) do
                local name = trim(read_field(row, 1))
                if name ~= "" then
                    items[#items + 1] = {
                        name = name,
                        packageId = name,
                        version = trim(read_field(row, 2)),
                        latestVersion = trim(read_field(row, 4)),
                        status = "outdated",
                        installed = true,
                        type = "package",
                        packageType = "package",
                        homepage = nonempty(read_field(row, 6)),
                        extraFields = merge_extra_fields(path_fields(context), {
                            wantedVersion = nonempty(read_field(row, 3)),
                            dependencyType = nonempty(read_field(row, 5)),
                        }),
                    }
                end
            end
            sort_items_by_name(items)
            return items
        end
    end
    return {}
end

local function build_curl_search_command(prompt)
    local encoded = tostring(prompt or "")
        :gsub("%%", "%%25")
        :gsub(" ", "%%20")
        :gsub('"', "%%22")
        :gsub("#", "%%23")
        :gsub("%+", "%%2B")
        :gsub("&", "%%26")
        :gsub("/", "%%2F")
        :gsub("%?", "%%3F")
    return "curl -fsSL " .. shell_quote("https://registry.npmjs.org/-/v1/search?text=" .. encoded .. "&size=" .. tostring(SEARCH_LIMIT))
end

local function parse_search_items(raw, context)
    local decoded, decode_error = decode_json(raw)
    if decoded == nil then
        return {}, decode_error
    end

    local objects = read_field(decoded, "objects")
    if type(objects) ~= "table" then
        return {}, nil
    end

    local items = {}
    local common = path_fields(context)
    for _, entry in ipairs(objects) do
        local package = read_field(entry, "package")
        local name = trim(read_field(package, "name"))
        if name ~= "" then
            items[#items + 1] = {
                name = name,
                packageId = name,
                version = trim(read_field(package, "version")),
                latestVersion = trim(read_field(package, "version")),
                summary = trim(read_field(package, "description")),
                description = trim(read_field(package, "description")),
                homepage = nonempty(read_field(package, "links") and read_field(read_field(package, "links"), "homepage")),
                repository = nonempty(read_field(package, "links") and read_field(read_field(package, "links"), "repository")),
                sourceUrl = nonempty(read_field(package, "links") and read_field(read_field(package, "links"), "npm")),
                type = "package",
                packageType = "package",
                extraFields = merge_extra_fields(common, {
                    keywords = type(read_field(package, "keywords")) == "table" and table.concat(read_field(package, "keywords"), ",") or nil,
                    score = tostring(read_field(entry, "score") and read_field(read_field(entry, "score"), "final") or ""),
                }),
            }
        end
    end

    sort_items_by_name(items)
    return items, nil
end

local function parse_info_item(raw, context, installed)
    for _, entry in ipairs(parse_json_lines(raw)) do
        if trim(read_field(entry, "type")) == "inspect" then
            local data = read_field(entry, "data")
            local name = trim(read_field(data, "name"))
            if name == "" then
                break
            end

            local dist_tags = read_field(data, "dist-tags")
            local repository = read_field(data, "repository")
            local repo_url = repository
            if type(repository) == "table" then
                repo_url = read_field(repository, "url") or read_field(repository, "directory")
            end

            local item = {
                name = name,
                packageId = name,
                version = first_nonempty(installed and installed.version, read_field(data, "version"), read_field(dist_tags, "latest")),
                latestVersion = first_nonempty(read_field(dist_tags, "latest"), read_field(data, "version"), installed and installed.version),
                summary = trim(read_field(data, "description")),
                description = trim(read_field(data, "description")),
                homepage = nonempty(read_field(data, "homepage")),
                repository = nonempty(repo_url),
                license = nonempty(read_field(data, "license")),
                installed = installed ~= nil,
                status = installed ~= nil and "installed" or nil,
                type = "package",
                packageType = "package",
                extraFields = merge_extra_fields(path_fields(context), {
                    requestedRange = installed and installed.extraFields and installed.extraFields.requestedRange or nil,
                    distTagLatest = nonempty(read_field(dist_tags, "latest")),
                    modifiedAt = nonempty(read_field(read_field(data, "time"), "modified")),
                    createdAt = nonempty(read_field(read_field(data, "time"), "created")),
                }),
            }
            return item
        end
    end

    return {}
end

local function lookup_package_info(context, name)
    local package_name_value = trim(name)
    if package_name_value == "" then
        return {}
    end

    local installed = installed_item_map(context)[package_name_value]
    local result = run_exec(context, REQUIRED_BINARY .. " info " .. shell_quote(package_name_value) .. " --json")
    if result ~= nil and result.success == true then
        return parse_info_item(result.stdout, context, installed)
    end

    return installed or {}
end

local function info_matches_request(request, item)
    local wanted_name = package_name(request)
    local wanted_version = package_version(request)
    if wanted_name == "" or trim(item.name) ~= wanted_name then
        return false
    end
    if wanted_version == "" then
        return true
    end
    return trim(item.version) == wanted_version or trim(item.latestVersion) == wanted_version
end

local function build_global_add_command(target)
    return REQUIRED_BINARY .. " global add " .. shell_quote(target) .. " --non-interactive --silent --no-progress"
end

local function build_global_remove_command(name)
    return REQUIRED_BINARY .. " global remove " .. shell_quote(name) .. " --non-interactive --silent --no-progress"
end

local function build_global_upgrade_command(name)
    return REQUIRED_BINARY .. " global upgrade " .. shell_quote(name) .. " --latest --non-interactive --silent --no-progress"
end

local function run_package_mutations(context, packages, label, event_name, builder)
    if packages == nil or #packages == 0 then
        return true
    end

    begin_step(context, label)
    for _, pkg in ipairs(packages) do
        local command = builder(pkg)
        if command ~= nil then
            local result = run_exec(context, command)
            if result == nil or result.success ~= true then
                tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, label .. " failed"))
                return false
            end
        end
    end

    emit_event(context, event_name, packages)
    tx_success(context)
    return true
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
    return { "Node.js", "Package Manager", "npm" }
end

function plugin.getMissingPackages(context, packages)
    local installed = installed_item_map(context)
    local action = lower(read_field(context, "action") or "install")
    local missing = {}

    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        local version = package_version(pkg)
        local item = installed[name]

        if action == "remove" then
            if item ~= nil then
                missing[#missing + 1] = pkg
            end
        elseif action == "update" then
            if item ~= nil then
                missing[#missing + 1] = pkg
            end
        else
            if item == nil then
                missing[#missing + 1] = pkg
            elseif version ~= "" and trim(item.version) ~= version then
                missing[#missing + 1] = pkg
            end
        end
    end

    return missing
end

function plugin.install(context, packages)
    if require_classic_for_write(context) == nil then
        return false
    end

    return run_package_mutations(context, packages or {}, "install yarn global packages", "installed", function(pkg)
        local target = package_request_string(pkg)
        if target == nil then
            return nil
        end
        return build_global_add_command(target)
    end)
end

function plugin.installLocal(context, path)
    if require_classic_for_write(context) == nil then
        return false
    end

    local local_path = trim(path)
    if local_path == "" then
        tx_failed(context, "yarn local install failed")
        return false
    end

    begin_step(context, "install local yarn package")
    local result = run_exec(context, build_global_add_command("file:" .. local_path))
    if result == nil or result.success ~= true then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "yarn local install failed"))
        return false
    end

    emit_event(context, "installed", { path = local_path, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    if require_classic_for_write(context) == nil then
        return false
    end

    return run_package_mutations(context, packages or {}, "remove yarn global packages", "deleted", function(pkg)
        local name = package_name(pkg)
        if name == "" then
            return nil
        end
        return build_global_remove_command(name)
    end)
end

function plugin.update(context, packages)
    if require_classic_for_write(context) == nil then
        return false
    end

    return run_package_mutations(context, packages or {}, "update yarn global packages", "updated", function(pkg)
        local name = package_name(pkg)
        local version = package_version(pkg)
        if name == "" then
            return nil
        end
        if version ~= "" then
            return build_global_add_command(name .. "@" .. version)
        end
        return build_global_upgrade_command(name)
    end)
end

function plugin.list(context)
    local items = list_installed_items(context)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local state = runtime_state(context)
    local items = {}
    if state.isClassic and nonempty(state.globalDir) ~= nil then
        local command = REQUIRED_BINARY .. " --cwd " .. shell_quote(state.globalDir) .. " outdated --json"
        local result = run_exec(context, command)
        if result ~= nil and trim(result.stdout) ~= "" then
            items = parse_outdated_items(result.stdout, context)
        elseif result ~= nil and result.success ~= true and trim(result.stderr) ~= "" then
            log_warn(context, "yarn outdated failed")
        end
    end

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

    local items = {}
    local result = run_exec(context, build_curl_search_command(search_prompt))
    if result ~= nil and result.success == true then
        items = select(1, parse_search_items(result.stdout, context)) or {}
    elseif result ~= nil and trim(result.stderr) ~= "" then
        log_warn(context, "yarn search failed for " .. search_prompt)
    end

    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local item = lookup_package_info(context, trim(name))
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == "" then
        return nil
    end

    local item = lookup_package_info(context, name)
    if info_matches_request(package, item) then
        return item
    end

    if trim(item.name) ~= "" then
        return {
            name = item.name,
            packageId = item.packageId,
            version = first_nonempty(package_version(package), item.version, item.latestVersion),
            latestVersion = item.latestVersion,
            license = item.license,
            homepage = item.homepage,
            repository = item.repository,
            type = item.type,
            packageType = item.packageType,
            extraFields = item.extraFields,
        }
    end

    return nil
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "yarn", "npm", "node" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".config/yarn" },
            { kind = "user-home-subpath", value = ".cache/yarn" },
            { kind = "user-home-subpath", value = ".yarn" },
        },
        networkScopes = {
            { host = "registry.npmjs.org", scheme = "https" },
            { scheme = "https" },
        },
        privilegeLevel = "user",
        osvEcosystem = "npm",
        purlType = "npm",
        versionTokenPattern = "[A-Za-z0-9._:+~%-]+",
        versionCaseInsensitive = false,
    }
end

function plugin.init()
    return command_exists(REQUIRED_BINARY)
end

function plugin.shutdown()
    cached_json_decoder = nil
    return true
end

return plugin
