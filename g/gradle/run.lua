plugin = {}

local PLUGIN_NAME = "Gradle"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "gradle"

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

local function shell_quote(value)
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,]+$") ~= nil then
        return text
    end
    return "'" .. text:gsub("'", "'\\''") .. "'"
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

local function ensure_available(context)
    local result = run_exec(context, "command -v " .. shell_quote(REQUIRED_BINARY) .. " >/dev/null 2>&1")
    if result ~= nil and result.success == true then
        return true, nil
    end

    return false, REQUIRED_BINARY .. " binary not available"
end

local function parent_dir(path)
    return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
end

local function ensure_directory(path)
    local dir = trim(path)
    if dir == "" or dir == "." then
        return true
    end

    if os == nil or type(os.execute) ~= "function" then
        return false
    end

    local ok = os.execute("mkdir -p " .. shell_quote(dir))
    if ok == true or ok == 0 then
        return true
    end
    return false
end

local function read_file(path)
    local handle = io.open(path, "r")
    if handle == nil then
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(path, content)
    local dir = parent_dir(path)
    local tmp_path = path .. ".tmp"
    local handle = io.open(tmp_path, "w")
    if handle == nil then
        if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
            return false, "mkdir failed for " .. tostring(dir)
        end

        handle = io.open(tmp_path, "w")
    end

    if handle == nil then
        return false, "open failed for " .. tostring(tmp_path)
    end
    handle:write(content)
    handle:close()

    if os == nil or type(os.remove) ~= "function" or type(os.rename) ~= "function" then
        local direct = io.open(path, "w")
        if direct == nil then
            return false, "direct open failed for " .. tostring(path)
        end
        direct:write(content)
        direct:close()
        return true, nil
    end

    os.remove(path)
    local ok = os.rename(tmp_path, path)
    if not ok then
        os.remove(tmp_path)
        return false, "rename failed from " .. tostring(tmp_path) .. " to " .. tostring(path)
    end
    return true, nil
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
            flags[#flags + 1] = trim(item)
        end
    end)

    if not ok then
        return {}
    end
    return flags
end

local function package_flag_value(pkg, prefix)
    for _, flag in ipairs(object_flags(pkg)) do
        if flag:sub(1, #prefix) == prefix then
            return trim(flag:sub(#prefix + 1))
        end
    end
    return ""
end

local function context_flag_value(context, prefix)
    local flags = context and context.flags or {}
    for _, flag in ipairs(flags) do
        local text = trim(flag)
        if text:sub(1, #prefix) == prefix then
            return trim(text:sub(#prefix + 1))
        end
    end
    return ""
end

local function get_plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR)
    if dir ~= "" then
        return dir
    end
    return "."
end

local function data_root_for_packages(context, packages)
    local context_value = context_flag_value(context, "data-root=")
    if context_value ~= "" then
        return context_value
    end
    for _, pkg in ipairs(packages or {}) do
        local value = package_flag_value(pkg, "data-root=")
        if value ~= "" then
            return value
        end
    end
    local env_root = os ~= nil and type(os.getenv) == "function" and trim(os.getenv("RQP_GRADLE_DATA_ROOT")) or ""
    if env_root ~= "" then
        return env_root
    end
    local fixture_root = os ~= nil and type(os.getenv) == "function" and trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT")) or ""
    if fixture_root ~= "" then
        return join_path(fixture_root, ".reqpack-data")
    end
    return join_path(get_plugin_dir(), ".reqpack-data")
end

local function data_root_for_name(name)
    local env_root = os ~= nil and type(os.getenv) == "function" and trim(os.getenv("RQP_GRADLE_DATA_ROOT")) or ""
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
    local data_root = trim(root)
    if data_root == "" then
        data_root = join_path(get_plugin_dir(), ".reqpack-data")
    end

    return {
        root = data_root,
        deps = join_path(data_root, "deps.json"),
        project = join_path(data_root, "gradle-project"),
        settings = join_path(data_root, "gradle-project", "settings.gradle"),
        build = join_path(data_root, "gradle-project", "build.gradle"),
        gradle_user_home = join_path(data_root, "gradle-user-home"),
    }
end

local function escape_json(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\")
    text = text:gsub('"', '\\"')
    text = text:gsub("\n", "\\n")
    text = text:gsub("\r", "\\r")
    text = text:gsub("\t", "\\t")
    return text
end

local function encode_deps(entries)
    local lines = {
        "{",
        '  "formatVersion": 1,',
        '  "dependencies": [',
    }

    for index, entry in ipairs(entries or {}) do
        lines[#lines + 1] = "    {"
        lines[#lines + 1] = '      "group": "' .. escape_json(entry.group) .. '",'
        lines[#lines + 1] = '      "artifact": "' .. escape_json(entry.artifact) .. '",'
        lines[#lines + 1] = '      "version": "' .. escape_json(entry.version) .. '"'
        local suffix = index < #(entries or {}) and "    }," or "    }"
        lines[#lines + 1] = suffix
    end

    lines[#lines + 1] = "  ]"
    lines[#lines + 1] = "}"
    lines[#lines + 1] = ""
    return table.concat(lines, "\n")
end

local function decode_deps(raw)
    local text = tostring(raw or "")
    local entries = {}
    for group, artifact, version in text:gmatch('"group"%s*:%s*"([^"]+)".-"artifact"%s*:%s*"([^"]+)".-"version"%s*:%s*"([^"]+)"') do
        entries[#entries + 1] = {
            group = group,
            artifact = artifact,
            version = version,
        }
    end
    return entries
end

local function sort_entries(entries)
    table.sort(entries, function(left, right)
        local left_key = lower((left.group or "") .. ":" .. (left.artifact or ""))
        local right_key = lower((right.group or "") .. ":" .. (right.artifact or ""))
        return left_key < right_key
    end)
end

local function load_entries(paths)
    local raw = read_file(paths.deps)
    if raw == nil or trim(raw) == "" then
        return {}
    end
    local entries = decode_deps(raw)
    sort_entries(entries)
    return entries
end

local function save_entries(paths, entries)
    sort_entries(entries)
    local ok, message = write_file(paths.deps, encode_deps(entries))
    if not ok then
        return false, message
    end
    return true, nil
end

local function render_build_gradle(entries)
    local lines = {
        "plugins {",
        "    id 'base'",
        "}",
        "",
        "repositories {",
        "    mavenCentral()",
        "}",
        "",
        "configurations {",
        "    reqpack {",
        "        canBeConsumed = false",
        "        canBeResolved = true",
        "    }",
        "}",
        "",
        "dependencies {",
    }

    for _, entry in ipairs(entries or {}) do
        lines[#lines + 1] = "    reqpack '" .. entry.group .. ":" .. entry.artifact .. ":" .. entry.version .. "'"
    end

    lines[#lines + 1] = "}"
    lines[#lines + 1] = ""
    return table.concat(lines, "\n")
end

local function ensure_project_files(paths, entries)
    if not ensure_directory(paths.project) then
        return false, "failed to create Gradle synthetic project directory"
    end
    if not ensure_directory(paths.gradle_user_home) then
        return false, "failed to create Gradle user home directory"
    end
    local ok, message = write_file(paths.settings, "rootProject.name = 'reqpack-gradle-cache'\n")
    if not ok then
        return false, "failed to write settings.gradle: " .. tostring(message)
    end
    ok, message = write_file(paths.build, render_build_gradle(entries))
    if not ok then
        return false, "failed to write build.gradle: " .. tostring(message)
    end
    return true, nil
end

local function normalize_coordinate_parts(name, version)
    local raw_name = trim(name)
    local raw_version = trim(version)
    if raw_name == "" then
        return nil, "missing package name"
    end

    local first, second, third = raw_name:match("^([^:]+):([^:]+):([^:]+)$")
    if first ~= nil then
        return {
            group = trim(first),
            artifact = trim(second),
            version = raw_version ~= "" and raw_version or trim(third),
        }, nil
    end

    first, second = raw_name:match("^([^:]+):([^:]+)$")
    if first ~= nil then
        return {
            group = trim(first),
            artifact = trim(second),
            version = raw_version,
        }, nil
    end

    return nil, "expected Gradle dependency coordinate group:artifact[:version]"
end

local function canonical_name(entry)
    return entry.group .. ":" .. entry.artifact
end

local function coordinate_name(entry)
    return entry.group .. ":" .. entry.artifact .. ":" .. entry.version
end

local function normalize_package(pkg)
    local name = trim(object_field(pkg, "name") or object_field(pkg, "packageName") or object_field(pkg, "packageId"))
    local version = trim(object_field(pkg, "version"))
    local parsed, err = normalize_coordinate_parts(name, version)
    if parsed == nil then
        return nil, err
    end
    if parsed.group == "" or parsed.artifact == "" then
        return nil, "expected Gradle dependency coordinate group:artifact[:version]"
    end
    return parsed, nil
end

local function entry_to_result(entry, source, requested_version)
    return {
        name = canonical_name(entry),
        version = entry.version,
        packageType = "dependency",
        group = entry.group,
        artifact = entry.artifact,
        coordinate = coordinate_name(entry),
        requestedVersion = requested_version or entry.version,
        source = source,
    }
end

local function gradle_base_command(paths, extra_parts)
    local parts = {
        "gradle",
        "--console=plain",
        "--quiet",
        "--no-daemon",
        "--gradle-user-home",
        paths.gradle_user_home,
        "--project-dir",
        paths.project,
    }
    for _, part in ipairs(extra_parts or {}) do
        parts[#parts + 1] = part
    end
    local quoted = {}
    for _, part in ipairs(parts) do
        quoted[#quoted + 1] = shell_quote(part)
    end
    return table.concat(quoted, " ")
end

local function resolve_command(paths, refresh)
    local parts = { "dependencies", "--configuration", "reqpack" }
    if refresh == true then
        parts[#parts + 1] = "--refresh-dependencies"
    end
    return gradle_base_command(paths, parts)
end

local function insight_command(paths, query)
    return gradle_base_command(paths, {
        "dependencyInsight",
        "--dependency",
        query,
        "--configuration",
        "reqpack",
    })
end

local function parse_selected_version(stdout, group, artifact)
    local target = group .. ":" .. artifact .. ":"
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned:sub(1, #target) == target then
            local requested, selected = cleaned:match("^[^:]+:[^:]+:([^%s]+)%s+%-%>%s+([^%s]+)")
            if selected ~= nil and selected ~= "" then
                return selected, requested
            end
            local exact = cleaned:match("^[^:]+:[^:]+:([^%s]+)$")
            if exact ~= nil and exact ~= "" then
                return exact, exact
            end
        end
    end
    return nil, nil
end

local function package_error(context, message, payload)
    tx_failed(context, message)
    emit_event(context, "failed", message)
    if payload ~= nil then
        emit_event(context, "unavailable", payload)
    end
    return false
end

local function index_by_name(entries)
    local indexed = {}
    for index, entry in ipairs(entries or {}) do
        indexed[lower(canonical_name(entry))] = index
    end
    return indexed
end

local function rewrite_state(paths, entries)
    local ok, message = save_entries(paths, entries)
    if not ok then
        return false, "failed to write dependency state: " .. tostring(message)
    end
    return ensure_project_files(paths, entries)
end

local function run_resolve(context, paths, refresh)
    local command = resolve_command(paths, refresh)
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        local message = trim((result and result.stderr) or "Gradle resolution failed")
        if message == "" then
            message = "Gradle resolution failed"
        end
        return false, message
    end
    return true, result.stdout or ""
end

local function clone_entries(entries)
    local copy = {}
    for _, entry in ipairs(entries or {}) do
        copy[#copy + 1] = {
            group = entry.group,
            artifact = entry.artifact,
            version = entry.version,
        }
    end
    return copy
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
    return { "build", "gradle", "maven", "jvm", "dependency-manager" }
end

function plugin.getMissingPackages(packages)
    local paths = state_paths(data_root_for_packages(nil, packages))
    local entries = load_entries(paths)
    local indexed = index_by_name(entries)
    local missing = {}

    for _, pkg in ipairs(packages or {}) do
        local parsed = normalize_package(pkg)
        if parsed ~= nil then
            local current = entries[indexed[lower(canonical_name(parsed))] or 0]
            if current == nil or trim(current.version) ~= trim(parsed.version) then
                missing[#missing + 1] = pkg
            end
        end
    end

    return missing
end

function plugin.install(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message)
    end

    if packages == nil or #packages == 0 then
        tx_success(context)
        return true
    end

    begin_step(context, "Track Gradle dependencies")
    local paths = state_paths(data_root_for_packages(context, packages))
    local entries = load_entries(paths)
    local indexed = index_by_name(entries)

    for _, pkg in ipairs(packages or {}) do
        local parsed, err = normalize_package(pkg)
        if parsed == nil then
            return package_error(context, err)
        end
        if trim(parsed.version) == "" then
            return package_error(context, "Gradle dependency version required for install")
        end

        local key = lower(canonical_name(parsed))
        local index = indexed[key]
        if index ~= nil then
            entries[index].version = parsed.version
        else
            entries[#entries + 1] = parsed
        end
        indexed = index_by_name(entries)
    end

    local ok, message = rewrite_state(paths, entries)
    if not ok then
        return package_error(context, message)
    end

    local resolved, stdout = run_resolve(context, paths, false)
    if not resolved then
        return package_error(context, stdout)
    end

    emit_event(context, "installed", {
        count = #packages,
        statePath = paths.deps,
        cachePath = paths.gradle_user_home,
    })
    tx_success(context)
    emit_event(context, "success", stdout)
    return true
end

function plugin.installLocal(context, path)
    local payload = {
        path = tostring(path or ""),
        reason = "local-install-unsupported",
    }
    return package_error(context, "gradle local installs are not supported", payload)
end

function plugin.remove(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message)
    end

    if packages == nil or #packages == 0 then
        tx_success(context)
        return true
    end

    begin_step(context, "Remove Gradle tracked dependencies")
    local paths = state_paths(data_root_for_packages(context, packages))
    local entries = load_entries(paths)
    local indexed = index_by_name(entries)
    local kept = {}
    local remove_set = {}

    for _, pkg in ipairs(packages or {}) do
        local parsed, err = normalize_package(pkg)
        if parsed == nil then
            return package_error(context, err)
        end
        remove_set[lower(canonical_name(parsed))] = true
    end

    for _, entry in ipairs(entries) do
        if not remove_set[lower(canonical_name(entry))] then
            kept[#kept + 1] = entry
        end
    end

    local ok, message = rewrite_state(paths, kept)
    if not ok then
        return package_error(context, message)
    end

    emit_event(context, "deleted", {
        count = #packages,
        statePath = paths.deps,
    })
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.update(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message)
    end

    if packages == nil or #packages == 0 then
        tx_success(context)
        return true
    end

    begin_step(context, "Update Gradle tracked dependencies")
    local paths = state_paths(data_root_for_packages(context, packages))
    local entries = load_entries(paths)
    local indexed = index_by_name(entries)

    for _, pkg in ipairs(packages or {}) do
        local parsed, err = normalize_package(pkg)
        if parsed == nil then
            return package_error(context, err)
        end
        if trim(parsed.version) == "" then
            return package_error(context, "Gradle dependency version required for update")
        end

        local key = lower(canonical_name(parsed))
        local index = indexed[key]
        if index ~= nil then
            entries[index].version = parsed.version
        else
            entries[#entries + 1] = parsed
        end
        indexed = index_by_name(entries)
    end

    local ok, message = rewrite_state(paths, entries)
    if not ok then
        return package_error(context, message)
    end

    local resolved, stdout = run_resolve(context, paths, true)
    if not resolved then
        return package_error(context, stdout)
    end

    emit_event(context, "updated", {
        count = #packages,
        statePath = paths.deps,
        cachePath = paths.gradle_user_home,
    })
    tx_success(context)
    emit_event(context, "success", stdout)
    return true
end

function plugin.list(context)
    local available, message = ensure_available(context)
    if not available then
        log_warn(context, message)
        local results = {}
        emit_event(context, "listed", results)
        return results
    end

    local paths = state_paths(data_root_for_name(""))
    local entries = load_entries(paths)
    local results = {}

    ensure_project_files(paths, entries)

    for _, entry in ipairs(entries) do
        local command = insight_command(paths, canonical_name(entry))
        local result = run_exec(context, command)
        local selected, requested = parse_selected_version(result and result.stdout or "", entry.group, entry.artifact)
        if result == nil or result.success ~= true then
            log_warn(context, "Gradle dependencyInsight failed for " .. canonical_name(entry) .. "; using tracked version")
        end
        local item = entry_to_result({
            group = entry.group,
            artifact = entry.artifact,
            version = selected or entry.version,
        }, selected and "resolved" or "tracked", requested or entry.version)
        results[#results + 1] = item
    end

    emit_event(context, "listed", results)
    return results
end

function plugin.outdated(context)
    ensure_available(context)
    local results = {}
    emit_event(context, "outdated", results)
    return results
end

function plugin.search(context, prompt)
    ensure_available(context)
    local results = {}
    emit_event(context, "searched", {
        prompt = trim(prompt),
        results = results,
    })
    return results
end

function plugin.info(context, name)
    local available, message = ensure_available(context)
    if not available then
        log_warn(context, message)
        local results = {}
        emit_event(context, "informed", results)
        return results
    end

    local raw_name = trim(name)
    if raw_name == "" then
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    local explicit, err = normalize_coordinate_parts(raw_name, "")
    if explicit == nil then
        log_warn(context, err)
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    local paths = state_paths(data_root_for_name(raw_name))
    local entries = load_entries(paths)
    local tracked = nil
    for _, entry in ipairs(entries) do
        if lower(canonical_name(entry)) == lower(canonical_name(explicit)) then
            tracked = entry
            break
        end
    end

    local active_entry = tracked
    local temporary = false
    if active_entry == nil then
        if trim(explicit.version) == "" then
            local item = {}
            emit_event(context, "informed", item)
            return item
        end
        active_entry = explicit
        temporary = true
    end

    local render_entries = temporary and { active_entry } or clone_entries(entries)
    local ok, message = ensure_project_files(paths, render_entries)
    if not ok then
        log_warn(context, message)
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    local result = run_exec(context, insight_command(paths, canonical_name(active_entry)))
    if result == nil or result.success ~= true then
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    local selected, requested = parse_selected_version(result.stdout or "", active_entry.group, active_entry.artifact)
    local info = entry_to_result({
        group = active_entry.group,
        artifact = active_entry.artifact,
        version = selected or active_entry.version,
    }, selected and "resolved" or "tracked", requested or active_entry.version)
    emit_event(context, "informed", info)
    return info
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "gradle", "maven", "jvm" },
        writeScopes = {
            { kind = "plugin-subpath", path = ".reqpack-data" },
        },
        networkScopes = {
            "repo1.maven.org",
            "repo.maven.apache.org",
            "plugins.gradle.org",
            "services.gradle.org",
        },
        privilegeLevel = "user",
        osvEcosystem = "Maven",
        purlType = "maven",
    }
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

return plugin
