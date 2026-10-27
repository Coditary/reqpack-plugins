plugin = {}
plugin.fileExtensions = { ".rockspec", ".src.rock", ".rock" }

local PLUGIN_ID = "luarocks"
local PLUGIN_NAME = "LuaRocks"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "luarocks"

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
        lines[#lines + 1] = line
    end
    return lines
end

local function split_tabs(line)
    local fields = {}
    for field in (tostring(line or "") .. "\t"):gmatch("(.-)\t") do
        fields[#fields + 1] = field
    end
    return fields
end

local function is_safe_token(value)
    return tostring(value or ""):match("^[A-Za-z0-9_./:@%%+=,%-$%{%}]+$") ~= nil
end

local function shell_quote(value)
    local text = tostring(value or "")
    if is_safe_token(text) then
        return text
    end
    return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(select(index, ...))
        if part ~= "" then
            if #parts == 0 then
                parts[#parts + 1] = part:gsub("[/\\]+$", "")
            else
                parts[#parts + 1] = part:gsub("^[/\\]+", ""):gsub("[/\\]+$", "")
            end
        end
    end
    return table.concat(parts, "/")
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

local function object_flags(value)
    local raw = read_field(value, "flags")
    if type(raw) ~= "table" and type(raw) ~= "userdata" then
        return {}
    end

    local flags = {}
    local ok = pcall(function()
        for _, item in ipairs(raw) do
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

local function flag_value(flags, prefix)
    local needle = trim(prefix)
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if cleaned:sub(1, #needle) == needle then
            return cleaned:sub(#needle + 1)
        end
    end
    return ""
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

local function get_plugin_dir()
    local plugin_dir = tostring(_G.REQPACK_PLUGIN_DIR or "")
    if plugin_dir ~= "" then
        if plugin_dir:find("\\", 1, true) ~= nil then
            return plugin_dir:gsub("\\", "/")
        end
        return plugin_dir
    end
    return "l/luarocks"
end

local function data_root_from_context(context, packages)
    local context_flags = context and context.flags or {}
    local from_context = flag_value(context_flags, "data-root=")
    if from_context ~= "" then
        return from_context
    end

    for _, pkg in ipairs(packages or {}) do
        local from_package = flag_value(object_flags(pkg), "data-root=")
        if from_package ~= "" then
            return from_package
        end
    end

    local fixture_root = os ~= nil and type(os.getenv) == "function" and trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT")) or ""
    if fixture_root ~= "" then
        return join_path(fixture_root, ".reqpack-data")
    end

    return join_path(get_plugin_dir(), ".reqpack-data")
end

local function state_paths(root)
    local base = trim(root)
    if base == "" then
        base = join_path(get_plugin_dir(), ".reqpack-data")
    end

    return {
        root = base,
        tree = join_path(base, "tree"),
        cache = join_path(base, "cache"),
        config = join_path(base, "config"),
    }
end

local function env_prefix(paths)
    return table.concat({
        "XDG_CACHE_HOME=" .. shell_quote(paths.cache),
        "XDG_CONFIG_HOME=" .. shell_quote(paths.config),
    }, " ")
end

local function luarocks_command(paths, args, options)
    local parts = { env_prefix(paths), REQUIRED_BINARY }
    if options == nil or options.use_tree ~= false then
        parts[#parts + 1] = "--tree"
        parts[#parts + 1] = shell_quote(paths.tree)
    end
    for _, arg in ipairs(args or {}) do
        local cleaned = trim(arg)
        if cleaned ~= "" then
            parts[#parts + 1] = shell_quote(cleaned)
        end
    end
    return table.concat(parts, " ")
end

local function run_exec(context, command)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return context.exec.run(command)
    end
    return reqpack.exec.run(command)
end

local function command_exists(binary)
    local result = reqpack.exec.run("command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function binary_available(context)
    local result = run_exec(context, "command -v " .. shell_quote(REQUIRED_BINARY) .. " >/dev/null 2>&1")
    if result ~= nil and result.success == true then
        return true, nil
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageName") or read_field(pkg, "packageId"))
end

local function package_version(pkg)
    return trim(read_field(pkg, "version"))
end

local function package_action(pkg)
    return lower(trim(read_field(pkg, "action") or read_field(pkg, "requestedAction")))
end

local function file_extension(path)
    local value = lower(trim(path))
    if value:sub(-9) == ".src.rock" then
        return ".src.rock"
    end
    return value:match("(%.[^.]+)$") or ""
end

local function local_install_supported(path)
    local ext = file_extension(path)
    return ext == ".rockspec" or ext == ".src.rock" or ext == ".rock"
end

local function first_non_empty(...)
    for index = 1, select("#", ...) do
        local value = trim(select(index, ...))
        if value ~= "" then
            return value
        end
    end
    return nil
end

local function add_unique(target, value)
    local cleaned = trim(value)
    if cleaned == "" then
        return
    end
    for _, existing in ipairs(target) do
        if existing == cleaned then
            return
        end
    end
    target[#target + 1] = cleaned
end

local function normalize_name(package, namespace)
    local name = trim(package)
    local ns = trim(namespace)
    if ns ~= "" and not name:find("/", 1, true) then
        return ns .. "/" .. name
    end
    return name
end

local function parse_porcelain_collection(raw, installed_default, status_default)
    local items = {}
    for _, line in ipairs(split_lines(raw)) do
        local fields = split_tabs(line)
        local package = trim(fields[1])
        local version = trim(fields[2])
        if package ~= "" and version ~= "" then
            local arch = trim(fields[3])
            local repo = trim(fields[4])
            local namespace = trim(fields[5])
            local name = normalize_name(package, namespace)
            items[#items + 1] = {
                name = name,
                packageId = package,
                version = version,
                latestVersion = version,
                installed = installed_default,
                status = status_default,
                repository = repo ~= "" and repo or nil,
                packageType = "rock",
                extraFields = next({ arch = arch ~= "" and arch or nil, namespace = namespace ~= "" and namespace or nil }) and {
                    arch = arch ~= "" and arch or nil,
                    namespace = namespace ~= "" and namespace or nil,
                } or nil,
            }
        end
    end
    return items
end

local function parse_outdated(raw)
    local items = {}
    for _, line in ipairs(split_lines(raw)) do
        local fields = split_tabs(line)
        local package = trim(fields[1])
        local current_version = trim(fields[2])
        local latest_version = trim(fields[3])
        local repo = trim(fields[4])
        if package ~= "" and current_version ~= "" and latest_version ~= "" then
            items[#items + 1] = {
                name = package,
                packageId = package,
                version = current_version,
                latestVersion = latest_version,
                installed = true,
                status = "outdated",
                repository = repo ~= "" and repo or nil,
                packageType = "rock",
            }
        end
    end
    return items
end

local function parse_show_porcelain(raw, installed_default)
    local item = {
        installed = installed_default,
        status = installed_default and "installed" or "available",
        packageType = "rock",
    }
    local modules = {}
    local commands = {}
    local dependencies = {}
    local description_lines = {}

    for _, line in ipairs(split_lines(raw)) do
        local fields = split_tabs(line)
        local kind = trim(fields[1])
        if kind == "package" then
            item.packageId = trim(fields[2])
            item.name = trim(fields[2])
        elseif kind == "version" then
            item.version = trim(fields[2])
            item.latestVersion = trim(fields[2])
        elseif kind == "summary" then
            item.summary = trim(fields[2])
        elseif kind == "detailed" then
            add_unique(description_lines, trim(fields[2]))
        elseif kind == "license" then
            item.license = trim(fields[2])
        elseif kind == "homepage" then
            item.homepage = trim(fields[2])
        elseif kind == "location" then
            item.extraFields = item.extraFields or {}
            item.extraFields.location = trim(fields[2])
        elseif kind == "module" then
            add_unique(modules, trim(fields[2]))
        elseif kind == "command" then
            add_unique(commands, trim(fields[2]))
        elseif kind == "dependency" then
            add_unique(dependencies, trim(fields[2]))
        end
    end

    if #description_lines > 0 then
        item.description = table.concat(description_lines, " ")
    end
    if #commands > 0 then
        item.binaries = commands
    end
    if #dependencies > 0 then
        item.dependencies = dependencies
    end
    if #modules > 0 then
        item.extraFields = item.extraFields or {}
        item.extraFields.modules = modules
    end

    if item.extraFields ~= nil and next(item.extraFields) == nil then
        item.extraFields = nil
    end
    if trim(item.name) == "" and trim(item.packageId) ~= "" then
        item.name = item.packageId
    end
    if trim(item.packageId) == "" and trim(item.name) ~= "" then
        item.packageId = item.name
    end
    if trim(item.name) == "" then
        return nil
    end
    return item
end

local function build_exact_lookup(items)
    local lookup = {}
    for _, item in ipairs(items or {}) do
        local key = lower(trim(item.packageId or item.name)) .. "@" .. lower(trim(item.version))
        lookup[key] = true
    end
    return lookup
end

local function query_list(context, paths)
    local result = run_exec(context, luarocks_command(paths, { "list", "--porcelain" }))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_porcelain_collection(result.stdout, true, "installed")
end

local function query_outdated(context, paths)
    local result = run_exec(context, luarocks_command(paths, { "list", "--outdated", "--porcelain" }))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_outdated(result.stdout)
end

local function query_search(context, paths, prompt, version)
    local args = { "search", "--porcelain", prompt }
    if trim(version) ~= "" then
        args[#args + 1] = version
    end
    local result = run_exec(context, luarocks_command(paths, args, { use_tree = false }))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_porcelain_collection(result.stdout, false, "available")
end

local function query_show_local(context, paths, name, version)
    local args = { "show", "--porcelain", name }
    if trim(version) ~= "" then
        args[#args + 1] = version
    end
    local result = run_exec(context, luarocks_command(paths, args))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_show_porcelain(result.stdout, true)
end

local function normalize_package(pkg)
    local name = package_name(pkg)
    if name == "" then
        return nil, "missing rock name"
    end
    return {
        name = name,
        version = package_version(pkg),
    }, nil
end

local function exact_search_match(items, name)
    local needle = lower(trim(name))
    local best = nil
    for _, item in ipairs(items or {}) do
        local candidate_name = lower(trim(item.packageId or item.name))
        local candidate_full = lower(trim(item.name))
        if candidate_name == needle or candidate_full == needle then
            if best == nil then
                best = shallow_copy(item)
            end
        end
    end
    return best
end

local function failure(context, message)
    tx_failed(context, message)
    return false
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
    return { "Lua", "Package Manager" }
end

function plugin.init()
    return true
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end

    if not command_exists(REQUIRED_BINARY) then
        return packages
    end

    local paths = state_paths(data_root_from_context(nil, packages))
    local installed_items = query_list(nil, paths)
    if installed_items == nil then
        return packages
    end

    local installed_versions = {}
    for _, item in ipairs(installed_items) do
        local key = lower(trim(item.packageId or item.name))
        installed_versions[key] = installed_versions[key] or {}
        installed_versions[key][lower(trim(item.version))] = true
    end

    local needs_outdated = false
    for _, pkg in ipairs(packages) do
        if package_action(pkg) == "update" then
            needs_outdated = true
            break
        end
    end

    local outdated_versions = {}
    if needs_outdated then
        local outdated_items = query_outdated(nil, paths)
        if outdated_items == nil then
            return packages
        end
        for _, item in ipairs(outdated_items) do
            outdated_versions[lower(trim(item.packageId or item.name))] = true
        end
    end

    local filtered = {}
    for _, pkg in ipairs(packages) do
        local action = package_action(pkg)
        local name = lower(package_name(pkg))
        local version = lower(package_version(pkg))
        local installed = installed_versions[name] ~= nil
        local exact_installed = installed and version ~= "" and installed_versions[name][version] == true

        if action == "remove" then
            if installed and (version == "" or exact_installed) then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "update" then
            if outdated_versions[name] == true or (version ~= "" and not exact_installed) then
                filtered[#filtered + 1] = pkg
            end
        elseif not installed or (version ~= "" and not exact_installed) then
            filtered[#filtered + 1] = pkg
        end
    end

    return filtered
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end

    local available, message = binary_available(context)
    if not available then
        return failure(context, message)
    end

    begin_step(context, "install luarocks packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local installed = {}

    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return failure(context, err)
        end

        local args = { "install", pkg.name }
        if pkg.version ~= "" then
            args[#args + 1] = pkg.version
        end
        local result = run_exec(context, luarocks_command(paths, args))
        if result == nil or result.success ~= true then
            return failure(context, "luarocks install failed for " .. pkg.name)
        end

        installed[#installed + 1] = {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "rock",
        }
    end

    emit_event(context, "installed", installed)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.installLocal(context, path)
    local source_path = trim(path or read_field(context, "localPath") or read_field(context, "path"))
    if source_path == "" then
        return failure(context, "missing local rock path")
    end
    if not local_install_supported(source_path) then
        return failure(context, "unsupported local file extension; supported: .rockspec, .src.rock, .rock")
    end

    local available, message = binary_available(context)
    if not available then
        return failure(context, message)
    end

    begin_step(context, "install local luarocks package")
    local paths = state_paths(data_root_from_context(context, {}))
    local result = run_exec(context, luarocks_command(paths, { "install", source_path }))
    if result == nil or result.success ~= true then
        return failure(context, "luarocks install failed for local artifact")
    end

    emit_event(context, "installed", { { path = source_path, localTarget = true } })
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end

    local available, message = binary_available(context)
    if not available then
        return failure(context, message)
    end

    begin_step(context, "remove luarocks packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local deleted = {}

    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return failure(context, err)
        end

        local args = { "remove", pkg.name }
        if pkg.version ~= "" then
            args[#args + 1] = pkg.version
        end
        local result = run_exec(context, luarocks_command(paths, args))
        if result == nil or result.success ~= true then
            return failure(context, "luarocks remove failed for " .. pkg.name)
        end
        deleted[#deleted + 1] = {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "rock",
        }
    end

    emit_event(context, "deleted", deleted)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end

    local available, message = binary_available(context)
    if not available then
        return failure(context, message)
    end

    begin_step(context, "update luarocks packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local updated = {}

    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return failure(context, err)
        end

        local args = { "install", pkg.name }
        if pkg.version ~= "" then
            args[#args + 1] = pkg.version
        end
        local result = run_exec(context, luarocks_command(paths, args))
        if result == nil or result.success ~= true then
            return failure(context, "luarocks update failed for " .. pkg.name)
        end
        updated[#updated + 1] = {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "rock",
        }
    end

    emit_event(context, "updated", updated)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.list(context)
    local available, message = binary_available(context)
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "listed", items)
        return items
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local items = query_list(context, paths)
    if items == nil then
        log_warn(context, "luarocks list failed")
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local available, message = binary_available(context)
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "outdated", items)
        return items
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local items = query_outdated(context, paths)
    if items == nil then
        log_warn(context, "luarocks list --outdated failed")
        items = {}
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned_prompt = trim(prompt)
    if cleaned_prompt == "" and context ~= nil then
        cleaned_prompt = trim(context.prompt)
    end
    if cleaned_prompt == "" then
        local items = {}
        emit_event(context, "searched", items)
        return items
    end

    local available, message = binary_available(context)
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "searched", items)
        return items
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local items = query_search(context, paths, cleaned_prompt, "")
    if items == nil then
        log_warn(context, "luarocks search failed")
        items = {}
    else
        local installed_items = query_list(context, paths) or {}
        local installed_lookup = build_exact_lookup(installed_items)
        for _, item in ipairs(items) do
            local key = lower(trim(item.packageId or item.name)) .. "@" .. lower(trim(item.version))
            if installed_lookup[key] == true then
                item.installed = true
                item.status = "installed"
            end
        end
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local cleaned_name = trim(name)
    if cleaned_name == "" and context ~= nil then
        cleaned_name = trim(context.prompt)
    end
    if cleaned_name == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local available, message = binary_available(context)
    if not available then
        log_warn(context, message)
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local item = query_show_local(context, paths, cleaned_name, "")
    if item == nil then
        local matches = query_search(context, paths, cleaned_name, "") or {}
        item = exact_search_match(matches, cleaned_name) or {}
    end
    if next(item) == nil then
        emit_event(context, "unavailable", {
            name = cleaned_name,
            reason = "not-found",
        })
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end

    local pkg, err = normalize_package(package)
    if pkg == nil then
        return nil, err
    end

    if not command_exists(REQUIRED_BINARY) then
        return {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "rock",
        }
    end

    local paths = state_paths(data_root_from_context(context, { package }))
    local item = query_show_local(context, paths, pkg.name, pkg.version)
    if item ~= nil then
        if pkg.version ~= "" then
            item.version = pkg.version
        end
        return item
    end

    local matches = query_search(context, paths, pkg.name, pkg.version)
    local found = exact_search_match(matches or {}, pkg.name)
    if found ~= nil then
        if pkg.version ~= "" then
            found.version = pkg.version
        end
        return found
    end

    return {
        name = pkg.name,
        packageId = pkg.name,
        version = pkg.version ~= "" and pkg.version or nil,
        packageType = "rock",
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "luarocks", "lua" },
        writeScopes = {
            "plugin-data:l/luarocks/.reqpack-data/tree",
            "plugin-data:l/luarocks/.reqpack-data/cache",
            "plugin-data:l/luarocks/.reqpack-data/config",
        },
        networkScopes = { "https://luarocks.org" },
        privilegeLevel = "none",
        purlType = "generic",
    }
end

function plugin.shutdown()
    return true
end

return plugin
