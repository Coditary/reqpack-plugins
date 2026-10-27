plugin = {}

local PLUGIN_ID = "qt"
local PLUGIN_NAME = "Qt"
local PLUGIN_VERSION = "0.1.0"
local DEFAULT_INSTALLER_URL = "https://download.qt.io/official_releases/online_installers/qt-online-installer-linux-x64-online.run"
local REQUIRED_DOWNLOAD_BINARY = "curl"

plugin.fileExtensions = { ".qbsp", ".7z" }

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

local function split_lines(value)
    local lines = {}
    local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
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

local function basename(path)
    local cleaned = trim(path)
    if cleaned == "" then
        return ""
    end
    return cleaned:match("([^/]+)$") or cleaned
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

local function normalize_exec_result(...)
    local result = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        local value_type = type(value)
        if value_type == "table" then
            for key, item in pairs(value) do
                if result[key] == nil then
                    result[key] = item
                end
            end
        elseif value_type == "userdata" then
            for _, key in ipairs({ "success", "ok", "stdout", "stderr", "exitCode", "exit_code", "code", "status", "stdoutText", "stderrText" }) do
                local ok, item = pcall(function()
                    return value[key]
                end)
                if ok and item ~= nil and result[key] == nil then
                    result[key] = item
                end
            end
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
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return normalize_exec_result(context.exec.run(command))
    end
    if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
        return normalize_exec_result(reqpack.exec.run(command))
    end
    return {
        success = false,
        stdout = "",
        stderr = "missing ReqPack exec runner",
        exitCode = 127,
    }
end

local function flag_value(flags, prefix)
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if cleaned:sub(1, #prefix) == prefix then
            return trim(cleaned:sub(#prefix + 1))
        end
    end
    return ""
end

local function first_flag_value(context, packages, prefix)
    local context_value = flag_value(context and context.flags or {}, prefix)
    if context_value ~= "" then
        return context_value
    end
    for _, pkg in ipairs(packages or {}) do
        local package_value = flag_value(object_flags(pkg), prefix)
        if package_value ~= "" then
            return package_value
        end
    end
    return ""
end

local function get_plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR)
    if dir ~= "" then
        return dir
    end
    return "q/qt"
end

local function data_root_from_context(context, packages)
    local from_flags = first_flag_value(context, packages, "data-root=")
    if from_flags ~= "" then
        return from_flags
    end
    local fixture_root = os ~= nil and type(os.getenv) == "function" and trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT")) or ""
    if fixture_root ~= "" then
        return join_path(fixture_root, ".reqpack-data")
    end
    return join_path(get_plugin_dir(), ".reqpack-data")
end

local function state_paths(root, installer_url)
    local base = trim(root)
    if base == "" then
        base = join_path(get_plugin_dir(), ".reqpack-data")
    end
    local url = non_empty(installer_url) or DEFAULT_INSTALLER_URL
    return {
        root = base,
        qt_root = join_path(base, "qt-root"),
        cache = join_path(base, "cache"),
        downloads = join_path(base, "downloads"),
        tmp = join_path(base, "tmp"),
        installer = join_path(base, "downloads", basename(url)),
    }
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function executable_exists(context, path)
    local result = exec_run(context, "test -x " .. shell_quote(path))
    return result ~= nil and result.success == true
end

local function env_prefix()
    return "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1'"
end

local function append_option(args, option, value)
    if non_empty(value) == nil then
        return
    end
    args[#args + 1] = option
    args[#args + 1] = value
end

local function command_parts(binary, args)
    local parts = { env_prefix(), shell_quote(binary) }
    for _, arg in ipairs(args or {}) do
        local cleaned = trim(arg)
        if cleaned ~= "" then
            parts[#parts + 1] = shell_quote(cleaned)
        end
    end
    return table.concat(parts, " ")
end

local function common_cli_args(context, packages, paths, include_confirm)
    local args = {
        "--cache-path", paths.cache,
    }
    local mirror = first_flag_value(context, packages, "mirror=")
    local repository = first_flag_value(context, packages, "repository=")
    local temp_repository = first_flag_value(context, packages, "temp-repository=")
    local email = first_flag_value(context, packages, "email=")
    local password = first_flag_value(context, packages, "pw=")
    append_option(args, "--mirror", mirror)
    append_option(args, "--add-repository", repository)
    append_option(args, "--add-temp-repository", temp_repository)
    append_option(args, "--email", email)
    append_option(args, "--pw", password)
    if include_confirm then
        args[#args + 1] = "--accept-licenses"
        args[#args + 1] = "--accept-obligations"
        args[#args + 1] = "--default-answer"
        args[#args + 1] = "--confirm-command"
    end
    return args
end

local function default_installer_url(context, packages)
    local override = first_flag_value(context, packages, "installer-url=")
    if override ~= "" then
        return override
    end
    return DEFAULT_INSTALLER_URL
end

local function maintenance_tool_candidates(paths)
    return {
        join_path(paths.qt_root, "MaintenanceTool"),
        join_path(paths.qt_root, "MaintenanceTool.run"),
        join_path(paths.qt_root, "maintenancetool"),
        join_path(paths.qt_root, "bin", "MaintenanceTool"),
    }
end

local function find_maintenance_tool(context, paths, packages)
    local override = first_flag_value(context, packages, "maintenance-tool=")
    if override ~= "" and executable_exists(context, override) then
        return override
    end
    for _, candidate in ipairs(maintenance_tool_candidates(paths)) do
        if executable_exists(context, candidate) then
            return candidate
        end
    end
    if command_exists(context, "MaintenanceTool") then
        return "MaintenanceTool"
    end
    if command_exists(context, "maintenancetool") then
        return "maintenancetool"
    end
    return nil
end

local function ensure_installer_binary(context, paths, packages)
    if executable_exists(context, paths.installer) then
        return paths.installer, nil
    end
    if not command_exists(context, REQUIRED_DOWNLOAD_BINARY) then
        return nil, "qt bootstrap requires curl"
    end
    local url = default_installer_url(context, packages)
    local command = "mkdir -p " .. shell_quote(paths.downloads)
        .. " && " .. REQUIRED_DOWNLOAD_BINARY .. " -fL --output " .. shell_quote(paths.installer) .. " " .. shell_quote(url)
        .. " && chmod +x " .. shell_quote(paths.installer)
    local result = exec_run(context, command)
    if result == nil or result.success ~= true then
        return nil, non_empty(result and result.stderr) or non_empty(result and result.stdout) or "qt online installer download failed"
    end
    return paths.installer, nil
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or "")
end

local function package_action(pkg)
    return lower(read_field(pkg, "action") or "")
end

local function build_items_from_packages(packages)
    local items = {}
    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        if name ~= "" then
            items[#items + 1] = {
                name = name,
                packageId = name,
                packageType = "qt-component",
            }
        end
    end
    return items
end

local function extract_xml_block(raw, root_tag)
    local text = tostring(raw or "")
    local start_pos = text:find("<" .. root_tag)
    local end_tag = "</" .. root_tag .. ">"
    if start_pos == nil then
        return nil
    end
    local end_pos = text:find(end_tag, start_pos, true)
    if end_pos == nil then
        return nil
    end
    return text:sub(start_pos, end_pos + #end_tag - 1)
end

local function decode_xml_entities(value)
    local text = tostring(value or "")
    text = text:gsub("&quot;", '"')
    text = text:gsub("&apos;", "'")
    text = text:gsub("&lt;", "<")
    text = text:gsub("&gt;", ">")
    text = text:gsub("&amp;", "&")
    return text
end

local function parse_xml_attributes(fragment)
    local attrs = {}
    for key, value in tostring(fragment or ""):gmatch("([%w_:%-]+)%s*=%s*\"([^\"]*)\"") do
        attrs[key] = decode_xml_entities(value)
    end
    return attrs
end

local function parse_available_packages(raw)
    local xml = extract_xml_block(raw, "availablepackages") or tostring(raw or "")
    local items = {}
    for fragment in xml:gmatch("<package%s+[^>]-/>") do
        local attrs = parse_xml_attributes(fragment)
        local package_id = non_empty(attrs.name)
        if package_id ~= nil then
            items[#items + 1] = {
                name = package_id,
                packageId = package_id,
                version = non_empty(attrs.version),
                summary = non_empty(attrs.displayname),
                packageType = "qt-component",
                installed = false,
                status = "available",
            }
        end
    end
    return items
end

local function parse_updates(raw)
    local xml = extract_xml_block(raw, "updates") or tostring(raw or "")
    local items = {}
    for fragment in xml:gmatch("<update%s+[^>]-/>") do
        local attrs = parse_xml_attributes(fragment)
        local package_id = non_empty(attrs.name)
        if package_id ~= nil then
            items[#items + 1] = {
                name = package_id,
                packageId = package_id,
                latestVersion = non_empty(attrs.version),
                packageType = "qt-component",
                installed = true,
                status = "outdated",
            }
        end
    end
    return items
end

local function finalize_list_item(target, items)
    if target.packageId ~= nil then
        target.name = target.packageId
        target.packageType = "qt-component"
        target.installed = true
        target.status = "installed"
        items[#items + 1] = target
    end
end

local function strip_log_prefix(line)
    local cleaned = tostring(line or "")
    cleaned = cleaned:gsub("^%[[^%]]+%]%s*", "")
    return cleaned
end

local function parse_installed_packages(raw)
    local items = {}
    local current = {}
    for _, line in ipairs(split_lines(raw)) do
        local cleaned = trim(strip_log_prefix(line))
        if cleaned:match("^Id:%s*") then
            finalize_list_item(current, items)
            current = { packageId = trim(cleaned:match("^Id:%s*(.+)$") or "") }
        elseif cleaned:match("^[Dd]isplay name:%s*") then
            current.summary = trim(cleaned:match("^[Dd]isplay name:%s*(.+)$") or "")
        elseif cleaned:match("^[Vv]ersion:%s*") then
            current.version = trim(cleaned:match("^[Vv]ersion:%s*(.+)$") or "")
        end
    end
    finalize_list_item(current, items)
    return items
end

local function exact_regex(value)
    local escaped = tostring(value or ""):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    return "^" .. escaped .. "$"
end

local function query_list_items(context, paths, packages)
    local tool = find_maintenance_tool(context, paths, packages)
    if tool == nil then
        return nil, "qt maintenance tool not found"
    end
    local args = common_cli_args(context, packages, paths, false)
    args[#args + 1] = "list"
    local result = exec_run(context, command_parts(tool, args))
    if result == nil or result.success ~= true then
        return nil, non_empty(result and result.stderr) or non_empty(result and result.stdout) or "qt list failed"
    end
    return parse_installed_packages(result.stdout), nil
end

local function query_search_items(context, paths, packages, prompt)
    local tool = find_maintenance_tool(context, paths, packages)
    local tool_packages = packages or {}
    if tool == nil then
        local installer, err = ensure_installer_binary(context, paths, tool_packages)
        if installer == nil then
            return nil, err
        end
        tool = installer
    end
    local args = common_cli_args(context, tool_packages, paths, false)
    args[#args + 1] = "--type"
    args[#args + 1] = "package"
    args[#args + 1] = "search"
    args[#args + 1] = non_empty(prompt) or ".*"
    local result = exec_run(context, command_parts(tool, args))
    if result == nil then
        return nil, "qt search failed"
    end
    local items = parse_available_packages(result.stdout)
    if result.success ~= true and #items == 0 then
        return nil, non_empty(result.stderr) or non_empty(result.stdout) or "qt search failed"
    end
    return items, nil
end

local function query_outdated_items(context, paths, packages)
    local tool = find_maintenance_tool(context, paths, packages)
    if tool == nil then
        return nil, "qt maintenance tool not found"
    end
    local args = common_cli_args(context, packages, paths, false)
    args[#args + 1] = "check-updates"
    local result = exec_run(context, command_parts(tool, args))
    if result == nil then
        return nil, "qt check-updates failed"
    end
    local items = parse_updates(result.stdout)
    if result.success ~= true and #items == 0 then
        if result.exitCode == 1 then
            return {}, nil
        end
        return nil, non_empty(result.stderr) or non_empty(result.stdout) or "qt check-updates failed"
    end
    return items, nil
end

local function find_item_by_id(items, package_id)
    for _, item in ipairs(items or {}) do
        if trim(item.packageId or item.name or "") == trim(package_id) then
            return item
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

local function merge_items(left, right)
    if left == nil and right == nil then
        return {}
    end
    if left == nil then
        return shallow_copy(right)
    end
    if right == nil then
        return shallow_copy(left)
    end
    local merged = shallow_copy(left)
    for key, value in pairs(right) do
        if merged[key] == nil or merged[key] == "" then
            merged[key] = value
        end
    end
    return merged
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
    return { "sdk", "development", "package-manager" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    local paths = state_paths(data_root_from_context(nil, requested), default_installer_url(nil, requested))
    local tool = find_maintenance_tool(nil, paths, requested)
    if tool == nil then
        return requested
    end

    local installed_items = query_list_items(nil, paths, requested)
    if installed_items == nil then
        return requested
    end

    local installed_set = {}
    for _, item in ipairs(installed_items or {}) do
        installed_set[item.packageId] = item
    end

    local needs_outdated = false
    for _, pkg in ipairs(requested) do
        if package_action(pkg) == "update" then
            needs_outdated = true
            break
        end
    end

    local outdated_set = {}
    if needs_outdated then
        local outdated_items = query_outdated_items(nil, paths, requested)
        if outdated_items == nil then
            return requested
        end
        for _, item in ipairs(outdated_items or {}) do
            outdated_set[item.packageId] = item
        end
    end

    local filtered = {}
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        local action = package_action(pkg)
        if action == "remove" then
            if installed_set[name] ~= nil then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "update" then
            if outdated_set[name] ~= nil then
                filtered[#filtered + 1] = pkg
            end
        elseif installed_set[name] == nil then
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

    local installer_url = default_installer_url(context, requested)
    local paths = state_paths(data_root_from_context(context, requested), installer_url)
    local tool = find_maintenance_tool(context, paths, requested)
    local args = common_cli_args(context, requested, paths, true)
    local step = "install qt packages"

    if tool == nil then
        begin_step(context, "bootstrap qt installation")
        local installer, err = ensure_installer_binary(context, paths, requested)
        if installer == nil then
            tx_failed(context, err)
            return false
        end
        tool = installer
        args[#args + 1] = "--root"
        args[#args + 1] = paths.qt_root
        step = "bootstrap qt packages"
    end

    begin_step(context, step)
    args[#args + 1] = "install"
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        if name == "" then
            tx_failed(context, "qt install requires package name")
            return false
        end
        args[#args + 1] = name
    end

    local result = exec_run(context, command_parts(tool, args))
    if result == nil or result.success ~= true then
        tx_failed(context, non_empty(result and result.stderr) or non_empty(result and result.stdout) or "qt install failed")
        return false
    end

    emit_event(context, "installed", build_items_from_packages(requested))
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local cleaned_path = trim(path)
    if cleaned_path == "" then
        tx_failed(context, "qt installLocal requires local .qbsp or .7z path")
        return false
    end
    local suffix = lower(cleaned_path)
    if not suffix:match("%.qbsp$") and not suffix:match("%.7z$") then
        tx_failed(context, "qt installLocal supports only .qbsp and .7z files")
        return false
    end

    local paths = state_paths(data_root_from_context(context, {}), default_installer_url(context, {}))
    local tool = find_maintenance_tool(context, paths, {})
    if tool == nil then
        tx_failed(context, "qt installLocal requires existing MaintenanceTool")
        return false
    end

    begin_step(context, "install local qt repository")
    local args = common_cli_args(context, {}, paths, true)
    args[#args + 1] = "--install-compressed-repository"
    args[#args + 1] = cleaned_path
    local result = exec_run(context, command_parts(tool, args))
    if result == nil or result.success ~= true then
        tx_failed(context, non_empty(result and result.stderr) or non_empty(result and result.stdout) or "qt installLocal failed")
        return false
    end
    emit_event(context, "installed", { path = cleaned_path, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end
    local paths = state_paths(data_root_from_context(context, requested), default_installer_url(context, requested))
    local tool = find_maintenance_tool(context, paths, requested)
    if tool == nil then
        tx_failed(context, "qt remove requires existing MaintenanceTool")
        return false
    end
    begin_step(context, "remove qt packages")
    local args = common_cli_args(context, requested, paths, true)
    args[#args + 1] = "remove"
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        if name == "" then
            tx_failed(context, "qt remove requires package name")
            return false
        end
        args[#args + 1] = name
    end
    local result = exec_run(context, command_parts(tool, args))
    if result == nil or result.success ~= true then
        tx_failed(context, non_empty(result and result.stderr) or non_empty(result and result.stdout) or "qt remove failed")
        return false
    end
    emit_event(context, "deleted", build_items_from_packages(requested))
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    local paths = state_paths(data_root_from_context(context, requested), default_installer_url(context, requested))
    local tool = find_maintenance_tool(context, paths, requested)
    if tool == nil then
        tx_failed(context, "qt update requires existing MaintenanceTool")
        return false
    end
    begin_step(context, "update qt packages")
    local args = common_cli_args(context, requested, paths, true)
    args[#args + 1] = "update"
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        if name ~= "" then
            args[#args + 1] = name
        end
    end
    local result = exec_run(context, command_parts(tool, args))
    if result == nil or result.success ~= true then
        tx_failed(context, non_empty(result and result.stderr) or non_empty(result and result.stdout) or "qt update failed")
        return false
    end
    emit_event(context, "updated", build_items_from_packages(requested))
    tx_success(context)
    return true
end

function plugin.list(context)
    local paths = state_paths(data_root_from_context(context, {}), default_installer_url(context, {}))
    local items, err = query_list_items(context, paths, {})
    if items == nil then
        log_warn(context, err or "qt list failed")
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local paths = state_paths(data_root_from_context(context, {}), default_installer_url(context, {}))
    local items, err = query_outdated_items(context, paths, {})
    if items == nil then
        log_warn(context, err or "qt check-updates failed")
        items = {}
    else
        local installed_items = query_list_items(context, paths, {}) or {}
        for _, item in ipairs(items) do
            local installed_item = find_item_by_id(installed_items, item.packageId)
            if installed_item ~= nil then
                item.version = installed_item.version
                item.summary = item.summary or installed_item.summary
            end
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = non_empty(prompt) or ".*"
    local paths = state_paths(data_root_from_context(context, {}), default_installer_url(context, {}))
    local items, err = query_search_items(context, paths, {}, query)
    if items == nil then
        log_warn(context, err or "qt search failed")
        items = {}
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local package_id = trim(name)
    if package_id == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local paths = state_paths(data_root_from_context(context, { { name = package_id } }), default_installer_url(context, { { name = package_id } }))
    local installed_items = query_list_items(context, paths, {}) or {}
    local search_items = query_search_items(context, paths, {}, exact_regex(package_id)) or {}
    local installed_item = find_item_by_id(installed_items, package_id)
    local remote_item = find_item_by_id(search_items, package_id)
    local item = merge_items(installed_item, remote_item)
    if next(item) == nil then
        item = {}
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.init()
    if command_exists(nil, REQUIRED_DOWNLOAD_BINARY) then
        return true
    end
    if command_exists(nil, "MaintenanceTool") then
        return true
    end
    if command_exists(nil, "maintenancetool") then
        return true
    end
    return false
end

function plugin.shutdown()
    return true
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "qt", "qtifw" },
        writeScopes = {
            { kind = "plugin-data", value = "q/qt/.reqpack-data" },
        },
        networkScopes = { "download.qt.io" },
        privilegeLevel = "user",
        osvEcosystem = "Generic",
        purlType = "generic",
        versionComparatorProfile = "lexicographic",
    }
end

return plugin
