plugin = {}

local PLUGIN_ID = "salesforce-apex"
local PLUGIN_NAME = "Salesforce Apex"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "sf"
local JSON_NULL = {}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return trim(value):lower()
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function command_quote(value)
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,]+$") ~= nil then
        return text
    end
    return shell_quote(text)
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

local function is_command_success(result, extra_exit_codes)
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
        for _, allowed in ipairs(extra_exit_codes) do
            if exit_code == allowed then
                return true
            end
        end
    end
    return false
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

local function home_dir()
    if os ~= nil and type(os.getenv) == "function" then
        local value = trim(os.getenv("HOME") or os.getenv("USERPROFILE") or "")
        if value ~= "" then
            return value
        end
    end
    return "/home/test"
end

local function cache_root()
    return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
end

local function cache_file(kind, key)
    return join_path(cache_root(), "query", kind .. "-" .. key .. ".json")
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

local function write_file(path, contents)
    local parent = path:match("^(.*)/[^/]+$")
    if parent == nil or not ensure_directory(parent) then
        return false
    end
    local handle = io.open(path, "w")
    if handle == nil then
        return false
    end
    handle:write(contents)
    handle:close()
    return true
end

local function read_file(path)
    local handle = io.open(path, "r")
    if handle == nil then
        return nil
    end
    local contents = handle:read("*a")
    handle:close()
    return contents
end

local function command_exists(binary)
    return is_command_success(exec_run(nil, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function object_flags(object)
    local value = read_field(object, "flags")
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local flags = {}
    local ok = pcall(function()
        for _, item in ipairs(value) do
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

local function append_unique(list, value, seen)
    local text = trim(value)
    if text == "" or seen[text] then
        return
    end
    seen[text] = true
    list[#list + 1] = text
end

local function collect_flags(context, packages)
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
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            return trim(cleaned:sub(#prefix + 1))
        end
    end
    return nil
end

local function has_flag(flags, key)
    local wanted = lower(trim(key))
    for _, flag in ipairs(flags or {}) do
        if lower(flag) == wanted then
            return true
        end
    end
    return false
end

local function base_env_prefix()
    return table.concat({
        "NO_COLOR=1",
        "CLICOLOR=0",
        "LC_ALL=C",
        "LANG=C",
        "LANGUAGE=C",
        "SHELL=/bin/sh",
    }, " ")
end

local function build_command(args)
    local parts = { base_env_prefix(), REQUIRED_BINARY }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = command_quote(arg)
    end
    return table.concat(parts, " ")
end

local function package_error(context, message, unavailable)
    tx_failed(context, message)
    emit_event(context, "failed", message)
    if unavailable ~= nil then
        emit_event(context, "unavailable", unavailable)
    end
    return false
end

local function ensure_binary(context)
    if command_exists(REQUIRED_BINARY) then
        return true
    end
    local message = REQUIRED_BINARY .. " binary not available"
    if context ~= nil then
        tx_failed(context, message)
        emit_event(context, "failed", message)
    end
    return false, message
end

local function normalize_package(raw)
    local name = trim(read_field(raw, "name") or raw)
    local version = trim(read_field(raw, "version") or "")
    if name == "" then
        return nil, "salesforce package name missing"
    end
    return {
        name = name,
        version = version,
        flags = object_flags(raw),
    }
end

local function package_spec(pkg)
    if trim(pkg.version) ~= "" then
        return trim(pkg.version)
    end
    return trim(pkg.name)
end

local function version_tuple(item)
    local major = tonumber(read_field(item, "MajorVersion") or read_field(item, "majorVersion") or 0) or 0
    local minor = tonumber(read_field(item, "MinorVersion") or read_field(item, "minorVersion") or 0) or 0
    local patch = tonumber(read_field(item, "PatchVersion") or read_field(item, "patchVersion") or 0) or 0
    local build = tonumber(read_field(item, "BuildNumber") or read_field(item, "buildNumber") or 0) or 0
    return major, minor, patch, build
end

local function version_string(item)
    local explicit = trim(
        read_field(item, "Version")
        or read_field(item, "version")
        or read_field(item, "SubscriberPackageVersionName")
        or read_field(item, "subscriberPackageVersionName")
        or ""
    )
    if explicit ~= "" then
        return explicit
    end
    local major, minor, patch, build = version_tuple(item)
    if major ~= 0 or minor ~= 0 or patch ~= 0 or build ~= 0 then
        return tostring(major) .. "." .. tostring(minor) .. "." .. tostring(patch) .. "." .. tostring(build)
    end
    return trim(read_field(item, "SubscriberPackageVersionId") or read_field(item, "subscriberPackageVersionId") or "")
end

local function package_name(item)
    return trim(
        read_field(item, "SubscriberPackageName")
        or read_field(item, "subscriberPackageName")
        or read_field(item, "Package2Name")
        or read_field(item, "package2Name")
        or read_field(item, "Name")
        or read_field(item, "name")
        or read_field(item, "Package")
        or read_field(item, "package")
        or ""
    )
end

local function package2_id(item)
    return trim(read_field(item, "Package2Id") or read_field(item, "package2Id") or read_field(item, "PackageId") or read_field(item, "packageId") or "")
end

local function subscriber_id(item)
    return trim(read_field(item, "SubscriberPackageVersionId") or read_field(item, "subscriberPackageVersionId") or read_field(item, "Id") or read_field(item, "id") or "")
end

local function item_summary(item)
    return trim(read_field(item, "Description") or read_field(item, "description") or read_field(item, "Summary") or read_field(item, "summary") or "")
end

local function item_namespace(item)
    return trim(read_field(item, "NamespacePrefix") or read_field(item, "namespacePrefix") or "")
end

local function flatten_result_items(decoded)
    if type(decoded) ~= "table" then
        return {}
    end
    if type(decoded.result) == "table" then
        if decoded.result[1] ~= nil then
            return decoded.result
        end
        if type(decoded.result.records) == "table" then
            return decoded.result.records
        end
        if type(decoded.result.packages) == "table" then
            return decoded.result.packages
        end
        if next(decoded.result) ~= nil then
            return { decoded.result }
        end
    end
    if decoded[1] ~= nil then
        return decoded
    end
    return {}
end

local function cache_key(text)
    local key = lower(trim(text))
    key = key:gsub("[^%w%._%-]", "-")
    key = key:gsub("%-+", "-")
    if key == "" then
        key = "default"
    end
    return key
end

local function load_cached_json(kind, key)
    local raw = read_file(cache_file(kind, cache_key(key)))
    if raw == nil or trim(raw) == "" then
        return nil
    end
    local decoded = decode_json(raw)
    return decoded
end

local function save_cached_json(kind, key, raw)
    if trim(raw) == "" then
        return false
    end
    return write_file(cache_file(kind, cache_key(key)), raw)
end

local function query_json(context, kind, key, args, extra_exit_codes)
    local result = exec_run(context, build_command(args))
    if not is_command_success(result, extra_exit_codes) then
        return nil, trim(result.stderr) ~= "" and trim(result.stderr) or trim(result.stdout)
    end
    local decoded, decode_error = decode_json(result.stdout)
    if decoded == nil then
        return nil, decode_error or (kind .. " json parse failed")
    end
    save_cached_json(kind, key, result.stdout)
    return decoded, nil
end

local function required_flag(flags, key, message)
    local value = trim(flag_value(flags, key) or "")
    if value == "" then
        return nil, message
    end
    return value, nil
end

local function install_args(target_org, pkg, flags)
    local args = { "package", "install", "--json", "--no-prompt", "--target-org", target_org, "--package", package_spec(pkg), "--wait", trim(flag_value(flags, "wait") or "10") }
    local publish_wait = trim(flag_value(flags, "publish-wait") or "")
    local installation_key = trim(flag_value(flags, "installation-key") or "")
    local apex_compile = trim(flag_value(flags, "apex-compile") or "")
    local security_type = trim(flag_value(flags, "security-type") or "")
    local upgrade_type = trim(flag_value(flags, "upgrade-type") or "")
    if publish_wait ~= "" then
        args[#args + 1] = "--publish-wait"
        args[#args + 1] = publish_wait
    end
    if installation_key ~= "" then
        args[#args + 1] = "--installation-key"
        args[#args + 1] = installation_key
    end
    if apex_compile ~= "" then
        args[#args + 1] = "--apex-compile"
        args[#args + 1] = apex_compile
    end
    if security_type ~= "" then
        args[#args + 1] = "--security-type"
        args[#args + 1] = security_type
    end
    if upgrade_type ~= "" then
        args[#args + 1] = "--upgrade-type"
        args[#args + 1] = upgrade_type
    end
    return args
end

local function uninstall_args(target_org, pkg, flags)
    return { "package", "uninstall", "--json", "--target-org", target_org, "--package", package_spec(pkg), "--wait", trim(flag_value(flags, "wait") or "10") }
end

local function installed_list(context, target_org)
    local decoded, err = query_json(context, "installed-list", target_org, { "package", "installed", "list", "--json", "--target-org", target_org })
    if decoded == nil then
        return nil, err
    end
    return flatten_result_items(decoded), nil
end

local function package_list(context, target_dev_hub)
    local cached = load_cached_json("package-list", target_dev_hub)
    if cached ~= nil then
        return flatten_result_items(cached), nil
    end
    local decoded, err = query_json(context, "package-list", target_dev_hub, { "package", "list", "--json", "--verbose", "--target-dev-hub", target_dev_hub })
    if decoded == nil then
        return nil, err
    end
    return flatten_result_items(decoded), nil
end

local function package_version_list(context, target_dev_hub, released_only)
    local key = target_dev_hub .. (released_only and "-released" or "-all")
    local cached = load_cached_json("package-version-list", key)
    if cached ~= nil then
        return flatten_result_items(cached), nil
    end
    local args = { "package", "version", "list", "--json", "--verbose", "--target-dev-hub", target_dev_hub }
    if released_only then
        args[#args + 1] = "--released"
    end
    local decoded, err = query_json(context, "package-version-list", key, args)
    if decoded == nil then
        return nil, err
    end
    return flatten_result_items(decoded), nil
end

local function package_version_report(context, target_dev_hub, package_ref)
    local key = target_dev_hub .. "-" .. package_ref
    local cached = load_cached_json("package-report", key)
    if cached ~= nil and type(cached.result) == "table" then
        return cached.result, nil
    end
    local decoded, err = query_json(context, "package-report", key, { "package", "version", "report", "--json", "--target-dev-hub", target_dev_hub, "--package", package_ref })
    if decoded == nil then
        return nil, err
    end
    return type(decoded.result) == "table" and decoded.result or nil, nil
end

local function build_item(source, installed, target_org, target_dev_hub)
    local item = {
        name = package_name(source),
        packageId = subscriber_id(source),
        version = version_string(source),
        latestVersion = version_string(source),
        installedVersion = installed and version_string(installed) or nil,
        summary = item_summary(source),
        description = item_summary(source),
        type = "package",
        packageType = PLUGIN_ID,
        installed = installed ~= nil,
        status = installed ~= nil and "installed" or "available",
        subscriberPackageVersionId = subscriber_id(source),
        package2Id = package2_id(source),
        subscriberPackageName = package_name(source),
        namespacePrefix = item_namespace(source),
        targetOrg = target_org,
        targetDevHub = target_dev_hub,
        isReleased = read_field(source, "IsReleased") or read_field(source, "isReleased"),
        branch = read_field(source, "Branch") or read_field(source, "branch"),
        tag = read_field(source, "Tag") or read_field(source, "tag"),
        hasPassedCodeCoverageCheck = read_field(source, "HasPassedCodeCoverageCheck") or read_field(source, "hasPassedCodeCoverageCheck"),
        hasPassedSecurityReview = read_field(source, "HasPassedSecurityReview") or read_field(source, "hasPassedSecurityReview"),
    }
    if trim(item.packageId or "") == "" then
        item.packageId = package2_id(source)
    end
    if trim(item.name or "") == "" then
        item.name = item.packageId
    end
    if installed ~= nil then
        item.version = version_string(installed)
        item.installedVersion = version_string(installed)
    end
    return item
end

local function best_versions_by_package(versions)
    local grouped = {}
    for _, version in ipairs(versions or {}) do
        local key = package2_id(version)
        if key == "" then
            key = package_name(version)
        end
        if key ~= "" then
            local current = grouped[key]
            if current == nil then
                grouped[key] = version
            else
                local a1, a2, a3, a4 = version_tuple(version)
                local b1, b2, b3, b4 = version_tuple(current)
                local newer = a1 > b1 or (a1 == b1 and (a2 > b2 or (a2 == b2 and (a3 > b3 or (a3 == b3 and a4 > b4)))) )
                if newer then
                    grouped[key] = version
                end
            end
        end
    end
    return grouped
end

local function installed_index(items)
    local by_subscriber = {}
    local by_name = {}
    local by_package2 = {}
    for _, item in ipairs(items or {}) do
        local sub = subscriber_id(item)
        local name = package_name(item)
        local pkg2 = package2_id(item)
        if sub ~= "" then
            by_subscriber[sub] = item
        end
        if name ~= "" then
            by_name[lower(name)] = item
        end
        if pkg2 ~= "" then
            by_package2[pkg2] = item
        end
    end
    return { bySubscriber = by_subscriber, byName = by_name, byPackage2 = by_package2 }
end

local function match_installed(index, source)
    local sub = subscriber_id(source)
    if sub ~= "" and index.bySubscriber[sub] ~= nil then
        return index.bySubscriber[sub]
    end
    local pkg2 = package2_id(source)
    if pkg2 ~= "" and index.byPackage2[pkg2] ~= nil then
        return index.byPackage2[pkg2]
    end
    local name = package_name(source)
    if name ~= "" and index.byName[lower(name)] ~= nil then
        return index.byName[lower(name)]
    end
    return nil
end

local function sort_items(items)
    table.sort(items, function(left, right)
        return lower(left.name or left.packageId or "") < lower(right.name or right.packageId or "")
    end)
    return items
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
    return { "package-manager", "salesforce", "apex" }
end

function plugin.getMissingPackages()
    if command_exists(REQUIRED_BINARY) then
        return {}
    end
    return { REQUIRED_BINARY }
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end
    local available, message = ensure_binary(context)
    if not available then
        return false
    end
    local flags = collect_flags(context, requested)
    local target_org, target_org_error = required_flag(flags, "target-org", "salesforce install requires target-org=<alias>")
    if target_org == nil then
        return package_error(context, target_org_error)
    end
    local installed = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        begin_step(context, "install salesforce package " .. package_spec(pkg))
        local result = exec_run(context, build_command(install_args(target_org, pkg, flags)))
        if not is_command_success(result) then
            return package_error(context, trim(result.stderr) ~= "" and trim(result.stderr) or "salesforce package install failed")
        end
        local item = {
            name = pkg.name,
            packageId = package_spec(pkg),
            version = pkg.version ~= "" and pkg.version or package_spec(pkg),
            latestVersion = pkg.version ~= "" and pkg.version or package_spec(pkg),
            type = "package",
            packageType = PLUGIN_ID,
            installed = true,
            status = "installed",
            targetOrg = target_org,
        }
        local decoded = decode_json(result.stdout)
        if decoded ~= nil and type(decoded.result) == "table" then
            item.installRequestId = trim(read_field(decoded.result, "Id") or read_field(decoded.result, "id") or read_field(decoded.result, "InstallRequestId") or "")
            item.subscriberPackageVersionId = trim(read_field(decoded.result, "SubscriberPackageVersionId") or read_field(decoded.result, "subscriberPackageVersionId") or item.packageId)
            if item.subscriberPackageVersionId ~= "" then
                item.packageId = item.subscriberPackageVersionId
            end
        end
        installed[#installed + 1] = item
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.installLocal(context, path)
    local cleaned = trim(path)
    return package_error(context, "salesforce local installs are not supported", {
        path = cleaned,
        reason = "local-install-unsupported",
    })
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end
    local available = ensure_binary(context)
    if not available then
        return false
    end
    local flags = collect_flags(context, requested)
    local target_org, target_org_error = required_flag(flags, "target-org", "salesforce remove requires target-org=<alias>")
    if target_org == nil then
        return package_error(context, target_org_error)
    end
    local removed = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        begin_step(context, "remove salesforce package " .. package_spec(pkg))
        local result = exec_run(context, build_command(uninstall_args(target_org, pkg, flags)))
        if not is_command_success(result) then
            return package_error(context, trim(result.stderr) ~= "" and trim(result.stderr) or "salesforce package uninstall failed")
        end
        removed[#removed + 1] = {
            name = pkg.name,
            packageId = package_spec(pkg),
            version = pkg.version ~= "" and pkg.version or package_spec(pkg),
            packageType = PLUGIN_ID,
            type = "package",
            targetOrg = target_org,
        }
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    local available = ensure_binary(context)
    if not available then
        return false
    end
    local flags = collect_flags(context, requested)
    local target_org, target_org_error = required_flag(flags, "target-org", "salesforce update requires target-org=<alias>")
    if target_org == nil then
        return package_error(context, target_org_error)
    end
    local target_dev_hub, target_dev_hub_error = required_flag(flags, "target-dev-hub", "salesforce update requires target-dev-hub=<alias>")
    if target_dev_hub == nil then
        return package_error(context, target_dev_hub_error)
    end
    local versions, version_error = package_version_list(context, target_dev_hub, true)
    if versions == nil then
        return package_error(context, version_error or "salesforce package version list failed")
    end
    local best = best_versions_by_package(versions)
    local updated = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        local chosen = nil
        for _, version in ipairs(versions) do
            if subscriber_id(version) == package_spec(pkg) or lower(package_name(version)) == lower(pkg.name) or package2_id(version) == pkg.name then
                local key = package2_id(version)
                if key == "" then
                    key = package_name(version)
                end
                chosen = best[key] or version
                break
            end
        end
        if chosen == nil then
            return package_error(context, "salesforce update target not found: " .. pkg.name)
        end
        local install_pkg = { name = package_name(chosen), version = subscriber_id(chosen), flags = pkg.flags }
        begin_step(context, "update salesforce package " .. install_pkg.name)
        local result = exec_run(context, build_command(install_args(target_org, install_pkg, flags)))
        if not is_command_success(result) then
            return package_error(context, trim(result.stderr) ~= "" and trim(result.stderr) or "salesforce package update failed")
        end
        updated[#updated + 1] = build_item(chosen, chosen, target_org, target_dev_hub)
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.list(context)
    local available, message = ensure_binary(nil)
    if not available then
        log_warn(context, message)
        emit_event(context, "listed", {})
        return {}
    end
    local flags = collect_flags(context, {})
    local target_org = trim(flag_value(flags, "target-org") or "")
    if target_org == "" then
        log_warn(context, "salesforce list requires target-org=<alias>")
        emit_event(context, "listed", {})
        return {}
    end
    local installed, err = installed_list(context, target_org)
    if installed == nil then
        log_warn(context, err or "salesforce installed list failed")
        emit_event(context, "listed", {})
        return {}
    end
    local items = {}
    for _, item in ipairs(installed) do
        items[#items + 1] = build_item(item, item, target_org, nil)
    end
    sort_items(items)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local available, message = ensure_binary(nil)
    if not available then
        log_warn(context, message)
        emit_event(context, "outdated", {})
        return {}
    end
    local flags = collect_flags(context, {})
    local target_org = trim(flag_value(flags, "target-org") or "")
    local target_dev_hub = trim(flag_value(flags, "target-dev-hub") or "")
    if target_org == "" or target_dev_hub == "" then
        log_warn(context, "salesforce outdated requires target-org=<alias> and target-dev-hub=<alias>")
        emit_event(context, "outdated", {})
        return {}
    end
    local installed, installed_error = installed_list(context, target_org)
    if installed == nil then
        log_warn(context, installed_error or "salesforce installed list failed")
        emit_event(context, "outdated", {})
        return {}
    end
    local versions, version_error = package_version_list(context, target_dev_hub, true)
    if versions == nil then
        log_warn(context, version_error or "salesforce package version list failed")
        emit_event(context, "outdated", {})
        return {}
    end
    local best = best_versions_by_package(versions)
    local items = {}
    for _, item in ipairs(installed) do
        local key = package2_id(item)
        if key == "" then
            key = package_name(item)
        end
        local latest = best[key]
        if latest ~= nil and subscriber_id(latest) ~= "" and subscriber_id(latest) ~= subscriber_id(item) then
            local merged = build_item(latest, item, target_org, target_dev_hub)
            merged.status = "outdated"
            merged.latestVersion = version_string(latest)
            merged.subscriberPackageVersionId = subscriber_id(item)
            items[#items + 1] = merged
        end
    end
    sort_items(items)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt"))
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end
    local available, message = ensure_binary(nil)
    if not available then
        log_warn(context, message)
        emit_event(context, "searched", {})
        return {}
    end
    local flags = collect_flags(context, {})
    local target_dev_hub = trim(flag_value(flags, "target-dev-hub") or "")
    if target_dev_hub == "" then
        log_warn(context, "salesforce search requires target-dev-hub=<alias>")
        emit_event(context, "searched", {})
        return {}
    end
    local packages, package_error_message = package_list(context, target_dev_hub)
    if packages == nil then
        log_warn(context, package_error_message or "salesforce package list failed")
        emit_event(context, "searched", {})
        return {}
    end
    local versions, version_error = package_version_list(context, target_dev_hub, not has_flag(flags, "include-unreleased"))
    if versions == nil then
        log_warn(context, version_error or "salesforce package version list failed")
        emit_event(context, "searched", {})
        return {}
    end
    local best = best_versions_by_package(versions)
    local items = {}
    local wanted = lower(query)
    for _, package in ipairs(packages) do
        local haystack = table.concat({
            lower(package_name(package)),
            lower(item_summary(package)),
            lower(item_namespace(package)),
            lower(package2_id(package)),
        }, " ")
        if haystack:find(wanted, 1, true) ~= nil then
            local key = package2_id(package)
            if key == "" then
                key = package_name(package)
            end
            items[#items + 1] = build_item(best[key] or package, nil, nil, target_dev_hub)
        end
    end
    sort_items(items)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = trim(name or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt"))
    if query == "" then
        emit_event(context, "informed", {})
        return {}
    end
    local available, message = ensure_binary(nil)
    if not available then
        log_warn(context, message)
        emit_event(context, "informed", {})
        return {}
    end
    local flags = collect_flags(context, {})
    local target_org = trim(flag_value(flags, "target-org") or "")
    local target_dev_hub = trim(flag_value(flags, "target-dev-hub") or "")
    if target_dev_hub == "" then
        log_warn(context, "salesforce info requires target-dev-hub=<alias>")
        emit_event(context, "informed", {})
        return {}
    end

    local installed = nil
    if target_org ~= "" then
        local installed_items = installed_list(context, target_org)
        if installed_items ~= nil then
            local index = installed_index(installed_items)
            installed = index.bySubscriber[query] or index.byName[lower(query)] or index.byPackage2[query]
        end
    end

    local source = nil
    if query:match("^04t[%w]+$") ~= nil then
        source = package_version_report(context, target_dev_hub, query)
    else
        local exact_report = package_version_report(context, target_dev_hub, query)
        if exact_report ~= nil then
            source = exact_report
        end
    end
    if source == nil then
        local packages = package_list(context, target_dev_hub) or {}
        local versions = package_version_list(context, target_dev_hub, true) or {}
        local best = best_versions_by_package(versions)
        for _, package in ipairs(packages) do
            if lower(package_name(package)) == lower(query) or package2_id(package) == query then
                local key = package2_id(package)
                if key == "" then
                    key = package_name(package)
                end
                source = best[key] or package
                break
            end
        end
    end
    if source == nil and installed ~= nil then
        source = installed
    end
    if source == nil then
        emit_event(context, "unavailable", { name = query, reason = "not-found" })
        emit_event(context, "informed", {})
        return {}
    end
    local item = build_item(source, installed, target_org ~= "" and target_org or nil, target_dev_hub)
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local pkg, err = normalize_package(package)
    if pkg == nil then
        return nil, err
    end
    local item = plugin.info(context, pkg.version ~= "" and pkg.version or pkg.name)
    if type(item) == "table" and next(item) ~= nil then
        local resolved = shallow_copy(item)
        if pkg.version ~= "" then
            resolved.version = pkg.version
            resolved.packageId = pkg.version
        end
        return resolved
    end
    return {
        name = pkg.name,
        packageId = package_spec(pkg),
        version = pkg.version ~= "" and pkg.version or package_spec(pkg),
        packageType = PLUGIN_ID,
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "salesforce", "apex", "sfdx", "sf" },
        writeScopes = {
            { kind = "user-home-subpath", path = ".cache/reqpack/salesforce-apex" },
        },
        networkScopes = {
            { host = "login.salesforce.com", scheme = "https", pathPrefix = "/" },
            { host = "test.salesforce.com", scheme = "https", pathPrefix = "/" },
            { host = "salesforce.com", scheme = "https", pathPrefix = "/" },
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
