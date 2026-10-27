plugin = {}

local PLUGIN_NAME = "dpkg"
local PLUGIN_VERSION = "1.0.0"
local REQUIRED_BINARIES = { "dpkg", "dpkg-query", "apt-cache", "apt-get", "apt" }

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function has_text(value)
    return trim(value) ~= ""
end

local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function split_lines(value)
    local lines = {}
    for line in (tostring(value or "") .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

local function split_csv(value)
    local items = {}
    for item in tostring(value or ""):gmatch("[^,]+") do
        item = trim(item)
        if item ~= "" then
            table.insert(items, item)
        end
    end
    return items
end

local function first_description_line(value)
    for _, line in ipairs(split_lines(value)) do
        local cleaned = trim(line)
        if cleaned ~= "" and cleaned ~= "." then
            return cleaned
        end
    end
    return nil
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

local function run_command(context, command)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return context.exec.run(command)
    end
    return reqpack.exec.run(command)
end

local function binaries_exist(binaries)
    local checks = {}
    for _, binary in ipairs(binaries) do
        table.insert(checks, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    end
    return reqpack.exec.run(table.concat(checks, " && ")).success
end

local function package_target(pkg)
    local name = trim(pkg and pkg.name)
    local version = trim(pkg and pkg.version)
    if name == "" then
        return nil
    end
    if version ~= "" then
        return name .. "=" .. version
    end
    return name
end

local function package_name(pkg)
    local name = trim(pkg and pkg.name)
    if name == "" then
        return nil
    end
    return name
end

local function collect_targets(packages, mapper)
    local items = {}
    for _, pkg in ipairs(packages or {}) do
        local value = mapper(pkg)
        if value ~= nil then
            table.insert(items, value)
        end
    end
    return items
end

local function join_quoted(items)
    local quoted = {}
    for _, item in ipairs(items or {}) do
        table.insert(quoted, shell_quote(item))
    end
    return table.concat(quoted, " ")
end

local function parse_installed_stdout(name, stdout)
    local status, version, architecture = tostring(stdout or ""):match("^(.-)\t(.-)\t(.-)\n?$")
    if trim(status) ~= "install ok installed" then
        return nil
    end

    return {
        name = name,
        version = trim(version),
        architecture = trim(architecture),
        installed = true,
        status = "installed",
    }
end

local function query_installed_package(name, context)
    name = trim(name)
    if name == "" then
        return nil
    end

    local result = run_command(
        context,
        "dpkg-query -W -f='${Status}\\t${Version}\\t${Architecture}\\n' " .. shell_quote(name)
    )
    if not result.success then
        return nil
    end

    return parse_installed_stdout(name, result.stdout)
end

local function parse_policy(stdout)
    local info = {}

    for _, line in ipairs(split_lines(stdout)) do
        local key, value = line:match("^%s*([A-Za-z][A-Za-z%-]+):%s*(.-)%s*$")
        if key ~= nil then
            info[key] = value
        end
    end

    if info.Installed == "(none)" then
        info.Installed = nil
    end
    if info.Candidate == "(none)" then
        info.Candidate = nil
    end

    return info
end

local function parse_first_deb822_stanza(stdout)
    local item = {}
    local current_key = nil

    for _, line in ipairs(split_lines(stdout)) do
        if line == "" then
            if next(item) ~= nil then
                break
            end
            current_key = nil
        elseif line:match("^ ") and current_key ~= nil then
            item[current_key] = (item[current_key] or "") .. "\n" .. line:sub(2)
        else
            local key, value = line:match("^([A-Za-z0-9][A-Za-z0-9%-]*):%s*(.*)$")
            if key ~= nil then
                item[key] = value
                current_key = key
            end
        end
    end

    return item
end

local function query_policy(context, name)
    local result = run_command(context, "apt-cache policy " .. shell_quote(name))
    if not result.success then
        return {}
    end
    return parse_policy(result.stdout)
end

local function query_show(context, name)
    local result = run_command(context, "apt-cache show " .. shell_quote(name))
    if not result.success then
        return {}
    end
    return parse_first_deb822_stanza(result.stdout)
end

local function build_package_info(name, installed_record, policy_info, show_info)
    local show_name = trim(show_info.Package)
    local version = installed_record and installed_record.version or trim(show_info.Version)
    local latest_version = trim(policy_info.Candidate)
    local description = trim(show_info.Description)
    local architecture = installed_record and installed_record.architecture or trim(show_info.Architecture)

    if version == "" and latest_version ~= "" then
        version = latest_version
    end
    if latest_version == "" then
        latest_version = nil
    end
    if description == "" then
        description = nil
    end
    if architecture == "" then
        architecture = nil
    end

    return {
        name = show_name ~= "" and show_name or name,
        packageId = show_name ~= "" and show_name or name,
        version = version ~= "" and version or nil,
        latestVersion = latest_version,
        status = installed_record ~= nil and "installed" or "available",
        installed = installed_record ~= nil,
        summary = first_description_line(description),
        description = description,
        homepage = has_text(show_info.Homepage) and trim(show_info.Homepage) or nil,
        section = has_text(show_info.Section) and trim(show_info.Section) or nil,
        architecture = architecture,
        dependencies = split_csv(show_info.Depends),
        optionalDependencies = split_csv(show_info.Recommends),
        provides = split_csv(show_info.Provides),
        conflicts = split_csv(show_info.Conflicts),
        replaces = split_csv(show_info.Replaces),
        packageType = "deb",
        type = "package",
    }
end

local function parse_list(stdout)
    local items = {}

    for _, line in ipairs(split_lines(stdout)) do
        local name, version, architecture, status = line:match("^(.-)\t(.-)\t(.-)\t(.-)$")
        if name ~= nil and trim(name) ~= "" and trim(status) == "install ok installed" then
            table.insert(items, {
                name = trim(name),
                packageId = trim(name),
                version = trim(version),
                architecture = trim(architecture),
                status = "installed",
                installed = true,
                packageType = "deb",
                type = "package",
            })
        end
    end

    return items
end

local function parse_search(stdout)
    local items = {}

    for _, line in ipairs(split_lines(stdout)) do
        local name, summary = line:match("^(.-)%s+%-%s+(.*)$")
        if name == nil then
            name = trim(line)
            summary = nil
        end

        if trim(name) ~= "" then
            table.insert(items, {
                name = trim(name),
                packageId = trim(name),
                summary = has_text(summary) and trim(summary) or nil,
                packageType = "deb",
                type = "package",
            })
        end
    end

    return items
end

local function parse_outdated(stdout)
    local items = {}

    for _, line in ipairs(split_lines(stdout)) do
        if not line:match("^Listing") and trim(line) ~= "" then
            local name, channel, latest_version, architecture, current_version =
                line:match("^([^/]+)/([^%s]+)%s+(%S+)%s+(%S+)%s+%[upgradable from:%s*(.-)%]$")

            if name ~= nil then
                table.insert(items, {
                    name = trim(name),
                    packageId = trim(name),
                    version = trim(current_version),
                    latestVersion = trim(latest_version),
                    architecture = trim(architecture),
                    channel = trim(channel),
                    status = "upgradable",
                    installed = true,
                    packageType = "deb",
                    type = "package",
                })
            end
        end
    end

    return items
end

local function run_mutating_action(context, step_label, command, event_name, payload, failure_message)
    begin_step(context, step_label)

    local result = run_command(context, command)
    if not result.success then
        tx_failed(context, failure_message)
        return false
    end

    emit_event(context, event_name, payload)
    tx_success(context)
    return true
end

plugin.fileExtensions = { ".deb" }

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
    return { "Debian", "Wrapper" }
end

function plugin.getMissingPackages(packages)
    local missing = {}
    local upgradable = nil

    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        local action = trim(pkg and pkg.action)
        local installed_record = query_installed_package(name)

        if action == "" then
            action = "install"
        end

        if action == "remove" then
            if installed_record ~= nil then
                table.insert(missing, pkg)
            end
        elseif action == "update" then
            if upgradable == nil then
                upgradable = {}
                local result = reqpack.exec.run("apt list --upgradable 2>/dev/null")
                if result.success then
                    for _, item in ipairs(parse_outdated(result.stdout)) do
                        upgradable[item.name] = item
                    end
                end
            end

            if name ~= nil and upgradable[name] ~= nil then
                table.insert(missing, pkg)
            end
        else
            if installed_record == nil then
                table.insert(missing, pkg)
            elseif has_text(pkg and pkg.version) and installed_record.version ~= trim(pkg.version) then
                table.insert(missing, pkg)
            end
        end
    end

    return missing
end

function plugin.install(context, packages)
    local targets = collect_targets(packages, package_target)
    if #targets == 0 then
        return true
    end

    return run_mutating_action(
        context,
        "install dpkg packages",
        "apt-get install -y -- " .. join_quoted(targets),
        "installed",
        packages or {},
        "dpkg install failed"
    )
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" then
        tx_failed(context, "missing local package path")
        return false
    end

    return run_mutating_action(
        context,
        "install local deb package",
        "dpkg -i -- " .. shell_quote(local_path),
        "installed",
        { path = local_path, localTarget = true },
        "local dpkg install failed"
    )
end

function plugin.remove(context, packages)
    local targets = collect_targets(packages, package_name)
    if #targets == 0 then
        return true
    end

    return run_mutating_action(
        context,
        "remove dpkg packages",
        "dpkg -r -- " .. join_quoted(targets),
        "deleted",
        packages or {},
        "dpkg remove failed"
    )
end

function plugin.update(context, packages)
    local targets = collect_targets(packages, package_target)
    if #targets == 0 then
        return true
    end

    return run_mutating_action(
        context,
        "update dpkg packages",
        "apt-get install --only-upgrade -y -- " .. join_quoted(targets),
        "updated",
        packages or {},
        "dpkg update failed"
    )
end

function plugin.list(context)
    local result = run_command(context, "dpkg-query -W -f='${Package}\\t${Version}\\t${Architecture}\\t${Status}\\n'")
    if not result.success then
        emit_event(context, "unavailable", { action = "list" })
        return {}
    end

    local items = parse_list(result.stdout)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local result = run_command(context, "apt list --upgradable 2>/dev/null")
    if not result.success then
        emit_event(context, "unavailable", { action = "outdated" })
        return {}
    end

    local items = parse_outdated(result.stdout)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt)
    if query == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local result = run_command(context, "apt-cache search " .. shell_quote(query))
    if not result.success then
        emit_event(context, "unavailable", { action = "search", prompt = query })
        return {}
    end

    local items = parse_search(result.stdout)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local package_name_value = trim(name)
    if package_name_value == "" then
        emit_event(context, "unavailable", { action = "info" })
        return {}
    end

    local installed_record = query_installed_package(package_name_value, context)
    local policy_info = query_policy(context, package_name_value)
    local show_info = query_show(context, package_name_value)

    if installed_record == nil and next(policy_info) == nil and next(show_info) == nil then
        emit_event(context, "unavailable", { action = "info", name = package_name_value })
        return {}
    end

    local item = build_package_info(package_name_value, installed_record, policy_info, show_info)
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local name = trim(package and package.name)
    local requested_version = trim(package and package.version)

    if name == "" then
        return nil
    end

    local installed_record = query_installed_package(name, context)
    local policy_info = query_policy(context, name)
    local version = requested_version

    if version == "" and installed_record ~= nil then
        version = installed_record.version
    end
    if version == "" then
        version = trim(policy_info.Candidate)
    end
    if version == "" then
        return nil
    end

    return {
        name = name,
        packageId = name,
        version = version,
        architecture = installed_record and installed_record.architecture or nil,
        packageType = "deb",
        type = "package",
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "deb" },
        privilegeLevel = "sudo",
        osvEcosystem = "Debian",
        purlType = "deb",
        versionTokenPattern = "[A-Za-z0-9.+:~%-]+",
        versionCaseInsensitive = false,
    }
end

function plugin.init()
    return binaries_exist(REQUIRED_BINARIES)
end

function plugin.shutdown()
    return true
end

return plugin
