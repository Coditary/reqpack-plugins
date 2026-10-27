plugin = {}

local PLUGIN_ID = "opam"
local PLUGIN_NAME = "opam"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "opam"
local CLI_VERSION = "2.1"
local ENV_PREFIX = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C OPAMNOSELFUPGRADE=true OPAMUTF8=never"
local FIELD_SEPARATOR = "|^|"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return trim(value):lower()
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

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function command_quote(value)
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,]+$") ~= nil then
        return text
    end
    return shell_quote(text)
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

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
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

local function command_exists(binary)
    return is_command_success(exec_run(nil, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
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

local function has_flag(flags, key)
    local wanted = lower(key)
    for _, flag in ipairs(flags or {}) do
        if lower(flag) == wanted then
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

local function get_plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR)
    if dir ~= "" then
        return dir
    end
    return join_path("o", "opam")
end

local function root_from_flags(flags)
    local explicit_root = trim(flag_value(flags, "root") or "")
    if explicit_root ~= "" then
        return explicit_root
    end
    local data_root = trim(flag_value(flags, "data-root") or "")
    if data_root ~= "" then
        return join_path(data_root, "opam-root")
    end
    return nil
end

local function switch_from_flags(flags)
    local value = trim(flag_value(flags, "switch") or "")
    if value ~= "" then
        return value
    end
    return nil
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageId") or read_field(pkg, "packageName"))
end

local function package_version(pkg)
    return trim(read_field(pkg, "version"))
end

local function normalize_package(pkg)
    local name = package_name(pkg)
    if name == "" then
        return nil, "missing opam package name"
    end
    local flags = object_flags(pkg)
    return {
        name = name,
        version = package_version(pkg),
        constraint = trim(flag_value(flags, "constraint") or ""),
    }
end

local function package_spec(pkg)
    if pkg.constraint ~= "" then
        return pkg.name .. pkg.constraint
    end
    if pkg.version ~= "" then
        return pkg.name .. "." .. pkg.version
    end
    return pkg.name
end

local function add_base_args(parts, flags, mutation)
    parts[#parts + 1] = REQUIRED_BINARY
    parts[#parts + 1] = "--cli=" .. CLI_VERSION
    parts[#parts + 1] = "--color=never"
    if mutation then
        parts[#parts + 1] = "--yes"
    end

    local root = root_from_flags(flags)
    if root ~= nil then
        parts[#parts + 1] = "--root"
        parts[#parts + 1] = root
    end

    local switch = switch_from_flags(flags)
    if switch ~= nil and not has_flag(flags, "no-switch") then
        parts[#parts + 1] = "--switch"
        parts[#parts + 1] = switch
    end
end

local function add_common_action_flags(parts, flags)
    local boolean_flags = {
        ["with-test"] = "--with-test",
        ["with-doc"] = "--with-doc",
        ["with-dev-setup"] = "--with-dev-setup",
        ["assume-depexts"] = "--assume-depexts",
        ["no-depexts"] = "--no-depexts",
        ["best-effort"] = "--best-effort",
        ["working-dir"] = "--working-dir",
        ["locked"] = "--locked",
        ["keep-build-dir"] = "--keep-build-dir",
        ["reuse-build-dir"] = "--reuse-build-dir",
        ["inplace-build"] = "--inplace-build",
        ["ignore-pin-depends"] = "--ignore-pin-depends",
    }

    for key, cli_flag in pairs(boolean_flags) do
        if has_flag(flags, key) then
            parts[#parts + 1] = cli_flag
        end
    end

    local criteria = trim(flag_value(flags, "criteria") or "")
    if criteria ~= "" then
        parts[#parts + 1] = "--criteria"
        parts[#parts + 1] = criteria
    end

    local jobs = trim(flag_value(flags, "jobs") or "")
    if jobs ~= "" then
        parts[#parts + 1] = "--jobs"
        parts[#parts + 1] = jobs
    end
end

local function add_query_selector_flags(parts, flags)
    if has_flag(flags, "no-switch") then
        parts[#parts + 1] = "--no-switch"
    end
end

local function build_command(parts)
    local command = { ENV_PREFIX }
    for _, part in ipairs(parts or {}) do
        local cleaned = trim(part)
        if cleaned ~= "" then
            command[#command + 1] = command_quote(cleaned)
        end
    end
    return table.concat(command, " ")
end

local function opam_install_command(flags, specs)
    local parts = {}
    add_base_args(parts, flags, true)
    parts[#parts + 1] = "install"
    add_common_action_flags(parts, flags)
    for _, spec in ipairs(specs or {}) do
        parts[#parts + 1] = spec
    end
    return build_command(parts)
end

local function opam_remove_command(flags, specs)
    local parts = {}
    add_base_args(parts, flags, true)
    parts[#parts + 1] = "remove"
    add_common_action_flags(parts, flags)
    for _, spec in ipairs(specs or {}) do
        parts[#parts + 1] = spec
    end
    return build_command(parts)
end

local function opam_update_command(flags)
    local parts = {}
    add_base_args(parts, flags, true)
    parts[#parts + 1] = "update"
    return build_command(parts)
end

local function opam_upgrade_command(flags, specs, check_only)
    local parts = {}
    add_base_args(parts, flags, not check_only)
    parts[#parts + 1] = "upgrade"
    if check_only then
        parts[#parts + 1] = "--check"
    else
        add_common_action_flags(parts, flags)
    end
    for _, spec in ipairs(specs or {}) do
        parts[#parts + 1] = spec
    end
    return build_command(parts)
end

local function opam_list_command(flags, prompt)
    local parts = {}
    add_base_args(parts, flags, false)
    parts[#parts + 1] = "list"
    parts[#parts + 1] = "--installed"
    parts[#parts + 1] = "--columns=name,installed-version,synopsis,repository"
    parts[#parts + 1] = "--separator=" .. FIELD_SEPARATOR
    parts[#parts + 1] = "--short"
    if trim(prompt or "") ~= "" then
        parts[#parts + 1] = prompt
    end
    return build_command(parts)
end

local function opam_search_command(flags, prompt)
    local parts = {}
    add_base_args(parts, flags, false)
    parts[#parts + 1] = "list"
    parts[#parts + 1] = "--search"
    add_query_selector_flags(parts, flags)
    parts[#parts + 1] = "--columns=name,version,synopsis,repository"
    parts[#parts + 1] = "--separator=" .. FIELD_SEPARATOR
    parts[#parts + 1] = "--short"
    parts[#parts + 1] = prompt
    return build_command(parts)
end

local function opam_show_field_command(flags, name, field)
    local parts = {}
    add_base_args(parts, flags, false)
    parts[#parts + 1] = "show"
    parts[#parts + 1] = "--field=" .. field
    parts[#parts + 1] = name
    return build_command(parts)
end

local function parse_delimited_lines(output, expected_fields)
    local items = {}
    for _, line in ipairs(split_lines(output)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            local fields = {}
            local start_index = 1
            while true do
                local found_start, found_end = cleaned:find(FIELD_SEPARATOR, start_index, true)
                if found_start == nil then
                    fields[#fields + 1] = cleaned:sub(start_index)
                    break
                end
                fields[#fields + 1] = cleaned:sub(start_index, found_start - 1)
                start_index = found_end + 1
            end
            if #fields >= expected_fields then
                items[#items + 1] = fields
            end
        end
    end
    return items
end

local function package_error(context, message)
    tx_failed(context, message)
    emit_event(context, "failed", message)
    return false
end

local function ensure_binary(context)
    if command_exists(REQUIRED_BINARY) then
        return true
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function query_field(context, flags, name, field, extra_exit_codes)
    local result = exec_run(context, opam_show_field_command(flags, name, field))
    if not is_command_success(result, extra_exit_codes) then
        return nil, trim(result.stderr)
    end
    local value = trim(result.stdout)
    if value == "" then
        return nil
    end
    return value
end

local function list_installed_items(context, flags)
    local result = exec_run(context, opam_list_command(flags, nil))
    if not is_command_success(result) then
        return nil, trim(result.stderr)
    end

    local items = {}
    for _, fields in ipairs(parse_delimited_lines(result.stdout, 4)) do
        items[#items + 1] = {
            name = trim(fields[1]),
            packageId = trim(fields[1]),
            version = trim(fields[2]),
            installedVersion = trim(fields[2]),
            summary = trim(fields[3]),
            description = trim(fields[3]),
            repository = trim(fields[4]),
            installed = true,
            status = "installed",
            packageType = "opam",
        }
    end
    table.sort(items, function(left, right)
        return lower(left.name) < lower(right.name)
    end)
    return items
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
    return { "package-manager", "ocaml", "opam" }
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
        emit_event(context, "success", "ok")
        return true
    end

    local available, message = ensure_binary(context)
    if not available then
        return package_error(context, message)
    end

    local flags = collect_flags(context, requested)
    local specs = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        specs[#specs + 1] = package_spec(pkg)
    end

    begin_step(context, "install opam packages")
    local result = exec_run(context, opam_install_command(flags, specs))
    if not is_command_success(result) then
        return package_error(context, trim(result.stderr) ~= "" and trim(result.stderr) or "opam install failed")
    end

    emit_event(context, "installed", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.installLocal(context, path)
    local cleaned_path = trim(path)
    if cleaned_path == "" then
        return package_error(context, "missing local opam path")
    end

    local available, message = ensure_binary(context)
    if not available then
        return package_error(context, message)
    end

    local flags = collect_flags(context, {})
    begin_step(context, "install local opam package")
    local result = exec_run(context, opam_install_command(flags, { cleaned_path }))
    if not is_command_success(result) then
        return package_error(context, trim(result.stderr) ~= "" and trim(result.stderr) or "opam local install failed")
    end

    emit_event(context, "installed", {
        path = cleaned_path,
        localTarget = true,
    })
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        emit_event(context, "success", "ok")
        return true
    end

    local available, message = ensure_binary(context)
    if not available then
        return package_error(context, message)
    end

    local flags = collect_flags(context, requested)
    local specs = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        specs[#specs + 1] = package_spec(pkg)
    end

    begin_step(context, "remove opam packages")
    local result = exec_run(context, opam_remove_command(flags, specs))
    if not is_command_success(result) then
        return package_error(context, trim(result.stderr) ~= "" and trim(result.stderr) or "opam remove failed")
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    local available, message = ensure_binary(context)
    if not available then
        return package_error(context, message)
    end

    local flags = collect_flags(context, requested)
    local specs = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return package_error(context, err)
        end
        specs[#specs + 1] = package_spec(pkg)
    end

    begin_step(context, "update opam packages")
    local refresh = exec_run(context, opam_update_command(flags))
    if not is_command_success(refresh) then
        return package_error(context, trim(refresh.stderr) ~= "" and trim(refresh.stderr) or "opam update failed")
    end

    local result = exec_run(context, opam_upgrade_command(flags, specs, false))
    if not is_command_success(result) then
        return package_error(context, trim(result.stderr) ~= "" and trim(result.stderr) or "opam upgrade failed")
    end

    emit_event(context, "updated", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.list(context)
    local available, message = ensure_binary(context)
    if not available then
        log_warn(context, message)
        local empty = {}
        emit_event(context, "listed", empty)
        return empty
    end

    local flags = collect_flags(context, {})
    local items, err = list_installed_items(context, flags)
    if items == nil then
        log_warn(context, err ~= "" and err or "opam list failed")
        local empty = {}
        emit_event(context, "listed", empty)
        return empty
    end

    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local available, message = ensure_binary(context)
    if not available then
        log_warn(context, message)
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end

    local flags = collect_flags(context, {})
    local refresh = exec_run(context, opam_update_command(flags))
    if not is_command_success(refresh) then
        log_warn(context, trim(refresh.stderr) ~= "" and trim(refresh.stderr) or "opam update failed before outdated check")
    end

    local installed_items, err = list_installed_items(context, flags)
    if installed_items == nil then
        log_warn(context, err ~= "" and err or "opam list failed")
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end

    local items = {}
    for _, installed_item in ipairs(installed_items) do
        local check = exec_run(context, opam_upgrade_command(flags, { installed_item.name }, true))
        if is_command_success(check, { 1 }) and (check.exitCode or check.exit_code or check.code or check.status) == 0 then
            local latest_version = query_field(context, flags, installed_item.name, "version", { 5 })
            items[#items + 1] = {
                name = installed_item.name,
                packageId = installed_item.packageId,
                version = installed_item.version,
                installedVersion = installed_item.installedVersion,
                latestVersion = latest_version or installed_item.version,
                summary = installed_item.summary,
                description = installed_item.description,
                repository = installed_item.repository,
                installed = true,
                status = "outdated",
                packageType = "opam",
            }
        end
    end

    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned_prompt = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt"))
    if cleaned_prompt == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local available, message = ensure_binary(context)
    if not available then
        log_warn(context, message)
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local flags = collect_flags(context, {})
    local result = exec_run(context, opam_search_command(flags, cleaned_prompt))
    if not is_command_success(result) then
        log_warn(context, trim(result.stderr) ~= "" and trim(result.stderr) or "opam search failed")
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local items = {}
    for _, fields in ipairs(parse_delimited_lines(result.stdout, 4)) do
        items[#items + 1] = {
            name = trim(fields[1]),
            packageId = trim(fields[1]),
            version = trim(fields[2]),
            summary = trim(fields[3]),
            description = trim(fields[3]),
            repository = trim(fields[4]),
            installed = false,
            status = "available",
            packageType = "opam",
        }
    end

    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local cleaned_name = trim(name or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt"))
    if cleaned_name == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local available, message = ensure_binary(context)
    if not available then
        log_warn(context, message)
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local flags = collect_flags(context, {})
    local version = query_field(context, flags, cleaned_name, "version", { 5 })
    if version == nil then
        local empty = {}
        emit_event(context, "unavailable", {
            name = cleaned_name,
            reason = "not-found",
        })
        emit_event(context, "informed", empty)
        return empty
    end

    local item = {
        name = cleaned_name,
        packageId = cleaned_name,
        version = version,
        installedVersion = query_field(context, flags, cleaned_name, "installed-version", { 5 }),
        availableVersions = query_field(context, flags, cleaned_name, "available-versions", { 5 }),
        summary = query_field(context, flags, cleaned_name, "synopsis-or-target", { 5 }),
        description = query_field(context, flags, cleaned_name, "description", { 5 }),
        homepage = query_field(context, flags, cleaned_name, "homepage:", { 5 }),
        license = query_field(context, flags, cleaned_name, "license:", { 5 }),
        repository = query_field(context, flags, cleaned_name, "repository", { 5 }),
        packageType = "opam",
    }
    item.installed = item.installedVersion ~= nil and trim(item.installedVersion) ~= ""
    item.status = item.installed and "installed" or "available"

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local pkg, err = normalize_package(package)
    if pkg == nil then
        return nil, err
    end

    local item = plugin.info(context, pkg.name)
    if type(item) == "table" and next(item) ~= nil then
        local resolved = shallow_copy(item)
        if pkg.version ~= "" then
            resolved.version = pkg.version
        end
        return resolved
    end

    return {
        name = pkg.name,
        packageId = pkg.name,
        version = pkg.version ~= "" and pkg.version or nil,
        packageType = "opam",
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "filesystem.write", "network" },
        ecosystemScopes = { "opam", "ocaml" },
        writeScopes = {
            "user-home-subpath:.opam",
            {
                path = join_path(get_plugin_dir(), ".reqpack-data", "opam-root"),
                reason = "ReqPack-managed opam root when data-root flag is used",
            },
        },
        networkScopes = { "*" },
        privilegeLevel = "user",
        purlType = "generic",
    }
end

function plugin.init()
    return command_exists(REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

return plugin
