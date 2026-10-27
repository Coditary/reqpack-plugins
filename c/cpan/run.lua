plugin = {}

local PLUGIN_ID = "cpan"
local PLUGIN_NAME = "CPAN"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "cpan"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(trim(value))
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

local function object_field(value, key)
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
    local raw = object_field(value, "flags")
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
            return trim(cleaned:sub(#needle + 1))
        end
    end
    return ""
end

local function has_flag(flags, expected)
    local needle = lower(expected)
    for _, flag in ipairs(flags or {}) do
        if lower(flag) == needle then
            return true
        end
    end
    return false
end

local function add_arg(args, value)
    local cleaned = trim(value)
    if cleaned ~= "" then
        args[#args + 1] = cleaned
    end
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

local function run_exec(context, command)
    local result = nil
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        result = context.exec.run(command)
    elseif reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
        result = reqpack.exec.run(command)
    else
        result = {
            success = false,
            stdout = "",
            stderr = "missing ReqPack exec runner",
            exitCode = 127,
        }
    end

    if type(result) ~= "table" and type(result) ~= "userdata" then
        return {
            success = false,
            stdout = "",
            stderr = "command execution failed",
            exitCode = 1,
        }
    end

    local normalized = {}
    for _, key in ipairs({ "success", "ok", "stdout", "stdoutText", "stderr", "stderrText", "exitCode", "exit_code", "code", "status" }) do
        local ok, value = pcall(function()
            return result[key]
        end)
        if ok and value ~= nil then
            normalized[key] = value
        end
    end
    if normalized.stdout == nil then
        normalized.stdout = normalized.stdoutText or ""
    end
    if normalized.stderr == nil then
        normalized.stderr = normalized.stderrText or ""
    end
    if normalized.exitCode == nil then
        normalized.exitCode = normalized.exit_code or normalized.code or normalized.status
    end
    if normalized.success == nil and normalized.ok ~= nil then
        normalized.success = normalized.ok
    end
    if normalized.success == nil and normalized.exitCode ~= nil then
        normalized.success = normalized.exitCode == 0
    end
    return normalized
end

local function command_exists(binary)
    local result = run_exec(nil, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function get_plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR)
    if dir ~= "" then
        return dir
    end
    return "c/cpan"
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
        home = join_path(base, "home"),
        cpan_home = join_path(base, "cpan-home"),
        perl5 = join_path(base, "perl5"),
        perl5_lib = join_path(base, "perl5", "lib", "perl5"),
        perl5_bin = join_path(base, "perl5", "bin"),
    }
end

local function env_prefix(paths)
    return table.concat({
        "HOME=" .. shell_quote(paths.home),
        "PERL_CPAN_HOME=" .. shell_quote(paths.cpan_home),
        "PERL_MM_OPT=" .. shell_quote("INSTALL_BASE=" .. paths.perl5),
        "PERL_MB_OPT=" .. shell_quote("--install_base " .. paths.perl5),
        "PERL5LIB=" .. shell_quote(paths.perl5_lib),
        "PATH=" .. shell_quote(paths.perl5_bin .. ":$PATH"),
        "AUTOMATED_TESTING=1",
        "NONINTERACTIVE_TESTING=1",
        "PERL_MM_USE_DEFAULT=1",
    }, " ")
end

local function cpan_command(paths, args)
    local parts = { env_prefix(paths), REQUIRED_BINARY }
    for _, arg in ipairs(args or {}) do
        if trim(arg) ~= "" then
            parts[#parts + 1] = shell_quote(arg)
        end
    end
    return table.concat(parts, " ")
end

local function package_name(pkg)
    return trim(object_field(pkg, "name") or object_field(pkg, "packageName") or object_field(pkg, "packageId"))
end

local function package_version(pkg)
    return trim(object_field(pkg, "version"))
end

local function normalize_package(pkg)
    local name = package_name(pkg)
    if name == "" then
        return nil, "missing CPAN module name"
    end
    local flags = object_flags(pkg)
    local mirrors = {}
    for _, flag in ipairs(flags) do
        local mirror = flag_value({ flag }, "mirror=")
        if mirror ~= "" then
            mirrors[#mirrors + 1] = mirror
        end
    end
    return {
        name = name,
        version = package_version(pkg),
        mirrors = mirrors,
        force = has_flag(flags, "force"),
        notest = has_flag(flags, "notest"),
        sudo = has_flag(flags, "sudo"),
        prefer_mirror = has_flag(flags, "prefer-mirror"),
    }
end

local function package_error(context, message)
    tx_failed(context, message)
    emit_event(context, "failed", message)
    return false
end

local function available_or_read_empty(context)
    if command_exists(REQUIRED_BINARY) then
        return true
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function ensure_data_dirs(context, paths)
    local result = run_exec(context, "mkdir -p "
        .. shell_quote(paths.root) .. " "
        .. shell_quote(paths.home) .. " "
        .. shell_quote(paths.cpan_home) .. " "
        .. shell_quote(paths.perl5) .. " "
        .. shell_quote(paths.perl5_lib) .. " "
        .. shell_quote(paths.perl5_bin))
    return result ~= nil and result.success == true
end

local function merge_package_options(context, pkg)
    local context_flags = context and context.flags or {}
    local mirrors = {}
    for _, flag in ipairs(context_flags) do
        local mirror = flag_value({ flag }, "mirror=")
        if mirror ~= "" then
            mirrors[#mirrors + 1] = mirror
        end
    end
    if #pkg.mirrors > 0 then
        mirrors = pkg.mirrors
    end
    return {
        name = pkg.name,
        version = pkg.version,
        mirrors = mirrors,
        force = pkg.force or has_flag(context_flags, "force"),
        notest = pkg.notest or has_flag(context_flags, "notest"),
        sudo = pkg.sudo or has_flag(context_flags, "sudo"),
        prefer_mirror = pkg.prefer_mirror or has_flag(context_flags, "prefer-mirror"),
    }
end

local function cpan_args_for_pkg(pkg, action)
    local args = {}
    if #pkg.mirrors > 0 then
        add_arg(args, "-M")
        add_arg(args, table.concat(pkg.mirrors, ","))
    end
    if pkg.prefer_mirror then
        add_arg(args, "-P")
    end
    if pkg.force then
        add_arg(args, "-f")
    end
    if pkg.notest then
        add_arg(args, "-T")
    end
    add_arg(args, action)
    return args
end

local function install_selector(pkg)
    if pkg.version ~= "" then
        return pkg.name .. "@" .. pkg.version
    end
    return pkg.name
end

local function maybe_with_sudo(command, use_sudo)
    if use_sudo then
        return "sudo " .. command
    end
    return command
end

local function parse_list(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local name, version = line:match("^([^%s]+)%s+(.+)$")
        name = trim(name)
        version = trim(version)
        if name ~= "" and version ~= "" then
            items[#items + 1] = {
                name = name,
                packageId = name,
                version = version,
                latestVersion = version,
                installed = true,
                status = "installed",
                packageType = "perl-module",
            }
        end
    end
    table.sort(items, function(left, right)
        return lower(left.name) < lower(right.name)
    end)
    return items
end

local function parse_outdated(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" and not cleaned:match("^Module%s+Name") and not cleaned:match("^%-+") then
            local name, local_version, cpan_version = cleaned:match("^(%S+)%s+(%S+)%s+(%S+)%s*$")
            if name ~= nil then
                items[#items + 1] = {
                    name = name,
                    packageId = name,
                    version = local_version,
                    latestVersion = cpan_version,
                    installed = true,
                    status = "outdated",
                    packageType = "perl-module",
                }
            end
        end
    end
    return items
end

local function parse_info(stdout, requested)
    local item = {
        name = trim(requested),
        packageId = trim(requested),
        installed = false,
        status = "available",
        packageType = "perl-module",
    }

    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        local installed = cleaned:match("^Installed:%s*(%S+)")
        local remote = cleaned:match("^CPAN:%s*(%S+)")
        local author, dist = cleaned:match("^([A-Z0-9]+)/([%w%._%-%+]+)$")
        if installed ~= nil then
            item.version = installed
            item.installed = installed ~= "undef"
            if item.installed then
                item.status = "installed"
            end
        elseif remote ~= nil then
            item.latestVersion = remote
            if item.version ~= nil and remote ~= item.version then
                item.status = "outdated"
            end
        elseif author ~= nil and dist ~= nil then
            item.repository = "https://cpan.org/authors/id/" .. author:sub(1, 1) .. "/" .. author:sub(1, 2) .. "/" .. author .. "/" .. dist
            item.extraFields = item.extraFields or {}
            item.extraFields.author = author
            item.extraFields.distribution = dist
        end
    end

    if item.latestVersion == nil and item.version ~= nil then
        item.latestVersion = item.version
    end
    return item
end

local function detail_lookup(context, paths, name)
    local result = run_exec(context, cpan_command(paths, { "-D", name }))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_info(result.stdout, name)
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
    return { "perl", "package-manager" }
end

function plugin.getMissingPackages()
    if command_exists(REQUIRED_BINARY) then
        return {}
    end
    return { REQUIRED_BINARY }
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end

    local available, message = available_or_read_empty(context)
    if not available then
        return package_error(context, message)
    end

    begin_step(context, "install CPAN packages")
    local paths = state_paths(data_root_from_context(context, requested))
    if not ensure_data_dirs(context, paths) then
        return package_error(context, "failed to prepare CPAN data directories")
    end

    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        pkg = merge_package_options(context, pkg)
        local args = cpan_args_for_pkg(pkg, "-i")
        add_arg(args, install_selector(pkg))
        local result = run_exec(context, maybe_with_sudo(cpan_command(paths, args), pkg.sudo))
        if result == nil or result.success ~= true then
            return package_error(context, "cpan install failed for " .. pkg.name)
        end
    end

    emit_event(context, "installed", requested)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path or (context and context.localPath) or "")
    if local_path == "" then
        return package_error(context, "missing local path")
    end

    local available, message = available_or_read_empty(context)
    if not available then
        return package_error(context, message)
    end

    local lower_path = lower(local_path)
    if lower_path ~= "." and not lower_path:match("%.tar%.gz$") and not lower_path:match("%.tgz$") and not lower_path:match("%.zip$") then
        emit_event(context, "unavailable", { path = local_path, reason = "local-install-unsupported" })
        return package_error(context, "installLocal only supports current directory, .tar.gz, .tgz, and .zip")
    end

    begin_step(context, "install local CPAN package")
    local paths = state_paths(data_root_from_context(context, {}))
    if not ensure_data_dirs(context, paths) then
        return package_error(context, "failed to prepare CPAN data directories")
    end
    local result = run_exec(context, cpan_command(paths, { local_path }))
    if result == nil or result.success ~= true then
        return package_error(context, "cpan local install failed")
    end

    emit_event(context, "installed", { { name = local_path, packageId = local_path } })
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
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        if name ~= "" then
            emit_event(context, "unavailable", { name = name, reason = "remove-unsupported" })
        end
    end
    return package_error(context, "cpan remove is unsupported")
end

function plugin.update(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end

    local available, message = available_or_read_empty(context)
    if not available then
        return package_error(context, message)
    end

    begin_step(context, "update CPAN packages")
    local paths = state_paths(data_root_from_context(context, requested))
    if not ensure_data_dirs(context, paths) then
        return package_error(context, "failed to prepare CPAN data directories")
    end
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        pkg = merge_package_options(context, pkg)
        local args = cpan_args_for_pkg(pkg, "-u")
        add_arg(args, pkg.name)
        local result = run_exec(context, maybe_with_sudo(cpan_command(paths, args), pkg.sudo))
        if result == nil or result.success ~= true then
            return package_error(context, "cpan update failed for " .. pkg.name)
        end
    end
    emit_event(context, "updated", requested)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.list(context)
    local available, message = available_or_read_empty(context)
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "listed", items)
        return items
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local result = run_exec(context, cpan_command(paths, { "-l" }))
    if result == nil or result.success ~= true then
        log_warn(context, "cpan list failed")
        local items = {}
        emit_event(context, "listed", items)
        return items
    end

    local items = parse_list(result.stdout)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local available, message = available_or_read_empty(context)
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "outdated", items)
        return items
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local result = run_exec(context, cpan_command(paths, { "-O" }))
    if result == nil or result.success ~= true then
        log_warn(context, "cpan outdated failed")
        local items = {}
        emit_event(context, "outdated", items)
        return items
    end

    local items = parse_outdated(result.stdout)
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

    local available, message = available_or_read_empty(context)
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "searched", items)
        return items
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local item = detail_lookup(context, paths, cleaned_prompt)
    local items = {}
    if item ~= nil and trim(item.name) ~= "" then
        items[1] = item
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
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    local available, message = available_or_read_empty(context)
    if not available then
        log_warn(context, message)
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local item = detail_lookup(context, paths, cleaned_name)
    if item == nil then
        item = {}
        emit_event(context, "unavailable", { name = cleaned_name, reason = "not-found" })
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local pkg, err = normalize_package(package)
    if pkg == nil then
        return nil, err
    end
    if not command_exists(REQUIRED_BINARY) then
        return {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "perl-module",
        }
    end
    local paths = state_paths(data_root_from_context(context, { package }))
    local item = detail_lookup(context, paths, pkg.name)
    if item ~= nil then
        if pkg.version ~= "" then
            item.version = pkg.version
        end
        return item
    end
    return {
        name = pkg.name,
        packageId = pkg.name,
        version = pkg.version ~= "" and pkg.version or nil,
        packageType = "perl-module",
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "cpan", "perl" },
        writeScopes = {
            "plugin-data:c/cpan/.reqpack-data/cpan-home",
            "plugin-data:c/cpan/.reqpack-data/perl5",
        },
        networkScopes = {
            "https://cpan.org",
            "https://www.cpan.org",
            "https://cpan.metacpan.org",
        },
        privilegeLevel = "none",
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
