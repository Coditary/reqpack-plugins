plugin = {}

local PLUGIN_ID = "mojo"
local PLUGIN_NAME = "Mojo"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "modular"
local PACKAGE_NAME = "mojo"
local PACKAGE_ALIAS = "modular"
local PACKAGE_ROOT_SUFFIX = "pkg/packages.modular.com_mojo"
local HOMEPAGE_URL = "https://docs.modular.com/mojo"
local SOURCE_URL = "https://packages.modular.com/mojo"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
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

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
end

local function merge_tables(left, right)
    local merged = shallow_copy(type(left) == "table" and left or {})
    for key, value in pairs(type(right) == "table" and right or {}) do
        merged[key] = value
    end
    if next(merged) == nil then
        return nil
    end
    return merged
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
            stderr = "reqpack.exec.run unavailable",
            exitCode = 127,
        }
    end
    return normalize_run_result(first, second, third, fourth, fifth)
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function object_flags(object)
    local value = read_field(object, "flags")
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end

    local flags = {}
    local ok = pcall(function()
        for _, item in ipairs(value) do
            local text = trim(item)
            if text ~= "" then
                flags[#flags + 1] = text
            end
        end
    end)
    if not ok then
        return {}
    end
    return flags
end

local function append_unique(list, value, seen)
    local text = trim(value)
    if text == "" or seen[text] then
        return
    end
    seen[text] = true
    list[#list + 1] = text
end

local function collect_flags(context, packages)
    local flags = {}
    local seen = {}

    local function collect_from(object)
        for _, item in ipairs(object_flags(object)) do
            append_unique(flags, item, seen)
        end
    end

    collect_from(context)
    collect_from(read_field(context, "request"))
    for _, package in ipairs(packages or {}) do
        collect_from(package)
    end
    return flags
end

local function context_flags(context)
    return collect_flags(context, nil)
end

local function has_flag(flags, wanted)
    local target = lower(trim(wanted))
    for _, flag in ipairs(flags or {}) do
        if lower(trim(flag)) == target then
            return true
        end
    end
    return false
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

local function home_dir()
    if os ~= nil and type(os.getenv) == "function" then
        local value = trim(os.getenv("HOME") or os.getenv("USERPROFILE") or "")
        if value ~= "" then
            return value
        end
    end
    return "/home/test"
end

local function modular_home_from_flags(flags)
    local value = trim(flag_value(flags, "modular-home") or flag_value(flags, "home") or "")
    if value ~= "" then
        return value
    end
    local env_value = os ~= nil and type(os.getenv) == "function" and trim(os.getenv("MODULAR_HOME") or "") or ""
    if env_value ~= "" then
        return env_value
    end
    return join_path(home_dir(), ".modular")
end

local function package_root(modular_home)
    return join_path(modular_home, PACKAGE_ROOT_SUFFIX)
end

local function mojo_binary_path(modular_home)
    return join_path(package_root(modular_home), "bin", "mojo")
end

local function path_exists(path)
    local target = trim(path)
    if target == "" then
        return false
    end

    local handle = io.open(target, "rb")
    if handle ~= nil then
        handle:close()
        return true
    end

    if os ~= nil and type(os.rename) == "function" then
        local ok, _, code = os.rename(target, target)
        if ok == true or code == 13 then
            return true
        end
    end

    return false
end

local function read_file(path)
    local handle = io.open(path, "rb")
    if handle == nil then
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function parse_config_lines(raw)
    local parsed = {}
    for _, line in ipairs(split_lines(raw)) do
        local key, value = tostring(line):match("^%s*([^=]+)%s*=%s*(.-)%s*$")
        if key ~= nil then
            parsed[trim(key)] = trim(value)
        end
    end
    return parsed
end

local function config_file_path(modular_home)
    return join_path(modular_home, "modular.cfg")
end

local function load_modular_config(context, modular_home)
    local config = {}

    if command_exists(context, REQUIRED_BINARY) then
        local command = "MODULAR_HOME=" .. shell_quote(modular_home) .. " modular config-list"
        local result = exec_run(context, command)
        if result ~= nil and result.success and trim(result.stdout) ~= "" then
            return parse_config_lines(result.stdout)
        end
    end

    local file_content = read_file(config_file_path(modular_home))
    if file_content ~= nil then
        config = parse_config_lines(file_content)
    end
    return config
end

local function parse_mojo_version(raw)
    for _, line in ipairs(split_lines(raw)) do
        local version = trim(line):match("^mojo%s+([^%s%(]+)")
        if version ~= nil and version ~= "" then
            return version
        end
    end
    return nil
end

local function load_installed_version(context, binary_path)
    if trim(binary_path) == "" then
        return nil
    end

    local result = exec_run(context, shell_quote(binary_path) .. " --version")
    if result == nil or not result.success then
        return nil
    end
    return parse_mojo_version(result.stdout)
end

local function accepted_query_name(value)
    local name = lower(trim(value))
    return name == PACKAGE_NAME or name == PACKAGE_ALIAS
end

local function accepted_mutation_name(value)
    return lower(trim(value)) == PACKAGE_NAME
end

local function installed_state(context, modular_home)
    local pkg_root = package_root(modular_home)
    local binary_path = mojo_binary_path(modular_home)
    local installed = path_exists(binary_path) or path_exists(pkg_root)
    local config = load_modular_config(context, modular_home)
    local driver_path = trim(read_field(config, "mojo.driver_path") or "")
    if driver_path ~= "" then
        installed = true
        binary_path = driver_path
    end

    local version = load_installed_version(context, binary_path)
    return installed, version, config, binary_path, pkg_root
end

local function build_item(modular_home, installed, version, config, binary_path, pkg_root)
    local extra_fields = {
        modularHome = modular_home,
        packagePath = pkg_root,
    }

    if trim(binary_path) ~= "" then
        extra_fields.driverPath = trim(binary_path)
    end

    for _, key in ipairs({ "mojo.driver_path", "mojo.python_lib", "mojo.repl_entry_point", "mojo.system_libs" }) do
        local value = trim(read_field(config, key) or "")
        if value ~= "" then
            extra_fields[key] = value
        end
    end

    local item = {
        name = PACKAGE_NAME,
        packageId = PACKAGE_NAME,
        packageType = "sdk",
        type = "package",
        installed = installed,
        status = installed and "installed" or "available",
        summary = "Mojo SDK managed by Modular CLI",
        description = "Legacy Modular CLI installation for the Mojo SDK and tooling",
        homepage = HOMEPAGE_URL,
        sourceUrl = SOURCE_URL,
        extraFields = extra_fields,
    }

    if trim(version) ~= "" then
        item.version = trim(version)
        item.latestVersion = trim(version)
    end

    return item
end

local function installed_item(context, modular_home)
    local installed, version, config, binary_path, pkg_root = installed_state(context, modular_home)
    if not installed then
        return nil
    end
    return build_item(modular_home, true, version, config, binary_path, pkg_root)
end

local function available_item(modular_home)
    return build_item(modular_home, false, nil, {}, mojo_binary_path(modular_home), package_root(modular_home))
end

local function env_prefix(flags)
    local parts = {
        "MODULAR_HOME=" .. shell_quote(modular_home_from_flags(flags))
    }

    local python_home = trim(flag_value(flags, "python-home") or "")
    if python_home ~= "" then
        parts[#parts + 1] = "PYTHONHOME=" .. shell_quote(python_home)
    end

    local python_lib = trim(flag_value(flags, "python-lib") or flag_value(flags, "mojo-python-library") or "")
    if python_lib ~= "" then
        parts[#parts + 1] = "MOJO_PYTHON_LIBRARY=" .. shell_quote(python_lib)
    end

    return table.concat(parts, " ")
end

local function ensure_supported_packages(packages)
    for _, package in ipairs(packages or {}) do
        local name = trim(read_field(package, "name") or read_field(package, "packageId") or "")
        if not accepted_mutation_name(name) then
            return nil, "mojo plugin only supports package 'mojo'"
        end
    end
    return true, nil
end

local function run_mutation(context, label, command, event_name, payload)
    begin_step(context, label)
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end

    local result = exec_run(context, command)
    if result == nil or not result.success then
        tx_failed(context, trim(result and result.stderr or result and result.stdout or (label .. " failed")))
        return false
    end

    emit_event(context, event_name, payload)
    tx_success(context)
    return true
end

local function update_needs_fallback(result)
    local text = lower(trim((result and result.stderr or "") .. "\n" .. (result and result.stdout or "")))
    return text:find("unknown command", 1, true) ~= nil
        or text:find("unrecognized subcommand", 1, true) ~= nil
        or text:find("unexpected argument", 1, true) ~= nil
        or text:find("did you mean", 1, true) ~= nil
end

plugin.fileExtensions = {}

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
    return { "Mojo", "Package Manager", "SDK" }
end

function plugin.getMissingPackages(packages)
    local flags = collect_flags(nil, packages)
    local modular_home = modular_home_from_flags(flags)
    local installed = installed_item(nil, modular_home) ~= nil
    local missing = {}

    for _, package in ipairs(packages or {}) do
        local action = lower(trim(read_field(package, "action") or "install"))
        if action == "remove" then
            if installed then
                missing[#missing + 1] = package
            end
        elseif action == "update" then
            if installed then
                missing[#missing + 1] = package
            end
        elseif not installed then
            missing[#missing + 1] = package
        end
    end

    return missing
end

function plugin.install(context, packages)
    if packages == nil or #packages == 0 then
        return true
    end

    local ok, err = ensure_supported_packages(packages)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local flags = collect_flags(context, packages)
    local command = env_prefix(flags) .. " modular install mojo"
    return run_mutation(context, "install mojo", command, "installed", packages)
end

function plugin.installLocal(context, path)
    begin_step(context, "install local mojo artifact")
    tx_failed(context, "modular mojo local installs are not supported")
    emit_event(context, "unavailable", {
        path = path,
        reason = "local-install-unsupported",
    })
    return false
end

function plugin.remove(context, packages)
    if packages == nil or #packages == 0 then
        return true
    end

    local ok, err = ensure_supported_packages(packages)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local flags = collect_flags(context, packages)
    begin_step(context, "remove mojo")
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end

    local uninstall_command = env_prefix(flags) .. " modular uninstall mojo"
    local uninstall_result = exec_run(context, uninstall_command)
    if uninstall_result == nil or not uninstall_result.success then
        tx_failed(context, trim(uninstall_result and uninstall_result.stderr or uninstall_result and uninstall_result.stdout or "mojo uninstall failed"))
        return false
    end

    if has_flag(flags, "clean") then
        local clean_command = env_prefix(flags) .. " modular clean"
        local clean_result = exec_run(context, clean_command)
        if clean_result == nil or not clean_result.success then
            tx_failed(context, trim(clean_result and clean_result.stderr or clean_result and clean_result.stdout or "modular clean failed"))
            return false
        end
    end

    emit_event(context, "deleted", packages)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    if packages == nil or #packages == 0 then
        return true
    end

    local ok, err = ensure_supported_packages(packages)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local flags = collect_flags(context, packages)
    begin_step(context, "update mojo")
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end

    local update_command = env_prefix(flags) .. " modular update mojo"
    local update_result = exec_run(context, update_command)
    if update_result == nil or not update_result.success then
        if update_needs_fallback(update_result) then
            local install_command = env_prefix(flags) .. " modular install mojo"
            local install_result = exec_run(context, install_command)
            if install_result == nil or not install_result.success then
                tx_failed(context, trim(install_result and install_result.stderr or install_result and install_result.stdout or "mojo update fallback failed"))
                return false
            end
        else
            tx_failed(context, trim(update_result and update_result.stderr or update_result and update_result.stdout or "mojo update failed"))
            return false
        end
    end

    emit_event(context, "updated", packages)
    tx_success(context)
    return true
end

function plugin.list(context)
    local flags = context_flags(context)
    local modular_home = modular_home_from_flags(flags)
    local item = installed_item(context, modular_home)
    local items = {}
    if item ~= nil then
        items[#items + 1] = item
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local empty = {}
    log_warn(context, "modular CLI has no reliable remote outdated query for mojo")
    emit_event(context, "outdated", empty)
    return empty
end

function plugin.search(context, prompt)
    local text = lower(trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt")))
    local flags = context_flags(context)
    local modular_home = modular_home_from_flags(flags)
    local items = {}

    if text == "" then
        emit_event(context, "searched", items)
        return items
    end

    if accepted_query_name(text) or text:find("mojo", 1, true) ~= nil or text:find("modular", 1, true) ~= nil then
        items[#items + 1] = available_item(modular_home)
    end

    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = trim(name or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt"))
    local flags = context_flags(context)
    local modular_home = modular_home_from_flags(flags)

    if query == "" or not accepted_query_name(query) then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local item = installed_item(context, modular_home) or available_item(modular_home)
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end

    local name = trim(read_field(package, "name") or read_field(package, "packageId") or "")
    if not accepted_query_name(name) then
        return nil
    end

    local flags = collect_flags(context, { package })
    local modular_home = modular_home_from_flags(flags)
    local item = installed_item(context, modular_home) or available_item(modular_home)
    if item == nil then
        return nil
    end

    local resolved = shallow_copy(package)
    for key, value in pairs(item) do
        resolved[key] = value
    end
    resolved.extraFields = merge_tables(read_field(package, "extraFields"), item.extraFields)
    return resolved
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "modular", "mojo" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".modular" },
        },
        networkScopes = {
            { host = "packages.modular.com", scheme = "https" },
            { host = "dl.modular.com", scheme = "https" },
        },
        privilegeLevel = "user",
    }
end

return plugin
