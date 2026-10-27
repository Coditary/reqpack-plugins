plugin = {}

local PLUGIN_ID = "nuget"
local PLUGIN_NAME = "NuGet"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "nuget"
local ENV_PREFIX = "LC_ALL=C LANG=C LANGUAGE=C NUGET_XMLDOC_MODE=skip"
local SEARCH_LIMIT = 20

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function cmd_quote(value)
    return '"' .. tostring(value or ""):gsub('"', '""') .. '"'
end

local function split_lines(value)
    local text = tostring(value or ""):gsub("\r\n", "\n")
    local lines = {}

    if text == "" then
        return lines
    end

    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line:gsub("\r$", "")
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

local function is_windows_host()
    local plugin_dir = tostring(_G.REQPACK_PLUGIN_DIR or "")
    if plugin_dir:find("\\", 1, true) ~= nil then
        return true
    end

    local host = reqpack and reqpack.host or nil
    local platform = host and host.platform or nil
    local os_info = host and host.os or nil
    local os_family = lower(trim(platform and platform.osFamily or ""))
    local os_id = lower(trim(os_info and os_info.id or ""))

    return os_family == "windows" or os_id == "windows"
end

local function command_quote(value)
    if is_windows_host() then
        return cmd_quote(value)
    end
    return shell_quote(value)
end

local function path_separator()
    if is_windows_host() then
        return "\\"
    end
    return "/"
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

    if #parts == 0 then
        return "."
    end

    return table.concat(parts, path_separator())
end

local function normalize_run_result(first, second, third, fourth, fifth)
    if type(first) == "table" then
        return first
    end

    local result = {}

    local function merge_exec_like(value)
        local probes = { "success", "ok", "stdout", "stderr", "exitCode", "exit_code", "code", "status" }
        for _, key in ipairs(probes) do
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

local function run_command(context, command)
    local first, second, third, fourth, fifth

    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        first, second, third, fourth, fifth = context.exec.run(command)
    elseif reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
        first, second, third, fourth, fifth = reqpack.exec.run(command)
    else
        return {
            success = false,
            stdout = "",
            stderr = "reqpack.exec.run unavailable",
            exitCode = 127,
        }
    end

    return normalize_run_result(first, second, third, fourth, fifth)
end

local function is_command_success(result, extra_exit_codes)
    if type(result) ~= "table" then
        return false
    end

    if result.success == true or result.ok == true then
        return true
    end

    local exit_code = result.exitCode or result.exit_code or result.code or result.status
    if exit_code == 0 then
        return true
    end

    if type(extra_exit_codes) == "table" then
        for _, allowed in ipairs(extra_exit_codes) do
            if exit_code == allowed then
                return true
            end
        end
    end

    return false
end

local function build_command(parts)
    local quoted = {}

    for _, part in ipairs(parts or {}) do
        local text = trim(part)
        if text ~= "" then
            quoted[#quoted + 1] = command_quote(text)
        end
    end

    return table.concat(quoted, " ")
end

local function os_command(parts)
    if is_windows_host() then
        return table.concat(parts or {}, " ")
    end
    return build_command(parts)
end

local function command_exists(binary)
    local command
    if is_windows_host() then
        command = "where " .. cmd_quote(binary) .. " >nul 2>nul"
    else
        command = "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"
    end
    return is_command_success(run_command(nil, command))
end

local function path_exists(path)
    local target = trim(path)
    if target == "" then
        return false
    end

    local handle = io.open(target, "r")
    if handle ~= nil then
        handle:close()
        return true
    end

    local command
    if is_windows_host() then
        command = "if exist " .. cmd_quote(target) .. " (exit /b 0) else (exit /b 1)"
    else
        command = "test -e " .. shell_quote(target)
    end

    return is_command_success(run_command(nil, command))
end

local function ensure_directory(context, path)
    local target = trim(path)
    if target == "" or target == "." or path_exists(target) then
        return true
    end

    local command
    if is_windows_host() then
        command = "if not exist " .. cmd_quote(target) .. " mkdir " .. cmd_quote(target) .. " >nul 2>nul"
    else
        command = "mkdir -p " .. shell_quote(target)
    end

    return is_command_success(run_command(context, command)) or path_exists(target)
end

local function remove_path_recursive(context, path)
    local target = trim(path)
    if target == "" then
        return true
    end

    local command
    if is_windows_host() then
        command = "rmdir /s /q " .. cmd_quote(target)
    else
        command = "rm -rf " .. shell_quote(target)
    end

    return is_command_success(run_command(context, command), { 1 }) or not path_exists(target)
end

local function basename(path)
    local normalized = tostring(path or ""):gsub("[/\\]+$", "")
    return normalized:match("([^/\\]+)$") or normalized
end

local function strip_extension(path, extension)
    local name = basename(path)
    local suffix = tostring(extension or "")
    if suffix ~= "" and lower(name:sub(-#suffix)) == lower(suffix) then
        return name:sub(1, #name - #suffix)
    end
    return name
end

local function sanitize_path_component(value)
    local text = trim(value):gsub("[^A-Za-z0-9._%-]", "-")
    if text == "" then
        return PLUGIN_ID
    end
    return text
end

local function split_words(value)
    local items = {}
    for item in tostring(value or ""):gmatch("%S+") do
        items[#items + 1] = item
    end
    return items
end

local function object_flags(object)
    local value = read_field(object, "flags")
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end

    local flags = {}
    local ok = pcall(function()
        for _, flag in ipairs(value) do
            flags[#flags + 1] = trim(flag)
        end
    end)
    if not ok then
        return {}
    end

    return flags
end

local function context_flags(context)
    local value = context and context.flags or nil
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end

    local flags = {}
    local ok = pcall(function()
        for _, flag in ipairs(value) do
            flags[#flags + 1] = trim(flag)
        end
    end)
    if not ok then
        return {}
    end

    return flags
end

local function flag_present(flags, token)
    local expected = lower(trim(token))
    for _, flag in ipairs(flags or {}) do
        if lower(trim(flag)) == expected then
            return true
        end
    end
    return false
end

local function flag_value(flags, prefix)
    local normalized_prefix = lower(trim(prefix))
    for _, flag in ipairs(flags or {}) do
        local text = trim(flag)
        if lower(text:sub(1, #normalized_prefix)) == normalized_prefix then
            return trim(text:sub(#normalized_prefix + 1))
        end
    end
    return ""
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageName") or read_field(pkg, "packageId"))
end

local function package_version(pkg)
    return trim(read_field(pkg, "version"))
end

local function package_source(pkg, context)
    local direct = trim(read_field(pkg, "source") or read_field(pkg, "registry") or read_field(pkg, "feed"))
    if direct ~= "" then
        return direct
    end

    local from_flags = flag_value(object_flags(pkg), "source=")
    if from_flags ~= "" then
        return from_flags
    end

    return flag_value(context_flags(context), "source=")
end

local function package_option_flags(pkg, context)
    local merged = {}
    for _, flag in ipairs(context_flags(context)) do
        merged[#merged + 1] = flag
    end
    for _, flag in ipairs(object_flags(pkg)) do
        merged[#merged + 1] = flag
    end
    return merged
end

local function local_path_from_context(context)
    return trim(
        read_field(context, "localPath")
            or read_field(context, "path")
            or read_field(context, "local_path")
    )
end

local function get_plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR)
    if dir ~= "" then
        return dir
    end
    return "."
end

local function get_cache_root(context)
    local override = flag_value(context_flags(context), "cache-root=")
    if override ~= "" then
        return override
    end
    return join_path(get_plugin_dir(), ".reqpack-data", "nuget-cache")
end

local function get_packages_dir(context)
    return join_path(get_cache_root(context), "packages")
end

local function get_local_feed_root(context)
    return join_path(get_cache_root(context), "local-feed")
end

local function looks_like_version(value)
    local text = trim(value)
    if text == "" then
        return false
    end
    return text:match("^%d[%w%._%-%+]*$") ~= nil
end

local function parse_package_line(line)
    local text = trim(line)
    if text == "" then
        return nil
    end

    local prefix = lower(text)
    if prefix:match("^warning")
        or prefix:match("^feeds used")
        or prefix:match("^installed:")
        or prefix:match("^attempting")
        or prefix:match("^gathering")
        or prefix:match("^using")
        or prefix:match("^no packages found")
        or prefix:match("^all packages listed")
        or prefix:match("^the source") then
        return nil
    end

    local parts = split_words(text)
    if #parts < 2 then
        return nil
    end

    local name = parts[1]
    local version = parts[2]
    if not looks_like_version(version) then
        return nil
    end

    local summary
    if #parts > 2 then
        summary = table.concat(parts, " ", 3)
    end

    return {
        name = name,
        packageId = name,
        version = version,
        summary = trim(summary),
    }
end

local function parse_package_lines(output)
    local items = {}
    for _, line in ipairs(split_lines(output)) do
        local item = parse_package_line(line)
        if item ~= nil then
            items[#items + 1] = item
        end
    end
    return items
end

local function parse_locals_output(output)
    local result = {}
    for _, line in ipairs(split_lines(output)) do
        local key, value = line:match("^(.-):%s*(.+)$")
        if key ~= nil and value ~= nil then
            result[lower(trim(key))] = trim(value)
        end
    end
    return result
end

local function sort_items(items)
    table.sort(items, function(left, right)
        local left_name = lower(left and left.name or "")
        local right_name = lower(right and right.name or "")
        if left_name == right_name then
            return lower(left and left.version or "") < lower(right and right.version or "")
        end
        return left_name < right_name
    end)
end

local function installed_path_for_item(context, item)
    local name = trim(item and item.name or "")
    local version = trim(item and item.version or "")
    if name == "" then
        return nil
    end

    local packages_dir = get_packages_dir(context)
    if version ~= "" then
        return join_path(packages_dir, name .. "." .. version)
    end

    return join_path(packages_dir, name)
end

local function collect_cache_metadata(context)
    local metadata = {
        reqpackRoot = get_cache_root(context),
        reqpackPackages = get_packages_dir(context),
    }

    local result = run_command(context, ENV_PREFIX .. " " .. build_command({
        REQUIRED_BINARY,
        "locals",
        "all",
        "-List",
        "-NonInteractive",
        "-ForceEnglishOutput",
    }))

    if is_command_success(result) then
        local parsed = parse_locals_output(result.stdout)
        for key, value in pairs(parsed) do
            metadata[key] = value
        end
    end

    return metadata
end

local function query_list(context, search_term, source, include_prerelease)
    local args = { REQUIRED_BINARY, "list" }
    local term = trim(search_term)
    if term ~= "" then
        args[#args + 1] = term
    end
    args[#args + 1] = "-AllVersions"
    if include_prerelease then
        args[#args + 1] = "-PreRelease"
    end
    if trim(source) ~= "" then
        args[#args + 1] = "-Source"
        args[#args + 1] = source
    end
    args[#args + 1] = "-NonInteractive"
    args[#args + 1] = "-ForceEnglishOutput"

    local result = run_command(context, ENV_PREFIX .. " " .. build_command(args))
    if not is_command_success(result, { 1 }) then
        return {}
    end

    return parse_package_lines(result.stdout)
end

local function query_search(context, prompt, source, include_prerelease)
    local term = trim(prompt)
    if term == "" then
        return {}
    end

    local args = { REQUIRED_BINARY, "search", term, "-Take", tostring(SEARCH_LIMIT) }
    if include_prerelease then
        args[#args + 1] = "-PreRelease"
    end
    if trim(source) ~= "" then
        args[#args + 1] = "-Source"
        args[#args + 1] = source
    end
    args[#args + 1] = "-NonInteractive"

    local result = run_command(context, ENV_PREFIX .. " " .. build_command(args))
    if not is_command_success(result, { 1 }) then
        return {}
    end

    return parse_package_lines(result.stdout)
end

local function local_installed_items(context, name)
    local packages_dir = get_packages_dir(context)
    local items = query_list(context, name, packages_dir, true)
    local expected_name = lower(trim(name))
    local caches = collect_cache_metadata(context)
    local filtered = {}

    for _, item in ipairs(items) do
        if expected_name == "" or lower(item.name) == expected_name then
            local enriched = shallow_copy(item)
            enriched.installed = true
            enriched.source = packages_dir
            enriched.installedPath = installed_path_for_item(context, item)
            enriched.cache = shallow_copy(caches)
            filtered[#filtered + 1] = enriched
        end
    end

    sort_items(filtered)
    return filtered
end

local function remote_items_for_name(context, name)
    local source = flag_value(context_flags(context), "source=")
    local prerelease = flag_present(context_flags(context), "prerelease")
    local items = query_list(context, name, source, prerelease)
    local exact = {}
    local target = lower(trim(name))

    for _, item in ipairs(items) do
        if lower(item.name) == target then
            exact[#exact + 1] = item
        end
    end

    if #exact > 0 then
        return exact
    end

    return items
end

local function best_item(items, requested_version)
    local version = trim(requested_version)
    if version ~= "" then
        for _, item in ipairs(items or {}) do
            if trim(item.version) == version then
                return item
            end
        end
    end

    return items and items[1] or nil
end

local function install_command(pkg, context, source_override)
    local name = package_name(pkg)
    local version = package_version(pkg)
    local source = trim(source_override or package_source(pkg, context))
    local flags = package_option_flags(pkg, context)
    local save_mode = flag_value(flags, "save=")
    local args = { REQUIRED_BINARY, "install", name, "-OutputDirectory", get_packages_dir(context) }

    if version ~= "" then
        args[#args + 1] = "-Version"
        args[#args + 1] = version
    end
    if source ~= "" then
        args[#args + 1] = "-Source"
        args[#args + 1] = source
    end
    if flag_present(flags, "prerelease") then
        args[#args + 1] = "-PreRelease"
    end
    if flag_present(flags, "directdownload") then
        args[#args + 1] = "-DirectDownload"
    end
    if flag_present(flags, "excludeversion") then
        args[#args + 1] = "-ExcludeVersion"
    end
    if save_mode ~= "" then
        args[#args + 1] = "-PackageSaveMode"
        args[#args + 1] = save_mode
    end
    args[#args + 1] = "-NonInteractive"
    args[#args + 1] = "-ForceEnglishOutput"

    return ENV_PREFIX .. " " .. build_command(args)
end

local function install_one_package(context, pkg, source_override)
    local name = package_name(pkg)
    if name == "" then
        return false
    end

    if not ensure_directory(context, get_packages_dir(context)) then
        return false
    end

    local result = run_command(context, install_command(pkg, context, source_override))
    return is_command_success(result)
end

local function make_temp_feed_dir(context, local_path)
    return join_path(get_local_feed_root(context), sanitize_path_component(strip_extension(local_path, ".nupkg")))
end

local function derive_package_from_filename(path)
    local stem = strip_extension(path, ".nupkg")
    local best_name = stem
    local best_version = ""

    for index = 1, #stem do
        if stem:sub(index, index) == "." then
            local name = stem:sub(1, index - 1)
            local version = stem:sub(index + 1)
            if name ~= "" and version:match("^%d[%w%._%-%+]*$") then
                best_name = name
                best_version = version
                break
            end
        end
    end

    return {
        name = best_name,
        version = best_version,
    }
end

local function stage_local_package(context, local_path)
    local feed_dir = make_temp_feed_dir(context, local_path)
    if not ensure_directory(context, feed_dir) then
        return nil, nil
    end

    local args = {
        REQUIRED_BINARY,
        "add",
        local_path,
        "-Source",
        feed_dir,
        "-Expand",
        "-NonInteractive",
        "-ForceEnglishOutput",
    }

    local result = run_command(context, ENV_PREFIX .. " " .. build_command(args))
    if not is_command_success(result) then
        return nil, nil
    end

    local items = query_list(context, "", feed_dir, true)
    if #items == 0 then
        local fallback = derive_package_from_filename(local_path)
        items = { { name = fallback.name, packageId = fallback.name, version = fallback.version } }
    end

    return feed_dir, best_item(items, "")
end

local function remove_packages_from_cache(context, packages)
    local ok = true

    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        local version = package_version(pkg)
        local installed = local_installed_items(context, name)

        for _, item in ipairs(installed) do
            if version == "" or trim(item.version) == version then
                local target = installed_path_for_item(context, item)
                if target ~= nil and not remove_path_recursive(context, target) then
                    ok = false
                end
            end
        end
    end

    return ok
end

local function info_item(context, name)
    local installed = local_installed_items(context, name)
    local remote_versions = remote_items_for_name(context, name)
    local remote_search = query_search(context, name, flag_value(context_flags(context), "source="), flag_present(context_flags(context), "prerelease"))
    local base = shallow_copy(best_item(installed, "") or best_item(remote_versions, "") or best_item(remote_search, "") or {})

    if #installed > 0 then
        base.installed = true
        base.installedPath = installed[1].installedPath
    end

    if trim(base.summary or "") == "" and remote_search[1] ~= nil then
        base.summary = remote_search[1].summary
    end

    local installed_versions = {}
    for _, item in ipairs(installed) do
        installed_versions[#installed_versions + 1] = item.version
    end

    local remote_version_list = {}
    for _, item in ipairs(remote_versions) do
        remote_version_list[#remote_version_list + 1] = item.version
    end

    base.installedVersions = installed_versions
    base.remoteVersions = remote_version_list
    base.cache = collect_cache_metadata(context)
    return base
end

local function info_matches_request(pkg, item)
    if type(item) ~= "table" then
        return false
    end

    local requested_name = lower(package_name(pkg))
    local requested_version = trim(package_version(pkg))
    local item_name = lower(trim(item.name or item.packageId or ""))
    local item_version = trim(item.version)

    if requested_name == "" or item_name == "" or requested_name ~= item_name then
        return false
    end

    if requested_version ~= "" and requested_version ~= item_version then
        return false
    end

    return true
end

plugin.fileExtensions = { ".nupkg" }

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
    return { "Cross Platform", "Dotnet", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    local missing = {}

    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        local version = package_version(pkg)
        local action = lower(trim(read_field(pkg, "action")))
        local installed = local_installed_items(nil, name)
        local matched = best_item(installed, version)

        if name ~= "" then
            if action == "update" then
                missing[#missing + 1] = pkg
            elseif action == "remove" then
                if matched ~= nil or (#installed > 0 and version == "") then
                    missing[#missing + 1] = pkg
                end
            elseif matched == nil then
                missing[#missing + 1] = pkg
            end
        end
    end

    return missing
end

function plugin.install(context, packages)
    local local_path = local_path_from_context(context)
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end

    if packages == nil or #packages == 0 then
        return true
    end

    begin_step(context, "install nuget packages")

    for _, pkg in ipairs(packages or {}) do
        if not install_one_package(context, pkg) then
            tx_failed(context, "nuget install failed")
            return false
        end
    end

    emit_event(context, "installed", packages)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" or lower(local_path:sub(-6)) ~= ".nupkg" then
        tx_failed(context, "nuget local install failed")
        return false
    end

    begin_step(context, "install local nuget package")

    local feed_dir, package_item = stage_local_package(context, local_path)
    if feed_dir == nil or package_item == nil or trim(package_item.name) == "" then
        tx_failed(context, "nuget local install failed")
        return false
    end

    if not install_one_package(context, package_item, feed_dir) then
        tx_failed(context, "nuget local install failed")
        return false
    end

    emit_event(context, "installed", {
        path = local_path,
        name = package_item.name,
        version = package_item.version,
        localTarget = true,
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    if packages == nil or #packages == 0 then
        return true
    end

    begin_step(context, "remove nuget packages")
    if not remove_packages_from_cache(context, packages) then
        tx_failed(context, "nuget remove failed")
        return false
    end

    emit_event(context, "deleted", packages)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    if packages == nil or #packages == 0 then
        return true
    end

    begin_step(context, "refresh nuget packages")

    for _, pkg in ipairs(packages or {}) do
        if not install_one_package(context, pkg) then
            tx_failed(context, "nuget update failed")
            return false
        end
    end

    emit_event(context, "updated", packages)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = local_installed_items(context, "")
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items = {}
    log_warn(context, "NuGet CLI has no reliable cache-wide outdated query for ReqPack shared cache model")
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local items = query_search(
        context,
        prompt,
        flag_value(context_flags(context), "source="),
        flag_present(context_flags(context), "prerelease")
    )
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local package_name_value = trim(name)
    local item = {}

    if package_name_value ~= "" then
        item = info_item(context, package_name_value)
    end

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == "" then
        return nil
    end

    local item = info_item(context, name)
    if not info_matches_request(package, item) then
        return nil
    end

    return {
        name = item.name,
        packageId = item.packageId or item.name,
        version = item.version,
        summary = item.summary,
        description = item.description,
        source = item.source,
        installed = item.installed,
        installedPath = item.installedPath,
        cache = item.cache,
        remoteVersions = item.remoteVersions,
        installedVersions = item.installedVersions,
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "filesystem.write", "filesystem.read" },
        ecosystemScopes = { "nuget" },
        writeScopes = {
            {
                path = join_path(get_plugin_dir(), ".reqpack-data", "nuget-cache"),
                reason = "ReqPack-managed NuGet shared cache and local feed staging",
            },
        },
        networkScopes = {
            {
                scheme = "https",
                host = "*",
                reason = "NuGet package feeds are request-defined",
            },
        },
        privilegeLevel = "none",
        osvEcosystem = "NuGet",
        purlType = "nuget",
    }
end

function plugin.init()
    return command_exists(REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

return plugin
