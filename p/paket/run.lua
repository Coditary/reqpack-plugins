plugin = {}

local PLUGIN_ID = "paket"
local PLUGIN_NAME = "Paket"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "dotnet"
local DEFAULT_SOURCE = "https://api.nuget.org/v3/index.json"
local DEFAULT_CACHE_LINE = "cache ./local-cache versions: current"
local LOCAL_FEED_SOURCE = "source ./local-feed"
local ENV_LOCALE = "LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en"
local SEARCH_LIMIT = 20

plugin.fileExtensions = { ".nupkg" }

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function cmd_quote(value)
    return '"' .. tostring(value or ""):gsub('"', '""') .. '"'
end

local function split_lines(value)
    local text = tostring(value or ""):gsub("\r\n", "\n")
    local lines = {}
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line:gsub("\r$", "")
    end
    return lines
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

local function append_unique(list, value, seen)
    local cleaned = trim(value)
    if cleaned == "" then
        return
    end
    if seen[cleaned] then
        return
    end
    seen[cleaned] = true
    list[#list + 1] = cleaned
end

local function is_windows_host()
    local plugin_dir = tostring(_G.REQPACK_PLUGIN_DIR or "")
    if plugin_dir:find("\\", 1, true) ~= nil then
        return true
    end

    local host = reqpack and reqpack.host or nil
    local platform = host and host.platform or nil
    local os_info = host and host.os or nil
    local os_family = lower(trim(platform and platform.osFamily or ""))
    local os_id = lower(trim(os_info and os_info.id or ""))

    return os_family == "windows" or os_id == "windows"
end

local function command_quote(value)
    if is_windows_host() then
        return cmd_quote(value)
    end
    return shell_quote(value)
end

local function path_separator()
    if is_windows_host() then
        return "\\"
    end
    return "/"
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

    return table.concat(parts, path_separator())
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

local function run_command(context, command)
    local first, second, third, fourth, fifth

    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        first, second, third, fourth, fifth = context.exec.run(command)
    elseif reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
        first, second, third, fourth, fifth = reqpack.exec.run(command)
    else
        return {
            success = false,
            stdout = "",
            stderr = "reqpack.exec.run unavailable",
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

local function command_exists(binary)
    local command
    if is_windows_host() then
        command = "where " .. cmd_quote(binary) .. " >nul 2>nul"
    else
        command = "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"
    end
    return is_command_success(run_command(nil, command))
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

    local command
    if is_windows_host() then
        command = "if exist " .. cmd_quote(target) .. " (exit /b 0) else (exit /b 1)"
    else
        command = "test -e " .. shell_quote(target)
    end
    return is_command_success(run_command(nil, command))
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

local function write_file(path, content)
    local handle = io.open(path, "wb")
    if handle == nil then
        return false
    end
    handle:write(content or "")
    handle:close()
    return true
end

local function ensure_directory(context, path)
    local command
    if is_windows_host() then
        command = "if not exist " .. cmd_quote(path) .. " mkdir " .. cmd_quote(path)
    else
        command = "mkdir -p " .. shell_quote(path)
    end
    return is_command_success(run_command(context, command))
end

local function ensure_directories(context, paths)
    local cleaned = {}
    local seen = {}
    for _, path in ipairs(paths or {}) do
        local value = trim(path)
        if value ~= "" and not seen[value] then
            seen[value] = true
            cleaned[#cleaned + 1] = value
        end
    end

    if #cleaned == 0 then
        return true
    end

    if is_windows_host() then
        for _, path in ipairs(cleaned) do
            if not ensure_directory(context, path) then
                return false
            end
        end
        return true
    end

    local quoted = {}
    for _, path in ipairs(cleaned) do
        quoted[#quoted + 1] = shell_quote(path)
    end
    return is_command_success(run_command(context, "mkdir -p " .. table.concat(quoted, " ")))
end

local function copy_file(source, target)
    local input = io.open(source, "rb")
    if input == nil then
        return false
    end
    local output = io.open(target, "wb")
    if output == nil then
        input:close()
        return false
    end
    local data = input:read("*a")
    output:write(data or "")
    input:close()
    output:close()
    return true
end

local function get_plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR or "")
    if dir ~= "" then
        return dir
    end
    return "."
end

local function read_flags(value)
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

local function collect_flags(context, package)
    local flags = {}
    local seen = {}

    local function collect_from(object)
        for _, flag in ipairs(read_flags(read_field(object, "flags"))) do
            append_unique(flags, flag, seen)
        end
    end

    collect_from(context)
    collect_from(context ~= nil and context.request or nil)
    collect_from(package)
    return flags
end

local function flag_present(flags, name)
    local wanted = lower(trim(name))
    for _, flag in ipairs(flags or {}) do
        if lower(trim(flag)) == wanted then
            return true
        end
    end
    return false
end

local function flag_value(flags, prefix)
    local wanted = lower(trim(prefix))
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #wanted) == wanted then
            return trim(cleaned:sub(#wanted + 1))
        end
    end
    return nil
end

local function flag_values(flags, prefix)
    local values = {}
    local wanted = lower(trim(prefix))
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #wanted) == wanted then
            values[#values + 1] = trim(cleaned:sub(#wanted + 1))
        end
    end
    return values
end

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = trim(select(index, ...))
        if value ~= "" then
            return value
        end
    end
    return ""
end

local function package_name(package)
    return first_nonempty(
        read_field(package, "name"),
        read_field(package, "packageId"),
        read_field(package, "id")
    )
end

local function package_version(package)
    return first_nonempty(read_field(package, "version"), read_field(package, "constraint"))
end

local function package_group(package)
    return first_nonempty(read_field(package, "group"), flag_value(read_flags(read_field(package, "flags")), "group="))
end

local function package_project(package)
    return first_nonempty(read_field(package, "project"), flag_value(read_flags(read_field(package, "flags")), "project="))
end

local function package_type(package)
    return first_nonempty(read_field(package, "type"), flag_value(read_flags(read_field(package, "flags")), "type="))
end

local function basename(path)
    local normalized = tostring(path or ""):gsub("\\", "/")
    return normalized:match("([^/]+)$") or normalized
end

local function is_template_path(path)
    return tostring(path or ""):find("${", 1, true) ~= nil
end

local function context_flags(context)
    return collect_flags(context, nil)
end

local function get_data_root(context)
    local override = flag_value(context_flags(context), "cache-root=")
    if override ~= nil and trim(override) ~= "" then
        return trim(override)
    end
    return join_path(get_plugin_dir(), ".reqpack-data")
end

local function get_workspace_root(context)
    return join_path(get_data_root(context), "workspace")
end

local function get_local_feed_root(context)
    return join_path(get_workspace_root(context), "local-feed")
end

local function get_local_cache_root(context)
    return join_path(get_workspace_root(context), "local-cache")
end

local function get_machine_cache_root(context)
    return join_path(get_workspace_root(context), "machine-cache")
end

local function get_dotnet_home_root(context)
    return join_path(get_workspace_root(context), "dotnet-home")
end

local function get_dependencies_path(context)
    return join_path(get_workspace_root(context), "paket.dependencies")
end

local function collect_cache_metadata(context)
    return {
        reqpackRoot = get_data_root(context),
        workspaceRoot = get_workspace_root(context),
        localFeed = get_local_feed_root(context),
        localArchiveCache = get_local_cache_root(context),
        machineCache = get_machine_cache_root(context),
    }
end

local function ensure_source_line(content, line)
    if content:find(line, 1, true) ~= nil then
        return content
    end

    local cleaned = content
    if cleaned ~= "" and not cleaned:match("\n$") then
        cleaned = cleaned .. "\n"
    end
    return cleaned .. line .. "\n"
end

local function ensure_workspace_file(context, require_local_feed)
    local path = get_dependencies_path(context)
    if is_template_path(path) then
        return true
    end
    local content = read_file(path)

    if content == nil then
        content = "source " .. DEFAULT_SOURCE .. "\n" .. DEFAULT_CACHE_LINE .. "\n"
        if require_local_feed then
            content = content .. LOCAL_FEED_SOURCE .. "\n"
        end
        return write_file(path, content)
    end

    local updated = content
    updated = ensure_source_line(updated, "source " .. DEFAULT_SOURCE)
    if updated:find(DEFAULT_CACHE_LINE, 1, true) == nil then
        updated = ensure_source_line(updated, DEFAULT_CACHE_LINE)
    end
    if require_local_feed then
        updated = ensure_source_line(updated, LOCAL_FEED_SOURCE)
    end

    if updated ~= content then
        return write_file(path, updated)
    end
    return true
end

local function ensure_workspace(context, require_local_feed)
    local ok = ensure_directories(context, {
        get_workspace_root(context),
        get_local_feed_root(context),
        get_local_cache_root(context),
        get_machine_cache_root(context),
        get_dotnet_home_root(context),
    })
    if not ok then
        return false
    end

    return ensure_workspace_file(context, require_local_feed == true)
end

local function build_command(parts)
    local quoted = {}
    for _, part in ipairs(parts or {}) do
        local text = trim(part)
        if text ~= "" then
            quoted[#quoted + 1] = command_quote(text)
        end
    end
    return table.concat(quoted, " ")
end

local function paket_env_prefix(context)
    local parts = {
        ENV_LOCALE,
        "DOTNET_CLI_HOME=" .. command_quote(get_dotnet_home_root(context)),
        "NuGetCachePath=" .. command_quote(get_machine_cache_root(context)),
    }
    return table.concat(parts, " ")
end

local function build_paket_command(context, args)
    local workspace = get_workspace_root(context)
    local parts = { REQUIRED_BINARY, "paket" }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = arg
    end
    local command = build_command(parts)

    if is_windows_host() then
        return "cd /d " .. cmd_quote(workspace) .. " && " .. paket_env_prefix(context) .. " " .. command
    end

    return "cd " .. shell_quote(workspace) .. " && " .. paket_env_prefix(context) .. " " .. command
end

local function run_paket(context, args)
    local result = run_command(context, build_paket_command(context, args))
    return result
end

local function ensure_paket_tool(context)
    if type(context) == "table" and context.__paketToolReady == true then
        return true
    end

    if not ensure_workspace(context, false) then
        return false, "failed to prepare paket workspace"
    end

    local result = run_paket(context, { "--help" })
    if is_command_success(result) then
        if type(context) == "table" then
            context.__paketToolReady = true
        end
        return true
    end

    local message = trim(result.stderr)
    if message == "" then
        message = trim(result.stdout)
    end
    if message == "" then
        message = "dotnet paket tool unavailable"
    end
    return false, message
end

local function append_option(args, flag, value)
    local cleaned = trim(value)
    if cleaned == "" then
        return
    end
    args[#args + 1] = flag
    args[#args + 1] = cleaned
end

local function add_common_mutation_flags(args, flags)
    if flag_present(flags, "force") then
        args[#args + 1] = "--force"
    end
    if flag_present(flags, "redirects") then
        args[#args + 1] = "--redirects"
    end
    if flag_present(flags, "clean-redirects") then
        args[#args + 1] = "--clean-redirects"
    end
    if flag_present(flags, "create-new-binding-files") then
        args[#args + 1] = "--create-new-binding-files"
    end
    if flag_present(flags, "keep-major") then
        args[#args + 1] = "--keep-major"
    end
    if flag_present(flags, "keep-minor") then
        args[#args + 1] = "--keep-minor"
    end
    if flag_present(flags, "keep-patch") then
        args[#args + 1] = "--keep-patch"
    end
    if flag_present(flags, "touch-affected-refs") then
        args[#args + 1] = "--touch-affected-refs"
    end
end

local function add_install_only_flags(args, flags)
    if flag_present(flags, "only-referenced") then
        args[#args + 1] = "--only-referenced"
    end
    if flag_present(flags, "generate-load-scripts") then
        args[#args + 1] = "--generate-load-scripts"
    end
    for _, framework in ipairs(flag_values(flags, "load-script-framework=")) do
        append_option(args, "--load-script-framework", framework)
    end
    for _, script_type in ipairs(flag_values(flags, "load-script-type=")) do
        append_option(args, "--load-script-type", script_type)
    end
end

local function build_add_args(context, package)
    local flags = collect_flags(context, package)
    local args = { "add", package_name(package) }

    append_option(args, "--version", package_version(package))
    append_option(args, "--project", first_nonempty(package_project(package), flag_value(flags, "project=")))
    append_option(args, "--group", first_nonempty(package_group(package), flag_value(flags, "group=")))
    append_option(args, "--type", first_nonempty(package_type(package), flag_value(flags, "type=")))
    add_common_mutation_flags(args, flags)
    args[#args + 1] = "--no-install"
    args[#args + 1] = "--silent"
    return args
end

local function build_remove_args(context, package)
    local flags = collect_flags(context, package)
    local args = { "remove", package_name(package) }

    append_option(args, "--project", first_nonempty(package_project(package), flag_value(flags, "project=")))
    append_option(args, "--group", first_nonempty(package_group(package), flag_value(flags, "group=")))
    if flag_present(flags, "force") then
        args[#args + 1] = "--force"
    end
    args[#args + 1] = "--no-install"
    args[#args + 1] = "--silent"
    return args
end

local function build_install_args(context, package)
    local flags = collect_flags(context, package)
    local args = { "install" }
    add_common_mutation_flags(args, flags)
    add_install_only_flags(args, flags)
    args[#args + 1] = "--silent"
    return args
end

local function build_update_args(context, package)
    local flags = collect_flags(context, package)
    local args = { "update" }
    local name = package_name(package)
    if name ~= "" then
        args[#args + 1] = name
    end

    append_option(args, "--version", package_version(package))
    append_option(args, "--group", first_nonempty(package_group(package), flag_value(flags, "group=")))
    add_common_mutation_flags(args, flags)
    if flag_present(flags, "filter") then
        args[#args + 1] = "--filter"
    end
    if flag_present(flags, "no-install") then
        args[#args + 1] = "--no-install"
    end
    args[#args + 1] = "--silent"
    return args
end

local function local_path_from_context(context)
    return first_nonempty(
        read_field(context, "path"),
        read_field(context, "localPath"),
        read_field(context ~= nil and context.request or nil, "path"),
        read_field(context ~= nil and context.request or nil, "localPath")
    )
end

local function parse_local_package_filename(path)
    local name = basename(path)
    local stem = name:gsub("%.nupkg$", "")
    local package_id, version = stem:match("^(.-)%.([0-9][0-9A-Za-z%+%-%.]*)$")
    if package_id ~= nil and version ~= nil then
        local split_name, split_version = stem:match("^(.*)%.([0-9]+%.[0-9]+%.[0-9]+[0-9A-Za-z%+%-%.]*)$")
        if split_name ~= nil and split_version ~= nil then
            package_id = split_name
            version = split_version
        end
    end
    package_id = trim(package_id)
    version = trim(version)
    if package_id == "" or version == "" then
        return nil
    end
    return {
        name = package_id,
        version = version,
    }
end

local function stage_local_package(context, path)
    local source = trim(path)
    if source == "" or lower(source:sub(-6)) ~= ".nupkg" then
        return nil, "paket local install only supports .nupkg files"
    end
    if not is_template_path(source) and not path_exists(source) then
        return nil, "local package file not found: " .. source
    end
    if not ensure_workspace(context, true) then
        return nil, "failed to prepare paket workspace"
    end

    local package = parse_local_package_filename(source)
    if package == nil then
        return nil, "unable to infer package id and version from local .nupkg filename"
    end

    local target = join_path(get_local_feed_root(context), basename(source))
    if not is_template_path(source) and not copy_file(source, target) then
        return nil, "failed to stage local package into paket feed"
    end

    return {
        name = package.name,
        version = package.version,
        stagedPath = target,
    }
end

local function parse_installed_items(context, output)
    local items = {}
    local cache = collect_cache_metadata(context)

    for _, line in ipairs(split_lines(output)) do
        local cleaned = trim(line)
        local group, name, version = cleaned:match("^(%S+)%s+(%S+)%s+%-%s+(.+)$")
        if group ~= nil and name ~= nil and version ~= nil then
            items[#items + 1] = {
                name = name,
                packageId = name,
                version = trim(version),
                installed = true,
                status = "installed",
                group = group,
                source = DEFAULT_SOURCE,
                repository = "nuget.org via Paket",
                cache = shallow_copy(cache),
                extraFields = {
                    workspaceRoot = cache.workspaceRoot,
                },
            }
        end
    end

    return items
end

local function list_items(context)
    local ok, message = ensure_paket_tool(context)
    if not ok then
        log_warn(context, message)
        return {}
    end

    local result = run_paket(context, { "show-installed-packages", "--all", "--silent" })
    if not is_command_success(result) then
        log_warn(context, trim(result.stderr) ~= "" and trim(result.stderr) or "paket show-installed-packages failed")
        return {}
    end

    return parse_installed_items(context, result.stdout)
end

local function installed_map(context)
    local map = {}
    for _, item in ipairs(list_items(context)) do
        local name = lower(trim(item.name))
        map[name] = map[name] or {}
        map[name][#map[name] + 1] = item
    end
    return map
end

local function parse_outdated_items(context, output)
    local items = {}
    local cache = collect_cache_metadata(context)
    local current_group = "Main"

    for _, line in ipairs(split_lines(output)) do
        local cleaned = trim(line)
        local group = cleaned:match("^Group:%s*(.+)$")
        if group ~= nil and trim(group) ~= "" then
            current_group = trim(group)
        else
            local name, current_version, latest_version = cleaned:match("^%*%s*(%S+)%s+([^%s]+)%s+%-%>%s+([^%s]+)$")
            if name ~= nil then
                items[#items + 1] = {
                    name = name,
                    packageId = name,
                    version = current_version,
                    latestVersion = latest_version,
                    installed = true,
                    status = "outdated",
                    group = current_group,
                    source = DEFAULT_SOURCE,
                    repository = "nuget.org via Paket",
                    cache = shallow_copy(cache),
                }
            end
        end
    end

    return items
end

local function outdated_items(context)
    local ok, message = ensure_paket_tool(context)
    if not ok then
        log_warn(context, message)
        return {}
    end

    local flags = context_flags(context)
    local args = { "outdated" }
    append_option(args, "--group", flag_value(flags, "group="))
    if flag_present(flags, "force") then
        args[#args + 1] = "--force"
    end
    if flag_present(flags, "ignore-constraints") then
        args[#args + 1] = "--ignore-constraints"
    end
    if flag_present(flags, "include-prereleases") or flag_present(flags, "prerelease") or flag_present(flags, "pre") then
        args[#args + 1] = "--include-prereleases"
    end
    args[#args + 1] = "--silent"

    local result = run_paket(context, args)
    if not is_command_success(result) then
        log_warn(context, trim(result.stderr) ~= "" and trim(result.stderr) or "paket outdated failed")
        return {}
    end

    return parse_outdated_items(context, result.stdout)
end

local function query_remote_versions(context, name)
    local package_id = trim(name)
    if package_id == "" then
        return {}
    end

    local ok, message = ensure_paket_tool(context)
    if not ok then
        log_warn(context, message)
        return {}
    end

    local flags = context_flags(context)
    local args = { "find-package-versions", package_id }
    append_option(args, "--source", flag_value(flags, "source="))
    append_option(args, "--max", first_nonempty(flag_value(flags, "max="), tostring(SEARCH_LIMIT)))
    args[#args + 1] = "--silent"

    local result = run_paket(context, args)
    if not is_command_success(result) then
        return {}
    end

    local versions = {}
    local seen = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        append_unique(versions, trim(line), seen)
    end
    return versions
end

local function info_item(context, name)
    local package_id = trim(name)
    if package_id == "" then
        return {}
    end

    local installed = installed_map(context)[lower(package_id)] or {}
    local outdated = {}
    for _, item in ipairs(outdated_items(context)) do
        if lower(trim(item.name)) == lower(package_id) then
            outdated[#outdated + 1] = item
        end
    end
    local remote_versions = query_remote_versions(context, package_id)
    local cache = collect_cache_metadata(context)
    local result = {
        name = package_id,
        packageId = package_id,
        source = DEFAULT_SOURCE,
        repository = "nuget.org via Paket",
        remoteVersions = remote_versions,
        cache = cache,
    }

    if #installed > 0 then
        result.installed = true
        result.version = installed[1].version
        result.group = installed[1].group
        result.status = "installed"
        local versions = {}
        local seen = {}
        for _, item in ipairs(installed) do
            append_unique(versions, item.version, seen)
        end
        result.installedVersions = versions
    else
        result.installed = false
        result.status = "available"
    end

    if #remote_versions > 0 then
        result.latestVersion = remote_versions[1]
        if result.version == nil then
            result.version = remote_versions[1]
        end
    end

    if #outdated > 0 then
        result.status = "outdated"
        result.latestVersion = outdated[1].latestVersion
        result.version = outdated[1].version
    end

    return result
end

local function search_items(context, prompt)
    local query = trim(prompt)
    if query == "" then
        return {}
    end

    local ok, message = ensure_paket_tool(context)
    if not ok then
        log_warn(context, message)
        return {}
    end

    local flags = context_flags(context)
    local max_value = first_nonempty(flag_value(flags, "max="), tostring(SEARCH_LIMIT))
    local args = { "find-packages", query }
    append_option(args, "--source", flag_value(flags, "source="))
    append_option(args, "--max", max_value)
    args[#args + 1] = "--silent"

    local result = run_paket(context, args)
    if not is_command_success(result) then
        log_warn(context, trim(result.stderr) ~= "" and trim(result.stderr) or "paket find-packages failed")
        return {}
    end

    local installed = installed_map(context)
    local items = {}
    local seen = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local name = trim(line)
        if name ~= "" and name:find("%s") == nil and not seen[lower(name)] then
            seen[lower(name)] = true
            local item = info_item(context, name)
            if installed[lower(name)] ~= nil then
                item.installed = true
                item.version = installed[lower(name)][1].version
                if item.status ~= "outdated" then
                    item.status = "installed"
                end
            end
            items[#items + 1] = item
        end
    end

    return items
end

local function info_matches_request(package, item)
    if item == nil or next(item) == nil then
        return false
    end

    local wanted_version = package_version(package)
    if wanted_version == "" then
        return true
    end

    if trim(item.version) == wanted_version then
        return true
    end

    for _, version in ipairs(item.remoteVersions or {}) do
        if trim(version) == wanted_version then
            return true
        end
    end

    return false
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
    return { "Cross Platform", "Dotnet", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    local missing = {}
    local installed = installed_map(nil)

    for _, pkg in ipairs(packages or {}) do
        local name = lower(package_name(pkg))
        local version = package_version(pkg)
        local action = lower(trim(read_field(pkg, "action")))
        local present = installed[name] or {}
        local matched = false

        for _, item in ipairs(present) do
            if version == "" or trim(item.version) == version then
                matched = true
                break
            end
        end

        if name ~= "" then
            if action == "update" then
                missing[#missing + 1] = pkg
            elseif action == "remove" then
                if matched or (#present > 0 and version == "") then
                    missing[#missing + 1] = pkg
                end
            elseif not matched then
                missing[#missing + 1] = pkg
            end
        end
    end

    return missing
end

function plugin.install(context, packages)
    local local_path = local_path_from_context(context)
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end

    if packages == nil or #packages == 0 then
        return true
    end

    local ok, message = ensure_paket_tool(context)
    if not ok then
        tx_failed(context, message)
        return false
    end

    begin_step(context, "install paket packages")

    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        if name == "" then
            tx_failed(context, "paket install failed")
            return false
        end
        local result = run_paket(context, build_add_args(context, pkg))
        if not is_command_success(result) then
            tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "paket install failed")
            return false
        end
    end

    local install_result = run_paket(context, build_install_args(context, packages[1]))
    if not is_command_success(install_result) then
        tx_failed(context, trim(install_result.stderr) ~= "" and trim(install_result.stderr) or "paket install failed")
        return false
    end

    emit_event(context, "installed", packages)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    begin_step(context, "install local paket package")

    local ok, message = ensure_paket_tool(context)
    if not ok then
        tx_failed(context, message)
        return false
    end

    local package_item, stage_error = stage_local_package(context, path)
    if package_item == nil then
        tx_failed(context, stage_error or "paket local install failed")
        return false
    end

    local result = run_paket(context, build_add_args(context, package_item))
    if not is_command_success(result) then
        tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "paket local install failed")
        return false
    end

    local install_result = run_paket(context, build_install_args(context, package_item))
    if not is_command_success(install_result) then
        tx_failed(context, trim(install_result.stderr) ~= "" and trim(install_result.stderr) or "paket local install failed")
        return false
    end

    emit_event(context, "installed", {
        path = trim(path),
        name = package_item.name,
        version = package_item.version,
        localTarget = true,
        stagedPath = package_item.stagedPath,
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    if packages == nil or #packages == 0 then
        return true
    end

    local ok, message = ensure_paket_tool(context)
    if not ok then
        tx_failed(context, message)
        return false
    end

    begin_step(context, "remove paket packages")

    for _, pkg in ipairs(packages or {}) do
        local result = run_paket(context, build_remove_args(context, pkg))
        if not is_command_success(result) then
            tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "paket remove failed")
            return false
        end
    end

    local install_result = run_paket(context, build_install_args(context, packages[1]))
    if not is_command_success(install_result) then
        tx_failed(context, trim(install_result.stderr) ~= "" and trim(install_result.stderr) or "paket remove failed")
        return false
    end

    emit_event(context, "deleted", packages)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local ok, message = ensure_paket_tool(context)
    if not ok then
        tx_failed(context, message)
        return false
    end

    begin_step(context, "update paket packages")

    if packages == nil or #packages == 0 then
        local result = run_paket(context, build_update_args(context, nil))
        if not is_command_success(result) then
            tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "paket update failed")
            return false
        end
        emit_event(context, "updated", {})
        tx_success(context)
        return true
    end

    for _, pkg in ipairs(packages or {}) do
        local result = run_paket(context, build_update_args(context, pkg))
        if not is_command_success(result) then
            tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "paket update failed")
            return false
        end
    end

    emit_event(context, "updated", packages)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = list_items(context)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items = outdated_items(context)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local items = search_items(context, prompt)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local item = info_item(context, name)
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local item = info_item(context, package_name(package))
    if not info_matches_request(package, item) then
        return nil
    end

    return {
        name = item.name,
        packageId = item.packageId,
        version = item.version,
        latestVersion = item.latestVersion,
        installed = item.installed,
        status = item.status,
        source = item.source,
        cache = item.cache,
        remoteVersions = item.remoteVersions,
        installedVersions = item.installedVersions,
        group = item.group,
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "filesystem.write", "filesystem.read" },
        ecosystemScopes = { "nuget", "dotnet", "fsharp" },
        writeScopes = {
            {
                path = join_path(get_plugin_dir(), ".reqpack-data"),
                reason = "ReqPack-managed Paket shared workspace, staged local feed, and cache metadata",
            },
        },
        networkScopes = {
            {
                scheme = "https",
                host = "*",
                reason = "Paket resolves packages from configured remote NuGet feeds",
            },
        },
        privilegeLevel = "none",
        osvEcosystem = "NuGet",
        purlType = "nuget",
    }
end

function plugin.init()
    return command_exists(REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

return plugin
