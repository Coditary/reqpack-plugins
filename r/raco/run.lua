plugin = {}

local PLUGIN_ID = "raco"
local PLUGIN_NAME = "Racket raco pkg"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "raco"
local MAX_SEARCH_RESULTS = 25

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return tostring(value or ""):lower()
end

local function is_blank(value)
    return trim(value) == ""
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil then
            if type(value) == "string" then
                local text = trim(value)
                if text ~= "" then
                    return text
                end
            else
                return value
            end
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

local function append_all(target, items)
    for _, item in ipairs(items or {}) do
        target[#target + 1] = item
    end
end

local function split_lines(value)
    local lines = {}
    for line in tostring(value or ""):gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end
    return lines
end

local function split_columns(line)
    local fields = {}
    local text = tostring(line or "")
    local start_index = 1

    while start_index <= #text do
        local split_start, split_end = text:find("%s%s+", start_index)
        if split_start == nil then
            local tail = trim(text:sub(start_index))
            if tail ~= "" then
                fields[#fields + 1] = tail
            end
            break
        end

        local field = trim(text:sub(start_index, split_start - 1))
        if field ~= "" then
            fields[#fields + 1] = field
        end
        start_index = split_end + 1
    end

    if #fields == 0 then
        for field in text:gmatch("%S+") do
            fields[#fields + 1] = trim(field)
        end
    end

    return fields
end

local function starts_with(value, prefix)
    local text = tostring(value or "")
    local expected = tostring(prefix or "")
    return text:sub(1, #expected) == expected
end

local function ends_with(value, suffix)
    local text = tostring(value or "")
    local expected = tostring(suffix or "")
    return expected == "" or text:sub(-#expected) == expected
end

local function path_exists(path)
    local handle = io.open(tostring(path or ""), "rb")
    if handle ~= nil then
        handle:close()
        return true
    end

    local dir_handle = io.open(tostring(path or "") .. "/.", "rb")
    if dir_handle ~= nil then
        dir_handle:close()
        return true
    end

    return false
end

local function is_directory_path(path)
    local handle = io.open(tostring(path or "") .. "/.", "rb")
    if handle ~= nil then
        handle:close()
        return true
    end
    return false
end

local function command_exists(binary)
    return reqpack.exec.run("command -v " .. shell_quote(binary) .. " >/dev/null 2>&1").success
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

local function path_is_directory(context, path)
    local result = exec_run(context, "test -d " .. shell_quote(path))
    if result ~= nil and result.success then
        return true
    end
    return is_directory_path(path)
end

local function build_command(parts)
    local command = {}
    for _, part in ipairs(parts or {}) do
        command[#command + 1] = part
    end
    return table.concat(command, " ")
end

local function scoped_command(parts)
    return build_command(parts)
end

local function package_name(pkg)
    return trim(pkg and pkg.name)
end

local function package_source_path(pkg)
    return trim(first_nonempty(pkg and pkg.sourcePath, pkg and pkg.localPath))
end

local function package_action(pkg)
    return lower(pkg and pkg.action)
end

local function merge_extra_fields(left, right)
    local merged = shallow_copy(type(left) == "table" and left or {})
    for key, value in pairs(type(right) == "table" and right or {}) do
        merged[key] = value
    end
    return merged
end

local function normalize_source_to_homepage(source)
    local text = trim(source)
    if starts_with(text, "http://") or starts_with(text, "https://") then
        return text
    end
    return nil
end

local function map_scope(header)
    local text = trim(header)
    if text == "" then
        return "user"
    end
    if lower(text):find("installation%-wide", 1, false) ~= nil then
        return "installation"
    end
    return "user"
end

local function make_package_id(name)
    local cleaned = trim(name)
    if cleaned == "" then
        return nil
    end
    return PLUGIN_ID .. "/" .. cleaned
end

local function build_status(installed, outdated)
    if outdated then
        return "outdated"
    end
    if installed then
        return "installed"
    end
    return "available"
end

local function parse_show_output(stdout)
    local items = {}
    local scope_label = "user"

    for _, raw_line in ipairs(split_lines(stdout)) do
        local line = trim(raw_line)
        if line ~= "" then
            if ends_with(line, ":") and not starts_with(line, "Package") then
                scope_label = line:sub(1, -2)
            elseif line ~= "[none]" and not starts_with(line, "Package") and not starts_with(line, "Checksum") and not starts_with(line, "[") then
                local fields = split_columns(raw_line)
                if #fields >= 3 then
                    local raw_name = trim(fields[1])
                    local auto_installed = ends_with(raw_name, "*")
                    local name = auto_installed and raw_name:sub(1, -2) or raw_name
                    local checksum = trim(fields[2])
                    local source = trim(fields[3])
                    local directory = trim(fields[4])

                    items[#items + 1] = {
                        name = name,
                        packageId = make_package_id(name),
                        version = checksum,
                        latestVersion = checksum,
                        installed = true,
                        status = "installed",
                        summary = source,
                        description = source,
                        homepage = normalize_source_to_homepage(source),
                        sourceUrl = normalize_source_to_homepage(source),
                        sourcePath = directory ~= "" and directory or nil,
                        packageType = "package",
                        type = "package",
                        extraFields = {
                            scope = map_scope(scope_label),
                            autoInstalled = auto_installed,
                            checksum = checksum,
                            source = source,
                            directory = directory ~= "" and directory or nil,
                        },
                    }
                end
            end
        end
    end

    return items
end

local function parse_dependency_line(line)
    local text = trim(line)
    if text == "" then
        return nil
    end
    local name = text:match("^([^%s]+)")
    if name == nil then
        return nil
    end
    return name
end

local function finalize_catalog_entry(entry)
    if entry == nil or entry.name == nil then
        return nil
    end

    local checksum = first_nonempty(entry.checksum)
    local dependencies = {}
    local seen = {}
    for _, dependency in ipairs(entry.dependencies or {}) do
        if dependency ~= nil and not seen[dependency] then
            seen[dependency] = true
            dependencies[#dependencies + 1] = dependency
        end
    end

    local modules = {}
    for _, module_name in ipairs(entry.modules or {}) do
        modules[#modules + 1] = module_name
    end

    local source_url = first_nonempty(entry.source)
    return {
        name = entry.name,
        packageId = make_package_id(entry.name),
        version = checksum,
        latestVersion = checksum,
        installed = false,
        status = "available",
        summary = first_nonempty(entry.description, source_url, entry.name),
        description = first_nonempty(entry.description, source_url),
        homepage = normalize_source_to_homepage(source_url),
        sourceUrl = source_url,
        dependencies = dependencies,
        packageType = "package",
        type = "package",
        extraFields = {
            checksum = checksum,
            author = first_nonempty(entry.author),
            tags = entry.tags,
            modules = modules,
            ring = first_nonempty(entry.ring),
            source = source_url,
        },
    }
end

local function parse_catalog_show_output(stdout)
    local items = {}
    local current = nil
    local mode = nil

    local function flush_current()
        local item = finalize_catalog_entry(current)
        if item ~= nil then
            items[#items + 1] = item
        end
    end

    for _, raw_line in ipairs(split_lines(stdout)) do
        local line = trim(raw_line)
        if line == "" then
            mode = nil
        elseif starts_with(line, "Package name:") then
            flush_current()
            current = {
                name = trim(line:sub(#"Package name:" + 1)),
                dependencies = {},
                modules = {},
                tags = {},
            }
            mode = nil
        elseif current ~= nil then
            if starts_with(line, "Author:") then
                current.author = trim(line:sub(#"Author:" + 1))
                mode = nil
            elseif starts_with(line, "Source:") then
                current.source = trim(line:sub(#"Source:" + 1))
                mode = nil
            elseif starts_with(line, "Checksum:") then
                current.checksum = trim(line:sub(#"Checksum:" + 1))
                mode = nil
            elseif starts_with(line, "Tags:") then
                current.tags = {}
                for tag in trim(line:sub(#"Tags:" + 1)):gmatch("[^,]+") do
                    current.tags[#current.tags + 1] = trim(tag)
                end
                mode = nil
            elseif starts_with(line, "Description:") then
                current.description = trim(line:sub(#"Description:" + 1))
                mode = nil
            elseif starts_with(line, "Ring:") then
                current.ring = trim(line:sub(#"Ring:" + 1))
                mode = nil
            elseif starts_with(line, "Dependencies:") then
                mode = "dependencies"
            elseif starts_with(line, "Modules:") then
                mode = "modules"
                local rest = trim(line:sub(#"Modules:" + 1))
                for module_name in rest:gmatch("'[^%s]+") do
                    current.modules[#current.modules + 1] = module_name
                end
            elseif mode == "dependencies" then
                local dependency = parse_dependency_line(line)
                if dependency ~= nil then
                    current.dependencies[#current.dependencies + 1] = dependency
                end
            elseif mode == "modules" then
                for module_name in line:gmatch("'[^%s]+") do
                    current.modules[#current.modules + 1] = module_name
                end
            end
        end
    end

    flush_current()
    return items
end

local function parse_only_names(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local name = trim(line)
        if name ~= "" then
            items[#items + 1] = name
        end
    end
    return items
end

local function find_installed_package(context, name)
    local result = exec_run(context, scoped_command({
        "raco", "pkg", "show", "--all", "--long", "-d", "--scope", "user", shell_quote(name)
    }))
    if result == nil or not result.success then
        return nil
    end

    local items = parse_show_output(result.stdout)
    for _, item in ipairs(items) do
        if item.name == name then
            return item
        end
    end
    return nil
end

local function find_catalog_package(context, name)
    local result = exec_run(context, scoped_command({ "raco", "pkg", "catalog-show", shell_quote(name) }))
    if result == nil or not result.success then
        return nil
    end

    local items = parse_catalog_show_output(result.stdout)
    for _, item in ipairs(items) do
        if item.name == name then
            return item
        end
    end
    return nil
end

local function merge_package_info(installed, remote)
    if installed == nil then
        return remote
    end
    if remote == nil then
        return installed
    end

    local merged = shallow_copy(installed)
    merged.summary = first_nonempty(installed.summary, remote.summary)
    merged.description = first_nonempty(installed.description, remote.description)
    merged.homepage = first_nonempty(remote.homepage, installed.homepage)
    merged.sourceUrl = first_nonempty(remote.sourceUrl, installed.sourceUrl)
    merged.dependencies = remote.dependencies or installed.dependencies
    merged.latestVersion = first_nonempty(remote.latestVersion, installed.latestVersion, installed.version)
    merged.extraFields = merge_extra_fields(installed.extraFields, remote.extraFields)

    if merged.version ~= nil and merged.latestVersion ~= nil and merged.version ~= merged.latestVersion then
        merged.status = "outdated"
    end

    return merged
end

local function local_install_command(context, path)
    local quoted = shell_quote(path)
    if path_is_directory(context, path) then
        return scoped_command({ "raco", "pkg", "install", "--batch", "--scope", "user", "--deps", "search-auto", "--link", quoted })
    end
    return scoped_command({ "raco", "pkg", "install", "--batch", "--scope", "user", "--deps", "search-auto", quoted })
end

local function build_install_targets(packages)
    local named = {}
    local locals = {}
    for _, pkg in ipairs(packages or {}) do
        local source_path = package_source_path(pkg)
        if source_path ~= "" then
            locals[#locals + 1] = source_path
        else
            local name = package_name(pkg)
            if name ~= "" then
                named[#named + 1] = name
            end
        end
    end
    return named, locals
end

local function unique_names(values)
    local items = {}
    local seen = {}
    for _, value in ipairs(values or {}) do
        local text = trim(value)
        if text ~= "" and not seen[text] then
            seen[text] = true
            items[#items + 1] = text
        end
    end
    return items
end

local function installed_index(context)
    local result = exec_run(context, "raco pkg show --all --long -d --scope user")
    if result == nil or not result.success then
        return {}, nil, result
    end
    local items = parse_show_output(result.stdout)
    local by_name = {}
    for _, item in ipairs(items) do
        by_name[item.name] = item
    end
    return items, by_name, result
end

local function dry_run_indicates_outdated(result)
    local text = lower((result and result.stdout or "") .. "\n" .. (result and result.stderr or ""))
    if text:find("up%-to%-date", 1, false) ~= nil then
        return false
    end
    if text:find("no updates", 1, true) ~= nil then
        return false
    end
    if text:find("updating", 1, true) ~= nil then
        return true
    end
    if text:find("would", 1, true) ~= nil then
        return true
    end
    if text:find("install", 1, true) ~= nil then
        return true
    end
    return result ~= nil and result.success == true and trim(result.stdout or "") ~= ""
end

plugin.fileExtensions = { ".zip", ".tar", ".tgz", ".tar.gz", ".plt" }

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
    return { "Package Manager", "Racket", "Wrapper" }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end

    if not command_exists(REQUIRED_BINARY) then
        return packages
    end

    local _, by_name = installed_index(nil)
    local filtered = {}
    for _, pkg in ipairs(packages) do
        local source_path = package_source_path(pkg)
        local name = package_name(pkg)
        local installed = by_name and by_name[name] or nil
        local action = package_action(pkg)

        if source_path ~= "" then
            filtered[#filtered + 1] = pkg
        elseif action == "remove" then
            if installed ~= nil then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "update" then
            if installed ~= nil then
                filtered[#filtered + 1] = pkg
            end
        elseif installed == nil then
            filtered[#filtered + 1] = pkg
        end
    end

    return filtered
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    begin_step(context, "install raco packages")
    if not command_exists(REQUIRED_BINARY) then
        tx_failed(context, "raco not installed")
        return false
    end

    local named, locals = build_install_targets(requested)
    named = unique_names(named)

    if #named > 0 then
        local command_parts = { "raco", "pkg", "install", "--batch", "--scope", "user", "--deps", "search-auto" }
        for _, name in ipairs(named) do
            command_parts[#command_parts + 1] = shell_quote(name)
        end
        local result = exec_run(context, build_command(command_parts))
        if result == nil or not result.success then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "raco install failed"))
            return false
        end
    end

    for _, path in ipairs(locals) do
        local result = exec_run(context, local_install_command(context, path))
        if result == nil or not result.success then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "raco local install failed"))
            return false
        end
    end

    emit_event(context, "installed", requested)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local cleaned = trim(path)
    begin_step(context, "install local raco package")
    if cleaned == "" then
        tx_failed(context, "local path required")
        return false
    end

    if not command_exists(REQUIRED_BINARY) then
        tx_failed(context, "raco not installed")
        return false
    end

    local result = exec_run(context, local_install_command(context, cleaned))
    if result == nil or not result.success then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "raco local install failed"))
        return false
    end

    emit_event(context, "installed", { path = cleaned, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    begin_step(context, "remove raco packages")
    if not command_exists(REQUIRED_BINARY) then
        tx_failed(context, "raco not installed")
        return false
    end

    local names = {}
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        if name ~= "" then
            names[#names + 1] = shell_quote(name)
        end
    end
    local result = exec_run(context, build_command({ "raco", "pkg", "remove", "--batch", "--scope", "user", table.concat(names, " ") }))
    if result == nil or not result.success then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "raco remove failed"))
        return false
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    begin_step(context, "update raco packages")
    if not command_exists(REQUIRED_BINARY) then
        tx_failed(context, "raco not installed")
        return false
    end

    local command_parts = { "raco", "pkg", "update", "--batch", "--scope", "user", "--deps", "search-auto" }
    if #requested == 0 then
        command_parts[#command_parts + 1] = "--all"
    else
        for _, pkg in ipairs(requested) do
            local name = package_name(pkg)
            if name ~= "" then
                command_parts[#command_parts + 1] = shell_quote(name)
            end
        end
    end

    local result = exec_run(context, build_command(command_parts))
    if result == nil or not result.success then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "raco update failed"))
        return false
    end

    emit_event(context, "updated", requested)
    tx_success(context)
    return true
end

function plugin.list(context)
    if not command_exists(REQUIRED_BINARY) then
        emit_event(context, "unavailable", { reason = "raco-not-installed" })
        return {}
    end

    local items = installed_index(context)
    local results = items or {}
    emit_event(context, "listed", results)
    return results
end

function plugin.outdated(context)
    if not command_exists(REQUIRED_BINARY) then
        emit_event(context, "unavailable", { reason = "raco-not-installed" })
        return {}
    end

    local items = select(1, installed_index(context))
    local outdated = {}

    for _, item in ipairs(items or {}) do
        local result = exec_run(context, build_command({
            "raco", "pkg", "update", "--batch", "--scope", "user", "--deps", "search-auto", "--dry-run", shell_quote(item.name)
        }))
        if result ~= nil and result.success and dry_run_indicates_outdated(result) then
            local remote = find_catalog_package(context, item.name)
            local merged = merge_package_info(item, remote)
            merged.status = build_status(true, true)
            outdated[#outdated + 1] = merged
        end
    end

    emit_event(context, "outdated", outdated)
    return outdated
end

function plugin.search(context, prompt)
    if is_blank(prompt) then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    if not command_exists(REQUIRED_BINARY) then
        emit_event(context, "unavailable", { reason = "raco-not-installed" })
        return {}
    end

    local names_result = exec_run(context, "raco pkg catalog-show --all --only-names")
    if names_result == nil or not names_result.success then
        log_warn(context, "raco catalog name listing failed")
        emit_event(context, "searched", {})
        return {}
    end

    local prompt_text = lower(trim(prompt))
    local matched_names = {}
    for _, name in ipairs(parse_only_names(names_result.stdout)) do
        if lower(name):find(prompt_text, 1, true) ~= nil then
            matched_names[#matched_names + 1] = name
            if #matched_names >= MAX_SEARCH_RESULTS then
                break
            end
        end
    end

    local items = {}
    for _, name in ipairs(matched_names) do
        local item = find_catalog_package(context, name)
        if item ~= nil then
            local installed = find_installed_package(context, name)
            items[#items + 1] = merge_package_info(installed, item)
        end
    end

    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local package_name_value = trim(name)
    if package_name_value == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    if not command_exists(REQUIRED_BINARY) then
        emit_event(context, "unavailable", { reason = "raco-not-installed" })
        return {}
    end

    local installed = find_installed_package(context, package_name_value)
    local remote = find_catalog_package(context, package_name_value)
    local merged = merge_package_info(installed, remote)
    if merged == nil then
        emit_event(context, "informed", {})
        return {}
    end

    emit_event(context, "informed", merged)
    return merged
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end

    local source_path = package_source_path(package)
    if source_path ~= "" then
        return {
            action = package.action,
            system = package.system,
            name = first_nonempty(package.name, source_path),
            version = first_nonempty(package.version, source_path),
            sourcePath = source_path,
        }
    end

    local name = package_name(package)
    if name == "" or not command_exists(REQUIRED_BINARY) then
        return nil
    end

    local installed = find_installed_package(context, name)
    local remote = find_catalog_package(context, name)
    local merged = merge_package_info(installed, remote)
    if merged == nil then
        return nil
    end

    return {
        action = package.action,
        system = package.system,
        name = merged.name,
        version = first_nonempty(merged.version, merged.latestVersion),
        latestVersion = merged.latestVersion,
        extraFields = merged.extraFields,
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
        capabilities = { "exec", "network" },
        ecosystemScopes = { "racket", "raco" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".cache/racket" },
            { kind = "user-home-subpath", value = ".local/share/racket" },
            { kind = "user-home-subpath", value = "Library/Caches/Racket" },
            { kind = "user-home-subpath", value = "Library/Racket" },
        },
        privilegeLevel = "user",
        purlType = "generic",
        versionComparatorProfile = "lexicographic",
    }
end

return plugin
