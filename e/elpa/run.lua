plugin = {}
plugin.fileExtensions = { ".el", ".tar" }

local PLUGIN_ID = "elpa"
local PLUGIN_NAME = "ELPA"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "emacs"

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

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil then
            local text = trim(value)
            if text ~= "" then
                return text
            end
        end
    end
    return nil
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
    if type(first) == "table" or type(first) == "userdata" then
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
    local function merge_value(value)
        local value_type = type(value)
        if value_type == "table" then
            for key, item in pairs(value or {}) do
                result[key] = item
            end
        elseif value_type == "userdata" then
            local stdout = read_field(value, "stdout") or read_field(value, "stdoutText")
            local stderr = read_field(value, "stderr") or read_field(value, "stderrText")
            local exit_code = read_field(value, "exitCode") or read_field(value, "exit_code") or read_field(value, "code") or read_field(value, "status")
            local success = read_field(value, "success")
            local ok = read_field(value, "ok")
            if stdout ~= nil then
                result.stdout = stdout
            end
            if stderr ~= nil then
                result.stderr = stderr
            end
            if exit_code ~= nil then
                result.exitCode = exit_code
            end
            if success ~= nil then
                result.success = success
            elseif ok ~= nil then
                result.success = ok
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
    local result_type = type(result)
    if result_type ~= "table" and result_type ~= "userdata" then
        return false
    end
    return result.success == true or result.exitCode == 0
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

    return join_path(".", ".reqpack-data")
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
    return {
        dataRoot = flag_value(flags, "data-root"),
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
        return nil, "missing ELPA package name"
    end
    return {
        name = name,
        version = package_version(pkg),
        raw = pkg,
    }, nil
end

local function helper_script_path()
    local configured = trim(_G.REQPACK_PLUGIN_DIR)
    if configured ~= "" then
        return join_path(configured, "scripts", "reqpack-elpa-batch.el")
    end
    return "./scripts/reqpack-elpa-batch.el"
end

local function emacs_env_prefix(paths)
    return table.concat({
        "NO_COLOR=1",
        "XDG_CACHE_HOME=" .. shell_quote(paths.cache),
        "XDG_CONFIG_HOME=" .. shell_quote(paths.config),
        "TMPDIR=" .. shell_quote(paths.tmp),
        "LC_ALL=C",
        "LANG=C",
        "LANGUAGE=C",
    }, " ")
end

local function build_command(parts)
    return table.concat(parts, " ")
end

local function emacs_command(paths, action, values)
    local parts = {
        emacs_env_prefix(paths),
        REQUIRED_BINARY,
        "--batch",
        "-Q",
        "--script",
        shell_quote(helper_script_path()),
        "--",
        action,
        shell_quote(paths.dataRoot),
    }
    for _, value in ipairs(values or {}) do
        parts[#parts + 1] = shell_quote(value)
    end
    return build_command(parts)
end

local function parse_items(raw)
    local items = {}
    for _, line in ipairs(split_lines(raw)) do
        local fields = split_tabs(line)
        if #fields >= 10 then
            local archive = trim(fields[10])
            local item = {
                name = trim(fields[1]),
                packageId = trim(fields[1]),
                version = trim(fields[2]),
                latestVersion = trim(fields[3]),
                installed = lower(fields[4]) == "true" and "true" or "false",
                status = trim(fields[5]),
                summary = trim(fields[6]) ~= "" and trim(fields[6]) or nil,
                description = trim(fields[7]) ~= "" and trim(fields[7]) or nil,
                homepage = trim(fields[8]) ~= "" and trim(fields[8]) or nil,
                dependencies = split_csv(fields[9]),
                repository = archive ~= "" and archive or nil,
                license = first_nonempty(fields[11], fields[12]),
                packageType = "emacs-lisp-package",
                type = "package",
                extraFields = {
                    archive = archive ~= "" and archive or nil,
                    kind = "archive-package",
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

local function query_items(context, action, values, packages)
    local options = context_options(context, packages)
    local paths = state_paths(options.dataRoot)
    local result = exec_run(context, emacs_command(paths, action, values))
    if not is_success(result) then
        return nil, result
    end
    return parse_items(result.stdout or ""), result
end

local function exec_error_message(result, fallback)
    return first_nonempty(result and result.stderr, result and result.stdout, fallback) or fallback
end

local function failure(context, message, unavailable)
    tx_failed(context, message)
    if unavailable ~= nil then
        emit_event(context, "unavailable", unavailable)
    end
    return false
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

    local installed_items = select(1, query_items(nil, "list", {}, packages))
    if installed_items == nil then
        return packages
    end

    local needs_outdated = false
    for _, pkg in ipairs(packages) do
        if package_action(pkg) == "update" then
            needs_outdated = true
            break
        end
    end

    local outdated_items = {}
    if needs_outdated then
        outdated_items = select(1, query_items(nil, "outdated", {}, packages))
        if outdated_items == nil then
            return packages
        end
    end

    return filtered_missing(packages, installed_items, outdated_items)
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    local normalized = {}
    local names = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return failure(context, err)
        end
        normalized[#normalized + 1] = pkg
        names[#names + 1] = pkg.name
    end

    local paths = state_paths(context_options(context, requested).dataRoot)
    begin_step(context, "install elpa packages")
    local result = exec_run(context, emacs_command(paths, "install", names))
    if not is_success(result) then
        return failure(context, exec_error_message(result, "ELPA install failed"))
    end

    emit_event(context, "installed", normalized)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local source_path = trim(path or read_field(context, "localPath") or read_field(context, "path"))
    if source_path == "" then
        return failure(context, "missing local ELPA package path")
    end

    local normalized = lower(source_path)
    if normalized:match("%.el$") == nil and normalized:match("%.tar$") == nil then
        return failure(context, "installLocal only supports .el or .tar packages", { path = source_path, reason = "local-install-unsupported" })
    end

    local paths = state_paths(context_options(context, {}).dataRoot)
    begin_step(context, "install local elpa package")
    local result = exec_run(context, emacs_command(paths, "install-local", { source_path }))
    if not is_success(result) then
        return failure(context, exec_error_message(result, "ELPA local install failed"))
    end

    emit_event(context, "installed", {
        localTarget = true,
        path = source_path,
        packageType = "emacs-lisp-package",
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    local normalized = {}
    local names = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return failure(context, err)
        end
        normalized[#normalized + 1] = pkg
        names[#names + 1] = pkg.name
    end

    local paths = state_paths(context_options(context, requested).dataRoot)
    begin_step(context, "remove elpa packages")
    local result = exec_run(context, emacs_command(paths, "remove", names))
    if not is_success(result) then
        return failure(context, exec_error_message(result, "ELPA remove failed"))
    end

    emit_event(context, "deleted", normalized)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    local paths = state_paths(context_options(context, requested).dataRoot)

    begin_step(context, "update elpa packages")

    local payload = {}
    local result = nil
    if #requested == 0 then
        result = exec_run(context, emacs_command(paths, "update-all", {}))
    else
        local names = {}
        for _, raw_pkg in ipairs(requested) do
            local pkg, err = normalize_package(raw_pkg)
            if pkg == nil then
                return failure(context, err)
            end
            payload[#payload + 1] = pkg
            names[#names + 1] = pkg.name
        end
        result = exec_run(context, emacs_command(paths, "update", names))
    end

    if not is_success(result) then
        return failure(context, exec_error_message(result, "ELPA update failed"))
    end

    emit_event(context, "updated", payload)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items, result = query_items(context, "list", {}, {})
    if items == nil then
        log_warn(context, exec_error_message(result, "ELPA list failed"))
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items, result = query_items(context, "outdated", {}, {})
    if items == nil then
        log_warn(context, exec_error_message(result, "ELPA outdated failed"))
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

    local items, result = query_items(context, "search", { query }, {})
    if items == nil then
        log_warn(context, exec_error_message(result, "ELPA search failed"))
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

    local items = select(1, query_items(context, "info", { query }, {}))
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

    local items = select(1, query_items(context, "info", { pkg.name }, { package }))
    if items ~= nil and items[1] ~= nil then
        return items[1]
    end
    return {
        name = pkg.name,
        packageId = pkg.name,
        version = pkg.version ~= "" and pkg.version or nil,
        packageType = "emacs-lisp-package",
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "elpa", "emacs-lisp" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".local/share/reqpack/elpa" },
        },
        networkScopes = {
            { host = "elpa.gnu.org", scheme = "https", pathPrefix = "/packages/" },
            { host = "elpa.nongnu.org", scheme = "https", pathPrefix = "/nongnu/" },
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
