plugin = {}

local PLUGIN_ID = "xbps"
local PLUGIN_NAME = "XBPS"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARIES = {
    "xbps-install",
    "xbps-remove",
    "xbps-query",
    "xbps-rindex",
}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return tostring(value or ""):lower()
end

local function split_lines(value)
    local text = tostring(value or ""):gsub("\r\n", "\n")
    local lines = {}
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

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        local value = os.getenv(name)
        if value ~= nil and value ~= "" then
            return value
        end
    end

    local handle = io.open("/proc/self/environ", "rb")
    if handle == nil then
        return nil
    end
    local payload = handle:read("*a")
    handle:close()
    if payload == nil or payload == "" then
        return nil
    end
    local prefix = tostring(name or "") .. "="
    for entry in tostring(payload):gmatch("[^%z]+") do
        if entry:sub(1, #prefix) == prefix then
            local value = entry:sub(#prefix + 1)
            if value ~= "" then
                return value
            end
        end
    end
    return nil
end

local function expand_placeholders(value)
    local text = tostring(value or "")
    local fixture_root = getenv("REQPACK_TEST_FIXTURE_ROOT")
    if fixture_root ~= nil and fixture_root ~= "" then
        text = text:gsub("%$%{fixtureRoot%}", fixture_root)
    end
    return text
end

local function shell_quote(value)
    return "'" .. tostring(expand_placeholders(value)):gsub("'", "'\\''") .. "'"
end

local function command_quote(value)
    local text = expand_placeholders(value)
    if text:match("^[A-Za-z0-9_./:@%%+=,-]+$") ~= nil then
        return text
    end
    return shell_quote(text)
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(expand_placeholders(select(index, ...)))
        if part ~= "" then
            if #parts == 0 then
                parts[#parts + 1] = part:gsub("[/\\]+$", "")
            else
                parts[#parts + 1] = part:gsub("^[/\\]+", ""):gsub("[/\\]+$", "")
            end
        end
    end
    if #parts == 0 then
        return "."
    end
    return table.concat(parts, "/")
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

local function object_flags(object)
    local value = read_field(object, "flags")
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

local function collect_raw_flags(context, packages)
    local flags = {}
    local seen = {}
    local function collect_from(object)
        for _, flag in ipairs(object_flags(object)) do
            append_unique(flags, flag, seen)
        end
    end
    collect_from(context)
    collect_from(read_field(context, "request"))
    for _, package in ipairs(packages or {}) do
        collect_from(package)
    end
    return flags
end

local function flag_value(flags, key)
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            return trim(cleaned:sub(#prefix + 1))
        end
    end
    return nil
end

local function flag_values(flags, key)
    local values = {}
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            local value = trim(cleaned:sub(#prefix + 1))
            if value ~= "" then
                values[#values + 1] = value
            end
        end
    end
    return values
end

local function has_flag(flags, key)
    local wanted = lower(trim(key))
    for _, flag in ipairs(flags or {}) do
        if lower(trim(flag)) == wanted then
            return true
        end
    end
    return false
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
            exitCode = 1,
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

local function command_exists(binary)
    return run_global("command -v " .. binary .. " >/dev/null 2>&1").success
end

local function ensure_binaries_available(context)
    if context == nil then
        return true
    end
    for _, binary in ipairs(REQUIRED_BINARIES) do
        if not exec_run(context, "command -v " .. binary .. " >/dev/null 2>&1").success then
            local message = binary .. " not available"
            tx_failed(context, message)
            return false, message
        end
    end
    return true
end

local function default_cache_root()
    local home = getenv("HOME") or "~"
    return join_path(home, ".cache", "reqpack", PLUGIN_ID)
end

local function cache_root_for(context, packages)
    local flags = collect_raw_flags(context, packages)
    local override = flag_value(flags, "cache-root")
    if override ~= nil and override ~= "" then
        return expand_placeholders(override)
    end
    return default_cache_root()
end

local function cache_dir_for(context, packages)
    return join_path(cache_root_for(context, packages), "cache")
end

local function local_repo_root_for(context, packages)
    return join_path(cache_root_for(context, packages), "local-repos")
end

local function xbps_common_args(context, packages, options)
    local flags = collect_raw_flags(context, packages)
    local args = { "-c", cache_dir_for(context, packages) }

    local rootdir = flag_value(flags, "rootdir")
    if rootdir ~= nil and rootdir ~= "" and options.allow_rootdir ~= false then
        args[#args + 1] = "-r"
        args[#args + 1] = rootdir
    end

    local config = flag_value(flags, "config")
    if config ~= nil and config ~= "" and options.allow_config ~= false then
        args[#args + 1] = "-C"
        args[#args + 1] = config
    end

    if options.allow_ignore_conf_repos and has_flag(flags, "ignore-conf-repos") then
        args[#args + 1] = "-i"
    end

    if options.allow_repositories then
        for _, repo in ipairs(flag_values(flags, "repository")) do
            args[#args + 1] = "--repository=" .. repo
        end
    end

    if options.allow_memory_sync and has_flag(flags, "memory-sync") then
        args[#args + 1] = "-M"
    end

    if options.allow_staging and has_flag(flags, "staging") then
        args[#args + 1] = "--staging"
    end

    return args, flags
end

local function package_name(value)
    return trim(read_field(value, "name") or read_field(value, "packageId") or value)
end

local function package_version(value)
    return trim(read_field(value, "version"))
end

local function has_constraint_syntax(value)
    local cleaned = trim(value)
    if cleaned == "" then
        return false
    end
    return cleaned:find(">=", 1, true) ~= nil
        or cleaned:find("<=", 1, true) ~= nil
        or cleaned:find(">", 1, true) ~= nil
        or cleaned:find("<", 1, true) ~= nil
        or cleaned:find("=", 1, true) ~= nil
end

local function package_comparator(item)
    local raw_flags = object_flags(item)
    for _, flag in ipairs(raw_flags) do
        local cleaned = lower(trim(flag))
        if cleaned == "eq" then
            return "="
        elseif cleaned == "lt" then
            return "<"
        elseif cleaned == "lte" then
            return "<="
        elseif cleaned == "gt" then
            return ">"
        elseif cleaned == "gte" then
            return ">="
        elseif cleaned:sub(1, 11) == "comparator=" then
            local value = trim(flag:sub(12))
            if value == "==" then
                return "="
            end
            if value == "=" or value == "<" or value == "<=" or value == ">" or value == ">=" then
                return value
            end
        end
    end
    return nil
end

local function package_expression(item)
    local name = package_name(item)
    if name == "" then
        return nil
    end
    if has_constraint_syntax(name) then
        return name
    end
    local version = package_version(item)
    if version == "" or lower(version) == "latest" then
        return name
    end
    local comparator = package_comparator(item) or ">="
    return name .. comparator .. version
end

local function basename(path)
    local text = expand_placeholders(path)
    return text:match("([^/\\]+)$") or text
end

local function strip_xbps_filename(filename)
    local name = trim(filename)
    name = name:gsub("%.xbps$", "")
    local pkgname = name:match("^(.*)%-%d[^-]*_[^%-]+%.[A-Za-z0-9_]+$")
    if pkgname ~= nil and pkgname ~= "" then
        return pkgname
    end
    pkgname = name:match("^(.*)%-%d[^-]*_[^%-]+$")
    if pkgname ~= nil and pkgname ~= "" then
        return pkgname
    end
    return name
end

local function build_command(binary, args)
    local parts = { binary }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = command_quote(arg)
    end
    return table.concat(parts, " ")
end

local function run_xbps(context, binary, args)
    return exec_run(context, build_command(binary, args))
end

local function starts_with(text, prefix)
    return tostring(text or ""):sub(1, #prefix) == prefix
end

local function split_words(line)
    local words = {}
    for word in tostring(line or ""):gmatch("%S+") do
        words[#words + 1] = word
    end
    return words
end

local function parse_pkgver(pkgver)
    local cleaned = trim(pkgver)
    local name, version = cleaned:match("^(.*)%-(%d[^%s]*)$")
    if name == nil or version == nil then
        return cleaned, nil
    end
    return name, version
end

local function maybe_set(target, key, value)
    if value ~= nil and value ~= "" then
        target[key] = value
    end
end

local function parse_property_output(stdout)
    local text = tostring(stdout or ""):gsub("\r\n", "\n")
    if text:sub(-1) == "\n" then
        text = text:sub(1, -2)
    end
    return text
end

local function fetch_property(context, package_name_value, property, remote, extra_args)
    local args = xbps_common_args(context, nil, {
        allow_rootdir = true,
        allow_config = true,
        allow_ignore_conf_repos = remote,
        allow_repositories = remote,
        allow_memory_sync = remote,
        allow_staging = remote,
    })
    for _, arg in ipairs(extra_args or {}) do
        args[#args + 1] = arg
    end
    if remote then
        args[#args + 1] = "-R"
    end
    args[#args + 1] = "--property=" .. property
    args[#args + 1] = package_name_value
    local result = run_xbps(context, "xbps-query", args)
    if not result.success then
        return nil
    end
    return parse_property_output(result.stdout)
end

local function fetch_dependencies(context, package_name_value, remote)
    local args = xbps_common_args(context, nil, {
        allow_rootdir = true,
        allow_config = true,
        allow_ignore_conf_repos = remote,
        allow_repositories = remote,
        allow_memory_sync = remote,
        allow_staging = remote,
    })
    if remote then
        args[#args + 1] = "-R"
    end
    args[#args + 1] = "-x"
    args[#args + 1] = package_name_value
    local result = run_xbps(context, "xbps-query", args)
    if not result.success then
        return {}
    end
    local deps = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            deps[#deps + 1] = cleaned
        end
    end
    return deps
end

local function fetch_categories(context, package_name_value, remote)
    local value = fetch_property(context, package_name_value, "categories", remote)
    if value == nil or value == "" then
        return nil
    end
    local categories = {}
    for item in value:gmatch("[^%s,]+") do
        categories[#categories + 1] = item
    end
    if #categories == 0 then
        return nil
    end
    return categories
end

local function fetch_package_info(context, package_name_value, remote)
    local pkgver = fetch_property(context, package_name_value, "pkgver", remote)
    if pkgver == nil or pkgver == "" then
        return nil
    end
    local resolved_name, resolved_version = parse_pkgver(pkgver)
    local item = {
        name = resolved_name,
        packageId = resolved_name,
        version = resolved_version,
        latestVersion = remote and resolved_version or nil,
        installed = not remote,
        status = remote and "available" or "installed",
        summary = fetch_property(context, package_name_value, "short_desc", remote),
        description = fetch_property(context, package_name_value, "short_desc", remote),
        homepage = fetch_property(context, package_name_value, "homepage", remote),
        license = fetch_property(context, package_name_value, "license", remote),
        repository = fetch_property(context, package_name_value, "repository", remote),
        architecture = fetch_property(context, package_name_value, "architecture", remote),
        dependencies = fetch_dependencies(context, package_name_value, remote),
        categories = fetch_categories(context, package_name_value, remote),
    }

    local extra = {}
    maybe_set(extra, "state", fetch_property(context, package_name_value, "state", remote))
    maybe_set(extra, "automaticInstall", fetch_property(context, package_name_value, "automatic-install", remote))
    maybe_set(extra, "hold", fetch_property(context, package_name_value, "hold", remote))
    maybe_set(extra, "repolock", fetch_property(context, package_name_value, "repolock", remote))
    if next(extra) ~= nil then
        item.extraFields = extra
    end

    return item
end

local function installed_package_info(context, package_name_value)
    return fetch_package_info(context, package_name_value, false)
end

local function remote_package_info(context, package_name_value)
    return fetch_package_info(context, package_name_value, true)
end

local function installed_package_info_for_item(item)
    return installed_package_info(item, package_name(item))
end

local function remote_package_info_for_item(item)
    return remote_package_info(item, package_name(item))
end

local function merged_package_info(context, package_name_value)
    local installed = installed_package_info(context, package_name_value)
    local remote = remote_package_info(context, package_name_value)
    if installed == nil then
        return remote
    end
    if remote ~= nil then
        installed.latestVersion = remote.version or remote.latestVersion
        installed.summary = installed.summary or remote.summary
        installed.description = installed.description or remote.description
        installed.homepage = installed.homepage or remote.homepage
        installed.license = installed.license or remote.license
        installed.repository = installed.repository or remote.repository
        installed.architecture = installed.architecture or remote.architecture
        if (installed.dependencies == nil or #installed.dependencies == 0) and remote.dependencies ~= nil then
            installed.dependencies = remote.dependencies
        end
        if installed.categories == nil and remote.categories ~= nil then
            installed.categories = remote.categories
        end
    end
    return installed
end

local function merged_package_info_for_item(item)
    local name = package_name(item)
    if name == "" then
        return nil
    end
    local installed = installed_package_info(item, name)
    local remote = remote_package_info(item, name)
    if installed == nil then
        return remote
    end
    if remote ~= nil then
        installed.latestVersion = remote.version or remote.latestVersion
        installed.summary = installed.summary or remote.summary
        installed.description = installed.description or remote.description
        installed.homepage = installed.homepage or remote.homepage
        installed.license = installed.license or remote.license
        installed.repository = installed.repository or remote.repository
        installed.architecture = installed.architecture or remote.architecture
        if (installed.dependencies == nil or #installed.dependencies == 0) and remote.dependencies ~= nil then
            installed.dependencies = remote.dependencies
        end
        if installed.categories == nil and remote.categories ~= nil then
            installed.categories = remote.categories
        end
    end
    return installed
end

local function parse_list_line(line)
    local cleaned = trim(line)
    local state = cleaned:sub(1, 2)
    local rest = trim(cleaned:sub(3))
    local pkgver = rest:match("^(%S+)")
    if pkgver == nil then
        return nil
    end
    local name, version = parse_pkgver(pkgver)
    local summary = trim(rest:sub(#pkgver + 1))
    return {
        name = name,
        packageId = name,
        version = version,
        installed = state == "ii" or state == "uu",
        status = state,
        summary = summary ~= "" and summary or nil,
        description = summary ~= "" and summary or nil,
        extraFields = { state = state },
    }
end

local function parse_search_line(line)
    local cleaned = trim(line)
    local marker = cleaned:sub(1, 3)
    local installed = marker == "[*]"
    local rest = trim(cleaned:sub(4))
    local pkgver = rest:match("^(%S+)")
    if pkgver == nil then
        return nil
    end
    local name, version = parse_pkgver(pkgver)
    local summary = trim(rest:sub(#pkgver + 1))
    return {
        name = name,
        packageId = name,
        version = installed and version or nil,
        latestVersion = version,
        installed = installed,
        status = installed and "installed" or "available",
        summary = summary ~= "" and summary or nil,
        description = summary ~= "" and summary or nil,
    }
end

local function parse_outdated_line(line)
    local cleaned = trim(line)
    if not cleaned:match(" update$") then
        return nil
    end
    local pkgver = cleaned:match("^(%S+)%s+update$")
    if pkgver == nil then
        return nil
    end
    local name, version = parse_pkgver(pkgver)
    return {
        name = name,
        packageId = name,
        latestVersion = version,
    }
end

local function package_needs_update(context, item)
    local info = merged_package_info_for_item(item) or merged_package_info(context, package_name(item))
    if info == nil then
        return false
    end
    return info.version ~= nil and info.latestVersion ~= nil and info.version ~= info.latestVersion
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
    return { "system", "package-manager" }
end

function plugin.getMissingPackages(packages)
    local missing = {}
    for _, item in ipairs(packages or {}) do
        local action = lower(read_field(item, "action") or "install")
        local name = package_name(item)
        local installed = name ~= "" and (installed_package_info_for_item(item) ~= nil or installed_package_info(nil, name) ~= nil)
        if action == "remove" then
            if installed then
                missing[#missing + 1] = item
            end
        elseif action == "update" then
            if name ~= "" and package_needs_update(nil, item) then
                missing[#missing + 1] = item
            end
        else
            if not installed then
                missing[#missing + 1] = item
            end
        end
    end
    return missing
end

function plugin.install(context, packages)
    local local_path = trim(
        read_field(context, "localPath")
        or read_field(read_field(context, "request"), "localPath")
    )
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end
    if packages == nil or #packages == 0 then
        return true
    end
    local ok = ensure_binaries_available(context)
    if not ok then
        return false
    end
    local expressions = {}
    for _, item in ipairs(packages) do
        local expression = package_expression(item)
        if expression ~= nil then
            expressions[#expressions + 1] = expression
        end
    end
    begin_step(context, "install xbps packages")
    local args = { "-S", "-y" }
    local common_args, flags = xbps_common_args(context, packages, {
        allow_rootdir = true,
        allow_config = true,
        allow_ignore_conf_repos = true,
        allow_repositories = true,
        allow_memory_sync = true,
        allow_staging = true,
    })
    for _, arg in ipairs(common_args) do
        args[#args + 1] = arg
    end
    if has_flag(flags, "automatic") then
        args[#args + 1] = "-A"
    end
    if has_flag(flags, "download-only") then
        args[#args + 1] = "-D"
    end
    if has_flag(flags, "force") then
        args[#args + 1] = "-f"
    end
    if has_flag(flags, "ignore-file-conflicts") then
        args[#args + 1] = "-I"
    end
    if has_flag(flags, "unpack-only") then
        args[#args + 1] = "-U"
    end
    for _, expression in ipairs(expressions) do
        args[#args + 1] = expression
    end
    local result = run_xbps(context, "xbps-install", args)
    if not result.success then
        tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "xbps install failed")
        return false
    end
    local payload = {}
    for _, item in ipairs(packages) do
        payload[#payload + 1] = merged_package_info(context, package_name(item)) or item
    end
    emit_event(context, "installed", payload)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" or not local_path:match("%.xbps$") then
        tx_failed(context, "installLocal expects .xbps file path")
        return false
    end
    local ok = ensure_binaries_available(context)
    if not ok then
        return false
    end
    begin_step(context, "install local xbps package")
    local repo_root = join_path(local_repo_root_for(context), strip_xbps_filename(basename(local_path)))
    local repo_path = join_path(repo_root, basename(local_path))
    local mkdir_result = exec_run(context, build_command("mkdir", { "-p", repo_root }))
    if not mkdir_result.success then
        tx_failed(context, "failed to create local repo dir")
        return false
    end
    local link_result = exec_run(context, build_command("ln", { "-s", local_path, repo_path }))
    if not link_result.success then
        local copy_result = exec_run(context, build_command("cp", { local_path, repo_path }))
        if not copy_result.success then
            tx_failed(context, "failed to stage local xbps file")
            return false
        end
    end
    local index_result = run_xbps(context, "xbps-rindex", { "-a", join_path(repo_root, "*.xbps") })
    if not index_result.success then
        tx_failed(context, trim(index_result.stderr) ~= "" and trim(index_result.stderr) or "xbps-rindex failed")
        return false
    end
    local pkgname = strip_xbps_filename(basename(local_path))
    local args = { "-S", "-y" }
    local common_args, flags = xbps_common_args(context, nil, {
        allow_rootdir = true,
        allow_config = true,
        allow_ignore_conf_repos = true,
        allow_repositories = true,
        allow_memory_sync = true,
        allow_staging = true,
    })
    for _, arg in ipairs(common_args) do
        args[#args + 1] = arg
    end
    if has_flag(flags, "force") then
        args[#args + 1] = "-f"
    end
    if has_flag(flags, "ignore-file-conflicts") then
        args[#args + 1] = "-I"
    end
    if has_flag(flags, "unpack-only") then
        args[#args + 1] = "-U"
    end
    args[#args + 1] = "--repository=" .. repo_root
    args[#args + 1] = pkgname
    local install_result = run_xbps(context, "xbps-install", args)
    if not install_result.success then
        tx_failed(context, trim(install_result.stderr) ~= "" and trim(install_result.stderr) or "local xbps install failed")
        return false
    end
    emit_event(context, "installed", {
        localTarget = true,
        path = local_path,
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    if packages == nil or #packages == 0 then
        return true
    end
    local ok = ensure_binaries_available(context)
    if not ok then
        return false
    end
    begin_step(context, "remove xbps packages")
    local args = { "-y" }
    local common_args, flags = xbps_common_args(context, packages, {
        allow_rootdir = true,
        allow_config = true,
        allow_ignore_conf_repos = false,
        allow_repositories = false,
        allow_memory_sync = false,
        allow_staging = false,
    })
    for _, arg in ipairs(common_args) do
        args[#args + 1] = arg
    end
    if has_flag(flags, "force-remove") then
        args[#args + 1] = "-f"
    end
    if has_flag(flags, "force-revdeps") then
        args[#args + 1] = "-F"
    end
    if has_flag(flags, "recursive") then
        args[#args + 1] = "-R"
    end
    for _, item in ipairs(packages) do
        args[#args + 1] = package_name(item)
    end
    local result = run_xbps(context, "xbps-remove", args)
    if not result.success then
        tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "xbps remove failed")
        return false
    end
    emit_event(context, "deleted", packages)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local ok = ensure_binaries_available(context)
    if not ok then
        return false
    end
    begin_step(context, "update xbps packages")
    local args = { "-S", "-u", "-y" }
    local common_args, flags = xbps_common_args(context, packages, {
        allow_rootdir = true,
        allow_config = true,
        allow_ignore_conf_repos = true,
        allow_repositories = true,
        allow_memory_sync = true,
        allow_staging = true,
    })
    for _, arg in ipairs(common_args) do
        args[#args + 1] = arg
    end
    if has_flag(flags, "download-only") then
        args[#args + 1] = "-D"
    end
    if has_flag(flags, "force") then
        args[#args + 1] = "-f"
    end
    if has_flag(flags, "ignore-file-conflicts") then
        args[#args + 1] = "-I"
    end
    if has_flag(flags, "unpack-only") then
        args[#args + 1] = "-U"
    end
    for _, item in ipairs(packages or {}) do
        local name = package_name(item)
        if name ~= "" then
            args[#args + 1] = name
        end
    end
    local result = run_xbps(context, "xbps-install", args)
    if not result.success then
        tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "xbps update failed")
        return false
    end
    local payload = {}
    if packages == nil or #packages == 0 then
        payload = plugin.outdated(context)
    else
        for _, item in ipairs(packages) do
            payload[#payload + 1] = merged_package_info(context, package_name(item)) or item
        end
    end
    emit_event(context, "updated", payload)
    tx_success(context)
    return true
end

function plugin.list(context)
    local ok = ensure_binaries_available(nil)
    if not ok then
        emit_event(context, "listed", {})
        return {}
    end
    local args = xbps_common_args(context, nil, {
        allow_rootdir = true,
        allow_config = true,
        allow_ignore_conf_repos = false,
        allow_repositories = false,
        allow_memory_sync = false,
        allow_staging = false,
    })
    args[#args + 1] = "-l"
    local result = run_xbps(context, "xbps-query", args)
    if not result.success then
        log_warn(context, trim(result.stderr) ~= "" and trim(result.stderr) or "xbps list failed")
        emit_event(context, "listed", {})
        return {}
    end
    local items = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local item = parse_list_line(line)
        if item ~= nil then
            local enriched = merged_package_info(context, item.name) or item
            if enriched.extraFields == nil then
                enriched.extraFields = item.extraFields
            end
            items[#items + 1] = enriched
        end
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local ok = ensure_binaries_available(nil)
    if not ok then
        emit_event(context, "outdated", {})
        return {}
    end
    local args = { "-u", "-n" }
    local common_args, flags = xbps_common_args(context, nil, {
        allow_rootdir = true,
        allow_config = true,
        allow_ignore_conf_repos = true,
        allow_repositories = true,
        allow_memory_sync = true,
        allow_staging = true,
    })
    for _, arg in ipairs(common_args) do
        args[#args + 1] = arg
    end
    if not has_flag(flags, "memory-sync") then
        table.insert(args, 1, "-M")
    end
    local result = run_xbps(context, "xbps-install", args)
    if not result.success then
        log_warn(context, trim(result.stderr) ~= "" and trim(result.stderr) or "xbps outdated check failed")
        emit_event(context, "outdated", {})
        return {}
    end
    local items = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local parsed = parse_outdated_line(line)
        if parsed ~= nil then
            local installed = installed_package_info(context, parsed.name)
            local remote = remote_package_info(context, parsed.name)
            local item = installed or remote or parsed
            item.latestVersion = parsed.latestVersion or (remote and remote.version) or item.latestVersion
            item.installed = true
            item.status = "outdated"
            items[#items + 1] = item
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local text = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt"))
    if text == "" then
        emit_event(context, "searched", {})
        return {}
    end
    local ok = ensure_binaries_available(nil)
    if not ok then
        emit_event(context, "searched", {})
        return {}
    end
    local args = xbps_common_args(context, nil, {
        allow_rootdir = true,
        allow_config = true,
        allow_ignore_conf_repos = true,
        allow_repositories = true,
        allow_memory_sync = true,
        allow_staging = true,
    })
    args[#args + 1] = "-R"
    args[#args + 1] = "-s"
    args[#args + 1] = text
    local result = run_xbps(context, "xbps-query", args)
    if not result.success then
        log_warn(context, trim(result.stderr) ~= "" and trim(result.stderr) or "xbps search failed")
        emit_event(context, "searched", {})
        return {}
    end
    local items = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local item = parse_search_line(line)
        if item ~= nil then
            local remote = remote_package_info(context, item.name)
            if remote ~= nil then
                remote.installed = item.installed
                if item.installed and remote.version == nil then
                    local installed = installed_package_info(context, item.name)
                    if installed ~= nil then
                        remote.version = installed.version
                    end
                end
                item = remote
                item.installed = item.installed or false
            end
            items[#items + 1] = item
        end
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, package_name_value)
    local name = trim(
        package_name_value
        or read_field(context, "prompt")
        or read_field(read_field(context, "request"), "prompt")
        or read_field(read_field(context, "request"), "packageName")
    )
    if name == "" then
        emit_event(context, "unavailable", { name = package_name_value })
        return {}
    end
    local ok = ensure_binaries_available(nil)
    if not ok then
        emit_event(context, "unavailable", { name = name })
        return {}
    end
    local item = merged_package_info(context, name) or remote_package_info(context, name)
    if item == nil then
        emit_event(context, "unavailable", { name = name })
        return {}
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == "" then
        name = trim(
            read_field(package, "prompt")
            or read_field(read_field(context, "request"), "prompt")
            or read_field(read_field(context, "request"), "packageName")
        )
    end
    if name == "" then
        return nil
    end
    local ok = ensure_binaries_available(nil)
    if not ok then
        return nil
    end
    return merged_package_info_for_item(package) or merged_package_info(context, name) or remote_package_info_for_item(package) or remote_package_info(context, name)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "xbps" },
        writeScopes = {
            { kind = "temp" },
            { kind = "user-home-subpath", value = ".cache/reqpack/xbps" },
        },
        privilegeLevel = "user",
        osvEcosystem = "Generic",
        purlType = "generic",
    }
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

return plugin
