plugin = {}

local PLUGIN_ID = "rtx"
local PLUGIN_NAME = "rtx"
local PLUGIN_VERSION = "0.1.0"
local DEFAULT_SEARCH_LIMIT = 20
local JSON_NULL = {}

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
        lines[#lines + 1] = line
    end
    return lines
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function command_quote(value)
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,%[%]]+$") ~= nil then
        return text
    end
    return shell_quote(text)
end

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
end

local function merge_tables(left, right)
    local merged = shallow_copy(type(left) == "table" and left or {})
    for key, value in pairs(type(right) == "table" and right or {}) do
        merged[key] = value
    end
    if next(merged) == nil then
        return nil
    end
    return merged
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

local function run_exec(context, command)
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

local function command_exists(context, binary)
    local result = run_exec(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function detect_binary(context)
    for _, candidate in ipairs({ "rtx", "mise" }) do
        if command_exists(context, candidate) then
            return candidate
        end
    end
    return nil
end

local function ensure_available(context)
    local binary = detect_binary(context)
    if binary ~= nil then
        return binary
    end
    return nil, "rtx or mise binary not available"
end

local function parent_dir(path)
    return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
end

local function ensure_directory(path)
    local dir = trim(path)
    if dir == "" or dir == "." then
        return true
    end
    if os == nil or type(os.execute) ~= "function" then
        return false
    end
    local ok, kind, code = os.execute("mkdir -p " .. shell_quote(dir))
    if ok == true then
        return true
    end
    if type(ok) == "number" then
        return ok == 0
    end
    return code == 0 or kind == "exit"
end

local function basename(path)
    local text = trim(path):gsub("[/\\]+$", "")
    if text == "" then
        return ""
    end
    return text:match("[^/\\]+$") or text
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

local function append_unique(list, value, seen)
    local text = trim(value)
    if text == "" or seen[text] then
        return
    end
    seen[text] = true
    list[#list + 1] = text
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

local function cache_root(context, packages)
    local raw_flags = collect_raw_flags(context, packages)
    local explicit = flag_value(raw_flags, "cache-root")
    if explicit ~= nil and explicit ~= "" then
        return explicit
    end
    return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
end

local function shared_paths(context, packages)
    local root = cache_root(context, packages)
    return {
        root = root,
        data = join_path(root, "data"),
        cache = join_path(root, "cache"),
        state = join_path(root, "state"),
        config = join_path(root, "config"),
        tmp = join_path(root, "tmp"),
    }
end

local function ensure_shared_paths(paths)
    for _, key in ipairs({ "root", "data", "cache", "state", "config", "tmp" }) do
        if not ensure_directory(paths[key]) then
            return false
        end
    end
    return true
end

local function env_prefix(paths)
    return table.concat({
        "RTX_DATA_DIR=" .. shell_quote(paths.data),
        "RTX_CACHE_DIR=" .. shell_quote(paths.cache),
        "RTX_STATE_DIR=" .. shell_quote(paths.state),
        "RTX_CONFIG_DIR=" .. shell_quote(paths.config),
        "RTX_TMP_DIR=" .. shell_quote(paths.tmp),
        "MISE_DATA_DIR=" .. shell_quote(paths.data),
        "MISE_CACHE_DIR=" .. shell_quote(paths.cache),
        "MISE_STATE_DIR=" .. shell_quote(paths.state),
        "MISE_CONFIG_DIR=" .. shell_quote(paths.config),
        "MISE_TMP_DIR=" .. shell_quote(paths.tmp),
        "NO_COLOR='1'",
        "CLICOLOR='0'",
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
    }, " ")
end

local function build_command(context, packages, binary, args)
    local paths = shared_paths(context, packages)
    ensure_shared_paths(paths)
    local parts = { env_prefix(paths), command_quote(binary) }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = command_quote(arg)
    end
    return table.concat(parts, " ")
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

    local value = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("unexpected trailing content")
    end
    return value
end

local function decode_json(raw)
    local ok, result = pcall(decode_json_internal, raw)
    if ok then
        return result
    end
    return nil, result
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

local function package_name(package)
    return trim(first_nonempty(
        read_field(package, "name"),
        read_field(package, "packageId"),
        read_field(package, "packageName")
    ) or "")
end

local function package_version(package)
    return trim(read_field(package, "version") or "")
end

local function parse_name_and_version(value)
    local text = trim(value)
    local name, version = text:match("^(.-)@([^@]+)$")
    if name ~= nil and trim(name) ~= "" and trim(version) ~= "" then
        return trim(name), trim(version)
    end
    return text, ""
end

local function package_requested_name(package)
    local name = package_name(package)
    if name == "" then
        return ""
    end
    local actual_name, embedded = parse_name_and_version(name)
    if embedded ~= "" and package_version(package) == "" then
        return actual_name
    end
    return name
end

local function package_requested_version(package)
    local explicit = package_version(package)
    if explicit ~= "" then
        return explicit
    end
    local _, embedded = parse_name_and_version(package_name(package))
    return embedded
end

local function package_spec(package)
    local name = package_requested_name(package)
    local version = package_requested_version(package)
    if name == "" then
        return ""
    end
    if version ~= "" then
        return name .. "@" .. version
    end
    return name
end

local function local_link_spec(context, path)
    local flags = collect_raw_flags(context, nil)
    local name = trim(flag_value(flags, "name") or basename(path))
    local version = trim(flag_value(flags, "version") or "local")
    if name == "" then
        return nil
    end
    return name, version, name .. "@" .. version
end

local function make_item(name, version, latest_version, fields)
    local item = {
        name = trim(name or ""),
        packageId = trim(name or ""),
        packageType = "tool",
        version = trim(version or ""),
        latestVersion = trim(latest_version or ""),
    }
    if item.version == "" then
        item.version = nil
    end
    if item.latestVersion == "" then
        item.latestVersion = item.version
    end
    if type(fields) == "table" then
        for key, value in pairs(fields) do
            item[key] = value
        end
    end
    return item
end

local function parse_ls_json(raw, binary)
    local decoded = decode_json(raw)
    if type(decoded) ~= "table" then
        return {}
    end

    local items = {}
    for name, entries in pairs(decoded) do
        if type(entries) == "table" then
            for _, entry in ipairs(entries) do
                local source = json_value(read_field(entry, "source"))
                local install_path = first_nonempty(
                    json_value(read_field(entry, "install_path")),
                    json_value(read_field(entry, "installPath")),
                    json_value(read_field(entry, "path"))
                )
                local version = first_nonempty(
                    json_value(read_field(entry, "version")),
                    json_value(read_field(entry, "latestVersion")),
                    json_value(read_field(entry, "latest_version"))
                )
                local requested = nil
                if type(source) == "table" then
                    requested = first_nonempty(
                        json_value(read_field(source, "requested")),
                        json_value(read_field(source, "version")),
                        json_value(read_field(source, "path")),
                        json_value(read_field(source, "type"))
                    )
                end
                items[#items + 1] = make_item(name, version, version, {
                    extraFields = {
                        installPath = install_path,
                        source = source,
                        requested = requested,
                        binary = binary,
                    },
                })
            end
        end
    end
    table.sort(items, function(left, right)
        local left_key = lower(trim(left.name or "") .. "@" .. trim(left.version or ""))
        local right_key = lower(trim(right.name or "") .. "@" .. trim(right.version or ""))
        return left_key < right_key
    end)
    return items
end

local function load_installed_items(context, binary, names)
    local args = { "ls", "--installed", "--json" }
    for _, name in ipairs(names or {}) do
        if trim(name) ~= "" then
            args[#args + 1] = trim(name)
        end
    end
    local result = run_exec(context, build_command(context, nil, binary, args))
    if result == nil or result.success ~= true then
        return {}
    end
    return parse_ls_json(result.stdout, binary)
end

local function installed_index_by_name(items)
    local index = {}
    for _, item in ipairs(items or {}) do
        local key = trim(item.name or "")
        if key ~= "" then
            index[key] = index[key] or {}
            index[key][#index[key] + 1] = item
        end
    end
    return index
end

local function installed_matches(items, version)
    if trim(version or "") == "" then
        return items or {}
    end
    local matches = {}
    for _, item in ipairs(items or {}) do
        if trim(item.version or "") == trim(version) then
            matches[#matches + 1] = item
        end
    end
    return matches
end

local function parse_search_output(raw)
    local items = {}
    for _, line in ipairs(split_lines(raw)) do
        local text = trim(line)
        if text ~= "" then
            local name, summary = text:match("^(%S+)%s+(.+)$")
            if name == nil then
                name = text
                summary = nil
            end
            items[#items + 1] = make_item(name, nil, nil, {
                summary = trim(summary or "") ~= "" and trim(summary) or nil,
                description = trim(summary or "") ~= "" and trim(summary) or nil,
            })
        end
    end
    return items
end

local function search_remote(context, binary, prompt, match_type)
    local args = { "search", "--match-type", match_type or "contains", "--no-header", prompt }
    local result = run_exec(context, build_command(context, nil, binary, args))
    if result == nil or result.success ~= true then
        local stderr = result ~= nil and result.stderr or nil
        return nil, first_nonempty(stderr, "search failed")
    end
    return parse_search_output(result.stdout)
end

local function latest_version(context, binary, name, version, packages)
    local args = { "latest" }
    local spec = trim(name or "")
    if spec == "" then
        return nil
    end
    if trim(version or "") ~= "" then
        spec = spec .. "@" .. trim(version)
    end
    local flags = collect_raw_flags(context, packages)
    local min_age = trim(flag_value(flags, "minimum-release-age") or "")
    if min_age ~= "" then
        args[#args + 1] = "--minimum-release-age"
        args[#args + 1] = min_age
    end
    args[#args + 1] = spec
    local result = run_exec(context, build_command(context, packages, binary, args))
    if result == nil or result.success ~= true then
        return nil
    end
    for _, line in ipairs(split_lines(result.stdout)) do
        local text = trim(line)
        if text ~= "" then
            return text
        end
    end
    return nil
end

local function merge_remote_with_installed(remote, installed)
    if remote == nil and installed == nil then
        return nil
    end
    local item = shallow_copy(remote or installed or {})
    item.name = first_nonempty(installed and installed.name, remote and remote.name)
    item.packageId = first_nonempty(item.name, installed and installed.packageId, remote and remote.packageId)
    item.packageType = first_nonempty(installed and installed.packageType, remote and remote.packageType, "tool")
    item.version = first_nonempty(installed and installed.version, remote and remote.version, remote and remote.latestVersion)
    item.latestVersion = first_nonempty(remote and remote.latestVersion, installed and installed.latestVersion, item.version)
    item.summary = first_nonempty(remote and remote.summary, installed and installed.summary)
    item.description = first_nonempty(remote and remote.description, installed and installed.description, item.summary)
    item.extraFields = merge_tables(installed and installed.extraFields, remote and remote.extraFields)
    if item.version ~= nil and item.latestVersion ~= nil and trim(item.version) ~= trim(item.latestVersion) then
        item.status = "outdated"
    elseif installed ~= nil then
        item.status = "installed"
    else
        item.status = "available"
    end
    return item
end

local function request_name_list(packages)
    local names = {}
    local seen = {}
    for _, package in ipairs(packages or {}) do
        append_unique(names, package_requested_name(package), seen)
    end
    return names
end

local function install_flags(context, packages)
    local flags = collect_raw_flags(context, packages)
    local args = {}
    if has_flag(flags, "force") then
        args[#args + 1] = "--force"
    end
    local jobs = trim(flag_value(flags, "jobs") or "")
    if jobs ~= "" then
        args[#args + 1] = "--jobs"
        args[#args + 1] = jobs
    end
    local min_age = trim(flag_value(flags, "minimum-release-age") or "")
    if min_age ~= "" then
        args[#args + 1] = "--minimum-release-age"
        args[#args + 1] = min_age
    end
    if has_flag(flags, "raw") then
        args[#args + 1] = "--raw"
    end
    return args
end

local function update_flags(context, packages)
    local flags = collect_raw_flags(context, packages)
    local args = {}
    if has_flag(flags, "bump") then
        args[#args + 1] = "--bump"
    end
    local jobs = trim(flag_value(flags, "jobs") or "")
    if jobs ~= "" then
        args[#args + 1] = "--jobs"
        args[#args + 1] = jobs
    end
    local min_age = trim(flag_value(flags, "minimum-release-age") or "")
    if min_age ~= "" then
        args[#args + 1] = "--minimum-release-age"
        args[#args + 1] = min_age
    end
    if has_flag(flags, "raw") then
        args[#args + 1] = "--raw"
    end
    return args
end

local function enrich_search_items(context, binary, remote_items, installed_items)
    local installed = installed_index_by_name(installed_items)
    local enriched = {}
    for _, remote in ipairs(remote_items or {}) do
        local merged = merge_remote_with_installed(remote, (installed[remote.name or ""] or {})[1])
        enriched[#enriched + 1] = merged
    end
    return enriched
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
    return { "version-manager", "development-tools" }
end

function plugin.getMissingPackages(packages)
    packages = packages or {}
    local binary = detect_binary(nil)
    if binary == nil then
        return packages
    end
    local installed = installed_index_by_name(load_installed_items(nil, binary, request_name_list(packages)))
    local missing = {}
    for _, package in ipairs(packages) do
        local name = package_requested_name(package)
        local version = package_requested_version(package)
        local matches = installed_matches(installed[name] or {}, version)
        if #matches == 0 then
            missing[#missing + 1] = package
        end
    end
    return missing
end

function plugin.install(context, packages)
    packages = packages or {}
    if #packages == 0 then
        return true
    end
    local binary, err = ensure_available(context)
    if binary == nil then
        tx_failed(context, err)
        return false
    end

    local installed = {}
    for _, package in ipairs(packages) do
        local spec = package_spec(package)
        if spec ~= "" then
            begin_step(context, "install " .. spec)
            local args = { "install" }
            for _, flag in ipairs(install_flags(context, { package })) do
                args[#args + 1] = flag
            end
            args[#args + 1] = spec
            local result = run_exec(context, build_command(context, { package }, binary, args))
            if result == nil or result.success ~= true then
                tx_failed(context, "rtx install failed")
                return false
            end
            local items = load_installed_items(context, binary, { package_requested_name(package) })
            local matches = installed_matches(items, package_requested_version(package))
            installed[#installed + 1] = matches[1] or make_item(package_requested_name(package), package_requested_version(package), package_requested_version(package), {
                status = "installed",
                extraFields = { binary = binary },
            })
        end
    end

    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" then
        tx_failed(context, "rtx local install failed")
        return false
    end
    local binary, err = ensure_available(context)
    if binary == nil then
        tx_failed(context, err)
        return false
    end
    local name, version, spec = local_link_spec(context, local_path)
    if spec == nil then
        tx_failed(context, "rtx local install failed")
        return false
    end

    begin_step(context, "link local tool " .. spec)
    local args = { "link" }
    if has_flag(collect_raw_flags(context, nil), "force") then
        args[#args + 1] = "--force"
    end
    args[#args + 1] = spec
    args[#args + 1] = local_path
    local result = run_exec(context, build_command(context, nil, binary, args))
    if result == nil or result.success ~= true then
        tx_failed(context, "rtx local install failed")
        return false
    end

    local items = load_installed_items(context, binary, { name })
    local matches = installed_matches(items, version)
    emit_event(context, "installed", matches[1] or {
        name = name,
        packageId = name,
        packageType = "tool",
        version = version,
        latestVersion = version,
        localTarget = true,
        path = local_path,
        extraFields = {
            binary = binary,
            installPath = local_path,
        },
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    packages = packages or {}
    if #packages == 0 then
        return true
    end
    local binary, err = ensure_available(context)
    if binary == nil then
        tx_failed(context, err)
        return false
    end

    local installed = installed_index_by_name(load_installed_items(context, binary, request_name_list(packages)))
    local specs = {}
    local deleted = {}
    for _, package in ipairs(packages) do
        local matches = installed_matches(installed[package_requested_name(package)] or {}, package_requested_version(package))
        for _, item in ipairs(matches) do
            specs[#specs + 1] = item.name .. "@" .. trim(item.version or "")
            deleted[#deleted + 1] = item
        end
    end
    if #specs == 0 then
        return true
    end

    begin_step(context, "remove rtx tools")
    local args = { "uninstall" }
    for _, spec in ipairs(specs) do
        args[#args + 1] = spec
    end
    local result = run_exec(context, build_command(context, packages, binary, args))
    if result == nil or result.success ~= true then
        tx_failed(context, "rtx uninstall failed")
        return false
    end

    emit_event(context, "deleted", deleted)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    packages = packages or {}
    local binary, err = ensure_available(context)
    if binary == nil then
        tx_failed(context, err)
        return false
    end

    local flags = collect_raw_flags(context, packages)
    local installed_items = load_installed_items(context, binary, request_name_list(packages))
    if #packages == 0 and has_flag(flags, "all") then
        installed_items = load_installed_items(context, binary, nil)
    end
    local installed = installed_index_by_name(installed_items)
    local specs = {}
    local updated = {}

    if #packages == 0 and has_flag(flags, "all") then
        for _, item in ipairs(installed_items) do
            specs[#specs + 1] = item.name .. "@" .. trim(item.version or "")
            updated[#updated + 1] = item
        end
    else
        for _, package in ipairs(packages) do
            local matches = installed_matches(installed[package_requested_name(package)] or {}, package_requested_version(package))
            for _, item in ipairs(matches) do
                specs[#specs + 1] = item.name .. "@" .. trim(item.version or "")
                updated[#updated + 1] = item
            end
        end
    end

    if #specs == 0 then
        return true
    end

    begin_step(context, "update rtx tools")
    local args = { "upgrade" }
    for _, flag in ipairs(update_flags(context, packages)) do
        args[#args + 1] = flag
    end
    for _, spec in ipairs(specs) do
        args[#args + 1] = spec
    end
    local result = run_exec(context, build_command(context, packages, binary, args))
    if result == nil or result.success ~= true then
        tx_failed(context, "rtx upgrade failed")
        return false
    end

    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local binary = detect_binary(context)
    if binary == nil then
        emit_event(context, "unavailable", { reason = "rtx-or-mise-not-installed" })
        return {}
    end
    local items = load_installed_items(context, binary, nil)
    emit_event(context, "listed", items)
    return items
end

function plugin.search(context, prompt)
    local binary = detect_binary(context)
    if binary == nil then
        emit_event(context, "unavailable", { reason = "rtx-or-mise-not-installed" })
        return {}
    end

    local search_prompt = trim(prompt)
    if search_prompt == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local flags = collect_raw_flags(context, nil)
    local match_type = trim(flag_value(flags, "match-type") or "contains")
    local limit = tonumber(flag_value(flags, "limit") or "") or DEFAULT_SEARCH_LIMIT
    local remote_items, search_err = search_remote(context, binary, search_prompt, match_type)
    if remote_items == nil then
        log_warn(context, "rtx search failed: " .. tostring(search_err or "unknown error"))
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    local items = enrich_search_items(context, binary, remote_items, load_installed_items(context, binary, nil))
    while #items > limit do
        table.remove(items)
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local binary = detect_binary(context)
    if binary == nil then
        emit_event(context, "unavailable", { reason = "rtx-or-mise-not-installed" })
        return {}
    end

    local requested = trim(name)
    if requested == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local requested_name, requested_version = parse_name_and_version(requested)
    local installed = installed_matches(load_installed_items(context, binary, { requested_name }), requested_version)
    local remote_items = search_remote(context, binary, requested_name, "equal") or {}
    local remote = nil
    for _, item in ipairs(remote_items) do
        if trim(item.name or "") == requested_name then
            remote = item
            break
        end
    end
    local latest = latest_version(context, binary, requested_name, requested_version ~= "" and requested_version or nil, nil)
    if remote ~= nil or latest ~= nil then
        remote = merge_remote_with_installed(make_item(requested_name, latest, latest, {
            summary = remote and remote.summary or nil,
            description = remote and remote.description or nil,
            extraFields = { binary = binary },
        }), nil)
    end
    local item = merge_remote_with_installed(remote, installed[1])
    if item == nil then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.outdated(context)
    local binary = detect_binary(context)
    if binary == nil then
        emit_event(context, "unavailable", { reason = "rtx-or-mise-not-installed" })
        return {}
    end

    local installed = load_installed_items(context, binary, nil)
    local latest_cache = {}
    local items = {}
    for _, item in ipairs(installed) do
        local key = item.name or ""
        if latest_cache[key] == nil then
            latest_cache[key] = latest_version(context, binary, item.name, nil, nil) or false
        end
        local latest = latest_cache[key]
        if latest ~= false and trim(latest or "") ~= "" and trim(latest) ~= trim(item.version or "") then
            items[#items + 1] = merge_remote_with_installed(make_item(item.name, latest, latest, {
                extraFields = { binary = binary },
            }), item)
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.resolvePackage(context, package)
    local binary = detect_binary(context)
    if binary == nil then
        return nil
    end
    local name = package_requested_name(package)
    if name == "" then
        return nil
    end
    local requested_version = package_requested_version(package)
    local installed = installed_matches(load_installed_items(context, binary, { name }), requested_version)
    local latest = latest_version(context, binary, name, requested_version ~= "" and requested_version or nil, { package })
    local remote = nil
    if latest ~= nil then
        remote = make_item(name, latest, latest, {
            extraFields = { binary = binary },
        })
    end
    return merge_remote_with_installed(remote, installed[1])
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "rtx", "mise", "dev-tools" },
        writeScopes = {
            { kind = "user-home-subpath", path = ".cache/reqpack/rtx" },
        },
        networkScopes = {
            { host = "mise-versions.jdx.dev", scheme = "https", pathPrefix = "/" },
            { host = "github.com", scheme = "https", pathPrefix = "/" },
            { host = "raw.githubusercontent.com", scheme = "https", pathPrefix = "/" },
        },
        privilegeLevel = "user",
    }
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

return plugin
