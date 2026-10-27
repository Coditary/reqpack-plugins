plugin = {}

local PLUGIN_NAME = "Snap"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "snap"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function non_empty(value)
    local cleaned = trim(value)
    if cleaned == "" or cleaned == "-" then
        return nil
    end
    return cleaned
end

local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function get_field(value, key)
    if value == nil then
        return nil
    end

    local value_type = type(value)
    if value_type == "table" or value_type == "userdata" then
        local ok, field = pcall(function()
            return value[key]
        end)
        if ok then
            return field
        end
    end

    return nil
end

local function split_lines(value)
    local lines = {}
    for line in tostring(value or ""):gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

local function split_whitespace(line)
    local fields = {}
    for field in tostring(line or ""):gmatch("%S+") do
        table.insert(fields, field)
    end
    return fields
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

local function normalize_run_result(first, second, third, fourth, fifth)
    if type(first) == "table" then
        return first
    end

    local result = {}

    local function merge_exec_like(value)
        local probes = {
            "success",
            "ok",
            "stdout",
            "stderr",
            "exitCode",
            "exit_code",
            "code",
            "status",
        }

        for _, key in ipairs(probes) do
            local ok, item = pcall(function()
                return value[key]
            end)
            if ok and item ~= nil and result[key] == nil then
                result[key] = item
            end
        end
    end

    local function merge_table(value)
        for key, item in pairs(value or {}) do
            result[key] = item
        end
    end

    local function apply_scalar(value)
        local value_type = type(value)
        if value_type == "table" then
            merge_table(value)
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

local function is_command_success(result)
    if type(result) ~= "table" then
        return false
    end

    if result.success or result.ok then
        return true
    end

    local exit_code = result.exitCode or result.exit_code or result.code or result.status
    return exit_code == 0
end

local function run_command(context, command)
    local first, second, third, fourth, fifth

    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        first, second, third, fourth, fifth = context.exec.run(command)
        return normalize_run_result(first, second, third, fourth, fifth)
    end

    first, second, third, fourth, fifth = reqpack.exec.run(command)
    return normalize_run_result(first, second, third, fourth, fifth)
end

local function command_exists(binary, context)
    return is_command_success(run_command(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function package_name(package)
    local name = get_field(package, "name")
    if name ~= nil then
        return trim(name)
    end

    return trim(package)
end

local function build_command_args(packages)
    local args = {}

    for _, package in ipairs(packages or {}) do
        local name = package_name(package)
        if name ~= "" then
            table.insert(args, shell_quote(name))
        end
    end

    return table.concat(args, " ")
end

local function read_package_flags(package)
    local values = {}
    local flags = get_field(package, "flags")

    if type(flags) == "table" or type(flags) == "userdata" then
        local ok = pcall(function()
            for _, flag in ipairs(flags) do
                local text = trim(flag)
                if text ~= "" then
                    table.insert(values, text)
                end
            end
        end)
        if ok then
            return values
        end
    end

    return values
end

local function package_channel(package)
    local direct = trim(get_field(package, "channel"))
    if direct ~= "" then
        return direct
    end

    for _, flag in ipairs(read_package_flags(package)) do
        local text = trim(flag)
        local value = text:match("^channel=(.+)$")
        if value ~= nil and trim(value) ~= "" then
            return trim(value)
        end
    end

    return ""
end

local function package_flag(package, key)
    local value = get_field(package, key)
    if type(value) == "boolean" then
        return value
    end

    local normalized = lower(trim(value))
    if normalized == "true" or normalized == "1" or normalized == "yes" then
        return true
    end

    for _, flag in ipairs(read_package_flags(package)) do
        if lower(trim(flag)) == lower(key) then
            return true
        end
    end

    return false
end

local function build_snap_option_args(package, action)
    local args = {}
    local current_action = trim(action)
    local channel = package_channel(package)

    if channel ~= "" then
        table.insert(args, "--channel=" .. shell_quote(channel))
    end

    if current_action == "install" then
        if package_flag(package, "classic") then
            table.insert(args, "--classic")
        end
        if package_flag(package, "devmode") then
            table.insert(args, "--devmode")
        end
    end

    return table.concat(args, " ")
end

local function extract_columns(line, starts)
    local columns = {}
    for index, start_pos in ipairs(starts) do
        local next_pos = starts[index + 1]
        local value
        if next_pos ~= nil then
            value = line:sub(start_pos, next_pos - 1)
        else
            value = line:sub(start_pos)
        end
        table.insert(columns, trim(value))
    end
    return columns
end

local function header_positions(header, labels)
    local starts = {}
    for _, label in ipairs(labels) do
        local start_pos = header:find(label, 1, true)
        if start_pos == nil then
            return nil
        end
        table.insert(starts, start_pos)
    end
    return starts
end

local function make_snap_item(name, version, installed)
    return {
        name = name,
        version = version,
        latestVersion = version,
        installed = installed,
        status = installed and "installed" or "available",
        packageType = "snap",
        packageId = name,
    }
end

local function parse_list_output(stdout)
    local items = {}
    local header = nil
    local starts = nil

    for _, line in ipairs(split_lines(stdout)) do
        local trimmed = trim(line)
        if trimmed ~= "" then
            if header == nil and trimmed:match("^Name%s+Version%s+Rev%s+Tracking%s+Publisher%s+Notes$") then
                header = line
                starts = header_positions(header, { "Name", "Version", "Rev", "Tracking", "Publisher", "Notes" })
            elseif starts ~= nil and not trimmed:match("^Name%s+") then
                local fields = extract_columns(line, starts)
                local name = non_empty(fields[1])
                local version = non_empty(fields[2])
                if name ~= nil then
                    local item = make_snap_item(name, version, true)
                    item.repository = non_empty(fields[4])
                    item.extraFields = {
                        revision = non_empty(fields[3]),
                        tracking = non_empty(fields[4]),
                        publisher = non_empty(fields[5]),
                        notes = non_empty(fields[6]),
                    }
                    if next(item.extraFields) == nil then
                        item.extraFields = nil
                    end
                    table.insert(items, item)
                end
            end
        end
    end

    return items
end

local function parse_outdated_output(stdout)
    local items = {}
    local header = nil
    local starts = nil

    for _, line in ipairs(split_lines(stdout)) do
        local trimmed = trim(line)
        if trimmed == "All snaps up to date." then
            return {}
        end

        if trimmed ~= "" then
            if header == nil and trimmed:match("^Name%s+Version%s+Rev%s+Size%s+Publisher%s+Notes$") then
                header = line
                starts = header_positions(header, { "Name", "Version", "Rev", "Size", "Publisher", "Notes" })
            elseif starts ~= nil and not trimmed:match("^Name%s+") then
                local fields = extract_columns(line, starts)
                local name = non_empty(fields[1])
                local version = non_empty(fields[2])
                if name ~= nil then
                    local item = make_snap_item(name, nil, true)
                    item.latestVersion = version
                    item.status = "upgradable"
                    item.extraFields = {
                        revision = non_empty(fields[3]),
                        size = non_empty(fields[4]),
                        publisher = non_empty(fields[5]),
                        notes = non_empty(fields[6]),
                    }
                    if next(item.extraFields) == nil then
                        item.extraFields = nil
                    end
                    table.insert(items, item)
                end
            end
        end
    end

    return items
end

local function parse_search_output(stdout)
    local items = {}
    local header = nil
    local starts = nil

    for _, line in ipairs(split_lines(stdout)) do
        local trimmed = trim(line)
        if trimmed ~= "" then
            if header == nil and trimmed:match("^Name%s+Version%s+Publisher%s+Notes%s+Summary$") then
                header = line
                starts = header_positions(header, { "Name", "Version", "Publisher", "Notes", "Summary" })
            elseif starts ~= nil and not trimmed:match("^Name%s+") and not trimmed:match("^No matching snaps") then
                local fields = extract_columns(line, starts)
                local name = non_empty(fields[1])
                local version = non_empty(fields[2])
                if name ~= nil then
                    local item = make_snap_item(name, version, false)
                    item.summary = non_empty(fields[5])
                    item.extraFields = {
                        publisher = non_empty(fields[3]),
                        notes = non_empty(fields[4]),
                    }
                    if next(item.extraFields) == nil then
                        item.extraFields = nil
                    end
                    table.insert(items, item)
                end
            end
        end
    end

    return items
end

local function parse_info_output(stdout)
    local fields = {}
    local description_lines = {}
    local in_description = false
    local installed_version = nil
    local installed_revision = nil
    local first_channel_version = nil

    for _, line in ipairs(split_lines(stdout)) do
        if in_description then
            if line:match("^%S") then
                in_description = false
            else
                local cleaned = line:gsub("^%s*", "")
                table.insert(description_lines, cleaned)
            end
        end

        if not in_description then
            local key, value = line:match("^%s*([%w%-%./]+):%s*(.*)$")
            if key ~= nil then
                local normalized_key = lower(trim(key))
                fields[normalized_key] = trim(value)
                if normalized_key == "description" and trim(value) == "|" then
                    description_lines = {}
                    in_description = true
                elseif normalized_key == "installed" then
                    local version, revision = trim(value):match("^([^%s]+)%s+%(([^%)]+)%)")
                    if version ~= nil then
                        installed_version = trim(version)
                        installed_revision = trim(revision)
                    end
                elseif normalized_key:find("/", 1, true) ~= nil and first_channel_version == nil then
                    local channel_version = split_whitespace(value)[1]
                    if non_empty(channel_version) ~= nil and channel_version ~= "↑" then
                        first_channel_version = trim(channel_version)
                    end
                end
            end
        end
    end

    local name = non_empty(fields.name)
    if name == nil then
        return nil
    end

    local item = make_snap_item(name, installed_version or nil, installed_version ~= nil)
    item.summary = non_empty(fields.summary)
    item.description = #description_lines > 0 and table.concat(description_lines, "\n") or nil
    item.license = non_empty(fields.license)
    item.homepage = non_empty(fields.contact or fields["store-url"])
    item.repository = non_empty(fields.tracking)

    local latest_version = non_empty(fields.version)
    if latest_version == nil then
        local first_channel = non_empty(fields["latest/stable"])
        if first_channel ~= nil then
            latest_version = split_whitespace(first_channel)[1]
        end
    end
    if latest_version == nil then
        latest_version = first_channel_version
    end

    item.latestVersion = latest_version or item.version
    if item.version == nil then
        item.version = latest_version
        item.installed = false
        item.status = "available"
    end

    local extra = {
        publisher = non_empty(fields.publisher),
        tracking = non_empty(fields.tracking),
        revision = installed_revision,
        snapId = non_empty(fields["snap-id"]),
    }
    if next(extra) ~= nil then
        item.extraFields = extra
    end

    return item
end

local function query_list_items(context, name)
    local command = "snap list"
    if trim(name) ~= "" then
        command = command .. " " .. shell_quote(name)
    end

    local result = run_command(context, command)
    if not is_command_success(result) then
        return {}
    end

    return parse_list_output(result.stdout)
end

local function run_mutation(context, label, command, event_name, payload, failure_message)
    begin_step(context, label)

    local result = run_command(context, command)
    if not is_command_success(result) then
        tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or failure_message)
        return false
    end

    emit_event(context, event_name, payload)
    tx_success(context)
    return true
end

local function run_package_commands(context, step_label, packages, action, command_builder, success_event, failure_message)
    if packages == nil or #packages == 0 then
        return true
    end

    begin_step(context, step_label)
    for _, package in ipairs(packages) do
        local name = package_name(package)
        if name == "" then
            tx_failed(context, "snap package name missing")
            return false
        end

        local command = command_builder(package, action)
        local result = run_command(context, command)
        if not is_command_success(result) then
            tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or failure_message)
            return false
        end
    end

    emit_event(context, success_event, packages)
    tx_success(context)
    return true
end

local function empty_result(context, event_name)
    local items = {}
    emit_event(context, event_name, items)
    return items
end

local function find_item_by_name(items, name)
    local wanted = trim(name)
    for _, item in ipairs(items or {}) do
        if trim(item.name) == wanted then
            return item
        end
    end
    return nil
end

plugin.fileExtensions = { ".snap" }

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
    return { "System", "Snap", "Wrapper" }
end

function plugin.getMissingPackages(packages)
    local missing = {}
    local installed_items = query_list_items(nil)
    local installed_lookup = {}

    for _, item in ipairs(installed_items) do
        installed_lookup[item.name] = item
    end

    local outdated_lookup = nil

    for _, package in ipairs(packages or {}) do
        local name = package_name(package)
        local action = trim(get_field(package, "action"))

        if name ~= "" then
            if action == "remove" then
                if installed_lookup[name] ~= nil then
                    table.insert(missing, package)
                end
            elseif action == "update" then
                if outdated_lookup == nil then
                    outdated_lookup = {}
                    for _, item in ipairs(plugin.outdated({ exec = { run = function(command)
                        return run_command(nil, command)
                    end }, events = {} })) do
                        outdated_lookup[item.name] = true
                    end
                end
                if outdated_lookup[name] then
                    table.insert(missing, package)
                end
            elseif installed_lookup[name] == nil then
                table.insert(missing, package)
            end
        end
    end

    return missing
end

function plugin.install(context, packages)
    return run_package_commands(
        context,
        "install snap packages",
        packages,
        "install",
        function(package, action)
            local parts = {
                "snap install",
                shell_quote(package_name(package)),
            }
            local option_args = build_snap_option_args(package, action)
            if option_args ~= "" then
                table.insert(parts, option_args)
            end
            return table.concat(parts, " ")
        end,
        "installed",
        "snap install failed"
    )
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    begin_step(context, "install local snap artifact")

    if local_path == "" then
        tx_failed(context, "local package path missing")
        return false
    end

    if not lower(local_path):match("%.snap$") then
        tx_failed(context, "unsupported local snap artifact type")
        return false
    end

    local result = run_command(context, "snap install " .. shell_quote(local_path) .. " --dangerous")
    if not is_command_success(result) then
        tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "snap local install failed")
        return false
    end

    emit_event(context, "installed", { path = local_path, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local args = build_command_args(packages)
    if args == "" then
        return true
    end

    return run_mutation(
        context,
        "remove snap packages",
        "snap remove " .. args,
        "deleted",
        packages or {},
        "snap remove failed"
    )
end

function plugin.update(context, packages)
    return run_package_commands(
        context,
        "update snap packages",
        packages,
        "update",
        function(package, action)
            local parts = {
                "snap refresh",
                shell_quote(package_name(package)),
            }
            local option_args = build_snap_option_args(package, action)
            if option_args ~= "" then
                table.insert(parts, option_args)
            end
            return table.concat(parts, " ")
        end,
        "updated",
        "snap refresh failed"
    )
end

function plugin.list(context)
    local items = query_list_items(context)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local result = run_command(context, "snap refresh --list")
    if not is_command_success(result) then
        return empty_result(context, "outdated")
    end

    local items = parse_outdated_output(result.stdout)
    if #items > 0 then
        local installed_items = query_list_items(context)
        for _, item in ipairs(items) do
            local installed_item = find_item_by_name(installed_items, item.name)
            if installed_item ~= nil then
                item.version = installed_item.version
                item.repository = installed_item.repository
                item.extraFields = item.extraFields or {}
                if installed_item.extraFields ~= nil then
                    item.extraFields.tracking = installed_item.extraFields.tracking
                end
            else
                item.version = item.latestVersion
            end
        end
    end

    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt)
    if query == "" then
        return empty_result(context, "searched")
    end

    local result = run_command(context, "snap find " .. shell_quote(query))
    if not is_command_success(result) then
        return empty_result(context, "searched")
    end

    local items = parse_search_output(result.stdout)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = trim(name)
    if query == "" then
        emit_event(context, "informed", {})
        return {}
    end

    local result = run_command(context, "snap info " .. shell_quote(query))
    if not is_command_success(result) then
        emit_event(context, "informed", {})
        return {}
    end

    local item = parse_info_output(result.stdout)
    if item == nil then
        emit_event(context, "informed", {})
        return {}
    end

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == "" then
        return nil
    end

    local installed_item = find_item_by_name(query_list_items(context), name)
    if installed_item ~= nil then
        return installed_item
    end

    local search_items = plugin.search(context, name)
    local search_item = find_item_by_name(search_items, name)
    if search_item ~= nil then
        return search_item
    end

    local info_item = plugin.info(context, name)
    if type(info_item) == "table" and info_item.name ~= nil then
        return info_item
    end

    return nil
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "snap" },
        writeScopes = {
            { kind = "system-path", value = "/var/lib/snapd" },
        },
        privilegeLevel = "sudo",
        purlType = "generic",
    }
end

function plugin.init()
    return command_exists(REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

return plugin
