plugin = {}

local PLUGIN_ID = "smlpkg"
local PLUGIN_NAME = "smlpkg"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "smlpkg"
local MANIFEST_FILE = "sml.pkg"
local LIB_DIR = "lib"
local workspace_root_from_flags

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

local function workspace_root(context, package)
    return workspace_root_from_flags(context, package) or non_empty(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT")) or "."
end

local function manifest_path(context, package)
    return join_path(workspace_root(context, package), MANIFEST_FILE)
end

local function lib_root(context, package)
    return join_path(workspace_root(context, package), LIB_DIR)
end

local function is_directory(path)
    local probe = io.open(join_path(path, ".keep"), "rb")
    if probe ~= nil then
        probe:close()
        return true
    end
    return false
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

local function read_text_file_with_context(context, path)
    if context ~= nil then
        local result = exec_run(context, "cat " .. shell_quote(path))
        if result ~= nil and result.success then
            return result.stdout
        end
    end
    return read_text_file(path)
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. binary .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageId") or "")
end

local function package_version(pkg)
    return trim(read_field(pkg, "version") or "")
end

local function package_action(pkg)
    return lower(read_field(pkg, "action") or "")
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

workspace_root_from_flags = function(context, package)
    local flags = {}
    local function collect(value)
        for _, flag in ipairs(object_flags(value)) do
            flags[#flags + 1] = flag
        end
    end
    collect(context)
    collect(read_field(context, "request"))
    collect(package)
    for _, flag in ipairs(flags) do
        local path = trim(flag:match("^root=(.+)$") or "")
        if path ~= "" then
            return path
        end
    end
    return nil
end

local function parse_semver(value)
    local text = trim(value)
    local main, prerelease = text:match("^([0-9]+%.[0-9]+%.[0-9]+)%-(.+)$")
    local build = nil
    if prerelease ~= nil then
        prerelease, build = prerelease:match("^([^+]+)%+(.+)$")
    else
        main, build = text:match("^([0-9]+%.[0-9]+%.[0-9]+)%+(.+)$")
    end
    main = main or text
    local major, minor, patch = main:match("^(%d+)%.(%d+)%.(%d+)$")
    if major == nil then
        return nil
    end
    return {
        major = tonumber(major),
        minor = tonumber(minor),
        patch = tonumber(patch),
        prerelease = prerelease,
        build = build,
        raw = text,
    }
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
    if a.prerelease == b.prerelease then
        return 0
    end
    return a.prerelease < b.prerelease and -1 or 1
end

local function parse_manifest(content)
    local manifest = {
        package = nil,
        requires = {},
    }
    local in_require = false
    for _, line in ipairs(split_lines(content or "")) do
        local cleaned = trim(line)
        if cleaned == "" then
        elseif cleaned:match("^package%s+") then
            manifest.package = trim(cleaned:match("^package%s+(.+)$") or "")
        elseif cleaned == "require {" then
            in_require = true
        elseif cleaned == "}" then
            in_require = false
        elseif in_require then
            local body, hash = cleaned:match("^(.-)%s+#([^%s]+)%s*$")
            if body == nil then
                body = cleaned
            end
            local name, version = body:match("^(%S+)%s+(%S+)$")
            if name ~= nil and version ~= nil then
                manifest.requires[#manifest.requires + 1] = {
                    name = name,
                    version = version,
                    hash = hash,
                }
            end
        end
    end
    return manifest
end

local function load_manifest(context, package)
    local content = read_text_file_with_context(context, manifest_path(context, package))
    if content == nil then
        return {
            package = nil,
            requires = {},
        }
    end
    return parse_manifest(content)
end

local function load_manifest_map(context, package)
    local map = {}
    for _, item in ipairs(load_manifest(context, package).requires) do
        map[item.name] = item
    end
    return map
end

local function installed_path(context, package, name)
    return join_path(lib_root(context, package), name)
end

local function is_installed(context, package, name)
    return is_directory(installed_path(context, package, name))
end

local function build_package_id(name, version)
    local cleaned_name = trim(name)
    local cleaned_version = trim(version)
    if cleaned_name == "" or cleaned_version == "" then
        return nil
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
    if item.packageId == nil then
        item.packageId = name
    end
    return item
end

local function query_versions(context, name)
    local result = exec_run(context, "smlpkg versions " .. shell_quote(name))
    if result == nil or not result.success then
        return nil, "smlpkg versions failed for " .. name
    end
    local versions = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            versions[#versions + 1] = cleaned
        end
    end
    table.sort(versions, function(left, right)
        return compare_semver(left, right) < 0
    end)
    return versions, nil
end

local function latest_version(context, name)
    local versions = query_versions(context, name)
    if type(versions) ~= "table" or #versions == 0 then
        return nil
    end
    return versions[#versions]
end

local function request_result_item(pkg, status)
    local name = package_name(pkg)
    local version = package_version(pkg)
    return build_item(name, version, status ~= "removed", status, nil, nil)
end

local function fail_action(context, message)
    tx_failed(context, message)
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
    return { "programming-language", "package-manager", "standard-ml" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end

    local manifest_map = load_manifest_map(nil, requested[1])
    local filtered = {}
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        local version = package_version(pkg)
        local action = package_action(pkg)
        local current = manifest_map[name]
        if action == "remove" then
            if current ~= nil then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "update" then
            filtered[#filtered + 1] = pkg
        elseif current == nil then
            filtered[#filtered + 1] = pkg
        elseif version ~= "" and current.version ~= version then
            filtered[#filtered + 1] = pkg
        elseif version == "" then
        end
    end
    return filtered
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        return fail_action(context, "smlpkg not installed")
    end

    begin_step(context, "install smlpkg packages")
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        if name == "" then
            return fail_action(context, "smlpkg package name missing")
        end
        local version = package_version(pkg)
        local command = "smlpkg add " .. shell_quote(name)
        if version ~= "" then
            command = command .. " " .. shell_quote(version)
        end
        local result = exec_run(context, command)
        if result == nil or not result.success then
            return fail_action(context, "smlpkg add failed for " .. name)
        end
    end

    local sync_result = exec_run(context, "smlpkg sync")
    if sync_result == nil or not sync_result.success then
        return fail_action(context, "smlpkg sync failed")
    end

    local installed = {}
    for _, pkg in ipairs(requested) do
        installed[#installed + 1] = request_result_item(pkg, "installed")
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    begin_step(context, "install local smlpkg target")
    tx_failed(context, "smlpkg does not support local artifact installs")
    emit_event(context, "failed", "smlpkg does not support local artifact installs")
    return false
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        return fail_action(context, "smlpkg not installed")
    end

    begin_step(context, "remove smlpkg packages")
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        if name == "" then
            return fail_action(context, "smlpkg package name missing")
        end
        local result = exec_run(context, "smlpkg remove " .. shell_quote(name))
        if result == nil or not result.success then
            return fail_action(context, "smlpkg remove failed for " .. name)
        end
    end

    local sync_result = exec_run(context, "smlpkg sync")
    if sync_result == nil or not sync_result.success then
        return fail_action(context, "smlpkg sync failed")
    end

    local removed = {}
    for _, pkg in ipairs(requested) do
        local item = request_result_item(pkg, "removed")
        item.installed = false
        removed[#removed + 1] = item
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    if not command_exists(context, REQUIRED_BINARY) then
        return fail_action(context, "smlpkg not installed")
    end
    if packages ~= nil and #packages > 0 then
        log_warn(context, "smlpkg updates all manifest dependencies; ignoring selected package subset")
    end

    begin_step(context, "update smlpkg packages")
    local upgrade_result = exec_run(context, "smlpkg upgrade")
    if upgrade_result == nil or not upgrade_result.success then
        return fail_action(context, "smlpkg upgrade failed")
    end
    local sync_result = exec_run(context, "smlpkg sync")
    if sync_result == nil or not sync_result.success then
        return fail_action(context, "smlpkg sync failed")
    end

    emit_event(context, "updated", packages or {})
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = {}
    for _, requirement in ipairs(load_manifest(context, nil).requires) do
        items[#items + 1] = build_item(
            requirement.name,
            requirement.version,
            is_installed(context, nil, requirement.name),
            is_installed(context, nil, requirement.name) and "installed" or "declared",
            nil,
            requirement.hash ~= nil and { hash = requirement.hash } or nil
        )
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    if not command_exists(context, REQUIRED_BINARY) then
        log_warn(context, "smlpkg not installed")
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end

    local items = {}
    for _, requirement in ipairs(load_manifest(context, nil).requires) do
        local latest = latest_version(context, requirement.name)
        if latest ~= nil and compare_semver(requirement.version, latest) < 0 then
            items[#items + 1] = build_item(
                requirement.name,
                requirement.version,
                is_installed(context, nil, requirement.name),
                "outdated",
                latest,
                requirement.hash ~= nil and { hash = requirement.hash } or nil
            )
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
    if query ~= "" then
        log_warn(context, "smlpkg upstream has no search command; returning empty result")
    end
    local empty = {}
    emit_event(context, "searched", empty)
    return empty
end

function plugin.info(context, name)
    local target = trim(name or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
    if target == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local manifest_map = load_manifest_map(context, nil)
    local current = manifest_map[target]
    local latest = nil
    if command_exists(context, REQUIRED_BINARY) then
        latest = latest_version(context, target)
    end

    local item = build_item(
        target,
        current ~= nil and current.version or "",
        is_installed(context, nil, target),
        (current ~= nil and latest ~= nil and compare_semver(current.version, latest) < 0) and "outdated" or (is_installed(context, nil, target) and "installed" or "available"),
        latest,
        current ~= nil and current.hash ~= nil and { hash = current.hash } or nil
    )
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
        ecosystemScopes = { "sml", "standard-ml", "smlpkg" },
        writeScopes = {
            { kind = "workspace-subpath", value = "sml.pkg" },
            { kind = "workspace-subpath", value = "lib" },
        },
        networkScopes = { "github.com", "gitlab.com" },
        privilegeLevel = "user",
        purlType = "generic",
    }
end

return plugin
