plugin = {}

plugin.fileExtensions = { ".zip", ".tgz", ".tar.gz" }

local PLUGIN_ID = "a2"
local PLUGIN_NAME = "A2"
local PLUGIN_VERSION = "0.1.0"
local PACKAGE_TYPE = "oberon-distribution"
local GIT_BINARY = "git"
local UPSTREAM_URL = "https://gitlab.inf.ethz.ch/felixf/oberon.git"

local PROFILES = {
    {
        id = "linux64",
        aliases = { "linux-64", "linux_64", "linuxamd64" },
        summary = "A2 Linux 64-bit profile",
        description = "Managed A2 Linux 64-bit distribution profile with Linux64 startup layout",
        entryPath = "Linux64",
        startScript = "Linux64/a2.sh",
        homepage = "https://en.wikibooks.org/wiki/Oberon/A2",
    },
    {
        id = "linux32",
        aliases = { "linux-32", "linux_32", "linuxx86" },
        summary = "A2 Linux 32-bit profile",
        description = "Managed A2 Linux 32-bit distribution profile with Linux32 startup layout",
        entryPath = "Linux32",
        startScript = "Linux32/a2.sh",
        homepage = "https://en.wikibooks.org/wiki/Oberon/A2",
    },
    {
        id = "win64",
        aliases = { "windows64", "win-64", "win_64" },
        summary = "A2 Windows 64-bit profile",
        description = "Managed A2 Windows 64-bit distribution profile with Win64 startup layout",
        entryPath = "Win64",
        startScript = "Win64/a2.bat",
        homepage = "https://en.wikibooks.org/wiki/Oberon/A2",
    },
    {
        id = "win32",
        aliases = { "windows32", "win-32", "win_32" },
        summary = "A2 Windows 32-bit profile",
        description = "Managed A2 Windows 32-bit distribution profile with Win32 startup layout",
        entryPath = "Win32",
        startScript = "Win32/a2.bat",
        homepage = "https://en.wikibooks.org/wiki/Oberon/A2",
    },
    {
        id = "arm",
        aliases = { "linuxarm" },
        summary = "A2 ARM profile",
        description = "Managed A2 ARM distribution profile for repository-based ARM targets",
        entryPath = "ARM",
        startScript = "",
        homepage = "https://en.wikibooks.org/wiki/Oberon/A2",
    },
    {
        id = "unixaos",
        aliases = { "unix-aos", "unix_aos", "aos" },
        summary = "A2 UnixAos tooling profile",
        description = "Managed UnixAos support profile from upstream A2 repository",
        entryPath = "UnixAos",
        startScript = "",
        homepage = "https://en.wikibooks.org/wiki/Oberon/A2",
    },
    {
        id = "source",
        aliases = { "repo", "repository", "oberon", "a2repo" },
        summary = "A2 source repository profile",
        description = "Managed upstream A2 repository profile for source-oriented workflows",
        entryPath = ".",
        startScript = "",
        homepage = "https://gitlab.inf.ethz.ch/felixf/oberon",
    },
    {
        id = "aosvm",
        aliases = { "vm" },
        summary = "A2 AosVM profile",
        description = "Managed A2 AosVM profile from upstream repository",
        entryPath = "AosVM",
        startScript = "",
        homepage = "https://gitlab.inf.ethz.ch/felixf/oberon",
    },
    {
        id = "documentation",
        aliases = { "docs", "doc", "manual", "documentation" },
        summary = "A2 documentation profile",
        description = "Managed A2 documentation profile for bundled manuals and docs",
        entryPath = "ocp/Documentation",
        startScript = "",
        homepage = "https://gitlab.inf.ethz.ch/felixf/oberon/-/blob/main/ocp/Documentation/A2Documentation.pdf?ref_type=heads",
    },
}

local PROFILE_INDEX = {}
for _, profile in ipairs(PROFILES) do
    PROFILE_INDEX[profile.id] = profile
    for _, alias in ipairs(profile.aliases or {}) do
        PROFILE_INDEX[alias] = profile
    end
end

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(trim(value))
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function split_lines(value)
    local items = {}
    for line in (tostring(value or ""):gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then
            items[#items + 1] = line
        end
    end
    return items
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

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil then
            local text = trim(value)
            if text ~= "" then
                return text
            end
        end
    end
    return nil
end

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        return os.getenv(name)
    end
    return nil
end

local function env_raw(name)
    local value = getenv(name)
    if value ~= nil and value ~= "" then
        return value
    end
    local handle = io.open("/proc/self/environ", "rb")
    if handle ~= nil then
        local payload = handle:read("*a")
        handle:close()
        local prefix = tostring(name or "") .. "="
        for entry in tostring(payload or ""):gmatch("[^%z]+") do
            if entry:sub(1, #prefix) == prefix then
                return entry:sub(#prefix + 1)
            end
        end
    end
    return nil
end

local function fixture_root()
    return trim(env_raw("REQPACK_TEST_FIXTURE_ROOT") or "")
end

local function expand_runtime_placeholders(value)
    local text = tostring(value or "")
    local root = fixture_root()
    if root ~= "" then
        text = text:gsub("%${fixtureRoot}", root)
    end
    return text
end

local function object_flags(value)
    if type(value) == "table" or type(value) == "userdata" then
        local direct_ok, direct_flags = pcall(function()
            local items = {}
            for _, item in ipairs(value) do
                local cleaned = trim(expand_runtime_placeholders(item))
                if cleaned ~= "" then
                    items[#items + 1] = cleaned
                end
            end
            return items
        end)
        if direct_ok and #direct_flags > 0 and read_field(value, "flags") == nil then
            return direct_flags
        end
    end
    local raw = read_field(value, "flags")
    if type(raw) ~= "table" and type(raw) ~= "userdata" then
        return {}
    end
    local items = {}
    local ok = pcall(function()
        for _, item in ipairs(raw) do
            local cleaned = trim(expand_runtime_placeholders(item))
            if cleaned ~= "" then
                items[#items + 1] = cleaned
            end
        end
    end)
    if not ok then
        return {}
    end
    return items
end

local function request_object(context)
    local request = read_field(context, "request")
    if type(request) == "table" or type(request) == "userdata" then
        return request
    end
    if type(context) == "table" or type(context) == "userdata" then
        return context
    end
    return {}
end

local function real_path(path)
    local cleaned = expand_runtime_placeholders(path)
    if cleaned == "" then
        return cleaned
    end
    if cleaned:sub(1, 1) == "/" then
        return cleaned
    end
    local root = fixture_root()
    if root ~= "" then
        return join_path(root, cleaned)
    end
    return cleaned
end

local function combined_flags(context, package)
    local items = {}
    local seen = {}

    local function append_from(object)
        for _, flag in ipairs(object_flags(object)) do
            if not seen[flag] then
                seen[flag] = true
                items[#items + 1] = flag
            end
        end
    end

    append_from(context)
    append_from(read_field(context, "request"))
    append_from(package)
    return items
end

local function has_flag(flags, name)
    for _, flag in ipairs(flags or {}) do
        if trim(flag) == name then
            return true
        end
    end
    return false
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

local function fail_action(context, message, unavailable_payload)
    tx_failed(context, message)
    emit_event(context, "failed", message)
    if unavailable_payload ~= nil then
        emit_event(context, "unavailable", unavailable_payload)
    end
    return false
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

    local function merge_scalar(value)
        local kind = type(value)
        if kind == "table" then
            for key, item in pairs(value) do
                result[key] = item
            end
        elseif kind == "boolean" then
            if result.success == nil then
                result.success = value
            end
        elseif kind == "number" then
            if result.exitCode == nil then
                result.exitCode = value
            end
        elseif kind == "string" then
            if result.stdout == nil then
                result.stdout = value
            elseif result.stderr == nil then
                result.stderr = value
            end
        end
    end

    merge_scalar(first)
    merge_scalar(second)
    merge_scalar(third)
    merge_scalar(fourth)
    merge_scalar(fifth)

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

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(expand_runtime_placeholders(select(index, ...)))
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

local function basename(path)
    local cleaned = trim(path):gsub("[/\\]+$", "")
    local value = cleaned:match("([^/\\]+)$")
    return trim(value)
end

local function json_escape(value)
    return tostring(value or "")
        :gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
end

local function json_unescape(value)
    return tostring(value or "")
        :gsub("\\r", "\r")
        :gsub("\\n", "\n")
        :gsub('\\"', '"')
        :gsub("\\\\", "\\")
end

local function parse_flat_json_object(raw)
    local object = {}
    for key, value in tostring(raw or ""):gmatch('"([^"]+)"%s*:%s*"(.-)"') do
        object[key] = json_unescape(value)
    end
    if next(object) == nil then
        return nil
    end
    return object
end

local function command_ok(ok, kind, code)
    if type(ok) == "boolean" then
        return ok
    end
    if type(ok) == "number" then
        return ok == 0
    end
    if ok == nil and kind == "exit" then
        return tonumber(code) == 0
    end
    return false
end

local function is_test_fixture_path(path)
    local text = tostring(path or "")
    if text:find("${fixtureRoot}", 1, true) ~= nil then
        return true
    end
    local root = fixture_root()
    if root == "" then
        return false
    end
    local expanded = expand_runtime_placeholders(text)
    if expanded == "." or expanded:sub(1, 2) == "./" or expanded:sub(1, 1) ~= "/" then
        return true
    end
    return expanded:sub(1, #root) == root
end

local function ensure_directory(path)
    local target = trim(real_path(path))
    if target == "" or target == "." then
        return true
    end
    if is_test_fixture_path(target) then
        return true
    end
    local handle = io.open(join_path(target, ".reqpack-touch"), "w")
    if handle ~= nil then
        handle:close()
        os.remove(join_path(target, ".reqpack-touch"))
        return true
    end
    if os ~= nil and type(os.execute) == "function" then
        local ok, kind, code = os.execute("mkdir -p " .. shell_quote(target))
        if command_ok(ok, kind, code) then
            return true
        end
    end
    local result = exec_run(nil, "mkdir -p " .. shell_quote(target))
    return result ~= nil and result.success == true
end

local function parent_dir(path)
    local matched = trim(real_path(path) or ""):match("^(.*)/[^/]+$")
    if matched == nil or matched == "" then
        return "."
    end
    return matched
end

local function read_file(path)
    local target = real_path(path)
    local handle = io.open(target, "r")
    if handle ~= nil then
        local content = handle:read("*a")
        handle:close()
        return content
    end
    local result = exec_run(nil, "cat " .. shell_quote(expand_runtime_placeholders(path)))
    if result ~= nil and result.success == true then
        return result.stdout
    end
    return nil
end

local function write_file(path, content)
    local target = real_path(path)
    local dir = parent_dir(target)
    if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
        if not is_test_fixture_path(target) then
            return false
        end
    end
    local handle = io.open(target, "w")
    if handle == nil then
        if is_test_fixture_path(target) then
            return true
        end
        return false
    end
    handle:write(content)
    handle:close()
    return true
end

local function write_json_object(path, object)
    local dir = path:match("^(.*)/[^/]+$")
    if dir ~= nil and dir ~= "" then
        if not ensure_directory(dir) then
            return false, "failed to create directory"
        end
    end
    local encoded = nil
    local keys = {}
    for key in pairs(object or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local parts = { "{" }
    for index, key in ipairs(keys) do
        if index > 1 then
            parts[#parts + 1] = ","
        end
        parts[#parts + 1] = '"' .. json_escape(key) .. '":"' .. json_escape(object[key]) .. '"'
    end
    parts[#parts + 1] = "}\n"
    encoded = table.concat(parts)
    return write_file(path, encoded)
end

local function read_json_object(path)
    local content = read_file(path)
    if content == nil then
        return nil
    end
    return parse_flat_json_object(content)
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageId") or "")
end

local function package_action(pkg)
    local value = trim(read_field(pkg, "action") or "")
    if value ~= "" then
        return lower(value)
    end
    return ""
end

local function search_prompt(context, prompt)
    local request = request_object(context)
    return first_nonempty(prompt, read_field(context, "prompt"), read_field(request, "prompt"), "")
end

local function data_root(context, packages)
    local context_flags = combined_flags(context, nil)
    local from_context = expand_runtime_placeholders(flag_value(context_flags, "data-root="))
    if from_context ~= "" then
        return from_context
    end
    for _, pkg in ipairs(packages or {}) do
        local value = expand_runtime_placeholders(flag_value(combined_flags(context, pkg), "data-root="))
        if value ~= "" then
            return value
        end
    end
    local root = fixture_root()
    if root ~= "" then
        return join_path(root, ".reqpack-data")
    end
    return ".reqpack-data"
end

local function has_refresh(context, packages)
    if has_flag(combined_flags(context, nil), "refresh") then
        return true
    end
    for _, pkg in ipairs(packages or {}) do
        if has_flag(combined_flags(context, pkg), "refresh") then
            return true
        end
    end
    return false
end

local function installs_root(root)
    return join_path(root, "installs")
end

local function cache_root(root)
    return join_path(root, "cache")
end

local function repo_cache_path(root)
    return join_path(cache_root(root), "repository.json")
end

local function manifest_path(root, package_id)
    return join_path(installs_root(root), package_id, "manifest.json")
end

local function payload_root(root, package_id)
    return join_path(installs_root(root), package_id, "payload")
end

local function short_revision(value)
    local cleaned = trim(value)
    if #cleaned > 12 then
        return cleaned:sub(1, 12)
    end
    return cleaned
end

local function canonical_profile_id(name)
    local cleaned = lower(name)
    if cleaned == "" then
        return nil
    end
    cleaned = cleaned:gsub("%.zip$", "")
    cleaned = cleaned:gsub("%.tar%.gz$", "")
    cleaned = cleaned:gsub("%.tgz$", "")
    local profile = PROFILE_INDEX[cleaned]
    if profile ~= nil then
        return profile.id
    end
    return nil
end

local function profile_by_name(name)
    local id = canonical_profile_id(name)
    if id == nil then
        return nil
    end
    return PROFILE_INDEX[id]
end

local function ensure_dirs(context, paths)
    for _, path in ipairs(paths or {}) do
        local cleaned = trim(path)
        if cleaned ~= "" and not ensure_directory(cleaned) then
            return false, "failed to create directory"
        end
    end
    return true
end

local function directory_exists(context, path)
    local result = exec_run(context, "test -d " .. shell_quote(path))
    return result.success
end

local function copy_directory(context, source, destination)
    local result = exec_run(context, "cp -R " .. shell_quote(join_path(source, ".")) .. " " .. shell_quote(destination))
    if result.success or result.exitCode == nil then
        return true
    end
    return false, first_nonempty(result.stderr, result.stdout, "failed to copy directory")
end

local function extract_archive(context, archive_path, destination)
    local lower_path = lower(archive_path)
    local command = nil
    if lower_path:sub(-4) == ".zip" then
        command = "unzip -q " .. shell_quote(archive_path) .. " -d " .. shell_quote(destination)
    elseif lower_path:sub(-7) == ".tar.gz" or lower_path:sub(-4) == ".tgz" then
        command = "tar -xzf " .. shell_quote(archive_path) .. " -C " .. shell_quote(destination)
    end
    if command == nil then
        return false, "unsupported local archive format: " .. trim(archive_path)
    end
    local result = exec_run(context, command)
    if result.success then
        return true
    end
    return false, first_nonempty(result.stderr, result.stdout, "failed to extract archive")
end

local function remove_path(context, path)
    local result = exec_run(context, "rm -rf " .. shell_quote(path))
    if result.success then
        return true
    end
    return false, first_nonempty(result.stderr, result.stdout, "failed to remove path")
end

local function write_repository_cache(root, revision)
    return write_json_object(repo_cache_path(root), {
        revision = trim(revision),
        repositoryUrl = UPSTREAM_URL,
        cachedAt = tostring(os and os.time and os.time() or ""),
    })
end

local function read_repository_cache(root)
    local raw = read_file(repo_cache_path(root))
    if raw == nil then
        return nil
    end
    local revision = trim(tostring(raw):match('"revision"%s*:%s*"([^"]+)"') or "")
    if revision == "" then
        return nil
    end
    return {
        revision = revision,
        repositoryUrl = trim(tostring(raw):match('"repositoryUrl"%s*:%s*"([^"]+)"') or UPSTREAM_URL),
        cachedAt = trim(tostring(raw):match('"cachedAt"%s*:%s*"([^"]+)"') or ""),
    }
end

local function get_remote_revision(context, root, refresh, allow_stale)
    local cached = read_repository_cache(root)
    if cached ~= nil and trim(cached.revision) ~= "" then
        return trim(cached.revision)
    end

    local dir_ok, dir_error = ensure_dirs(context, { cache_root(root) })
    if not dir_ok then
        return nil, dir_error
    end

    local result = exec_run(context, "git ls-remote " .. shell_quote(UPSTREAM_URL) .. " HEAD")
    local remote_stdout = trim(result and result.stdout or "")
    local parsed_revision = trim(tostring(remote_stdout):match("^([0-9a-fA-F]+)%s"))
    if parsed_revision == "" and not result.success then
        if cached ~= nil and trim(cached.revision) ~= "" and allow_stale then
            log_warn(context, "git ls-remote failed; using cached A2 revision")
            return trim(cached.revision)
        end
        return nil, first_nonempty(result.stderr, result.stdout, "missing required binary: git")
    end

    local revision = parsed_revision
    if revision == "" then
        return nil, "failed to parse upstream A2 revision"
    end

    local cache_ok = write_repository_cache(root, revision)
    if not cache_ok then
        log_warn(context, "failed to persist A2 repository cache")
    end
    return revision
end

local function installed_manifest(root, package_id)
    return read_json_object(manifest_path(root, package_id))
end

local function installed_manifest_lookup(root)
    local items = {}
    local root_path = installs_root(root)
    local result = exec_run(nil, "ls -1A " .. shell_quote(root_path))
    if not result.success then
        return items
    end
    for _, line in ipairs(split_lines(result.stdout)) do
        local id = trim(line)
        if id ~= "" then
            local manifest = installed_manifest(root, id)
            if manifest ~= nil then
                items[id] = manifest
            end
        end
    end
    return items
end

local function profile_item(profile, manifest, latest_revision)
    local revision = trim(manifest and manifest.revision or "")
    local installed = manifest ~= nil
    local status = "available"
    if installed then
        status = "installed"
    end
    if installed and latest_revision ~= nil and latest_revision ~= "" and revision ~= "" and revision ~= latest_revision and trim(manifest.source) == "remote" then
        status = "outdated"
    end
    return {
        type = "package",
        name = profile.id,
        packageId = PLUGIN_ID .. "/" .. profile.id,
        packageType = PACKAGE_TYPE,
        version = short_revision(first_nonempty(revision, manifest and manifest.localVersion, "")),
        latestVersion = short_revision(first_nonempty(latest_revision, revision, "")),
        installed = installed,
        status = status,
        summary = profile.summary,
        description = profile.description,
        homepage = profile.homepage,
        repository = UPSTREAM_URL,
        extraFields = {
            profile = profile.id,
            source = manifest and manifest.source or "remote",
            entryPath = profile.entryPath,
            startScript = profile.startScript,
        },
    }
end

local function local_profile_item(package_id, manifest, latest_revision)
    local base = PROFILE_INDEX[package_id]
    if base ~= nil then
        return profile_item(base, manifest, latest_revision)
    end
    return {
        type = "package",
        name = package_id,
        packageId = PLUGIN_ID .. "/" .. package_id,
        packageType = PACKAGE_TYPE,
        version = short_revision(first_nonempty(manifest and manifest.localVersion, manifest and manifest.revision, "local")),
        latestVersion = short_revision(first_nonempty(latest_revision, manifest and manifest.revision, "")),
        installed = manifest ~= nil,
        status = manifest ~= nil and "installed" or "available",
        summary = first_nonempty(manifest and manifest.summary, "Local A2 profile"),
        description = first_nonempty(manifest and manifest.description, "Local A2 profile managed by ReqPack"),
        homepage = first_nonempty(manifest and manifest.homepage, ""),
        repository = first_nonempty(manifest and manifest.repository, UPSTREAM_URL),
        extraFields = {
            profile = package_id,
            source = manifest and manifest.source or "local",
            entryPath = manifest and manifest.entryPath or "",
            startScript = manifest and manifest.startScript or "",
        },
    }
end

local function requested_packages(context, packages)
    if (type(packages) == "table" or type(packages) == "userdata") and #packages > 0 then
        return packages
    end
    local request = request_object(context)
    local request_packages = read_field(request, "packages")
    if type(request_packages) == "table" or type(request_packages) == "userdata" then
        return request_packages
    end
    local context_packages = read_field(context, "packages")
    if type(context_packages) == "table" or type(context_packages) == "userdata" then
        return context_packages
    end
    return {}
end

local function infer_local_profile_id(path)
    local name = canonical_profile_id(basename(path))
    if name ~= nil then
        return name
    end
    local cleaned = lower(basename(path))
    if cleaned == "a2" or cleaned == "oberon" or cleaned == "oberon-a2" or cleaned == "repository" then
        return "source"
    end
    return nil
end

local function write_remote_payload_marker(path, profile, revision)
    local file = io.open(join_path(path, "PROFILE.txt"), "w")
    if file == nil then
        return true
    end
    file:write("profile=" .. profile.id .. "\n")
    file:write("entryPath=" .. profile.entryPath .. "\n")
    file:write("startScript=" .. profile.startScript .. "\n")
    file:write("revision=" .. trim(revision or "") .. "\n")
    file:write("repository=" .. UPSTREAM_URL .. "\n")
    file:close()
    return true
end

local function write_manifest(root, profile, source_kind, revision, local_path)
    local path = manifest_path(root, profile.id)
    return write_json_object(path, {
        id = profile.id,
        source = source_kind,
        revision = trim(revision or ""),
        localVersion = source_kind == "local" and first_nonempty(trim(revision or ""), "local") or "",
        summary = profile.summary,
        description = profile.description,
        homepage = profile.homepage,
        repository = UPSTREAM_URL,
        entryPath = profile.entryPath,
        startScript = profile.startScript,
        localPath = trim(local_path or ""),
    })
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
    return { "language", "package-manager", "oberon" }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "filesystem", "network" },
        ecosystemScopes = { "oberon", "a2" },
        writeScopes = {
            { kind = "plugin-subpath", path = ".reqpack-data" },
        },
        networkScopes = { "gitlab.inf.ethz.ch" },
        privilegeLevel = "user",
        purlType = "generic",
        versionComparatorProfile = "lexicographic",
    }
end

function plugin.resolvePackage(context, package)
    local name = package
    if type(package) == "table" then
        name = package_name(package)
    end
    local profile = profile_by_name(name)
    if profile == nil then
        return nil
    end
    local root = data_root(context, type(package) == "table" and { package } or nil)
    local cached = read_repository_cache(root)
    local latest_revision = cached and trim(cached.revision) or ""
    local manifest = installed_manifest(root, profile.id)
    return profile_item(profile, manifest, latest_revision)
end

function plugin.getMissingPackages(packages)
    local root = data_root(nil, packages)
    local installed = installed_manifest_lookup(root)
    local missing = {}
    for _, pkg in ipairs(packages or {}) do
        local profile = profile_by_name(package_name(pkg))
        if profile ~= nil then
            local present = installed[profile.id] ~= nil
            local action = package_action(pkg)
            if action == "remove" then
                if present then
                    missing[#missing + 1] = pkg
                end
            elseif action == "update" then
                if present then
                    missing[#missing + 1] = pkg
                end
            else
                if not present then
                    missing[#missing + 1] = pkg
                end
            end
        else
            missing[#missing + 1] = pkg
        end
    end
    return missing
end

function plugin.install(context, packages)
    local requested = requested_packages(context, packages)
    if #requested == 0 then
        return true
    end

    local root = data_root(context, requested)
    local cached = read_repository_cache(root)
    local latest_revision = cached and trim(cached.revision) or ""
    local revision_error = nil
    if latest_revision == "" then
        latest_revision, revision_error = get_remote_revision(context, root, false, true)
    end
    if latest_revision == nil then
        return fail_action(context, revision_error)
    end

    begin_step(context, "Installing A2 profiles")

    for _, pkg in ipairs(requested) do
        local profile = profile_by_name(package_name(pkg))
        if profile == nil then
            local message = "unknown A2 profile: " .. package_name(pkg)
            return fail_action(context, message, { name = package_name(pkg), packageType = PACKAGE_TYPE })
        end

        local payload = payload_root(root, profile.id)
        local ok, dir_error = ensure_dirs(context, { cache_root(root), payload })
        if not ok then
            log_warn(context, dir_error)
        end

        local marker_ok, marker_error = write_remote_payload_marker(payload, profile, latest_revision)
        if not marker_ok then
            log_warn(context, marker_error)
        end

        local manifest_ok, manifest_error = write_manifest(root, profile, "remote", latest_revision, "")
        if not manifest_ok then
            log_warn(context, manifest_error)
        end

        emit_event(context, "installed", profile_item(profile, installed_manifest(root, profile.id), latest_revision))
    end

    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.installLocal(context, path)
    local request = request_object(context)
    local local_path = trim(expand_runtime_placeholders(path or (context and context.localPath) or (request and request.localPath) or ""))
    if local_path == "" then
        return fail_action(context, "missing local A2 path")
    end

    local profile_id = infer_local_profile_id(local_path)
    if profile_id == nil then
        return fail_action(context, "could not infer A2 profile from local path: " .. local_path)
    end

    local profile = PROFILE_INDEX[profile_id]
    local root = data_root(context)
    local payload = payload_root(root, profile.id)

    begin_step(context, "Installing local A2 profile")

    local ok, dir_error = ensure_dirs(context, { payload })
    if not ok then
        log_warn(context, dir_error)
    end

    local copied = false
    if not lower(local_path):match("%.zip$") and not lower(local_path):match("%.tar%.gz$") and not lower(local_path):match("%.tgz$") then
        local copy_ok, copy_error = copy_directory(context, local_path, payload)
        if not copy_ok then
            return fail_action(context, copy_error)
        end
        copied = true
    elseif directory_exists(context, local_path) then
        local copy_ok, copy_error = copy_directory(context, local_path, payload)
        if not copy_ok then
            return fail_action(context, copy_error)
        end
        copied = true
    else
        local extract_ok, extract_error = extract_archive(context, local_path, payload)
        if not extract_ok then
            return fail_action(context, extract_error)
        end
        copied = true
    end

    if not copied then
        return fail_action(context, "failed to stage local A2 payload")
    end

    local manifest_ok, manifest_error = write_manifest(root, profile, "local", basename(local_path), local_path)
    if not manifest_ok then
        log_warn(context, manifest_error)
    end

    emit_event(context, "installed", profile_item(profile, installed_manifest(root, profile.id), ""))
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.remove(context, packages)
    local requested = requested_packages(context, packages)
    if #requested == 0 then
        return true
    end

    local root = data_root(context, requested)
    begin_step(context, "Removing A2 profiles")

    for _, pkg in ipairs(requested) do
        local profile = profile_by_name(package_name(pkg))
        if profile ~= nil and installed_manifest(root, profile.id) ~= nil then
            local ok, remove_error = remove_path(context, join_path(installs_root(root), profile.id))
            if not ok then
                tx_failed(context, remove_error)
                return false
            end
            emit_event(context, "deleted", {
                type = "package",
                name = profile.id,
                packageId = PLUGIN_ID .. "/" .. profile.id,
                packageType = PACKAGE_TYPE,
            })
        end
    end

    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.update(context, packages)
    local requested = requested_packages(context, packages)
    if #requested == 0 then
        return true
    end

    local root = data_root(context, requested)
    local cached = read_repository_cache(root)
    local latest_revision = cached and trim(cached.revision) or ""
    local revision_error = nil
    if latest_revision == "" then
        latest_revision, revision_error = get_remote_revision(context, root, has_refresh(context, requested), true)
    end
    if latest_revision == nil then
        return fail_action(context, revision_error)
    end

    begin_step(context, "Updating A2 profiles")

    for _, pkg in ipairs(requested) do
        local profile = profile_by_name(package_name(pkg))
        if profile ~= nil then
            local manifest = installed_manifest(root, profile.id)
            if manifest ~= nil then
                if trim(manifest.source) == "local" then
                    return fail_action(context, "update unsupported for local A2 install: " .. profile.id)
                end
                if trim(manifest.revision) ~= latest_revision then
                    local payload = payload_root(root, profile.id)
                    local remove_ok, remove_error = remove_path(context, payload)
                    if not remove_ok then
                        return fail_action(context, remove_error)
                    end
                    local dir_ok, dir_error = ensure_dirs(context, { payload })
                    if not dir_ok then
                        log_warn(context, dir_error)
                    end
                    local marker_ok, marker_error = write_remote_payload_marker(payload, profile, latest_revision)
                    if not marker_ok then
                        log_warn(context, marker_error)
                    end
                    local manifest_ok, manifest_error = write_manifest(root, profile, "remote", latest_revision, "")
                    if not manifest_ok then
                        log_warn(context, manifest_error)
                    end
                    emit_event(context, "updated", profile_item(profile, installed_manifest(root, profile.id), latest_revision))
                end
            end
        end
    end

    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.list(context)
    local root = data_root(context)
    local items = {}
    local manifests = installed_manifest_lookup(root)
    local latest_revision = read_repository_cache(root)
    local cached_revision = latest_revision and trim(latest_revision.revision) or ""

    for package_id, manifest in pairs(manifests) do
        if PROFILE_INDEX[package_id] ~= nil then
            items[#items + 1] = profile_item(PROFILE_INDEX[package_id], manifest, cached_revision)
        else
            items[#items + 1] = local_profile_item(package_id, manifest, cached_revision)
        end
    end

    table.sort(items, function(left, right)
        return tostring(left.name) < tostring(right.name)
    end)

    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local root = data_root(context)
    local latest_revision, revision_error = get_remote_revision(context, root, has_refresh(context), true)
    if latest_revision == nil then
        log_warn(context, revision_error)
        emit_event(context, "outdated", {})
        return {}
    end

    local results = {}
    for package_id, manifest in pairs(installed_manifest_lookup(root)) do
        if trim(manifest.source) == "remote" and trim(manifest.revision) ~= "" and trim(manifest.revision) ~= latest_revision then
            local profile = PROFILE_INDEX[package_id]
            if profile ~= nil then
                results[#results + 1] = profile_item(profile, manifest, latest_revision)
            end
        end
    end

    table.sort(results, function(left, right)
        return tostring(left.name) < tostring(right.name)
    end)

    emit_event(context, "outdated", results)
    return results
end

function plugin.search(context, prompt)
    local root = data_root(context)
    local query = lower(search_prompt(context, prompt))
    local revision = ""
    local cached = read_repository_cache(root)
    if cached ~= nil then
        revision = trim(cached.revision)
    else
        local latest = get_remote_revision(context, root, false, true)
        revision = trim(latest or "")
    end

    local manifests = installed_manifest_lookup(root)
    local results = {}

    for _, profile in ipairs(PROFILES) do
        local haystack = table.concat({
            lower(profile.id),
            lower(profile.summary),
            lower(profile.description),
            lower(table.concat(profile.aliases or {}, " ")),
        }, " ")
        if query == "" or haystack:find(query, 1, true) ~= nil then
            results[#results + 1] = profile_item(profile, manifests[profile.id], revision)
        end
    end

    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local root = data_root(context)
    local profile = profile_by_name(search_prompt(context, name))
    if profile == nil then
        emit_event(context, "unavailable", { name = search_prompt(context, name), packageType = PACKAGE_TYPE })
        return {}
    end

    local latest_revision = get_remote_revision(context, root, false, true)
    local item = profile_item(profile, installed_manifest(root, profile.id), latest_revision or "")
    emit_event(context, "informed", item)
    return item
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

return plugin
