plugin = {}

local PLUGIN_NAME = "Pacman"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "pacman"

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
        table.insert(lines, line)
    end

    return lines
end

local function shell_quote(value)
    local text = tostring(value or "")

    if text:match("^[%w%+%-%._/%:@=,]+$") then
        return text
    end

    return "'" .. text:gsub("'", "'\\''") .. "'"
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

local function log_error(context, message)
    if context == nil or context.log == nil then
        return
    end

    local fn = context.log.error
    if type(fn) == "function" then
        fn(message)
    end
end

local function run_exec(context, command, options)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        if options ~= nil then
            return context.exec.run(command, options)
        end
        return context.exec.run(command)
    end

    if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
        return reqpack.exec.run(command)
    end

    return {
        success = false,
        stdout = "",
        stderr = "missing ReqPack exec runner",
        exitCode = 127,
    }
end

local function command_exists(binary)
    local result = run_exec(nil, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function build_pacman_command(operation, flags, values)
    local parts = { "LC_ALL=C", REQUIRED_BINARY, operation }

    for _, flag in ipairs(flags or {}) do
        table.insert(parts, flag)
    end

    for _, value in ipairs(values or {}) do
        local text = trim(value)
        if text ~= "" then
            table.insert(parts, shell_quote(text))
        end
    end

    return table.concat(parts, " ")
end

local function object_field(object, key)
    if object == nil then
        return nil
    end

    local ok, value = pcall(function()
        return object[key]
    end)
    if ok then
        return value
    end

    return nil
end

local function pacman_progress_rules(default_step)
    local step = trim(default_step)
    local fallback = step ~= "" and step or "run pacman"

    return {
        rules = {
            {
                source = "line",
                regex = "^:: Synchronizing package databases%.%.%.$",
                actions = {
                    { type = "progress", percent = "5" },
                    { type = "begin_step", label = "synchronize package databases" },
                },
            },
            {
                source = "line",
                regex = "^:: Starting (.+)%.%.%.$",
                actions = {
                    { type = "progress", percent = "10" },
                    { type = "begin_step", label = "${1}" },
                },
            },
            {
                source = "line",
                regex = "^:: Retrieving packages%.%.%.$",
                actions = {
                    { type = "progress", percent = "15" },
                    { type = "begin_step", label = "retrieve packages" },
                },
            },
            {
                source = "line",
                regex = "^%((%d+)/(%d+)%) checking keys in keyring$",
                actions = {
                    { type = "progress", percent = "20" },
                    { type = "begin_step", label = "checking keys in keyring" },
                },
            },
            {
                source = "line",
                regex = "^%((%d+)/(%d+)%) checking package integrity$",
                actions = {
                    { type = "progress", percent = "30" },
                    { type = "begin_step", label = "checking package integrity" },
                },
            },
            {
                source = "line",
                regex = "^%((%d+)/(%d+)%) loading package files$",
                actions = {
                    { type = "progress", percent = "40" },
                    { type = "begin_step", label = "loading package files" },
                },
            },
            {
                source = "line",
                regex = "^%((%d+)/(%d+)%) checking for file conflicts$",
                actions = {
                    { type = "progress", percent = "50" },
                    { type = "begin_step", label = "checking for file conflicts" },
                },
            },
            {
                source = "line",
                regex = "^%((%d+)/(%d+)%) checking available disk space$",
                actions = {
                    { type = "progress", percent = "60" },
                    { type = "begin_step", label = "checking available disk space" },
                },
            },
            {
                source = "line",
                regex = "^:: Processing package changes%.%.%.$",
                actions = {
                    { type = "progress", percent = "70" },
                    { type = "begin_step", label = "processing package changes" },
                },
            },
            {
                source = "line",
                regex = "^%((%d+)/(%d+)%) (installing|upgrading|downgrading|reinstalling|removing) (.+)$",
                actions = {
                    { type = "progress", percent = "80" },
                    { type = "begin_step", label = "${3} ${4}" },
                },
            },
            {
                source = "line",
                regex = "^:: Running post%-transaction hooks%.%.%.$",
                actions = {
                    { type = "progress", percent = "90" },
                    { type = "begin_step", label = "running post-transaction hooks" },
                },
            },
            {
                source = "line",
                regex = "^%((%d+)/(%d+)%) (.+)$",
                actions = {
                    { type = "progress", percent = "95" },
                    { type = "begin_step", label = "${3}" },
                },
            },
            {
                source = "line",
                regex = "^warning:%s+(.+)$",
                actions = {
                    { type = "log", level = "warn", message = "${1}" },
                },
            },
            {
                source = "line",
                regex = "^error:%s+(.+)$",
                actions = {
                    { type = "log", level = "error", message = "${1}" },
                },
            },
            {
                source = "screen",
                regex = "(\\d+)%%",
                actions = {
                    { type = "progress", percent = "${1}" },
                },
            },
        },
        initial = fallback,
    }
end

local function package_name(pkg)
    return trim(object_field(pkg, "name") or object_field(pkg, "packageName") or object_field(pkg, "packageId"))
end

local function collect_package_names(packages)
    local names = {}

    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        if name ~= "" then
            table.insert(names, name)
        end
    end

    return names
end

local function is_not_found_result(result)
    local text = lower((result and result.stderr) or "") .. "\n" .. lower((result and result.stdout) or "")
    return text:find("was not found", 1, true) ~= nil
        or text:find("no packages matched", 1, true) ~= nil
        or text:find("target not found", 1, true) ~= nil
        or text:find("package not found", 1, true) ~= nil
end

local function is_none_value(value)
    local text = lower(trim(value))
    return text == "" or text == "none"
end

local function split_field_items(value, tokenize)
    local items = {}
    local text = trim(value)

    if is_none_value(text) then
        return items
    end

    if text:find("\n", 1, true) ~= nil then
        for _, line in ipairs(split_lines(text)) do
            local item = trim(line)
            if item ~= "" and lower(item) ~= "none" then
                if tokenize then
                    for token in item:gmatch("%S+") do
                        table.insert(items, token)
                    end
                else
                    table.insert(items, item)
                end
            end
        end
        return items
    end

    if not tokenize then
        table.insert(items, text)
        return items
    end

    for item in text:gmatch("%S+") do
        table.insert(items, item)
    end

    return items
end

local function parse_key_value_output(stdout)
    local fields = {}
    local current_key = nil

    for _, line in ipairs(split_lines(stdout)) do
        local key, value = line:match("^([%w][%w%s%-]+)%s*:%s*(.*)$")

        if key ~= nil then
            current_key = lower(trim(key))
            fields[current_key] = trim(value)
        elseif current_key ~= nil and line:match("^%s+%S") ~= nil then
            local continuation = trim(line)
            if continuation ~= "" then
                if fields[current_key] == nil or fields[current_key] == "" then
                    fields[current_key] = continuation
                else
                    fields[current_key] = fields[current_key] .. "\n" .. continuation
                end
            end
        end
    end

    return fields
end

local function parse_list_output(stdout)
    local items = {}

    for _, line in ipairs(split_lines(stdout)) do
        local name, version = line:match("^(%S+)%s+(%S+)$")
        if name ~= nil and version ~= nil then
            table.insert(items, {
                name = name,
                packageId = name,
                version = version,
                installed = true,
                status = "installed",
                type = "package",
                packageType = "package",
            })
        end
    end

    return items
end

local function parse_search_output(stdout)
    local items = {}
    local current = nil

    local function flush_current()
        if current ~= nil and current.name ~= nil and current.name ~= "" then
            table.insert(items, current)
        end
        current = nil
    end

    for _, line in ipairs(split_lines(stdout)) do
        local repo, name, version = line:match("^(%S+)/(%S+)%s+(%S+)")

        if repo ~= nil and name ~= nil and version ~= nil then
            flush_current()
            current = {
                name = name,
                packageId = name,
                version = version,
                repository = repo,
                installed = line:find("[installed", 1, true) ~= nil,
                status = line:find("[installed", 1, true) ~= nil and "installed" or "available",
                type = "package",
                packageType = "package",
            }
        elseif current ~= nil then
            local summary = trim(line)
            if summary ~= "" then
                if current.summary == nil then
                    current.summary = summary
                else
                    current.summary = current.summary .. " " .. summary
                end
                current.description = current.summary
            end
        end
    end

    flush_current()
    return items
end

local function parse_outdated_output(stdout)
    local items = {}

    for _, line in ipairs(split_lines(stdout)) do
        local name, version, latest = line:match("^(%S+)%s+(%S+)%s+%-%>%s+(%S+)$")
        if name ~= nil and version ~= nil and latest ~= nil then
            table.insert(items, {
                name = name,
                packageId = name,
                version = version,
                latestVersion = latest,
                installed = true,
                status = "outdated",
                type = "package",
                packageType = "package",
            })
        end
    end

    return items
end

local function info_from_fields(fields)
    local name = trim(fields.name)
    if name == "" then
        return {}
    end

    local licenses = trim(fields.licenses or fields.license)
    local item = {
        name = name,
        packageId = name,
        version = trim(fields.version),
        summary = trim(fields.description),
        description = trim(fields.description),
        architecture = trim(fields.architecture),
        license = licenses,
        repository = trim(fields.repository),
        homepage = trim(fields.url),
        dependencies = split_field_items(fields["depends on"], true),
        optionalDependencies = split_field_items(fields["optional deps"], false),
        provides = split_field_items(fields.provides, true),
        conflicts = split_field_items(fields["conflicts with"], true),
        type = "package",
        packageType = "package",
    }

    if trim(fields["install date"]) ~= "" then
        item.installed = true
        item.status = "installed"
    end

    return item
end

local function lookup_package_info(context, name)
    local repo_result = run_exec(context, build_pacman_command("-Si", nil, { name }))
    if repo_result.success then
        return info_from_fields(parse_key_value_output(repo_result.stdout))
    end

    local local_result = run_exec(context, build_pacman_command("-Qi", nil, { name }))
    if local_result.success then
        return info_from_fields(parse_key_value_output(local_result.stdout))
    end

    if not is_not_found_result(repo_result) and not is_not_found_result(local_result) then
        log_error(context, "pacman info failed for " .. name)
    end

    return {}
end

local function package_version(pkg)
    return trim(object_field(pkg, "version"))
end

local function info_matches_request(pkg, item)
    if item == nil or trim(item.name) == "" then
        return false
    end

    local name = package_name(pkg)
    local version = package_version(pkg)
    if name ~= "" and trim(item.name) ~= name then
        return false
    end

    if version ~= "" and trim(item.version) ~= version then
        return false
    end

    return true
end

local function is_installed(name)
    local result = run_exec(nil, build_pacman_command("-Q", nil, { name }))
    return result ~= nil and result.success == true
end

local function load_outdated_lookup()
    local lookup = {}
    local result = run_exec(nil, build_pacman_command("-Qu"))

    if result == nil or result.success ~= true then
        return lookup
    end

    for _, item in ipairs(parse_outdated_output(result.stdout)) do
        lookup[item.name] = true
    end

    return lookup
end

plugin.fileExtensions = {
    ".pkg.tar",
    ".pkg.tar.zst",
    ".pkg.tar.xz",
    ".pkg.tar.gz",
    ".pkg.tar.bz2",
    ".pkg.tar.lz",
    ".pkg.tar.lz4",
    ".pkg.tar.lrz",
    ".pkg.tar.lzo",
    ".pkg.tar.Z",
}

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
    return { "System", "Linux", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    local missing = {}
    local outdated_lookup = nil

    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        local action = trim(object_field(pkg, "action"))

        if name ~= "" then
            if action == "remove" then
                if is_installed(name) then
                    table.insert(missing, pkg)
                end
            elseif action == "update" then
                if outdated_lookup == nil then
                    outdated_lookup = load_outdated_lookup()
                end

                if outdated_lookup[name] == true then
                    table.insert(missing, pkg)
                end
            elseif not is_installed(name) then
                table.insert(missing, pkg)
            end
        end
    end

    return missing
end

function plugin.install(context, packages)
    local names = collect_package_names(packages)
    if #names == 0 then
        return true
    end

    begin_step(context, "install pacman packages")
    local result = run_exec(
        context,
        build_pacman_command("-S", { "--needed", "--noconfirm" }, names),
        pacman_progress_rules("install pacman packages")
    )

    if not result.success then
        tx_failed(context, "pacman install failed")
        return false
    end

    emit_event(context, "installed", packages or {})
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" then
        tx_failed(context, "pacman local install failed")
        return false
    end

    begin_step(context, "install local pacman package")
    local result = run_exec(
        context,
        build_pacman_command("-U", { "--noconfirm" }, { local_path }),
        pacman_progress_rules("install local pacman package")
    )

    if not result.success then
        tx_failed(context, "pacman local install failed")
        return false
    end

    emit_event(context, "installed", { path = local_path, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local names = collect_package_names(packages)
    if #names == 0 then
        return true
    end

    begin_step(context, "remove pacman packages")
    local result = run_exec(
        context,
        build_pacman_command("-R", { "--noconfirm" }, names),
        pacman_progress_rules("remove pacman packages")
    )

    if not result.success then
        tx_failed(context, "pacman remove failed")
        return false
    end

    emit_event(context, "deleted", packages or {})
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local names = collect_package_names(packages)
    if #names == 0 then
        return true
    end

    begin_step(context, "update pacman packages")
    local result = run_exec(
        context,
        build_pacman_command("-S", { "--noconfirm" }, names),
        pacman_progress_rules("update pacman packages")
    )

    if not result.success then
        tx_failed(context, "pacman update failed")
        return false
    end

    emit_event(context, "updated", packages or {})
    tx_success(context)
    return true
end

function plugin.list(context)
    local result = run_exec(context, build_pacman_command("-Q"))
    local items = {}

    if result.success then
        items = parse_list_output(result.stdout)
    else
        log_error(context, "pacman list failed")
    end

    emit_event(context, "listed", items)
    return items
end

function plugin.search(context, prompt)
    local search_prompt = trim(prompt)
    if search_prompt == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local result = run_exec(context, build_pacman_command("-Ss", nil, { search_prompt }))
    local items = {}

    if result.success then
        items = parse_search_output(result.stdout)
    elseif not is_not_found_result(result) then
        log_error(context, "pacman search failed for " .. search_prompt)
    end

    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local package_name_value = trim(name)
    local item = {}

    if package_name_value ~= "" then
        item = lookup_package_info(context, package_name_value)
    end

    emit_event(context, "informed", item)
    return item
end

function plugin.outdated(context)
    local result = run_exec(context, build_pacman_command("-Qu"))
    local items = {}

    if result.success then
        items = parse_outdated_output(result.stdout)
    elseif not is_not_found_result(result) then
        log_error(context, "pacman outdated check failed")
    end

    emit_event(context, "outdated", items)
    return items
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == "" then
        return nil
    end

    local item = lookup_package_info(context, name)
    if info_matches_request(package, item) then
        return item
    end

    if trim(item.name) ~= "" then
        return {
            name = item.name,
            packageId = item.packageId,
            version = trim(item.version) ~= "" and item.version or package_version(package),
            repository = item.repository,
            architecture = item.architecture,
            homepage = item.homepage,
            license = item.license,
            packageType = item.packageType,
            type = item.type,
        }
    end

    return nil
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "alpm", "arch" },
        privilegeLevel = "sudo",
        osvEcosystem = "Linux",
        purlType = "alpm",
        versionTokenPattern = "[A-Za-z0-9._:+-]+",
        versionCaseInsensitive = false,
    }
end

function plugin.init()
    return command_exists(REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

return plugin
