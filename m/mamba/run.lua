plugin = {}

local PLUGIN_ID = "mamba"
local PLUGIN_NAME = "Mamba"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "mamba"
local JSON_NULL = {}

plugin.fileExtensions = { ".conda", ".json", ".tar.bz2", ".txt", ".yaml", ".yml" }

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

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
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

local function exec_run(context, command)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return context.exec.run(command)
    end
    return reqpack.exec.run(command)
end

local function command_exists(binary)
    local result = reqpack.exec.run("command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function package_error(context, message, payload)
    tx_failed(context, message)
    if payload ~= nil then
        emit_event(context, "unavailable", payload)
    end
    return false
end

local function ensure_available(context, fatal)
    if command_exists(REQUIRED_BINARY) then
        return true
    end

    local message = "mamba command not available"
    if fatal then
        tx_failed(context, message)
        emit_event(context, "unavailable", { reason = "mamba-not-installed" })
    else
        log_warn(context, message)
    end
    return false
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
        decode_error("unexpected trailing content")
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

local function normalize_flags(flags)
    local result = {}
    if type(flags) == "table" then
        for _, flag in ipairs(flags) do
            local text = trim(flag)
            if text ~= "" then
                result[#result + 1] = text
            end
        end
    elseif type(flags) == "string" then
        local text = trim(flags)
        if text ~= "" then
            result[#result + 1] = text
        end
    end
    return result
end

local function select_prefix(context)
    local request = read_field(context, "request") or {}
    return non_empty(read_field(context, "prefix"))
        or non_empty(read_field(request, "prefix"))
        or "/"
end

local function local_path_from_context(context)
    local request = read_field(context, "request") or {}
    return trim(read_field(context, "localPath") or read_field(request, "localPath") or "")
end

local function join_command(parts)
    return table.concat(parts, " ")
end

local function append_arg(parts, value)
    parts[#parts + 1] = shell_quote(value)
end

local function append_option(parts, name, value)
    parts[#parts + 1] = name
    append_arg(parts, value)
end

local function add_package_flags(parts, package, allowed)
    local allowed_set = {}
    for _, item in ipairs(allowed or {}) do
        allowed_set[item] = true
    end

    for _, flag in ipairs(normalize_flags(read_field(package, "flags"))) do
        local key, value = flag:match("^([^=]+)=(.+)$")
        if key == "channel" and allowed_set.channel then
            append_option(parts, "--channel", value)
        elseif flag == "override-channels" and allowed_set.override_channels then
            parts[#parts + 1] = "--override-channels"
        elseif flag == "no-deps" and allowed_set.no_deps then
            parts[#parts + 1] = "--no-deps"
        elseif flag == "only-deps" and allowed_set.only_deps then
            parts[#parts + 1] = "--only-deps"
        elseif flag == "force-reinstall" and allowed_set.force_reinstall then
            parts[#parts + 1] = "--force-reinstall"
        elseif flag == "freeze-installed" and allowed_set.freeze_installed then
            parts[#parts + 1] = "--freeze-installed"
        elseif flag == "allow-downgrade" and allowed_set.allow_downgrade then
            parts[#parts + 1] = "--allow-downgrade"
        elseif flag == "local" and allowed_set.local_only then
            parts[#parts + 1] = "--local"
        end
    end
end

local function build_spec(name, version)
    local package_name = trim(name)
    if package_name == "" then
        return nil
    end

    local package_version = trim(version)
    if package_version == "" then
        return package_name
    end

    if package_version:match("^[<>=!~]") then
        return package_name .. package_version
    end
    return package_name .. "=" .. package_version
end

local function supports_local_path(path)
    local lowered = lower(path)
    for _, ext in ipairs(plugin.fileExtensions or {}) do
        if lowered:sub(-#ext) == ext then
            return true
        end
    end
    return false
end

local function local_path_uses_file_flag(path)
    local lowered = lower(path)
    return lowered:sub(-4) == ".txt"
        or lowered:sub(-4) == ".yml"
        or lowered:sub(-5) == ".yaml"
        or lowered:sub(-5) == ".json"
end

local function next_version_token(version, index)
    local text = tostring(version or "")
    local length = #text
    local i = index or 1

    while i <= length do
        local char = text:sub(i, i)
        if char:match("[%w]") then
            break
        end
        i = i + 1
    end

    if i > length then
        return nil, nil, i
    end

    local is_number = text:sub(i, i):match("%d") ~= nil
    local start = i
    i = i + 1
    while i <= length do
        local char = text:sub(i, i)
        if is_number then
            if char:match("%d") == nil then
                break
            end
        elseif char:match("%a") == nil then
            break
        end
        i = i + 1
    end

    local token = text:sub(start, i - 1)
    if is_number then
        return "number", tonumber(token), i
    end
    return "string", lower(token), i
end

local function compare_versions(left, right)
    local li = 1
    local ri = 1

    while true do
        local ltype, ltoken, next_li = next_version_token(left, li)
        local rtype, rtoken, next_ri = next_version_token(right, ri)

        if ltype == nil and rtype == nil then
            return 0
        elseif ltype == nil then
            return -1
        elseif rtype == nil then
            return 1
        elseif ltype == rtype then
            if ltoken < rtoken then
                return -1
            elseif ltoken > rtoken then
                return 1
            end
        elseif ltype == "number" then
            return 1
        else
            return -1
        end

        li = next_li
        ri = next_ri
    end
end

local function numeric_value(value)
    local number = tonumber(value)
    if number == nil then
        return 0
    end
    return number
end

local function compare_records(left, right)
    local by_version = compare_versions(read_field(left, "version"), read_field(right, "version"))
    if by_version ~= 0 then
        return by_version
    end

    local left_build = numeric_value(read_field(left, "build_number") or read_field(left, "buildNumber"))
    local right_build = numeric_value(read_field(right, "build_number") or read_field(right, "buildNumber"))
    if left_build < right_build then
        return -1
    elseif left_build > right_build then
        return 1
    end

    local left_timestamp = numeric_value(read_field(left, "timestamp"))
    local right_timestamp = numeric_value(read_field(right, "timestamp"))
    if left_timestamp < right_timestamp then
        return -1
    elseif left_timestamp > right_timestamp then
        return 1
    end

    return 0
end

local function make_extra_fields(record, prefix)
    local extra = {}
    local channel = non_empty(json_value(read_field(record, "channel")))
    local build = non_empty(json_value(read_field(record, "build_string"))) or non_empty(json_value(read_field(record, "build")))
    local build_number = json_value(read_field(record, "build_number")) or json_value(read_field(record, "buildNumber"))
    local fn = non_empty(json_value(read_field(record, "fn")))
    local subdir = non_empty(json_value(read_field(record, "subdir")))

    if channel ~= nil then extra.channel = channel end
    if build ~= nil then extra.build = build end
    if build_number ~= nil then extra.buildNumber = tostring(build_number) end
    if fn ~= nil then extra.fn = fn end
    if subdir ~= nil then extra.subdir = subdir end
    if prefix ~= nil and prefix ~= "" then extra.prefix = prefix end

    if next(extra) == nil then
        return nil
    end
    return extra
end

local function make_package_id(record)
    local name = non_empty(json_value(read_field(record, "name"))) or non_empty(json_value(read_field(record, "packageId")))
    if name == nil then
        return nil
    end

    local channel = non_empty(json_value(read_field(record, "channel")))
    if channel ~= nil then
        return channel .. "/" .. name
    end
    return name
end

local function copy_dependencies(record)
    local dependencies = json_value(read_field(record, "depends"))
    if type(dependencies) ~= "table" or #dependencies == 0 then
        return nil
    end

    local copy = {}
    for _, item in ipairs(dependencies) do
        copy[#copy + 1] = tostring(item)
    end
    return copy
end

local function normalize_record(record, prefix, defaults)
    if type(record) ~= "table" then
        return nil
    end

    local name = non_empty(json_value(read_field(record, "name")))
    if name == nil then
        return nil
    end

    defaults = defaults or {}
    local version = non_empty(json_value(read_field(record, "version"))) or defaults.version
    local latest_version = defaults.latestVersion
    local installed = defaults.installed
    local status = defaults.status

    local item = {
        name = name,
        packageId = make_package_id(record) or name,
        version = version,
        latestVersion = latest_version,
        description = non_empty(json_value(read_field(record, "description"))) or defaults.description,
        summary = non_empty(json_value(read_field(record, "summary"))) or non_empty(json_value(read_field(record, "description"))) or defaults.summary,
        homepage = non_empty(json_value(read_field(record, "homepage"))) or defaults.homepage,
        sourceUrl = non_empty(json_value(read_field(record, "url"))) or defaults.sourceUrl,
        license = non_empty(json_value(read_field(record, "license"))) or defaults.license,
        packageType = "conda",
        type = "package",
        installed = installed,
        status = status,
        dependencies = copy_dependencies(record) or defaults.dependencies,
        extraFields = make_extra_fields(record, prefix) or defaults.extraFields,
    }

    return item
end

local function sort_items(items)
    table.sort(items, function(left, right)
        return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "")
    end)
end

local function choose_best_record(records, package_name, preferred_channel, preferred_subdir)
    local best = nil
    local best_score = nil
    local wanted_name = lower(package_name)

    for _, record in ipairs(records or {}) do
        local name = lower(json_value(read_field(record, "name")) or "")
        if name == wanted_name then
            local score = 0
            local channel = lower(json_value(read_field(record, "channel")) or "")
            local subdir = lower(json_value(read_field(record, "subdir")) or "")

            if preferred_channel ~= nil and channel == lower(preferred_channel) then
                score = score + 4
            end
            if preferred_subdir ~= nil and subdir == lower(preferred_subdir) then
                score = score + 2
            end

            if best == nil or score > best_score or (score == best_score and compare_records(record, best) > 0) then
                best = record
                best_score = score
            end
        end
    end

    return best
end

local function grouped_best_records(records)
    local grouped = {}
    for _, record in ipairs(records or {}) do
        local name = non_empty(json_value(read_field(record, "name")))
        if name ~= nil then
            local channel = non_empty(json_value(read_field(record, "channel"))) or ""
            local key = lower(channel .. "/" .. name)
            local current = grouped[key]
            if current == nil or compare_records(record, current) > 0 then
                grouped[key] = record
            end
        end
    end

    local items = {}
    for _, record in pairs(grouped) do
        items[#items + 1] = record
    end
    table.sort(items, function(left, right)
        local lkey = lower((read_field(left, "channel") or "") .. "/" .. (read_field(left, "name") or ""))
        local rkey = lower((read_field(right, "channel") or "") .. "/" .. (read_field(right, "name") or ""))
        return lkey < rkey
    end)
    return items
end

local function parse_list_items(stdout, prefix)
    local decoded, error_message = decode_json(stdout)
    if decoded == nil then
        return nil, error_message
    end
    if type(decoded) ~= "table" then
        return {}, nil
    end

    local items = {}
    for _, record in ipairs(decoded) do
        local item = normalize_record(record, prefix, { installed = true, status = "installed" })
        if item ~= nil then
            items[#items + 1] = item
        end
    end
    sort_items(items)
    return items, nil
end

local function parse_search_records(stdout)
    local decoded, error_message = decode_json(stdout)
    if decoded == nil then
        return nil, error_message
    end

    local result = json_value(read_field(decoded, "result"))
    local pkgs = json_value(read_field(result, "pkgs"))
    if type(pkgs) ~= "table" then
        return {}, nil
    end

    local records = {}
    for _, record in ipairs(pkgs) do
        if type(record) == "table" then
            records[#records + 1] = record
        end
    end
    return records, nil
end

local function query_list_items(context)
    local prefix = select_prefix(context)
    local result = exec_run(context, "mamba list --json --prefix " .. shell_quote(prefix))
    if result == nil or not result.success then
        return nil, (result and (result.stderr ~= "" and result.stderr or result.stdout)) or "mamba list failed"
    end
    return parse_list_items(result.stdout, prefix)
end

local function parse_search_prompt(prompt)
    local text = trim(prompt)
    local options = {
        query = text,
        channel = nil,
        local_only = false,
    }

    if text:match("^local:%S") then
        options.local_only = true
        options.query = trim(text:sub(7))
    elseif text:match("^channel:%S+") then
        local channel, query = text:match("^channel:([^%s]+)%s+(.+)$")
        if channel ~= nil then
            options.channel = channel
            options.query = trim(query)
        end
    end

    return options
end

local function build_search_command(context, query, options)
    local parts = {
        "mamba",
        "search",
        "--json",
        "--prefix",
        shell_quote(select_prefix(context)),
    }

    options = options or {}
    if non_empty(options.channel) ~= nil then
        parts[#parts + 1] = "--channel"
        append_arg(parts, options.channel)
    end
    if options.local_only then
        parts[#parts + 1] = "--local"
    end
    append_arg(parts, query)
    return join_command(parts)
end

local function query_search_records(context, query, options)
    local result = exec_run(context, build_search_command(context, query, options))
    if result == nil or not result.success then
        return nil, (result and (result.stderr ~= "" and result.stderr or result.stdout)) or "mamba search failed"
    end
    return parse_search_records(result.stdout)
end

local function build_search_items(context, prompt)
    local options = parse_search_prompt(prompt)
    if options.query == "" then
        return {}, nil
    end

    local records, error_message = query_search_records(context, options.query, options)
    if records == nil then
        return nil, error_message
    end

    local items = {}
    for _, record in ipairs(grouped_best_records(records)) do
        local item = normalize_record(record, select_prefix(context), { installed = false, status = "available", latestVersion = read_field(record, "version") })
        if item ~= nil then
            items[#items + 1] = item
        end
    end
    sort_items(items)
    return items, nil
end

local function merge_info(installed_item, remote_record, prefix)
    if installed_item == nil and remote_record == nil then
        return nil
    end
    if installed_item == nil then
        return normalize_record(remote_record, prefix, {
            installed = false,
            status = "available",
            latestVersion = non_empty(json_value(read_field(remote_record, "version"))),
        })
    end
    if remote_record == nil then
        return installed_item
    end

    local latest_version = non_empty(json_value(read_field(remote_record, "version")))
    local status = "installed"
    if latest_version ~= nil and compare_versions(installed_item.version, latest_version) < 0 then
        status = "outdated"
    elseif latest_version ~= nil then
        local remote_build_number = numeric_value(read_field(remote_record, "build_number"))
        local installed_build_number = numeric_value(read_field(installed_item.extraFields or {}, "buildNumber"))
        if remote_build_number > installed_build_number then
            status = "outdated"
        end
    end

    local merged_record = shallow_copy(remote_record)
    merged_record.version = installed_item.version

    return normalize_record(merged_record, prefix, {
        latestVersion = latest_version,
        description = installed_item.description,
        summary = installed_item.summary,
        homepage = installed_item.homepage,
        sourceUrl = installed_item.sourceUrl,
        license = installed_item.license,
        dependencies = installed_item.dependencies,
        extraFields = shallow_copy(installed_item.extraFields),
        installed = true,
        status = status,
    })
end

local function installed_index(items)
    local indexed = {}
    for _, item in ipairs(items or {}) do
        indexed[lower(item.name or "")] = item
    end
    return indexed
end

local function make_requested_item(package, action)
    local name = trim(read_field(package, "name") or "")
    local version = non_empty(read_field(package, "version"))
    local channel = nil
    for _, flag in ipairs(normalize_flags(read_field(package, "flags"))) do
        local key, value = flag:match("^([^=]+)=(.+)$")
        if key == "channel" then
            channel = value
            break
        end
    end

    local extra = {}
    if channel ~= nil then
        extra.channel = channel
    end

    return {
        name = name,
        packageId = channel ~= nil and (channel .. "/" .. name) or name,
        version = version,
        packageType = "conda",
        type = "package",
        installed = action == "install" and true or nil,
        status = action == "update" and "installed" or nil,
        extraFields = next(extra) ~= nil and extra or nil,
    }
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
    return { "Development", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end
    if not ensure_available(nil, false) then
        return packages
    end

    local items = select(1, query_list_items(nil))
    if items == nil then
        return packages
    end

    local installed = installed_index(items)
    local outdated_lookup = nil
    local wants_update = false
    for _, package in ipairs(packages) do
        if lower(read_field(package, "action") or "") == "update" then
            wants_update = true
            break
        end
    end

    if wants_update then
        outdated_lookup = {}
        for _, item in ipairs(plugin.outdated(nil) or {}) do
            outdated_lookup[lower(item.name or "")] = true
        end
    end

    local missing = {}
    for _, package in ipairs(packages) do
        local action = lower(read_field(package, "action") or "")
        local name = lower(read_field(package, "name") or "")
        local local_path = lower(read_field(package, "localPath") or "")
        local is_installed = installed[name] ~= nil

        if local_path ~= "" then
            missing[#missing + 1] = package
        elseif action == "remove" then
            if is_installed then
                missing[#missing + 1] = package
            end
        elseif action == "update" then
            if outdated_lookup ~= nil and outdated_lookup[name] == true then
                missing[#missing + 1] = package
            end
        elseif not is_installed then
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
    if not ensure_available(context, true) then
        return false
    end
    if packages == nil or #packages == 0 then
        return true
    end

    local prefix = select_prefix(context)
    local installed = {}
    for _, package in ipairs(packages) do
        local spec = build_spec(read_field(package, "name"), read_field(package, "version"))
        if spec == nil then
            return package_error(context, "mamba install package name missing")
        end

        begin_step(context, "install mamba package")
        local parts = { "mamba", "install", "--yes", "--json", "--prefix", shell_quote(prefix) }
        add_package_flags(parts, package, {
            "channel", "override_channels", "no_deps", "only_deps", "force_reinstall", "freeze_installed", "allow_downgrade"
        })
        append_arg(parts, spec)

        local result = exec_run(context, join_command(parts))
        if result == nil or not result.success then
            return package_error(context, "mamba install failed")
        end

        installed[#installed + 1] = make_requested_item(package, "install")
    end

    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" then
        return package_error(context, "mamba local install path missing")
    end
    if not supports_local_path(local_path) then
        return package_error(context, "installLocal only supports .conda, .tar.bz2, .txt, .json, .yaml, and .yml", {
            path = local_path,
            reason = "local-install-unsupported",
        })
    end
    if not ensure_available(context, true) then
        return false
    end

    local prefix = select_prefix(context)
    begin_step(context, "install local mamba target")
    local parts = { "mamba", "install", "--yes", "--json", "--prefix", shell_quote(prefix) }
    if local_path_uses_file_flag(local_path) then
        parts[#parts + 1] = "--file"
        append_arg(parts, local_path)
    else
        append_arg(parts, local_path)
    end

    local result = exec_run(context, join_command(parts))
    if result == nil or not result.success then
        return package_error(context, "mamba local install failed")
    end

    emit_event(context, "installed", { path = local_path, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    if not ensure_available(context, true) then
        return false
    end
    if packages == nil or #packages == 0 then
        return true
    end

    local prefix = select_prefix(context)
    local removed = {}
    for _, package in ipairs(packages) do
        local spec = build_spec(read_field(package, "name"), read_field(package, "version"))
        if spec == nil then
            return package_error(context, "mamba remove package name missing")
        end

        begin_step(context, "remove mamba package")
        local command = "mamba remove --yes --json --prefix " .. shell_quote(prefix) .. " " .. shell_quote(spec)
        local result = exec_run(context, command)
        if result == nil or not result.success then
            return package_error(context, "mamba remove failed")
        end

        removed[#removed + 1] = make_requested_item(package, "remove")
    end

    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    if not ensure_available(context, true) then
        return false
    end

    local prefix = select_prefix(context)
    if packages == nil or #packages == 0 then
        begin_step(context, "update all mamba packages")
        local result = exec_run(context, "mamba update --yes --json --prefix " .. shell_quote(prefix) .. " --all")
        if result == nil or not result.success then
            return package_error(context, "mamba update failed")
        end

        emit_event(context, "updated", {})
        tx_success(context)
        return true
    end

    local updated = {}
    for _, package in ipairs(packages) do
        local spec = build_spec(read_field(package, "name"), read_field(package, "version"))
        if spec == nil then
            return package_error(context, "mamba update package name missing")
        end

        begin_step(context, "update mamba package")
        local parts = { "mamba", "update", "--yes", "--json", "--prefix", shell_quote(prefix) }
        add_package_flags(parts, package, {
            "channel", "override_channels", "no_deps", "only_deps", "allow_downgrade"
        })
        append_arg(parts, spec)

        local result = exec_run(context, join_command(parts))
        if result == nil or not result.success then
            return package_error(context, "mamba update failed")
        end

        updated[#updated + 1] = make_requested_item(package, "update")
    end

    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    if not ensure_available(context, false) then
        emit_event(context, "listed", {})
        return {}
    end

    local items, error_message = query_list_items(context)
    if items == nil then
        log_warn(context, error_message)
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    if not ensure_available(context, false) then
        emit_event(context, "outdated", {})
        return {}
    end

    local items, error_message = query_list_items(context)
    if items == nil then
        log_warn(context, error_message)
        emit_event(context, "outdated", {})
        return {}
    end

    local outdated = {}
    local prefix = select_prefix(context)
    for _, item in ipairs(items) do
        local extra = item.extraFields or {}
        local records, search_error = query_search_records(context, item.name, {
            channel = read_field(extra, "channel"),
        })

        if records == nil then
            log_warn(context, search_error)
        else
            local best = choose_best_record(records, item.name, read_field(extra, "channel"), read_field(extra, "subdir"))
            if best ~= nil then
                local latest_version = non_empty(json_value(read_field(best, "version")))
                local newer = false
                if latest_version ~= nil and compare_versions(item.version, latest_version) < 0 then
                    newer = true
                elseif latest_version ~= nil and compare_versions(item.version, latest_version) == 0 then
                    local remote_build = numeric_value(read_field(best, "build_number"))
                    local installed_build = numeric_value(read_field(extra, "buildNumber"))
                    newer = remote_build > installed_build
                end

                if newer then
                    outdated[#outdated + 1] = merge_info(item, best, prefix)
                end
            end
        end
    end

    sort_items(outdated)
    emit_event(context, "outdated", outdated)
    return outdated
end

function plugin.search(context, prompt)
    if not ensure_available(context, false) then
        emit_event(context, "searched", {})
        return {}
    end

    local items, error_message = build_search_items(context, prompt)
    if items == nil then
        log_warn(context, error_message)
        items = {}
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    if trim(name) == "" then
        emit_event(context, "informed", {})
        return {}
    end
    if not ensure_available(context, false) then
        emit_event(context, "informed", {})
        return {}
    end

    local installed_items = plugin.list(context)
    local installed = installed_index(installed_items)
    local installed_item = installed[lower(name)]
    local records, error_message = query_search_records(context, name, {
        channel = installed_item ~= nil and read_field(installed_item.extraFields or {}, "channel") or nil,
    })

    if records == nil then
        log_warn(context, error_message)
        local result = installed_item or {}
        emit_event(context, "informed", result)
        return result
    end

    local best = choose_best_record(
        records,
        name,
        installed_item ~= nil and read_field(installed_item.extraFields or {}, "channel") or nil,
        installed_item ~= nil and read_field(installed_item.extraFields or {}, "subdir") or nil
    )

    local item = merge_info(installed_item, best, select_prefix(context)) or {}
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if package == nil or trim(read_field(package, "name") or "") == "" then
        return nil
    end
    local item = plugin.info(context, package.name)
    if type(item) == "table" and next(item) ~= nil then
        return item
    end
    return make_requested_item(package, "install")
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "conda", "mamba" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".mamba" },
            { kind = "user-home-subpath", value = ".conda" },
            { kind = "user-home-subpath", value = ".cache/conda" },
        },
        privilegeLevel = "user",
        osvEcosystem = "Conda",
        purlType = "conda",
    }
end

function plugin.init()
    return command_exists(REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

return plugin
