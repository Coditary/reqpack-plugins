plugin = {}

local PLUGIN_ID = "composer"
local PLUGIN_NAME = "Composer"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "composer"
local JSON_NULL = {}

local INSTALL_BOOLEAN_FLAGS = {
    dev = "--dev",
    ["no-update"] = "--no-update",
    ["no-install"] = "--no-install",
    ["prefer-stable"] = "--prefer-stable",
    ["prefer-lowest"] = "--prefer-lowest",
    ["minimal-changes"] = "--minimal-changes",
    ["sort-packages"] = "--sort-packages",
    ["update-with-dependencies"] = "--update-with-dependencies",
    ["update-with-all-dependencies"] = "--update-with-all-dependencies",
    ["ignore-platform-reqs"] = "--ignore-platform-reqs",
}

local REMOVE_BOOLEAN_FLAGS = {
    dev = "--dev",
    unused = "--unused",
    ["no-update"] = "--no-update",
    ["no-install"] = "--no-install",
    ["minimal-changes"] = "--minimal-changes",
    ["update-with-all-dependencies"] = "--update-with-all-dependencies",
    ["ignore-platform-reqs"] = "--ignore-platform-reqs",
}

local UPDATE_BOOLEAN_FLAGS = {
    ["with-dependencies"] = "--with-dependencies",
    ["with-all-dependencies"] = "--with-all-dependencies",
    ["prefer-stable"] = "--prefer-stable",
    ["prefer-lowest"] = "--prefer-lowest",
    ["minimal-changes"] = "--minimal-changes",
    ["patch-only"] = "--patch-only",
    ["root-reqs"] = "--root-reqs",
    ["no-dev"] = "--no-dev",
    ["no-install"] = "--no-install",
    ["no-audit"] = "--no-audit",
    lock = "--lock",
    ["ignore-platform-reqs"] = "--ignore-platform-reqs",
}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return trim(value):lower()
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

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
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

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function command_quote(value)
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,%[%]%*%^~]+$") then
        return text
    end
    return shell_quote(text)
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
            decode_error("invalid number")
        end

        if peek() == "." then
            index = index + 1
            if peek():match("%d") == nil then
                decode_error("invalid fraction")
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
                decode_error("invalid exponent")
            end
            repeat
                index = index + 1
                current = peek()
            until current == "" or current:match("%d") == nil
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

local function is_array(value)
    if type(value) ~= "table" then
        return false
    end
    local count = 0
    local max = 0
    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
            return false
        end
        count = count + 1
        if key > max then
            max = key
        end
    end
    return count == max
end

local function object_flags(object)
    local value = read_field(object, "flags")
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local flags = {}
    local ok = pcall(function()
        for _, flag in ipairs(value) do
            local text = trim(flag)
            if text ~= "" then
                flags[#flags + 1] = text
            end
        end
    end)
    if not ok then
        return {}
    end
    return flags
end

local function context_flags(context)
    return object_flags(context)
end

local function flag_value(flags, prefix)
    local needle = trim(prefix)
    for _, flag in ipairs(flags or {}) do
        local text = trim(flag)
        if text:sub(1, #needle) == needle then
            return trim(text:sub(#needle + 1))
        end
    end
    return ""
end

local function flag_values(flags, prefix)
    local values = {}
    local needle = trim(prefix)
    for _, flag in ipairs(flags or {}) do
        local text = trim(flag)
        if text:sub(1, #needle) == needle then
            local value = trim(text:sub(#needle + 1))
            if value ~= "" then
                values[#values + 1] = value
            end
        end
    end
    return values
end

local function has_flag(flags, name)
    local wanted = lower(name)
    for _, flag in ipairs(flags or {}) do
        if lower(flag) == wanted then
            return true
        end
    end
    return false
end

local function merged_flags(context, package)
    local flags = {}
    for _, flag in ipairs(context_flags(context)) do
        flags[#flags + 1] = flag
    end
    for _, flag in ipairs(object_flags(package)) do
        flags[#flags + 1] = flag
    end
    return flags
end

local function get_plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR)
    if dir ~= "" then
        return dir
    end
    return "."
end

local function get_cache_root(context)
    local override = flag_value(context_flags(context), "cache-root=")
    if override ~= "" then
        return override
    end
    return join_path(get_plugin_dir(), ".reqpack-data", "composer")
end

local function get_composer_home(context)
    return join_path(get_cache_root(context), "home")
end

local function get_composer_cache_dir(context)
    return join_path(get_cache_root(context), "cache")
end

local function command_prefix(context)
    return table.concat({
        "COMPOSER_HOME=" .. shell_quote(get_composer_home(context)),
        "COMPOSER_CACHE_DIR=" .. shell_quote(get_composer_cache_dir(context)),
        "COMPOSER_NO_INTERACTION='1'",
        "COMPOSER_ALLOW_SUPERUSER='1'",
        "NO_COLOR='1'",
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
        "SHELL='/bin/sh'",
    }, " ")
end

local function with_env(context, command)
    return command_prefix(context) .. " " .. command
end

local function request_packages(context, packages)
    if (type(packages) == "table" or type(packages) == "userdata") and #packages > 0 then
        return packages
    end
    local from_context = read_field(context, "packages")
    if type(from_context) == "table" then
        return from_context
    end
    local request = read_field(context, "request")
    local nested = read_field(request, "packages")
    if type(nested) == "table" or type(nested) == "userdata" then
        return nested
    end
    return {}
end

local function request_prompt(context, value)
    return trim(value or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
end

local function local_path_from_context(context)
    local request = read_field(context, "request")
    return trim(
        read_field(context, "localPath")
            or read_field(context, "path")
            or read_field(context, "local_path")
            or read_field(request, "localPath")
            or read_field(request, "path")
            or read_field(request, "local_path")
    )
end

local function package_action(pkg)
    return lower(read_field(pkg, "action"))
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageName") or read_field(pkg, "packageId"))
end

local function package_version(pkg)
    return trim(read_field(pkg, "version"))
end

local function package_spec(pkg)
    local name = package_name(pkg)
    local version = package_version(pkg)
    if name == "" then
        return nil
    end
    if version ~= "" then
        return name .. ":" .. version
    end
    return name
end

local function package_error(context, message, payload)
    local text = trim(message)
    if text == "" then
        text = "composer command failed"
    end
    tx_failed(context, text)
    emit_event(context, "failed", text)
    return false, payload
end

local function ensure_available(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function append_flag_parts(parts, flags, boolean_map, value_map)
    for key, option in pairs(boolean_map or {}) do
        if has_flag(flags, key) then
            parts[#parts + 1] = option
        end
    end
    for key, option in pairs(value_map or {}) do
        local value = flag_value(flags, key .. "=")
        if value ~= "" then
            parts[#parts + 1] = option .. "=" .. command_quote(value)
        end
    end
    for _, value in ipairs(flag_values(flags, "ignore-platform-req=")) do
        parts[#parts + 1] = "--ignore-platform-req=" .. command_quote(value)
    end
end

local function map_raw_item(raw)
    if type(raw) ~= "table" then
        return nil
    end

    local name = first_nonempty(json_value(raw.name), json_value(raw.package))
    if name == nil then
        return nil
    end

    local source = json_value(raw.source)
    local source_url = nil
    if type(source) == "table" then
        source_url = first_nonempty(json_value(source.url), json_value(source.source), json_value(source.reference))
    else
        source_url = first_nonempty(source)
    end

    local dist = json_value(raw.dist)
    local dist_url = nil
    if type(dist) == "table" then
        dist_url = first_nonempty(json_value(dist.url), json_value(dist.reference))
    end

    local version = first_nonempty(json_value(raw.version), json_value(raw.pretty_version))
    if version == nil and type(raw.versions) == "table" and #raw.versions > 0 then
        version = first_nonempty(json_value(raw.versions[1]))
    end

    local item = {
        name = name,
        packageId = name,
        version = version,
        latestVersion = first_nonempty(json_value(raw.latest), json_value(raw.latestVersion)),
        summary = first_nonempty(json_value(raw.description), json_value(raw.summary)),
        description = first_nonempty(json_value(raw.description), json_value(raw.summary)),
        homepage = first_nonempty(json_value(raw.homepage), json_value(raw.url), json_value(raw.repository)),
        source = first_nonempty(source_url, dist_url, json_value(raw.repository), json_value(raw.url)),
        type = first_nonempty(json_value(raw.type)),
        license = json_value(raw.license) or json_value(raw.licenses),
        keywords = json_value(raw.keywords),
        names = json_value(raw.names),
        abandoned = json_value(raw.abandoned),
    }

    if item.description == nil and item.summary ~= nil then
        item.description = item.summary
    end
    return item
end

local function collect_items(node, out)
    if type(node) ~= "table" then
        return
    end
    local item = map_raw_item(node)
    if item ~= nil then
        out[#out + 1] = item
        return
    end
    if is_array(node) then
        for _, value in ipairs(node) do
            collect_items(value, out)
        end
        return
    end
    for _, value in pairs(node) do
        collect_items(value, out)
    end
end

local function unique_items(items)
    local deduped = {}
    local seen = {}
    for _, item in ipairs(items or {}) do
        local key = lower(item.name or "")
        if key ~= "" and seen[key] == nil then
            seen[key] = true
            deduped[#deduped + 1] = item
        end
    end
    return deduped
end

local function parse_items_json(raw)
    local decoded, err = decode_json(raw)
    if decoded == nil then
        return nil, err
    end
    local items = {}
    collect_items(decoded, items)
    return unique_items(items), nil
end

local function parse_item_json(raw)
    local decoded, err = decode_json(raw)
    if decoded == nil then
        return nil, err
    end
    local item = map_raw_item(decoded)
    if item ~= nil then
        return item, nil
    end
    local items = {}
    collect_items(decoded, items)
    if #items > 0 then
        return items[1], nil
    end
    return {}, nil
end

local function merge_item(installed, remote)
    if type(installed) ~= "table" or next(installed) == nil then
        return remote or {}
    end
    if type(remote) ~= "table" or next(remote) == nil then
        return installed or {}
    end
    local merged = shallow_copy(remote)
    for key, value in pairs(installed) do
        if value ~= nil and value ~= JSON_NULL and value ~= "" then
            if key == "version" or merged[key] == nil or merged[key] == "" then
                merged[key] = value
            end
        end
    end
    merged.installed = true
    return merged
end

local function query_installed_items(context)
    local command = with_env(context, "composer global show --format json")
    local result = exec_run(context, command)
    if not result_success(result) then
        return nil, first_nonempty(result.stderr, result.stdout, "composer global show failed")
    end
    local items, err = parse_items_json(result.stdout or "")
    if items == nil then
        return nil, "failed to parse composer global show JSON: " .. tostring(err)
    end
    return items, nil
end

local function query_outdated_items(context)
    local command = with_env(context, "composer global outdated --format json")
    local result = exec_run(context, command)
    if not result_success(result, { 1 }) then
        return nil, first_nonempty(result.stderr, result.stdout, "composer global outdated failed")
    end
    local items, err = parse_items_json(result.stdout or "")
    if items == nil then
        return nil, "failed to parse composer global outdated JSON: " .. tostring(err)
    end
    return items, nil
end

local function query_installed_item(context, name)
    local command = with_env(context, "composer global show --format json " .. shell_quote(name))
    local result = exec_run(context, command)
    if not result_success(result) then
        return nil
    end
    local item = select(1, parse_item_json(result.stdout or ""))
    return item
end

local function query_remote_item(context, name)
    local command = with_env(context, "composer show --all --format json " .. shell_quote(name))
    local result = exec_run(context, command)
    if not result_success(result) then
        return nil, first_nonempty(result.stderr, result.stdout, "composer show failed")
    end
    local item, err = parse_item_json(result.stdout or "")
    if item == nil then
        return nil, "failed to parse composer show JSON: " .. tostring(err)
    end
    return item, nil
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
    return { "PHP", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    packages = request_packages(nil, packages)
    if packages == nil or #packages == 0 then
        return {}
    end

    if not command_exists(nil, REQUIRED_BINARY) then
        return packages
    end

    local installed_items = select(1, query_installed_items(nil)) or {}
    local outdated_items = select(1, query_outdated_items(nil)) or {}
    local installed = {}
    local outdated = {}

    for _, item in ipairs(installed_items) do
        installed[lower(item.name or "")] = true
    end
    for _, item in ipairs(outdated_items) do
        outdated[lower(item.name or "")] = true
    end

    local filtered = {}
    for _, pkg in ipairs(packages) do
        local name = package_name(pkg)
        local action = package_action(pkg)
        local key = lower(name)
        if action == "remove" then
            if installed[key] then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "update" then
            if outdated[key] or key == "" then
                filtered[#filtered + 1] = pkg
            end
        else
            if not installed[key] then
                filtered[#filtered + 1] = pkg
            end
        end
    end
    return filtered
end

function plugin.install(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "composer-not-installed" })
    end

    local local_path = local_path_from_context(context)
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end

    packages = request_packages(context, packages)
    if packages == nil or #packages == 0 then
        tx_success(context)
        emit_event(context, "success", "")
        return true
    end

    local outputs = {}
    for _, pkg in ipairs(packages) do
        local spec = package_spec(pkg)
        if spec ~= nil then
            local flags = merged_flags(context, pkg)
            local parts = { "composer", "global", "require", "--no-progress", "--no-ansi" }
            append_flag_parts(parts, flags, INSTALL_BOOLEAN_FLAGS, { ["prefer-install"] = "--prefer-install" })
            parts[#parts + 1] = shell_quote(spec)
            begin_step(context, "install Composer package " .. package_name(pkg))
            local command = with_env(context, table.concat(parts, " "))
            local result = exec_run(context, command)
            if not result_success(result) then
                return package_error(context, first_nonempty(result.stderr, result.stdout, "composer global require failed"))
            end
            outputs[#outputs + 1] = result.stdout or ""
            emit_event(context, "installed", {
                name = package_name(pkg),
                packageId = package_name(pkg),
                version = package_version(pkg),
            })
        end
    end

    tx_success(context)
    emit_event(context, "success", table.concat(outputs))
    return true
end

function plugin.installLocal(context, path)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "composer-not-installed", path = tostring(path or "") })
    end
    return package_error(context, "composer local installs are not supported in v1", {
        path = trim(path),
        reason = "local-install-unsupported",
    })
end

function plugin.remove(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "composer-not-installed" })
    end

    packages = request_packages(context, packages)
    if packages == nil or #packages == 0 then
        tx_success(context)
        emit_event(context, "success", "")
        return true
    end

    local outputs = {}
    for _, pkg in ipairs(packages) do
        local name = package_name(pkg)
        if name ~= "" then
            local parts = { "composer", "global", "remove", "--no-progress", "--no-ansi" }
            append_flag_parts(parts, merged_flags(context, pkg), REMOVE_BOOLEAN_FLAGS, nil)
            parts[#parts + 1] = shell_quote(name)
            begin_step(context, "remove Composer package " .. name)
            local command = with_env(context, table.concat(parts, " "))
            local result = exec_run(context, command)
            if not result_success(result) then
                return package_error(context, first_nonempty(result.stderr, result.stdout, "composer global remove failed"))
            end
            outputs[#outputs + 1] = result.stdout or ""
            emit_event(context, "deleted", {
                name = name,
                packageId = name,
            })
        end
    end

    tx_success(context)
    emit_event(context, "success", table.concat(outputs))
    return true
end

function plugin.update(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "composer-not-installed" })
    end

    packages = request_packages(context, packages)
    local parts = { "composer", "global", "update", "--no-progress", "--no-ansi" }
    append_flag_parts(parts, context_flags(context), UPDATE_BOOLEAN_FLAGS, nil)

    local updated_names = {}
    for _, pkg in ipairs(packages or {}) do
        local spec = package_spec(pkg)
        if spec ~= nil then
            updated_names[#updated_names + 1] = package_name(pkg)
            parts[#parts + 1] = shell_quote(spec)
        end
    end

    begin_step(context, #updated_names > 0 and "update Composer packages" or "update all Composer packages")
    local command = with_env(context, table.concat(parts, " "))
    local result = exec_run(context, command)
    if not result_success(result) then
        return package_error(context, first_nonempty(result.stderr, result.stdout, "composer global update failed"))
    end

    if #updated_names == 0 then
        emit_event(context, "updated", { all = true })
    else
        for _, name in ipairs(updated_names) do
            emit_event(context, "updated", { name = name, packageId = name })
        end
    end

    tx_success(context)
    emit_event(context, "success", result.stdout or "")
    return true
end

function plugin.list(context)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "composer-not-installed" })
    end

    local items, err = query_installed_items(context)
    if items == nil then
        return package_error(context, err)
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "composer-not-installed" })
    end

    local items, err = query_outdated_items(context)
    if items == nil then
        return package_error(context, err)
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "composer-not-installed" })
    end

    local query = request_prompt(context, prompt)
    if query == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local command = with_env(context, "composer search --format json " .. shell_quote(query))
    local result = exec_run(context, command)
    if not result_success(result) then
        return package_error(context, first_nonempty(result.stderr, result.stdout, "composer search failed"))
    end

    local items, err = parse_items_json(result.stdout or "")
    if items == nil then
        return package_error(context, "failed to parse composer search JSON: " .. tostring(err))
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "composer-not-installed" })
    end

    local query = request_prompt(context, name)
    if query == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local installed = query_installed_item(context, query)
    local remote, err = query_remote_item(context, query)
    if remote == nil and installed == nil then
        log_warn(context, err or (query .. " not found"))
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local item = merge_item(installed, remote)
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
    local installed = query_installed_item(context, name)
    if type(installed) == "table" and next(installed) ~= nil then
        return installed
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
        ecosystemScopes = { "composer", "packagist", "php" },
        writeScopes = {},
        networkScopes = {
            { host = "packagist.org", scheme = "https", pathPrefix = "/" },
            { host = "repo.packagist.org", scheme = "https", pathPrefix = "/" },
        },
        privilegeLevel = "user",
        osvEcosystem = "Packagist",
        purlType = "composer",
        versionComparatorProfile = "semver",
    }
end

return plugin
