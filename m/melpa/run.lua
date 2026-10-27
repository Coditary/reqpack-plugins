plugin = {}
plugin.fileExtensions = { ".el", ".tar", ".tar.gz" }

local PLUGIN_ID = "melpa"
local PLUGIN_NAME = "MELPA"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "emacs"
local DEFAULT_ARCHIVE_URL = "https://melpa.org/packages/"

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

local function split_tabs(line)
    local fields = {}
    for field in (tostring(line or "") .. "\t"):gmatch("(.-)\t") do
        fields[#fields + 1] = field
    end
    return fields
end

local function split_csv(value)
    local items = {}
    for part in tostring(value or ""):gmatch("([^,]+)") do
        local cleaned = trim(part)
        if cleaned ~= "" then
            items[#items + 1] = cleaned
        end
    end
    return items
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

local function object_flags(value)
    return sequence_values(read_field(value, "flags"))
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
    add_from(read_field(context, "request"))
    for _, pkg in ipairs(packages or {}) do
        add_from(pkg)
    end
    return flags
end

local function flag_value(flags, key)
    local prefix = trim(key) .. "="
    for _, raw in ipairs(flags or {}) do
        local cleaned = trim(raw)
        if cleaned:sub(1, #prefix) == prefix then
            return trim(cleaned:sub(#prefix + 1))
        end
    end
    return ""
end

local function get_reqpack_path(name)
    local paths = type(reqpack) == "table" and read_field(reqpack, "paths") or nil
    if type(paths) ~= "table" then
        return nil
    end
    local value = trim(read_field(paths, name))
    if value == "" then
        return nil
    end
    return value
end

local function get_plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR)
    if dir ~= "" then
        return dir
    end
    return join_path("m", "melpa")
end

local function home_dir()
    local getenv = os ~= nil and type(os.getenv) == "function" and os.getenv or nil
    local home = getenv and trim(getenv("HOME") or "") or ""
    if home ~= "" then
        return home
    end
    return nil
end

local function default_data_root()
    local reqpack_data_root = get_reqpack_path("dataRoot")
    if reqpack_data_root ~= nil then
        return join_path(reqpack_data_root, PLUGIN_ID)
    end

    local getenv = os ~= nil and type(os.getenv) == "function" and os.getenv or nil
    local fixture_root = getenv and trim(getenv("REQPACK_TEST_FIXTURE_ROOT") or "") or ""
    if fixture_root ~= "" then
        return join_path(fixture_root, ".reqpack-data", PLUGIN_ID)
    end

    local home = home_dir()
    if home ~= nil then
        return join_path(home, ".local", "share", "reqpack", PLUGIN_ID)
    end

    return join_path(get_plugin_dir(), ".reqpack-data")
end

local function state_paths(root)
    local data_root = trim(root)
    if data_root == "" then
        data_root = default_data_root()
    end
    return {
        dataRoot = data_root,
        elpa = join_path(data_root, "elpa"),
        cache = join_path(data_root, "cache"),
        config = join_path(data_root, "config"),
        tmp = join_path(data_root, "tmp"),
    }
end

local function context_options(context, packages)
    local flags = collect_flags(context, packages)
    local archive_url = flag_value(flags, "archive-url")
    if archive_url == "" then
        archive_url = DEFAULT_ARCHIVE_URL
    end
    return {
        flags = flags,
        dataRoot = flag_value(flags, "data-root"),
        archiveUrl = archive_url,
    }
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageName") or read_field(pkg, "packageId"))
end

local function package_version(pkg)
    return trim(read_field(pkg, "version"))
end

local function package_action(pkg)
    local action = lower(read_field(pkg, "action") or read_field(pkg, "requestedAction"))
    if action == "" then
        return "install"
    end
    return action
end

local function normalize_package(pkg)
    local name = package_name(pkg)
    if name == "" then
        return nil, "missing MELPA package name"
    end
    return {
        name = name,
        version = package_version(pkg),
        raw = pkg,
    }, nil
end

local function helper_script_path()
    return join_path(get_plugin_dir(), "scripts", "reqpack-batch.el")
end

local function env_assign(name, value)
    return name .. "=" .. shell_quote(value)
end

local function names_value(packages)
    local values = {}
    for _, pkg in ipairs(packages or {}) do
        local name = trim(pkg.name or pkg)
        if name ~= "" then
            values[#values + 1] = name
        end
    end
    return table.concat(values, ",")
end

local function emacs_command(paths, archive_url, action, packages, prompt, local_path)
    local parts = {
        env_assign("REQPACK_MELPA_ARCHIVE_URL", archive_url),
        env_assign("REQPACK_MELPA_PACKAGE_USER_DIR", paths.elpa),
        env_assign("REQPACK_MELPA_XDG_CACHE_HOME", paths.cache),
        env_assign("REQPACK_MELPA_XDG_CONFIG_HOME", paths.config),
        env_assign("REQPACK_MELPA_TMPDIR", paths.tmp),
        env_assign("REQPACK_MELPA_ACTION", action),
        env_assign("REQPACK_MELPA_NAMES", names_value(packages)),
        env_assign("REQPACK_MELPA_PROMPT", prompt or ""),
        env_assign("REQPACK_MELPA_LOCAL_PATH", local_path or ""),
        "LC_ALL=C",
        "LANG=C",
        "LANGUAGE=C",
        REQUIRED_BINARY,
        "--batch",
        "--quick",
        "--load",
        shell_quote("package"),
        "--load",
        shell_quote(helper_script_path()),
    }
    return table.concat(parts, " ")
end

local function parse_items(raw)
    local items = {}
    for _, line in ipairs(split_lines(raw)) do
        local fields = split_tabs(line)
        if #fields >= 10 then
            local item = {
                name = trim(fields[1]),
                packageId = trim(fields[1]),
                version = trim(fields[2]),
                latestVersion = trim(fields[3]),
                installed = lower(fields[4]) == "true",
                status = trim(fields[5]),
                summary = trim(fields[6]) ~= "" and trim(fields[6]) or nil,
                description = trim(fields[7]) ~= "" and trim(fields[7]) or nil,
                homepage = trim(fields[8]) ~= "" and trim(fields[8]) or nil,
                dependencies = split_csv(fields[9]),
                repository = trim(fields[10]) ~= "" and trim(fields[10]) or nil,
                packageType = "emacs-lisp",
                type = "package",
                extraFields = {
                    archive = trim(fields[10]),
                },
            }
            if item.version == "" then
                item.version = nil
            end
            if item.latestVersion == "" then
                item.latestVersion = item.version
            end
            items[#items + 1] = item
        end
    end
    return items
end

local function run_action(context, action, packages, prompt, local_path)
    local options = context_options(context, packages)
    local paths = state_paths(options.dataRoot)
    return exec_run(context, emacs_command(paths, options.archiveUrl, action, packages, prompt, local_path))
end

local function query_items(context, action, packages, prompt)
    local result = run_action(context, action, packages, prompt, nil)
    if not is_success(result) then
        return nil, result
    end
    return parse_items(result.stdout or ""), result
end

local function failure(context, message, unavailable)
    tx_failed(context, message)
    if unavailable ~= nil then
        emit_event(context, "unavailable", unavailable)
    end
    return false
end

local function ensure_available(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true, nil
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function filtered_missing(packages, installed_items, outdated_items)
    local installed = {}
    local outdated = {}
    for _, item in ipairs(installed_items or {}) do
        installed[lower(item.name or "")] = item
    end
    for _, item in ipairs(outdated_items or {}) do
        outdated[lower(item.name or "")] = item
    end

    local filtered = {}
    for _, pkg in ipairs(packages or {}) do
        local action = package_action(pkg)
        local name = lower(package_name(pkg))
        if action == "remove" then
            if installed[name] ~= nil then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "update" then
            if outdated[name] ~= nil then
                filtered[#filtered + 1] = pkg
            end
        elseif installed[name] == nil then
            filtered[#filtered + 1] = pkg
        end
    end
    return filtered
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
    return { "Emacs", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end

    if not command_exists(nil, REQUIRED_BINARY) then
        local filtered = {}
        for _, pkg in ipairs(packages) do
            local action = package_action(pkg)
            if action ~= "remove" and action ~= "update" then
                filtered[#filtered + 1] = pkg
            end
        end
        return filtered
    end

    local installed_items = select(1, query_items(nil, "list", packages, nil))
    if installed_items == nil then
        return packages
    end

    local outdated_items = {}
    local needs_outdated = false
    for _, pkg in ipairs(packages) do
        if package_action(pkg) == "update" then
            needs_outdated = true
            break
        end
    end
    if needs_outdated then
        outdated_items = select(1, query_items(nil, "outdated", packages, nil))
        if outdated_items == nil then
            return packages
        end
    end

    return filtered_missing(packages, installed_items, outdated_items)
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        emit_event(context, "success", "")
        return true
    end

    local available, message = ensure_available(context)
    if not available then
        return failure(context, message, { reason = "emacs-not-installed" })
    end

    local normalized = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return failure(context, err)
        end
        normalized[#normalized + 1] = pkg
    end

    begin_step(context, "install MELPA packages")
    local result = run_action(context, "install", normalized, nil, nil)
    if not is_success(result) then
        return failure(context, trim(result.stderr) ~= "" and trim(result.stderr) or "MELPA install failed")
    end

    local payload = {}
    for _, pkg in ipairs(normalized) do
        payload[#payload + 1] = {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "emacs-lisp",
        }
    end
    emit_event(context, "installed", payload)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.installLocal(context, path)
    local available, message = ensure_available(context)
    if not available then
        return failure(context, message, { reason = "emacs-not-installed" })
    end

    local source_path = trim(path or read_field(context, "localPath") or read_field(context, "path"))
    if source_path == "" then
        return failure(context, "missing local MELPA package path")
    end

    local normalized = lower(source_path)
    if normalized:match("%.el$") == nil and normalized:match("%.tar$") == nil and normalized:match("%.tar%.gz$") == nil then
        return failure(context, "installLocal only supports .el, .tar, or .tar.gz packages")
    end

    begin_step(context, "install local MELPA package")
    local result = run_action(context, "install-local", {}, nil, source_path)
    if not is_success(result) then
        return failure(context, trim(result.stderr) ~= "" and trim(result.stderr) or "MELPA local install failed")
    end

    emit_event(context, "installed", {
        localTarget = true,
        path = source_path,
        packageType = "emacs-lisp",
    })
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        emit_event(context, "success", "")
        return true
    end

    local available, message = ensure_available(context)
    if not available then
        return failure(context, message, { reason = "emacs-not-installed" })
    end

    local normalized = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return failure(context, err)
        end
        normalized[#normalized + 1] = pkg
    end

    begin_step(context, "remove MELPA packages")
    local result = run_action(context, "remove", normalized, nil, nil)
    if not is_success(result) then
        return failure(context, trim(result.stderr) ~= "" and trim(result.stderr) or "MELPA remove failed")
    end

    local payload = {}
    for _, pkg in ipairs(normalized) do
        payload[#payload + 1] = {
            name = pkg.name,
            packageId = pkg.name,
            packageType = "emacs-lisp",
        }
    end
    emit_event(context, "deleted", payload)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        emit_event(context, "updated", {})
        tx_success(context)
        emit_event(context, "success", "")
        return true
    end

    local available, message = ensure_available(context)
    if not available then
        return failure(context, message, { reason = "emacs-not-installed" })
    end

    local normalized = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return failure(context, err)
        end
        normalized[#normalized + 1] = pkg
    end

    begin_step(context, "update MELPA packages")
    local result = run_action(context, "update", normalized, nil, nil)
    if not is_success(result) then
        return failure(context, trim(result.stderr) ~= "" and trim(result.stderr) or "MELPA update failed")
    end

    local payload = {}
    for _, pkg in ipairs(normalized) do
        payload[#payload + 1] = {
            name = pkg.name,
            packageId = pkg.name,
            packageType = "emacs-lisp",
        }
    end
    emit_event(context, "updated", payload)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.list(context)
    local available, message = ensure_available(context)
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "listed", items)
        return items
    end

    local items = select(1, query_items(context, "list", {}, nil))
    if items == nil then
        log_warn(context, "MELPA list failed")
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local available, message = ensure_available(context)
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "outdated", items)
        return items
    end

    local items = select(1, query_items(context, "outdated", {}, nil))
    if items == nil then
        log_warn(context, "MELPA outdated failed")
        items = {}
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt)
    if query == "" and context ~= nil then
        query = trim(read_field(context, "prompt"))
    end
    if query == "" then
        local items = {}
        emit_event(context, "searched", items)
        return items
    end

    local available, message = ensure_available(context)
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "searched", items)
        return items
    end

    local items = select(1, query_items(context, "search", {}, query))
    if items == nil then
        log_warn(context, "MELPA search failed")
        items = {}
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = trim(name)
    if query == "" and context ~= nil then
        query = trim(read_field(context, "prompt"))
    end
    if query == "" then
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    local available, message = ensure_available(context)
    if not available then
        log_warn(context, message)
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    local items = select(1, query_items(context, "info", {}, query))
    local item = (items ~= nil and items[1]) or {}
    if next(item) == nil then
        emit_event(context, "unavailable", { name = query, reason = "not-found" })
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

    if not command_exists(context, REQUIRED_BINARY) then
        return {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "emacs-lisp",
        }
    end

    local items = select(1, query_items(context, "info", { package }, pkg.name))
    if items ~= nil and items[1] ~= nil then
        return items[1]
    end
    return {
        name = pkg.name,
        packageId = pkg.name,
        version = pkg.version ~= "" and pkg.version or nil,
        packageType = "emacs-lisp",
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "melpa", "emacs-lisp" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".local/share/reqpack/melpa" },
        },
        networkScopes = {
            { host = "melpa.org", scheme = "https", pathPrefix = "/packages/" },
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
