plugin = {}

local PLUGIN_NAME = "npm"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "npm"
local COMMAND_ENV_PREFIX = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME=\"$HOME\" XDG_CONFIG_HOME=\"$HOME/.config\" XDG_CACHE_HOME=\"$HOME/.cache\" XDG_DATA_HOME=\"$HOME/.local/share\" XDG_STATE_HOME=\"$HOME/.local/state\" NPM_CONFIG_PREFIX=\"$HOME/.local\" NPM_CONFIG_CACHE=\"$HOME/.npm\" NPM_CONFIG_UPDATE_NOTIFIER=false NPM_CONFIG_FUND=false NPM_CONFIG_AUDIT=false NPM_CONFIG_PROGRESS=false NPM_CONFIG_LOGLEVEL=error"
local JSON_NULL = {}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return tostring(value or ""):lower()
end

local function non_empty(value)
    if value == nil or value == JSON_NULL then
        return nil
    end

    local value_type = type(value)
    if value_type == "string" then
        local cleaned = trim(value)
        if cleaned ~= "" then
            return cleaned
        end
        return nil
    end

    if value_type == "number" or value_type == "boolean" then
        return tostring(value)
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

    local value_type = type(result)
    if value_type == "table" then
        return result
    end

    if value_type == "userdata" then
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

local function command_exists(binary)
    local result = run_exec(nil, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function object_field(value, key)
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

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
end

local function merge_extra_fields(left, right)
    local merged = shallow_copy(type(left) == "table" and left or {})
    for key, value in pairs(type(right) == "table" and right or {}) do
        merged[key] = value
    end
    if next(merged) == nil then
        return nil
    end
    return merged
end

local function sort_by_name(items)
    table.sort(items, function(left, right)
        return lower(object_field(left, "name")) < lower(object_field(right, "name"))
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
        elseif current:match("%d") ~= nil then
            repeat
                index = index + 1
                current = peek()
            until current:match("%d") == nil
        else
            decode_error("invalid number")
        end

        if peek() == "." then
            index = index + 1
            if peek():match("%d") == nil then
                decode_error("invalid number fraction")
            end
            repeat
                index = index + 1
            until peek():match("%d") == nil
        end

        current = peek()
        if current == "e" or current == "E" then
            index = index + 1
            current = peek()
            if current == "+" or current == "-" then
                index = index + 1
            end
            if peek():match("%d") == nil then
                decode_error("invalid number exponent")
            end
            repeat
                index = index + 1
            until peek():match("%d") == nil
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
                decode_error("expected ',' or ']' in array")
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
                decode_error("expected ':' after key")
            end
            index = index + 1
            skip_whitespace()
            result[key] = parse_value()
            skip_whitespace()

            local current = peek()
            if current == "," then
                index = index + 1
                skip_whitespace()
            elseif current == "}" then
                index = index + 1
                return result
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
        decode_error("trailing characters")
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

local function looks_like_json(raw)
    local text = trim(raw)
    if text == "" then
        return false
    end

    local first = text:sub(1, 1)
    if first == "{" or first == "[" or first == '"' or first == "-" then
        return true
    end
    if first:match("%d") ~= nil then
        return true
    end
    return text == "true" or text == "false" or text == "null"
end

local function package_name(pkg)
    return trim(object_field(pkg, "name") or object_field(pkg, "packageName") or object_field(pkg, "packageId"))
end

local function package_version(pkg)
    return trim(object_field(pkg, "version"))
end

local function package_doc_url(name)
    local package_name_value = trim(name)
    if package_name_value == "" then
        return nil
    end
    return "https://www.npmjs.com/package/" .. package_name_value
end

local function normalize_url(value)
    if type(value) == "table" and is_array(value) then
        for _, item in ipairs(value) do
            local normalized = non_empty(item)
            if normalized ~= nil then
                return normalized
            end
        end
        return nil
    end

    return non_empty(value)
end

local function normalize_repository(value)
    if type(value) == "table" then
        value = object_field(value, "url") or object_field(value, "web") or object_field(value, "homepage")
    end

    local url = non_empty(value)
    if url == nil then
        return nil
    end

    return url:gsub("^git%+", "")
end

local function normalize_license(value)
    if type(value) == "table" then
        value = object_field(value, "type") or object_field(value, "name")
    end
    return non_empty(value)
end

local function list_to_csv(values, formatter)
    if type(values) ~= "table" or not is_array(values) then
        return non_empty(values)
    end

    local items = {}
    for _, value in ipairs(values) do
        local item = formatter and formatter(value) or non_empty(value)
        if item ~= nil then
            items[#items + 1] = item
        end
    end

    if #items == 0 then
        return nil
    end
    return table.concat(items, ", ")
end

local function publisher_name(value)
    if type(value) == "table" then
        return non_empty(object_field(value, "username") or object_field(value, "name") or object_field(value, "email"))
    end
    return non_empty(value)
end

local function maintainer_name(value)
    if type(value) == "table" then
        return non_empty(object_field(value, "username") or object_field(value, "name") or object_field(value, "email"))
    end
    return non_empty(value)
end

local function scope_from_name(name)
    return trim(name):match("^@([^/]+)/")
end

local function base_extra_fields(name, additions)
    local extra = {
        ["purl.name"] = name,
    }

    local scope = scope_from_name(name)
    if scope ~= nil and scope ~= "" then
        extra["npm.scope"] = scope
    end

    return merge_extra_fields(extra, additions)
end

local function build_npm_command(arguments)
    local parts = { COMMAND_ENV_PREFIX, REQUIRED_BINARY }
    for _, argument in ipairs(arguments or {}) do
        local value = trim(argument)
        if value ~= "" then
            parts[#parts + 1] = shell_quote(value)
        end
    end
    return table.concat(parts, " ")
end

local function install_command(specs)
    local args = { "install", "-g" }
    for _, spec in ipairs(specs or {}) do
        args[#args + 1] = spec
    end
    return build_npm_command(args)
end

local function uninstall_command(names)
    local args = { "uninstall", "-g" }
    for _, name in ipairs(names or {}) do
        args[#args + 1] = name
    end
    return build_npm_command(args)
end

local function update_command(names)
    local args = { "update", "-g" }
    for _, name in ipairs(names or {}) do
        args[#args + 1] = name
    end
    return build_npm_command(args)
end

local function list_command()
    return build_npm_command({ "ls", "-g", "--depth=0", "--json" })
end

local function outdated_command()
    return build_npm_command({ "outdated", "-g", "--depth=0", "--json" })
end

local function search_command(prompt)
    return build_npm_command({ "search", prompt, "--json" })
end

local function info_command(name)
    return build_npm_command({ "view", name, "--json" })
end

local function build_package_spec(pkg)
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

local function collect_install_specs(packages)
    local specs = {}
    for _, pkg in ipairs(packages or {}) do
        local spec = build_package_spec(pkg)
        if spec ~= nil then
            specs[#specs + 1] = spec
        end
    end
    return specs
end

local function collect_package_names(packages)
    local names = {}
    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        if name ~= "" then
            names[#names + 1] = name
        end
    end
    return names
end

local function is_not_found_result(result)
    local text = lower((result and result.stdout) or "") .. "\n" .. lower((result and result.stderr) or "")
    return text:find("e404", 1, true) ~= nil
        or text:find("404 not found", 1, true) ~= nil
        or text:find("not in this registry", 1, true) ~= nil
        or text:find("no match found for", 1, true) ~= nil
end

local function decode_result_json(result)
    if type(result) ~= "table" then
        return nil, "missing result"
    end

    local stdout = result.stdout or ""
    if not looks_like_json(stdout) then
        return nil, "missing json output"
    end

    return decode_json(stdout)
end

local function installed_lookup_from_tree(decoded)
    local lookup = {}
    if type(decoded) ~= "table" then
        return lookup
    end

    local dependencies = object_field(decoded, "dependencies")
    if type(dependencies) ~= "table" then
        return lookup
    end

    for name, value in pairs(dependencies) do
        local package_name_value = trim(name)
        if package_name_value ~= "" and type(value) == "table" then
            lookup[package_name_value] = {
                version = non_empty(object_field(value, "version")),
                path = non_empty(object_field(value, "path")),
            }
        end
    end

    return lookup
end

local function normalize_list_item(name, data)
    local package_name_value = trim(name)
    if package_name_value == "" then
        return nil
    end

    local extra = base_extra_fields(package_name_value, {
        ["npm.path"] = non_empty(object_field(data, "path")),
    })

    return {
        name = package_name_value,
        packageId = package_name_value,
        version = non_empty(object_field(data, "version")),
        description = non_empty(object_field(data, "description")),
        documentation = package_doc_url(package_name_value),
        installed = true,
        packageType = "tool",
        type = "package",
        extraFields = extra,
    }
end

local function parse_list_items(decoded)
    local items = {}
    if type(decoded) ~= "table" then
        return items
    end

    local dependencies = object_field(decoded, "dependencies")
    if type(dependencies) ~= "table" then
        return items
    end

    for name, value in pairs(dependencies) do
        local item = normalize_list_item(name, value)
        if item ~= nil then
            items[#items + 1] = item
        end
    end

    sort_by_name(items)
    return items
end

local function normalize_outdated_item(name, data)
    local package_name_value = trim(name)
    if package_name_value == "" or type(data) ~= "table" then
        return nil
    end

    local extra = base_extra_fields(package_name_value, {
        ["npm.wanted"] = non_empty(object_field(data, "wanted")),
        ["npm.location"] = non_empty(object_field(data, "location")),
    })

    return {
        name = package_name_value,
        packageId = package_name_value,
        version = non_empty(object_field(data, "current")),
        latestVersion = non_empty(object_field(data, "latest")),
        documentation = package_doc_url(package_name_value),
        installed = true,
        packageType = "tool",
        type = "package",
        extraFields = extra,
    }
end

local function parse_outdated_items(decoded)
    local items = {}
    if type(decoded) ~= "table" then
        return items
    end

    for name, value in pairs(decoded) do
        local item = normalize_outdated_item(name, value)
        if item ~= nil then
            items[#items + 1] = item
        end
    end

    sort_by_name(items)
    return items
end

local function select_info_payload(decoded)
    if type(decoded) ~= "table" then
        return nil
    end

    if not is_array(decoded) then
        return decoded
    end

    for index = #decoded, 1, -1 do
        if type(decoded[index]) == "table" then
            return decoded[index]
        end
    end

    return nil
end

local function normalize_search_item(data)
    if type(data) ~= "table" then
        return nil
    end

    local name = non_empty(object_field(data, "name") or object_field(data, "sanitized_name"))
    if name == nil then
        return nil
    end

    local links = object_field(data, "links")
    local extra = base_extra_fields(name, {
        ["npm.publisher"] = publisher_name(object_field(data, "publisher")),
        ["npm.maintainers"] = list_to_csv(object_field(data, "maintainers"), maintainer_name),
        ["npm.keywords"] = list_to_csv(object_field(data, "keywords")),
    })

    return {
        name = name,
        packageId = name,
        version = non_empty(object_field(data, "version")),
        description = non_empty(object_field(data, "description")),
        license = normalize_license(object_field(data, "license")),
        homepage = normalize_url(object_field(links, "homepage") or object_field(data, "homepage")),
        repository = normalize_repository(object_field(links, "repository") or object_field(data, "repository")),
        documentation = normalize_url(object_field(links, "npm")) or package_doc_url(name),
        packageType = "tool",
        type = "package",
        extraFields = extra,
    }
end

local function parse_search_items(decoded)
    local items = {}
    if type(decoded) ~= "table" or not is_array(decoded) then
        return items
    end

    for _, value in ipairs(decoded) do
        local item = normalize_search_item(value)
        if item ~= nil then
            items[#items + 1] = item
        end
    end

    return items
end

local function normalize_info_item(name, data, installed_lookup)
    local package_name_value = trim(name)
    if package_name_value == "" or type(data) ~= "table" then
        return {}
    end

    local dist_tags = object_field(data, "dist-tags")
    local latest_tag = non_empty(object_field(dist_tags, "latest"))
    local remote_version = non_empty(object_field(data, "version")) or latest_tag
    local installed_item = type(installed_lookup) == "table" and installed_lookup[package_name_value] or nil
    local installed_version = installed_item and non_empty(object_field(installed_item, "version")) or nil
    local links = object_field(data, "links")

    local extra = base_extra_fields(package_name_value, {
        ["dist-tags.latest"] = latest_tag,
        ["npm.publisher"] = publisher_name(object_field(data, "publisher") or object_field(data, "_npmUser")),
        ["npm.maintainers"] = list_to_csv(object_field(data, "maintainers"), maintainer_name),
        ["npm.keywords"] = list_to_csv(object_field(data, "keywords")),
        ["npm.unpackSize"] = non_empty(object_field(object_field(data, "dist"), "unpackedSize")),
    })

    return {
        name = package_name_value,
        packageId = package_name_value,
        version = installed_version or remote_version,
        latestVersion = latest_tag or remote_version,
        description = non_empty(object_field(data, "description")),
        license = normalize_license(object_field(data, "license")),
        homepage = normalize_url(object_field(data, "homepage") or object_field(links, "homepage")),
        repository = normalize_repository(object_field(data, "repository") or object_field(links, "repository")),
        documentation = package_doc_url(package_name_value),
        installed = installed_item ~= nil,
        packageType = "tool",
        type = "package",
        extraFields = extra,
    }
end

local function load_installed_lookup(context)
    local result = run_exec(context, list_command())
    local decoded, decode_error = decode_result_json(result)
    if decoded == nil then
        return nil, decode_error
    end
    return installed_lookup_from_tree(decoded), nil
end

local function load_outdated_lookup(context)
    local result = run_exec(context, outdated_command())
    local decoded, decode_error = decode_result_json(result)
    if decoded == nil then
        if type(result) == "table" and trim(result.stdout or "") == "" then
            return {}, nil
        end
        return nil, decode_error
    end

    local lookup = {}
    if type(decoded) == "table" then
        for name, _ in pairs(decoded) do
            local package_name_value = trim(name)
            if package_name_value ~= "" then
                lookup[package_name_value] = true
            end
        end
    end
    return lookup, nil
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
    return { "Cross Platform", "Node.js", "JavaScript", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    if not command_exists(REQUIRED_BINARY) then
        local passthrough = {}
        for _, package in ipairs(packages or {}) do
            passthrough[#passthrough + 1] = package
        end
        return passthrough
    end

    local installed_lookup, installed_error = load_installed_lookup(nil)
    local outdated_lookup = nil
    local outdated_error = nil
    local missing = {}

    if installed_lookup == nil then
        installed_lookup = {}
    end

    for _, package in ipairs(packages or {}) do
        local action = trim(object_field(package, "action"))
        local name = package_name(package)
        local version = package_version(package)

        if name ~= "" then
            local installed_item = installed_lookup[name]
            local installed_version = installed_item and non_empty(object_field(installed_item, "version")) or nil

            if action == "remove" then
                if installed_error ~= nil or installed_item ~= nil then
                    missing[#missing + 1] = package
                end
            elseif action == "update" then
                if outdated_lookup == nil and outdated_error == nil then
                    outdated_lookup, outdated_error = load_outdated_lookup(nil)
                    if outdated_lookup == nil then
                        outdated_lookup = {}
                    end
                end

                if outdated_error ~= nil or outdated_lookup[name] == true then
                    missing[#missing + 1] = package
                end
            elseif installed_error ~= nil or installed_item == nil or (version ~= "" and installed_version ~= version) then
                missing[#missing + 1] = package
            end
        end
    end

    return missing
end

function plugin.install(context, packages)
    local specs = collect_install_specs(packages)
    if #specs == 0 then
        return true
    end

    begin_step(context, "install npm packages")
    local result = run_exec(context, install_command(specs))
    if result == nil or result.success ~= true then
        tx_failed(context, "npm install failed")
        return false
    end

    emit_event(context, "installed", packages or {})
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" then
        tx_failed(context, "npm local install failed")
        return false
    end

    begin_step(context, "install local npm package")
    local result = run_exec(context, install_command({ local_path }))
    if result == nil or result.success ~= true then
        tx_failed(context, "npm local install failed")
        return false
    end

    emit_event(context, "installed", { path = local_path, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local names = collect_package_names(packages)
    if #names == 0 then
        return true
    end

    begin_step(context, "remove npm packages")
    local result = run_exec(context, uninstall_command(names))
    if result == nil or result.success ~= true then
        tx_failed(context, "npm remove failed")
        return false
    end

    emit_event(context, "deleted", packages or {})
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local names = collect_package_names(packages)
    begin_step(context, "update npm packages")
    local result = run_exec(context, update_command(names))
    if result == nil or result.success ~= true then
        tx_failed(context, "npm update failed")
        return false
    end

    emit_event(context, "updated", packages or {})
    tx_success(context)
    return true
end

function plugin.list(context)
    local result = run_exec(context, list_command())
    local decoded, decode_error = decode_result_json(result)
    if decoded == nil then
        log_warn(context, "npm list failed: " .. tostring(decode_error))
        local empty = {}
        emit_event(context, "listed", empty)
        return empty
    end

    local items = parse_list_items(decoded)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local result = run_exec(context, outdated_command())
    if type(result) == "table" and trim(result.stdout or "") == "" then
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end

    local decoded, decode_error = decode_result_json(result)
    if decoded == nil then
        log_warn(context, "npm outdated failed: " .. tostring(decode_error))
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end

    local items = parse_outdated_items(decoded)
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

    local result = run_exec(context, search_command(search_prompt))
    local decoded, decode_error = decode_result_json(result)
    if decoded == nil then
        if not is_not_found_result(result) then
            log_warn(context, "npm search failed: " .. tostring(decode_error))
        end
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local items = parse_search_items(decoded)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local package_name_value = trim(name)
    if package_name_value == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local installed_lookup = nil
    local result = run_exec(context, info_command(package_name_value))
    local decoded, decode_error = decode_result_json(result)
    if decoded == nil then
        if not is_not_found_result(result) then
            log_warn(context, "npm info failed: " .. tostring(decode_error))
        end
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    installed_lookup = select(1, load_installed_lookup(context)) or {}
    local payload = select_info_payload(decoded)
    local item = normalize_info_item(package_name_value, payload, installed_lookup)
    emit_event(context, "informed", item)
    return item
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "npm", "node", "javascript", "typescript" },
        writeScopes = {
            "user-home-subpath:.local",
            "user-home-subpath:.npm",
            "user-home-subpath:.config",
            "user-home-subpath:.cache",
            "user-home-subpath:.local/share",
            "user-home-subpath:.local/state",
        },
        networkScopes = { "registry.npmjs.org" },
        privilegeLevel = "user",
        osvEcosystem = "npm",
        purlType = "npm",
        versionCaseInsensitive = false,
    }
end

function plugin.init()
    return command_exists(REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

return plugin
