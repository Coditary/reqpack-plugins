plugin = {}

local PLUGIN_ID = "cpanm"
local PLUGIN_NAME = "cpanm"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "cpanm"

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
    return "c/cpanm"
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
        cpanm_home = join_path(base, "cpanm-home"),
        perl5 = join_path(base, "perl5"),
        perl5_lib = join_path(base, "perl5", "lib", "perl5"),
        perl5_bin = join_path(base, "perl5", "bin"),
    }
end

local function env_prefix(paths)
    return table.concat({
        "PERL_CPANM_HOME=" .. shell_quote(paths.cpanm_home),
        "PERL_MM_OPT=" .. shell_quote("INSTALL_BASE=" .. paths.perl5),
        "PERL_MB_OPT=" .. shell_quote("--install_base " .. paths.perl5),
        "PERL5LIB=" .. shell_quote(paths.perl5_lib),
        "PATH=" .. shell_quote(paths.perl5_bin .. ":$PATH"),
        "AUTOMATED_TESTING=1",
        "NONINTERACTIVE_TESTING=1",
        "PERL_MM_USE_DEFAULT=1",
    }, " ")
end

local function cpanm_command(paths, args, binary)
    local parts = { env_prefix(paths), trim(binary) ~= "" and binary or REQUIRED_BINARY }
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
        return nil, "missing cpanm module name"
    end
    local flags = object_flags(pkg)
    return {
        name = name,
        version = package_version(pkg),
        version_range = flag_value(flags, "version-range="),
        mirror = flag_value(flags, "mirror="),
        from = flag_value(flags, "from="),
        mirror_only = has_flag(flags, "mirror-only"),
        force = has_flag(flags, "force"),
        notest = has_flag(flags, "notest"),
        sudo = has_flag(flags, "sudo"),
        reinstall = has_flag(flags, "reinstall"),
        dev = has_flag(flags, "dev"),
        self_contained = has_flag(flags, "self-contained"),
        exclude_vendor = has_flag(flags, "exclude-vendor"),
        cascade_search = has_flag(flags, "cascade-search"),
        skip_installed = has_flag(flags, "skip-installed"),
        skip_satisfied = has_flag(flags, "skip-satisfied"),
    }
end

local function package_error(context, message)
    tx_failed(context, message)
    emit_event(context, "failed", message)
    return false
end

local function binary_available(context)
    local result = run_exec(context, "command -v " .. shell_quote(REQUIRED_BINARY) .. " >/dev/null 2>&1")
    if result ~= nil and result.success == true then
        return true
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function perl_available(context)
    local result = run_exec(context, "command -v perl >/dev/null 2>&1")
    if result ~= nil and result.success == true then
        return true
    end
    return false, "perl binary not available"
end

local function install_args(pkg)
    local args = {}
    if pkg.mirror ~= "" then
        args[#args + 1] = "--mirror"
        args[#args + 1] = pkg.mirror
    end
    if pkg.from ~= "" then
        args[#args + 1] = "--from"
        args[#args + 1] = pkg.from
    end
    if pkg.mirror_only then
        args[#args + 1] = "--mirror-only"
    end
    if pkg.dev then
        args[#args + 1] = "--dev"
    end
    if pkg.force then
        args[#args + 1] = "--force"
    end
    if pkg.notest then
        args[#args + 1] = "--notest"
    end
    if pkg.reinstall then
        args[#args + 1] = "--reinstall"
    end
    if pkg.self_contained then
        args[#args + 1] = "--self-contained"
    end
    if pkg.exclude_vendor then
        args[#args + 1] = "--exclude-vendor"
    end
    if pkg.cascade_search then
        args[#args + 1] = "--cascade-search"
    end
    if pkg.skip_installed then
        args[#args + 1] = "--skip-installed"
    end
    if pkg.skip_satisfied then
        args[#args + 1] = "--skip-satisfied"
    end
    return args
end

local function ensure_data_dirs(context, paths)
    local result = run_exec(context, "mkdir -p "
        .. shell_quote(paths.root) .. " "
        .. shell_quote(paths.home) .. " "
        .. shell_quote(paths.cpan_home) .. " "
        .. shell_quote(paths.cpanm_home) .. " "
        .. shell_quote(paths.perl5) .. " "
        .. shell_quote(paths.perl5_lib) .. " "
        .. shell_quote(paths.perl5_bin))
    return result ~= nil and result.success == true
end

local function cpan_env_prefix(paths)
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

local function local_cpanm_binary(paths)
    return join_path(paths.perl5_bin, REQUIRED_BINARY)
end

local function path_is_executable(context, path)
    local result = run_exec(context, "test -x " .. shell_quote(path))
    return result ~= nil and result.success == true
end

local function bootstrap_requested(context, packages)
    if context ~= nil and has_flag(context.flags or {}, "bootstrap") then
        return true
    end
    for _, pkg in ipairs(packages or {}) do
        if has_flag(object_flags(pkg), "bootstrap") then
            return true
        end
    end
    return false
end

local function bootstrap_cpanm(context, paths)
    if not command_exists("cpan") then
        return nil, REQUIRED_BINARY .. " binary not available and cpan bootstrap unavailable"
    end
    local command = cpan_env_prefix(paths) .. " cpan -T -i App::cpanminus"
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        return nil, "cpanm bootstrap failed"
    end

    return local_cpanm_binary(paths), nil
end

local function ensure_cpanm_binary(context, paths, packages)
    if command_exists(REQUIRED_BINARY) then
        return REQUIRED_BINARY, nil
    end

    local local_binary = local_cpanm_binary(paths)
    if path_is_executable(context, local_binary) then
        return local_binary, nil
    end
    if not bootstrap_requested(context, packages) then
        return nil, REQUIRED_BINARY .. " binary not available"
    end
    if not ensure_data_dirs(context, paths) then
        return nil, "failed to prepare cpanm data directories"
    end
    return bootstrap_cpanm(context, paths)
end

local function install_selector(pkg)
    if pkg.version ~= "" then
        return pkg.name .. "@" .. pkg.version
    end
    if pkg.version_range ~= "" then
        return pkg.name .. "~" .. pkg.version_range
    end
    return pkg.name
end

local function maybe_with_sudo(command, use_sudo)
    if use_sudo then
        return "sudo " .. command
    end
    return command
end

local function merge_package_options(context, pkg)
    local context_flags = context and context.flags or {}
    return {
        name = pkg.name,
        version = pkg.version,
        version_range = pkg.version_range ~= "" and pkg.version_range or flag_value(context_flags, "version-range="),
        mirror = pkg.mirror ~= "" and pkg.mirror or flag_value(context_flags, "mirror="),
        from = pkg.from ~= "" and pkg.from or flag_value(context_flags, "from="),
        mirror_only = pkg.mirror_only or has_flag(context_flags, "mirror-only"),
        force = pkg.force or has_flag(context_flags, "force"),
        notest = pkg.notest or has_flag(context_flags, "notest"),
        sudo = pkg.sudo or has_flag(context_flags, "sudo"),
        reinstall = pkg.reinstall or has_flag(context_flags, "reinstall"),
        dev = pkg.dev or has_flag(context_flags, "dev"),
        self_contained = pkg.self_contained or has_flag(context_flags, "self-contained"),
        exclude_vendor = pkg.exclude_vendor or has_flag(context_flags, "exclude-vendor"),
        cascade_search = pkg.cascade_search or has_flag(context_flags, "cascade-search"),
        skip_installed = pkg.skip_installed or has_flag(context_flags, "skip-installed"),
        skip_satisfied = pkg.skip_satisfied or has_flag(context_flags, "skip-satisfied"),
    }
end

local function parse_list(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local name, version = trim(line):match("^([^%s]+)%s+(.+)$")
        if name ~= nil and version ~= nil then
            items[#items + 1] = {
                name = name,
                packageId = name,
                version = trim(version),
                latestVersion = trim(version),
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

local function list_command(paths)
    local perl_code = "use ExtUtils::Installed; my $i = ExtUtils::Installed->new(skip_cwd => 1); for my $m (sort $i->modules) { my $v = eval { $i->version($m) }; $v = defined($v) && $v ne q{} ? $v : q{undef}; print $m, qq{ }, $v, qq{\\n}; }"
    return env_prefix(paths) .. " perl -MExtUtils::Installed -e " .. shell_quote(perl_code)
end

local function installed_lookup(context, paths)
    local result = run_exec(context, list_command(paths))
    if result == nil or result.success ~= true then
        return nil
    end

    local lookup = {}
    for _, item in ipairs(parse_list(result.stdout)) do
        lookup[lower(item.name)] = item
    end
    return lookup
end

local function parse_info(stdout, requested, installed)
    local cleaned = trim(stdout)
    if cleaned == "" then
        return nil
    end

    local item = {
        name = trim(requested),
        packageId = trim(requested),
        installed = installed ~= nil,
        status = installed ~= nil and "installed" or "available",
        packageType = "perl-module",
    }
    if installed ~= nil then
        item.version = installed.version
        item.latestVersion = installed.version
    end

    local dist = cleaned:match("([^\n]+)")
    if dist ~= nil then
        item.extraFields = { distribution = trim(dist) }
        local version = trim(dist):match("%-([0-9][A-Za-z0-9%._%-]*)%.t")
        if version ~= nil and version ~= "" then
            item.latestVersion = version
            if item.version ~= nil and item.version ~= version then
                item.status = "outdated"
            end
        end
    end
    return item
end

local function query_info(context, paths, name, installed, binary)
    local result = run_exec(context, cpanm_command(paths, { "--info", name }, binary))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_info(result.stdout, name, installed)
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

    begin_step(context, "install cpanm packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local binary, ensure_error = ensure_cpanm_binary(context, paths, requested)
    if binary == nil then
        return package_error(context, ensure_error)
    end
    if not ensure_data_dirs(context, paths) then
        return package_error(context, "failed to prepare cpanm data directories")
    end
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        pkg = merge_package_options(context, pkg)
        local args = install_args(pkg)
        add_arg(args, install_selector(pkg))
        local result = run_exec(context, maybe_with_sudo(cpanm_command(paths, args, binary), pkg.sudo))
        if result == nil or result.success ~= true then
            return package_error(context, "cpanm install failed for " .. pkg.name)
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

    local lower_path = lower(local_path)
    if not (lower_path == "." or lower_path:match("^/") or lower_path:match("^%./") or lower_path:match("^%.%./")) then
        emit_event(context, "unavailable", { path = local_path, reason = "local-install-unsupported" })
        return package_error(context, "installLocal only supports local directories and local artifact paths")
    end

    begin_step(context, "install local cpanm package")
    local paths = state_paths(data_root_from_context(context, {}))
    local binary, ensure_error = ensure_cpanm_binary(context, paths, {})
    if binary == nil then
        return package_error(context, ensure_error)
    end
    if not ensure_data_dirs(context, paths) then
        return package_error(context, "failed to prepare cpanm data directories")
    end
    local result = run_exec(context, cpanm_command(paths, { local_path }, binary))
    if result == nil or result.success ~= true then
        return package_error(context, "cpanm local install failed")
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

    begin_step(context, "remove cpanm packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local binary, ensure_error = ensure_cpanm_binary(context, paths, requested)
    if binary == nil then
        return package_error(context, ensure_error)
    end
    if not ensure_data_dirs(context, paths) then
        return package_error(context, "failed to prepare cpanm data directories")
    end
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        pkg = merge_package_options(context, pkg)
        local result = run_exec(context, maybe_with_sudo(cpanm_command(paths, { "--uninstall", pkg.name }, binary), pkg.sudo))
        if result == nil or result.success ~= true then
            return package_error(context, "cpanm uninstall failed for " .. pkg.name)
        end
    end
    emit_event(context, "deleted", requested)
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

    begin_step(context, "update cpanm packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local binary, ensure_error = ensure_cpanm_binary(context, paths, requested)
    if binary == nil then
        return package_error(context, ensure_error)
    end
    if not ensure_data_dirs(context, paths) then
        return package_error(context, "failed to prepare cpanm data directories")
    end
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        pkg = merge_package_options(context, pkg)
        local args = install_args(pkg)
        add_arg(args, install_selector(pkg))
        if not pkg.reinstall then
            args[#args + 1] = "--reinstall"
        end
        local result = run_exec(context, maybe_with_sudo(cpanm_command(paths, args, binary), pkg.sudo))
        if result == nil or result.success ~= true then
            return package_error(context, "cpanm update failed for " .. pkg.name)
        end
    end
    emit_event(context, "updated", requested)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.list(context)
    local binary_ok, binary_message = binary_available(context)
    if not binary_ok then
        log_warn(context, binary_message)
        local items = {}
        emit_event(context, "listed", items)
        return items
    end

    local perl_ok, perl_message = perl_available(context)
    if not perl_ok then
        log_warn(context, perl_message)
        local items = {}
        emit_event(context, "listed", items)
        return items
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local result = run_exec(context, list_command(paths))
    if result == nil or result.success ~= true then
        log_warn(context, "cpanm list probe failed")
        local items = {}
        emit_event(context, "listed", items)
        return items
    end
    local items = parse_list(result.stdout)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items = {}
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

    local paths = state_paths(data_root_from_context(context, {}))
    local binary, message = ensure_cpanm_binary(context, paths, {})
    if binary == nil then
        log_warn(context, message)
        local items = {}
        emit_event(context, "searched", items)
        return items
    end
    local installed = installed_lookup(context, paths) or {}
    local item = query_info(context, paths, cleaned_prompt, installed[lower(cleaned_prompt)], binary)
    local items = {}
    if item ~= nil then
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

    local paths = state_paths(data_root_from_context(context, {}))
    local binary, message = ensure_cpanm_binary(context, paths, {})
    if binary == nil then
        log_warn(context, message)
        local item = {}
        emit_event(context, "informed", item)
        return item
    end
    local installed = installed_lookup(context, paths) or {}
    local item = query_info(context, paths, cleaned_name, installed[lower(cleaned_name)], binary)
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
    local installed = installed_lookup(context, paths) or {}
    local item = query_info(context, paths, pkg.name, installed[lower(pkg.name)])
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
            "plugin-data:c/cpanm/.reqpack-data/cpanm-home",
            "plugin-data:c/cpanm/.reqpack-data/perl5",
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
