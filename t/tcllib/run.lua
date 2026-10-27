plugin = {}

local PLUGIN_ID = "tcllib"
local PLUGIN_NAME = "Tcllib"
local PLUGIN_VERSION = "0.1.0"
local DEFAULT_HOME_SUFFIX = ".cache/reqpack/tcllib"
local TAGS_API_URL = "https://api.github.com/repos/tcltk/tcllib/tags?per_page=100"
local ARCHIVE_URL_PREFIX = "https://codeload.github.com/tcltk/tcllib/tar.gz/refs/tags/"
local REQUIRED_LOCAL_BINARIES = { "tclsh" }
local REQUIRED_REMOTE_BINARIES = { "tclsh", "curl", "tar" }

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return tostring(value or ""):lower()
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

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
end

local function merge_tables(left, right)
    local merged = shallow_copy(type(left) == "table" and left or {})
    for key, value in pairs(type(right) == "table" and right or {}) do
        merged[key] = value
    end
    if next(merged) == nil then
        return nil
    end
    return merged
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

local function normalize_exec_result(...)
    local result = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
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
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return normalize_exec_result(context.exec.run(command))
    end
    if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
        return normalize_exec_result(reqpack.exec.run(command))
    end
    return {
        success = false,
        stdout = "",
        stderr = "missing ReqPack exec runner",
        exitCode = 127,
    }
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

local function read_file(path)
    local handle = io.open(path, "rb")
    if handle == nil then
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function dirname(path)
    local cleaned = trim(path)
    local parent = cleaned:match("^(.*)[/\\][^/\\]+$")
    return parent or "."
end

local function read_text_file(context, path)
    local content = read_file(path)
    if content ~= nil then
        return content
    end
    if context == nil then
        return nil
    end
    local result = exec_run(context, "cat " .. shell_quote(path))
    if result ~= nil and result.success == true then
        return result.stdout
    end
    return nil
end

local function path_exists(context, path)
    local content = read_file(path)
    if content ~= nil then
        return true
    end
    if context == nil then
        return false
    end
    return exec_run(context, "test -e " .. shell_quote(path)).success == true
end

local function write_text_file(context, path, content)
    local handle = io.open(path, "wb")
    if handle == nil then
        if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
            return true
        end
        return false
    end
    handle:write(content or "")
    handle:close()
    return true
end

local function object_flags(value)
    local raw = read_field(value, "flags")
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

local function collect_flags(context, package)
    local flags = {}
    local seen = {}
    local function collect_from(value)
        for _, flag in ipairs(object_flags(value)) do
            local cleaned = trim(flag)
            if cleaned ~= "" and not seen[cleaned] then
                seen[cleaned] = true
                flags[#flags + 1] = cleaned
            end
        end
    end
    collect_from(context)
    collect_from(context ~= nil and context.request or nil)
    collect_from(package)
    return flags
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

local function command_exists(context, binary)
    return exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1").success == true
end

local function home_directory()
    local home = trim((os ~= nil and type(os.getenv) == "function") and (os.getenv("HOME") or "") or "")
    if home ~= "" then
        return home
    end
    return nil
end

local function default_cache_root()
    local home = home_directory()
    if home ~= nil then
        return join_path(home, DEFAULT_HOME_SUFFIX)
    end
    return join_path(".reqpack-data", PLUGIN_ID)
end

local function package_request(value, maybe_version)
    local structured = type(value) == "table" or type(value) == "userdata"
    local raw_name = trim(structured and (read_field(value, "name") or read_field(value, "packageId") or "") or value or "")
    local raw_version = trim(structured and (read_field(value, "version") or "") or maybe_version or "")

    if raw_name:find("@", 1, true) ~= nil and raw_version == "" then
        local before, after = raw_name:match("^(.-)@(.+)$")
        raw_name = trim(before or "")
        raw_version = trim(after or "")
    end

    if raw_name == "" and raw_version == "" then
        raw_name = "tcllib"
    elseif raw_name ~= "" and raw_name:match("^%d") and raw_version == "" then
        raw_version = raw_name
        raw_name = "tcllib"
    elseif raw_name == "" then
        raw_name = "tcllib"
    end

    return {
        name = raw_name,
        version = raw_version,
    }
end

local function request_name(context, explicit_name)
    local request = read_field(context, "request")
    return trim(
        explicit_name
        or read_field(context, "name")
        or read_field(request, "name")
        or read_field(context, "prompt")
        or read_field(request, "prompt")
        or ""
    )
end

local function request_local_path(context, explicit_path)
    local request = read_field(context, "request")
    return trim(
        explicit_path
        or read_field(context, "localPath")
        or read_field(request, "localPath")
        or read_field(context, "path")
        or read_field(request, "path")
        or ""
    )
end

local function managed_paths(root, version)
    local cleaned_version = trim(version)
    local current_root = join_path(root, "current")
    return {
        root = root,
        archives = join_path(root, "archives"),
        sources = join_path(root, "sources"),
        state = join_path(root, "state"),
        manifest = join_path(root, "state", "current.txt"),
        currentRoot = current_root,
        pkgPath = join_path(current_root, "lib", "tcllib" .. cleaned_version),
        examplePath = join_path(current_root, "examples"),
        htmlPath = join_path(current_root, "doc", "html"),
        nroffPath = join_path(current_root, "man", "mann"),
    }
end

local function parse_manifest_text(text)
    if text == nil or text == "" then
        return nil
    end
    local manifest = {}
    for _, line in ipairs(split_lines(text)) do
        local key, value = line:match("^([^=]+)=(.*)$")
        if key ~= nil then
            manifest[trim(key)] = trim(value)
        end
    end
    if trim(manifest.version or "") == "" then
        return nil
    end
    return manifest
end

local function read_manifest(context, path)
    return parse_manifest_text(read_text_file(context, path))
end

local function write_manifest(context, path, manifest)
    local lines = {
        "name=" .. trim(manifest.name or "tcllib"),
        "version=" .. trim(manifest.version or ""),
        "tag=" .. trim(manifest.tag or ""),
        "origin=" .. trim(manifest.origin or "remote"),
        "root=" .. trim(manifest.root or ""),
        "pkgPath=" .. trim(manifest.pkgPath or ""),
        "examplePath=" .. trim(manifest.examplePath or ""),
        "htmlPath=" .. trim(manifest.htmlPath or ""),
        "nroffPath=" .. trim(manifest.nroffPath or ""),
        "sourcePath=" .. trim(manifest.sourcePath or ""),
    }
    return write_text_file(context, path, table.concat(lines, "\n") .. "\n")
end

local function current_manifest_for_root(context, root)
    return read_manifest(context, join_path(root, "state", "current.txt"))
end

local function derive_root(context, package)
    local flags = collect_flags(context, package)
    local overridden = trim(flag_value(flags, "cache-root") or "")
    if overridden ~= "" then
        return overridden
    end
    return default_cache_root()
end

local function parse_release_version(tag)
    local body = trim(tag or "")
    body = body:match("^tcllib[-_](.+)$")
    if body == nil or body == "" then
        return nil
    end
    body = body:gsub("_", "-")
    local parts = {}
    for part in body:gmatch("[^%-]+") do
        parts[#parts + 1] = part
    end
    if #parts == 0 then
        return nil
    end
    local numbers = {}
    local suffix = {}
    local collecting_numbers = true
    for _, part in ipairs(parts) do
        if collecting_numbers and part:match("^%d+$") then
            numbers[#numbers + 1] = part
        else
            collecting_numbers = false
            suffix[#suffix + 1] = part
        end
    end
    if #numbers == 0 then
        return nil
    end
    local version = table.concat(numbers, ".")
    if #suffix > 0 then
        version = version .. "-" .. table.concat(suffix, "-")
    end
    return version
end

local function version_to_tag(version)
    local cleaned = trim(version)
    if cleaned == "" then
        return nil
    end
    local base, suffix = cleaned:match("^([^%-]+)%-(.+)$")
    if base == nil then
        base = cleaned
    end
    base = base:gsub("%.", "-")
    if suffix ~= nil and suffix ~= "" then
        return "tcllib-" .. base .. "-" .. suffix
    end
    return "tcllib-" .. base
end

local function version_tokens(version)
    local tokens = {}
    local cleaned = tostring(version or "")
    local base, suffix = cleaned:match("^([^%-]+)%-(.+)$")
    if base == nil then
        base = cleaned
    end
    for piece in tostring(base or ""):gmatch("[^%.]+") do
        if piece:match("^%d+$") then
            tokens[#tokens + 1] = tonumber(piece)
        elseif piece ~= "" then
            tokens[#tokens + 1] = lower(piece)
        end
    end
    if suffix ~= nil and suffix ~= "" then
        tokens[#tokens + 1] = lower(suffix)
    end
    return tokens
end

local function compare_versions(left, right)
    local a = version_tokens(left)
    local b = version_tokens(right)
    local count = math.max(#a, #b)
    for index = 1, count do
        local av = a[index]
        local bv = b[index]
        if av == nil and bv == nil then
            return 0
        elseif av == nil then
            if type(bv) == "string" then
                return 1
            end
            return -1
        elseif bv == nil then
            if type(av) == "string" then
                return -1
            end
            return 1
        elseif type(av) == type(bv) then
            if av ~= bv then
                if av < bv then
                    return -1
                end
                return 1
            end
        elseif type(av) == "number" then
            return 1
        else
            return -1
        end
    end
    return 0
end

local function release_item(version, tag, installed_manifest)
    local item = {
        name = "tcllib",
        packageId = "tcllib@" .. version,
        version = version,
        summary = "Tcl Standard Library release " .. version,
        description = "Tcllib release managed through bundled installer.tcl workflow.",
        homepage = "https://core.tcl-lang.org/tcllib",
        packageType = "library-collection",
        source = ARCHIVE_URL_PREFIX .. tag,
        extraFields = {
            tag = tag,
        },
    }
    if installed_manifest ~= nil and trim(installed_manifest.version or "") == version then
        item.installed = true
        item.status = "installed"
        item.extraFields = merge_tables(item.extraFields, {
            origin = trim(installed_manifest.origin or "remote"),
            pkgPath = trim(installed_manifest.pkgPath or ""),
            examplePath = trim(installed_manifest.examplePath or ""),
            htmlPath = trim(installed_manifest.htmlPath or ""),
            nroffPath = trim(installed_manifest.nroffPath or ""),
            sourcePath = trim(installed_manifest.sourcePath or ""),
        })
    else
        item.status = "available"
    end
    return item
end

local function installed_item_from_manifest(manifest)
    if manifest == nil then
        return nil
    end
    return {
        name = trim(manifest.name or "tcllib"),
        packageId = "tcllib@" .. trim(manifest.version or ""),
        version = trim(manifest.version or ""),
        summary = "Tcl Standard Library managed install",
        description = "ReqPack-managed Tcllib installation.",
        packageType = "library-collection",
        installed = true,
        status = "installed",
        extraFields = {
            tag = trim(manifest.tag or ""),
            origin = trim(manifest.origin or "remote"),
            root = trim(manifest.root or ""),
            pkgPath = trim(manifest.pkgPath or ""),
            examplePath = trim(manifest.examplePath or ""),
            htmlPath = trim(manifest.htmlPath or ""),
            nroffPath = trim(manifest.nroffPath or ""),
            sourcePath = trim(manifest.sourcePath or ""),
        },
    }
end

local function fetch_remote_releases(context)
    if not command_exists(context, "curl") then
        return nil, "missing required binary: curl"
    end
    local result = exec_run(context, "curl -fsSL " .. shell_quote(TAGS_API_URL))
    if not result.success then
        return nil, trim(result.stderr) ~= "" and trim(result.stderr) or "failed to fetch remote Tcllib tags"
    end

    local by_version = {}
    local ordered = {}
    for name in tostring(result.stdout or ""):gmatch('"name"%s*:%s*"([^"]+)"') do
        local version = parse_release_version(name)
        if version ~= nil then
            local current = by_version[version]
            if current == nil or (name:find("_", 1, true) == nil and current.tag:find("_", 1, true) ~= nil) then
                local item = {
                    version = version,
                    tag = name,
                    archiveUrl = ARCHIVE_URL_PREFIX .. name,
                }
                by_version[version] = item
            end
        end
    end

    for _, item in pairs(by_version) do
        ordered[#ordered + 1] = item
    end
    table.sort(ordered, function(left, right)
        return compare_versions(left.version, right.version) > 0
    end)
    return ordered, nil
end

local function resolve_release(releases, requested_version)
    local cleaned = trim(requested_version or "")
    if cleaned == "" then
        return releases ~= nil and releases[1] or nil
    end
    for _, item in ipairs(releases or {}) do
        if trim(item.version) == cleaned then
            return item
        end
    end
    return nil
end

local function require_binaries(context, binaries)
    for _, binary in ipairs(binaries or {}) do
        if not command_exists(context, binary) then
            return false, "missing required binary: " .. binary
        end
    end
    return true, nil
end

local function installer_command(source_path, paths)
    return "rm -rf " .. shell_quote(paths.currentRoot)
        .. " && mkdir -p "
        .. shell_quote(join_path(paths.currentRoot, "lib")) .. " "
        .. shell_quote(paths.examplePath) .. " "
        .. shell_quote(paths.htmlPath) .. " "
        .. shell_quote(paths.nroffPath)
        .. " && (cd " .. shell_quote(source_path)
        .. " && tclsh './installer.tcl' -no-gui -no-wait -pkg-path " .. shell_quote(paths.pkgPath)
        .. " -example-path " .. shell_quote(paths.examplePath)
        .. " -html-path " .. shell_quote(paths.htmlPath)
        .. " -nroff-path " .. shell_quote(paths.nroffPath)
        .. " -pkgs -examples -html -nroff)"
end

local function archive_path(paths, tag)
    return join_path(paths.archives, tag .. ".tar.gz")
end

local function source_path(paths, tag)
    return join_path(paths.sources, "tcllib-" .. tag)
end

local function fetch_release_source(context, root, release)
    local paths = managed_paths(root, release.version)
    local archive = archive_path(paths, release.tag)
    local source = source_path(paths, release.tag)
    local download = "mkdir -p " .. shell_quote(paths.archives) .. " " .. shell_quote(paths.sources) .. " " .. shell_quote(paths.state)
        .. " && curl -fsSL " .. shell_quote(release.archiveUrl) .. " -o " .. shell_quote(archive)
    local extract = "rm -rf " .. shell_quote(source)
        .. " && mkdir -p " .. shell_quote(paths.sources)
        .. " && tar -xzf " .. shell_quote(archive) .. " -C " .. shell_quote(paths.sources)

    local download_result = exec_run(context, download)
    if not download_result.success then
        return nil, trim(download_result.stderr) ~= "" and trim(download_result.stderr) or "failed to download Tcllib archive"
    end

    local extract_result = exec_run(context, extract)
    if not extract_result.success then
        return nil, trim(extract_result.stderr) ~= "" and trim(extract_result.stderr) or "failed to unpack Tcllib archive"
    end

    return source, nil
end

local function parse_local_version(context, local_root)
    local version_file = join_path(local_root, "tcllib_version.tcl")
    local content = read_text_file(context, version_file)
    if content == nil then
        return nil
    end
    local version = content:match("set%s+tcllib_version%s+([0-9A-Za-z%._%-]+)")
    return trim(version or "") ~= "" and trim(version) or nil
end

local function matches_requested_version(manifest, request)
    if manifest == nil then
        return false
    end
    local wanted = trim(request.version or "")
    if wanted == "" then
        return lower(trim(request.name or "")) == "tcllib" or trim(request.name or "") == ""
    end
    return trim(manifest.version or "") == wanted
end

local function install_from_source(context, root, version, tag, origin, source)
    local paths = managed_paths(root, version)
    local command = installer_command(source, paths)
    local result = exec_run(context, command)
    if not result.success then
        return nil, trim(result.stderr) ~= "" and trim(result.stderr) or "Tcllib installer failed"
    end

    local manifest = {
        name = "tcllib",
        version = version,
        tag = tag or version_to_tag(version) or "",
        origin = origin,
        root = root,
        pkgPath = paths.pkgPath,
        examplePath = paths.examplePath,
        htmlPath = paths.htmlPath,
        nroffPath = paths.nroffPath,
        sourcePath = source,
    }
    if not write_manifest(context, paths.manifest, manifest) then
        return nil, "failed to write Tcllib manifest"
    end
    return manifest, nil
end

local function install_remote_release(context, package, event_name)
    local ok, message = require_binaries(context, REQUIRED_REMOTE_BINARIES)
    if not ok then
        tx_failed(context, message)
        return false
    end

    local root = derive_root(context, package)
    local request = package_request(package)
    if lower(request.name) ~= "tcllib" then
        tx_failed(context, "unsupported package for Tcllib plugin: " .. request.name)
        return false
    end

    begin_step(context, "resolve Tcllib release")
    local releases, release_error = fetch_remote_releases(context)
    if releases == nil then
        tx_failed(context, release_error)
        return false
    end

    local release = resolve_release(releases, request.version)
    if release == nil then
        tx_failed(context, "requested Tcllib release not found: " .. trim(request.version ~= "" and request.version or request.name))
        return false
    end

    begin_step(context, "download Tcllib source")
    local source, source_error = fetch_release_source(context, root, release)
    if source == nil then
        tx_failed(context, source_error)
        return false
    end

    begin_step(context, "install Tcllib")
    local manifest, install_error = install_from_source(context, root, release.version, release.tag, "remote", source)
    if manifest == nil then
        tx_failed(context, install_error)
        return false
    end

    local item = installed_item_from_manifest(manifest)
    emit_event(context, event_name, { item })
    tx_success(context)
    return true
end

local function update_remote_release(context, package)
    return install_remote_release(context, package or { name = "tcllib" }, "updated")
end

local function local_source_exists(context, path)
    return path_exists(context, join_path(path, "installer.tcl"))
end

local function install_local_source(context, local_path)
    local ok, message = require_binaries(context, REQUIRED_LOCAL_BINARIES)
    if not ok then
        tx_failed(context, message)
        return false
    end

    local source = trim(local_path)
    if source == "" or not local_source_exists(context, source) then
        tx_failed(context, "local Tcllib source directory must contain installer.tcl")
        return false
    end

    local version = parse_local_version(context, source)
    if version == nil then
        tx_failed(context, "failed to determine Tcllib version from local source")
        return false
    end

    local root = derive_root(context, nil)
    begin_step(context, "install local Tcllib source")
    local manifest, install_error = install_from_source(context, root, version, version_to_tag(version), "local", source)
    if manifest == nil then
        tx_failed(context, install_error)
        return false
    end

    emit_event(context, "installed", { installed_item_from_manifest(manifest) })
    tx_success(context)
    return true
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
    return { "Tcl", "Libraries", "tcllib" }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "package-install", "package-remove", "package-update", "package-query" },
        ecosystemScopes = { "tcl", "tcllib" },
        writeScopes = { "user-home-subpath:.cache/reqpack/tcllib" },
        networkScopes = {
            { host = "api.github.com", scheme = "https", pathPrefix = "/repos/tcltk/tcllib/tags" },
            { host = "codeload.github.com", scheme = "https", pathPrefix = "/tcltk/tcllib/tar.gz/refs/tags/" },
        },
        privilegeLevel = "none",
    }
end

function plugin.getMissingPackages(packages)
    local root = default_cache_root()
    local manifest = current_manifest_for_root(nil, root)
    local missing = {}
    for _, package in ipairs(packages or {}) do
        local request = package_request(package)
        if manifest == nil or not matches_requested_version(manifest, request) then
            missing[#missing + 1] = package
        end
    end
    return missing
end

function plugin.install(context, packages)
    local local_path = request_local_path(context, nil)
    if local_path ~= "" then
        return install_local_source(context, local_path)
    end
    local queue = packages or {}
    if #queue == 0 then
        queue = { { name = "tcllib" } }
    end
    for _, package in ipairs(queue) do
        if not install_remote_release(context, package, "installed") then
            return false
        end
    end
    return true
end

function plugin.installLocal(context, path)
    return install_local_source(context, request_local_path(context, path))
end

function plugin.remove(context, packages)
    local root = derive_root(context, nil)
    local manifest = current_manifest_for_root(context, root)
    if manifest == nil then
        tx_success(context)
        return true
    end

    local should_remove = false
    local queue = packages or {}
    if #queue == 0 then
        should_remove = true
    else
        for _, package in ipairs(queue) do
            if matches_requested_version(manifest, package_request(package)) then
                should_remove = true
                break
            end
        end
    end

    if not should_remove then
        tx_success(context)
        return true
    end

    begin_step(context, "remove Tcllib install")
    local current_root = managed_paths(root, manifest.version).currentRoot
    local result = exec_run(context, "rm -rf " .. shell_quote(current_root))
    if not result.success then
        tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "failed to remove Tcllib install")
        return false
    end
    if os ~= nil and type(os.remove) == "function" then
        os.remove(join_path(root, "state", "current.txt"))
    end
    emit_event(context, "deleted", { installed_item_from_manifest(manifest) })
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local queue = packages or {}
    if #queue == 0 then
        queue = { { name = "tcllib" } }
        return update_remote_release(context, queue[1])
    end
    for _, package in ipairs(queue) do
        if not update_remote_release(context, package) then
            return false
        end
    end
    return true
end

function plugin.list(context)
    local root = derive_root(context, nil)
    local manifest = current_manifest_for_root(context, root)
    local items = {}
    if manifest ~= nil then
        items[#items + 1] = installed_item_from_manifest(manifest)
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local root = derive_root(context, nil)
    local manifest = current_manifest_for_root(context, root)
    if manifest == nil then
        emit_event(context, "outdated", {})
        return {}
    end

    local releases, error_message = fetch_remote_releases(context)
    if releases == nil then
        log_warn(context, error_message)
        emit_event(context, "outdated", {})
        return {}
    end

    local latest = releases[1]
    local items = {}
    if latest ~= nil and compare_versions(latest.version, manifest.version) > 0 then
        local item = release_item(latest.version, latest.tag)
        item.status = "outdated"
        item.extraFields = merge_tables(item.extraFields, {
            installedVersion = manifest.version,
            origin = manifest.origin,
            pkgPath = manifest.pkgPath,
        })
        items[#items + 1] = item
    end

    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local root = derive_root(context, nil)
    local manifest = current_manifest_for_root(context, root)
    local releases, error_message = fetch_remote_releases(context)
    if releases == nil then
        log_warn(context, error_message)
        emit_event(context, "searched", {})
        return {}
    end

    local query = lower(trim(prompt or request_name(context, nil)))
    local items = {}
    for _, release in ipairs(releases) do
        local haystack = table.concat({ "tcllib", release.version, release.tag }, " "):lower()
        if query == "" or haystack:find(query, 1, true) ~= nil then
            items[#items + 1] = release_item(release.version, release.tag, manifest)
        end
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local root = derive_root(context, nil)
    local manifest = current_manifest_for_root(context, root)
    local query = package_request(request_name(context, name))

    if lower(query.name) ~= "tcllib" then
        return {}
    end

    local releases, error_message = fetch_remote_releases(context)
    if releases == nil then
        log_warn(context, error_message)
        local local_item = installed_item_from_manifest(manifest)
        if local_item ~= nil then
            emit_event(context, "informed", local_item)
            return local_item
        end
        return {}
    end

    local release = resolve_release(releases, query.version) or releases[1]
    if release == nil then
        return {}
    end

    local item = release_item(release.version, release.tag, manifest)
    item.extraFields = merge_tables(item.extraFields, {
        availableVersions = table.concat((function()
            local versions = {}
            for _, entry in ipairs(releases) do
                versions[#versions + 1] = entry.version
            end
            return versions
        end)(), ", "),
    })
    if manifest ~= nil then
        item.extraFields = merge_tables(item.extraFields, {
            installedVersion = manifest.version,
        })
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

return plugin
