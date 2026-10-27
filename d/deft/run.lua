plugin = {}

local PLUGIN_ID = "deft"
local PLUGIN_NAME = "Deft"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "deft"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
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

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        return trim(os.getenv(name))
    end
    return ""
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(select(index, ...))
        if part ~= "" then
            if #parts == 0 then
                parts[#parts + 1] = part:gsub("/+$", "")
            else
                parts[#parts + 1] = part:gsub("^/+", ""):gsub("/+$", "")
            end
        end
    end
    return table.concat(parts, "/")
end

local function normalize_run_result(first, second, third, fourth, fifth)
    if type(first) == "table" then
        if first.stdout == nil then
            first.stdout = ""
        end
        if first.stderr == nil then
            first.stderr = ""
        end
        if first.success == nil and first.exitCode ~= nil then
            first.success = first.exitCode == 0
        end
        return first
    end

    local result = {}

    local function apply(value)
        local value_type = type(value)
        if value_type == "table" then
            for key, item in pairs(value or {}) do
                result[key] = item
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

    apply(first)
    apply(second)
    apply(third)
    apply(fourth)
    apply(fifth)
    if result.stdout == nil then
        result.stdout = ""
    end
    if result.stderr == nil then
        result.stderr = ""
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

local function is_success(result)
    if result == nil then
        return false
    end
    if result.success ~= nil then
        return result.success == true
    end
    if result.exitCode ~= nil then
        return tonumber(result.exitCode) == 0
    end
    return true
end

local function command_exists(context, binary)
    return is_success(exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function failure(context, message, payload)
    tx_failed(context, message)
    if payload ~= nil then
        emit_event(context, "unavailable", payload)
    end
    return false
end

local function split_lines(value)
    local lines = {}
    local text = tostring(value or ""):gsub("\r\n", "\n")
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then
            lines[#lines + 1] = line
        end
    end
    return lines
end

local function split_words(value)
    local words = {}
    for word in tostring(value or ""):gmatch("%S+") do
        words[#words + 1] = word
    end
    return words
end

local function package_name(package)
    local value = trim(read_field(package, "name") or read_field(package, "packageId") or package)
    if value == "" then
        return nil
    end
    return (value:match("^([^@]+)")) or value
end

local function package_version(package)
    local explicit = trim(read_field(package, "version"))
    if explicit ~= "" then
        return explicit
    end
    local name = trim(read_field(package, "name") or read_field(package, "packageId") or package)
    local version = name:match("^[^@]+@(.+)$")
    if version ~= nil and trim(version) ~= "" then
        return trim(version)
    end
    return nil
end

local function package_request(package)
    local name = trim(read_field(package, "name") or read_field(package, "packageId") or package)
    if name ~= "" then
        return name
    end
    return nil
end

local function request_local_path(context, path)
    local cleaned = trim(path or read_field(context, "localPath") or read_field(context, "path"))
    if cleaned == "" then
        return nil
    end
    return cleaned
end

local function nearest_workspace_root(context)
    local root = trim(read_field(context, "workspaceRoot") or read_field(context, "cwd") or read_field(context, "workingDirectory") or "")
    if root ~= "" then
        return root
    end
    return ""
end

local function global_packages_root()
    local dylan = getenv("DYLAN")
    if dylan ~= "" then
        return join_path(dylan, "_packages")
    end
    local xdg_state_home = getenv("XDG_STATE_HOME")
    if xdg_state_home ~= "" then
        return join_path(xdg_state_home, "dylan", "_packages")
    end
    local home = getenv("HOME")
    if home ~= "" then
        return join_path(home, ".local", "state", "dylan", "_packages")
    end
    return ".local/state/dylan/_packages"
end

local function workspace_packages_root(context)
    local root = nearest_workspace_root(context)
    if root == "" then
        return ""
    end
    return join_path(root, "_packages")
end

local function package_roots(context)
    local roots = {}
    local seen = {}
    local workspace_root = workspace_packages_root(context)
    if workspace_root ~= "" then
        roots[#roots + 1] = { path = workspace_root, scope = "workspace" }
        seen[workspace_root] = true
    end
    local global_root = global_packages_root()
    if global_root ~= "" and not seen[global_root] then
        roots[#roots + 1] = { path = global_root, scope = "global" }
    end
    return roots
end

local function parse_json_string(raw, start_index)
    local index = start_index + 1
    local out = {}
    while index <= #raw do
        local current = raw:sub(index, index)
        if current == '"' then
            return table.concat(out), index + 1
        end
        if current == "\\" then
            local escape = raw:sub(index + 1, index + 1)
            if escape == '"' or escape == "\\" or escape == "/" then
                out[#out + 1] = escape
                index = index + 2
            elseif escape == "n" then
                out[#out + 1] = "\n"
                index = index + 2
            elseif escape == "r" then
                out[#out + 1] = "\r"
                index = index + 2
            elseif escape == "t" then
                out[#out + 1] = "\t"
                index = index + 2
            else
                out[#out + 1] = escape
                index = index + 2
            end
        else
            out[#out + 1] = current
            index = index + 1
        end
    end
    return nil, start_index
end

local function parse_string_array(raw, key)
    local result = {}
    local pattern = '"' .. key .. '"%s*:%s*%['
    local start_index = raw:find(pattern)
    if start_index == nil then
        return result
    end
    local index = raw:find("[", start_index, true)
    if index == nil then
        return result
    end
    index = index + 1
    while index <= #raw do
        local current = raw:sub(index, index)
        if current == "]" then
            return result
        end
        if current == '"' then
            local value
            value, index = parse_json_string(raw, index)
            if value ~= nil then
                result[#result + 1] = value
            else
                return result
            end
        else
            index = index + 1
        end
    end
    return result
end

local function parse_metadata_json(raw)
    local metadata = {}
    for _, key in ipairs({ "name", "version", "description", "url", "license", "category", "contact" }) do
        local pattern = '"' .. key .. '"%s*:%s*"'
        local start_index = raw:find(pattern)
        if start_index ~= nil then
            local quote_index = raw:find('"', start_index + #key + 2, true)
            if quote_index ~= nil then
                local value
                value = select(1, parse_json_string(raw, quote_index))
                metadata[key] = value
            end
        end
    end
    metadata.keywords = parse_string_array(raw, "keywords")
    return metadata
end

local function file_exists(context, path)
    return is_success(exec_run(context, "test -f " .. shell_quote(path)))
end

local function dir_exists(context, path)
    return is_success(exec_run(context, "test -d " .. shell_quote(path)))
end

local function read_file(context, path)
    return exec_run(context, "cat " .. shell_quote(path))
end

local function list_dir(context, path)
    return exec_run(context, "ls -1A " .. shell_quote(path))
end

local function compare_versions(left, right)
    local function split(version)
        local parts = {}
        for token in tostring(version or ""):gmatch("[^%.%-]+") do
            local number = tonumber(token)
            parts[#parts + 1] = number or token
        end
        return parts
    end
    local a = split(left)
    local b = split(right)
    local count = math.max(#a, #b)
    for index = 1, count do
        local x = a[index]
        local y = b[index]
        if x == nil and y ~= nil then
            return -1
        end
        if x ~= nil and y == nil then
            return 1
        end
        if x ~= y then
            if type(x) == "number" and type(y) == "number" then
                return x < y and -1 or 1
            end
            return tostring(x) < tostring(y) and -1 or 1
        end
    end
    return 0
end

local function metadata_file_for(root, name, version)
    return join_path(root, name, version, "src", "dylan-package.json")
end

local function enrich_item_from_metadata(item, metadata, path, scope)
    if metadata == nil then
        return item
    end
    item.name = trim(metadata.name or item.name)
    item.packageId = item.name
    item.summary = trim(item.summary or metadata.description or "")
    item.description = trim(metadata.description or item.description or "")
    item.version = trim(item.version or metadata.version or "")
    item.extraFields = item.extraFields or {}
    if trim(metadata.url or "") ~= "" then
        item.extraFields.sourceUrl = trim(metadata.url)
    end
    if trim(metadata.license or "") ~= "" then
        item.extraFields.license = trim(metadata.license)
    end
    if trim(metadata.category or "") ~= "" then
        item.extraFields.category = trim(metadata.category)
    end
    if type(metadata.keywords) == "table" and #metadata.keywords > 0 then
        item.extraFields.keywords = metadata.keywords
    end
    item.extraFields.packagePath = path
    item.extraFields.installScope = scope
    return item
end

local function scan_installed(context)
    local items = {}
    local by_name = {}
    for _, root in ipairs(package_roots(context)) do
        if dir_exists(context, root.path) then
            local names_result = list_dir(context, root.path)
            if is_success(names_result) then
                for _, name in ipairs(split_lines(names_result.stdout)) do
                    local package_root = join_path(root.path, name)
                    local versions_result = list_dir(context, package_root)
                    if is_success(versions_result) then
                        local installed_versions = {}
                        local selected = nil
                        for _, version in ipairs(split_lines(versions_result.stdout)) do
                            local metadata_path = metadata_file_for(root.path, name, version)
                            local metadata = nil
                            if file_exists(context, metadata_path) then
                                local metadata_result = read_file(context, metadata_path)
                                if is_success(metadata_result) then
                                    metadata = parse_metadata_json(metadata_result.stdout)
                                end
                            end
                            installed_versions[#installed_versions + 1] = version
                            local candidate = {
                                name = name,
                                packageId = name,
                                version = version,
                                installed = true,
                                summary = metadata and trim(metadata.description or "") or "",
                                description = metadata and trim(metadata.description or "") or "",
                                extraFields = {
                                    packagePath = join_path(root.path, name, version, "src"),
                                    installScope = root.scope,
                                    installedVersions = installed_versions,
                                },
                            }
                            enrich_item_from_metadata(candidate, metadata, join_path(root.path, name, version, "src"), root.scope)
                            if selected == nil or compare_versions(candidate.version, selected.version) > 0 then
                                selected = candidate
                            end
                        end
                        if selected ~= nil then
                            items[#items + 1] = selected
                            by_name[lower(name)] = selected
                        end
                    end
                end
            end
        end
    end
    return items, by_name
end

local function parse_deft_list(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local marker = ""
        local installed, latest, name, description = line:match("^%s*!%s*([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+(.+)$")
        if installed ~= nil then
            marker = "!"
        else
            installed, latest, name, description = line:match("^%s*([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+(.+)$")
        end
        if name ~= nil and lower(installed) ~= "inst." and lower(latest) ~= "latest" and lower(name) ~= "name" then
            items[#items + 1] = {
                name = name,
                packageId = name,
                version = installed ~= "-" and installed or (latest ~= "-" and latest or nil),
                latestVersion = latest ~= "-" and latest or nil,
                installed = installed ~= "-",
                outdated = marker == "!" or (installed ~= "-" and latest ~= "-" and compare_versions(installed, latest) < 0),
                summary = trim(description),
                description = trim(description),
            }
        end
    end
    return items
end

local function merge_catalog_with_installed(catalog_items, installed_map)
    local results = {}
    for _, item in ipairs(catalog_items or {}) do
        local installed = installed_map[lower(item.name or item.packageId or "")]
        local merged = {}
        for key, value in pairs(item) do
            merged[key] = value
        end
        if installed ~= nil then
            merged.installed = true
            merged.version = installed.version or merged.version
            merged.extraFields = installed.extraFields
            if trim(installed.description or "") ~= "" then
                merged.description = installed.description
            end
            if trim(installed.summary or "") ~= "" then
                merged.summary = installed.summary
            end
        end
        results[#results + 1] = merged
    end
    return results
end

local function rank_match(item, query)
    local name = lower(item.name or item.packageId or "")
    local summary = lower(item.summary or "")
    local description = lower(item.description or "")
    if name == query then
        return 1
    end
    if name:sub(1, #query) == query then
        return 2
    end
    if name:find(query, 1, true) ~= nil then
        return 3
    end
    if summary:find(query, 1, true) ~= nil then
        return 4
    end
    if description:find(query, 1, true) ~= nil then
        return 5
    end
    return nil
end

local function load_catalog(context)
    local result = exec_run(context, "deft list --all")
    if not is_success(result) then
        return nil, trim(result.stderr) ~= "" and trim(result.stderr) or trim(result.stdout)
    end
    return parse_deft_list(result.stdout), nil
end

local function ensure_available(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true
    end
    return false, "deft binary not found"
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
    return { "language", "development", "package-management" }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end
    if not command_exists(nil, REQUIRED_BINARY) then
        return packages
    end
    local installed_items, installed_map = scan_installed(nil)
    local catalog_items = select(1, load_catalog(nil)) or {}
    local latest_by_name = {}
    for _, item in ipairs(catalog_items) do
        latest_by_name[lower(item.name or item.packageId or "")] = item.latestVersion or item.version
    end
    local missing = {}
    for _, package in ipairs(packages) do
        local action = lower(read_field(package, "action") or "install")
        local name = package_name(package)
        local installed = name ~= nil and installed_map[lower(name)] or nil
        if action == "remove" then
            if installed ~= nil then
                missing[#missing + 1] = package
            end
        elseif action == "update" then
            local latest = name ~= nil and latest_by_name[lower(name)] or nil
            if installed == nil or latest == nil or compare_versions(installed.version, latest) < 0 then
                missing[#missing + 1] = package
            end
        elseif request_local_path(package) ~= nil then
            missing[#missing + 1] = package
        else
            local version = package_version(package)
            if installed == nil then
                missing[#missing + 1] = package
            elseif version ~= nil and trim(installed.version or "") ~= trim(version) then
                missing[#missing + 1] = package
            end
        end
    end
    return missing
end

function plugin.init()
    return true
end

function plugin.install(context, packages)
    local local_path = request_local_path(context, packages and packages[1] and read_field(packages[1], "path"))
    if local_path ~= nil then
        return plugin.installLocal(context, local_path)
    end
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end
    begin_step(context, "install deft packages")
    local installed = {}
    for _, package in ipairs(requested) do
        local request = package_request(package)
        if request == nil then
            return failure(context, "deft install failed: missing package name")
        end
        local result = exec_run(context, "deft install " .. request)
        if not is_success(result) then
            return failure(context, "deft install failed for " .. request)
        end
        installed[#installed + 1] = {
            name = package_name(package),
            packageId = package_name(package),
            version = package_version(package),
            requested = request,
        }
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    return failure(context, "deft installLocal is not supported; use published catalog packages", {
        path = local_path,
        reason = "local-install-unsupported",
    })
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end
    begin_step(context, "remove deft package caches")
    local deleted = {}
    local roots = package_roots(context)
    for _, package in ipairs(requested) do
        local name = package_name(package)
        if name == nil then
            return failure(context, "deft remove failed: missing package name")
        end
        local target_version = package_version(package)
        for _, root in ipairs(roots) do
            if dir_exists(context, root.path) then
                local package_root = join_path(root.path, name)
                local versions_result = list_dir(context, package_root)
                if is_success(versions_result) then
                    local versions = split_lines(versions_result.stdout)
                    if target_version == nil then
                        for _, version in ipairs(versions) do
                            if target_version == nil or compare_versions(version, target_version) > 0 then
                                target_version = version
                            end
                        end
                    end
                    if target_version ~= nil then
                        local result = exec_run(context, "rm -rf " .. shell_quote(join_path(package_root, target_version)))
                        if not is_success(result) then
                            return failure(context, "deft remove failed for " .. name)
                        end
                        deleted[#deleted + 1] = {
                            name = name,
                            packageId = name,
                            version = target_version,
                        }
                        break
                    end
                end
            end
        end
    end
    emit_event(context, "deleted", deleted)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    begin_step(context, "update deft packages")
    if #requested == 0 then
        local result = exec_run(context, "deft update")
        if not is_success(result) then
            return failure(context, "deft update failed")
        end
        emit_event(context, "updated", {})
        tx_success(context)
        return true
    end
    for _, package in ipairs(requested) do
        local request = package_request(package)
        if request == nil then
            return failure(context, "deft update failed: missing package name")
        end
        local result = exec_run(context, "deft install " .. request)
        if not is_success(result) then
            return failure(context, "deft update failed for " .. request)
        end
    end
    local refresh = exec_run(context, "deft update")
    if not is_success(refresh) then
        return failure(context, "deft update failed")
    end
    emit_event(context, "updated", requested)
    tx_success(context)
    return true
end

function plugin.list(context)
    local result = exec_run(context, "deft list")
    if is_success(result) then
        local listed = parse_deft_list(result.stdout)
        emit_event(context, "listed", listed)
        return listed
    end
    local installed_items = select(1, scan_installed(context))
    emit_event(context, "listed", installed_items)
    return installed_items
end

function plugin.outdated(context)
    local result = exec_run(context, "deft list")
    local items = {}
    if is_success(result) then
        for _, item in ipairs(parse_deft_list(result.stdout)) do
            if item.outdated then
                items[#items + 1] = item
            end
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = lower(trim(prompt or read_field(context, "prompt")))
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end
    local catalog_items, err = load_catalog(context)
    if catalog_items == nil then
        log_warn(context, err or "deft list --all failed")
        emit_event(context, "searched", {})
        return {}
    end
    local ranked = {}
    for _, item in ipairs(catalog_items) do
        local score = rank_match(item, query)
        if score ~= nil then
            ranked[#ranked + 1] = { score = score, item = item }
        end
    end
    table.sort(ranked, function(left, right)
        if left.score ~= right.score then
            return left.score < right.score
        end
        return lower(left.item.name) < lower(right.item.name)
    end)
    local results = {}
    for _, entry in ipairs(ranked) do
        results[#results + 1] = entry.item
    end
    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local query = lower(trim(name or read_field(context, "prompt")))
    if query == "" then
        emit_event(context, "unavailable", { name = name, reason = "missing-name" })
        return {}
    end
    local catalog_items = select(1, load_catalog(context)) or {}
    for _, item in ipairs(catalog_items) do
        if lower(item.name or item.packageId or "") == query then
            emit_event(context, "informed", item)
            return item
        end
    end
    local _, installed_map = scan_installed(context)
    local installed = installed_map[query]
    if installed ~= nil then
        emit_event(context, "informed", installed)
        return installed
    end
    emit_event(context, "unavailable", { name = name, reason = "not-found" })
    return {}
end

function plugin.shutdown()
    return true
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "install", "remove-cache", "update", "list", "outdated", "search", "info" },
        ecosystemScopes = { "dylan", "deft" },
        writeScopes = {
            { kind = "user-home-subpath", path = ".local/state/dylan/_packages" },
            { kind = "workspace-subpath", path = "_packages" },
            { kind = "workspace-subpath", path = "registry" },
        },
        networkScopes = {
            "https://github.com/dylan-lang/pacman-catalog.git",
            "https://github.com/",
        },
        privilegeLevel = "none",
    }
end

return plugin
