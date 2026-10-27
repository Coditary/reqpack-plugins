plugin = {}

local PLUGIN_ID = "pinto"
local PLUGIN_NAME = "Pinto"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "pinto"
local FIELD_SEPARATOR = "|^|"

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

local function split_fields(line)
    local fields = {}
    local pattern = "(.-)" .. FIELD_SEPARATOR
    for field in (tostring(line or "") .. FIELD_SEPARATOR):gmatch(pattern) do
        fields[#fields + 1] = field
    end
    return fields
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

local function flag_values(flags, key)
    local values = {}
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            values[#values + 1] = trim(cleaned:sub(#prefix + 1))
        end
    end
    return values
end

local function flag_value(flags, key)
    local values = flag_values(flags, key)
    if #values == 0 then
        return nil
    end
    return values[#values]
end

local function get_plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR)
    if dir ~= "" then
        return dir
    end
    return join_path("p", "pinto")
end

local function default_root()
    return join_path(get_plugin_dir(), ".reqpack-data", "repository")
end

local function pinto_root_from_flags(flags)
    local explicit = trim(flag_value(flags, "root") or "")
    if explicit ~= "" then
        return explicit
    end
    local data_root = trim(flag_value(flags, "data-root") or "")
    if data_root ~= "" then
        return join_path(data_root, "repository")
    end
    local fixture_root = os ~= nil and type(os.getenv) == "function" and trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT")) or ""
    if fixture_root ~= "" then
        return join_path(fixture_root, ".reqpack-data", "repository")
    end
    return default_root()
end

local function selected_stack(flags)
    local stack = trim(flag_value(flags, "stack") or "")
    if stack == "" then
        return "master"
    end
    return stack
end

local function custom_message(flags)
    local value = trim(flag_value(flags, "message") or "")
    if value == "" then
        return nil
    end
    return value
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
        return nil, "missing pinto package name"
    end
    local flags = object_flags(pkg)
    return {
        name = name,
        version = package_version(pkg),
        pin = has_flag(flags, "pin"),
    }
end

local function package_target(pkg)
    if pkg.version ~= "" then
        return pkg.name .. "~" .. pkg.version
    end
    return pkg.name
end

local function local_path_from_context(context, path)
    local direct = trim(path)
    if direct ~= "" then
        return direct
    end
    local request = context ~= nil and context.request or nil
    if request == nil then
        return ""
    end
    return trim(request.localPath or request.path or "")
end

local function path_is_file(context, path)
    return is_command_success(exec_run(context, "test -f " .. shell_quote(path)))
end

local function init_marker_path(root)
    return join_path(root, ".pinto", "config", "pinto.ini")
end

local function repository_initialized(context, root)
    return is_command_success(exec_run(context, "test -f " .. shell_quote(init_marker_path(root))))
end

local function add_mutation_message(args, flags)
    local message = custom_message(flags)
    if message ~= nil then
        args[#args + 1] = "--message"
        args[#args + 1] = message
    else
        args[#args + 1] = "--use-default-message"
    end
end

local function add_common_stack_args(args, flags)
    local stack = selected_stack(flags)
    if stack ~= "" then
        args[#args + 1] = "--stack"
        args[#args + 1] = stack
    end
end

local function pinto_command(root, args, env)
    local parts = {}
    if trim(env or "") ~= "" then
        parts[#parts + 1] = trim(env)
    end
    parts[#parts + 1] = REQUIRED_BINARY
    parts[#parts + 1] = "--root"
    parts[#parts + 1] = shell_quote(root)
    for _, arg in ipairs(args or {}) do
        if trim(arg) ~= "" then
            parts[#parts + 1] = shell_quote(arg)
        end
    end
    return table.concat(parts, " ")
end

local function ensure_repository(context, flags)
    local root = pinto_root_from_flags(flags)
    local stack = selected_stack(flags)
    if repository_initialized(context, root) then
        return root, stack
    end

    local args = { "init", "--stack", stack }
    for _, source in ipairs(flag_values(flags, "source")) do
        if trim(source) ~= "" then
            args[#args + 1] = "--source"
            args[#args + 1] = source
        end
    end
    local result = exec_run(context, pinto_command(root, args))
    if not is_command_success(result) then
        local message = trim(result.stderr) ~= "" and trim(result.stderr) or trim(result.stdout)
        if message == "" then
            message = "pinto init failed"
        end
        return nil, nil, message
    end
    return root, stack
end

local function query_ready(context, flags)
    if not command_exists(REQUIRED_BINARY) then
        return nil, nil, "missing pinto binary"
    end
    local root = pinto_root_from_flags(flags)
    local stack = selected_stack(flags)
    if not repository_initialized(context, root) then
        return root, stack, "pinto repository is not initialized"
    end
    return root, stack
end

local function format_string()
    return table.concat({ "%p", "%v", "%a", "%f", "%y", "%s", "%d", "%D", "%V", "%u", "%S" }, FIELD_SEPARATOR)
end

local function package_item_from_fields(fields, stack, root)
    local name = trim(fields[1] or "")
    if name == "" then
        return nil
    end
    local version = trim(fields[2] or "")
    local author = trim(fields[3] or "")
    local archive = trim(fields[4] or "")
    local pinned = trim(fields[5] or "") == "!"
    local source = trim(fields[6] or "")
    local dist_name = trim(fields[7] or "")
    local dist_name_version = trim(fields[8] or "")
    local dist_version = trim(fields[9] or "")
    local uri = trim(fields[10] or "")
    local source_url = trim(fields[11] or "")

    local item = {
        name = name,
        packageId = name,
        version = version ~= "" and version or nil,
        latestVersion = version ~= "" and version or nil,
        installed = true,
        status = "installed",
        packageType = "perl-module",
        repository = uri ~= "" and uri or nil,
        summary = dist_name ~= "" and (dist_name_version ~= "" and (dist_name .. " from " .. dist_name_version) or dist_name) or nil,
        extraFields = {
            author = author ~= "" and author or nil,
            archive = archive ~= "" and archive or nil,
            pinned = pinned,
            source = source ~= "" and source or nil,
            distribution = dist_name_version ~= "" and dist_name_version or dist_name,
            distributionVersion = dist_version ~= "" and dist_version or nil,
            sourceUrl = source_url ~= "" and source_url or nil,
            stack = stack,
            repositoryRoot = root,
        },
    }
    return item
end

local function parse_list_output(stdout, stack, root)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            local item = package_item_from_fields(split_fields(cleaned), stack, root)
            if item ~= nil then
                items[#items + 1] = item
            end
        end
    end
    table.sort(items, function(left, right)
        local left_name = lower(left.name)
        local right_name = lower(right.name)
        if left_name == right_name then
            return lower(left.version or "") < lower(right.version or "")
        end
        return left_name < right_name
    end)
    return items
end

local function run_list_command(context, root, stack, extra_args)
    local args = { "list", "--stack", stack, "--format", format_string() }
    for _, arg in ipairs(extra_args or {}) do
        args[#args + 1] = arg
    end
    local result = exec_run(context, pinto_command(root, args))
    if not is_command_success(result, { 1 }) then
        return nil, trim(result.stderr) ~= "" and trim(result.stderr) or trim(result.stdout)
    end
    return parse_list_output(result.stdout, stack, root)
end

local function exact_match(items, name)
    local wanted = lower(name)
    for _, item in ipairs(items or {}) do
        if lower(item.name) == wanted then
            return item
        end
    end
    return nil
end

local function parse_outdated_output(stdout, current_items, stack, root)
    local current_by_name = {}
    for _, item in ipairs(current_items or {}) do
        current_by_name[lower(item.name)] = item
    end

    local changes = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            local sign, rest = cleaned:match("^([%+%-])(.*)$")
            if sign ~= nil then
                local parts = split_fields(trim(rest))
                local name = trim(parts[1] or "")
                local version = trim(parts[2] or "")
                local author = trim(parts[3] or "")
                local archive = trim(parts[4] or "")
                if name ~= "" then
                    local key = lower(name)
                    local entry = changes[key] or { name = name }
                    if sign == "+" then
                        entry.newVersion = version
                        entry.author = author
                        entry.archive = archive
                    else
                        entry.oldVersion = version
                    end
                    changes[key] = entry
                end
            end
        end
    end

    local outdated = {}
    for key, change in pairs(changes) do
        local current = current_by_name[key]
        if current ~= nil and trim(change.newVersion or "") ~= "" and trim(change.oldVersion or "") ~= "" and trim(change.newVersion or "") ~= trim(change.oldVersion or "") then
            local item = shallow_copy(current)
            item.status = "outdated"
            item.version = change.oldVersion
            item.latestVersion = change.newVersion
            item.extraFields = shallow_copy(item.extraFields)
            item.extraFields.author = trim(change.author or "") ~= "" and trim(change.author) or item.extraFields.author
            item.extraFields.archive = trim(change.archive or "") ~= "" and trim(change.archive) or item.extraFields.archive
            item.extraFields.stack = stack
            item.extraFields.repositoryRoot = root
            outdated[#outdated + 1] = item
        end
    end

    table.sort(outdated, function(left, right)
        return lower(left.name) < lower(right.name)
    end)
    return outdated
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
    return { "package-manager", "perl", "cpan", "repository" }
end

function plugin.getMissingPackages()
    local missing = {}
    if not command_exists(REQUIRED_BINARY) then
        missing[#missing + 1] = REQUIRED_BINARY
    end
    return missing
end

function plugin.install(context, packages)
    local flags = collect_flags(context, packages)
    if not command_exists(REQUIRED_BINARY) then
        tx_failed(context, "missing pinto binary")
        return false
    end

    local normalized = {}
    for _, pkg in ipairs(packages or {}) do
        local item, err = normalize_package(pkg)
        if item == nil then
            tx_failed(context, err)
            return false
        end
        normalized[#normalized + 1] = item
    end
    if #normalized == 0 then
        tx_failed(context, "no pinto packages requested")
        return false
    end

    local root, stack, init_error = ensure_repository(context, flags)
    if root == nil then
        tx_failed(context, init_error or "pinto repository initialization failed")
        return false
    end

    begin_step(context, "Pull packages into Pinto repository")
    local args = { "pull" }
    add_common_stack_args(args, flags)
    add_mutation_message(args, flags)
    if has_flag(flags, "cascade") then
        args[#args + 1] = "--cascade"
    end
    if has_flag(flags, "pin") then
        args[#args + 1] = "--pin"
    end
    if has_flag(flags, "no-recurse") then
        args[#args + 1] = "--no-recurse"
    end
    for _, pkg in ipairs(normalized) do
        args[#args + 1] = package_target(pkg)
    end

    local result = exec_run(context, pinto_command(root, args))
    if not is_command_success(result) then
        local message = trim(result.stderr) ~= "" and trim(result.stderr) or trim(result.stdout)
        tx_failed(context, message ~= "" and message or "pinto pull failed")
        return false
    end

    local installed = {}
    for _, pkg in ipairs(normalized) do
        installed[#installed + 1] = {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "perl-module",
            status = "installed",
            installed = true,
            extraFields = { stack = stack, repositoryRoot = root },
        }
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local flags = collect_flags(context, {})
    if not command_exists(REQUIRED_BINARY) then
        tx_failed(context, "missing pinto binary")
        return false
    end

    local local_path = local_path_from_context(context, path)
    if local_path == "" then
        tx_failed(context, "missing local distribution path")
        return false
    end
    if not path_is_file(context, local_path) then
        tx_failed(context, "local distribution archive not found: " .. local_path)
        return false
    end

    local root, stack, init_error = ensure_repository(context, flags)
    if root == nil then
        tx_failed(context, init_error or "pinto repository initialization failed")
        return false
    end

    begin_step(context, "Add local distribution to Pinto repository")
    local args = { "add" }
    add_common_stack_args(args, flags)
    add_mutation_message(args, flags)
    if has_flag(flags, "pin") then
        args[#args + 1] = "--pin"
    end
    local author = trim(flag_value(flags, "author") or "")
    if author ~= "" then
        args[#args + 1] = "--author"
        args[#args + 1] = author
    end
    args[#args + 1] = local_path

    local result = exec_run(context, pinto_command(root, args))
    if not is_command_success(result) then
        local message = trim(result.stderr) ~= "" and trim(result.stderr) or trim(result.stdout)
        tx_failed(context, message ~= "" and message or "pinto add failed")
        return false
    end

    emit_event(context, "installed", {
        localTarget = true,
        path = local_path,
        stack = stack,
        repositoryRoot = root,
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local flags = collect_flags(context, packages)
    if not command_exists(REQUIRED_BINARY) then
        tx_failed(context, "missing pinto binary")
        return false
    end

    local normalized = {}
    for _, pkg in ipairs(packages or {}) do
        local item, err = normalize_package(pkg)
        if item == nil then
            tx_failed(context, err)
            return false
        end
        normalized[#normalized + 1] = item
    end
    if #normalized == 0 then
        tx_failed(context, "no pinto packages requested")
        return false
    end

    local root, stack, query_error = query_ready(context, flags)
    if query_error ~= nil then
        tx_failed(context, query_error)
        return false
    end

    begin_step(context, "Unregister packages from Pinto stack")
    local args = { "unregister" }
    add_common_stack_args(args, flags)
    add_mutation_message(args, flags)
    if has_flag(flags, "force") then
        args[#args + 1] = "--force"
    end
    for _, pkg in ipairs(normalized) do
        args[#args + 1] = package_target(pkg)
    end

    local result = exec_run(context, pinto_command(root, args))
    if not is_command_success(result) then
        local message = trim(result.stderr) ~= "" and trim(result.stderr) or trim(result.stdout)
        tx_failed(context, message ~= "" and message or "pinto unregister failed")
        return false
    end

    local removed = {}
    for _, pkg in ipairs(normalized) do
        removed[#removed + 1] = {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "perl-module",
            status = "removed",
            installed = false,
            extraFields = { stack = stack, repositoryRoot = root },
        }
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local flags = collect_flags(context, packages)
    if not command_exists(REQUIRED_BINARY) then
        tx_failed(context, "missing pinto binary")
        return false
    end

    local normalized = {}
    for _, pkg in ipairs(packages or {}) do
        local item, err = normalize_package(pkg)
        if item == nil then
            tx_failed(context, err)
            return false
        end
        normalized[#normalized + 1] = item
    end

    local root, stack, query_error = query_ready(context, flags)
    if query_error ~= nil then
        tx_failed(context, query_error)
        return false
    end

    begin_step(context, "Update Pinto stack packages")
    local args = { "update" }
    add_common_stack_args(args, flags)
    add_mutation_message(args, flags)
    if has_flag(flags, "cascade") then
        args[#args + 1] = "--cascade"
    end
    if has_flag(flags, "pin") then
        args[#args + 1] = "--pin"
    end
    if has_flag(flags, "force") then
        args[#args + 1] = "--force"
    end
    if has_flag(flags, "no-recurse") then
        args[#args + 1] = "--no-recurse"
    end
    if has_flag(flags, "roots") or #normalized == 0 then
        args[#args + 1] = "--roots"
    else
        for _, pkg in ipairs(normalized) do
            args[#args + 1] = pkg.name
        end
    end

    local result = exec_run(context, pinto_command(root, args))
    if not is_command_success(result) then
        local message = trim(result.stderr) ~= "" and trim(result.stderr) or trim(result.stdout)
        tx_failed(context, message ~= "" and message or "pinto update failed")
        return false
    end

    local updated = {}
    if #normalized == 0 then
        updated[#updated + 1] = {
            name = "roots",
            packageId = "roots",
            packageType = "perl-module",
            status = "updated",
            extraFields = { stack = stack, repositoryRoot = root },
        }
    else
        for _, pkg in ipairs(normalized) do
            updated[#updated + 1] = {
                name = pkg.name,
                packageId = pkg.name,
                packageType = "perl-module",
                status = "updated",
                extraFields = { stack = stack, repositoryRoot = root },
            }
        end
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local flags = collect_flags(context, {})
    local root, stack, query_error = query_ready(context, flags)
    if query_error ~= nil then
        log_warn(context, query_error)
        emit_event(context, "listed", {})
        return {}
    end
    local items, err = run_list_command(context, root, stack)
    if items == nil then
        log_warn(context, err or "pinto list failed")
        emit_event(context, "listed", {})
        return {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local flags = collect_flags(context, {})
    local root, stack, query_error = query_ready(context, flags)
    if query_error ~= nil then
        log_warn(context, query_error)
        emit_event(context, "outdated", {})
        return {}
    end

    local current_items, list_error = run_list_command(context, root, stack)
    if current_items == nil then
        log_warn(context, list_error or "pinto list failed")
        emit_event(context, "outdated", {})
        return {}
    end

    local args = { "update", "--stack", stack, "--roots", "--dry-run", "--use-default-message" }
    local result = exec_run(context, pinto_command(root, args, "PINTO_DIFF_STYLE=detailed"))
    if not is_command_success(result, { 1 }) then
        log_warn(context, trim(result.stderr) ~= "" and trim(result.stderr) or trim(result.stdout) or "pinto update --dry-run failed")
        emit_event(context, "outdated", {})
        return {}
    end

    local items = parse_outdated_output(result.stdout, current_items, stack, root)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local flags = collect_flags(context, {})
    local cleaned_prompt = trim(prompt or read_field(context, "prompt") or "")
    if cleaned_prompt == "" then
        emit_event(context, "searched", {})
        return {}
    end

    local root, _, query_error = query_ready(context, flags)
    if query_error ~= nil then
        log_warn(context, query_error)
        emit_event(context, "searched", {})
        return {}
    end

    local args = { "list", "--all", "--packages", cleaned_prompt, "--format", format_string() }
    local result = exec_run(context, pinto_command(root, args))
    if not is_command_success(result, { 1 }) then
        log_warn(context, trim(result.stderr) ~= "" and trim(result.stderr) or trim(result.stdout) or "pinto search failed")
        emit_event(context, "searched", {})
        return {}
    end

    local items = parse_list_output(result.stdout, "all", root)
    for _, item in ipairs(items) do
        item.installed = false
        item.status = "available"
        item.extraFields.stack = "all"
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local flags = collect_flags(context, {})
    local cleaned_name = trim(name or read_field(context, "prompt") or "")
    if cleaned_name == "" then
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    local root, stack, query_error = query_ready(context, flags)
    if query_error ~= nil then
        log_warn(context, query_error)
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    local all_result = exec_run(context, pinto_command(root, { "list", "--all", "--packages", cleaned_name, "--format", format_string() }))
    local all_items = {}
    if is_command_success(all_result, { 1 }) then
        all_items = parse_list_output(all_result.stdout, "all", root)
    end
    local item = exact_match(all_items, cleaned_name)
    if item ~= nil then
        item.installed = false
        item.status = "available"
        item.extraFields.stack = "all"
        local stack_items, _ = run_list_command(context, root, stack, { "--packages", cleaned_name })
        if exact_match(stack_items or {}, cleaned_name) ~= nil then
            item.installed = true
            item.status = "installed"
            item.extraFields.stack = stack
        end
        emit_event(context, "informed", item)
        return item
    end

    local stack_items, _ = run_list_command(context, root, stack, { "--packages", cleaned_name })
    item = exact_match(stack_items or {}, cleaned_name)
    if item ~= nil then
        emit_event(context, "informed", item)
        return item
    end

    local empty = {}
    emit_event(context, "unavailable", { name = cleaned_name, reason = "not-found" })
    emit_event(context, "informed", empty)
    return empty
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
        packageType = "perl-module",
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "filesystem.write", "network" },
        ecosystemScopes = { "cpan", "perl", "pinto" },
        writeScopes = {
            "plugin-data:p/pinto/.reqpack-data/repository",
            {
                path = default_root(),
                reason = "ReqPack-managed Pinto repository root",
            },
        },
        networkScopes = { "*" },
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
