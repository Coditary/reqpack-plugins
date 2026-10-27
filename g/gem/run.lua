plugin = {}

local PLUGIN_ID = "gem"
local PLUGIN_NAME = "RubyGems"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "gem"

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

local function split_csv(value)
    local items = {}
    for item in tostring(value or ""):gmatch("([^,]+)") do
        local cleaned = trim(item)
        if cleaned ~= "" then
            items[#items + 1] = cleaned
        end
    end
    return items
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

    local value_type = type(result)
    if value_type == "table" then
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

    if value_type == "userdata" then
        local normalized = {}
        for _, key in ipairs({ "success", "ok", "exitCode", "exit_code", "code", "status", "stdout", "stdoutText", "stderr", "stderrText" }) do
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

    return {
        success = false,
        stdout = "",
        stderr = "command execution failed",
        exitCode = 1,
    }
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
    return "."
end

local function flag_value(flags, prefix)
    for _, flag in ipairs(flags or {}) do
        if flag:sub(1, #prefix) == prefix then
            return trim(flag:sub(#prefix + 1))
        end
    end
    return ""
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

    local env_root = os ~= nil and type(os.getenv) == "function" and trim(os.getenv("RQP_GEM_DATA_ROOT")) or ""
    if env_root ~= "" then
        return env_root
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
        gem_home = join_path(base, "gem-home"),
        gem_bin = join_path(base, "gem-bin"),
        spec_cache = join_path(base, "spec-cache"),
    }
end

local function gem_env_prefix(paths)
    return table.concat({
        "GEM_HOME=" .. shell_quote(paths.gem_home),
        "GEM_PATH=" .. shell_quote(paths.gem_home),
        "GEM_SPEC_CACHE=" .. shell_quote(paths.spec_cache),
        "GEMRC=/dev/null",
    }, " ")
end

local function gem_command(paths, args)
    local parts = { gem_env_prefix(paths), REQUIRED_BINARY }
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

local function package_action(pkg)
    return lower(trim(object_field(pkg, "action") or object_field(pkg, "requestedAction")))
end

local function normalize_package(pkg)
    local name = package_name(pkg)
    if name == "" then
        return nil, "missing gem name"
    end

    local flags = object_flags(pkg)
    local source = flag_value(flags, "source=")
    local prerelease = false
    local ignore_dependencies = false
    for _, flag in ipairs(flags) do
        if lower(flag) == "prerelease" then
            prerelease = true
        elseif lower(flag) == "ignore-dependencies" then
            ignore_dependencies = true
        end
    end

    return {
        name = name,
        version = package_version(pkg),
        source = source,
        prerelease = prerelease,
        ignore_dependencies = ignore_dependencies,
        raw = pkg,
    }, nil
end

local function parse_versions(raw)
    local versions = split_csv(raw)
    if #versions == 0 then
        local cleaned = trim(raw)
        if cleaned ~= "" then
            versions[1] = cleaned
        end
    end
    return versions
end

local function add_if_missing(target, value)
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

local function parse_detail_blocks(raw, installed_default)
    local items = {}
    local current = nil

    local function finish_current()
        if current == nil then
            return
        end

        local authors = {}
        local licenses = {}
        local executables = {}
        local summary_lines = {}
        local installed_path = nil
        local homepage = nil

        for _, line in ipairs(current.detail_lines) do
            local cleaned = trim(line)
            if cleaned ~= "" then
                local authors_value = cleaned:match("^Authors?:%s*(.+)$")
                local homepage_value = cleaned:match("^Homepage:%s*(.+)$")
                local license_value = cleaned:match("^Licenses?:%s*(.+)$")
                local installed_value = cleaned:match("^Installed at%s*%(default%)?:%s*(.+)$") or cleaned:match("^Installed at:%s*(.+)$")
                local executables_value = cleaned:match("^Executables?:%s*(.+)$")

                if authors_value ~= nil then
                    for _, author in ipairs(split_csv(authors_value:gsub(" and ", ","))) do
                        add_if_missing(authors, author)
                    end
                elseif homepage_value ~= nil then
                    homepage = trim(homepage_value)
                elseif license_value ~= nil then
                    for _, license in ipairs(split_csv(license_value)) do
                        add_if_missing(licenses, license)
                    end
                elseif installed_value ~= nil then
                    installed_path = trim(installed_value)
                elseif executables_value ~= nil then
                    for _, executable in ipairs(split_csv(executables_value)) do
                        add_if_missing(executables, executable)
                    end
                else
                    summary_lines[#summary_lines + 1] = cleaned
                end
            end
        end

        local versions = parse_versions(current.versions)
        local item = {
            name = current.name,
            packageId = current.name,
            version = versions[1],
            latestVersion = versions[1],
            installed = installed_default,
            status = installed_default and "installed" or "available",
            summary = table.concat(summary_lines, " "),
            homepage = homepage,
            authors = authors,
            binaries = executables,
            packageType = "gem",
            extraFields = {
                installedVersions = versions,
                installedPath = installed_path,
            },
        }

        if #licenses > 0 then
            item.license = table.concat(licenses, ", ")
        end

        items[#items + 1] = item
        current = nil
    end

    for _, line in ipairs(split_lines(raw)) do
        local name, versions = line:match("^([^%s][^%(]-)%s*%((.+)%)%s*$")
        if name ~= nil and versions ~= nil then
            finish_current()
            current = {
                name = trim(name),
                versions = trim(versions),
                detail_lines = {},
            }
        elseif current ~= nil then
            current.detail_lines[#current.detail_lines + 1] = line
        end
    end
    finish_current()

    return items
end

local function parse_outdated(raw)
    local items = {}
    for _, line in ipairs(split_lines(raw)) do
        local name, current_version, latest_version = line:match("^([^%s][^%(]-)%s*%(([^<]+)%s*<%s*([^)]+)%)%s*$")
        if name ~= nil then
            items[#items + 1] = {
                name = trim(name),
                packageId = trim(name),
                version = trim(current_version),
                latestVersion = trim(latest_version),
                installed = true,
                status = "outdated",
                packageType = "gem",
            }
        end
    end
    return items
end

local function strip_yaml_scalar(value)
    local cleaned = trim(value)
    if cleaned == "[]" then
        return ""
    end
    cleaned = cleaned:gsub("^['\"]", ""):gsub("['\"]$", "")
    return cleaned
end

local function parse_gemspec(raw, installed_default)
    local spec = {
        authors = {},
        licenses = {},
        executables = {},
        dependencies = {},
        extraFields = {},
        installed = installed_default,
        packageType = "gem",
    }

    local current_key = nil
    local in_dependency = false

    for _, line in ipairs(split_lines(raw)) do
        local top_key, top_value = line:match("^([A-Za-z_][A-Za-z0-9_]*):%s*(.*)$")
        if top_key ~= nil then
            current_key = top_key
            in_dependency = false
            local scalar = strip_yaml_scalar(top_value)

            if top_key == "name" then
                spec.name = scalar
                spec.packageId = scalar
            elseif top_key == "homepage" then
                spec.homepage = scalar
            elseif top_key == "summary" then
                spec.summary = scalar
            elseif top_key == "description" then
                spec.description = scalar
            elseif top_key == "platform" then
                spec.extraFields.platform = scalar
            elseif top_key == "authors" and scalar == "[]" then
                current_key = nil
            elseif top_key == "licenses" and scalar == "[]" then
                current_key = nil
            elseif top_key == "executables" and scalar == "[]" then
                current_key = nil
            elseif top_key == "dependencies" and scalar == "[]" then
                current_key = nil
            end
        elseif current_key == "version" then
            local nested = line:match("^%s+version:%s*'?([^']+)'?%s*$")
            if nested ~= nil then
                spec.version = trim(nested)
                spec.latestVersion = trim(nested)
                current_key = nil
            end
        elseif current_key == "authors" then
            local item = line:match("^%-%s*(.+)$")
            if item ~= nil then
                add_if_missing(spec.authors, strip_yaml_scalar(item))
            end
        elseif current_key == "licenses" then
            local item = line:match("^%-%s*(.+)$")
            if item ~= nil then
                add_if_missing(spec.licenses, strip_yaml_scalar(item))
            end
        elseif current_key == "executables" then
            local item = line:match("^%-%s*(.+)$")
            if item ~= nil then
                add_if_missing(spec.executables, strip_yaml_scalar(item))
            end
        elseif current_key == "dependencies" then
            if line:match("^%-%s*!ruby/object:Gem::Dependency") then
                in_dependency = true
            elseif in_dependency then
                local dep_name = line:match("^%s+name:%s*(.+)$")
                if dep_name ~= nil then
                    add_if_missing(spec.dependencies, strip_yaml_scalar(dep_name))
                    in_dependency = false
                end
            end
        elseif current_key == "metadata" then
            local metadata_key, metadata_value = line:match("^%s+([A-Za-z_][A-Za-z0-9_]*):%s*(.+)$")
            if metadata_key ~= nil then
                spec.extraFields[metadata_key] = strip_yaml_scalar(metadata_value)
            end
        elseif current_key == "required_ruby_version" then
            local nested = line:match("^%s+version:%s*'?([^']+)'?%s*$")
            if nested ~= nil then
                spec.extraFields.requiredRubyVersion = trim(nested)
            end
        end
    end

    if spec.name == nil or spec.name == "" then
        return nil
    end

    if #spec.licenses > 0 then
        spec.license = table.concat(spec.licenses, ", ")
    end
    if #spec.authors > 0 then
        spec.authors = spec.authors
    else
        spec.authors = nil
    end
    if #spec.executables > 0 then
        spec.binaries = spec.executables
    else
        spec.binaries = nil
    end
    spec.executables = nil
    if #spec.dependencies == 0 then
        spec.dependencies = nil
    end

    local source_uri = spec.extraFields.source_code_uri or spec.extraFields.homepage_uri
    if source_uri ~= nil and trim(source_uri) ~= "" then
        spec.extraFields.sourceUri = trim(source_uri)
    end
    if next(spec.extraFields) == nil then
        spec.extraFields = nil
    end

    spec.status = installed_default and "installed" or "available"
    return spec
end

local function collect_installed(context, paths)
    local result = run_exec(context, gem_command(paths, { "list", "--local", "--details", "--norc" }))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_detail_blocks(result.stdout, true)
end

local function collect_outdated(context, paths)
    local result = run_exec(context, gem_command(paths, { "outdated", "--norc" }))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_outdated(result.stdout)
end

local function info_lookup(context, paths, name, domain)
    local result = run_exec(context, gem_command(paths, { "specification", name, domain, "--yaml", "--norc" }))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_gemspec(result.stdout, domain == "--local")
end

local function available_or_read_empty(context)
    local result = run_exec(context, "command -v " .. shell_quote(REQUIRED_BINARY) .. " >/dev/null 2>&1")
    if result ~= nil and result.success == true then
        return true, nil
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function package_error(context, message)
    tx_failed(context, message)
    return false
end

local function install_args(paths, pkg)
    local args = {
        "install",
        pkg.name,
        "--install-dir", paths.gem_home,
        "--bindir", paths.gem_bin,
        "--no-document",
        "--norc",
    }
    if pkg.version ~= "" then
        args[#args + 1] = "--version"
        args[#args + 1] = pkg.version
    end
    if pkg.source ~= "" then
        args[#args + 1] = "--source"
        args[#args + 1] = pkg.source
    end
    if pkg.prerelease then
        args[#args + 1] = "--prerelease"
    end
    if pkg.ignore_dependencies then
        args[#args + 1] = "--ignore-dependencies"
    end
    return args
end

plugin.fileExtensions = { ".gem" }

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
    return { "Ruby", "Package Manager" }
end

function plugin.init()
    return true
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end

    local available = command_exists(REQUIRED_BINARY)
    if not available then
        local fallback = {}
        for _, pkg in ipairs(packages) do
            local action = package_action(pkg)
            if action == "install" or action == "" then
                fallback[#fallback + 1] = pkg
            end
        end
        return fallback
    end

    local paths = state_paths(data_root_from_context(nil, packages))
    local installed_items = collect_installed(nil, paths)
    if installed_items == nil then
        return packages
    end

    local installed_set = {}
    for _, item in ipairs(installed_items) do
        installed_set[lower(item.name)] = true
    end

    local needs_update = false
    for _, pkg in ipairs(packages) do
        if package_action(pkg) == "update" then
            needs_update = true
            break
        end
    end

    local outdated_set = {}
    if needs_update then
        local outdated_items = collect_outdated(nil, paths)
        if outdated_items == nil then
            return packages
        end
        for _, item in ipairs(outdated_items) do
            outdated_set[lower(item.name)] = true
        end
    end

    local filtered = {}
    for _, pkg in ipairs(packages) do
        local name = lower(package_name(pkg))
        local action = package_action(pkg)
        if action == "remove" then
            if installed_set[name] == true then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "update" then
            if outdated_set[name] == true then
                filtered[#filtered + 1] = pkg
            end
        elseif installed_set[name] ~= true then
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

    local available, message = available_or_read_empty(context)
    if not available then
        return package_error(context, message)
    end

    begin_step(context, "install gem packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local installed = {}

    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end

        local result = run_exec(context, gem_command(paths, install_args(paths, pkg)))
        if result == nil or result.success ~= true then
            return package_error(context, "gem install failed for " .. pkg.name)
        end
        installed[#installed + 1] = {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "gem",
        }
    end

    emit_event(context, "installed", installed)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.installLocal(context, path)
    local cleaned_path = trim(path)
    begin_step(context, "install local gem artifact")

    local available, message = available_or_read_empty(context)
    if not available then
        return package_error(context, message)
    end
    if cleaned_path == "" or lower(cleaned_path):sub(-4) ~= ".gem" then
        tx_failed(context, "unsupported local gem artifact type")
        emit_event(context, "unavailable", {
            path = cleaned_path,
            reason = "local-install-unsupported",
        })
        return false
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local result = run_exec(context, gem_command(paths, {
        "install",
        "--local",
        cleaned_path,
        "--install-dir", paths.gem_home,
        "--bindir", paths.gem_bin,
        "--no-document",
        "--norc",
    }))
    if result == nil or result.success ~= true then
        return package_error(context, "gem local install failed")
    end

    emit_event(context, "installed", {
        path = cleaned_path,
        localTarget = true,
    })
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

    local available, message = available_or_read_empty(context)
    if not available then
        return package_error(context, message)
    end

    begin_step(context, "remove gem packages")
    local paths = state_paths(data_root_from_context(context, requested))

    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end

        local result = run_exec(context, gem_command(paths, {
            "uninstall",
            pkg.name,
            "--install-dir", paths.gem_home,
            "--bindir", paths.gem_bin,
            "--all",
            "--executables",
            "--ignore-dependencies",
            "--norc",
        }))
        if result == nil or result.success ~= true then
            return package_error(context, "gem uninstall failed for " .. pkg.name)
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

    local available, message = available_or_read_empty(context)
    if not available then
        return package_error(context, message)
    end

    begin_step(context, "update gem packages")
    local paths = state_paths(data_root_from_context(context, requested))

    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end

        local args = nil
        if pkg.version ~= "" then
            args = install_args(paths, pkg)
        else
            args = {
                "update",
                pkg.name,
                "--install-dir", paths.gem_home,
                "--bindir", paths.gem_bin,
                "--no-document",
                "--norc",
            }
            if pkg.source ~= "" then
                args[#args + 1] = "--source"
                args[#args + 1] = pkg.source
            end
            if pkg.prerelease then
                args[#args + 1] = "--prerelease"
            end
        end

        local result = run_exec(context, gem_command(paths, args))
        if result == nil or result.success ~= true then
            return package_error(context, "gem update failed for " .. pkg.name)
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
    local result = run_exec(context, gem_command(paths, { "list", "--local", "--details", "--norc" }))
    if result == nil or result.success ~= true then
        log_warn(context, "gem list failed")
        local items = {}
        emit_event(context, "listed", items)
        return items
    end

    local items = parse_detail_blocks(result.stdout, true)
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
    local result = run_exec(context, gem_command(paths, { "outdated", "--norc" }))
    if result == nil or result.success ~= true then
        log_warn(context, "gem outdated failed")
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
    local result = run_exec(context, gem_command(paths, { "search", "--remote", "--details", cleaned_prompt, "--norc" }))
    if result == nil or result.success ~= true then
        log_warn(context, "gem search failed")
        local items = {}
        emit_event(context, "searched", items)
        return items
    end

    local items = parse_detail_blocks(result.stdout, false)
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
    local item = info_lookup(context, paths, cleaned_name, "--local")
    if item == nil then
        item = info_lookup(context, paths, cleaned_name, "--remote")
    end
    if item == nil then
        item = {}
        emit_event(context, "unavailable", {
            name = cleaned_name,
            reason = "not-found",
        })
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local pkg, err = normalize_package(package)
    if pkg == nil then
        return nil, err
    end

    local available = command_exists(REQUIRED_BINARY)
    if not available then
        return {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "gem",
        }
    end

    local paths = state_paths(data_root_from_context(context, { package }))
    local item = info_lookup(context, paths, pkg.name, "--remote") or info_lookup(context, paths, pkg.name, "--local")
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
        packageType = "gem",
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "rubygems", "ruby" },
        writeScopes = {
            "plugin-data:g/gem/.reqpack-data/gem-home",
            "plugin-data:g/gem/.reqpack-data/gem-bin",
            "plugin-data:g/gem/.reqpack-data/spec-cache",
        },
        networkScopes = { "https://rubygems.org" },
        privilegeLevel = "none",
        purlType = "gem",
        osvEcosystem = "RubyGems",
    }
end

function plugin.shutdown()
    return true
end

return plugin
