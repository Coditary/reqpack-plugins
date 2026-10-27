plugin = {}

local PLUGIN_ID = "pnpm"
local PLUGIN_NAME = "pnpm"
local PLUGIN_VERSION = "0.1.0"
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
        if value ~= JSON_NULL and value ~= nil then
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
    local result = exec_run(context, "command -v " .. tostring(binary or "") .. " >/dev/null 2>&1")
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
        decode_error("unexpected token")
    end

    local parsed = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("trailing data")
    end
    return parsed
end

local function decode_json(raw)
    local ok, value = pcall(decode_json_internal, raw)
    if not ok then
        return nil, value
    end
    return value, nil
end

local function split_lines(value)
    local lines = {}
    for line in tostring(value or ""):gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end
    return lines
end

local FLAG_ALIASES = {
    ["-C"] = "dir",
    ["-D"] = "save-dev",
    ["-E"] = "save-exact",
    ["-O"] = "save-optional",
    ["-P"] = "save-prod",
    ["-g"] = "global",
    ["-w"] = "workspace-root",
    ["--dir"] = "dir",
    ["--global"] = "global",
    ["--global-dir"] = "global-dir",
    ["--store-dir"] = "store-dir",
    ["--save-dev"] = "save-dev",
    ["--save-optional"] = "save-optional",
    ["--save-peer"] = "save-peer",
    ["--save-prod"] = "save-prod",
    ["--save-exact"] = "save-exact",
    ["--ignore-scripts"] = "ignore-scripts",
    ["--offline"] = "offline",
    ["--prefer-offline"] = "prefer-offline",
    ["--workspace"] = "workspace",
    ["--workspace-root"] = "workspace-root",
    ["--latest"] = "latest",
    ["--dev"] = "dev",
    ["--prod"] = "prod",
    ["--no-optional"] = "no-optional",
    ["dir"] = "dir",
    ["global"] = "global",
    ["global-dir"] = "global-dir",
    ["store-dir"] = "store-dir",
    ["save-dev"] = "save-dev",
    ["save-optional"] = "save-optional",
    ["save-peer"] = "save-peer",
    ["save-prod"] = "save-prod",
    ["save-exact"] = "save-exact",
    ["ignore-scripts"] = "ignore-scripts",
    ["offline"] = "offline",
    ["prefer-offline"] = "prefer-offline",
    ["workspace"] = "workspace",
    ["workspace-root"] = "workspace-root",
    ["latest"] = "latest",
    ["dev"] = "dev",
    ["prod"] = "prod",
    ["no-optional"] = "no-optional",
}

local function ordered_values(values)
    local ordered = {}
    if values == nil then
        return ordered
    end

    for index = 1, 256 do
        local ok, value = pcall(function()
            return values[index]
        end)
        if not ok or value == nil then
            break
        end
        ordered[#ordered + 1] = value
    end
    if #ordered > 0 then
        return ordered
    end

    local ok, iter, state, init = pcall(ipairs, values)
    if ok then
        for _, value in iter, state, init do
            ordered[#ordered + 1] = value
        end
        if #ordered > 0 then
            return ordered
        end
    end

    if type(values) ~= "table" then
        return ordered
    end

    local indexed = {}
    for key, value in pairs(values) do
        if type(key) == "number" then
            indexed[#indexed + 1] = { key = key, value = value }
        end
    end
    table.sort(indexed, function(left, right)
        return left.key < right.key
    end)
    for _, entry in ipairs(indexed) do
        ordered[#ordered + 1] = entry.value
    end
    return ordered
end

local function merged_request_flags(context, packages)
    local values = {}
    local context_flag_sources = {
        context and context.flags,
        context and read_field(context, "request") and read_field(read_field(context, "request"), "flags"),
        context and read_field(context, "input") and read_field(read_field(context, "input"), "flags"),
        context and read_field(context, "operation") and read_field(read_field(context, "operation"), "flags"),
    }

    for _, source in ipairs(context_flag_sources) do
        for _, value in ipairs(ordered_values(source)) do
            values[#values + 1] = value
        end
    end
    for _, pkg in ipairs(packages or {}) do
        if pkg ~= nil and type(pkg.flags) == "table" then
            for _, value in ipairs(ordered_values(pkg.flags)) do
                values[#values + 1] = value
            end
        end
    end
    return values
end

local function parse_flag(raw)
    local value = trim(raw)
    if value == "" then
        return nil, nil
    end

    local key, assigned = value:match("^%-%-([^=]+)=(.+)$")
    if key ~= nil then
        return FLAG_ALIASES[key] or key, assigned
    end

    key, assigned = value:match("^([^=]+)=(.+)$")
    if key ~= nil then
        local normalized = key:gsub("^%-%-?", "")
        return FLAG_ALIASES[normalized] or normalized, assigned
    end

    local normalized = value:gsub("^%-%-?", "")
    return FLAG_ALIASES[value] or FLAG_ALIASES[normalized] or normalized, true
end

local function collect_flags(context, packages, boolean_flags, value_flags, skip_flags)
    local flags = {}
    local seen = {}

    for _, raw in ipairs(merged_request_flags(context, packages)) do
        local key, value = parse_flag(raw)
        if key ~= nil and (skip_flags == nil or skip_flags[key] ~= true) then
            if value == true then
                local rendered = boolean_flags[key]
                if rendered ~= nil and seen[rendered] ~= true then
                    flags[#flags + 1] = rendered
                    seen[rendered] = true
                end
            else
                local prefix = value_flags[key]
                local normalized = trim(value)
                if prefix ~= nil and normalized ~= "" then
                    local rendered = prefix .. " " .. shell_quote(normalized)
                    if seen[rendered] ~= true then
                        flags[#flags + 1] = rendered
                        seen[rendered] = true
                    end
                end
            end
        end
    end

    return flags
end

local COMMON_BOOLEAN_FLAGS = {
    ["global"] = "--global",
    ["ignore-scripts"] = "--ignore-scripts",
    ["offline"] = "--offline",
    ["prefer-offline"] = "--prefer-offline",
    ["workspace"] = "--workspace",
    ["workspace-root"] = "--workspace-root",
}

local COMMON_VALUE_FLAGS = {
    ["dir"] = "--dir",
    ["global-dir"] = "--global-dir",
    ["store-dir"] = "--store-dir",
}

local ADD_BOOLEAN_FLAGS = merge_extra_fields(COMMON_BOOLEAN_FLAGS, {
    ["save-dev"] = "--save-dev",
    ["save-optional"] = "--save-optional",
    ["save-peer"] = "--save-peer",
    ["save-prod"] = "--save-prod",
    ["save-exact"] = "--save-exact",
})

local REMOVE_BOOLEAN_FLAGS = merge_extra_fields(COMMON_BOOLEAN_FLAGS, {
    ["save-dev"] = "--save-dev",
    ["save-optional"] = "--save-optional",
    ["save-prod"] = "--save-prod",
})

local UPDATE_BOOLEAN_FLAGS = merge_extra_fields(COMMON_BOOLEAN_FLAGS, {
    ["latest"] = "--latest",
    ["dev"] = "--dev",
    ["prod"] = "--prod",
    ["no-optional"] = "--no-optional",
})

local QUERY_BOOLEAN_FLAGS = merge_extra_fields(COMMON_BOOLEAN_FLAGS, {})

local function append_command_flags(command, flags)
    if flags == nil or #flags == 0 then
        return command
    end
    return command .. " " .. table.concat(flags, " ")
end

local function package_spec(pkg)
    local name = trim(read_field(pkg, "name") or "")
    local version = trim(read_field(pkg, "version") or "")
    if version == "" then
        return name
    end
    return name .. "@" .. version
end

local function package_specs(packages)
    local names = {}
    for _, pkg in ipairs(packages or {}) do
        local spec = package_spec(pkg)
        if spec ~= "" then
            names[#names + 1] = shell_quote(spec)
        end
    end
    return names
end

local function package_names(packages)
    local names = {}
    for _, pkg in ipairs(packages or {}) do
        local name = trim(read_field(pkg, "name") or "")
        if name ~= "" then
            names[#names + 1] = shell_quote(name)
        end
    end
    return names
end

local function build_scope_flags(context, packages)
    return collect_flags(context, packages, QUERY_BOOLEAN_FLAGS, COMMON_VALUE_FLAGS)
end

local function run_json_command(context, command)
    local result = exec_run(context, command)
    if result == nil or not result.success then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "command failed"), result
    end

    local decoded, decode_error = decode_json(result.stdout)
    if decoded == nil then
        return nil, first_nonempty(decode_error, "json decode failed"), result
    end

    return decoded, nil, result
end

local function registry_from_context(context)
    local registry = nil
    if context ~= nil and type(context.repositories) == "table" then
        for _, repository in ipairs(context.repositories) do
            if repository ~= nil and repository.enabled ~= false then
                registry = trim(repository.url or "")
                if registry ~= "" then
                    break
                end
            end
        end
    end
    return first_nonempty(registry and registry:gsub("/+$", ""), "https://registry.npmjs.org")
end

local function query_store_path(context, packages)
    local configured = nil
    for _, raw in ipairs(merged_request_flags(context, packages)) do
        local key, value = parse_flag(raw)
        if key == "store-dir" and value ~= true then
            configured = trim(value)
            break
        end
    end
    if configured ~= nil and configured ~= "" then
        return configured
    end
    local command = append_command_flags("pnpm store path", build_scope_flags(context, packages))
    local result = exec_run(context, command)
    if result ~= nil and result.success then
        return trim(result.stdout)
    end
    return nil
end

local function query_global_root(context, packages)
    local configured = nil
    for _, raw in ipairs(merged_request_flags(context, packages)) do
        local key, value = parse_flag(raw)
        if key == "global-dir" and value ~= true then
            configured = trim(value)
            break
        end
    end
    if configured ~= nil and configured ~= "" then
        return configured
    end
    local command = append_command_flags(
        "pnpm root --global",
        collect_flags(context, packages, {}, {
            ["dir"] = "--dir",
            ["global-dir"] = "--global-dir",
        })
    )
    local result = exec_run(context, command)
    if result ~= nil and result.success then
        return trim(result.stdout)
    end
    return nil
end

local function build_package_info(name, data, dependency_type, defaults)
    local package_name = first_nonempty(name, read_field(data, "name"), read_field(data, "from"))
    local version = first_nonempty(read_field(data, "version"), read_field(defaults, "version"))
    local latest_version = first_nonempty(read_field(data, "latest"), read_field(defaults, "latestVersion"), version)
    local status = first_nonempty(read_field(defaults, "status"), "installed")

    return {
        name = package_name,
        packageId = package_name,
        version = version,
        latestVersion = latest_version,
        type = "package",
        packageType = dependency_type,
        installed = status == "installed" or status == "outdated",
        status = status,
        summary = first_nonempty(read_field(defaults, "summary"), read_field(data, "description"), package_name),
        description = first_nonempty(read_field(defaults, "description"), read_field(data, "description")),
        homepage = first_nonempty(read_field(defaults, "homepage"), read_field(data, "homepage")),
        sourceUrl = first_nonempty(read_field(defaults, "sourceUrl"), type(read_field(data, "repository")) == "table" and read_field(read_field(data, "repository"), "url") or nil),
        license = first_nonempty(read_field(defaults, "license"), read_field(data, "license")),
        repository = first_nonempty(read_field(defaults, "repository")),
        updatedAt = first_nonempty(read_field(defaults, "updatedAt")),
        extraFields = merge_extra_fields(read_field(defaults, "extraFields"), {
            dependencyType = dependency_type,
            resolved = first_nonempty(read_field(data, "resolved")),
            installPath = first_nonempty(read_field(data, "path")),
        }),
    }
end

local function append_dependency_map(items, deps, dependency_type, defaults)
    if type(deps) ~= "table" then
        return
    end
    for name, value in pairs(deps) do
        items[#items + 1] = build_package_info(name, value, dependency_type, defaults)
    end
end

local function sort_items(items)
    table.sort(items, function(left, right)
        return lower(left.name or left.packageId or "") < lower(right.name or right.packageId or "")
    end)
    return items
end

local function parse_list_payload(payload, context, packages)
    local items = {}
    local entry = type(payload) == "table" and payload[1] or nil
    local registry = registry_from_context(context)
    local store_path = query_store_path(context, packages)
    local global_root = nil
    local defaults = {
        repository = registry,
        extraFields = {
            registry = registry,
            storePath = store_path,
        },
    }

    local scope_flags = merged_request_flags(context, packages)
    for _, raw in ipairs(scope_flags) do
        local key = parse_flag(raw)
        if key == "global" then
            global_root = query_global_root(context, packages)
            defaults.extraFields.globalRoot = global_root
            break
        end
    end

    if type(entry) ~= "table" then
        return items
    end

    append_dependency_map(items, read_field(entry, "dependencies"), "dependencies", defaults)
    append_dependency_map(items, read_field(entry, "devDependencies"), "devDependencies", defaults)
    append_dependency_map(items, read_field(entry, "optionalDependencies"), "optionalDependencies", defaults)

    if global_root ~= nil and global_root ~= "" then
        for _, item in ipairs(items) do
            item.packageType = "global"
        end
    end

    return sort_items(items)
end

local function parse_outdated_payload(payload, context, packages)
    local items = {}
    if type(payload) ~= "table" then
        return items
    end

    local registry = registry_from_context(context)
    local store_path = query_store_path(context, packages)
    local global_root = nil
    for _, raw in ipairs(merged_request_flags(context, packages)) do
        local key = parse_flag(raw)
        if key == "global" then
            global_root = query_global_root(context, packages)
            break
        end
    end

    for name, value in pairs(payload) do
        if type(value) == "table" then
            items[#items + 1] = {
                name = name,
                packageId = name,
                version = first_nonempty(read_field(value, "current")),
                latestVersion = first_nonempty(read_field(value, "latest"), read_field(value, "wanted")),
                type = "package",
                packageType = first_nonempty(global_root and "global" or nil, read_field(value, "dependencyType")),
                installed = true,
                status = "outdated",
                summary = name,
                description = name,
                repository = registry,
                extraFields = merge_extra_fields(nil, {
                    dependencyType = first_nonempty(read_field(value, "dependencyType")),
                    wantedVersion = first_nonempty(read_field(value, "wanted")),
                    isDeprecated = tostring(read_field(value, "isDeprecated") == true),
                    registry = registry,
                    storePath = store_path,
                    globalRoot = global_root,
                }),
            }
        end
    end

    return sort_items(items)
end

local function parse_search_payload(payload, context)
    local items = {}
    if type(payload) ~= "table" then
        return items
    end

    local registry = registry_from_context(context)
    for _, value in ipairs(payload) do
        if type(value) == "table" then
            local links = type(read_field(value, "links")) == "table" and read_field(value, "links") or {}
            items[#items + 1] = {
                name = first_nonempty(read_field(value, "name")),
                packageId = first_nonempty(read_field(value, "name")),
                version = first_nonempty(read_field(value, "version")),
                latestVersion = first_nonempty(read_field(value, "version")),
                type = "package",
                packageType = "npm",
                status = "available",
                summary = first_nonempty(read_field(value, "description"), read_field(value, "name")),
                description = first_nonempty(read_field(value, "description")),
                homepage = first_nonempty(read_field(links, "homepage"), read_field(links, "npm")),
                sourceUrl = first_nonempty(read_field(links, "repository"), read_field(links, "npm")),
                license = first_nonempty(read_field(value, "license")),
                repository = registry,
                updatedAt = first_nonempty(read_field(value, "date")),
                extraFields = merge_extra_fields(nil, {
                    registry = registry,
                    publisher = type(read_field(value, "publisher")) == "table" and first_nonempty(read_field(read_field(value, "publisher"), "username")) or nil,
                    npmUrl = first_nonempty(read_field(links, "npm")),
                }),
            }
        end
    end

    return sort_items(items)
end

local function join_keywords(keywords)
    if type(keywords) ~= "table" then
        return nil
    end
    local parts = {}
    for _, value in ipairs(keywords) do
        local text = trim(value)
        if text ~= "" then
            parts[#parts + 1] = text
        end
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, ", ")
end

local function parse_info_payload(payload, spec, context)
    if type(payload) ~= "table" then
        return {}
    end

    local dist_tags = type(read_field(payload, "dist-tags")) == "table" and read_field(payload, "dist-tags") or {}
    local repository = type(read_field(payload, "repository")) == "table" and read_field(read_field(payload, "repository"), "url") or nil
    local dist = type(read_field(payload, "dist")) == "table" and read_field(payload, "dist") or {}
    local time = type(read_field(payload, "time")) == "table" and read_field(payload, "time") or {}
    local package_name = first_nonempty(read_field(payload, "name"), spec)
    local latest = first_nonempty(read_field(dist_tags, "latest"), read_field(payload, "version"))
    local registry = registry_from_context(context)

    return {
        name = package_name,
        packageId = package_name,
        version = first_nonempty(read_field(payload, "version"), latest),
        latestVersion = latest,
        type = "package",
        packageType = "npm",
        status = "available",
        summary = first_nonempty(read_field(payload, "description"), package_name),
        description = first_nonempty(read_field(payload, "description")),
        homepage = first_nonempty(read_field(payload, "homepage"), read_field(read_field(payload, "bugs") or {}, "url")),
        sourceUrl = first_nonempty(repository),
        license = first_nonempty(read_field(payload, "license")),
        repository = registry,
        updatedAt = first_nonempty(read_field(time, "modified")),
        extraFields = merge_extra_fields(nil, {
            registry = registry,
            tarball = first_nonempty(read_field(dist, "tarball")),
            integrity = first_nonempty(read_field(dist, "integrity")),
            shasum = first_nonempty(read_field(dist, "shasum")),
            keywords = join_keywords(read_field(payload, "keywords")),
        }),
    }
end

local function installed_names_map(context, packages)
    local command = append_command_flags("pnpm list --json --depth 0", build_scope_flags(context, packages))
    local payload = select(1, run_json_command(context, command))
    local items = parse_list_payload(payload, context, packages)
    local map = {}
    for _, item in ipairs(items) do
        map[item.name] = true
    end
    return map, items
end

local function outdated_names_map(context, packages)
    local command = append_command_flags("pnpm outdated --format json", build_scope_flags(context, packages))
    local payload = select(1, run_json_command(context, command))
    local items = parse_outdated_payload(payload, context, packages)
    local map = {}
    for _, item in ipairs(items) do
        map[item.name] = true
    end
    return map, items
end

plugin.fileExtensions = { ".tgz", ".tar.gz" }

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
    return { "JavaScript", "Node", "npm", "pnpm", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end
    if not command_exists(nil, "pnpm") then
        return requested
    end

    local installed_map = select(1, installed_names_map(nil, requested))
    if installed_map == nil then
        return requested
    end

    local needs_update = false
    for _, pkg in ipairs(requested) do
        if lower(read_field(pkg, "action") or "") == "update" then
            needs_update = true
            break
        end
    end

    local outdated_map = nil
    if needs_update then
        outdated_map = select(1, outdated_names_map(nil, requested))
        if outdated_map == nil then
            return requested
        end
    end

    local filtered = {}
    for _, pkg in ipairs(requested) do
        local name = trim(read_field(pkg, "name") or "")
        local action = lower(read_field(pkg, "action") or "install")
        local installed = installed_map[name] == true
        local outdated = outdated_map ~= nil and outdated_map[name] == true

        if action == "remove" then
            if installed then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "update" then
            if outdated then
                filtered[#filtered + 1] = pkg
            end
        elseif not installed then
            filtered[#filtered + 1] = pkg
        end
    end

    return filtered
end

function plugin.install(context, packages)
    local local_path = trim(read_field(context, "localPath") or read_field(read_field(context, "request") or {}, "localPath") or "")
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end

    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    local flags = collect_flags(context, requested, ADD_BOOLEAN_FLAGS, COMMON_VALUE_FLAGS)
    local command = append_command_flags("pnpm add", flags) .. " " .. table.concat(package_specs(requested), " ")

    begin_step(context, "install pnpm packages")
    local result = exec_run(context, command)
    if result == nil or not result.success then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "pnpm install failed"))
        return false
    end

    emit_event(context, "installed", requested)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local target = trim(path)
    if target == "" then
        tx_failed(context, "pnpm local install path missing")
        return false
    end

    local flags = collect_flags(context, nil, ADD_BOOLEAN_FLAGS, COMMON_VALUE_FLAGS)
    local command = append_command_flags("pnpm add", flags) .. " " .. shell_quote(target)

    begin_step(context, "install local pnpm package")
    local result = exec_run(context, command)
    if result == nil or not result.success then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "pnpm local install failed"))
        return false
    end

    emit_event(context, "installed", { path = target, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    local flags = collect_flags(context, requested, REMOVE_BOOLEAN_FLAGS, COMMON_VALUE_FLAGS)
    local command = append_command_flags("pnpm remove", flags) .. " " .. table.concat(package_names(requested), " ")

    begin_step(context, "remove pnpm packages")
    local result = exec_run(context, command)
    if result == nil or not result.success then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "pnpm remove failed"))
        return false
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    local flags = collect_flags(context, requested, UPDATE_BOOLEAN_FLAGS, COMMON_VALUE_FLAGS)
    local command = append_command_flags("pnpm update", flags)
    local names = package_names(requested)
    if #names > 0 then
        command = command .. " " .. table.concat(names, " ")
    end

    begin_step(context, "update pnpm packages")
    local result = exec_run(context, command)
    if result == nil or not result.success then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "pnpm update failed"))
        return false
    end

    emit_event(context, "updated", requested)
    tx_success(context)
    return true
end

function plugin.list(context)
    local command = append_command_flags("pnpm list --json --depth 0", build_scope_flags(context, nil))
    local payload, err = run_json_command(context, command)
    if payload == nil then
        log_warn(context, err)
        emit_event(context, "listed", {})
        return {}
    end

    local items = parse_list_payload(payload, context, nil)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local command = append_command_flags("pnpm outdated --format json", build_scope_flags(context, nil))
    local payload, err = run_json_command(context, command)
    if payload == nil then
        log_warn(context, err)
        emit_event(context, "outdated", {})
        return {}
    end

    local items = parse_outdated_payload(payload, context, nil)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local normalized = trim(prompt)
    if normalized == "" then
        emit_event(context, "searched", {})
        return {}
    end

    local command = "pnpm search " .. shell_quote(normalized) .. " --json"
    local payload, err = run_json_command(context, command)
    if payload == nil then
        log_warn(context, err)
        emit_event(context, "searched", {})
        return {}
    end

    local items = parse_search_payload(payload, context)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local spec = trim(name)
    if spec == "" then
        emit_event(context, "informed", {})
        return {}
    end

    local command = "pnpm view " .. shell_quote(spec) .. " --json"
    local payload, err = run_json_command(context, command)
    if payload == nil then
        log_warn(context, err)
        emit_event(context, "informed", {})
        return {}
    end

    local item = parse_info_payload(payload, spec, context)
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end
    local name = trim(read_field(package, "name") or "")
    if name == "" then
        return nil
    end

    local item = plugin.info(context, package_spec(package))
    if type(item) ~= "table" or next(item) == nil then
        return nil
    end
    return {
        name = item.name,
        packageId = item.packageId,
        version = item.version,
        homepage = item.homepage,
        sourceUrl = item.sourceUrl,
        license = item.license,
        extraFields = item.extraFields,
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "npm", "pnpm" },
        writeScopes = {
            { kind = "temp" },
            { kind = "user-home-subpath", value = ".local/share/pnpm" },
            { kind = "user-home-subpath", value = ".pnpm-store" },
        },
        networkScopes = {
            { host = "registry.npmjs.org", scheme = "https", pathPrefix = "/" },
        },
        privilegeLevel = "user",
        osvEcosystem = "npm",
        purlType = "npm",
        versionComparatorProfile = "semver",
    }
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

return plugin
