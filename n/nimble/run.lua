plugin = {}

local PLUGIN_NAME = "Nimble"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "nimble"
local READ_FLAGS = "--noColor"
local WRITE_FLAGS = "--accept --noColor"

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
    for line in tostring(value or ""):gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end
    return lines
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

local function command_exists(binary)
    return reqpack.exec.run("command -v " .. binary .. " >/dev/null 2>&1").success
end

local function path_exists_as_dir(context, path)
    return exec_run(context, "test -d " .. shell_quote(path)).success
end

local function path_exists_as_file(context, path)
    return exec_run(context, "test -f " .. shell_quote(path)).success
end

local function is_url_selector(value)
    local cleaned = trim(value)
    return cleaned:match("^[%a][%w+%-%.]*://") ~= nil or cleaned:match("^git@") ~= nil
end

local function is_local_selector(value)
    local cleaned = trim(value)
    return cleaned:match("^/") ~= nil or cleaned:match("^%./") ~= nil or cleaned:match("^%.%./") ~= nil or cleaned:match("^~/?") ~= nil
end

local function split_selector(value)
    local cleaned = trim(value)
    if cleaned == "" then
        return nil, nil
    end
    if is_url_selector(cleaned) or is_local_selector(cleaned) then
        return cleaned, nil
    end

    local name, version = cleaned:match("^([^@]+)@(.+)$")
    if name ~= nil then
        return trim(name), trim(version)
    end
    return cleaned, nil
end

local function package_selector(pkg)
    if pkg == nil then
        return ""
    end

    local name = trim(pkg.name)
    local version = trim(pkg.version)
    if name == "" then
        return ""
    end
    if version ~= "" and not is_url_selector(name) and not is_local_selector(name) and name:find("@", 1, true) == nil then
        return name .. "@" .. version
    end
    return name
end

local function package_action(pkg)
    return lower(pkg and pkg.action or "")
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

local function parse_installed_output(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            local name = cleaned:match("^(%S+)")
            if name ~= nil then
                local versions = {}
                for bracket in cleaned:gmatch("%b[]") do
                    local inside = trim(bracket:sub(2, -2))
                    for token in inside:gmatch("[^,%s]+") do
                        versions[#versions + 1] = token
                    end
                end

                if #versions == 0 then
                    items[#items + 1] = {
                        name = name,
                        packageId = name,
                        installed = true,
                        status = "installed",
                        packageType = "library",
                    }
                else
                    for _, version in ipairs(versions) do
                        items[#items + 1] = {
                            name = name,
                            packageId = make_package_id(name, version),
                            version = version,
                            installed = true,
                            status = "installed",
                            packageType = "library",
                        }
                    end
                end
            end
        end
    end

    table.sort(items, function(left, right)
        local left_name = lower(left.name)
        local right_name = lower(right.name)
        if left_name == right_name then
            return lower(left.version) < lower(right.version)
        end
        return left_name < right_name
    end)
    return items
end

local function build_installed_name_set(items)
    local installed = {}
    for _, item in ipairs(items or {}) do
        local name = lower(item.name)
        if name ~= "" then
            installed[name] = true
        end
    end
    return installed
end

local function query_installed_items(context)
    local result = exec_run(context, "nimble " .. READ_FLAGS .. " list -i")
    if result == nil or not result.success then
        return nil
    end
    return parse_installed_output(result.stdout)
end

local function query_installed_name_set()
    local result = reqpack.exec.run("nimble " .. READ_FLAGS .. " list -i")
    if result == nil or not result.success then
        return nil
    end
    return build_installed_name_set(parse_installed_output(result.stdout))
end

local function finalize_search_item(raw)
    if raw == nil or is_blank(raw.name) then
        return nil
    end

    local item = {
        name = trim(raw.name),
        packageId = trim(raw.name),
        summary = trim(raw.description),
        description = trim(raw.description),
        homepage = trim(raw.website),
        repository = trim(raw.url),
        license = trim(raw.license),
        installed = false,
        status = "available",
        packageType = "library",
    }

    local extra = {}
    if not is_blank(raw.tags) then
        extra.tags = trim(raw.tags)
    end
    if next(extra) ~= nil then
        item.extraFields = extra
    end

    return item
end

local function parse_search_output(stdout)
    local items = {}
    local current = nil

    local function flush_current()
        local item = finalize_search_item(current)
        if item ~= nil then
            items[#items + 1] = item
        end
    end

    for _, line in ipairs(split_lines(stdout)) do
        local header = line:match("^([^%s][^:]*)%:%s*$")
        if header ~= nil then
            flush_current()
            current = { name = trim(header) }
        elseif current ~= nil then
            local key, value = line:match("^([%a][%w%-]*)%:%s*(.-)%s*$")
            if key ~= nil then
                current[lower(key)] = trim(value)
            end
        end
    end

    flush_current()
    return items
end

local function refresh_index(context)
    local result = exec_run(context, "nimble " .. WRITE_FLAGS .. " refresh")
    return result ~= nil and result.success
end

local function query_search_items(context, prompt)
    local result = exec_run(context, "nimble " .. READ_FLAGS .. " search " .. shell_quote(prompt))
    if result == nil or not result.success then
        return nil
    end
    return parse_search_output(result.stdout)
end

local function query_install_paths(context, name)
    local result = exec_run(context, "nimble " .. READ_FLAGS .. " path " .. shell_quote(name))
    if result == nil or not result.success then
        return nil
    end

    local paths = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            paths[#paths + 1] = cleaned
        end
    end
    return paths
end

local function find_installed_item(items, name, version)
    local wanted_name = lower(name)
    local wanted_version = lower(version)
    for _, item in ipairs(items or {}) do
        if lower(item.name) == wanted_name then
            if wanted_version == "" or lower(item.version) == wanted_version then
                return item
            end
        end
    end
    return nil
end

local function find_exact_search_item(items, name)
    local wanted = lower(name)
    for _, item in ipairs(items or {}) do
        if lower(item.name) == wanted then
            return item
        end
    end
    return nil
end

local function clone_table(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
end

local function info_for_installed(context, name, version)
    local installed = query_installed_items(context)
    if installed == nil then
        return nil
    end

    local item = find_installed_item(installed, name, version)
    if item == nil then
        return nil
    end

    local resolved = clone_table(item)
    local paths = query_install_paths(context, name)
    if paths ~= nil and #paths > 0 then
        resolved.extraFields = resolved.extraFields or {}
        resolved.extraFields.installPath = paths[1]
        resolved.extraFields.installPaths = paths
    end
    return resolved
end

local function info_for_remote(context, name)
    if not refresh_index(context) then
        log_warn(context, "nimble refresh failed before remote info lookup")
    end

    local items = query_search_items(context, name)
    if items == nil then
        return nil
    end
    return find_exact_search_item(items, name)
end

local function run_package_commands(context, step_label, packages, builder, failure_message, event_name)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    begin_step(context, step_label)
    for _, package in ipairs(requested) do
        local selector = package_selector(package)
        if selector == "" then
            tx_failed(context, failure_message)
            return false
        end

        local result = exec_run(context, builder(selector))
        if result == nil or not result.success then
            tx_failed(context, failure_message)
            return false
        end
    end

    emit_event(context, event_name, requested)
    tx_success(context)
    return true
end

plugin.fileExtensions = { ".nimble" }

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
    return { "Development", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end

    local installed = query_installed_name_set()
    if installed == nil then
        return packages
    end

    local filtered = {}
    for _, package in ipairs(packages) do
        local selector = package_selector(package)
        local name = split_selector(selector)
        local installed_name = lower(name)
        local action = package_action(package)
        local is_installed = installed_name ~= "" and installed[installed_name] == true
        local explicit_selector = selector:find("@", 1, true) ~= nil or is_url_selector(selector) or is_local_selector(selector)

        if action == "remove" then
            if is_installed then
                filtered[#filtered + 1] = package
            end
        elseif action == "update" then
            if is_installed then
                filtered[#filtered + 1] = package
            end
        elseif not is_installed or explicit_selector then
            filtered[#filtered + 1] = package
        end
    end

    return filtered
end

function plugin.install(context, packages)
    return run_package_commands(
        context,
        "install nimble packages",
        packages,
        function(selector)
            return "nimble " .. WRITE_FLAGS .. " install " .. shell_quote(selector)
        end,
        "nimble install failed",
        "installed"
    )
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    begin_step(context, "install local nimble package")

    if local_path == "" then
        tx_failed(context, "unsupported local Nimble target; expected directory or .nimble file")
        return false
    end

    local is_dir = path_exists_as_dir(context, local_path)
    local is_file = path_exists_as_file(context, local_path)
    if not is_dir then
        if not is_file or not lower(local_path):match("%.nimble$") then
            tx_failed(context, "unsupported local Nimble target; expected directory or .nimble file")
            return false
        end
    end

    local result = exec_run(context, "nimble " .. WRITE_FLAGS .. " install " .. shell_quote(local_path))
    if result == nil or not result.success then
        tx_failed(context, "nimble local install failed")
        return false
    end

    emit_event(context, "installed", { path = local_path, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    return run_package_commands(
        context,
        "remove nimble packages",
        packages,
        function(selector)
            return "nimble " .. WRITE_FLAGS .. " uninstall " .. shell_quote(selector)
        end,
        "nimble uninstall failed",
        "deleted"
    )
end

function plugin.update(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    return run_package_commands(
        context,
        "update nimble packages",
        requested,
        function(selector)
            return "nimble " .. WRITE_FLAGS .. " install " .. shell_quote(selector)
        end,
        "nimble update failed",
        "updated"
    )
end

function plugin.list(context)
    local items = query_installed_items(context)
    if items == nil then
        log_warn(context, "nimble list -i failed")
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local empty = {}
    emit_event(context, "outdated", empty)
    return empty
end

function plugin.search(context, prompt)
    local query = trim(prompt)
    if query == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    if not refresh_index(context) then
        log_warn(context, "nimble refresh failed before search")
    end

    local items = query_search_items(context, query)
    if items == nil then
        log_warn(context, "nimble search failed")
        items = {}
    end
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

    local base_name, version = split_selector(selector)
    local installed_item = info_for_installed(context, base_name or selector, version)
    if installed_item ~= nil then
        emit_event(context, "informed", installed_item)
        return installed_item
    end

    local remote_item = info_for_remote(context, base_name or selector)
    if remote_item == nil then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    emit_event(context, "informed", remote_item)
    return remote_item
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
        ecosystemScopes = { "nim" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".nimble" },
        },
        networkScopes = { "*" },
        privilegeLevel = "user",
        purlType = "generic",
    }
end

return plugin
