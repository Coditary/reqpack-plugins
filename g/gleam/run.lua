plugin = {}

local PLUGIN_ID = "gleam"
local PLUGIN_NAME = "gleam"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "gleam"
local QUERY_BINARY = "curl"
local COMMAND_ENV_PREFIX = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME=\"$HOME\" XDG_CONFIG_HOME=\"$HOME/.config\" XDG_CACHE_HOME=\"$HOME/.cache\" XDG_DATA_HOME=\"$HOME/.local/share\" XDG_STATE_HOME=\"$HOME/.local/state\""

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return tostring(value or ""):lower()
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

local function is_success(result)
    return type(result) == "table" and (result.success == true or result.ok == true or result.exitCode == 0)
end

local function command_exists(context, binary)
    return is_success(exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function ensure_available(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true, nil
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function ensure_query_available(context)
    if command_exists(context, QUERY_BINARY) then
        return true, nil
    end
    return false, QUERY_BINARY .. " binary not available"
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

local function list_flags(object)
    local result = {}
    for _, item in ipairs(sequence_values(read_field(object, "flags"))) do
        local cleaned = trim(item)
        if cleaned ~= "" then
            result[#result + 1] = cleaned
        end
    end
    return result
end

local function append_unique(list, seen, value)
    local cleaned = trim(value)
    if cleaned == "" or seen[cleaned] then
        return
    end
    seen[cleaned] = true
    list[#list + 1] = cleaned
end

local function collect_flags(context, packages)
    local result = {}
    local seen = {}
    local function add_from(object)
        for _, flag in ipairs(list_flags(object)) do
            append_unique(result, seen, flag)
        end
    end
    add_from(context)
    add_from(read_field(context, "request"))
    for _, pkg in ipairs(packages or {}) do
        add_from(pkg)
    end
    return result
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
        if lower(trim(flag)) == wanted then
            return true
        end
    end
    return false
end

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = trim(select(index, ...) or "")
        if value ~= "" then
            return value
        end
    end
    return nil
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

local function project_root(context, packages)
    local flags = collect_flags(context, packages)
    return first_nonempty(
        flag_value(flags, "cwd"),
        read_field(context, "cwd"),
        read_field(context, "workspaceRoot"),
        read_field(context, "workingDirectory"),
        "."
    )
end

local function read_file(context, path)
    local handle = io.open(path, "r")
    if handle ~= nil then
        local content = handle:read("*a")
        handle:close()
        return content
    end

    local result = exec_run(context, "cat " .. shell_quote(path))
    if is_success(result) then
        return result.stdout or ""
    end
    return nil
end

local function ensure_project(context, packages)
    local root = project_root(context, packages)
    local result = exec_run(context, "test -f " .. shell_quote(join_path(root, "gleam.toml")))
    if is_success(result) then
        return true, root
    end
    return false, root, "gleam plugin requires project root containing gleam.toml"
end

local function build_project_command(context, packages, args)
    local root = project_root(context, packages)
    local command = COMMAND_ENV_PREFIX .. " sh -lc " .. shell_quote("cd " .. shell_quote(root) .. " && gleam " .. table.concat(args or {}, " "))
    return command, root
end

local function cache_root()
    return join_path("$HOME", ".cache", "reqpack", PLUGIN_ID)
end

local function package_name(pkg)
    return first_nonempty(read_field(pkg, "name"), read_field(pkg, "packageId"), pkg)
end

local function package_version(pkg)
    local explicit = trim(read_field(pkg, "version"))
    if explicit ~= "" then
        return explicit
    end
    local name = trim(package_name(pkg))
    local parsed = name:match("^[^@]+@(.+)$")
    if parsed ~= nil and trim(parsed) ~= "" then
        return trim(parsed)
    end
    return nil
end

local function package_selector(pkg)
    local name = trim(package_name(pkg))
    local version = trim(package_version(pkg))
    if name == "" then
        return nil
    end
    if name:find("@", 1, true) ~= nil or version == "" then
        return name
    end
    return name .. "@" .. version
end

local function package_is_dev(pkg)
    local flags = collect_flags(nil, { pkg })
    return has_flag(flags, "dev")
end

local function split_top_level_entries(text)
    local entries = {}
    local depth = 0
    local in_string = false
    local current = {}
    local index = 1
    while index <= #text do
        local char = text:sub(index, index)
        local prev = index > 1 and text:sub(index - 1, index - 1) or ""
        if char == '"' and prev ~= "\\" then
            in_string = not in_string
        end
        if not in_string then
            if char == "{" then
                depth = depth + 1
            elseif char == "}" then
                depth = depth - 1
            elseif char == "," and depth == 0 then
                local item = trim(table.concat(current))
                if item ~= "" then
                    entries[#entries + 1] = item
                end
                current = {}
                index = index + 1
                goto continue
            end
        end
        current[#current + 1] = char
        ::continue::
        index = index + 1
    end
    local item = trim(table.concat(current))
    if item ~= "" then
        entries[#entries + 1] = item
    end
    return entries
end

local function extract_array_block(text, key)
    local start_pos, open_pos = text:find(key .. "%s*=%s*%[")
    if open_pos == nil then
        return nil
    end

    local depth = 0
    local in_string = false
    local block_start = nil
    for index = open_pos, #text do
        local char = text:sub(index, index)
        local prev = index > 1 and text:sub(index - 1, index - 1) or ""
        if char == '"' and prev ~= "\\" then
            in_string = not in_string
        elseif not in_string then
            if char == "[" then
                depth = depth + 1
                if block_start == nil then
                    block_start = index + 1
                end
            elseif char == "]" then
                depth = depth - 1
                if depth == 0 and block_start ~= nil then
                    return text:sub(block_start, index - 1)
                end
            end
        end
    end
    return nil
end

local function parse_manifest_packages(text)
    local packages = {}
    local block = extract_array_block(text, "packages")
    if block == nil then
        return packages
    end

    for _, entry in ipairs(split_top_level_entries(block)) do
        local normalized = trim(entry)
        if normalized:sub(1, 1) == "{" and normalized:sub(-1) == "}" then
            local name = normalized:match('name%s*=%s*"([^"]+)"')
            local version = normalized:match('version%s*=%s*"([^"]+)"')
            local source = normalized:match('source%s*=%s*"([^"]+)"')
            local otp_app = normalized:match('otp_app%s*=%s*"([^"]+)"')
            if name ~= nil then
                packages[#packages + 1] = {
                    name = name,
                    packageId = name,
                    version = version,
                    installed = true,
                    status = "installed",
                    packageType = "library",
                    extraFields = {
                        source = source,
                        otpApp = otp_app,
                    },
                }
            end
        end
    end

    table.sort(packages, function(left, right)
        return lower(left.name) < lower(right.name)
    end)
    return packages
end

local function parse_deps_list_output(stdout)
    local items = {}
    for index, line in ipairs(split_lines(stdout)) do
        if index > 1 then
            local name, version = line:match("^(%S+)%s+(%S+)%s*$")
            if name ~= nil then
                items[#items + 1] = {
                    name = name,
                    packageId = name,
                    version = version,
                    installed = true,
                    status = "installed",
                    packageType = "library",
                }
            end
        end
    end
    return items
end

local function parse_outdated_output(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        local name, current, latest = cleaned:match("^(%S+)%s+(%S+)%s+(%S+)$")
        if name ~= nil and lower(name) ~= "package" and lower(name) ~= "of" then
            items[#items + 1] = {
                name = name,
                packageId = name,
                version = current,
                latestVersion = latest,
                installed = true,
                outdated = current ~= latest,
                status = current ~= latest and "outdated" or "installed",
                packageType = "library",
            }
        end
    end
    return items
end

local function decode_json(text)
    local index = 1
    local length = #text

    local function skip_ws()
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
                    local code = tonumber(hex, 16)
                    if code ~= nil then
                        if code <= 0x7F then
                            parts[#parts + 1] = string.char(code)
                        elseif code <= 0x7FF then
                            parts[#parts + 1] = string.char(0xC0 + math.floor(code / 0x40), 0x80 + (code % 0x40))
                        else
                            parts[#parts + 1] = string.char(0xE0 + math.floor(code / 0x1000), 0x80 + (math.floor(code / 0x40) % 0x40), 0x80 + (code % 0x40))
                        end
                    end
                    index = index + 5
                else
                    index = index + 1
                end
                segment_start = index
            else
                index = index + 1
            end
        end
        return table.concat(parts)
    end

    local function parse_number()
        local start = index
        repeat
            index = index + 1
        until index > length or text:sub(index, index):match("[%d%+%-%.eE]") == nil
        return tonumber(text:sub(start, index - 1))
    end

    local function parse_array()
        index = index + 1
        skip_ws()
        local result = {}
        if text:sub(index, index) == "]" then
            index = index + 1
            return result
        end
        while index <= length do
            result[#result + 1] = parse_value()
            skip_ws()
            local current = text:sub(index, index)
            if current == "," then
                index = index + 1
                skip_ws()
            elseif current == "]" then
                index = index + 1
                return result
            else
                return result
            end
        end
        return result
    end

    local function parse_object()
        index = index + 1
        skip_ws()
        local result = {}
        if text:sub(index, index) == "}" then
            index = index + 1
            return result
        end
        while index <= length do
            local key = parse_string()
            skip_ws()
            index = index + 1
            skip_ws()
            result[key] = parse_value()
            skip_ws()
            local current = text:sub(index, index)
            if current == "," then
                index = index + 1
                skip_ws()
            elseif current == "}" then
                index = index + 1
                return result
            else
                return result
            end
        end
        return result
    end

    function parse_value()
        skip_ws()
        local current = text:sub(index, index)
        if current == '"' then
            return parse_string()
        elseif current == "{" then
            return parse_object()
        elseif current == "[" then
            return parse_array()
        elseif current == "-" or current:match("%d") ~= nil then
            return parse_number()
        elseif text:sub(index, index + 3) == "true" then
            index = index + 4
            return true
        elseif text:sub(index, index + 4) == "false" then
            index = index + 5
            return false
        elseif text:sub(index, index + 3) == "null" then
            index = index + 4
            return nil
        end
        return nil
    end

    local ok, result = pcall(parse_value)
    if ok then
        return result
    end
    return nil
end

local function encode_url_component(value)
    return tostring(value or ""):gsub("([^%w%-_%.~])", function(char)
        return string.format("%%%02X", string.byte(char))
    end)
end

local function query_hex(context, path)
    local ok, err = ensure_query_available(context)
    if not ok then
        return nil, err
    end
    local command = COMMAND_ENV_PREFIX .. " " .. shell_quote(QUERY_BINARY) .. " -fsSL " .. shell_quote("https://hex.pm/api" .. path)
    local result = exec_run(context, command)
    if not is_success(result) then
        return nil, trim(result.stderr) ~= "" and trim(result.stderr) or "hex query failed"
    end
    return decode_json(result.stdout or "")
end

local function manifest_path(context)
    return join_path(project_root(context, {}), "manifest.toml")
end

local function list_from_manifest(context)
    local content = read_file(context, manifest_path(context))
    if content == nil then
        return nil
    end
    return parse_manifest_packages(content)
end

local function list_from_cli(context)
    local command = build_project_command(context, {}, { "deps", "list" })
    local result = exec_run(context, command)
    if not is_success(result) then
        return nil
    end
    return parse_deps_list_output(result.stdout)
end

local function find_installed_item(context, name)
    for _, item in ipairs(list_from_manifest(context) or {}) do
        if lower(item.name) == lower(name) then
            return item
        end
    end
    return nil
end

local function remote_item_from_package(payload)
    if type(payload) ~= "table" or trim(payload.name) == "" then
        return nil
    end
    local meta = type(payload.meta) == "table" and payload.meta or {}
    local links = type(meta.links) == "table" and meta.links or {}
    local releases = type(payload.releases) == "table" and payload.releases or {}
    local latest = trim(payload.latest_stable_version or payload.latest_version or "")
    if latest == "" and #releases > 0 then
        latest = trim(read_field(releases[1], "version"))
    end
    local licenses = read_field(meta, "licenses")
    local license = nil
    if type(licenses) == "table" and #licenses > 0 then
        license = licenses[1]
    end
    return {
        name = trim(payload.name),
        packageId = trim(payload.name),
        version = latest ~= "" and latest or nil,
        summary = trim(meta.description),
        description = trim(meta.description),
        homepage = trim(links.Website or payload.html_url or ""),
        repository = trim(links.Repository or ""),
        license = license,
        installed = false,
        status = "available",
        packageType = "library",
        extraFields = {
            docsUrl = trim(payload.docs_html_url or ""),
            downloads = read_field(payload, "downloads"),
            latestStableVersion = trim(payload.latest_stable_version or ""),
        },
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
    return { "Development", "Package Manager", "Gleam" }
end

function plugin.getMissingPackages(packages)
    if not command_exists(nil, REQUIRED_BINARY) then
        return packages or { REQUIRED_BINARY }
    end
    return {}
end

function plugin.install(context, packages)
    local available, available_err = ensure_available(context)
    if not available then
        tx_failed(context, available_err)
        return false
    end
    local ok, _, err = ensure_project(context, packages)
    if not ok then
        tx_failed(context, err)
        return false
    end
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end
    begin_step(context, "install gleam dependencies")
    for _, package in ipairs(requested) do
        local selector = package_selector(package)
        if selector == nil then
            tx_failed(context, "gleam install failed: missing package name")
            return false
        end
        local args = { "add" }
        if package_is_dev(package) then
            args[#args + 1] = "--dev"
        end
        args[#args + 1] = shell_quote(selector)
        local command = build_project_command(context, requested, args)
        local result = exec_run(context, command)
        if not is_success(result) then
            tx_failed(context, "gleam install failed")
            return false
        end
        emit_event(context, "installed", package)
    end
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    begin_step(context, "install local gleam dependency")
    local local_path = trim(path or read_field(context, "localPath"))
    local payload = { path = local_path, reason = "local-install-unsupported" }
    tx_failed(context, "gleam installLocal is not supported; use path dependency in gleam.toml")
    emit_event(context, "unavailable", payload)
    return false
end

function plugin.remove(context, packages)
    local available, available_err = ensure_available(context)
    if not available then
        tx_failed(context, available_err)
        return false
    end
    local ok, _, err = ensure_project(context, packages)
    if not ok then
        tx_failed(context, err)
        return false
    end
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end
    begin_step(context, "remove gleam dependencies")
    for _, package in ipairs(requested) do
        local name = trim(package_name(package)):match("^([^@]+)")
        if name == nil or name == "" then
            tx_failed(context, "gleam remove failed: missing package name")
            return false
        end
        local command = build_project_command(context, requested, { "remove", shell_quote(name) })
        local result = exec_run(context, command)
        if not is_success(result) then
            tx_failed(context, "gleam remove failed")
            return false
        end
        emit_event(context, "deleted", package)
    end
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local available, available_err = ensure_available(context)
    if not available then
        tx_failed(context, available_err)
        return false
    end
    local ok, _, err = ensure_project(context, packages)
    if not ok then
        tx_failed(context, err)
        return false
    end
    begin_step(context, "update gleam dependencies")
    local args = { "update" }
    for _, package in ipairs(packages or {}) do
        local name = trim(package_name(package)):match("^([^@]+)")
        if name ~= nil and name ~= "" then
            args[#args + 1] = shell_quote(name)
        end
    end
    local command = build_project_command(context, packages or {}, args)
    local result = exec_run(context, command)
    if not is_success(result) then
        tx_failed(context, "gleam update failed")
        return false
    end
    for _, package in ipairs(packages or {}) do
        emit_event(context, "updated", package)
    end
    tx_success(context)
    return true
end

function plugin.list(context)
    local available, available_err = ensure_available(context)
    if not available then
        tx_failed(context, available_err)
        return {}
    end
    local ok, _, err = ensure_project(context, {})
    if not ok then
        tx_failed(context, err)
        return {}
    end
    local items = list_from_manifest(context)
    if items == nil or #items == 0 then
        items = list_from_cli(context) or {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local available, available_err = ensure_available(context)
    if not available then
        tx_failed(context, available_err)
        return {}
    end
    local ok, _, err = ensure_project(context, {})
    if not ok then
        tx_failed(context, err)
        return {}
    end
    local command = build_project_command(context, {}, { "deps", "outdated" })
    local result = exec_run(context, command)
    if not is_success(result) then
        log_warn(context, "gleam deps outdated failed")
        emit_event(context, "outdated", {})
        return {}
    end
    local items = parse_outdated_output(result.stdout)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(context, "prompt"))
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end
    local payload, err = query_hex(context, "/packages?search=" .. encode_url_component(query))
    if payload == nil then
        log_warn(context, err or "gleam search failed")
        emit_event(context, "searched", {})
        return {}
    end
    local items = {}
    for _, raw in ipairs(payload or {}) do
        local item = remote_item_from_package(raw)
        if item ~= nil then
            items[#items + 1] = item
        end
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = trim(name or read_field(context, "prompt"))
    if query == "" then
        emit_event(context, "informed", {})
        return {}
    end
    local base_name = query:match("^([^@]+)") or query

    local flags = collect_flags(context, {})
    local explicit_root = first_nonempty(flag_value(flags, "cwd"), read_field(context, "cwd"), read_field(context, "workspaceRoot"), read_field(context, "workingDirectory"))
    if explicit_root ~= nil then
        local available = ensure_available(context)
        if available then
            local ok = ensure_project(context, {})
            if ok then
                local installed = find_installed_item(context, base_name)
                if installed ~= nil then
                    emit_event(context, "informed", installed)
                    return installed
                end
            end
        end
    end

    local payload, err = query_hex(context, "/packages/" .. encode_url_component(base_name))
    if payload == nil then
        log_warn(context, err or "gleam info failed")
        emit_event(context, "informed", {})
        return {}
    end
    local item = remote_item_from_package(payload) or {}
    emit_event(context, "informed", item)
    return item
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
        capabilities = { "dependency-install", "dependency-remove", "dependency-update", "dependency-query", "project-manifest-edit" },
        ecosystemScopes = { "gleam", "hexpm" },
        writeScopes = {
            "user-home-subpath:.cache/reqpack/gleam",
            "project-file:gleam.toml",
            "project-file:manifest.toml",
            "project-subpath:build",
        },
        networkScopes = { "hex.pm" },
        privilegeLevel = "none",
        purlType = "hex",
    }
end

return plugin
