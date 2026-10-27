plugin = {}

plugin.fileExtensions = {}

local PLUGIN_ID = "carbon"
local PLUGIN_NAME = "Carbon"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "carbon"

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

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        local cleaned = non_empty(value)
        if cleaned ~= nil then
            return cleaned
        end
    end
    return nil
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

local function split_columns(line)
    local columns = {}
    for field in tostring(line or ""):gmatch("([^%s].-)%s%s+") do
        columns[#columns + 1] = trim(field)
    end
    local tail = trim(tostring(line or ""):match(".*%s%s+([^%s].-)$") or "")
    if tail ~= "" and (#columns == 0 or columns[#columns] ~= tail) then
        columns[#columns + 1] = tail
    end
    if #columns == 0 then
        for field in tostring(line or ""):gmatch("%S+") do
            columns[#columns + 1] = field
        end
    end
    return columns
end

local function split_words(line)
    local columns = {}
    for field in tostring(line or ""):gmatch("%S+") do
        columns[#columns + 1] = field
    end
    return columns
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
    return table.concat(parts, "/")
end

local function dirname(path)
    return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
end

local function shallow_copy(value)
    local copy = {}
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return copy
    end
    local ok = pcall(function()
        for key, item in pairs(value) do
            copy[key] = item
        end
    end)
    if not ok then
        return {}
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

local function sequence_values(value)
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local items = {}
    local ok = pcall(function()
        for _, item in ipairs(value) do
            items[#items + 1] = item
        end
    end)
    if not ok then
        return {}
    end
    return items
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

    local function merge_value(value)
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

local function is_success(result)
    return type(result) == "table" and (result.success == true or result.exitCode == 0)
end

local function command_exists(context, binary)
    return is_success(exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function object_flags(value)
    local flags = {}
    for _, item in ipairs(sequence_values(read_field(value, "flags"))) do
        local cleaned = trim(item)
        if cleaned ~= "" then
            flags[#flags + 1] = cleaned
        end
    end
    return flags
end

local function request_object(context)
    return read_field(context, "request")
end

local function request_packages(context, fallback)
    return sequence_values(read_field(request_object(context), "packages") or read_field(context, "packages") or fallback or {})
end

local function request_prompt(context, fallback)
    return first_nonempty(fallback, read_field(request_object(context), "prompt"), read_field(context, "prompt")) or ""
end

local function request_local_path(context, fallback)
    return first_nonempty(
        fallback,
        read_field(request_object(context), "localPath"),
        read_field(request_object(context), "path"),
        read_field(context, "localPath"),
        read_field(context, "path")
    )
end

local function collect_flags(context, packages)
    local flags = {}
    local seen = {}

    local function add_from(object)
        for _, raw in ipairs(object_flags(object)) do
            local cleaned = trim(raw)
            if cleaned ~= "" and not seen[cleaned] then
                seen[cleaned] = true
                flags[#flags + 1] = cleaned
            end
        end
    end

    add_from(context)
    add_from(request_object(context))
    for _, pkg in ipairs(packages or {}) do
        add_from(pkg)
    end
    return flags
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

local function flag_values(flags, key)
    local values = {}
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        local lowered = lower(cleaned)
        if lowered:sub(1, #prefix) == prefix then
            local value = trim(cleaned:sub(#prefix + 1))
            if value ~= "" then
                values[#values + 1] = value
            end
        end
    end
    return values
end

local function flag_value(flags, key)
    local values = flag_values(flags, key)
    return values[#values]
end

local function get_reqpack_path(name)
    local paths = type(reqpack) == "table" and read_field(reqpack, "paths") or nil
    if type(paths) ~= "table" then
        return nil
    end
    return non_empty(read_field(paths, name))
end

local function env_value(name)
    if os ~= nil and type(os.getenv) == "function" then
        return non_empty(os.getenv(name))
    end
    return nil
end

local function xdg_root(kind)
    local home = env_value("HOME") or "/home/test"
    if kind == "data" then
        return env_value("XDG_DATA_HOME") or join_path(home, ".local", "share")
    end
    if kind == "cache" then
        return env_value("XDG_CACHE_HOME") or join_path(home, ".cache")
    end
    return env_value("XDG_CONFIG_HOME") or join_path(home, ".config")
end

local function reqpack_root(kind, flags)
    local override = nil
    if kind == "data" then
        override = flag_value(flags, "data-root")
    elseif kind == "cache" then
        override = flag_value(flags, "cache-root")
    else
        override = flag_value(flags, "config-root")
    end
    if override ~= nil then
        return override
    end
    local fixture_root = env_value("REQPACK_TEST_FIXTURE_ROOT")
    if fixture_root ~= nil then
        if kind == "data" then
            return join_path(fixture_root, ".reqpack-data")
        end
        if kind == "cache" then
            return join_path(fixture_root, ".reqpack-cache")
        end
        return join_path(fixture_root, ".reqpack-config")
    end
    if kind == "data" then
        return get_reqpack_path("dataRoot") or join_path(xdg_root("data"), "reqpack")
    end
    if kind == "cache" then
        return get_reqpack_path("cacheRoot") or join_path(xdg_root("cache"), "reqpack")
    end
    return get_reqpack_path("configRoot") or join_path(xdg_root("config"), "reqpack")
end

local function carbon_roots(flags)
    local data_root = join_path(reqpack_root("data", flags), PLUGIN_ID)
    local cache_root = join_path(reqpack_root("cache", flags), PLUGIN_ID)
    local config_root = join_path(reqpack_root("config", flags), PLUGIN_ID)
    local home_root = join_path(config_root, "home")
    return {
        dataRoot = data_root,
        cacheRoot = cache_root,
        configRoot = config_root,
        homeRoot = home_root,
        carbonHome = join_path(home_root, ".carbon"),
        carbonVarsFile = join_path(home_root, ".carbon", "carbon.vars"),
        xdgConfigHome = join_path(config_root, "xdg-config"),
        xdgCacheHome = join_path(cache_root, "xdg-cache"),
        xdgDataHome = join_path(data_root, "xdg-data"),
    }
end

local function ensure_parent_dir(context, path)
    local parent = dirname(path)
    if parent == nil or parent == "" then
        return true
    end
    return is_success(exec_run(context, "mkdir -p " .. shell_quote(parent)))
end

local function ensure_carbon_home(context, roots)
    if not ensure_parent_dir(context, roots.carbonVarsFile) then
        return false, "failed to create Carbon config directory"
    end
    local result = exec_run(context, "test -e " .. shell_quote(roots.carbonVarsFile) .. " || printf %s '' > " .. shell_quote(roots.carbonVarsFile))
    if not is_success(result) then
        return false, first_nonempty(result.stderr, result.stdout, "failed to create Carbon var file")
    end
    return true
end

local function carbon_env_prefix(roots)
    return table.concat({
        "NO_COLOR=1",
        "LC_ALL=C",
        "LANG=C",
        "LANGUAGE=C",
        "HOME=" .. shell_quote(roots.homeRoot),
        "XDG_CONFIG_HOME=" .. shell_quote(roots.xdgConfigHome),
        "XDG_CACHE_HOME=" .. shell_quote(roots.xdgCacheHome),
        "XDG_DATA_HOME=" .. shell_quote(roots.xdgDataHome),
    }, " ")
end

local function package_name(pkg)
    return first_nonempty(read_field(pkg, "name"), read_field(pkg, "packageId"), read_field(pkg, "id"))
end

local function package_version(pkg)
    return first_nonempty(read_field(pkg, "version"), read_field(pkg, "latestVersion"))
end

local function package_namespace(pkg)
    local extra = read_field(pkg, "extraFields")
    return first_nonempty(read_field(pkg, "namespace"), read_field(extra, "namespace"))
end

local function package_source(pkg)
    local extra = read_field(pkg, "extraFields")
    return first_nonempty(read_field(pkg, "source"), read_field(extra, "source"))
end

local function looks_like_image_ref(value)
    local text = trim(value)
    if text == "" then
        return false
    end
    if text:find(":", 1, true) ~= nil then
        return true
    end
    if text:find("/", 1, true) ~= nil then
        return true
    end
    if text:find("@", 1, true) ~= nil then
        return true
    end
    return false
end

local function package_error(context, message, unavailable_payload)
    tx_failed(context, message)
    emit_event(context, "failed", message)
    if unavailable_payload ~= nil then
        emit_event(context, "unavailable", unavailable_payload)
    end
    return false
end

local function ensure_available(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true, nil
    end
    return false, "carbon binary not found"
end

local function carbon_command(context, flags, args)
    local roots = carbon_roots(flags)
    local ok, message = ensure_carbon_home(context, roots)
    if not ok then
        return nil, message
    end
    return carbon_env_prefix(roots) .. " carbon " .. table.concat(args, " "), nil
end

local function normalize_status_row(line)
    local text = trim(line)
    if text == "" then
        return nil
    end
    if lower(text):match("^namespace%s+name%s+version%s+source$") then
        return nil
    end
    local cols = {}
    for field in text:gmatch("([^%s].-)%s%s+") do
        cols[#cols + 1] = trim(field)
    end
    local last_start = nil
    local search_from = 1
    for start_pos, end_pos in text:gmatch("()(%S+)()") do
        last_start = start_pos
        search_from = end_pos
    end
    if #cols >= 3 and last_start ~= nil then
        cols[#cols + 1] = trim(text:sub(last_start))
    else
        cols = split_words(text)
    end
    if #cols < 4 then
        return nil
    end
    return {
        namespace = cols[1],
        name = cols[2],
        version = cols[3],
        source = cols[4],
    }
end

local function parse_status_list(output)
    local items = {}
    for _, line in ipairs(split_lines(output)) do
        local row = normalize_status_row(line)
        if row ~= nil then
            items[#items + 1] = {
                name = row.name,
                packageId = row.name,
                version = row.version,
                latestVersion = row.version,
                packageType = "carbon-package",
                type = "package",
                source = row.source,
                extraFields = {
                    namespace = row.namespace,
                    source = row.source,
                },
            }
        end
    end
    return items
end

local function parse_variable_row(line)
    local text = trim(line)
    if text == "" then
        return nil
    end
    local words = split_words(text)
    if #words == 0 then
        return nil
    end
    if lower(words[1]) == "name" and (lower(words[2] or "") == "value" or lower(words[2] or "") == "default") then
        return nil
    end
    if #words == 1 then
        return { name = words[1], value = "", description = "" }
    end
    if #words == 2 then
        return { name = words[1], value = words[2], description = "" }
    end
    return {
        name = words[1],
        value = words[2],
        description = table.concat(words, " ", 3),
    }
end

local function parse_status_detail(output)
    local item = {
        extraFields = {
            variables = {},
        },
    }
    local mode = nil
    for _, raw_line in ipairs(split_lines(output)) do
        local line = trim(raw_line)
        if line == "" then
            if mode == "variables" then
                mode = nil
            end
        elseif line:sub(1, 10) == "Namespace:" then
            item.extraFields.namespace = trim(line:sub(11))
            mode = nil
        elseif line:sub(1, 5) == "Name:" then
            local name = trim(line:sub(6))
            item.name = name
            item.packageId = name
            mode = nil
        elseif line:sub(1, 8) == "Version:" then
            local version = trim(line:sub(9))
            item.version = version
            item.latestVersion = version
            mode = nil
        elseif line:sub(1, 7) == "Source:" then
            local source = trim(line:sub(8))
            item.source = source
            item.extraFields.source = source
            mode = nil
        elseif line == "Variables:" then
            mode = "variables"
        elseif line:sub(1, 8) == "Patches:" then
            item.extraFields.patches = trim(line:sub(9))
            mode = nil
        elseif line:sub(1, 9) == "Manifest:" then
            item.extraFields.manifest = trim(line:sub(10))
            mode = nil
        elseif mode == "variables" then
            local variable = parse_variable_row(raw_line)
            if variable ~= nil then
                item.extraFields.variables[#item.extraFields.variables + 1] = variable
            end
        end
    end
    if item.name == nil then
        return {}
    end
    item.packageType = "carbon-package"
    item.type = "package"
    return item
end

local function parse_inspect_detail(output, image)
    local item = {
        extraFields = {
            source = image,
            variables = {},
        },
    }
    local mode = nil
    for _, raw_line in ipairs(split_lines(output)) do
        local line = trim(raw_line)
        if line == "" then
            if mode == "variables" then
                mode = nil
            end
        elseif line:sub(1, 5) == "Name:" then
            item.name = trim(line:sub(6))
            mode = nil
        elseif line:sub(1, 8) == "Version:" then
            local version = trim(line:sub(9))
            item.version = version
            item.latestVersion = version
            mode = nil
        elseif line == "Variables:" then
            mode = "variables"
        elseif mode == "variables" then
            local variable = parse_variable_row(raw_line)
            if variable ~= nil then
                item.extraFields.variables[#item.extraFields.variables + 1] = variable
            end
        end
    end
    if item.name == nil then
        item.name = image
    end
    item.packageId = image
    item.source = image
    item.packageType = "carbon-image"
    item.type = "package"
    return item
end

local function query_list(context, flags)
    local command, message = carbon_command(context, flags, { "status" })
    if command == nil then
        log_warn(context, message)
        return {}
    end
    local result = exec_run(context, command)
    if not is_success(result) then
        log_warn(context, first_nonempty(result.stderr, result.stdout, "carbon status failed"))
        return {}
    end
    return parse_status_list(result.stdout or "")
end

local function installed_lookup(context, flags)
    local lookup = {}
    for _, item in ipairs(query_list(context, flags)) do
        lookup[lower(item.name or "")] = item
    end
    return lookup
end

local function install_args_for_package(pkg, flags)
    local args = {}
    if has_flag(flags, "minikube") then
        args[#args + 1] = "--minikube"
    end
    local namespace = first_nonempty(package_namespace(pkg), flag_value(flags, "namespace"))
    if namespace ~= nil then
        args[#args + 1] = "--namespace"
        args[#args + 1] = shell_quote(namespace)
    end
    if has_flag(flags, "default-prune-white-list") then
        args[#args + 1] = "--default-prune-white-list"
    end
    for _, value in ipairs(flag_values(flags, "var")) do
        args[#args + 1] = "--var"
        args[#args + 1] = shell_quote(value)
    end
    for _, value in ipairs(flag_values(flags, "var-file")) do
        args[#args + 1] = "--var-file"
        args[#args + 1] = shell_quote(value)
    end
    for _, value in ipairs(flag_values(flags, "patch")) do
        args[#args + 1] = "--patch"
        args[#args + 1] = shell_quote(value)
    end
    for _, value in ipairs(flag_values(flags, "patch-file")) do
        args[#args + 1] = "--patch-file"
        args[#args + 1] = shell_quote(value)
    end
    return args
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
    return { "Development", "Package Manager", "Kubernetes" }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end
    local flags = collect_flags(nil, packages)
    local installed = installed_lookup(nil, flags)
    local filtered = {}
    for _, pkg in ipairs(packages) do
        local action = lower(read_field(pkg, "action") or "install")
        local name = trim(package_name(pkg) or "")
        local key = lower(name)
        if action == "remove" then
            if installed[key] ~= nil then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "install" then
            if looks_like_image_ref(name) or installed[key] == nil then
                filtered[#filtered + 1] = pkg
            end
        else
            filtered[#filtered + 1] = pkg
        end
    end
    return filtered
end

function plugin.install(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "carbon-not-installed" })
    end

    packages = request_packages(context, packages)
    local local_path = request_local_path(context, nil)
    if local_path ~= nil then
        return plugin.installLocal(context, local_path)
    end
    if packages == nil or #packages == 0 then
        tx_success(context)
        emit_event(context, "success", "")
        return true
    end

    local flags = collect_flags(context, packages)
    begin_step(context, "install Carbon packages")
    for _, pkg in ipairs(packages) do
        local image = trim(package_name(pkg) or "")
        if image == "" then
            return package_error(context, "carbon install requires Docker image reference", { reason = "missing-image-ref" })
        end
        local args = install_args_for_package(pkg, flags)
        args[#args + 1] = "install"
        args[#args + 1] = shell_quote(image)
        local command, command_error = carbon_command(context, flags, args)
        if command == nil then
            return package_error(context, command_error or "failed to build carbon command")
        end
        local result = exec_run(context, command)
        if not is_success(result) then
            return package_error(context, first_nonempty(result.stderr, result.stdout, "carbon install failed"))
        end
    end
    emit_event(context, "installed", packages)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.installLocal(context, path)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { path = tostring(path or ""), reason = "carbon-not-installed" })
    end
    return package_error(
        context,
        "carbon installLocal is not supported; Carbon installs packages from Docker image references",
        { path = trim(path), reason = "local-install-unsupported" }
    )
end

function plugin.remove(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "carbon-not-installed" })
    end
    packages = request_packages(context, packages)
    if packages == nil or #packages == 0 then
        tx_success(context)
        emit_event(context, "success", "")
        return true
    end
    local flags = collect_flags(context, packages)
    begin_step(context, "remove Carbon packages")
    for _, pkg in ipairs(packages) do
        local name = trim(package_name(pkg) or "")
        if name == "" then
            return package_error(context, "carbon remove requires installed package name", { reason = "missing-package-name" })
        end
        local args = {}
        if has_flag(flags, "minikube") then
            args[#args + 1] = "--minikube"
        end
        local namespace = first_nonempty(package_namespace(pkg), flag_value(flags, "namespace"))
        if namespace ~= nil then
            args[#args + 1] = "--namespace"
            args[#args + 1] = shell_quote(namespace)
        end
        args[#args + 1] = "uninstall"
        args[#args + 1] = shell_quote(name)
        local command, command_error = carbon_command(context, flags, args)
        if command == nil then
            return package_error(context, command_error or "failed to build carbon command")
        end
        local result = exec_run(context, command)
        if not is_success(result) then
            return package_error(context, first_nonempty(result.stderr, result.stdout, "carbon uninstall failed"))
        end
    end
    emit_event(context, "deleted", packages)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.update(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "carbon-not-installed" })
    end
    packages = request_packages(context, packages)
    if packages == nil or #packages == 0 then
        emit_event(context, "updated", {})
        tx_success(context)
        emit_event(context, "success", "")
        return true
    end
    local flags = collect_flags(context, packages)
    begin_step(context, "update Carbon packages")
    local updated = {}
    for _, pkg in ipairs(packages) do
        local name = trim(package_name(pkg) or "")
        if name == "" then
            return package_error(context, "carbon update requires installed package name", { reason = "missing-package-name" })
        end
        local detail = plugin.info(context, name)
        local source = first_nonempty(package_source(detail), package_source(pkg))
        if source == nil then
            return package_error(context, "carbon update requires known source image from installed metadata", { reason = "missing-source-image", name = name })
        end
        local install_pkg = shallow_copy(pkg)
        install_pkg.name = source
        install_pkg.packageId = source
        install_pkg.source = source
        install_pkg.extraFields = shallow_copy(read_field(pkg, "extraFields") or {})
        if read_field(detail, "extraFields") ~= nil then
            install_pkg.extraFields.namespace = first_nonempty(read_field(detail.extraFields, "namespace"), install_pkg.extraFields.namespace)
        end
        local args = install_args_for_package(install_pkg, flags)
        args[#args + 1] = "install"
        args[#args + 1] = shell_quote(source)
        local command, command_error = carbon_command(context, flags, args)
        if command == nil then
            return package_error(context, command_error or "failed to build carbon command")
        end
        local result = exec_run(context, command)
        if not is_success(result) then
            return package_error(context, first_nonempty(result.stderr, result.stdout, "carbon update failed"))
        end
        updated[#updated + 1] = {
            name = name,
            packageId = name,
            source = source,
        }
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.list(context)
    local flags = collect_flags(context, nil)
    local items = query_list(context, flags)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items = {}
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local available, message = ensure_available(context)
    if not available then
        log_warn(context, message)
    else
        local query = trim(request_prompt(context, prompt))
        if query ~= "" then
            log_warn(context, "carbon CLI has no search command; returning empty result set")
        end
    end
    local items = {}
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = trim(request_prompt(context, name))
    if query == "" then
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    local flags = collect_flags(context, nil)
    local available, message = ensure_available(context)
    if not available then
        log_warn(context, message)
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    if not looks_like_image_ref(query) then
        local status_args = {}
        if has_flag(flags, "minikube") then
            status_args[#status_args + 1] = "--minikube"
        end
        local namespace = flag_value(flags, "namespace")
        if namespace ~= nil then
            status_args[#status_args + 1] = "--namespace"
            status_args[#status_args + 1] = shell_quote(namespace)
        end
        status_args[#status_args + 1] = "status"
        status_args[#status_args + 1] = shell_quote(query)
        status_args[#status_args + 1] = "--full"
        local status_command, _ = carbon_command(context, flags, status_args)
        local status_result = exec_run(context, status_command)
        if is_success(status_result) then
            local item = parse_status_detail(status_result.stdout or "")
            if next(item) ~= nil then
                emit_event(context, "informed", item)
                return item
            end
        end
    end

    local inspect_args = {}
    if has_flag(flags, "minikube") then
        inspect_args[#inspect_args + 1] = "--minikube"
    end
    inspect_args[#inspect_args + 1] = "inspect"
    inspect_args[#inspect_args + 1] = shell_quote(query)
    local inspect_command, _ = carbon_command(context, flags, inspect_args)
    local inspect_result = exec_run(context, inspect_command)
    if is_success(inspect_result) then
        local item = parse_inspect_detail(inspect_result.stdout or "", query)
        emit_event(context, "informed", item)
        return item
    end

    local item = {}
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end
    local query = trim(package_name(package) or "")
    if query == "" then
        return nil
    end
    local item = plugin.info(context, query)
    if type(item) == "table" and next(item) ~= nil then
        return item
    end
    return {
        name = query,
        packageId = query,
        version = package_version(package),
        source = package_source(package),
        packageType = looks_like_image_ref(query) and "carbon-image" or "carbon-package",
        type = "package",
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "carbon", "docker", "kubernetes" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".local/share/reqpack/carbon" },
            { kind = "user-home-subpath", value = ".cache/reqpack/carbon" },
            { kind = "user-home-subpath", value = ".config/reqpack/carbon" },
        },
        privilegeLevel = "user",
        purlType = "generic",
    }
end

function plugin.init()
    return command_exists(nil, REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

return plugin
