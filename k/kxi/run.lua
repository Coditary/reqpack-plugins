plugin = {}

local PLUGIN_ID = "kxi"
local PLUGIN_NAME = "kxi"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "kxi"
local JSON_NULL = {}

plugin.fileExtensions = { ".kxi" }

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

local function starts_with(value, prefix)
    return tostring(value or ""):sub(1, #prefix) == prefix
end

local function ends_with(value, suffix)
    local text = tostring(value or "")
    return suffix ~= "" and text:sub(-#suffix) == suffix
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function split_lines(value)
    local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = {}
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
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

local function first_non_empty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil and value ~= JSON_NULL then
            local cleaned = trim(value)
            if cleaned ~= "" then
                return cleaned
            end
        end
    end
    return nil
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

local function sequence_values(value)
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local items = {}
    local ok = pcall(function()
        for _, item in ipairs(value) do
            items[#items + 1] = item
        end
    end)
    if not ok then
        return {}
    end
    return items
end

local function object_flags(value)
    local flags = {}
    for _, item in ipairs(sequence_values(read_field(value, "flags"))) do
        local cleaned = trim(item)
        if cleaned ~= "" then
            flags[#flags + 1] = cleaned
        end
    end
    return flags
end

local function collect_flags(context, package)
    local flags = {}
    local seen = {}

    local function add_from(object)
        for _, flag in ipairs(object_flags(object)) do
            if not seen[flag] then
                seen[flag] = true
                flags[#flags + 1] = flag
            end
        end
    end

    add_from(context)
    add_from(read_field(context, "request"))

    if type(package) == "table" and read_field(package, 1) ~= nil and read_field(package, "name") == nil then
        for _, item in ipairs(package) do
            add_from(item)
        end
    else
        add_from(package)
    end

    return flags
end

local expand_runtime_placeholders

local function flag_value(flags, key)
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            return trim(expand_runtime_placeholders(cleaned:sub(#prefix + 1)))
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

local function read_proc_environ_value(name)
    if os ~= nil and type(os.getenv) == "function" then
        local value = os.getenv(tostring(name or ""))
        if value ~= nil and value ~= "" then
            return trim(value)
        end
    end

    local handle = io.open("/proc/self/environ", "rb")
    if handle == nil then
        return nil
    end
    local payload = handle:read("*a")
    handle:close()
    if payload == nil or payload == "" then
        return nil
    end

    local prefix = tostring(name or "") .. "="
    for entry in tostring(payload):gmatch("[^%z]+") do
        if entry:sub(1, #prefix) == prefix then
            return trim(entry:sub(#prefix + 1))
        end
    end
    return nil
end

local function fixture_root()
    return non_empty(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT"))
end

expand_runtime_placeholders = function(value)
    local text = tostring(value or "")
    local root = fixture_root()
    if root ~= nil then
        text = text:gsub("%${fixtureRoot}", root)
    end
    return text
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(expand_runtime_placeholders(select(index, ...)))
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
        for _, key in ipairs({ "success", "ok", "stdout", "stderr", "stdoutText", "stderrText", "exitCode", "exit_code", "code", "status" }) do
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

local function command_exists(context)
    local result = exec_run(context, "command -v " .. REQUIRED_BINARY .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function default_home()
    return non_empty(read_proc_environ_value("HOME")) or "~"
end

local function resolve_paths(context, package)
    local flags = collect_flags(context, package)
    local home = default_home()

    local package_root = non_empty(flag_value(flags, "path"))
        or non_empty(flag_value(flags, "pkg-lib"))
        or non_empty(read_proc_environ_value("KX_PACKAGE_PATH"))
        or join_path(home, ".insights", "packages")

    local artifact_root = non_empty(flag_value(flags, "artifacts"))
        or non_empty(flag_value(flags, "artifact-store"))
        or non_empty(read_proc_environ_value("KX_ARTIFACT_PATH"))
        or join_path(home, ".insights", "artifacts")

    local deployment_root = non_empty(flag_value(flags, "deployments"))
        or non_empty(flag_value(flags, "deployment-store"))
        or non_empty(read_proc_environ_value("KX_DEPLOYMENT_PATH"))
        or join_path(home, ".insights", "deployments")

    return {
        packageRoot = package_root,
        artifactRoot = artifact_root,
        deploymentRoot = deployment_root,
    }
end

local function env_prefix(paths)
    return "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C"
        .. " KX_PACKAGE_PATH=" .. shell_quote(paths.packageRoot)
        .. " KX_ARTIFACT_PATH=" .. shell_quote(paths.artifactRoot)
        .. " KX_DEPLOYMENT_PATH=" .. shell_quote(paths.deploymentRoot)
end

local function kxi_command(paths, subcommand)
    return env_prefix(paths) .. " kxi package " .. subcommand
end

local function is_local_artifact(value)
    return ends_with(trim(value), ".kxi")
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageId") or "")
end

local function package_version(pkg)
    return trim(read_field(pkg, "version") or "")
end

local function parse_json_error(message, index)
    error("invalid json at offset " .. tostring(index) .. ": " .. message)
end

local function json_decode(input)
    local source = tostring(input or "")
    local index = 1

    local function peek(offset)
        return source:sub(index + (offset or 0), index + (offset or 0))
    end

    local function advance(count)
        index = index + (count or 1)
    end

    local function skip_whitespace()
        while true do
            local char = peek()
            if char == " " or char == "\n" or char == "\r" or char == "\t" then
                advance(1)
            else
                return
            end
        end
    end

    local parse_value

    local function parse_string()
        if peek() ~= '"' then
            parse_json_error("expected string", index)
        end

        advance(1)
        local parts = {}

        while true do
            local char = peek()
            if char == "" then
                parse_json_error("unterminated string", index)
            elseif char == '"' then
                advance(1)
                return table.concat(parts)
            elseif char == "\\" then
                local escape = peek(1)
                if escape == '"' or escape == "\\" or escape == "/" then
                    parts[#parts + 1] = escape
                    advance(2)
                elseif escape == "b" then
                    parts[#parts + 1] = "\b"
                    advance(2)
                elseif escape == "f" then
                    parts[#parts + 1] = "\f"
                    advance(2)
                elseif escape == "n" then
                    parts[#parts + 1] = "\n"
                    advance(2)
                elseif escape == "r" then
                    parts[#parts + 1] = "\r"
                    advance(2)
                elseif escape == "t" then
                    parts[#parts + 1] = "\t"
                    advance(2)
                elseif escape == "u" then
                    local hex = source:sub(index + 2, index + 5)
                    if not hex:match("^%x%x%x%x$") then
                        parse_json_error("invalid unicode escape", index)
                    end
                    local codepoint = tonumber(hex, 16)
                    if utf8 ~= nil and type(utf8.char) == "function" then
                        parts[#parts + 1] = utf8.char(codepoint)
                    elseif codepoint < 128 then
                        parts[#parts + 1] = string.char(codepoint)
                    else
                        parse_json_error("unicode escape unsupported without utf8 library", index)
                    end
                    advance(6)
                else
                    parse_json_error("invalid escape sequence", index)
                end
            else
                parts[#parts + 1] = char
                advance(1)
            end
        end
    end

    local function parse_number()
        local start = index

        if peek() == "-" then
            advance(1)
        end

        local char = peek()
        if char == "0" then
            advance(1)
        elseif char:match("%d") then
            repeat
                advance(1)
                char = peek()
            until not char:match("%d")
        else
            parse_json_error("invalid number", index)
        end

        if peek() == "." then
            advance(1)
            if not peek():match("%d") then
                parse_json_error("invalid number fraction", index)
            end
            repeat
                advance(1)
                char = peek()
            until not char:match("%d")
        end

        char = peek()
        if char == "e" or char == "E" then
            advance(1)
            char = peek()
            if char == "+" or char == "-" then
                advance(1)
            end
            if not peek():match("%d") then
                parse_json_error("invalid number exponent", index)
            end
            repeat
                advance(1)
                char = peek()
            until not char:match("%d")
        end

        return tonumber(source:sub(start, index - 1))
    end

    local function parse_array()
        if peek() ~= "[" then
            parse_json_error("expected array", index)
        end

        advance(1)
        skip_whitespace()

        local result = {}
        if peek() == "]" then
            advance(1)
            return result
        end

        while true do
            result[#result + 1] = parse_value()
            skip_whitespace()

            local char = peek()
            if char == "," then
                advance(1)
                skip_whitespace()
            elseif char == "]" then
                advance(1)
                return result
            else
                parse_json_error("expected ',' or ']'", index)
            end
        end
    end

    local function parse_object()
        if peek() ~= "{" then
            parse_json_error("expected object", index)
        end

        advance(1)
        skip_whitespace()

        local result = {}
        if peek() == "}" then
            advance(1)
            return result
        end

        while true do
            local key = parse_string()
            skip_whitespace()

            if peek() ~= ":" then
                parse_json_error("expected ':'", index)
            end

            advance(1)
            skip_whitespace()
            result[key] = parse_value()
            skip_whitespace()

            local char = peek()
            if char == "," then
                advance(1)
                skip_whitespace()
            elseif char == "}" then
                advance(1)
                return result
            else
                parse_json_error("expected ',' or '}'", index)
            end
        end
    end

    function parse_value()
        skip_whitespace()
        local char = peek()

        if char == '"' then
            return parse_string()
        elseif char == "{" then
            return parse_object()
        elseif char == "[" then
            return parse_array()
        elseif char == "-" or char:match("%d") then
            return parse_number()
        elseif source:sub(index, index + 3) == "true" then
            advance(4)
            return true
        elseif source:sub(index, index + 4) == "false" then
            advance(5)
            return false
        elseif source:sub(index, index + 3) == "null" then
            advance(4)
            return JSON_NULL
        end

        parse_json_error("unexpected token", index)
    end

    local result = parse_value()
    skip_whitespace()
    if index <= #source then
        parse_json_error("trailing data", index)
    end
    return result
end

local function decode_json_object(stdout)
    local text = trim(stdout)
    if text == "" or text:sub(1, 1) ~= "{" then
        return nil
    end
    local ok, decoded = pcall(json_decode, text)
    if not ok or type(decoded) ~= "table" then
        return nil
    end
    return decoded
end

local function build_package_id(name, version)
    return PLUGIN_ID .. "/" .. trim(name) .. "/" .. trim(version ~= "" and version or "unknown")
end

local function build_item(name, version, installed, source, status, extra)
    local summary_source = source == "artifact" and "local artifact" or "installed package"
    return {
        name = trim(name),
        version = trim(version),
        installed = installed == true,
        status = trim(status ~= "" and status or (installed and "installed" or "available")),
        type = "package",
        packageType = "library",
        packageId = build_package_id(name, version),
        summary = "kxi " .. summary_source .. " " .. trim(name),
        description = "kxi " .. summary_source .. " " .. trim(name),
        extraFields = extra,
    }
end

local function item_sort_key(item)
    return lower(item.name or "") .. "\0" .. trim(item.version or "") .. "\0" .. lower(read_field(item.extraFields, "source") or "")
end

local function sort_items(items)
    table.sort(items, function(left, right)
        return item_sort_key(left) < item_sort_key(right)
    end)
    return items
end

local function dedupe_items(items)
    local merged = {}
    for _, item in ipairs(items or {}) do
        local key = trim(item.name or "") .. "@" .. trim(item.version or "")
        if merged[key] == nil then
            merged[key] = shallow_copy(item)
        else
            local current = merged[key]
            current.installed = current.installed == true or item.installed == true
            current.status = non_empty(item.status) or current.status
            current.extraFields = merge_extra_fields(current.extraFields, item.extraFields)
        end
    end

    local result = {}
    for _, item in pairs(merged) do
        result[#result + 1] = item
    end
    return sort_items(result)
end

local function append_mapping_item(items, name, version, source, installed, status, paths, extra)
    local merged_extra = merge_extra_fields(extra, {
        source = source,
    })
    if source == "installed" then
        merged_extra = merge_extra_fields(merged_extra, {
            path = join_path(paths.packageRoot, name, version),
        })
    end
    items[#items + 1] = build_item(name, version, installed, source, status, merged_extra)
end

local function items_from_mapping(mapping, source, installed, paths)
    local items = {}
    for name, value in pairs(mapping or {}) do
        if type(name) == "string" then
            if type(value) == "table" and read_field(value, 1) ~= nil then
                for _, entry in ipairs(value) do
                    local version = non_empty(read_field(entry, "version")) or "unknown"
                    append_mapping_item(items, name, version, source, installed, non_empty(read_field(entry, "_status")) or nil, paths, nil)
                end
            elseif type(value) == "table" then
                local direct_version = non_empty(read_field(value, "version"))
                if direct_version ~= nil then
                    append_mapping_item(items, name, direct_version, source, installed, non_empty(read_field(value, "_status")) or nil, paths, nil)
                else
                    for version, meta in pairs(value) do
                        if type(version) == "string" then
                            append_mapping_item(items, name, version, source, installed, non_empty(read_field(meta, "_status")) or nil, paths, nil)
                        end
                    end
                end
            elseif type(value) == "string" then
                append_mapping_item(items, name, value, source, installed, nil, paths, nil)
            end
        end
    end
    return dedupe_items(items)
end

local function list_directory(context, path)
    local result = exec_run(context, "ls -1 " .. shell_quote(path))
    if result == nil or not result.success then
        return {}
    end
    local items = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" and cleaned ~= "." and cleaned ~= ".." then
            items[#items + 1] = cleaned
        end
    end
    table.sort(items)
    return items
end

local function path_is_directory(context, path)
    local result = exec_run(context, "test -d " .. shell_quote(path))
    return result ~= nil and result.success == true
end

local function scan_package_root(context, paths)
    local items = {}
    if not path_is_directory(context, paths.packageRoot) then
        return items
    end
    for _, name in ipairs(list_directory(context, paths.packageRoot)) do
        local version_root = join_path(paths.packageRoot, name)
        for _, version in ipairs(list_directory(context, version_root)) do
            items[#items + 1] = build_item(name, version, true, "installed", "installed", {
                source = "installed",
                path = join_path(paths.packageRoot, name, version),
            })
        end
    end
    return dedupe_items(items)
end

local function query_cli_mapping(context, paths, subcommand)
    local result = exec_run(context, kxi_command(paths, subcommand))
    if result == nil or not result.success then
        return nil, first_non_empty(result and result.stderr, result and result.stdout, "kxi package command failed")
    end
    local decoded = decode_json_object(result.stdout)
    if decoded == nil then
        return {}, nil
    end
    return decoded, nil
end

local function installed_items(context, paths)
    local mapping, err = query_cli_mapping(context, paths, "list")
    if mapping == nil then
        return nil, err
    end
    local from_cli = items_from_mapping(mapping, "installed", true, paths)
    local from_scan = scan_package_root(context, paths)
    local merged = {}
    for _, item in ipairs(from_cli) do
        merged[#merged + 1] = item
    end
    for _, item in ipairs(from_scan) do
        merged[#merged + 1] = item
    end
    return dedupe_items(merged), nil
end

local function artifact_items(context, paths)
    local mapping, err = query_cli_mapping(context, paths, "list --artifacts")
    if mapping == nil then
        return nil, err
    end
    local items = items_from_mapping(mapping, "artifact", false, paths)
    for _, item in ipairs(items) do
        item.extraFields = merge_extra_fields(item.extraFields, {
            artifactStore = paths.artifactRoot,
        })
    end
    return items, nil
end

local function matches_prompt(item, prompt)
    local needle = lower(trim(prompt))
    if needle == "" then
        return true
    end
    local haystacks = {
        lower(item.name),
        lower(item.version),
        lower(read_field(item.extraFields, "source") or ""),
    }
    for _, haystack in ipairs(haystacks) do
        if haystack:find(needle, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function requirement_specifier(pkg)
    local name = package_name(pkg)
    local version = package_version(pkg)
    if is_local_artifact(name) then
        return name
    end
    if version ~= "" then
        return name .. "/" .. version
    end
    return name
end

local function install_command(paths, pkg, extra_force)
    local flags = collect_flags(nil, pkg)
    local parts = { "install" }
    if extra_force or has_flag(flags, "force") then
        parts[#parts + 1] = "--force"
    end
    if has_flag(flags, "simple") then
        parts[#parts + 1] = "--simple"
    end
    parts[#parts + 1] = shell_quote(requirement_specifier(pkg))
    return kxi_command(paths, table.concat(parts, " "))
end

local function uninstall_command(paths, pkg)
    local flags = collect_flags(nil, pkg)
    local parts = { "uninstall" }
    if has_flag(flags, "force") then
        parts[#parts + 1] = "--force"
    end
    parts[#parts + 1] = shell_quote(requirement_specifier(pkg))
    return kxi_command(paths, table.concat(parts, " "))
end

local function parse_install_result(stdout, paths)
    local mapping = decode_json_object(stdout)
    if mapping == nil then
        return {}
    end
    return items_from_mapping(mapping, "installed", true, paths)
end

local function fail_action(context, message)
    tx_failed(context, message)
    return false
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
    return { "programming-language", "package-manager", "q", "kdb+" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end
    if not command_exists(nil) then
        return requested
    end
    return {}
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if not command_exists(context) then
        return fail_action(context, "kxi not installed")
    end

    begin_step(context, "install kxi packages")
    local installed = {}

    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        if name == "" then
            return fail_action(context, "kxi package name missing")
        end
        local paths = resolve_paths(context, pkg)
        local result = exec_run(context, install_command(paths, pkg, false))
        if result == nil or not result.success then
            return fail_action(context, first_non_empty(result and result.stderr, "kxi install failed for " .. name))
        end
        local parsed = parse_install_result(result.stdout, paths)
        if #parsed == 0 then
            installed[#installed + 1] = build_item(name, package_version(pkg) ~= "" and package_version(pkg) or "unknown", true, "installed", "installed", {
                source = "installed",
            })
        else
            for _, item in ipairs(parsed) do
                installed[#installed + 1] = item
            end
        end
    end

    emit_event(context, "installed", dedupe_items(installed))
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local target = trim(path or read_field(context, "localPath") or read_field(read_field(context, "request") or {}, "localPath") or read_field(context, "path") or read_field(read_field(context, "request") or {}, "path") or "")
    if target == "" then
        return fail_action(context, "kxi local artifact path missing")
    end
    return plugin.install(context, {
        {
            name = target,
        },
    })
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if not command_exists(context) then
        return fail_action(context, "kxi not installed")
    end

    begin_step(context, "remove kxi packages")
    local removed = {}
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        if name == "" then
            return fail_action(context, "kxi package name missing")
        end
        local paths = resolve_paths(context, pkg)
        local result = exec_run(context, uninstall_command(paths, pkg))
        if result == nil or not result.success then
            return fail_action(context, first_non_empty(result and result.stderr, "kxi uninstall failed for " .. name))
        end
        removed[#removed + 1] = build_item(name, package_version(pkg) ~= "" and package_version(pkg) or "unknown", false, "installed", "removed", {
            source = "installed",
        })
    end

    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    if not command_exists(context) then
        return fail_action(context, "kxi not installed")
    end

    begin_step(context, "update kxi packages")
    local requested = packages or {}
    local targets = {}

    if #requested > 0 then
        for _, item in ipairs(requested) do
            targets[#targets + 1] = item
        end
    else
        local paths = resolve_paths(context, nil)
        local listed, err = installed_items(context, paths)
        if listed == nil then
            return fail_action(context, err or "kxi list failed during update")
        end
        for _, item in ipairs(listed) do
            targets[#targets + 1] = {
                name = item.name,
                version = item.version,
            }
        end
    end

    local updated = {}
    for _, pkg in ipairs(targets) do
        local name = package_name(pkg)
        local paths = resolve_paths(context, pkg)
        local result = exec_run(context, install_command(paths, pkg, true))
        if result == nil or not result.success then
            return fail_action(context, first_non_empty(result and result.stderr, "kxi update failed for " .. name))
        end
        updated[#updated + 1] = build_item(name, package_version(pkg) ~= "" and package_version(pkg) or "unknown", true, "installed", "updated", {
            source = "installed",
        })
    end

    emit_event(context, "updated", dedupe_items(updated))
    tx_success(context)
    return true
end

function plugin.list(context)
    if not command_exists(context) then
        log_warn(context, "kxi not installed")
        local empty = {}
        emit_event(context, "listed", empty)
        return empty
    end

    local paths = resolve_paths(context, nil)
    local items, err = installed_items(context, paths)
    if items == nil then
        log_warn(context, err)
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local empty = {}
    emit_event(context, "outdated", empty)
    return empty
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
    if not command_exists(context) then
        log_warn(context, "kxi not installed")
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local paths = resolve_paths(context, nil)
    local installed = installed_items(context, paths) or {}
    local artifacts = artifact_items(context, paths) or {}
    local items = {}
    for _, item in ipairs(installed) do
        if matches_prompt(item, query) then
            items[#items + 1] = item
        end
    end
    for _, item in ipairs(artifacts) do
        if matches_prompt(item, query) then
            items[#items + 1] = item
        end
    end
    items = dedupe_items(items)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local target = trim(name or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
    if target == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    if not command_exists(context) then
        log_warn(context, "kxi not installed")
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local paths = resolve_paths(context, nil)
    local installed, installed_err = installed_items(context, paths)
    if installed ~= nil then
        for _, item in ipairs(installed) do
            if item.name == target then
                emit_event(context, "informed", item)
                return item
            end
        end
    elseif installed_err ~= nil then
        log_warn(context, installed_err)
    end

    local artifacts, artifact_err = artifact_items(context, paths)
    if artifacts ~= nil then
        for _, item in ipairs(artifacts) do
            if item.name == target then
                emit_event(context, "informed", item)
                return item
            end
        end
    elseif artifact_err ~= nil then
        log_warn(context, artifact_err)
    end

    local empty = {}
    emit_event(context, "informed", empty)
    return empty
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
        capabilities = { "exec" },
        ecosystemScopes = { "q", "kdb+", "kxi" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".insights" },
        },
        networkScopes = {},
        privilegeLevel = "none",
        purlType = "generic",
    }
end

return plugin
