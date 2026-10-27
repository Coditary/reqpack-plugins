plugin = {}

local PLUGIN_NAME = "Leiningen"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "lein"

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

local function non_empty(value)
    local cleaned = trim(value)
    if cleaned == "" then
        return nil
    end
    return cleaned
end

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        local cleaned = non_empty(value)
        if cleaned ~= nil then
            return cleaned
        end
    end
    return nil
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

local function basename(path)
    local cleaned = trim(path):gsub("[/\\]+$", "")
    return cleaned:match("[^/\\]+$") or cleaned
end

local function dirname(path)
    return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
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

local function is_success(result)
    return type(result) == "table" and (result.success == true or result.exitCode == 0)
end

local function read_file(context, path)
    return exec_run(context, "cat " .. shell_quote(path))
end

local function write_file(context, path, content)
    local dir = dirname(path) or "."
    return exec_run(context, "mkdir -p " .. shell_quote(dir) .. " && printf %s " .. shell_quote(content) .. " > " .. shell_quote(path))
end

local function path_exists(context, path)
    return is_success(exec_run(context, "test -e " .. shell_quote(path)))
end

local function command_exists(binary)
    return is_success(exec_run(nil, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function list_flags(object)
    local result = {}
    for _, item in ipairs(sequence_values(read_field(object, "flags"))) do
        local cleaned = trim(item)
        if cleaned ~= "" then
            result[#result + 1] = cleaned
        end
    end
    return result
end

local function request_object(context)
    return read_field(context, "request")
end

local function request_packages(context, fallback)
    local packages = read_field(request_object(context), "packages") or read_field(context, "packages") or fallback or {}
    return sequence_values(packages)
end

local function request_prompt(context, fallback)
    return first_nonempty(fallback, read_field(request_object(context), "prompt"), read_field(context, "prompt")) or ""
end

local function request_local_path(context, fallback)
    return first_nonempty(fallback, read_field(request_object(context), "localPath"), read_field(request_object(context), "path"), read_field(context, "localPath"), read_field(context, "path"))
end

local function collect_flags(context, packages)
    local result = {}
    local seen = {}
    local function add_from(object)
        for _, flag in ipairs(list_flags(object)) do
            if not seen[flag] then
                seen[flag] = true
                result[#result + 1] = flag
            end
        end
    end
    add_from(context)
    add_from(request_object(context))
    for _, package in ipairs(packages or {}) do
        add_from(package)
    end
    return result
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

local function home_dir()
    local getenv = os ~= nil and type(os.getenv) == "function" and os.getenv or nil
    return first_nonempty(getenv and getenv("HOME") or nil, "/home/test")
end

local function repo_root(flags)
    return first_nonempty(flag_value(flags, "repo-root"), join_path(home_dir(), ".m2", "repository"))
end

local function cache_root(flags)
    return first_nonempty(flag_value(flags, "cache-root"), join_path(home_dir(), ".cache", "reqpack", "leiningen"))
end

local function normalize_coordinate(name)
    local cleaned = trim(name)
    if cleaned == "" then
        return nil
    end
    cleaned = cleaned:gsub(":", "/")
    cleaned = cleaned:gsub("^/+", ""):gsub("/+$", "")
    local left, right = cleaned:match("^([^/]+)/([^/]+)$")
    if left ~= nil and right ~= nil then
        return left .. "/" .. right
    end
    if cleaned:match("^[^/]+$") then
        return cleaned
    end
    return nil
end

local function coordinate_parts(name)
    local coordinate = normalize_coordinate(name)
    if coordinate == nil then
        return nil, nil, nil
    end
    local namespace, artifact = coordinate:match("^([^/]+)/([^/]+)$")
    if namespace == nil then
        namespace = coordinate
        artifact = coordinate
        coordinate = namespace .. "/" .. artifact
    end
    return coordinate, namespace, artifact
end

local function coordinate_repo_path(root, namespace, artifact)
    return join_path(root, namespace:gsub("%.", "/"), artifact)
end

local function version_dir_path(root, namespace, artifact, version)
    return join_path(coordinate_repo_path(root, namespace, artifact), version)
end

local function package_version(pkg)
    return first_nonempty(pkg and pkg.version, pkg and pkg.requestedVersion)
end

local function package_name(pkg)
    return first_nonempty(pkg and pkg.name, pkg and pkg.packageId)
end

local function local_path_from_context(context, packages)
    return first_nonempty(request_local_path(context), packages and packages[1] and packages[1].localPath, packages and packages[1] and packages[1].path)
end

local function parse_search_output(output)
    local items = {}
    local pending = nil
    for _, line in ipairs(split_lines(output)) do
        local bracket_body, version = line:match('^%[([^%s]+)%s+"([^"]+)"%]$')
        if bracket_body ~= nil then
            local coordinate, namespace, artifact = coordinate_parts(bracket_body)
            pending = {
                name = coordinate or bracket_body,
                namespace = namespace,
                packageType = "jar",
                version = version,
                installed = false,
                status = "available",
            }
            items[#items + 1] = pending
        elseif pending ~= nil and line:match("^%s+") then
            local description = trim(line)
            if description ~= "" then
                pending.summary = description
                pending.description = description
            end
            pending = nil
        else
            pending = nil
        end
    end
    return items
end

local function load_search_cache(context, flags, prompt)
    local cache_file = join_path(cache_root(flags), "search", trim(prompt):gsub("[^A-Za-z0-9._-]", "_") .. ".txt")
    local result = read_file(context, cache_file)
    if is_success(result) then
        return parse_search_output(result.stdout or "")
    end
    return nil
end

local function save_search_cache(context, flags, prompt, output)
    local cache_file = join_path(cache_root(flags), "search", trim(prompt):gsub("[^A-Za-z0-9._-]", "_") .. ".txt")
    write_file(context, cache_file, output or "")
end

local function list_versions_in_artifact(context, root, namespace, artifact)
    local path = coordinate_repo_path(root, namespace, artifact)
    local result = exec_run(context, "ls -1 " .. shell_quote(path))
    if not is_success(result) then
        return {}
    end
    local versions = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local version = trim(line)
        if version ~= "" then
            versions[#versions + 1] = version
        end
    end
    table.sort(versions)
    return versions
end

local function artifact_entry(root, namespace, artifact, version, has_pom, has_jar)
    return {
        name = namespace .. "/" .. artifact,
        namespace = namespace,
        packageType = "jar",
        version = version,
        installed = true,
        status = "installed",
        extraFields = {
            repoRoot = root,
            hasPom = has_pom,
            hasJar = has_jar,
        },
    }
end

local function inspect_version_dir(context, root, namespace, artifact, version)
    local path = version_dir_path(root, namespace, artifact, version)
    local pom = join_path(path, artifact .. "-" .. version .. ".pom")
    local jar = join_path(path, artifact .. "-" .. version .. ".jar")
    local has_pom = path_exists(context, pom)
    local has_jar = path_exists(context, jar)
    if not has_pom and not has_jar then
        return nil
    end
    return artifact_entry(root, namespace, artifact, version, has_pom, has_jar)
end

local function collect_exact_installed(context, flags, query)
    local coordinate, namespace, artifact = coordinate_parts(query)
    if coordinate == nil then
        return {}
    end
    local root = repo_root(flags)
    local versions = list_versions_in_artifact(context, root, namespace, artifact)
    local items = {}
    for _, version in ipairs(versions) do
        local item = inspect_version_dir(context, root, namespace, artifact, version)
        if item ~= nil then
            items[#items + 1] = item
        end
    end
    return items
end

local function split_tab(line)
    local fields = {}
    for field in (tostring(line or "") .. "\t"):gmatch("(.-)\t") do
        fields[#fields + 1] = field
    end
    return fields
end

local function collect_list_from_index(context, flags)
    local index_file = join_path(cache_root(flags), "state", "installed.tsv")
    local result = read_file(context, index_file)
    if not is_success(result) then
        return nil
    end
    local items = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local fields = split_tab(line)
        if #fields >= 5 then
            items[#items + 1] = {
                name = non_empty(fields[1]),
                namespace = non_empty(fields[2]),
                packageType = "jar",
                version = non_empty(fields[3]),
                installed = true,
                status = "installed",
                extraFields = {
                    repoRoot = non_empty(fields[4]),
                    hasPom = fields[5] == "true",
                    hasJar = fields[6] == "true",
                },
            }
        end
    end
    return items
end

local function persist_list_index(context, flags, items)
    local lines = {}
    for _, item in ipairs(items or {}) do
        local extra = type(item.extraFields) == "table" and item.extraFields or {}
        lines[#lines + 1] = table.concat({
            item.name or "",
            item.namespace or "",
            item.version or "",
            extra.repoRoot or "",
            extra.hasPom and "true" or "false",
            extra.hasJar and "true" or "false",
        }, "\t")
    end
    write_file(context, join_path(cache_root(flags), "state", "installed.tsv"), table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
end

local function collect_list_from_repo(context, flags)
    local root = repo_root(flags)
    local index_result = exec_run(context, "find " .. shell_quote(root) .. " -type f \\( -name '*.pom' -o -name '*.jar' \\)")
    if not is_success(index_result) then
        return {}
    end

    local seen = {}
    local items = {}
    for _, line in ipairs(split_lines(index_result.stdout)) do
        local path = trim(line)
        local root_prefix = root:gsub("([%%%+%-%*%?%[%]%^%$%(%)%.])", "%%%1")
        local rel = path:match("^" .. root_prefix .. "/(.+)$")
        if rel ~= nil then
            local parts = {}
            for part in rel:gmatch("[^/]+") do
                parts[#parts + 1] = part
            end
            if #parts >= 4 then
                local filename = parts[#parts]
                local version = parts[#parts - 1]
                local artifact = parts[#parts - 2]
                local namespace = table.concat(parts, "/", 1, #parts - 3):gsub("/", ".")
                if filename == artifact .. "-" .. version .. ".pom" or filename == artifact .. "-" .. version .. ".jar" then
                    local key = namespace .. "/" .. artifact .. ":" .. version
                    if not seen[key] then
                        local item = inspect_version_dir(context, root, namespace, artifact, version)
                        if item ~= nil then
                            seen[key] = true
                            items[#items + 1] = item
                        end
                    end
                end
            end
        end
    end
    table.sort(items, function(left, right)
        if left.name == right.name then
            return (left.version or "") < (right.version or "")
        end
        return (left.name or "") < (right.name or "")
    end)
    persist_list_index(context, flags, items)
    return items
end

local function collect_list_items(context, flags)
    local cached = collect_list_from_index(context, flags)
    if cached ~= nil and #cached > 0 then
        return cached
    end
    return collect_list_from_repo(context, flags)
end

local function exact_remote_match(items, query)
    local wanted = normalize_coordinate(query)
    if wanted == nil then
        return nil
    end
    for _, item in ipairs(items or {}) do
        if normalize_coordinate(item.name) == wanted then
            return item
        end
    end
    return nil
end

local function package_error(context, message, unavailable_payload)
    tx_failed(context, message)
    emit_event(context, "failed", message)
    if unavailable_payload ~= nil then
        emit_event(context, "unavailable", unavailable_payload)
    end
    return false
end

local function ensure_available(context)
    if command_exists(REQUIRED_BINARY) then
        return true, nil
    end
    return false, "lein binary not found"
end

local function ensure_localrepo_available(context)
    local result = exec_run(context, "lein help localrepo")
    if is_success(result) then
        return true
    end
    return false
end

plugin.fileExtensions = { ".jar" }

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
    return { "Development", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end
    local flags = collect_flags(nil, packages)
    local items = collect_list_items(nil, flags)
    if items == nil then
        return packages
    end
    local installed = {}
    for _, item in ipairs(items) do
        installed[(item.name or "") .. ":" .. (item.version or "")] = true
        installed[item.name or ""] = true
    end
    local filtered = {}
    for _, pkg in ipairs(packages) do
        local action = lower(pkg and pkg.action or "install")
        local name = normalize_coordinate(package_name(pkg) or "")
        local version = package_version(pkg) or ""
        if action == "remove" then
            if installed[(name or "") .. ":" .. version] or installed[name or ""] then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "update" then
            filtered[#filtered + 1] = pkg
        elseif pkg.localPath or pkg.path then
            if not installed[(name or "") .. ":" .. version] then
                filtered[#filtered + 1] = pkg
            end
        elseif not installed[(name or "") .. ":" .. version] then
            filtered[#filtered + 1] = pkg
        end
    end
    return filtered
end

function plugin.install(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "lein-not-installed" })
    end

    packages = request_packages(context, packages)
    local local_path = local_path_from_context(context, packages)
    if local_path ~= nil then
        return plugin.installLocal(context, local_path)
    end

    return package_error(
        context,
        "leiningen remote installs are not supported; use installLocal or project-specific dependency management",
        { reason = "remote-install-unsupported" }
    )
end

function plugin.installLocal(context, path)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { path = tostring(path or ""), reason = "lein-not-installed" })
    end

    local cleaned_path = trim(path)
    if cleaned_path == "" or not lower(cleaned_path):match("%.jar$") then
        return package_error(context, "installLocal only supports local .jar artifacts", { path = cleaned_path, reason = "local-install-unsupported" })
    end

    if not ensure_localrepo_available(context) then
        return package_error(context, "lein localrepo task not available; install lein-localrepo first", { path = cleaned_path, reason = "missing-localrepo-task" })
    end

    local packages = request_packages(context, {})
    local flags = collect_flags(context, packages)
    local pkg = packages and packages[1] or {}
    local coord = normalize_coordinate(first_nonempty(package_name(pkg), flag_value(flags, "coord")))
    local version = first_nonempty(package_version(pkg), flag_value(flags, "version"))
    if coord == nil or version == nil then
        return package_error(context, "installLocal requires package coordinate and version", { path = cleaned_path, reason = "missing-metadata" })
    end

    begin_step(context, "install local Leiningen artifact")
    local command = "lein localrepo install " .. shell_quote(cleaned_path) .. " " .. shell_quote(coord) .. " " .. shell_quote(version)
    local result = exec_run(context, command)
    if not is_success(result) then
        return package_error(context, first_nonempty(result.stderr, result.stdout, "lein local install failed"))
    end

    emit_event(context, "installed", {
        localTarget = true,
        path = cleaned_path,
        name = coord,
        version = version,
    })
    tx_success(context)
    emit_event(context, "success", result.stdout or "")
    return true
end

function plugin.remove(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "lein-not-installed" })
    end
    packages = request_packages(context, packages)
    if packages == nil or #packages == 0 then
        tx_success(context)
        emit_event(context, "success", "")
        return true
    end

    local flags = collect_flags(context, packages)
    local root = repo_root(flags)
    begin_step(context, "remove Leiningen artifacts")
    for _, pkg in ipairs(packages) do
        local coordinate, namespace, artifact = coordinate_parts(package_name(pkg) or "")
        if coordinate == nil then
            return package_error(context, "invalid Maven coordinate")
        end
        local target = package_version(pkg) and version_dir_path(root, namespace, artifact, package_version(pkg)) or coordinate_repo_path(root, namespace, artifact)
        local result = exec_run(context, "rm -rf " .. shell_quote(target))
        if not is_success(result) then
            return package_error(context, first_nonempty(result.stderr, result.stdout, "leiningen remove failed"))
        end
    end
    emit_event(context, "deleted", packages)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.update(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message, { reason = "lein-not-installed" })
    end
    packages = request_packages(context, packages)
    if packages == nil or #packages == 0 then
        emit_event(context, "updated", {})
        tx_success(context)
        emit_event(context, "success", "")
        return true
    end
    return package_error(context, "leiningen update is not supported for arbitrary artifacts", { reason = "update-unsupported" })
end

function plugin.list(context)
    local flags = collect_flags(context, nil)
    local items = collect_list_items(context, flags)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items = {}
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local available, message = ensure_available(context)
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "searched", items)
        return items
    end

    local query = trim(request_prompt(context, prompt))
    if query == "" then
        local items = {}
        emit_event(context, "searched", items)
        return items
    end

    local flags = collect_flags(context, nil)
    local cached = load_search_cache(context, flags, query)
    if cached ~= nil and #cached > 0 then
        emit_event(context, "searched", cached)
        return cached
    end

    local result = exec_run(context, "lein search " .. shell_quote(query))
    if not is_success(result) then
        log_warn(context, first_nonempty(result.stderr, result.stdout, "lein search failed"))
        local items = {}
        emit_event(context, "searched", items)
        return items
    end
    save_search_cache(context, flags, query, result.stdout or "")
    local items = parse_search_output(result.stdout or "")
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = trim(request_prompt(context, name))
    if query == "" then
        local item = {}
        emit_event(context, "informed", item)
        return item
    end

    local flags = collect_flags(context, nil)
    local installed = collect_exact_installed(context, flags, query)
    if #installed > 0 then
        local item = installed[#installed]
        emit_event(context, "informed", item)
        return item
    end

    local search_items = plugin.search(context, query)
    local match = exact_remote_match(search_items, query)
    if match ~= nil then
        emit_event(context, "informed", match)
        return match
    end

    local item = {}
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == nil then
        return nil
    end
    local item = plugin.info(context, name)
    if type(item) ~= "table" or next(item) == nil then
        return nil
    end
    return item
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "clojure", "leiningen", "maven" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".m2/repository" },
            { kind = "user-home-subpath", value = ".cache/reqpack/leiningen" },
        },
        networkScopes = {
            { host = "search.maven.org", scheme = "https", pathPrefix = "/" },
            { host = "clojars.org", scheme = "https", pathPrefix = "/" },
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
