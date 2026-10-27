plugin = {}

local PLUGIN_ID = "eiffelstudio"
local PLUGIN_NAME = "EiffelStudio"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "iron"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
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

local function run_global(command)
    if reqpack == nil or reqpack.exec == nil or type(reqpack.exec.run) ~= "function" then
        return {
            success = false,
            stdout = "",
            stderr = "reqpack.exec.run unavailable",
        }
    end
    return reqpack.exec.run(command)
end

local function normalize_run_result(first)
    if type(first) == "table" or type(first) == "userdata" then
        local result = first
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

    return {
        success = false,
        stdout = "",
        stderr = "unexpected exec result",
    }
end

local function exec_run(context, command)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return normalize_run_result(context.exec.run(command))
    end
    return normalize_run_result(run_global(command))
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. binary .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function request_object(context)
    return read_field(context, "request")
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

local function request_packages(context, fallback)
    return sequence_values(read_field(request_object(context), "packages") or read_field(context, "packages") or fallback or {})
end

local function request_prompt(context, fallback)
    return non_empty(fallback) or non_empty(read_field(request_object(context), "prompt")) or non_empty(read_field(context, "prompt")) or ""
end

local function request_local_path(context, fallback)
    return non_empty(fallback)
        or non_empty(read_field(request_object(context), "localPath"))
        or non_empty(read_field(request_object(context), "path"))
        or non_empty(read_field(context, "localPath"))
        or non_empty(read_field(context, "path"))
end

local function package_target(pkg)
    return non_empty(read_field(pkg, "name"))
        or non_empty(read_field(pkg, "sourceUrl"))
        or non_empty(read_field(pkg, "uri"))
        or non_empty(read_field(pkg, "path"))
end

local function build_package_id(name, version)
    local cleaned_name = trim(name)
    local cleaned_version = trim(version)
    if cleaned_name == "" then
        return nil
    end
    if cleaned_version == "" then
        return PLUGIN_ID .. "/" .. cleaned_name
    end
    return PLUGIN_ID .. "/" .. cleaned_name .. "/" .. cleaned_version
end

local function sort_items(items)
    table.sort(items, function(left, right)
        local left_key = trim(left.packageId or left.name or "")
        local right_key = trim(right.packageId or right.name or "")
        return left_key < right_key
    end)
    return items
end

local function normalize_item(item)
    if item == nil then
        return nil
    end
    item.name = trim(item.name or "")
    item.version = non_empty(item.version)
    item.summary = non_empty(item.summary)
    item.description = non_empty(item.description or item.summary)
    item.repository = non_empty(item.repository)
    item.license = non_empty(item.license)
    item.homepage = non_empty(item.homepage)
    item.installPath = non_empty(item.installPath)
    item.packageType = item.packageType or "library"
    if item.installed == nil then
        item.installed = false
    end
    if item.status == nil or trim(item.status) == "" then
        item.status = item.installed and "installed" or "available"
    end
    item.packageId = item.packageId or build_package_id(item.name, item.version)
    if type(item.extraFields) == "table" and next(item.extraFields) == nil then
        item.extraFields = nil
    end
    return item
end

local function parse_name_summary_line(line)
    local cleaned = trim(line)
    if cleaned == "" then
        return nil
    end

    local name, version, summary = cleaned:match("^(%S+)%s+v?([%d][%w%._%-%+]*)%s*%-+%s*(.+)$")
    if name ~= nil then
        return normalize_item({
            name = name,
            version = version,
            summary = summary,
            installed = true,
        })
    end

    name, summary = cleaned:match("^(%S+)%s*%-+%s*(.+)$")
    if name ~= nil then
        return normalize_item({
            name = name,
            summary = summary,
            installed = true,
        })
    end

    name, summary = cleaned:match("^(%S+)%s+%((installed)%)$")
    if name ~= nil then
        return normalize_item({
            name = name,
            summary = summary,
            installed = true,
        })
    end

    name = cleaned:match("^(%S+)")
    if name ~= nil then
        return normalize_item({
            name = name,
            summary = cleaned ~= name and trim(cleaned:sub(#name + 1)) or nil,
            installed = true,
        })
    end

    return nil
end

local function parse_list_output(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local item = parse_name_summary_line(line)
        if item ~= nil and item.name ~= "" then
            items[#items + 1] = item
        end
    end
    return sort_items(items)
end

local function parse_search_output(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            local name, version, summary = cleaned:match("^(%S+)%s+v?([%d][%w%._%-%+]*)%s*%-+%s*(.+)$")
            if name == nil then
                name, summary = cleaned:match("^(%S+)%s*%-+%s*(.+)$")
            end
            if name == nil then
                name = cleaned:match("^(%S+)")
            end
            if name ~= nil then
                items[#items + 1] = normalize_item({
                    name = name,
                    version = version,
                    summary = summary,
                    description = summary,
                    installed = false,
                })
            end
        end
    end
    return sort_items(items)
end

local function parse_yes_no(value)
    local cleaned = lower(trim(value))
    return cleaned == "yes" or cleaned == "true" or cleaned == "installed"
end

local function parse_info_output(stdout)
    local item = {
        installed = false,
        extraFields = {},
    }
    local description_lines = {}

    for _, line in ipairs(split_lines(stdout)) do
        local key, value = line:match("^([%a][%w _%-]*)%s*:%s*(.-)%s*$")
        if key ~= nil then
            local normalized = lower(key)
            local cleaned_value = trim(value)
            if normalized == "name" or normalized == "package" then
                item.name = cleaned_value
            elseif normalized == "title" then
                item.summary = cleaned_value
            elseif normalized == "version" then
                item.version = cleaned_value
            elseif normalized == "summary" then
                item.summary = cleaned_value
            elseif normalized == "description" then
                description_lines[#description_lines + 1] = cleaned_value
            elseif normalized == "license" then
                item.license = cleaned_value
            elseif normalized == "repository" then
                item.repository = cleaned_value
            elseif normalized == "path" then
                item.installPath = cleaned_value
            elseif normalized == "homepage" or normalized == "url" then
                item.homepage = cleaned_value
            elseif normalized == "uri" then
                item.extraFields.nativeUri = cleaned_value
            elseif normalized == "id" then
                item.extraFields.nativeId = cleaned_value
            elseif normalized == "installed" or normalized == "status" then
                item.installed = parse_yes_no(cleaned_value)
                item.status = item.installed and "installed" or "available"
            else
                item.extraFields[normalized] = cleaned_value
            end
        elseif trim(line) ~= "" then
            description_lines[#description_lines + 1] = trim(line)
        end
    end

    if item.description == nil and #description_lines > 0 then
        item.description = table.concat(description_lines, "\n")
    end
    if item.summary == nil then
        item.summary = item.description and (item.description:match("^([^\n]+)") or item.description) or nil
    end
    return normalize_item(item)
end

local function query_install_path(context, name)
    local cleaned = trim(name)
    if cleaned == "" then
        return nil
    end
    local result = exec_run(context, "iron path " .. shell_quote(cleaned))
    if result == nil or result.success ~= true then
        return nil
    end
    for _, line in ipairs(split_lines(result.stdout)) do
        local candidate = trim(line)
        if candidate ~= "" then
            return candidate
        end
    end
    return nil
end

local function require_binary(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true
    end
    tx_failed(context, "iron binary missing")
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
    return { "language", "package-manager", "eiffel" }
end

function plugin.getMissingPackages()
    if command_exists(nil, REQUIRED_BINARY) then
        return {}
    end
    return { REQUIRED_BINARY }
end

function plugin.init()
    return true
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "eiffel" },
        writeScopes = {},
        networkScopes = {},
        privilegeLevel = "none",
        purlType = "generic",
    }
end

function plugin.resolvePackage(_, package)
    if type(package) ~= "table" then
        return nil
    end
    local target = package_target(package)
    if target == nil then
        return nil
    end
    local resolved = shallow_copy(package)
    resolved.name = trim(target)
    resolved.packageId = build_package_id(resolved.name, trim(read_field(package, "version") or ""))
    resolved.packageType = "library"
    resolved.type = "package"
    return resolved
end

function plugin.install(context, packages)
    local requested = request_packages(context, packages)
    if #requested == 0 then
        tx_success(context)
        return true
    end
    if not require_binary(context) then
        return false
    end

    for _, package in ipairs(requested) do
        local target = package_target(package)
        if target == nil then
            tx_failed(context, "missing package target")
            return false
        end
        begin_step(context, "Installing " .. trim(target))
        local result = exec_run(context, "iron install " .. shell_quote(target))
        if result == nil or result.success ~= true then
            tx_failed(context, "iron install failed")
            return false
        end
    end

    emit_event(context, "installed", requested)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = request_local_path(context, path)
    if local_path == nil then
        tx_failed(context, "missing local path")
        return false
    end
    if not require_binary(context) then
        return false
    end

    begin_step(context, "Installing local EiffelStudio package")
    local result = exec_run(context, "iron install " .. shell_quote(local_path))
    if result == nil or result.success ~= true then
        tx_failed(context, "iron local install failed")
        return false
    end

    emit_event(context, "installed", {
        normalize_item({
            name = local_path,
            packageId = local_path,
            installed = true,
            packageType = "library",
        })
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = request_packages(context, packages)
    if #requested == 0 then
        tx_success(context)
        return true
    end
    if not require_binary(context) then
        return false
    end

    for _, package in ipairs(requested) do
        local target = package_target(package)
        if target == nil then
            tx_failed(context, "missing package target")
            return false
        end
        begin_step(context, "Removing " .. trim(target))
        local result = exec_run(context, "iron remove " .. shell_quote(target))
        if result == nil or result.success ~= true then
            tx_failed(context, "iron remove failed")
            return false
        end
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context)
    if not require_binary(context) then
        return false
    end
    local requested = request_packages(context, nil)
    begin_step(context, "Updating EiffelStudio package metadata")
    local result = exec_run(context, "iron update")
    if result == nil or result.success ~= true then
        tx_failed(context, "iron update failed")
        return false
    end
    emit_event(context, "updated", requested)
    tx_success(context)
    return true
end

function plugin.list(context)
    if not command_exists(context, REQUIRED_BINARY) then
        emit_event(context, "listed", {})
        return {}
    end

    local result = exec_run(context, "iron list --installed")
    if result == nil or result.success ~= true then
        log_warn(context, "iron list --installed failed")
        emit_event(context, "listed", {})
        return {}
    end

    local items = parse_list_output(result.stdout)
    for _, item in ipairs(items) do
        item.installPath = query_install_path(context, item.name)
        normalize_item(item)
    end
    sort_items(items)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    if not command_exists(context, REQUIRED_BINARY) then
        emit_event(context, "outdated", {})
        return {}
    end
    log_warn(context, "eiffelstudio outdated() returns empty list in v1; iron standard CLI output does not expose reliable comparable version data")
    local items = {}
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned_prompt = request_prompt(context, prompt)
    if cleaned_prompt == "" then
        emit_event(context, "searched", {})
        return {}
    end
    if not command_exists(context, REQUIRED_BINARY) then
        emit_event(context, "searched", {})
        return {}
    end

    local result = exec_run(context, "iron search " .. shell_quote(cleaned_prompt))
    if result == nil or result.success ~= true then
        log_warn(context, "iron search failed")
        emit_event(context, "searched", {})
        return {}
    end

    local items = parse_search_output(result.stdout)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local target = request_prompt(context, name)
    if target == "" then
        emit_event(context, "informed", {})
        return {}
    end
    if not command_exists(context, REQUIRED_BINARY) then
        emit_event(context, "informed", {})
        return {}
    end

    local result = exec_run(context, "iron info " .. shell_quote(target))
    if result == nil or result.success ~= true then
        log_warn(context, "iron info failed")
        emit_event(context, "informed", {})
        return {}
    end

    local item = parse_info_output(result.stdout)
    if item == nil or item.name == nil or item.name == "" then
        emit_event(context, "informed", {})
        return {}
    end
    if item.installed and item.installPath == nil then
        item.installPath = query_install_path(context, item.name)
        normalize_item(item)
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.shutdown()
    return true
end

return plugin
