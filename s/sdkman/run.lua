plugin = {}

local PLUGIN_ID = "sdkman"
local PLUGIN_NAME = "sdkman"
local PLUGIN_VERSION = "0.1.0"
local SDKMAN_HOME = "$HOME/.sdkman"

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

local function double_quote(value)
    local cleaned = tostring(value or "")
    cleaned = cleaned:gsub("\\", "\\\\")
    cleaned = cleaned:gsub('"', '\\"')
    cleaned = cleaned:gsub("`", "\\`")
    cleaned = cleaned:gsub("%$", "\\$")
    return '"' .. cleaned .. '"'
end

local function split_lines(value)
    local lines = {}
    for line in tostring(value or ""):gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end
    return lines
end

local function split_tsv(line)
    local fields = {}
    for field in (tostring(line or "") .. "\t"):gmatch("(.-)\t") do
        fields[#fields + 1] = field
    end
    return fields
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

local function exec_run(context, command)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return context.exec.run(command)
    end
    return run_global(command)
end

local function sdkman_shell(command)
    local script = table.concat({
        "export SDKMAN_DIR=\"" .. SDKMAN_HOME .. "\"",
        "export sdkman_auto_answer=true",
        "export sdkman_colour_enable=false",
        "export sdkman_auto_complete=false",
        "export sdkman_auto_env=false",
        "export sdkman_selfupdate_feature=false",
        "export sdkman_healthcheck_enable=false",
        "export USE=n",
        "export PAGER=cat",
        "export TERM=dumb",
        ". \"$SDKMAN_DIR/bin/sdkman-init.sh\" >/dev/null 2>&1",
        command,
    }, "; ")
    return "bash -lc " .. shell_quote(script)
end

local function run_sdk(context, command)
    return exec_run(context, sdkman_shell(command))
end

local function command_exists(context)
    local result = exec_run(context, "test -f \"" .. SDKMAN_HOME .. "/bin/sdkman-init.sh\"")
    return result ~= nil and result.success == true
end

local function build_package_id(name, version)
    local candidate = trim(name)
    local resolved = trim(version)
    if candidate == "" or resolved == "" then
        return nil
    end
    return PLUGIN_ID .. "/" .. candidate .. "/" .. resolved
end

local function package_action(pkg)
    local action = read_field(pkg, "action")
    if type(action) == "number" then
        return ""
    end
    return lower(action or "")
end

local function request_candidate_name(pkg)
    return trim(read_field(pkg, "name") or "")
end

local function requested_version(pkg, default_latest)
    local version = trim(read_field(pkg, "version") or "")
    if version ~= "" then
        return version
    end
    if default_latest then
        return "latest"
    end
    return ""
end

local function append_all(target, items)
    for _, item in ipairs(items or {}) do
        target[#target + 1] = item
    end
end

local function find_version(entries, wanted)
    for _, entry in ipairs(entries or {}) do
        if entry.version == wanted then
            return entry
        end
    end
    return nil
end

local function sort_items(items)
    table.sort(items, function(left, right)
        local left_key = trim(left.packageId or left.name or "")
        local right_key = trim(right.packageId or right.name or "")
        return left_key < right_key
    end)
    return items
end

local function parse_name_lines(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            items[#items + 1] = cleaned
        end
    end
    return items
end

local function parse_version_entries(stdout)
    local entries = {}
    for _, line in ipairs(split_lines(stdout)) do
        local fields = split_tsv(line)
        local version = non_empty(fields[1])
        if version ~= nil then
            entries[#entries + 1] = {
                version = version,
                kind = non_empty(fields[2]) or "d",
            }
        end
    end
    return entries
end

local function parse_single_value(stdout)
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            return cleaned
        end
    end
    return nil
end

local function query_candidate_cache(context)
    local command = "if [ -f \"" .. SDKMAN_HOME .. "/var/candidates\" ]; then tr ',' '\\n' < \"" .. SDKMAN_HOME .. "/var/candidates\"; fi"
    local result = exec_run(context, "bash -lc " .. shell_quote(command))
    if result == nil or not result.success then
        return nil, "sdkman candidate cache read failed"
    end
    return parse_name_lines(result.stdout), nil
end

local function query_installed_candidates(context)
    local command = "if [ -d \"" .. SDKMAN_HOME .. "/candidates\" ]; then find \"" .. SDKMAN_HOME .. "/candidates\" -mindepth 1 -maxdepth 1 -type d -printf '%f\\n' | sort; fi"
    local result = exec_run(context, "bash -lc " .. shell_quote(command))
    if result == nil or not result.success then
        return nil, "sdkman installed candidate scan failed"
    end
    return parse_name_lines(result.stdout), nil
end

local function query_candidate_versions(context, candidate)
    local path = SDKMAN_HOME .. "/candidates/" .. candidate
    local command = "if [ -d \"" .. path .. "\" ]; then find \"" .. path .. "\" -mindepth 1 -maxdepth 1 \\( -type d -o -type l \\) ! -name current -printf '%f\\t%y\\n' | sort; fi"
    local result = exec_run(context, "bash -lc " .. shell_quote(command))
    if result == nil or not result.success then
        return nil, "sdkman version scan failed for " .. candidate
    end
    return parse_version_entries(result.stdout), nil
end

local function query_current_version(context, candidate)
    local path = SDKMAN_HOME .. "/candidates/" .. candidate .. "/current"
    local command = "if [ -L \"" .. path .. "\" ]; then target=$(readlink \"" .. path .. "\"); basename \"$target\"; fi"
    local result = exec_run(context, "bash -lc " .. shell_quote(command))
    if result == nil or not result.success then
        return nil, "sdkman current link read failed for " .. candidate
    end
    return parse_single_value(result.stdout), nil
end

local function query_default_version(context, candidate)
    local url = "${SDKMAN_CANDIDATES_API}/candidates/default/" .. candidate
    local result = run_sdk(context, "printf '%s\\n' \"$(__sdkman_secure_curl \"" .. url .. "\")\"")
    if result == nil or not result.success then
        return nil, "sdkman default version lookup failed for " .. candidate
    end
    return parse_single_value(result.stdout), nil
end

local function resolve_target_version(context, pkg)
    local candidate = request_candidate_name(pkg)
    if candidate == "" then
        return nil, "sdkman candidate name missing"
    end

    local version = requested_version(pkg, true)
    if version ~= "" and version ~= "latest" then
        return version, nil
    end

    local resolved, err = query_default_version(context, candidate)
    if resolved == nil then
        return nil, err
    end
    return resolved, nil
end

local function install_path(candidate, version)
    return SDKMAN_HOME .. "/candidates/" .. candidate .. "/" .. version
end

local function build_version_item(candidate, entry, current_version, latest_version, status)
    local extra = {
        installPath = install_path(candidate, entry.version),
    }
    if entry.kind == "l" then
        extra.linked = "true"
    end
    if current_version ~= nil and current_version == entry.version then
        extra.current = "true"
    end

    return {
        name = candidate,
        packageId = build_package_id(candidate, entry.version),
        version = entry.version,
        latestVersion = latest_version,
        installed = true,
        status = status or "installed",
        summary = "Installed SDKMAN version for " .. candidate,
        description = "Installed SDKMAN version for " .. candidate,
        packageType = "candidate-version",
        type = "package",
        extraFields = extra,
    }
end

local function collect_candidate_items(context, candidate, include_latest)
    local entries = query_candidate_versions(context, candidate)
    if type(entries) ~= "table" then
        return {}
    end

    local current_version = nil
    local latest_version = nil
    current_version = select(1, query_current_version(context, candidate))
    if include_latest then
        latest_version = select(1, query_default_version(context, candidate))
    end

    local items = {}
    for _, entry in ipairs(entries) do
        local status = "installed"
        if latest_version ~= nil and entry.kind ~= "l" and entry.version ~= latest_version then
            status = "outdated"
        end
        items[#items + 1] = build_version_item(candidate, entry, current_version, latest_version, status)
    end
    return items
end

local function installed_candidate_set(context)
    local names = query_installed_candidates(context)
    if type(names) ~= "table" then
        return {}
    end
    local set = {}
    for _, name in ipairs(names) do
        set[name] = true
    end
    return set
end

local function selected_candidate_version(entries, current_version)
    if current_version ~= nil and current_version ~= "" then
        return current_version
    end
    if type(entries) == "table" and #entries > 0 then
        return entries[#entries].version
    end
    return nil
end

plugin.fileExtensions = {}

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
    return { "Package Manager", "Version Manager", "SDKMAN" }
end

function plugin.getMissingPackages(packages)
    local items = packages or {}
    if #items == 0 then
        return {}
    end

    if not command_exists(nil) then
        local missing = {}
        for _, pkg in ipairs(items) do
            local action = package_action(pkg)
            if action ~= "remove" and action ~= "update" then
                missing[#missing + 1] = pkg
            end
        end
        return missing
    end

    local versions_by_candidate = {}
    local filtered = {}
    for _, pkg in ipairs(items) do
        local candidate = request_candidate_name(pkg)
        if versions_by_candidate[candidate] == nil then
            local entries = query_candidate_versions(nil, candidate)
            versions_by_candidate[candidate] = type(entries) == "table" and entries or {}
        end

        local entries = versions_by_candidate[candidate]
        local action = package_action(pkg)
        if action == "remove" then
            local version = requested_version(pkg, false)
            if version ~= "" and find_version(entries, version) ~= nil then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "update" then
            local latest = select(1, query_default_version(nil, candidate))
            if latest == nil or find_version(entries, latest) == nil then
                filtered[#filtered + 1] = pkg
            end
        else
            local version = select(1, resolve_target_version(nil, pkg))
            if version == nil or find_version(entries, version) == nil then
                filtered[#filtered + 1] = pkg
            end
        end
    end

    return filtered
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    if not command_exists(context) then
        tx_failed(context, "sdkman not installed")
        return false
    end

    begin_step(context, "install sdkman packages")
    local installed = {}
    for _, pkg in ipairs(requested) do
        local candidate = request_candidate_name(pkg)
        if candidate == "" then
            tx_failed(context, "sdkman candidate name missing")
            return false
        end

        local version, resolve_error = resolve_target_version(context, pkg)
        if version == nil then
            tx_failed(context, resolve_error or ("sdkman version resolve failed for " .. candidate))
            return false
        end

        local result = run_sdk(context, "sdk install " .. double_quote(candidate) .. " " .. double_quote(version))
        if result == nil or not result.success then
            tx_failed(context, "sdkman install failed for " .. candidate)
            return false
        end

        installed[#installed + 1] = build_version_item(candidate, {
            version = version,
            kind = "d",
        }, select(1, query_current_version(context, candidate)), version, "installed")
    end

    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    begin_step(context, "install local sdkman target")
    tx_failed(context, "sdkman installLocal is not supported; use install with candidate name and version")
    emit_event(context, "unavailable", {
        path = path,
        reason = "local-install-unsupported",
    })
    return false
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    if not command_exists(context) then
        tx_failed(context, "sdkman not installed")
        return false
    end

    begin_step(context, "remove sdkman packages")
    local removed = {}
    for _, pkg in ipairs(requested) do
        local candidate = request_candidate_name(pkg)
        local version = requested_version(pkg, false)
        if candidate == "" then
            tx_failed(context, "sdkman candidate name missing")
            return false
        end
        if version == "" or version == "latest" then
            tx_failed(context, "sdkman remove requires explicit version")
            return false
        end

        local result = run_sdk(context, "sdk uninstall " .. double_quote(candidate) .. " " .. double_quote(version))
        if result == nil or not result.success then
            tx_failed(context, "sdkman uninstall failed for " .. candidate)
            return false
        end

        removed[#removed + 1] = {
            name = candidate,
            packageId = build_package_id(candidate, version),
            version = version,
            packageType = "candidate-version",
            type = "package",
            installed = false,
            status = "removed",
        }
    end

    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    if not command_exists(context) then
        tx_failed(context, "sdkman not installed")
        return false
    end

    local requested = packages or {}
    local targets = {}
    if #requested == 0 then
        local installed_candidates, installed_error = query_installed_candidates(context)
        if installed_candidates == nil then
            tx_failed(context, installed_error or "sdkman installed candidate scan failed")
            return false
        end
        for _, candidate in ipairs(installed_candidates) do
            targets[#targets + 1] = { name = candidate }
        end
    else
        targets = requested
    end

    begin_step(context, "update sdkman packages")
    local updated = {}
    for _, pkg in ipairs(targets) do
        local candidate = request_candidate_name(pkg)
        if candidate == "" then
            tx_failed(context, "sdkman candidate name missing")
            return false
        end

        local latest, latest_error = query_default_version(context, candidate)
        if latest == nil then
            tx_failed(context, latest_error or ("sdkman default version lookup failed for " .. candidate))
            return false
        end

        local entries = query_candidate_versions(context, candidate)
        if type(entries) ~= "table" then
            tx_failed(context, "sdkman update target not installed: " .. candidate)
            return false
        end

        if find_version(entries, latest) == nil then
            local result = run_sdk(context, "sdk install " .. double_quote(candidate) .. " " .. double_quote(latest))
            if result == nil or not result.success then
                tx_failed(context, "sdkman update failed for " .. candidate)
                return false
            end

            updated[#updated + 1] = build_version_item(candidate, {
                version = latest,
                kind = "d",
            }, select(1, query_current_version(context, candidate)), latest, "installed")
        end
    end

    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    if not command_exists(context) then
        emit_event(context, "listed", {})
        return {}
    end

    local candidates, candidates_error = query_installed_candidates(context)
    if candidates == nil then
        log_warn(context, candidates_error)
        emit_event(context, "listed", {})
        return {}
    end

    local items = {}
    for _, candidate in ipairs(candidates) do
        append_all(items, collect_candidate_items(context, candidate, false))
    end

    sort_items(items)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    if not command_exists(context) then
        emit_event(context, "outdated", {})
        return {}
    end

    local candidates, candidates_error = query_installed_candidates(context)
    if candidates == nil then
        log_warn(context, candidates_error)
        emit_event(context, "outdated", {})
        return {}
    end

    local items = {}
    for _, candidate in ipairs(candidates) do
        local candidate_items = collect_candidate_items(context, candidate, true)
        for _, item in ipairs(candidate_items) do
            if item.status == "outdated" then
                items[#items + 1] = item
            end
        end
    end

    sort_items(items)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned_prompt = trim(prompt)
    if cleaned_prompt == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    if not command_exists(context) then
        emit_event(context, "searched", {})
        return {}
    end

    local catalog, catalog_error = query_candidate_cache(context)
    if catalog == nil then
        log_warn(context, catalog_error)
        emit_event(context, "searched", {})
        return {}
    end

    local installed = installed_candidate_set(context)
    local items = {}
    for _, candidate in ipairs(catalog) do
        if lower(candidate):find(lower(cleaned_prompt), 1, true) ~= nil then
            local is_installed = installed[candidate] == true
            items[#items + 1] = {
                name = candidate,
                packageId = "sdkman-candidate/" .. candidate,
                summary = "SDKMAN candidate",
                description = "SDKMAN candidate cached locally",
                installed = is_installed,
                status = is_installed and "installed" or "available",
                packageType = "candidate",
                type = "package",
            }
        end
    end

    sort_items(items)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local candidate = trim(name)
    if candidate == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    if not command_exists(context) then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local catalog = query_candidate_cache(context)
    local known = false
    if type(catalog) == "table" then
        for _, item in ipairs(catalog) do
            if item == candidate then
                known = true
                break
            end
        end
    end

    local entries = query_candidate_versions(context, candidate)
    if type(entries) ~= "table" then
        entries = {}
    end
    if not known and #entries == 0 then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local current_version = select(1, query_current_version(context, candidate))
    local latest_version = select(1, query_default_version(context, candidate))
    local selected_version = selected_candidate_version(entries, current_version)
    local installed = #entries > 0
    local status = installed and "installed" or "available"
    if installed and latest_version ~= nil and find_version(entries, latest_version) == nil then
        status = "outdated"
    end

    local extra = {}
    if #entries > 0 then
        local installed_versions = {}
        for _, entry in ipairs(entries) do
            installed_versions[#installed_versions + 1] = entry.version
        end
        extra.installedVersions = table.concat(installed_versions, ",")
    end
    if current_version ~= nil then
        extra.currentVersion = current_version
    end

    local item = {
        name = candidate,
        packageId = installed and build_package_id(candidate, selected_version or latest_version or candidate) or ("sdkman-candidate/" .. candidate),
        version = selected_version,
        latestVersion = latest_version,
        installed = installed,
        status = status,
        summary = "SDKMAN candidate",
        description = "SDKMAN candidate and installed version summary",
        packageType = installed and "candidate-version" or "candidate",
        type = "package",
        extraFields = next(extra) ~= nil and extra or nil,
    }

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if type(package) ~= "table" then
        return nil
    end

    local candidate = request_candidate_name(package)
    if candidate == "" then
        return nil
    end

    local resolved = shallow_copy(package)
    local version = requested_version(package, true)
    if version == "latest" or version == "" then
        version = select(1, resolve_target_version(context, package))
    end

    resolved.name = candidate
    resolved.version = non_empty(version)
    resolved.packageId = build_package_id(candidate, version or "")
    resolved.packageType = "candidate-version"
    resolved.type = "package"
    return resolved
end

function plugin.init()
    return command_exists(nil)
end

function plugin.shutdown()
    return true
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "sdkman", "jvm" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".sdkman" },
        },
        privilegeLevel = "user",
        purlType = "generic",
    }
end

return plugin
