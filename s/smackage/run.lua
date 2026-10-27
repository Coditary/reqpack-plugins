plugin = {}

local PLUGIN_ID = "smackage"
local PLUGIN_NAME = "smackage"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "smackage"

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

local function split_lines(value)
    local lines = {}
    local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
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

local function collect_flags(context, package)
    local flags = {}
    local seen = {}
    local function collect_from(value)
        for _, flag in ipairs(object_flags(value)) do
            if not seen[flag] then
                seen[flag] = true
                flags[#flags + 1] = flag
            end
        end
    end
    collect_from(context)
    collect_from(read_field(context, "request"))
    collect_from(package)
    return flags
end

local function flag_value(flags, key)
    local prefix = lower(key) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            return trim(cleaned:sub(#prefix + 1))
        end
    end
    return nil
end

local function normalize_exec_result(first, second, third, fourth, fifth)
    local result = {}
    local function apply(value)
        local value_type = type(value)
        if value_type == "table" then
            for key, item in pairs(value or {}) do
                if result[key] == nil then
                    result[key] = item
                end
            end
        elseif value_type == "userdata" then
            for _, key in ipairs({ "success", "ok", "stdout", "stderr", "exitCode", "exit_code", "code", "status", "stdoutText", "stderrText" }) do
                local ok, item = pcall(function()
                    return value[key]
                end)
                if ok and item ~= nil and result[key] == nil then
                    result[key] = item
                end
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
    apply(first)
    apply(second)
    apply(third)
    apply(fourth)
    apply(fifth)
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
    else
        first, second, third, fourth, fifth = reqpack.exec.run(command)
    end
    return normalize_exec_result(first, second, third, fourth, fifth)
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

local function read_proc_environ_value(name)
    if os ~= nil and type(os.getenv) == "function" then
        local value = os.getenv(tostring(name or ""))
        if value ~= nil and value ~= "" then
            return trim(value)
        end
    end

    local handle = io.open("/proc/self/environ", "rb")
    if handle == nil then
        return nil
    end
    local payload = handle:read("*a")
    handle:close()
    if payload == nil or payload == "" then
        return nil
    end

    local prefix = tostring(name or "") .. "="
    for entry in tostring(payload):gmatch("[^%z]+") do
        if entry:sub(1, #prefix) == prefix then
            return trim(entry:sub(#prefix + 1))
        end
    end
    return nil
end

local function fixture_root()
    return non_empty(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT"))
end

local function default_smackage_home()
    local fixture = fixture_root()
    if fixture ~= nil then
        return join_path(fixture, ".smackage")
    end
    local env_home = non_empty(read_proc_environ_value("SMACKAGE_HOME"))
    if env_home ~= nil then
        return env_home
    end
    local home = non_empty(read_proc_environ_value("HOME")) or "~"
    return join_path(home, ".smackage")
end

local function smackage_home(context, package)
    local flags = collect_flags(context, package)
    return flag_value(flags, "home") or default_smackage_home()
end

local function read_text_file(path)
    local handle = io.open(path, "rb")
    if handle == nil then
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function command_exists(context)
    local result = exec_run(context, "command -v " .. REQUIRED_BINARY .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function smackage_command(home, command)
    return "TERM=dumb PAGER=cat SMACKAGE_HOME=" .. shell_quote(home) .. " " .. command
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageId") or "")
end

local function package_version(pkg)
    return trim(read_field(pkg, "version") or "")
end

local function parse_semver(value)
    local text = trim(value):gsub("^v", "")
    local main, prerelease = text:match("^([0-9]+%.[0-9]+%.[0-9]+)%-(.+)$")
    if main == nil then
        local major, minor = text:match("^(%d+)%.(%d+)$")
        if major ~= nil then
            return { major = tonumber(major), minor = tonumber(minor), patch = 0, prerelease = nil, raw = text }
        end
        local single = text:match("^(%d+)$")
        if single ~= nil then
            return { major = tonumber(single), minor = 0, patch = 0, prerelease = nil, raw = text }
        end
    end
    main = main or text
    local major, minor, patch = main:match("^(%d+)%.(%d+)%.(%d+)$")
    if major == nil then
        return nil
    end
    return { major = tonumber(major), minor = tonumber(minor), patch = tonumber(patch), prerelease = prerelease, raw = text }
end

local function compare_semver(left, right)
    local a = parse_semver(left)
    local b = parse_semver(right)
    if a == nil or b == nil then
        if tostring(left) == tostring(right) then
            return 0
        end
        return tostring(left) < tostring(right) and -1 or 1
    end
    for _, key in ipairs({ "major", "minor", "patch" }) do
        if a[key] ~= b[key] then
            return a[key] < b[key] and -1 or 1
        end
    end
    if a.prerelease == b.prerelease then
        return 0
    end
    if a.prerelease == nil then
        return 1
    end
    if b.prerelease == nil then
        return -1
    end
    return a.prerelease < b.prerelease and -1 or 1
end

local function build_package_id(name, version)
    local cleaned_name = trim(name)
    local cleaned_version = trim(version)
    if cleaned_name == "" or cleaned_version == "" then
        return cleaned_name
    end
    return PLUGIN_ID .. "/" .. cleaned_name .. "/" .. cleaned_version
end

local function build_item(name, version, installed, status, latest_version, extra)
    local item = {
        name = name,
        version = version,
        latestVersion = latest_version,
        installed = installed == true,
        status = status,
        packageType = "library",
        type = "package",
        summary = "Standard ML package " .. name,
        description = "Standard ML package " .. name,
        packageId = build_package_id(name, version ~= "" and version or (latest_version or "unknown")),
    }
    if type(extra) == "table" and next(extra) ~= nil then
        item.extraFields = extra
    end
    return item
end

local function parse_explicit_installs(home)
    local items = {}
    local content = read_text_file(join_path(home, "packages.installed"))
    if content == nil then
        return items
    end
    for _, line in ipairs(split_lines(content)) do
        local cleaned = trim(line)
        if cleaned ~= "" and cleaned:sub(1, 1) ~= "#" then
            local name, version = cleaned:match("^(%S+)%s+(%S+)$")
            if name ~= nil and version ~= nil then
                items[name] = version
            end
        end
    end
    return items
end

local function parse_list_output(stdout, explicit_map)
    local items = {}
    local current_name = nil
    for _, line in ipairs(split_lines(stdout)) do
        local pkg = trim(line):match("^Package%s+([^:]+):$")
        if pkg ~= nil then
            current_name = pkg
        else
            local version = trim(line):match("^Version:%s+(.+)$")
            if current_name ~= nil and version ~= nil then
                local extra = {}
                if explicit_map[current_name] ~= nil then
                    extra.explicit = "true"
                    extra.constraint = explicit_map[current_name]
                end
                items[#items + 1] = build_item(current_name, version, true, "installed", nil, next(extra) ~= nil and extra or nil)
            end
        end
    end
    return items
end

local function parse_search_output(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" and cleaned ~= "No packages found." then
            local name, version, source = cleaned:match("^(%S+)%s+(%S+)%s+%((.+)%)$")
            if name ~= nil and version ~= nil then
                local extra = {}
                if source ~= nil then
                    extra.source = source
                end
                items[#items + 1] = build_item(name, version, false, "available", nil, next(extra) ~= nil and extra or nil)
            end
        end
    end
    return items
end

local function parse_info_output(name, stdout)
    local items = {}
    local in_candidates = false
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned == "Candidates:" then
            in_candidates = true
        elseif in_candidates and cleaned ~= "" then
            local candidate_name, version, installed = cleaned:match("^(%S+)%s+(%S+)%s+%((installed)%)$")
            if candidate_name == nil then
                candidate_name, version = cleaned:match("^(%S+)%s+(%S+)$")
            end
            if candidate_name ~= nil and version ~= nil then
                items[#items + 1] = build_item(candidate_name, version, installed == "installed", installed == "installed" and "installed" or "available", nil, nil)
            end
        end
    end
    if #items == 0 and trim(stdout) ~= "" and trim(stdout) ~= "Candidates:" then
        return build_item(name, "", false, "available", nil, nil)
    end

    local best = nil
    for _, item in ipairs(items) do
        if item.installed then
            if best == nil or compare_semver(best.version, item.version) < 0 then
                best = item
            end
        elseif best == nil then
            best = item
        end
    end
    return best or {}
end

local function fail_action(context, message)
    tx_failed(context, message)
    return false
end

local function query_list(context, home)
    local result = exec_run(context, smackage_command(home, "smackage list"))
    if result == nil or not result.success then
        return nil, "smackage list failed"
    end
    return parse_list_output(result.stdout, parse_explicit_installs(home)), nil
end

local function query_info(context, home, name, version)
    local command = "smackage info " .. shell_quote(name)
    if version ~= nil and version ~= "" then
        command = command .. " " .. shell_quote(version)
    end
    local result = exec_run(context, smackage_command(home, command))
    if result == nil or not result.success then
        return nil, "smackage info failed for " .. name
    end
    return parse_info_output(name, result.stdout), nil
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
    return { "programming-language", "package-manager", "standard-ml" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end
    if not command_exists(nil) then
        return requested
    end

    local home = smackage_home(nil, requested[1])
    local listed = query_list(nil, home)
    if type(listed) ~= "table" then
        return requested
    end

    local installed = {}
    for _, item in ipairs(listed) do
        installed[item.name .. "@" .. trim(item.version)] = true
    end

    local filtered = {}
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        local version = package_version(pkg)
        if version == "" then
            local found = false
            for key in pairs(installed) do
                if key:match("^" .. name:gsub("([^%w])", "%%%1") .. "@") then
                    found = true
                    break
                end
            end
            if not found then
                filtered[#filtered + 1] = pkg
            end
        elseif not installed[name .. "@" .. version] then
            filtered[#filtered + 1] = pkg
        end
    end
    return filtered
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if not command_exists(context) then
        return fail_action(context, "smackage not installed")
    end

    local home = smackage_home(context, requested[1])
    begin_step(context, "install smackage packages")
    local installed = {}
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        local version = package_version(pkg)
        if name == "" then
            return fail_action(context, "smackage package name missing")
        end
        local command = "smackage get " .. shell_quote(name)
        if version ~= "" then
            command = command .. " " .. shell_quote(version)
        end
        local result = exec_run(context, smackage_command(home, command))
        if result == nil or not result.success then
            return fail_action(context, "smackage get failed for " .. name)
        end
        installed[#installed + 1] = build_item(name, version, true, "installed", nil, nil)
    end

    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    begin_step(context, "install local smackage target")
    tx_failed(context, "smackage does not support local artifact installs")
    emit_event(context, "failed", "smackage does not support local artifact installs")
    return false
end

function plugin.remove(context, packages)
    begin_step(context, "remove smackage packages")
    tx_failed(context, "smackage does not support package removal")
    return false
end

function plugin.update(context, packages)
    if not command_exists(context) then
        return fail_action(context, "smackage not installed")
    end
    if packages ~= nil and #packages > 0 then
        log_warn(context, "smackage updates global explicit installs; ignoring selected package subset")
    end
    local home = smackage_home(context, packages ~= nil and packages[1] or nil)
    begin_step(context, "update smackage packages")
    local result = exec_run(context, smackage_command(home, "smackage update"))
    if result == nil or not result.success then
        return fail_action(context, "smackage update failed")
    end
    emit_event(context, "updated", packages or {})
    tx_success(context)
    return true
end

function plugin.list(context)
    if not command_exists(context) then
        log_warn(context, "smackage not installed")
        local empty = {}
        emit_event(context, "listed", empty)
        return empty
    end

    local home = smackage_home(context, nil)
    local items, err = query_list(context, home)
    if items == nil then
        log_warn(context, err)
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    if not command_exists(context) then
        log_warn(context, "smackage not installed")
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end

    local home = smackage_home(context, nil)
    local refresh = exec_run(context, smackage_command(home, "smackage refresh"))
    if refresh == nil or not refresh.success then
        log_warn(context, "smackage refresh failed")
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end

    local listed = plugin.list(context)
    local items = {}
    for _, installed in ipairs(listed) do
        local info, err = query_info(context, home, installed.name, nil)
        if info ~= nil and type(info) == "table" and non_empty(info.version) ~= nil then
            if compare_semver(installed.version, info.version) < 0 then
                items[#items + 1] = build_item(installed.name, installed.version, true, "outdated", info.version, type(installed.extraFields) == "table" and installed.extraFields or nil)
            end
        elseif err ~= nil then
            log_warn(context, err)
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
    if query == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    if not command_exists(context) then
        log_warn(context, "smackage not installed")
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local home = smackage_home(context, nil)
    local command = smackage_command(home, "smackage search " .. shell_quote(query))
    local result = exec_run(context, command)
    if result == nil or not result.success then
        log_warn(context, "smackage search failed")
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    local items = parse_search_output(result.stdout)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local target = trim(name or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
    if target == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    if not command_exists(context) then
        log_warn(context, "smackage not installed")
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local home = smackage_home(context, nil)
    local item, err = query_info(context, home, target, nil)
    if item == nil then
        log_warn(context, err)
        item = {}
    end
    emit_event(context, "informed", item)
    return item
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
        capabilities = { "exec" },
        ecosystemScopes = { "sml", "standard-ml", "smackage" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".smackage" },
        },
        networkScopes = { "github.com" },
        privilegeLevel = "user",
        purlType = "generic",
    }
end

return plugin
