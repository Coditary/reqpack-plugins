plugin = {}

local PLUGIN_ID = "eupm"
local PLUGIN_NAME = "Euphoria Package Manager"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "eupm"

local COMMAND_VERBS = {
    install = "install",
    remove = "remove",
    update = "update",
    list = "list",
    search = "search",
    info = "info",
}

local PROBE_STATE = {
    attempted = false,
    enabled = false,
    details = {},
    verbs = nil,
}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return trim(value):lower()
end

local function is_blank(value)
    return trim(value) == ""
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

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if not is_blank(value) then
            return trim(value)
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

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        return os.getenv(name)
    end
    return nil
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

local function append_unique(list, value, seen)
    local cleaned = trim(value)
    if cleaned == "" or seen[cleaned] then
        return
    end
    seen[cleaned] = true
    list[#list + 1] = cleaned
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
    collect_from(read_field(context, "request"))
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

local function env_truthy(name)
    local value = lower(trim(getenv(name) or ""))
    return value == "1" or value == "true" or value == "yes" or value == "on"
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

local function log_info_like(context, message)
    if context ~= nil and context.log ~= nil then
        local info_fn = context.log.info
        if type(info_fn) == "function" then
            info_fn(message)
            return
        end
    end
    log_warn(context, message)
end

local function normalize_run_result(first, second, third, fourth, fifth)
    if type(first) == "table" or type(first) == "userdata" then
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

    local function merge_value(value)
        local value_type = type(value)
        if value_type == "table" then
            for key, item in pairs(value or {}) do
                result[key] = item
            end
        elseif value_type == "userdata" then
            local stdout = read_field(value, "stdout") or read_field(value, "stdoutText")
            local stderr = read_field(value, "stderr") or read_field(value, "stderrText")
            local exit_code = read_field(value, "exitCode") or read_field(value, "exit_code") or read_field(value, "code") or read_field(value, "status")
            local success = read_field(value, "success")
            local ok = read_field(value, "ok")
            if stdout ~= nil then
                result.stdout = stdout
            end
            if stderr ~= nil then
                result.stderr = stderr
            end
            if exit_code ~= nil then
                result.exitCode = exit_code
            end
            if success ~= nil then
                result.success = success
            elseif ok ~= nil then
                result.success = ok
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

    merge_value(first)
    merge_value(second)
    merge_value(third)
    merge_value(fourth)
    merge_value(fifth)

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

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. binary .. " >/dev/null 2>&1")
    return result.success == true
end

local function contains_word(text, word)
    local haystack = " " .. lower(text or "") .. " "
    local needle = "%f[%a]" .. lower(word) .. "%f[^%a]"
    return haystack:match(needle) ~= nil
end

local function detect_verb(help_text, fallback, candidates)
    for _, candidate in ipairs(candidates) do
        if contains_word(help_text, candidate) then
            return candidate
        end
    end
    return fallback
end

local function apply_probe_help(help_text)
    local detected = {
        install = COMMAND_VERBS.install,
        remove = COMMAND_VERBS.remove,
        update = COMMAND_VERBS.update,
        list = COMMAND_VERBS.list,
        search = COMMAND_VERBS.search,
        info = COMMAND_VERBS.info,
    }
    detected.remove = detect_verb(help_text, detected.remove, { "remove", "uninstall", "delete" })
    detected.update = detect_verb(help_text, detected.update, { "update", "upgrade", "up" })
    detected.list = detect_verb(help_text, detected.list, { "list", "installed", "ls" })
    detected.search = detect_verb(help_text, detected.search, { "search", "find", "lookup" })
    detected.info = detect_verb(help_text, detected.info, { "info", "show", "query" })
    return detected
end

local function should_probe(context, package)
    if env_truthy("REQPACK_EUPM_PROBE") then
        return true
    end
    local flags = collect_flags(context, package)
    return has_flag(flags, "probe") or lower(trim(flag_value(flags, "probe") or "")) == "help"
end

local function reset_probe_state_if_needed(context, package)
    if should_probe(context, package) then
        return
    end
    PROBE_STATE.attempted = false
    PROBE_STATE.enabled = false
    PROBE_STATE.details = {}
    PROBE_STATE.verbs = nil
end

local function maybe_probe(context, package)
    if PROBE_STATE.attempted or not should_probe(context, package) then
        return
    end

    PROBE_STATE.attempted = true
    PROBE_STATE.enabled = true

    if not command_exists(context, REQUIRED_BINARY) then
        log_warn(context, "eupm probe requested but binary not found")
        return
    end

    local candidates = {
        "eupm --help",
        "eupm help",
        "eupm -h",
    }
    local help_texts = {}

    for _, command in ipairs(candidates) do
        local result = exec_run(context, command)
        if result ~= nil and result.success == true then
            help_texts[#help_texts + 1] = trim(result.stdout)
            PROBE_STATE.details[#PROBE_STATE.details + 1] = command
        end
    end

    if #help_texts == 0 then
        log_warn(context, "eupm probe found no successful help command")
        return
    end

    local combined_help = table.concat(help_texts, "\n")
    local detected = apply_probe_help(combined_help)
    PROBE_STATE.verbs = detected
    log_info_like(
        context,
        "eupm probe verbs: remove=" .. detected.remove
            .. ", update=" .. detected.update
            .. ", list=" .. detected.list
            .. ", search=" .. detected.search
            .. ", info=" .. detected.info
    )
end

local function active_verbs()
    return PROBE_STATE.verbs or COMMAND_VERBS
end

local function diagnostic_snapshot(context)
    local verbs = active_verbs()
    local details = {}
    for _, item in ipairs(PROBE_STATE.details or {}) do
        details[#details + 1] = item
    end
    return {
        binary = REQUIRED_BINARY,
        binaryFound = command_exists(context, REQUIRED_BINARY),
        probeEnabled = PROBE_STATE.enabled == true,
        probeAttempted = PROBE_STATE.attempted == true,
        helpCommands = details,
        verbs = {
            install = verbs.install,
            remove = verbs.remove,
            update = verbs.update,
            list = verbs.list,
            search = verbs.search,
            info = verbs.info,
        },
    }
end

local function package_selector(pkg)
    if pkg == nil then
        return nil
    end
    local name = trim(read_field(pkg, "name") or "")
    local version = trim(read_field(pkg, "version") or "")
    if name == "" then
        return nil
    end
    if version ~= "" then
        return name .. "@" .. version
    end
    return name
end

local function make_package_id(name, version)
    if is_blank(name) then
        return nil
    end
    if is_blank(version) then
        return trim(name)
    end
    return trim(name) .. "@" .. trim(version)
end

local function parse_name_version_line(line)
    local cleaned = trim(line)
    if cleaned == "" then
        return nil
    end

    local name, version = cleaned:match("^(%S+)%s+v?([%d][%w%._%-%+]*)%s*$")
    if name ~= nil then
        return {
            name = name,
            version = version,
        }
    end

    name, version = cleaned:match("^(%S+)%s*[%-%:]%s*v?([%d][%w%._%-%+]*)%s*$")
    if name ~= nil then
        return {
            name = name,
            version = version,
        }
    end

    name = cleaned:match("^(%S+)")
    if name ~= nil then
        return { name = name }
    end
    return nil
end

local function parse_list_output(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local parsed = parse_name_version_line(line)
        if parsed ~= nil and not is_blank(parsed.name) then
            items[#items + 1] = {
                name = parsed.name,
                packageId = make_package_id(parsed.name, parsed.version),
                version = parsed.version,
                installed = true,
                status = "installed",
                packageType = "library",
            }
        end
    end

    table.sort(items, function(left, right)
        return lower(left.name) < lower(right.name)
    end)
    return items
end

local function installed_name_set(items)
    local names = {}
    for _, item in ipairs(items or {}) do
        local name = lower(item.name)
        if name ~= "" then
            names[name] = item.version or true
        end
    end
    return names
end

local function query_installed_items(context)
    maybe_probe(context, nil)
    local verbs = active_verbs()
    local result = exec_run(context, "eupm " .. verbs.list)
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_list_output(result.stdout)
end

local function parse_search_output(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            local name, version, summary = cleaned:match("^(%S+)%s+v?([%d][%w%._%-%+]*)%s*%-+%s*(.+)$")
            if name == nil then
                name, version, summary = cleaned:match("^(%S+)%s+v?([%d][%w%._%-%+]*)%s+(.+)$")
            end
            if name == nil then
                name, summary = cleaned:match("^(%S+)%s*%-+%s*(.+)$")
            end
            if name == nil then
                name = cleaned:match("^(%S+)")
            end
            if name ~= nil then
                items[#items + 1] = {
                    name = name,
                    packageId = make_package_id(name, version),
                    version = version,
                    summary = trim(summary),
                    description = trim(summary),
                    installed = false,
                    status = "available",
                    packageType = "library",
                }
            end
        end
    end
    return items
end

local function finalize_info_item(item)
    if item == nil or is_blank(item.name) then
        return {}
    end
    item.packageId = make_package_id(item.name, item.version)
    item.packageType = "library"
    if item.installed == nil then
        item.installed = false
    end
    if is_blank(item.status) then
        item.status = item.installed and "installed" or "available"
    end
    if item.extraFields ~= nil and next(item.extraFields) == nil then
        item.extraFields = nil
    end
    return item
end

local function parse_info_output(stdout)
    local item = {
        installed = false,
        status = "available",
        extraFields = {},
    }
    local description_lines = {}

    for index, line in ipairs(split_lines(stdout)) do
        local key, value = line:match("^([%a][%w _%-]*)%s*:%s*(.-)%s*$")
        if key ~= nil then
            local normalized = lower(key)
            value = trim(value)
            if normalized == "name" or normalized == "package" then
                item.name = value
            elseif normalized == "version" then
                item.version = value
            elseif normalized == "latest version" or normalized == "latest" then
                item.latestVersion = value
            elseif normalized == "installed" then
                item.installed = lower(value) == "true" or lower(value) == "yes"
                if item.installed and item.status == "available" then
                    item.status = "installed"
                end
            elseif normalized == "summary" then
                item.summary = value
            elseif normalized == "description" then
                description_lines[#description_lines + 1] = value
            elseif normalized == "homepage" or normalized == "url" then
                item.homepage = value
            elseif normalized == "author" or normalized == "authors" or normalized == "maintainer" then
                item.author = value
            elseif normalized == "license" then
                item.license = value
            elseif normalized == "status" then
                item.status = lower(value)
                item.installed = lower(value) == "installed" or lower(value) == "outdated"
            else
                item.extraFields[normalized] = value
            end
        elseif index == 1 then
            local header = parse_name_version_line(line)
            if header ~= nil then
                item.name = header.name
                item.version = header.version
            else
                local header_name, header_version, header_summary = trim(line):match("^(%S+)%s+v?([%d][%w%._%-%+]*)%s*%-+%s*(.+)$")
                if header_name ~= nil then
                    item.name = header_name
                    item.version = header_version
                    item.summary = first_nonempty(item.summary, header_summary)
                else
                    local header_only_name, header_only_summary = trim(line):match("^(%S+)%s*%-+%s*(.+)$")
                    if header_only_name ~= nil then
                        item.name = header_only_name
                        item.summary = first_nonempty(item.summary, header_only_summary)
                    elseif trim(line) ~= "" then
                        item.extraFields.rawHeader = trim(line)
                    end
                end
            end
        elseif trim(line) ~= "" then
            description_lines[#description_lines + 1] = trim(line)
        end
    end

    if is_blank(item.description) and #description_lines > 0 then
        item.description = table.concat(description_lines, "\n")
    end
    if is_blank(item.summary) and not is_blank(item.description) then
        item.summary = item.description:match("^([^\n]+)") or item.description
    end
    return finalize_info_item(item)
end

local function install_command(pkg)
    local selector = package_selector(pkg)
    if selector == nil then
        return nil
    end
    local verbs = active_verbs()
    return "eupm " .. verbs.install .. " " .. shell_quote(selector)
end

local function remove_command(pkg)
    local name = trim(read_field(pkg, "name") or "")
    if name == "" then
        return nil
    end
    local verbs = active_verbs()
    return "eupm " .. verbs.remove .. " " .. shell_quote(name)
end

local function update_command(pkg)
    local selector = package_selector(pkg)
    if selector == nil then
        return nil
    end
    local verbs = active_verbs()
    return "eupm " .. verbs.update .. " " .. shell_quote(selector)
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
    return { "language", "package-manager", "euphoria" }
end

function plugin.init()
    return command_exists(nil, REQUIRED_BINARY)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "euphoria" },
        writeScopes = {},
        networkScopes = {},
        privilegeLevel = "none",
        purlType = "generic",
    }
end

function plugin.diagnoseEupm(context)
    reset_probe_state_if_needed(context, nil)
    maybe_probe(context, nil)
    return diagnostic_snapshot(context)
end

function plugin.getMissingPackages(packages)
    local installed = query_installed_items(nil)
    if installed == nil then
        return packages or {}
    end

    local installed_map = installed_name_set(installed)
    local missing = {}

    for _, pkg in ipairs(packages or {}) do
        local action = lower(read_field(pkg, "action") or "")
        local name = trim(read_field(pkg, "name") or "")
        local version = trim(read_field(pkg, "version") or "")
        local installed_version = installed_map[lower(name)]
        if name ~= "" then
            if action == "install" then
                if installed_version == nil then
                    missing[#missing + 1] = pkg
                elseif version ~= "" and installed_version ~= true and trim(installed_version) ~= version then
                    missing[#missing + 1] = pkg
                end
            elseif action == "remove" then
                if installed_version ~= nil then
                    missing[#missing + 1] = pkg
                end
            elseif action == "update" then
                missing[#missing + 1] = pkg
            end
        end
    end

    return missing
end

function plugin.install(context, packages)
    if packages == nil or #packages == 0 then
        return true
    end

    reset_probe_state_if_needed(context, nil)
    for _, pkg in ipairs(packages) do
        maybe_probe(context, pkg)
        local command = install_command(pkg)
        if command ~= nil then
            begin_step(context, "Installing " .. trim(read_field(pkg, "name") or "package"))
            local result = exec_run(context, command)
            if result == nil or result.success ~= true then
                tx_failed(context, "eupm install failed")
                return false
            end
        end
    end

    emit_event(context, "installed", packages)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local cleaned = trim(path)
    if cleaned == "" then
        tx_failed(context, "missing local path")
        return false
    end

    reset_probe_state_if_needed(context, nil)
    begin_step(context, "Installing local eupm package")
    maybe_probe(context, nil)
    local verbs = active_verbs()
    local result = exec_run(context, "eupm " .. verbs.install .. " " .. shell_quote(cleaned))
    if result == nil or result.success ~= true then
        tx_failed(context, "eupm local install failed")
        return false
    end

    emit_event(context, "installed", {
        {
            name = cleaned,
            packageId = cleaned,
            localTarget = true,
            packageType = "library",
        }
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    if packages == nil or #packages == 0 then
        return true
    end

    reset_probe_state_if_needed(context, nil)
    for _, pkg in ipairs(packages) do
        maybe_probe(context, pkg)
        local command = remove_command(pkg)
        if command ~= nil then
            begin_step(context, "Removing " .. trim(read_field(pkg, "name") or "package"))
            local result = exec_run(context, command)
            if result == nil or result.success ~= true then
                tx_failed(context, "eupm remove failed")
                return false
            end
        end
    end

    emit_event(context, "deleted", packages)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    if packages == nil or #packages == 0 then
        return true
    end

    reset_probe_state_if_needed(context, nil)
    for _, pkg in ipairs(packages) do
        maybe_probe(context, pkg)
        local command = update_command(pkg)
        if command ~= nil then
            begin_step(context, "Updating " .. trim(read_field(pkg, "name") or "package"))
            local result = exec_run(context, command)
            if result == nil or result.success ~= true then
                tx_failed(context, "eupm update failed")
                return false
            end
        end
    end

    emit_event(context, "updated", packages)
    tx_success(context)
    return true
end

function plugin.list(context)
    reset_probe_state_if_needed(context, nil)
    maybe_probe(context, nil)
    local verbs = active_verbs()
    local result = exec_run(context, "eupm " .. verbs.list)
    if result == nil or result.success ~= true then
        log_warn(context, "eupm list failed")
        return {}
    end
    local items = parse_list_output(result.stdout)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    reset_probe_state_if_needed(context, nil)
    local items = {}
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned = trim(prompt)
    if cleaned == "" then
        emit_event(context, "searched", {})
        return {}
    end

    reset_probe_state_if_needed(context, nil)
    maybe_probe(context, nil)
    local verbs = active_verbs()
    local result = exec_run(context, "eupm " .. verbs.search .. " " .. shell_quote(cleaned))
    if result == nil or result.success ~= true then
        log_warn(context, "eupm search failed")
        return {}
    end
    local items = parse_search_output(result.stdout)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local cleaned = trim(name)
    if cleaned == "" then
        return {}
    end

    reset_probe_state_if_needed(context, nil)
    maybe_probe(context, nil)
    local verbs = active_verbs()
    local result = exec_run(context, "eupm " .. verbs.info .. " " .. shell_quote(cleaned))
    if result == nil or result.success ~= true then
        log_warn(context, "eupm info failed")
        return {}
    end
    local item = parse_info_output(result.stdout)
    emit_event(context, "informed", item)
    return item
end

function plugin.shutdown()
    PROBE_STATE.attempted = false
    PROBE_STATE.enabled = false
    PROBE_STATE.details = {}
    PROBE_STATE.verbs = nil
    return true
end

return plugin
