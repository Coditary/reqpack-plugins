plugin = {}

local PLUGIN_ID = "ctan"
local PLUGIN_NAME = "CTAN"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "tlmgr"
local DEFAULT_REPOSITORY = "ctan"
local JSON_NULL = {}

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

local function get_plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR)
    if dir ~= "" then
        return dir
    end
    return "c/ctan"
end

local function data_root_from_context(context, packages)
    local context_flags = context and context.flags or {}
    local from_context = flag_value(context_flags, "data-root=")
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
        texmf_home = join_path(base, "texmf-home"),
        texmf_var = join_path(base, "texmf-var"),
        texmf_config = join_path(base, "texmf-config"),
        downloads = join_path(base, "downloads"),
    }
end

local function env_prefix(paths)
    return table.concat({
        "TEXMFHOME=" .. shell_quote(paths.texmf_home),
        "TEXMFVAR=" .. shell_quote(paths.texmf_var),
        "TEXMFCONFIG=" .. shell_quote(paths.texmf_config),
        "TL_DOWNLOAD_DIRECTORY=" .. shell_quote(paths.downloads),
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
        "NO_COLOR='1'",
    }, " ")
end

local function repository_from_flags(flags, fallback)
    local override = flag_value(flags or {}, "repository=")
    if override ~= "" then
        return override
    end
    return fallback or DEFAULT_REPOSITORY
end

local function tlmgr_command(paths, repository, args)
    local parts = {
        env_prefix(paths),
        REQUIRED_BINARY,
        shell_quote("--usermode"),
        shell_quote("--usertree"),
        shell_quote(paths.texmf_home),
        shell_quote("--repository"),
        shell_quote(repository or DEFAULT_REPOSITORY),
    }
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

local function available_or_read_empty()
    if command_exists(REQUIRED_BINARY) then
        return true
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function ensure_data_dirs(context, paths)
    local result = exec_run(context, "mkdir -p "
        .. shell_quote(paths.root) .. " "
        .. shell_quote(paths.texmf_home) .. " "
        .. shell_quote(paths.texmf_var) .. " "
        .. shell_quote(paths.texmf_config) .. " "
        .. shell_quote(paths.downloads))
    return result ~= nil and result.success == true
end

local function ensure_user_tree(context, paths, repository)
    if not ensure_data_dirs(context, paths) then
        return false, "failed to prepare CTAN data directories"
    end
    local result = exec_run(context, tlmgr_command(paths, repository, { "init-usertree" }))
    if result == nil or result.success ~= true then
        return false, "failed to initialize tlmgr user tree"
    end
    return true
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
        return nil, "missing CTAN package name"
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
    if json_value(item.available) == false then
        return nil
    end

    local installed = json_value(item.installed) == true
    local local_rev = json_value(item.localrev) or json_value(item.lrev)
    local remote_rev = json_value(item.remoterev) or json_value(item.rrev)
    local extra = {}
    local relocatable = json_value(item.relocatable)
    if relocatable ~= nil then
        extra.relocatable = relocatable == true or tostring(relocatable) == "1"
    end
    local depends = json_value(item.depends)
    if depends ~= nil then
        extra.depends = depends
    end

    local catalog = json_value(item.rcataloguedata) or json_value(item.cataloguedata)
    if type(catalog) == "table" then
        local version = json_value(catalog.version)
        local date = json_value(catalog.date)
        local license = json_value(catalog.license)
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

    local version = installed and non_empty(local_rev) or non_empty(remote_rev) or non_empty(local_rev)
    local latest = non_empty(remote_rev) or version
    local status = installed and "installed" or "available"
    if installed and latest ~= nil and version ~= nil and latest ~= version then
        status = "outdated"
    end

    return {
        name = name,
        packageId = name,
        version = version,
        latestVersion = latest,
        installed = installed,
        status = status,
        packageType = non_empty(json_value(item.category)) or "package",
        summary = non_empty(json_value(item.shortdesc)),
        description = non_empty(json_value(item.longdesc)),
        extraFields = maybe_extra_fields(extra),
    }
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
    return items
end

local function info_command(context, paths, repository, name)
    return exec_run(context, tlmgr_command(paths, repository, { "info", "--json", name }))
end

local function detail_lookup(context, paths, repository, name)
    local result = info_command(context, paths, repository, name)
    if result == nil or result.success ~= true then
        return nil, result and result.stderr or "info failed"
    end
    return parse_info(result.stdout, name)
end

local function query_list_items(context, paths, repository)
    local result = exec_run(context, tlmgr_command(paths, repository, {
        "info",
        "--only-installed",
        "--data",
        "name,category,localrev,shortdesc,relocatable",
    }))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_list(result.stdout)
end

local function query_outdated_items(context, paths, repository, names)
    local args = { "--machine-readable", "update", "--list" }
    for _, name in ipairs(names or {}) do
        args[#args + 1] = name
    end
    local result = exec_run(context, tlmgr_command(paths, repository, args))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_outdated(result.stdout)
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

    local paths = state_paths(data_root_from_context(nil, requested))
    local repository = repository_from_flags({}, DEFAULT_REPOSITORY)
    local listed = query_list_items(nil, paths, repository)
    if listed == nil then
        return requested
    end

    local installed = installed_set(listed)
    local needs_update = false
    for _, pkg in ipairs(requested) do
        if package_action(pkg) == "update" then
            needs_update = true
            break
        end
    end

    local updateable = nil
    if needs_update then
        local names = {}
        for _, pkg in ipairs(requested) do
            if package_action(pkg) == "update" then
                local name = package_name(pkg)
                if name ~= "" then
                    names[#names + 1] = name
                end
            end
        end
        local outdated = query_outdated_items(nil, paths, repository, names)
        if outdated == nil then
            return requested
        end
        updateable = installed_set(outdated)
    end

    local filtered = {}
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        local action = package_action(pkg)
        local reinstall = has_flag(object_flags(pkg), "reinstall")
        if action == "remove" then
            if installed[name] == true then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "update" then
            if updateable ~= nil and updateable[name] == true then
                filtered[#filtered + 1] = pkg
            end
        elseif installed[name] ~= true or reinstall then
            filtered[#filtered + 1] = pkg
        end
    end
    return filtered
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end

    local available, message = available_or_read_empty()
    if not available then
        return package_error(context, message)
    end

    begin_step(context, "install CTAN packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local ok, ensure_message = ensure_user_tree(context, paths, DEFAULT_REPOSITORY)
    if not ok then
        return package_error(context, ensure_message)
    end

    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end

        local flags = package_flags_with_context(context, raw_pkg)
        local repository = repository_from_flags(flags, DEFAULT_REPOSITORY)
        local info_item, info_err = detail_lookup(context, paths, repository, pkg.name)
        if info_item ~= nil and info_item.extraFields ~= nil and info_item.extraFields.relocatable == false then
            return package_error(context, "ctan install requires relocatable package in tlmgr user mode: " .. pkg.name)
        end
        if info_item == nil and info_err ~= nil then
            log_warn(context, "ctan info preflight failed for " .. pkg.name)
        end

        local args = tlmgr_args_for_pkg(pkg, "install")
        args[#args + 1] = pkg.name
        local result = exec_run(context, tlmgr_command(paths, repository, args))
        if result == nil or result.success ~= true then
            return package_error(context, "ctan install failed for " .. pkg.name)
        end
    end

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

    local available, message = available_or_read_empty()
    if not available then
        return package_error(context, message)
    end

    begin_step(context, "install local CTAN package")
    local paths = state_paths(data_root_from_context(context, {}))
    local ok, ensure_message = ensure_user_tree(context, paths, DEFAULT_REPOSITORY)
    if not ok then
        return package_error(context, ensure_message)
    end

    local result = exec_run(context, tlmgr_command(paths, DEFAULT_REPOSITORY, { "install", "--file", local_path }))
    if result == nil or result.success ~= true then
        return package_error(context, "ctan local install failed; tlmgr expects TeX Live package container input")
    end

    emit_event(context, "installed", { path = local_path, localTarget = true })
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end

    local available, message = available_or_read_empty()
    if not available then
        return package_error(context, message)
    end

    begin_step(context, "remove CTAN packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local ok, ensure_message = ensure_user_tree(context, paths, DEFAULT_REPOSITORY)
    if not ok then
        return package_error(context, ensure_message)
    end

    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        local repository = repository_from_flags(package_flags_with_context(context, raw_pkg), DEFAULT_REPOSITORY)
        local args = tlmgr_args_for_pkg(pkg, "remove")
        args[#args + 1] = pkg.name
        local result = exec_run(context, tlmgr_command(paths, repository, args))
        if result == nil or result.success ~= true then
            return package_error(context, "ctan remove failed for " .. pkg.name)
        end
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    local available, message = available_or_read_empty()
    if not available then
        return package_error(context, message)
    end

    begin_step(context, "update CTAN packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local ok, ensure_message = ensure_user_tree(context, paths, DEFAULT_REPOSITORY)
    if not ok then
        return package_error(context, ensure_message)
    end

    if #requested == 0 then
        local result = exec_run(context, tlmgr_command(paths, DEFAULT_REPOSITORY, { "update", "--all" }))
        if result == nil or result.success ~= true then
            return package_error(context, "ctan update failed")
        end
        emit_event(context, "updated", {})
        tx_success(context)
        emit_event(context, "success", "ok")
        return true
    end

    local repository = DEFAULT_REPOSITORY
    local names = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        local flags = package_flags_with_context(context, raw_pkg)
        repository = repository_from_flags(flags, repository)
        local info_item, info_err = detail_lookup(context, paths, repository, pkg.name)
        if info_item ~= nil and info_item.extraFields ~= nil and info_item.extraFields.relocatable == false then
            return package_error(context, "ctan update requires relocatable package in tlmgr user mode: " .. pkg.name)
        end
        if info_item == nil and info_err ~= nil then
            log_warn(context, "ctan info preflight failed for " .. pkg.name)
        end
        names[#names + 1] = pkg.name
    end

    local result = exec_run(context, tlmgr_command(paths, repository, { "update", table.unpack(names) }))
    if result == nil or result.success ~= true then
        return package_error(context, "ctan update failed")
    end

    emit_event(context, "updated", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.list(context)
    local available, message = available_or_read_empty()
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "listed", items)
        return items
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local items = query_list_items(context, paths, DEFAULT_REPOSITORY)
    if items == nil then
        log_warn(context, "ctan list failed")
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local available, message = available_or_read_empty()
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "outdated", items)
        return items
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local items = query_outdated_items(context, paths, DEFAULT_REPOSITORY, nil)
    if items == nil then
        log_warn(context, "ctan outdated failed")
        items = {}
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

    local available, message = available_or_read_empty()
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "searched", items)
        return items
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local result = exec_run(context, tlmgr_command(paths, DEFAULT_REPOSITORY, { "search", "--global", "--json", cleaned_prompt }))
    if result == nil or result.success ~= true then
        log_warn(context, "ctan search failed")
        local items = {}
        emit_event(context, "searched", items)
        return items
    end

    local items, err = parse_search(result.stdout)
    if items == nil then
        log_warn(context, "ctan search JSON parse failed: " .. tostring(err))
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

    local available, message = available_or_read_empty()
    if not available then
        log_warn(context, message)
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local item, err = detail_lookup(context, paths, DEFAULT_REPOSITORY, cleaned_name)
    if item == nil then
        log_warn(context, "ctan info JSON parse failed: " .. tostring(err))
        item = {}
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "ctan", "texlive" },
        writeScopes = {
            "plugin-data:c/ctan/.reqpack-data/texmf-home",
            "plugin-data:c/ctan/.reqpack-data/texmf-var",
            "plugin-data:c/ctan/.reqpack-data/texmf-config",
            "plugin-data:c/ctan/.reqpack-data/downloads",
        },
        networkScopes = {
            "https://mirror.ctan.org",
            "https://ctan.org",
        },
        privilegeLevel = "none",
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
