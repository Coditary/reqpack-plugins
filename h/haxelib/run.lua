plugin = {}

local PLUGIN_ID = "haxelib"
local PLUGIN_NAME = "Haxelib"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "haxelib"
local REMOTE_REPOSITORY = "lib.haxe.org"

plugin.fileExtensions = { ".zip" }

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

local function append_unique(list, value, seen)
    local cleaned = trim(value)
    if cleaned == "" then
        return
    end
    if seen[cleaned] then
        return
    end
    seen[cleaned] = true
    list[#list + 1] = cleaned
end

local function merge_extra_fields(left, right)
    local merged = shallow_copy(type(left) == "table" and left or {})
    for key, value in pairs(type(right) == "table" and right or {}) do
        merged[key] = value
    end
    return merged
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
    else
        first, second, third, fourth, fifth = reqpack.exec.run(command)
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

local function read_flags(value)
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

local function collect_flags(context, package)
    local flags = {}
    local seen = {}

    local function collect_from(object)
        for _, flag in ipairs(read_flags(read_field(object, "flags"))) do
            append_unique(flags, flag, seen)
        end
    end

    collect_from(context)
    collect_from(context ~= nil and context.request or nil)
    collect_from(package)
    return flags
end

local function has_flag(flags, name)
    local wanted = lower(trim(name))
    for _, flag in ipairs(flags or {}) do
        if lower(trim(flag)) == wanted then
            return true
        end
    end
    return false
end

local function flag_value(flags, name)
    local prefix = lower(trim(name)) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            return trim(cleaned:sub(#prefix + 1))
        end
    end
    return nil
end

local function command_options(context, package, extra)
    local flags = collect_flags(context, package)
    local debug_enabled = has_flag(flags, "debug")
    local quiet_enabled = not debug_enabled
    if has_flag(flags, "quiet") then
        quiet_enabled = true
    end
    local options = {
        quiet = quiet_enabled,
        debug = debug_enabled,
        global = not has_flag(flags, "local"),
        always = has_flag(flags, "always"),
        never = has_flag(flags, "never"),
        skipDependencies = has_flag(flags, "skip-dependencies"),
        noTimeout = has_flag(flags, "notimeout") or has_flag(flags, "no-timeout"),
        remote = flag_value(flags, "remote"),
        cwd = flag_value(flags, "cwd"),
    }
    for key, value in pairs(extra or {}) do
        options[key] = value
    end
    return options
end

local function build_haxelib_command(subcommand, args, options)
    local parts = { REQUIRED_BINARY }
    options = options or {}

    if options.quiet then
        parts[#parts + 1] = "--quiet"
    end
    if options.debug then
        parts[#parts + 1] = "--debug"
    end
    if options.global then
        parts[#parts + 1] = "--global"
    end
    if options.always then
        parts[#parts + 1] = "--always"
    end
    if options.never then
        parts[#parts + 1] = "--never"
    end
    if options.skipDependencies then
        parts[#parts + 1] = "--skip-dependencies"
    end
    if options.noTimeout then
        parts[#parts + 1] = "-notimeout"
    end
    if options.cwd ~= nil and trim(options.cwd) ~= "" then
        parts[#parts + 1] = "-cwd"
        parts[#parts + 1] = shell_quote(options.cwd)
    end
    if options.remote ~= nil and trim(options.remote) ~= "" then
        parts[#parts + 1] = "-R"
        parts[#parts + 1] = shell_quote(options.remote)
    end

    parts[#parts + 1] = subcommand
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = shell_quote(arg)
    end
    return table.concat(parts, " ")
end

local function command_exists(context, binary)
    return exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1").success == true
end

local function package_name(package)
    if type(package) ~= "table" then
        return trim(
            read_field(package, "name")
            or read_field(package, "packageId")
            or read_field(package, "id")
            or package
        )
    end
    return trim(
        read_field(package, "name")
        or read_field(package, "packageId")
        or read_field(package, "id")
        or ""
    )
end

local function package_version(package)
    return trim(read_field(package, "version") or read_field(package, "targetVersion") or "")
end

local function package_action(package)
    return lower(trim(read_field(package, "action") or "install"))
end

local function request_local_path(context, explicit_path)
    local request = read_field(context, "request")
    return trim(
        explicit_path
        or read_field(context, "localPath")
        or read_field(request, "localPath")
        or read_field(context, "path")
        or read_field(request, "path")
        or ""
    )
end

local function stable_release_version(version)
    local cleaned = trim(version)
    if cleaned == "" then
        return false
    end
    if cleaned == "git" or cleaned == "dev" or cleaned:match("^dev:") then
        return false
    end
    return true
end

local function parse_list_output(raw)
    local items = {}
    local map = {}

    for _, line in ipairs(split_lines(raw)) do
        local cleaned = trim(line)
        local name, versions_part = cleaned:match("^([^:]+):%s*(.+)$")
        if name ~= nil and versions_part ~= nil then
            local versions = {}
            local seen = {}
            local current = versions_part:match("%[([^%]]+)%]")
            for token in versions_part:gmatch("%S+") do
                local version = token:gsub("^%[", ""):gsub("%]$", "")
                append_unique(versions, version, seen)
            end
            local entry = {
                name = trim(name),
                currentVersion = trim(current),
                installedVersions = versions,
            }
            if entry.currentVersion == "" and #versions > 0 then
                entry.currentVersion = versions[1]
            end
            items[#items + 1] = entry
            map[entry.name] = entry
        end
    end

    return items, map
end

local function parse_tags(value)
    local tags = {}
    local seen = {}
    local text = trim(value)
    if text == "" then
        return tags
    end
    if text:find(",", 1, true) ~= nil then
        for item in text:gmatch("([^,]+)") do
            append_unique(tags, item, seen)
        end
    else
        for item in text:gmatch("%S+") do
            append_unique(tags, item, seen)
        end
    end
    return tags
end

local function parse_release_line(line)
    local cleaned = trim(line):gsub("^[%-%*]+%s*", "")
    if cleaned == "" then
        return nil
    end
    local version = cleaned:match("^([^%s%(]+)")
    if version == nil or version == "" then
        return nil
    end
    local released = cleaned:match("%(([^%)]+)%)")
    return {
        version = trim(version),
        released = trim(released),
        raw = cleaned,
    }
end

local function parse_info_output(name, raw)
    local data = {
        name = trim(name),
        dependencies = {},
        tags = {},
        releases = {},
        links = {},
        extraFields = {},
    }
    local dependency_seen = {}
    local mode = nil

    for _, line in ipairs(split_lines(raw)) do
        local cleaned = trim(line)
        if cleaned == "" then
            mode = nil
        else
            local key, value = cleaned:match("^([%a][%w%s/_%-]+):%s*(.*)$")
            if key ~= nil then
                local normalized = lower(trim(key))
                local text = trim(value)
                if normalized == "desc" or normalized == "description" or normalized == "summary" then
                    data.summary = text
                    data.description = text
                    mode = nil
                elseif normalized == "website" or normalized == "homepage" or normalized == "url" or normalized == "project website" then
                    data.homepage = text
                    mode = nil
                elseif normalized == "license" or normalized == "licenses" then
                    data.license = text
                    mode = nil
                elseif normalized == "owner" or normalized == "owners" or normalized == "author" or normalized == "maintainer" then
                    data.owner = text
                    mode = nil
                elseif normalized == "version" or normalized == "current version" or normalized == "latest version" then
                    data.latestVersion = text
                    mode = nil
                elseif normalized == "installed version" or normalized == "locked version" or normalized == "selected version" then
                    data.installedVersion = text
                    mode = nil
                elseif normalized == "tags" then
                    data.tags = parse_tags(text)
                    mode = nil
                elseif normalized == "dependencies" then
                    mode = "dependencies"
                    if text ~= "" then
                        for dep in text:gmatch("[^,]+") do
                            append_unique(data.dependencies, trim(dep), dependency_seen)
                        end
                    end
                elseif normalized == "recent releases" or normalized == "releases" or normalized == "versions" then
                    mode = "releases"
                    if text ~= "" then
                        local release = parse_release_line(text)
                        if release ~= nil then
                            data.releases[#data.releases + 1] = release
                        end
                    end
                elseif normalized == "links" then
                    mode = "links"
                else
                    data.extraFields[key] = text
                    mode = nil
                end
            elseif mode == "dependencies" then
                append_unique(data.dependencies, cleaned, dependency_seen)
            elseif mode == "releases" then
                local release = parse_release_line(cleaned)
                if release ~= nil then
                    data.releases[#data.releases + 1] = release
                end
            elseif mode == "links" then
                local link_name, link_value = cleaned:match("^([^:]+):%s*(.+)$")
                if link_name ~= nil and link_value ~= nil then
                    local link_key = trim(link_name)
                    data.links[link_key] = trim(link_value)
                    if data.homepage == nil or data.homepage == "" then
                        data.homepage = trim(link_value)
                    end
                end
            elseif data.summary == nil then
                data.summary = cleaned
                data.description = cleaned
            end
        end
    end

    if (data.latestVersion == nil or data.latestVersion == "") and #data.releases > 0 then
        data.latestVersion = data.releases[1].version
    end

    if next(data.links) ~= nil then
        data.extraFields.links = data.links
    end
    if #data.tags > 0 then
        data.extraFields.tags = data.tags
    end
    if #data.releases > 0 then
        data.extraFields.releases = data.releases
    end
    if data.owner ~= nil and data.owner ~= "" then
        data.extraFields.owner = data.owner
    end

    return data
end

local function search_names_from_output(raw)
    local names = {}
    local seen = {}
    for _, line in ipairs(split_lines(raw)) do
        local cleaned = trim(line)
        if cleaned:match("^[%w%._%-]+$") ~= nil then
            append_unique(names, cleaned, seen)
        end
    end
    return names
end

local function get_repo_path(context, options)
    local result = exec_run(context, build_haxelib_command("config", {}, options))
    if not result.success then
        return nil
    end
    for _, line in ipairs(split_lines(result.stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            return cleaned
        end
    end
    return nil
end

local function get_installed_state(context, options)
    local result = exec_run(context, build_haxelib_command("list", {}, options))
    if not result.success then
        return nil, nil, result.stderr
    end
    local items, map = parse_list_output(result.stdout)
    return items, map, nil
end

local function get_lib_path(context, name, options)
    local result = exec_run(context, build_haxelib_command("libpath", { name }, options))
    if not result.success then
        return nil
    end
    for _, line in ipairs(split_lines(result.stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            return cleaned
        end
    end
    return nil
end

local function fetch_info(context, name, options)
    local result = exec_run(context, build_haxelib_command("info", { name }, options))
    if not result.success then
        return nil
    end
    return parse_info_output(name, result.stdout)
end

local function ensure_lib_path(context, installed_entry, options)
    if installed_entry == nil then
        return nil
    end
    if installed_entry.libPath == nil or installed_entry.libPath == "" then
        installed_entry.libPath = get_lib_path(context, installed_entry.name, options)
    end
    return installed_entry.libPath
end

local function make_package_info(name, installed_entry, info, repo_path)
    info = info or {}
    local current_version = trim(installed_entry ~= nil and installed_entry.currentVersion or info.installedVersion)
    local latest_version = trim(info.latestVersion)
    local installed = installed_entry ~= nil or current_version ~= ""

    local extra = {}
    if info.owner ~= nil and info.owner ~= "" then
        extra.owner = info.owner
    end
    if type(info.tags) == "table" and #info.tags > 0 then
        extra.tags = info.tags
    end
    if repo_path ~= nil and repo_path ~= "" then
        extra.repoPath = repo_path
    end
    if installed_entry ~= nil then
        if installed_entry.libPath ~= nil and installed_entry.libPath ~= "" then
            extra.libPath = installed_entry.libPath
        end
        if type(installed_entry.installedVersions) == "table" and #installed_entry.installedVersions > 0 then
            extra.installedVersions = installed_entry.installedVersions
        end
    end
    extra = merge_extra_fields(extra, info.extraFields)
    if next(extra) == nil then
        extra = nil
    end

    local status = "available"
    if installed then
        status = "installed"
        if stable_release_version(current_version) and latest_version ~= "" and latest_version ~= current_version then
            status = "outdated"
        end
    end

    local version = current_version
    if version == "" then
        version = latest_version
    end

    local result = {
        type = "package",
        name = trim(name),
        packageId = trim(name),
        packageType = "library",
        version = version,
        latestVersion = latest_version,
        installed = installed,
        status = status,
        summary = info.summary or info.description,
        description = info.description or info.summary,
        homepage = info.homepage,
        license = info.license,
        repository = REMOTE_REPOSITORY,
        dependencies = (#(info.dependencies or {}) > 0) and info.dependencies or nil,
        extraFields = extra,
    }

    return result
end

local function get_installed_entry_map(context, options)
    local _, map = get_installed_state(context, options)
    return map or {}
end

local function resolved_package(context, package, options, installed_map, repo_path)
    local name = package_name(package)
    if name == "" then
        return nil
    end
    installed_map = installed_map or get_installed_entry_map(context, options)
    local installed_entry = installed_map[name]
    if installed_entry ~= nil then
        installed_entry.libPath = get_lib_path(context, name, options)
    end
    local info = fetch_info(context, name, options)
    local item = make_package_info(name, installed_entry, info, repo_path)
    local requested_version = package_version(package)
    if requested_version ~= "" and (item.version == nil or item.version == "") then
        item.version = requested_version
    end
    return item
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
    return { "Haxe", "Haxelib", "Package Manager" }
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
        ecosystemScopes = { "haxelib", "haxe" },
        writeScopes = {},
        networkScopes = { REMOTE_REPOSITORY },
        privilegeLevel = "user",
        purlType = "generic",
        versionComparatorProfile = "lexicographic",
    }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end
    if not command_exists(nil, REQUIRED_BINARY) then
        return requested
    end

    local options = command_options(nil, nil, {})
    local installed_items, installed_map = get_installed_state(nil, options)
    if installed_items == nil then
        return requested
    end

    local filtered = {}
    for _, package in ipairs(requested) do
        local name = package_name(package)
        local action = package_action(package)
        local installed_entry = installed_map[name]

        if action == "remove" then
            if installed_entry ~= nil then
                filtered[#filtered + 1] = package
            end
        elseif action == "update" then
            if installed_entry ~= nil and stable_release_version(installed_entry.currentVersion) then
                local info = fetch_info(nil, name, options)
                if info ~= nil and trim(info.latestVersion) ~= "" and trim(info.latestVersion) ~= trim(installed_entry.currentVersion) then
                    filtered[#filtered + 1] = package
                end
            end
        else
            local wanted_version = package_version(package)
            if installed_entry == nil then
                filtered[#filtered + 1] = package
            elseif wanted_version ~= "" and trim(installed_entry.currentVersion) ~= wanted_version then
                filtered[#filtered + 1] = package
            end
        end
    end

    return filtered
end

function plugin.install(context, packages)
    local local_path = request_local_path(context)
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end

    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    begin_step(context, "install haxelib packages")
    for _, package in ipairs(requested) do
        local name = package_name(package)
        if name == "" then
            tx_failed(context, "haxelib install failed: missing package name")
            return false
        end
        local args = { name }
        local version = package_version(package)
        if version ~= "" then
            args[#args + 1] = version
        end
        local options = command_options(context, package, { always = true })
        local result = exec_run(context, build_haxelib_command("install", args, options))
        if not result.success then
            tx_failed(context, "haxelib install failed for " .. name)
            return false
        end
    end

    emit_event(context, "installed", requested)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local target = request_local_path(context, path)
    if target == "" then
        tx_failed(context, "haxelib installLocal failed: missing path")
        return false
    end
    if lower(target):sub(-4) ~= ".zip" then
        tx_failed(context, "haxelib installLocal supports only .zip archives")
        return false
    end

    begin_step(context, "install local haxelib package")
    local options = command_options(context, nil, { always = true })
    local result = exec_run(context, build_haxelib_command("install", { target }, options))
    if not result.success then
        tx_failed(context, "haxelib installLocal failed")
        return false
    end

    emit_event(context, "installed", {
        path = target,
        localTarget = true,
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    begin_step(context, "remove haxelib packages")
    for _, package in ipairs(requested) do
        local name = package_name(package)
        if name == "" then
            tx_failed(context, "haxelib remove failed: missing package name")
            return false
        end
        local args = { name }
        local version = package_version(package)
        if version ~= "" then
            args[#args + 1] = version
        end
        local options = command_options(context, package, {})
        local result = exec_run(context, build_haxelib_command("remove", args, options))
        if not result.success then
            tx_failed(context, "haxelib remove failed for " .. name)
            return false
        end
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    begin_step(context, "update haxelib packages")

    if #requested == 0 then
        local options = command_options(context, nil, { always = true })
        local result = exec_run(context, build_haxelib_command("update", {}, options))
        if not result.success then
            tx_failed(context, "haxelib update failed")
            return false
        end
        emit_event(context, "updated", {})
        tx_success(context)
        return true
    end

    for _, package in ipairs(requested) do
        local name = package_name(package)
        if name == "" then
            tx_failed(context, "haxelib update failed: missing package name")
            return false
        end
        local options = command_options(context, package, { always = true })
        local result = exec_run(context, build_haxelib_command("update", { name }, options))
        if not result.success then
            tx_failed(context, "haxelib update failed for " .. name)
            return false
        end
    end

    emit_event(context, "updated", requested)
    tx_success(context)
    return true
end

function plugin.list(context)
    local options = command_options(context, nil, {})
    local repo_path = get_repo_path(context, options)
    local installed_items, _, err = get_installed_state(context, options)
    if installed_items == nil then
        log_warn(context, "haxelib list failed: " .. trim(err))
        emit_event(context, "listed", {})
        return {}
    end

    local results = {}
    for _, entry in ipairs(installed_items) do
        entry.libPath = get_lib_path(context, entry.name, options)
        results[#results + 1] = make_package_info(entry.name, entry, nil, repo_path)
    end

    emit_event(context, "listed", results)
    return results
end

function plugin.outdated(context)
    local options = command_options(context, nil, {})
    local repo_path = get_repo_path(context, options)
    local installed_items = plugin.list(context)
    local results = {}

    for _, item in ipairs(installed_items) do
        if item.installed and stable_release_version(item.version) then
            local info = fetch_info(context, item.name, command_options(context, nil, { global = false }))
            if info ~= nil then
                local latest_version = trim(info.latestVersion)
                if latest_version ~= "" and latest_version ~= trim(item.version) then
                    local installed_entry = {
                        name = item.name,
                        currentVersion = item.version,
                        installedVersions = item.extraFields ~= nil and item.extraFields.installedVersions or nil,
                        libPath = item.extraFields ~= nil and item.extraFields.libPath or nil,
                    }
                    results[#results + 1] = make_package_info(item.name, installed_entry, info, repo_path)
                end
            end
        end
    end

    emit_event(context, "outdated", results)
    return results
end

function plugin.search(context, prompt)
    local query = trim(prompt)
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end

    local options = command_options(context, nil, { global = false })
    local result = exec_run(context, build_haxelib_command("search", { query }, options))
    if not result.success then
        log_warn(context, "haxelib search failed for " .. query)
        emit_event(context, "searched", {})
        return {}
    end

    local repo_path = get_repo_path(context, command_options(context, nil, {}))
    local _, installed_map = get_installed_state(context, command_options(context, nil, {}))
    installed_map = installed_map or {}

    local results = {}
    for _, name in ipairs(search_names_from_output(result.stdout)) do
        local installed_entry = installed_map[name]
        if installed_entry ~= nil then
            installed_entry.libPath = get_lib_path(context, name, command_options(context, nil, {}))
        end
        local info = fetch_info(context, name, command_options(context, nil, { global = false }))
        results[#results + 1] = make_package_info(name, installed_entry, info, repo_path)
    end

    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local package_name_value = trim(name)
    if package_name_value == "" then
        emit_event(context, "unavailable", { name = name })
        return {}
    end

    local global_options = command_options(context, nil, {})
    local repo_path = get_repo_path(context, global_options)
    local _, installed_map = get_installed_state(context, global_options)
    installed_map = installed_map or {}
    local installed_entry = installed_map[package_name_value]
    if installed_entry ~= nil then
        installed_entry.libPath = get_lib_path(context, package_name_value, global_options)
    end

    local info = fetch_info(context, package_name_value, command_options(context, nil, { global = false }))
    if info == nil and installed_entry == nil then
        emit_event(context, "unavailable", { name = package_name_value })
        return {}
    end

    local item = make_package_info(package_name_value, installed_entry, info, repo_path)
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local options = command_options(context, package, {})
    local repo_path = get_repo_path(context, options)
    local installed_map = get_installed_entry_map(context, options)
    local resolved = resolved_package(context, package, options, installed_map, repo_path)
    if resolved == nil then
        return package
    end

    local merged = shallow_copy(type(package) == "table" and package or {})
    for key, value in pairs(resolved) do
        merged[key] = value
    end
    return merged
end

return plugin
