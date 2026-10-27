plugin = {}

local PLUGIN_ID = "zef"
local PLUGIN_NAME = "zef"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "zef"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return trim(value):lower()
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function split_lines(value)
    local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = {}
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(select(index, ...) or "")
        if part ~= "" then
            if #parts == 0 then
                parts[#parts + 1] = part:gsub("/+$", "")
            else
                parts[#parts + 1] = part:gsub("^/+", ""):gsub("/+$", "")
            end
        end
    end
    if #parts == 0 then
        return "."
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

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil then
            if type(value) == "string" then
                local cleaned = trim(value)
                if cleaned ~= "" then
                    return cleaned
                end
            else
                return value
            end
        end
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

local function get_reqpack_path(name)
    local paths = type(reqpack) == "table" and read_field(reqpack, "paths") or nil
    if type(paths) ~= "table" then
        return nil
    end
    return first_nonempty(read_field(paths, name))
end

local function get_plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR or "")
    if dir ~= "" then
        return dir
    end
    return join_path("z", "zef")
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

local function collect_flags(context, packages)
    local result = {}
    local seen = {}

    local function add_from(object)
        for _, flag in ipairs(object_flags(object)) do
            if not seen[flag] then
                seen[flag] = true
                result[#result + 1] = flag
            end
        end
    end

    add_from(context)
    add_from(read_field(context, "request"))
    for _, pkg in ipairs(packages or {}) do
        add_from(pkg)
    end
    return result
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

local function has_flag(flags, key)
    local wanted = lower(trim(key))
    for _, flag in ipairs(flags or {}) do
        if lower(trim(flag)) == wanted then
            return true
        end
    end
    return false
end

local function runtime_paths(flags)
    local data_root = first_nonempty(
        flag_value(flags, "data-root"),
        get_reqpack_path("dataRoot") and join_path(get_reqpack_path("dataRoot"), PLUGIN_ID),
        join_path(get_plugin_dir(), ".reqpack-data")
    )
    local cache_root = first_nonempty(
        flag_value(flags, "cache-root"),
        get_reqpack_path("cacheRoot") and join_path(get_reqpack_path("cacheRoot"), PLUGIN_ID),
        join_path(get_plugin_dir(), ".reqpack-cache")
    )
    local install_root = join_path(data_root, "cur")
    return {
        dataRoot = data_root,
        cacheRoot = cache_root,
        installRoot = install_root,
        installTo = "inst#" .. install_root,
        storeRoot = join_path(cache_root, "store"),
        tempRoot = join_path(cache_root, "temp"),
    }
end

local function ensure_runtime_dirs(context, paths)
    local command = "mkdir -p " .. shell_quote(paths.installRoot) .. " " .. shell_quote(paths.storeRoot) .. " " .. shell_quote(paths.tempRoot)
    local result = exec_run(context, command)
    if result ~= nil and result.success then
        return true, nil
    end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to create zef runtime directories")
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function zef_env_prefix(paths)
    return table.concat({
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
        "NO_COLOR='1'",
        "RAKULIB=" .. shell_quote(paths.installTo),
        "ZEF_INSTALL_TO=" .. shell_quote(paths.installTo),
        "ZEF_CONFIG_STOREDIR=" .. shell_quote(paths.storeRoot),
        "ZEF_CONFIG_TEMPDIR=" .. shell_quote(paths.tempRoot),
    }, " ")
end

local function zef_command(paths, args)
    local parts = { zef_env_prefix(paths), shell_quote(REQUIRED_BINARY) }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = shell_quote(arg)
    end
    return table.concat(parts, " ")
end

local function parse_identity(identity)
    local raw = trim(identity)
    local item = {
        identity = raw,
        name = raw,
        version = nil,
        auth = nil,
        api = nil,
    }
    if raw == "" then
        return item
    end
    item.version = raw:match(":ver<([^>]+)>")
    item.auth = raw:match(":auth<([^>]+)>")
    item.api = raw:match(":api<([^>]+)>")
    item.name = trim(raw:gsub(":ver<[^>]+>", ""):gsub(":auth<[^>]+>", ""):gsub(":api<[^>]+>", ""))
    return item
end

local function identity_string(name, version)
    local cleaned = trim(name)
    if cleaned == "" then
        return ""
    end
    if cleaned:find(":ver<", 1, true) ~= nil or trim(version) == "" then
        return cleaned
    end
    return cleaned .. ":ver<" .. trim(version) .. ">"
end

local function package_identity(pkg)
    local name = first_nonempty(read_field(pkg, "name"), read_field(pkg, "packageId"), read_field(pkg, "packageName"))
    if name == nil then
        return ""
    end
    return identity_string(name, read_field(pkg, "version"))
end

local function package_name(pkg)
    local identity = package_identity(pkg)
    return parse_identity(identity).name
end

local function with_runtime_fields(item, paths)
    if type(item) ~= "table" then
        return item
    end
    item.extraFields = shallow_copy(type(item.extraFields) == "table" and item.extraFields or {})
    item.extraFields.installRoot = paths.installRoot
    item.extraFields.storeRoot = paths.storeRoot
    item.extraFields.tempRoot = paths.tempRoot
    return item
end

local function sort_items(items)
    table.sort(items, function(left, right)
        local left_key = lower(first_nonempty(left.name, left.packageId, left.version) or "")
        local right_key = lower(first_nonempty(right.name, right.packageId, right.version) or "")
        if left_key == right_key then
            return lower(left.version or "") < lower(right.version or "")
        end
        return left_key < right_key
    end)
    return items
end

local function split_pipe_fields(line)
    local fields = {}
    for field in (tostring(line or "") .. "|"):gmatch("(.-)|") do
        fields[#fields + 1] = trim(field)
    end
    return fields
end

local function parse_list_output(stdout, paths)
    local items = {}
    local found_via = nil
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned:match("^===>%s+Found via%s+") then
            found_via = trim(cleaned:gsub("^===>%s+Found via%s+", "", 1))
        elseif cleaned ~= "" and not cleaned:match("^===>") then
            local identity = parse_identity(cleaned)
            local item = {
                name = identity.name,
                packageId = identity.identity,
                version = identity.version,
                latestVersion = identity.version,
                installed = true,
                status = "installed",
                repository = found_via,
                packageType = "raku-distribution",
                type = "package",
            }
            items[#items + 1] = with_runtime_fields(item, paths)
        end
    end
    return sort_items(items)
end

local function parse_search_output(stdout, paths)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned:match("^%d+%s*|") or cleaned:match("^%d+%s*%|") then
            local fields = split_pipe_fields(cleaned)
            local identity = parse_identity(fields[3] or "")
            if identity.identity ~= "" then
                local item = {
                    name = identity.name,
                    packageId = identity.identity,
                    version = identity.version,
                    latestVersion = identity.version,
                    installed = false,
                    status = "available",
                    repository = fields[2],
                    summary = fields[4],
                    description = fields[4],
                    packageType = "raku-distribution",
                    type = "package",
                }
                items[#items + 1] = with_runtime_fields(item, paths)
            end
        end
    end
    return sort_items(items)
end

local function parse_info_output(stdout, paths)
    local item = {
        installed = false,
        status = "available",
        packageType = "raku-distribution",
        type = "package",
        extraFields = {},
    }

    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned:match("^%- Info for:%s*") then
            item.name = trim(cleaned:gsub("^%- Info for:%s*", "", 1))
        elseif cleaned:match("^%- Identity:%s*") then
            local identity_text = trim(cleaned:gsub("^%- Identity:%s*", "", 1))
            local identity = parse_identity(identity_text)
            item.packageId = identity.identity
            item.name = first_nonempty(identity.name, item.name)
            item.version = identity.version
            item.latestVersion = identity.version
            item.extraFields.auth = identity.auth
            item.extraFields.api = identity.api
        elseif cleaned:match("^%- Recommended By:%s*") then
            item.repository = trim(cleaned:gsub("^%- Recommended By:%s*", "", 1))
        elseif cleaned:match("^%- Installed:%s*") then
            local installed = lower(cleaned:gsub("^%- Installed:%s*", "", 1))
            item.installed = installed == "yes"
            item.status = item.installed and "installed" or "available"
        else
            local key, value = cleaned:match("^([A-Za-z][A-Za-z%-]+):%s*(.*)$")
            if key ~= nil then
                if key == "Description" then
                    item.summary = value
                    item.description = value
                elseif key == "License" then
                    item.license = value
                elseif key == "Source-url" then
                    item.sourceUrl = value
                elseif key == "Homepage" then
                    item.homepage = value
                elseif key == "Provides" then
                    item.extraFields.provides = value
                elseif key == "Depends" then
                    item.extraFields.depends = value
                end
            elseif cleaned:match("^#%s+source:%s*") then
                item.repositoryUrl = trim(cleaned:gsub("^#%s+source:%s*", "", 1))
            elseif cleaned:match("^#%s+bugtracker:%s*") then
                item.extraFields.bugtracker = trim(cleaned:gsub("^#%s+bugtracker:%s*", "", 1))
            end
        end
    end

    if next(item.extraFields) == nil then
        item.extraFields = nil
    end
    if first_nonempty(item.name, item.packageId, item.version, item.description, item.repository) == nil then
        return {}
    end
    return with_runtime_fields(item, paths)
end

local function find_installed_item(items, prompt)
    local cleaned = trim(prompt)
    if cleaned == "" then
        return nil
    end
    local wanted = parse_identity(cleaned)
    for _, item in ipairs(items or {}) do
        if trim(item.packageId or "") == cleaned then
            return item
        end
        if trim(item.name or "") == cleaned then
            return item
        end
        if wanted.name ~= "" and trim(item.name or "") == wanted.name then
            if wanted.version == nil or wanted.version == "" or trim(item.version or "") == wanted.version then
                return item
            end
        end
    end
    return nil
end

local function query_installed(context, paths)
    local ok, dir_error = ensure_runtime_dirs(context, paths)
    if not ok then
        return nil, dir_error
    end
    local result = exec_run(context, zef_command(paths, { "--installed", "list" }))
    if result == nil or not result.success then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "zef list failed")
    end
    return parse_list_output(result.stdout, paths), nil
end

local function query_info(context, paths, prompt)
    local ok, dir_error = ensure_runtime_dirs(context, paths)
    if not ok then
        return nil, dir_error
    end
    local installed_items = query_installed(context, paths)
    local installed_item = type(installed_items) == "table" and find_installed_item(installed_items, prompt) or nil

    local result = exec_run(context, zef_command(paths, { "info", trim(prompt), "-v" }))
    if result == nil or not result.success then
        if installed_item ~= nil then
            return installed_item, nil
        end
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "zef info failed")
    end

    local item = parse_info_output(result.stdout, paths)
    if installed_item ~= nil then
        item.installed = true
        if trim(installed_item.version or "") ~= "" and trim(item.version or "") ~= "" and trim(installed_item.version or "") ~= trim(item.version or "") then
            item.latestVersion = item.version
            item.version = installed_item.version
            item.status = "outdated"
        else
            item.version = first_nonempty(installed_item.version, item.version)
            item.latestVersion = first_nonempty(item.latestVersion, item.version)
            item.status = "installed"
        end
    end
    return item, nil
end

local function query_search(context, paths, prompt)
    local ok, dir_error = ensure_runtime_dirs(context, paths)
    if not ok then
        return nil, dir_error
    end
    local result = exec_run(context, zef_command(paths, { "search", trim(prompt) }))
    if result == nil or not result.success then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "zef search failed")
    end
    return parse_search_output(result.stdout, paths), nil
end

local function query_outdated(context, paths)
    local installed_items, list_error = query_installed(context, paths)
    if installed_items == nil then
        return nil, list_error
    end
    local outdated = {}
    for _, item in ipairs(installed_items or {}) do
        local info_item = query_info(context, paths, item.name)
        if type(info_item) == "table" and next(info_item) ~= nil and trim(info_item.latestVersion or "") ~= "" and trim(info_item.version or "") ~= "" and trim(info_item.latestVersion or "") ~= trim(info_item.version or "") then
            outdated[#outdated + 1] = info_item
        end
    end
    return sort_items(outdated), nil
end

local function install_args_for_flags(flags)
    local args = {}
    if has_flag(flags, "force") then
        args[#args + 1] = "--force"
    end
    if has_flag(flags, "contained") then
        args[#args + 1] = "--contained"
    end
    if has_flag(flags, "serial") then
        args[#args + 1] = "--serial"
    end
    if has_flag(flags, "no-test") or has_flag(flags, "notest") then
        args[#args + 1] = "--/test"
    end
    if has_flag(flags, "no-build") or has_flag(flags, "nobuild") then
        args[#args + 1] = "--/build"
    end
    if has_flag(flags, "no-depends") or has_flag(flags, "nodeps") then
        args[#args + 1] = "--/depends"
    end
    if has_flag(flags, "dry") then
        args[#args + 1] = "--dry"
    end
    local update_value = flag_value(flags, "update")
    if update_value ~= nil and update_value ~= "" then
        args[#args + 1] = "--update=" .. update_value
    elseif has_flag(flags, "update") then
        args[#args + 1] = "--update"
    end
    for _, key in ipairs({ "timeout", "fetch-timeout", "extract-timeout", "build-timeout", "test-timeout", "install-timeout", "fetch-degree", "test-degree" }) do
        local value = flag_value(flags, key)
        if value ~= nil and value ~= "" then
            args[#args + 1] = "--" .. key .. "=" .. value
        end
    end
    return args
end

local function failure_message(result, fallback)
    return first_nonempty(result and result.stderr, result and result.stdout, fallback)
end

plugin.fileExtensions = { ".tgz", ".tar.gz", ".zip" }

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
    return { "programming-language", "package-manager", "raku" }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end
    if not command_exists(nil, REQUIRED_BINARY) then
        local missing = {}
        for _, pkg in ipairs(packages) do
            local action = lower(read_field(pkg, "action") or "")
            if action ~= "remove" and action ~= "update" then
                missing[#missing + 1] = pkg
            end
        end
        return missing
    end

    local flags = collect_flags(nil, packages)
    local paths = runtime_paths(flags)
    local installed_items = query_installed(nil, paths) or {}
    local outdated_items = query_outdated(nil, paths) or {}
    local missing = {}

    for _, pkg in ipairs(packages or {}) do
        local action = lower(read_field(pkg, "action") or "")
        local identity = package_identity(pkg)
        local installed_item = find_installed_item(installed_items, identity)
        local outdated_item = find_installed_item(outdated_items, identity)
        if action == "remove" then
            if installed_item ~= nil then
                missing[#missing + 1] = pkg
            end
        elseif action == "update" then
            if outdated_item ~= nil then
                missing[#missing + 1] = pkg
            end
        elseif installed_item == nil then
            missing[#missing + 1] = pkg
        end
    end

    return missing
end

function plugin.install(context, packages)
    local request = read_field(context, "request") or {}
    local requested = packages or read_field(request, "packages") or {}
    if read_field(request, "localPath") ~= nil or read_field(context, "localPath") ~= nil then
        return plugin.installLocal(context, read_field(request, "localPath") or read_field(context, "localPath"))
    end
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "zef binary not available")
        return false
    end

    local flags = collect_flags(context, requested)
    local paths = runtime_paths(flags)
    local ok, dir_error = ensure_runtime_dirs(context, paths)
    if not ok then
        tx_failed(context, dir_error)
        return false
    end

    for _, pkg in ipairs(requested) do
        local identity = package_identity(pkg)
        if identity == "" then
            tx_failed(context, "missing zef package identity")
            return false
        end
        begin_step(context, "install zef package " .. identity)
        local args = { "install" }
        for _, arg in ipairs(install_args_for_flags(flags)) do
            args[#args + 1] = arg
        end
        args[#args + 1] = identity
        local result = exec_run(context, zef_command(paths, args))
        if result == nil or not result.success then
            tx_failed(context, failure_message(result, "zef install failed"))
            return false
        end
        emit_event(context, "installed", with_runtime_fields({
            name = parse_identity(identity).name,
            packageId = identity,
            version = parse_identity(identity).version,
            installed = true,
            status = "installed",
            packageType = "raku-distribution",
        }, paths))
    end

    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path or read_field(read_field(context, "request") or {}, "localPath") or read_field(context, "localPath") or "")
    if local_path == "" then
        tx_failed(context, "missing local zef path")
        return false
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "zef binary not available")
        return false
    end

    local flags = collect_flags(context, {})
    local paths = runtime_paths(flags)
    local ok, dir_error = ensure_runtime_dirs(context, paths)
    if not ok then
        tx_failed(context, dir_error)
        return false
    end

    begin_step(context, "install local zef package")
    local result = exec_run(context, zef_command(paths, { "install", local_path }))
    if result == nil or not result.success then
        tx_failed(context, failure_message(result, "zef local install failed"))
        return false
    end
    emit_event(context, "installed", with_runtime_fields({
        localTarget = true,
        path = local_path,
        installed = true,
        status = "installed",
        packageType = "raku-distribution",
    }, paths))
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local request = read_field(context, "request") or {}
    local requested = packages or read_field(request, "packages") or {}
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "zef binary not available")
        return false
    end

    local flags = collect_flags(context, requested)
    local paths = runtime_paths(flags)
    local ok, dir_error = ensure_runtime_dirs(context, paths)
    if not ok then
        tx_failed(context, dir_error)
        return false
    end

    for _, pkg in ipairs(requested) do
        local identity = first_nonempty(package_name(pkg), package_identity(pkg))
        if identity == nil or identity == "" then
            tx_failed(context, "missing zef package identity")
            return false
        end
        begin_step(context, "remove zef package " .. identity)
        local result = exec_run(context, zef_command(paths, { "uninstall", identity }))
        if result == nil or not result.success then
            tx_failed(context, failure_message(result, "zef uninstall failed"))
            return false
        end
        emit_event(context, "deleted", with_runtime_fields({
            name = parse_identity(identity).name,
            packageId = identity,
            installed = false,
            status = "removed",
            packageType = "raku-distribution",
        }, paths))
    end

    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local request = read_field(context, "request") or {}
    local requested = packages or read_field(request, "packages") or {}
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "zef binary not available")
        return false
    end

    local flags = collect_flags(context, requested)
    local paths = runtime_paths(flags)
    local ok, dir_error = ensure_runtime_dirs(context, paths)
    if not ok then
        tx_failed(context, dir_error)
        return false
    end

    begin_step(context, "update zef indexes")
    local update_result = exec_run(context, zef_command(paths, { "update" }))
    if update_result == nil or not update_result.success then
        tx_failed(context, failure_message(update_result, "zef update failed"))
        return false
    end

    if #requested == 0 then
        begin_step(context, "upgrade zef packages")
        local result = exec_run(context, zef_command(paths, { "upgrade" }))
        if result == nil or not result.success then
            tx_failed(context, failure_message(result, "zef upgrade failed"))
            return false
        end
        emit_event(context, "updated", with_runtime_fields({
            name = "*",
            packageId = "*",
            status = "updated",
            packageType = "raku-distribution",
        }, paths))
        tx_success(context)
        return true
    end

    for _, pkg in ipairs(requested) do
        local identity = first_nonempty(package_name(pkg), package_identity(pkg))
        if identity == nil or identity == "" then
            tx_failed(context, "missing zef package identity")
            return false
        end
        begin_step(context, "upgrade zef package " .. identity)
        local result = exec_run(context, zef_command(paths, { "upgrade", identity }))
        if result == nil or not result.success then
            tx_failed(context, failure_message(result, "zef upgrade failed"))
            return false
        end
        emit_event(context, "updated", with_runtime_fields({
            name = parse_identity(identity).name,
            packageId = identity,
            status = "updated",
            packageType = "raku-distribution",
        }, paths))
    end

    tx_success(context)
    return true
end

function plugin.list(context)
    if not command_exists(context, REQUIRED_BINARY) then
        log_warn(context, "zef binary not available")
        emit_event(context, "listed", {})
        return {}
    end
    local flags = collect_flags(context, {})
    local paths = runtime_paths(flags)
    local items, err = query_installed(context, paths)
    if items == nil then
        log_warn(context, err or "zef list failed")
        emit_event(context, "listed", {})
        return {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    if not command_exists(context, REQUIRED_BINARY) then
        log_warn(context, "zef binary not available")
        emit_event(context, "outdated", {})
        return {}
    end
    local flags = collect_flags(context, {})
    local paths = runtime_paths(flags)
    local items, err = query_outdated(context, paths)
    if items == nil then
        log_warn(context, err or "zef outdated check failed")
        emit_event(context, "outdated", {})
        return {}
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(read_field(context, "request") or {}, "prompt") or "")
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end
    if not command_exists(context, REQUIRED_BINARY) then
        log_warn(context, "zef binary not available")
        emit_event(context, "searched", {})
        return {}
    end
    local flags = collect_flags(context, {})
    local paths = runtime_paths(flags)
    local items, err = query_search(context, paths, query)
    if items == nil then
        log_warn(context, err or "zef search failed")
        emit_event(context, "searched", {})
        return {}
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local prompt = trim(name or read_field(read_field(context, "request") or {}, "prompt") or "")
    if prompt == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    if not command_exists(context, REQUIRED_BINARY) then
        log_warn(context, "zef binary not available")
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local flags = collect_flags(context, {})
    local paths = runtime_paths(flags)
    local item, err = query_info(context, paths, prompt)
    if item == nil then
        log_warn(context, err or "zef info failed")
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local identity = package_identity(package)
    if identity == "" then
        return nil
    end
    local item = plugin.info(context, identity)
    if type(item) == "table" and next(item) ~= nil then
        return item
    end
    return {
        name = parse_identity(identity).name,
        packageId = identity,
        version = parse_identity(identity).version,
        packageType = "raku-distribution",
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "raku", "zef" },
        writeScopes = {
            { kind = "plugin-subpath", path = ".reqpack-data" },
            { kind = "plugin-subpath", path = ".reqpack-cache" },
        },
        privilegeLevel = "user",
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
