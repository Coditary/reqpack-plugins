plugin = {}

local PLUGIN_ID = "guix"
local PLUGIN_NAME = "GNU Guix"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "guix"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return trim(value):lower()
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
    local normalized = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    for line in (normalized .. "\n"):gmatch("(.-)\n") do
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

local function exec_run(context, command)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return context.exec.run(command)
    end
    return reqpack.exec.run(command)
end

local function home_dir()
    if os ~= nil and type(os.getenv) == "function" then
        return non_empty(os.getenv("HOME")) or non_empty(os.getenv("USERPROFILE")) or "/home/test"
    end
    return "/home/test"
end

local function guix_root()
    return home_dir() .. "/.cache/reqpack/guix"
end

local function guix_profile()
    return guix_root() .. "/profile"
end

local function env_prefix()
    return "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C'"
end

local function guix_command(parts)
    local command = env_prefix() .. " guix"
    for _, part in ipairs(parts or {}) do
        command = command .. " " .. part
    end
    return command
end

local function command_exists(binary)
    local result = reqpack.exec.run("command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function path_exists_as_file(context, path)
    local result = exec_run(context, "test -f " .. shell_quote(path))
    return result ~= nil and result.success == true
end

local function package_name(pkg)
    if pkg == nil then
        return ""
    end
    return trim(pkg.name)
end

local function package_version(pkg)
    if pkg == nil then
        return ""
    end
    return trim(pkg.version)
end

local function package_action(pkg)
    if pkg == nil then
        return ""
    end
    return lower(pkg.action)
end

local function package_selector(pkg)
    local name = package_name(pkg)
    local version = package_version(pkg)
    if name == "" then
        return ""
    end
    if version ~= "" and name:find("@", 1, true) == nil and name:sub(1, 1) ~= "/" then
        return name .. "@" .. version
    end
    return name
end

local function request_packages(context, packages)
    if (type(packages) == "table" or type(packages) == "userdata") and #packages > 0 then
        return packages
    end
    local request = context ~= nil and context.request or nil
    local request_packages_value = request ~= nil and request.packages or nil
    if type(request_packages_value) == "table" or type(request_packages_value) == "userdata" then
        return request_packages_value
    end
    return {}
end

local function local_path_from_context(context, path)
    local direct = trim(path)
    if direct ~= "" then
        return direct
    end
    local request = context ~= nil and context.request or nil
    if request == nil then
        return ""
    end
    return trim(request.localPath or request.path or "")
end

local function split_package_id(identifier)
    local cleaned = trim(identifier)
    if cleaned == "" then
        return nil, nil
    end
    local name, output = cleaned:match("^([^:]+):(.+)$")
    if name ~= nil then
        return trim(name), trim(output)
    end
    return cleaned, nil
end

local function make_package_id(name, output)
    local cleaned_name = trim(name)
    local cleaned_output = trim(output)
    if cleaned_name == "" then
        return nil
    end
    if cleaned_output ~= "" and cleaned_output ~= "out" then
        return cleaned_name .. ":" .. cleaned_output
    end
    return cleaned_name
end

local function compare_versions(left, right)
    local a = trim(left)
    local b = trim(right)
    if a == b then
        return 0
    end
    if a < b then
        return -1
    end
    return 1
end

local function append_record_field(record, field, chunk)
    if record == nil or field == nil then
        return
    end

    if record[field] == nil or record[field] == "" then
        record[field] = chunk
    else
        record[field] = record[field] .. "\n" .. chunk
    end
end

local function parse_recutils(stdout)
    local records = {}
    local current = nil
    local last_field = nil

    local function flush()
        if current ~= nil and next(current) ~= nil then
            records[#records + 1] = current
        end
        current = nil
        last_field = nil
    end

    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned == "" then
            flush()
        else
            local field, value = line:match("^([%w%-]+):%s*(.*)$")
            if field ~= nil then
                if current == nil then
                    current = {}
                end
                field = lower(field)
                current[field] = trim(value)
                last_field = field
            elseif current ~= nil and last_field ~= nil then
                local continuation = line
                if continuation:sub(1, 2) == "+ " then
                    continuation = continuation:sub(3)
                end
                append_record_field(current, last_field, trim(continuation))
            end
        end
    end

    flush()
    return records
end

local function build_installed_item(name, version, output, store_path)
    local item = {
        name = trim(name),
        packageId = make_package_id(name, output),
        packageType = "package",
        version = trim(version),
        latestVersion = trim(version),
        installed = true,
        status = "installed",
        extraFields = {
            output = trim(output),
            storePath = trim(store_path),
        },
    }
    return item
end

local function enrich_item(item, record)
    if item == nil or record == nil then
        return item
    end

    local extra = shallow_copy(item.extraFields)
    if non_empty(record.outputs) ~= nil then
        extra.outputs = trim(record.outputs)
    end
    if non_empty(record.systems) ~= nil then
        extra.systems = trim(record.systems)
    end
    if non_empty(record.dependencies) ~= nil then
        extra.dependencies = trim(record.dependencies)
    end
    if non_empty(record.location) ~= nil then
        extra.location = trim(record.location)
    end
    item.extraFields = extra
    item.description = non_empty(record.synopsis) or non_empty(record.description) or item.description
    item.summary = non_empty(record.synopsis) or item.summary
    item.homepage = non_empty(record.homepage) or item.homepage
    item.license = non_empty(record.license) or item.license
    item.latestVersion = non_empty(record.version) or item.latestVersion or item.version
    if item.version == nil or item.version == "" then
        item.version = non_empty(record.version) or item.version
    end
    return item
end

local function build_remote_item(record)
    local name = non_empty(record and record.name)
    if name == nil then
        return nil
    end

    local item = {
        name = name,
        packageId = make_package_id(name, "out"),
        packageType = "package",
        version = non_empty(record.version),
        latestVersion = non_empty(record.version),
        installed = false,
        status = "available",
        summary = non_empty(record.synopsis),
        description = non_empty(record.synopsis) or non_empty(record.description),
        homepage = non_empty(record.homepage),
        license = non_empty(record.license),
        extraFields = {},
    }
    return enrich_item(item, record)
end

local function parse_list_output(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local fields = split_tsv(line)
        local name = non_empty(fields[1])
        if name ~= nil then
            items[#items + 1] = build_installed_item(name, fields[2], fields[3], fields[4])
        end
    end
    return items
end

local function list_command(selector)
    local parts = {
        "package",
        "--profile=" .. shell_quote(guix_profile()),
        "--list-installed",
    }
    if non_empty(selector) ~= nil then
        parts[#parts + 1] = shell_quote(selector)
    end
    return guix_command(parts)
end

local function show_command(name)
    return guix_command({
        "package",
        "--show=" .. shell_quote(name),
    })
end

local function search_command(prompt)
    return guix_command({
        "package",
        "--search",
        shell_quote(prompt),
    })
end

local function install_command(selector)
    return guix_command({
        "package",
        "--profile=" .. shell_quote(guix_profile()),
        "--install",
        shell_quote(selector),
    })
end

local function install_local_command(path)
    return guix_command({
        "package",
        "--profile=" .. shell_quote(guix_profile()),
        "--install-from-file",
        shell_quote(path),
    })
end

local function remove_command(selector)
    return guix_command({
        "package",
        "--profile=" .. shell_quote(guix_profile()),
        "--remove",
        shell_quote(selector),
    })
end

local function update_command(selector)
    local parts = {
        "package",
        "--profile=" .. shell_quote(guix_profile()),
        "--upgrade",
    }
    if non_empty(selector) ~= nil and selector ~= "." then
        parts[#parts + 1] = shell_quote(selector)
    end
    return guix_command(parts)
end

local function query_installed_items(context, selector)
    local result = exec_run(context, list_command(selector))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_list_output(result.stdout)
end

local function find_exact_record(records, selector)
    local cleaned = trim(selector)
    local wanted_name, _ = split_package_id(cleaned)
    local wanted_version = cleaned:match("@(.+)$")

    local fallback = nil
    for _, record in ipairs(records or {}) do
        if lower(record.name) == lower(wanted_name or cleaned) then
            if wanted_version ~= nil then
                if trim(record.version) == trim(wanted_version) then
                    return record
                end
            elseif fallback == nil then
                fallback = record
            end
        end
    end
    return fallback
end

local function highest_version_record(records, name)
    local best = nil
    for _, record in ipairs(records or {}) do
        if lower(record.name) == lower(name) then
            if best == nil or compare_versions(record.version, best.version) > 0 then
                best = record
            end
        end
    end
    return best
end

local function query_show_records(context, name)
    local result = exec_run(context, show_command(name))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_recutils(result.stdout)
end

local function sort_items(items)
    table.sort(items, function(left, right)
        local left_name = lower(left.name)
        local right_name = lower(right.name)
        if left_name == right_name then
            return lower(left.packageId) < lower(right.packageId)
        end
        return left_name < right_name
    end)
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
    return { "System", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end

    local installed = query_installed_items(nil, nil)
    if installed == nil then
        return packages
    end

    local installed_map = {}
    for _, item in ipairs(installed) do
        installed_map[lower(item.packageId)] = true
        installed_map[lower(item.name)] = true
    end

    local filtered = {}
    for _, package in ipairs(packages) do
        local selector = package_selector(package)
        local key = lower(selector)
        local action = package_action(package)
        local is_installed = installed_map[key] == true or installed_map[lower((split_package_id(selector)) or selector)] == true
        if action == "remove" then
            if is_installed then
                filtered[#filtered + 1] = package
            end
        elseif action == "update" then
            if is_installed then
                filtered[#filtered + 1] = package
            end
        elseif not is_installed then
            filtered[#filtered + 1] = package
        end
    end
    return filtered
end

function plugin.install(context, packages)
    local local_path = local_path_from_context(context, "")
    local requested = request_packages(context, packages)
    if #requested == 0 and local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end
    if #requested == 0 then
        return true
    end
    if not command_exists(REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end

    begin_step(context, "install guix packages")
    local installed = {}
    for _, package in ipairs(requested) do
        local selector = package_selector(package)
        if selector == "" then
            tx_failed(context, "guix package name missing")
            return false
        end
        local result = exec_run(context, install_command(selector))
        if result == nil or result.success ~= true then
            tx_failed(context, non_empty(result and result.stderr) or non_empty(result and result.stdout) or "guix install failed")
            return false
        end
        installed[#installed + 1] = {
            name = split_package_id(selector),
            packageId = selector,
            version = package_version(package) ~= "" and package_version(package) or nil,
            latestVersion = package_version(package) ~= "" and package_version(package) or nil,
            packageType = "package",
        }
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = local_path_from_context(context, path)
    if not command_exists(REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end

    begin_step(context, "install local guix package file")
    if local_path == "" or not path_exists_as_file(context, local_path) then
        tx_failed(context, "guix local install path missing or not a file")
        return false
    end

    local result = exec_run(context, install_local_command(local_path))
    if result == nil or result.success ~= true then
        tx_failed(context, non_empty(result and result.stderr) or non_empty(result and result.stdout) or "guix local install failed")
        return false
    end
    emit_event(context, "installed", { path = local_path, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = request_packages(context, packages)
    if #requested == 0 then
        return true
    end
    if not command_exists(REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end

    begin_step(context, "remove guix packages")
    for _, package in ipairs(requested) do
        local selector = package_selector(package)
        if selector == "" then
            tx_failed(context, "guix package name missing")
            return false
        end
        local result = exec_run(context, remove_command(selector))
        if result == nil or result.success ~= true then
            tx_failed(context, non_empty(result and result.stderr) or non_empty(result and result.stdout) or "guix remove failed")
            return false
        end
    end
    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = request_packages(context, packages)
    if #requested == 0 then
        return true
    end
    if not command_exists(REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end

    begin_step(context, "update guix packages")
    local updated = {}
    for _, package in ipairs(requested) do
        local selector = package_selector(package)
        if selector == "" then
            tx_failed(context, "guix package name missing")
            return false
        end
        local result = exec_run(context, update_command(selector))
        if result == nil or result.success ~= true then
            tx_failed(context, non_empty(result and result.stderr) or non_empty(result and result.stdout) or "guix update failed")
            return false
        end
        updated[#updated + 1] = {
            name = split_package_id(selector),
            packageId = selector,
            packageType = "package",
        }
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    if not command_exists(REQUIRED_BINARY) then
        log_warn(context, REQUIRED_BINARY .. " binary not available")
        emit_event(context, "listed", {})
        return {}
    end

    local items = query_installed_items(context, nil)
    if items == nil then
        log_warn(context, "guix list failed")
        items = {}
    end
    sort_items(items)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    if not command_exists(REQUIRED_BINARY) then
        log_warn(context, REQUIRED_BINARY .. " binary not available")
        emit_event(context, "outdated", {})
        return {}
    end

    local installed = query_installed_items(context, nil)
    if installed == nil then
        log_warn(context, "guix list failed before outdated lookup")
        emit_event(context, "outdated", {})
        return {}
    end

    local outdated = {}
    local seen = {}
    for _, item in ipairs(installed) do
        if not seen[item.name] then
            seen[item.name] = true
            local records = query_show_records(context, item.name)
            if records == nil then
                log_warn(context, "guix show failed for " .. item.name)
            else
                local highest = highest_version_record(records, item.name)
                if highest ~= nil and non_empty(highest.version) ~= nil and compare_versions(item.version, highest.version) < 0 then
                    local enriched = shallow_copy(item)
                    enriched.extraFields = shallow_copy(item.extraFields)
                    enrich_item(enriched, highest)
                    outdated[#outdated + 1] = enriched
                end
            end
        end
    end
    sort_items(outdated)
    emit_event(context, "outdated", outdated)
    return outdated
end

function plugin.search(context, prompt)
    local query = trim(prompt)
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end
    if not command_exists(REQUIRED_BINARY) then
        log_warn(context, REQUIRED_BINARY .. " binary not available")
        emit_event(context, "searched", {})
        return {}
    end

    local result = exec_run(context, search_command(query))
    if result == nil or result.success ~= true then
        log_warn(context, "guix search failed")
        emit_event(context, "searched", {})
        return {}
    end

    local items = {}
    for _, record in ipairs(parse_recutils(result.stdout)) do
        local item = build_remote_item(record)
        if item ~= nil then
            items[#items + 1] = item
        end
    end
    sort_items(items)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local selector = trim(name)
    if selector == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    if not command_exists(REQUIRED_BINARY) then
        log_warn(context, REQUIRED_BINARY .. " binary not available")
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local installed_items = query_installed_items(context, selector)
    local installed = installed_items ~= nil and installed_items[1] or nil

    local base_name = split_package_id(selector)
    local show_records = query_show_records(context, base_name or selector)
    local record = show_records ~= nil and find_exact_record(show_records, selector) or nil

    if installed ~= nil and record ~= nil then
        enrich_item(installed, record)
        emit_event(context, "informed", installed)
        return installed
    end
    if installed ~= nil then
        emit_event(context, "informed", installed)
        return installed
    end
    if record ~= nil then
        local item = build_remote_item(record)
        emit_event(context, "informed", item)
        return item
    end

    local empty = {}
    emit_event(context, "informed", empty)
    return empty
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end
    local selector = package_selector(package)
    if selector == "" then
        return nil
    end

    local info = plugin.info(context, selector)
    if type(info) == "table" and non_empty(info.name) ~= nil then
        return {
            name = info.name,
            packageId = info.packageId,
            packageType = info.packageType,
            version = non_empty(package.version) or non_empty(info.version) or non_empty(info.latestVersion),
            latestVersion = non_empty(info.latestVersion) or non_empty(info.version),
        }
    end

    local name = split_package_id(selector)
    return {
        name = name,
        packageId = selector,
        packageType = "package",
        version = non_empty(package.version),
        latestVersion = non_empty(package.version),
    }
end

function plugin.init()
    return command_exists(REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "guix", "gnu", "packages" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".cache/reqpack/guix" },
        },
        networkScopes = {},
        privilegeLevel = "user",
        purlType = "generic",
        versionComparatorProfile = "lexicographic",
    }
end

return plugin
