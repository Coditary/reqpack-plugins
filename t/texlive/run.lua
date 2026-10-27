plugin = {}

local PLUGIN_ID = "texlive"
local PLUGIN_NAME = "TeX Live"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "tlmgr"
local JSON_NULL = {}

local CACHE = {
    installed_list = nil,
    local_tlpdb = nil,
    remote_tlpdb = {},
    outdated = {},
    search = {},
}

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

local function split_lines(value)
    local lines = {}
    local text = tostring(value or ""):gsub("\r\n", "\n")
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
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

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
end

local function json_value(value)
    if value == JSON_NULL then
        return nil
    end
    return value
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

local function has_flag(flags, expected)
    local needle = lower(expected)
    for _, flag in ipairs(flags or {}) do
        if lower(flag) == needle then
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

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageName") or read_field(pkg, "packageId"))
end

local function package_action(pkg)
    local action = trim(read_field(pkg, "action"))
    if action == "" then
        return "install"
    end
    return lower(action)
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

    if type(result) ~= "table" and type(result) ~= "userdata" then
        return {
            success = false,
            stdout = "",
            stderr = "command execution failed",
            exitCode = 1,
        }
    end

    local normalized = {}
    for _, key in ipairs({ "success", "ok", "stdout", "stdoutText", "stderr", "stderrText", "exitCode", "exit_code", "code", "status" }) do
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

local function command_exists(binary)
    local result = exec_run(nil, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
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
                decode_error("expected ',' or ']'")
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

local function split_csv_line(line)
    local fields = {}
    local current = {}
    local in_quotes = false
    local i = 1
    local text = tostring(line or "")
    while i <= #text do
        local char = text:sub(i, i)
        if in_quotes then
            if char == '"' then
                if text:sub(i + 1, i + 1) == '"' then
                    current[#current + 1] = '"'
                    i = i + 1
                else
                    in_quotes = false
                end
            else
                current[#current + 1] = char
            end
        else
            if char == '"' then
                in_quotes = true
            elseif char == "," then
                fields[#fields + 1] = table.concat(current)
                current = {}
            else
                current[#current + 1] = char
            end
        end
        i = i + 1
    end
    fields[#fields + 1] = table.concat(current)
    return fields
end

local function repository_key(repository)
    local cleaned = trim(repository)
    if cleaned == "" then
        return "__default__"
    end
    return cleaned
end

local function repository_from_flags(flags, fallback)
    local override = flag_value(flags or {}, "repository=")
    if override ~= "" then
        return override
    end
    return fallback
end

local function tlmgr_command(repository, args)
    local parts = { REQUIRED_BINARY }
    local cleaned_repository = trim(repository)
    if cleaned_repository ~= "" then
        parts[#parts + 1] = shell_quote("--repository")
        parts[#parts + 1] = shell_quote(cleaned_repository)
    end
    for _, arg in ipairs(args or {}) do
        local cleaned = trim(arg)
        if cleaned ~= "" then
            parts[#parts + 1] = shell_quote(cleaned)
        end
    end
    return table.concat(parts, " ")
end

local function package_error(context, message)
    tx_failed(context, message)
    emit_event(context, "failed", message)
    return false
end

local function clear_cache()
    CACHE.installed_list = nil
    CACHE.local_tlpdb = nil
    CACHE.remote_tlpdb = {}
    CACHE.outdated = {}
    CACHE.search = {}
end

local function available_or_error()
    if command_exists(REQUIRED_BINARY) then
        return true
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function package_flags_with_context(context, pkg)
    local merged = {}
    for _, item in ipairs(context and context.flags or {}) do
        merged[#merged + 1] = item
    end
    for _, item in ipairs(object_flags(pkg)) do
        merged[#merged + 1] = item
    end
    return merged
end

local function normalize_package(pkg)
    local name = package_name(pkg)
    if name == "" then
        return nil, "missing TeX Live package name"
    end
    local flags = object_flags(pkg)
    return {
        name = name,
        flags = flags,
        force = has_flag(flags, "force"),
        no_depends = has_flag(flags, "no-depends"),
        no_depends_at_all = has_flag(flags, "no-depends-at-all"),
        reinstall = has_flag(flags, "reinstall"),
        with_doc = has_flag(flags, "with-doc"),
        with_src = has_flag(flags, "with-src"),
    }
end

local function tlmgr_args_for_pkg(pkg, action)
    local args = {}
    if pkg.force then
        args[#args + 1] = "--force"
    end
    if pkg.no_depends_at_all then
        args[#args + 1] = "--no-depends-at-all"
    elseif pkg.no_depends then
        args[#args + 1] = "--no-depends"
    end
    if action == "install" or action == "update" then
        if pkg.reinstall then
            args[#args + 1] = "--reinstall"
        end
        if pkg.with_doc then
            args[#args + 1] = "--with-doc"
        end
        if pkg.with_src then
            args[#args + 1] = "--with-src"
        end
    end
    args[#args + 1] = action
    return args
end

local function parse_boolish(value)
    local cleaned = lower(value)
    if cleaned == "1" or cleaned == "true" or cleaned == "yes" then
        return true
    end
    if cleaned == "0" or cleaned == "false" or cleaned == "no" then
        return false
    end
    return nil
end

local function maybe_extra_fields(extra)
    if next(extra) == nil then
        return nil
    end
    return extra
end

local function compare_revision(left, right)
    local left_number = tonumber(left)
    local right_number = tonumber(right)
    if left_number ~= nil and right_number ~= nil then
        if left_number < right_number then
            return -1
        end
        if left_number > right_number then
            return 1
        end
        return 0
    end

    local left_text = trim(left)
    local right_text = trim(right)
    if left_text < right_text then
        return -1
    end
    if left_text > right_text then
        return 1
    end
    return 0
end

local function package_status(installed, local_rev, remote_rev)
    if installed then
        if non_empty(local_rev) ~= nil and non_empty(remote_rev) ~= nil and compare_revision(local_rev, remote_rev) < 0 then
            return "outdated"
        end
        return "installed"
    end
    if non_empty(remote_rev) ~= nil then
        return "available"
    end
    return "unknown"
end

local function parse_relocatable_value(value)
    if value == nil then
        return nil
    end
    if type(value) == "boolean" then
        return value
    end
    local boolish = parse_boolish(value)
    if boolish ~= nil then
        return boolish
    end
    return nil
end

local function make_extra_fields(item)
    local extra = {}
    local relocatable = parse_relocatable_value(json_value(item.relocatable))
    if relocatable == nil then
        relocatable = parse_relocatable_value(json_value(item.relocated))
    end
    if relocatable ~= nil then
        extra.relocatable = relocatable
    end

    local depends = json_value(item.depends)
    if depends ~= nil then
        extra.depends = depends
    end

    local catalog = json_value(item.rcataloguedata) or json_value(item.lcataloguedata) or json_value(item.cataloguedata)
    if type(catalog) == "table" then
        local version = non_empty(json_value(catalog.version))
        local date = non_empty(json_value(catalog.date))
        local license = non_empty(json_value(catalog.license))
        if version ~= nil then
            extra.catalogVersion = version
        end
        if date ~= nil then
            extra.catalogDate = date
        end
        if license ~= nil then
            extra.catalogLicense = license
        end
    end

    return maybe_extra_fields(extra)
end

local function build_item_from_sources(name, local_item, remote_item)
    local local_name = non_empty(json_value(local_item and local_item.name))
    local remote_name = non_empty(json_value(remote_item and remote_item.name))
    local resolved_name = non_empty(name) or local_name or remote_name
    if resolved_name == nil then
        return nil
    end

    local local_rev = json_value(local_item and local_item.localrev) or json_value(local_item and local_item.lrev) or json_value(local_item and local_item.revision)
    local remote_rev = json_value(remote_item and remote_item.remoterev) or json_value(remote_item and remote_item.rrev) or json_value(remote_item and remote_item.revision)
    if remote_rev == nil then
        remote_rev = json_value(local_item and local_item.remoterev) or json_value(local_item and local_item.rrev)
    end
    if local_rev == nil then
        local_rev = json_value(remote_item and remote_item.localrev) or json_value(remote_item and remote_item.lrev)
    end

    local installed = local_item ~= nil or json_value(remote_item and remote_item.installed) == true or json_value(local_item and local_item.installed) == true
    local category = non_empty(json_value(local_item and local_item.category)) or non_empty(json_value(remote_item and remote_item.category)) or "package"
    local summary = non_empty(json_value(local_item and local_item.shortdesc)) or non_empty(json_value(remote_item and remote_item.shortdesc))
    local description = non_empty(json_value(local_item and local_item.longdesc)) or non_empty(json_value(remote_item and remote_item.longdesc))
    local version = installed and non_empty(local_rev) or non_empty(remote_rev) or non_empty(local_rev)
    local latest = non_empty(remote_rev) or version
    local merged_extra = {}

    local local_extra = make_extra_fields(local_item or {}) or {}
    local remote_extra = make_extra_fields(remote_item or {}) or {}
    for key, value in pairs(local_extra) do
        merged_extra[key] = value
    end
    for key, value in pairs(remote_extra) do
        merged_extra[key] = value
    end

    return {
        name = resolved_name,
        packageId = resolved_name,
        version = version,
        latestVersion = latest,
        installed = installed,
        status = package_status(installed, version, latest),
        packageType = category,
        summary = summary,
        description = description,
        extraFields = maybe_extra_fields(merged_extra),
    }
end

local function parse_list(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            local fields = split_csv_line(cleaned)
            local name = non_empty(fields[1])
            if name ~= nil then
                local extra = {}
                local relocatable = parse_boolish(fields[5] or "")
                if relocatable ~= nil then
                    extra.relocatable = relocatable
                end
                items[#items + 1] = {
                    name = name,
                    packageId = name,
                    version = non_empty(fields[3]),
                    latestVersion = non_empty(fields[3]),
                    installed = true,
                    status = "installed",
                    packageType = non_empty(fields[2]) or "package",
                    summary = non_empty(fields[4]),
                    extraFields = maybe_extra_fields(extra),
                }
            end
        end
    end
    table.sort(items, function(left, right)
        return lower(left.name) < lower(right.name)
    end)
    return items
end

local function parse_info_item(item, requested)
    local name = non_empty(json_value(item.name)) or non_empty(requested)
    if name == nil then
        return nil
    end
    if json_value(item.available) == false and json_value(item.installed) ~= true then
        return nil
    end
    return build_item_from_sources(name, json_value(item.installed) == true and item or nil, item)
end

local function parse_info(stdout, requested)
    local decoded, err = decode_json(stdout)
    if decoded == nil then
        return nil, err
    end
    if type(decoded) ~= "table" then
        return {}, nil
    end

    local matched = nil
    for _, item in ipairs(decoded) do
        local parsed = parse_info_item(item, requested)
        if parsed ~= nil then
            if parsed.name == requested then
                return parsed, nil
            end
            if matched == nil then
                matched = parsed
            end
        end
    end
    return matched or {}, nil
end

local function parse_search(stdout)
    local decoded, err = decode_json(stdout)
    if decoded == nil then
        return nil, err
    end
    if type(decoded) ~= "table" then
        return {}, nil
    end

    local items = {}
    local packages = json_value(decoded.packages)
    local files = json_value(decoded.files)
    if type(packages) ~= "table" then
        return items, nil
    end

    for name, summary in pairs(packages) do
        local extra = {}
        if type(files) == "table" and type(files[name]) == "table" then
            extra.matchingFiles = shallow_copy(files[name])
        end
        items[#items + 1] = {
            name = tostring(name),
            packageId = tostring(name),
            summary = non_empty(summary),
            installed = false,
            status = "available",
            packageType = "package",
            extraFields = maybe_extra_fields(extra),
        }
    end

    table.sort(items, function(left, right)
        return lower(left.name) < lower(right.name)
    end)
    return items, nil
end

local function status_from_update_code(code)
    if code == "u" then
        return "outdated"
    end
    if code == "a" then
        return "available"
    end
    if code == "d" then
        return "removed"
    end
    if code == "f" then
        return "forcibly-removed"
    end
    if code == "r" then
        return "local-newer"
    end
    return "unknown"
end

local function parse_outdated(stdout)
    local items = {}
    local in_updates = false
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned == "end-of-header" then
            in_updates = true
        elseif cleaned == "end-of-updates" then
            break
        elseif in_updates and cleaned ~= "" then
            local fields = {}
            for field in (line .. "\t"):gmatch("(.-)\t") do
                fields[#fields + 1] = field
            end
            if #fields >= 7 then
                local extra = {
                    updateAction = non_empty(fields[2]),
                }
                if non_empty(fields[8]) ~= nil and fields[8] ~= "-" then
                    extra.repositoryTag = fields[8]
                end
                if non_empty(fields[9]) ~= nil and fields[9] ~= "-" then
                    extra.catalogVersionLocal = fields[9]
                end
                if non_empty(fields[10]) ~= nil and fields[10] ~= "-" then
                    extra.catalogVersionRemote = fields[10]
                end

                items[#items + 1] = {
                    name = non_empty(fields[1]),
                    packageId = non_empty(fields[1]),
                    version = non_empty(fields[3]),
                    latestVersion = non_empty(fields[4]),
                    installed = fields[2] ~= "a",
                    status = status_from_update_code(fields[2]),
                    packageType = "package",
                    extraFields = maybe_extra_fields(extra),
                }
            end
        end
    end
    table.sort(items, function(left, right)
        return lower(left.name or "") < lower(right.name or "")
    end)
    return items
end

local function normalize_tlpdb(stdout)
    local decoded, err = decode_json(stdout)
    if decoded == nil then
        return nil, err
    end
    if type(decoded) ~= "table" then
        return {}, nil
    end

    local packages = {}
    for _, repo_data in pairs(decoded) do
        local repo_packages = json_value(repo_data and repo_data.tlpkgs)
        if type(repo_packages) == "table" then
            for _, item in ipairs(repo_packages) do
                local name = non_empty(json_value(item.name))
                if name ~= nil and packages[name] == nil then
                    packages[name] = item
                end
            end
        end
    end
    return packages, nil
end

local function query_installed_list(context)
    if CACHE.installed_list ~= nil then
        return CACHE.installed_list
    end

    local result = exec_run(context, tlmgr_command(nil, {
        "info",
        "--only-installed",
        "--data",
        "name,category,localrev,shortdesc,relocatable",
    }))
    if result == nil or result.success ~= true then
        return nil
    end

    CACHE.installed_list = parse_list(result.stdout)
    return CACHE.installed_list
end

local function fetch_local_tlpdb(context)
    if CACHE.local_tlpdb ~= nil then
        return CACHE.local_tlpdb, nil
    end

    local result = exec_run(context, tlmgr_command(nil, { "dump-tlpdb", "--local", "--json" }))
    if result == nil or result.success ~= true then
        return nil, result and result.stderr or "local TLPDB query failed"
    end

    local normalized, err = normalize_tlpdb(result.stdout)
    if normalized == nil then
        return nil, err
    end
    CACHE.local_tlpdb = normalized
    return CACHE.local_tlpdb, nil
end

local function fetch_remote_tlpdb(context, repository)
    local key = repository_key(repository)
    if CACHE.remote_tlpdb[key] ~= nil then
        return CACHE.remote_tlpdb[key], nil
    end

    local result = exec_run(context, tlmgr_command(repository, { "dump-tlpdb", "--remote", "--json" }))
    if result == nil or result.success ~= true then
        return nil, result and result.stderr or "remote TLPDB query failed"
    end

    local normalized, err = normalize_tlpdb(result.stdout)
    if normalized == nil then
        return nil, err
    end
    CACHE.remote_tlpdb[key] = normalized
    return CACHE.remote_tlpdb[key], nil
end

local function snapshot_list_items(snapshot)
    local items = {}
    for name, item in pairs(snapshot or {}) do
        local package_item = build_item_from_sources(name, item, item)
        if package_item ~= nil then
            package_item.installed = true
            package_item.status = "installed"
            package_item.latestVersion = package_item.version
            items[#items + 1] = package_item
        end
    end
    table.sort(items, function(left, right)
        return lower(left.name) < lower(right.name)
    end)
    return items
end

local function query_outdated_items(context, repository)
    local key = repository_key(repository)
    if CACHE.outdated[key] ~= nil then
        return CACHE.outdated[key]
    end

    local result = exec_run(context, tlmgr_command(repository, { "--machine-readable", "update", "--list" }))
    if result == nil or result.success ~= true then
        return nil
    end

    CACHE.outdated[key] = parse_outdated(result.stdout)
    return CACHE.outdated[key]
end

local function outdated_from_snapshots(context, repository)
    local local_snapshot = fetch_local_tlpdb(context)
    local remote_snapshot = fetch_remote_tlpdb(context, repository)
    if local_snapshot == nil or remote_snapshot == nil then
        return {}
    end

    local items = {}
    for name, local_item in pairs(local_snapshot) do
        local remote_item = remote_snapshot[name]
        if remote_item ~= nil then
            local built = build_item_from_sources(name, local_item, remote_item)
            if built ~= nil and built.status == "outdated" then
                items[#items + 1] = built
            end
        end
    end
    table.sort(items, function(left, right)
        return lower(left.name) < lower(right.name)
    end)
    return items
end

local function detail_lookup(context, repository, name)
    local result = exec_run(context, tlmgr_command(repository, { "info", "--json", name }))
    if result ~= nil and result.success == true then
        local parsed, err = parse_info(result.stdout, name)
        if parsed ~= nil and next(parsed) ~= nil then
            return parsed, nil
        end
        if parsed == nil and err ~= nil then
            log_warn(context, "texlive info JSON parse failed: " .. tostring(err))
        end
    end

    local local_snapshot = fetch_local_tlpdb(context)
    local remote_snapshot = fetch_remote_tlpdb(context, repository)
    local local_item = local_snapshot and local_snapshot[name] or nil
    local remote_item = remote_snapshot and remote_snapshot[name] or nil
    local fallback = build_item_from_sources(name, local_item, remote_item)
    if fallback ~= nil then
        return fallback, nil
    end
    return {}, nil
end

local function query_search_items(context, repository, prompt)
    local key = repository_key(repository) .. ":" .. prompt
    if CACHE.search[key] ~= nil then
        return CACHE.search[key]
    end

    local result = exec_run(context, tlmgr_command(repository, { "search", "--global", "--json", prompt }))
    if result == nil or result.success ~= true then
        return nil
    end

    local items, err = parse_search(result.stdout)
    if items == nil then
        log_warn(context, "texlive search JSON parse failed: " .. tostring(err))
        return {}
    end
    CACHE.search[key] = items
    return CACHE.search[key]
end

local function installed_set(items)
    local seen = {}
    for _, item in ipairs(items or {}) do
        if non_empty(item.name) ~= nil then
            seen[item.name] = true
        end
    end
    return seen
end

local function partition_updateable(requested)
    local grouped = {}
    for _, pkg in ipairs(requested or {}) do
        if package_action(pkg) == "update" then
            local flags = package_flags_with_context(nil, pkg)
            local repository = repository_from_flags(flags, nil)
            local key = repository_key(repository)
            if grouped[key] == nil then
                grouped[key] = {
                    repository = repository,
                    names = {},
                }
            end
            local name = package_name(pkg)
            if name ~= "" then
                grouped[key].names[#grouped[key].names + 1] = name
            end
        end
    end
    return grouped
end

plugin.fileExtensions = { ".tar.xz", ".tar.gz", ".zip", ".tlpobj" }

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
    return { "tex", "document", "package-manager" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end
    if not command_exists(REQUIRED_BINARY) then
        return { REQUIRED_BINARY }
    end

    local listed = query_installed_list(nil)
    if listed == nil then
        return requested
    end

    local installed = installed_set(listed)
    local updateable_by_repo = {}
    local grouped_updates = partition_updateable(requested)
    for key, group in pairs(grouped_updates) do
        local outdated = query_outdated_items(nil, group.repository)
        if outdated == nil then
            return requested
        end
        updateable_by_repo[key] = installed_set(outdated)
    end

    local filtered = {}
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        local action = package_action(pkg)
        local flags = object_flags(pkg)
        local reinstall = has_flag(flags, "reinstall")
        local repo_key = repository_key(repository_from_flags(flags, nil))
        local is_installed = installed[name] == true
        local updateable = updateable_by_repo[repo_key] or {}

        if action == "remove" then
            if is_installed then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "update" then
            if updateable[name] == true then
                filtered[#filtered + 1] = pkg
            end
        elseif is_installed ~= true or reinstall then
            filtered[#filtered + 1] = pkg
        end
    end
    return filtered
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        emit_event(context, "success", "ok")
        return true
    end

    local available, message = available_or_error()
    if not available then
        return package_error(context, message)
    end

    begin_step(context, "install texlive packages")
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        local repository = repository_from_flags(package_flags_with_context(context, raw_pkg), nil)
        local args = tlmgr_args_for_pkg(pkg, "install")
        args[#args + 1] = pkg.name
        local result = exec_run(context, tlmgr_command(repository, args))
        if result == nil or result.success ~= true then
            return package_error(context, "texlive install failed for " .. pkg.name)
        end
    end

    clear_cache()
    emit_event(context, "installed", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path or (context and context.localPath) or "")
    if local_path == "" then
        return package_error(context, "missing local path")
    end

    local available, message = available_or_error()
    if not available then
        return package_error(context, message)
    end

    begin_step(context, "install local texlive package")
    local result = exec_run(context, tlmgr_command(nil, { "install", "--file", local_path }))
    if result == nil or result.success ~= true then
        return package_error(context, "texlive local install failed; tlmgr expects TeX Live package container input")
    end

    clear_cache()
    emit_event(context, "installed", { path = local_path, localTarget = true })
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        emit_event(context, "success", "ok")
        return true
    end

    local available, message = available_or_error()
    if not available then
        return package_error(context, message)
    end

    begin_step(context, "remove texlive packages")
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        local repository = repository_from_flags(package_flags_with_context(context, raw_pkg), nil)
        local args = tlmgr_args_for_pkg(pkg, "remove")
        args[#args + 1] = pkg.name
        local result = exec_run(context, tlmgr_command(repository, args))
        if result == nil or result.success ~= true then
            return package_error(context, "texlive remove failed for " .. pkg.name)
        end
    end

    clear_cache()
    emit_event(context, "deleted", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    local available, message = available_or_error()
    if not available then
        return package_error(context, message)
    end

    begin_step(context, "update texlive packages")
    if #requested == 0 then
        local repository = repository_from_flags(context and context.flags or {}, nil)
        local result = exec_run(context, tlmgr_command(repository, { "update", "--all" }))
        if result == nil or result.success ~= true then
            return package_error(context, "texlive update failed")
        end

        clear_cache()
        emit_event(context, "updated", {})
        tx_success(context)
        emit_event(context, "success", "ok")
        return true
    end

    local groups = {}
    local order = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        local flags = package_flags_with_context(context, raw_pkg)
        local repository = repository_from_flags(flags, nil)
        local args = tlmgr_args_for_pkg(pkg, "update")
        local key = repository_key(repository) .. "\31" .. table.concat(args, "\31")
        if groups[key] == nil then
            groups[key] = {
                repository = repository,
                args = shallow_copy(args),
                names = {},
            }
            order[#order + 1] = key
        end
        groups[key].names[#groups[key].names + 1] = pkg.name
    end

    for _, key in ipairs(order) do
        local group = groups[key]
        local args = shallow_copy(group.args)
        for _, name in ipairs(group.names) do
            args[#args + 1] = name
        end
        local result = exec_run(context, tlmgr_command(group.repository, args))
        if result == nil or result.success ~= true then
            return package_error(context, "texlive update failed")
        end
    end

    clear_cache()
    emit_event(context, "updated", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.list(context)
    local available, message = available_or_error()
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "listed", items)
        return items
    end

    local items = query_installed_list(context)
    if items == nil then
        local snapshot = fetch_local_tlpdb(context)
        items = snapshot and snapshot_list_items(snapshot) or {}
        if #items == 0 then
            log_warn(context, "texlive list failed")
        end
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local available, message = available_or_error()
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "outdated", items)
        return items
    end

    local repository = repository_from_flags(context and context.flags or {}, nil)
    local items = query_outdated_items(context, repository)
    if items == nil then
        items = outdated_from_snapshots(context, repository)
        if #items == 0 then
            log_warn(context, "texlive outdated failed")
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
        local items = {}
        emit_event(context, "searched", items)
        return items
    end

    local available, message = available_or_error()
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "searched", items)
        return items
    end

    local repository = repository_from_flags(context and context.flags or {}, nil)
    local items = query_search_items(context, repository, cleaned_prompt)
    if items == nil then
        log_warn(context, "texlive search failed")
        items = {}
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
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    local available, message = available_or_error()
    if not available then
        log_warn(context, message)
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    local repository = repository_from_flags(context and context.flags or {}, nil)
    local item = nil
    local err = nil
    item, err = detail_lookup(context, repository, cleaned_name)
    if item == nil then
        log_warn(context, "texlive info failed: " .. tostring(err))
        item = {}
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "texlive", "tex", "latex" },
        writeScopes = { "*" },
        networkScopes = { "*" },
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
