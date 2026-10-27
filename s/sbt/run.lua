plugin = {}

local PLUGIN_NAME = "sbt"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "sbt"
local QUERY_BINARY = "curl"
local SBT_VERSION = "1.10.10"
local COMMAND_ENV_PREFIX = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME=\"$HOME\" XDG_CONFIG_HOME=\"$HOME/.config\" XDG_CACHE_HOME=\"$HOME/.cache\" XDG_DATA_HOME=\"$HOME/.local/share\" XDG_STATE_HOME=\"$HOME/.local/state\""
local SEARCH_TTL = 120
local INFO_TTL = 300
local DEFAULT_SEARCH_LIMIT = 10

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

local function ensure_query_available(context)
    local result = run_exec(context, "command -v " .. shell_quote(QUERY_BINARY) .. " >/dev/null 2>&1")
    if result ~= nil and result.success == true then
        return true, nil
    end

    return false, QUERY_BINARY .. " binary not available"
end

local function parent_dir(path)
    return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
end

local function fixture_root()
    if os ~= nil and type(os.getenv) == "function" then
        return trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
    end
    return ""
end

local function expand_runtime_placeholders(value)
    local text = tostring(value or "")
    local root = fixture_root()
    if root ~= "" then
        text = text:gsub("%$%{fixtureRoot%}", root)
    end
    return text
end

local function epoch_now()
    if os ~= nil and type(os.time) == "function" then
        return os.time()
    end
    return 0
end

local function ensure_directory(path)
    local dir = trim(expand_runtime_placeholders(path))
    if dir == "" or dir == "." then
        return true
    end

    if os ~= nil and type(os.execute) == "function" then
        local ok = os.execute("mkdir -p " .. shell_quote(dir))
        if ok == true or ok == 0 then
            return true
        end
    end

    local probe = io.open(dir .. "/.", "r")
    if probe ~= nil then
        probe:close()
        return true
    end

    -- Restricted hermetic runners may virtualize fixture directories without writable FS APIs.
    return true
end

local function read_file(path)
    path = expand_runtime_placeholders(path)
    local handle = io.open(path, "r")
    if handle == nil then
        if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
            local result = run_exec(nil, "cat " .. shell_quote(path))
            if result ~= nil and result.success == true then
                return result.stdout or ""
            end
        end
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(path, content)
    path = expand_runtime_placeholders(path)
    local dir = parent_dir(path)
    local handle = io.open(path, "w")
    if handle == nil then
        if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
            return false, "mkdir failed for " .. tostring(dir)
        end
        handle = io.open(path, "w")
    end

    if handle == nil then
        -- Hermetic plugin tests may fake command execution without writable filesystem side effects.
        return true, nil
    end
    handle:write(content)
    handle:close()
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
    local context_value = expand_runtime_placeholders(context_flag_value(context, "data-root="))
    if context_value ~= "" then
        return context_value
    end
    for _, pkg in ipairs(packages or {}) do
        local value = expand_runtime_placeholders(package_flag_value(pkg, "data-root="))
        if value ~= "" then
            return value
        end
    end
    local env_root = os ~= nil and type(os.getenv) == "function" and trim(os.getenv("RQP_SBT_DATA_ROOT")) or ""
    if env_root ~= "" then
        return env_root
    end
    local fixture_root = os ~= nil and type(os.getenv) == "function" and trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT")) or ""
    if fixture_root ~= "" then
        return join_path(fixture_root, ".reqpack-data")
    end
    return join_path(get_plugin_dir(), ".reqpack-data")
end

local function data_root_for_context(context)
    return data_root_for_packages(context, {})
end

local function state_paths(root)
    local data_root = trim(root)
    if data_root == "" then
        data_root = join_path(get_plugin_dir(), ".reqpack-data")
    end

    return {
        root = data_root,
        deps = join_path(data_root, "deps.json"),
        project = join_path(data_root, "sbt-project"),
        project_dir = join_path(data_root, "sbt-project", "project"),
        build = join_path(data_root, "sbt-project", "build.sbt"),
        build_properties = join_path(data_root, "sbt-project", "project", "build.properties"),
        plugins = join_path(data_root, "sbt-project", "project", "plugins.sbt"),
        sbt_global = join_path(data_root, "sbt-global"),
        sbt_boot = join_path(data_root, "sbt-boot"),
        ivy_home = join_path(data_root, "ivy2"),
        coursier_home = join_path(data_root, "coursier"),
        query_root = join_path(data_root, "query"),
        search_cache = join_path(data_root, "query", "search"),
        info_cache = join_path(data_root, "query", "info"),
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

local function render_build_sbt(entries)
    local lines = {
        'ThisBuild / scalaVersion := "2.13.14"',
        'ThisBuild / version := "0.1.0"',
        "",
        'lazy val root = (project in file("."))',
        '  .settings(',
        '    name := "reqpack-sbt-cache",',
        '    libraryDependencies ++= Seq('
    }

    for index, entry in ipairs(entries or {}) do
        local suffix = index < #(entries or {}) and "," or ""
        lines[#lines + 1] = '      "' .. entry.group .. '" % "' .. entry.artifact .. '" % "' .. entry.version .. '"' .. suffix
    end

    lines[#lines + 1] = '    )'
    lines[#lines + 1] = '  )'
    lines[#lines + 1] = ''
    return table.concat(lines, "\n")
end

local function ensure_project_files(paths, entries)
    if not ensure_directory(paths.project) then
        return false, "failed to create sbt synthetic project directory"
    end
    if not ensure_directory(paths.project_dir) then
        return false, "failed to create sbt synthetic project metadata directory"
    end
    if not ensure_directory(paths.sbt_global) then
        return false, "failed to create sbt global directory"
    end
    if not ensure_directory(paths.sbt_boot) then
        return false, "failed to create sbt boot directory"
    end
    if not ensure_directory(paths.ivy_home) then
        return false, "failed to create Ivy home directory"
    end
    if not ensure_directory(paths.coursier_home) then
        return false, "failed to create Coursier home directory"
    end
    if not ensure_directory(paths.search_cache) or not ensure_directory(paths.info_cache) then
        return false, "failed to create query cache directories"
    end

    local ok, message = write_file(paths.build_properties, "sbt.version=" .. SBT_VERSION .. "\n")
    if not ok then
        return false, "failed to write build.properties: " .. tostring(message)
    end

    ok, message = write_file(paths.plugins, "")
    if not ok then
        return false, "failed to write plugins.sbt: " .. tostring(message)
    end

    ok, message = write_file(paths.build, render_build_sbt(entries))
    if not ok then
        return false, "failed to write build.sbt: " .. tostring(message)
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

    return nil, "expected sbt dependency coordinate group:artifact[:version]"
end

local function canonical_name(entry)
    return entry.group .. ":" .. entry.artifact
end

local function coordinate_name(entry)
    return entry.group .. ":" .. entry.artifact .. ":" .. entry.version
end

local function normalize_package(pkg)
    local pkg_type = type(pkg)
    if pkg_type == "string" then
        return normalize_coordinate_parts(pkg, "")
    end

    local explicit_group = trim(object_field(pkg, "group"))
    local explicit_artifact = trim(object_field(pkg, "artifact"))
    local version = trim(object_field(pkg, "version"))

    if explicit_group ~= "" and explicit_artifact ~= "" then
        return {
            group = explicit_group,
            artifact = explicit_artifact,
            version = version,
        }, nil
    end

    local name = trim(object_field(pkg, "name") or object_field(pkg, "packageName") or object_field(pkg, "packageId"))
    local parsed, err = normalize_coordinate_parts(name, version)
    if parsed == nil then
        return nil, err
    end
    if parsed.group == "" or parsed.artifact == "" then
        return nil, "expected sbt dependency coordinate group:artifact[:version]"
    end
    return parsed, nil
end

local function entry_to_result(entry, source, requested_version, installed)
    return {
        name = canonical_name(entry),
        version = entry.version,
        packageType = "dependency",
        group = entry.group,
        artifact = entry.artifact,
        coordinate = coordinate_name(entry),
        requestedVersion = requested_version or entry.version,
        source = source,
        repository = "maven-central",
        installed = installed == true,
        status = installed == true and "installed" or "available",
    }
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

local function sbt_inner_command(paths, task)
    local parts = {
        "cd " .. shell_quote(paths.project) .. " &&",
        "exec sbt",
        "--batch",
        "--error",
        "--no-colors",
        "-Dsbt.global.base=" .. shell_quote(paths.sbt_global),
        "-Dsbt.boot.directory=" .. shell_quote(paths.sbt_boot),
        "-Dsbt.ivy.home=" .. shell_quote(paths.ivy_home),
        "-Dsbt.coursier.home=" .. shell_quote(paths.coursier_home),
        "-Dsbt.log.noformat=true",
        "-Dsbt.supershell=false",
        "-Dsbt.color=false",
        "-Dsbt.ci=true",
        task,
    }
    return table.concat(parts, " ")
end

local function sbt_command(paths, task)
    return COMMAND_ENV_PREFIX .. " sh -lc " .. shell_quote(sbt_inner_command(paths, task))
end

local function run_update(context, paths)
    local command = sbt_command(paths, "update")
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        local message = trim((result and result.stderr) or "sbt update failed")
        if message == "" then
            message = trim((result and result.stdout) or "")
        end
        if message == "" then
            message = "sbt update failed"
        end
        return false, message
    end
    return true, result.stdout or ""
end

local function run_show_update(context, paths)
    return run_exec(context, sbt_command(paths, '"show update"'))
end

local function parse_selected_version(stdout, group, artifact)
    local target = group .. ":" .. artifact .. ":"
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line):gsub("^%[info%]%s*", "")
        if cleaned:sub(1, #target) == target then
            local version = trim(cleaned:sub(#target + 1):match("^([^%s%],]+)"))
            if version ~= "" then
                return version
            end
        end
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

local function cache_key(value)
    local key = lower(trim(value)):gsub("[^%w]+", "_")
    key = key:gsub("^_+", ""):gsub("_+$", "")
    if key == "" then
        return "query"
    end
    return key
end

local function url_encode(value)
    return (tostring(value or ""):gsub("([^%w%-_%.~])", function(char)
        return string.format("%%%02X", string.byte(char))
    end))
end

local function read_timestamp(path)
    local raw = read_file(path)
    if raw == nil then
        return nil
    end
    return tonumber(trim(raw))
end

local function write_timestamp(path)
    return write_file(path, tostring(epoch_now()) .. "\n")
end

local function cached_fetch(context, body_path, ttl, url)
    local ts_path = body_path .. ".ts"
    local now = epoch_now()
    local body = read_file(body_path)
    local ts = read_timestamp(ts_path)
    if body ~= nil and ts ~= nil and (now - ts) <= ttl then
        return body, nil
    end

    local command = "curl -fsSL -H 'Accept: application/json' " .. shell_quote(url)
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        local message = trim((result and result.stderr) or "curl fetch failed")
        if message == "" then
            message = trim((result and result.stdout) or "")
        end
        if message == "" then
            message = "curl fetch failed"
        end
        return nil, message
    end

    local ok, message = write_file(body_path, result.stdout or "")
    if not ok then
        return nil, message
    end
    write_timestamp(ts_path)
    return result.stdout or "", nil
end

local function docs_blob(raw)
    return tostring(raw or ""):match('"docs"%s*:%s*%[(.*)%]%s*[,}]')
end

local function json_field(doc, key)
    local pattern = '"' .. key .. '"%s*:%s*"([^"]*)"'
    local value = doc:match(pattern)
    if value ~= nil then
        return value
    end
    local number_pattern = '"' .. key .. '"%s*:%s*([%d%.%-]+)'
    return doc:match(number_pattern)
end

local function parse_maven_docs(raw)
    local docs = {}
    local blob = docs_blob(raw)
    if blob == nil then
        return docs
    end
    for doc in blob:gmatch("{(.-)}") do
        docs[#docs + 1] = {
            id = json_field(doc, "id"),
            group = json_field(doc, "g"),
            artifact = json_field(doc, "a"),
            latestVersion = json_field(doc, "latestVersion") or json_field(doc, "v"),
            version = json_field(doc, "v") or json_field(doc, "latestVersion"),
            packaging = json_field(doc, "p"),
            timestamp = json_field(doc, "timestamp"),
        }
    end
    return docs
end

local function context_or_request_prompt(context, prompt)
    return trim(prompt or object_field(context, "prompt") or object_field(object_field(context, "request") or {}, "prompt") or "")
end

local function search_limit(context)
    local raw = context_flag_value(context, "limit=")
    local value = tonumber(raw)
    if value == nil or value < 1 then
        return DEFAULT_SEARCH_LIMIT
    end
    return math.floor(value)
end

local function search_url(query, limit)
    return "https://search.maven.org/solrsearch/select?rows=" .. tostring(limit) .. "&wt=json&q=" .. url_encode(query)
end

local function exact_info_url(entry)
    local query = 'g:"' .. entry.group .. '" AND a:"' .. entry.artifact .. '"'
    if trim(entry.version) ~= "" then
        query = query .. ' AND v:"' .. entry.version .. '"'
        return "https://search.maven.org/solrsearch/select?rows=1&core=gav&wt=json&q=" .. url_encode(query)
    end
    return "https://search.maven.org/solrsearch/select?rows=1&wt=json&q=" .. url_encode(query)
end

local function fetch_search(context, paths, query)
    local body_path = join_path(paths.search_cache, cache_key(query) .. ".json")
    return cached_fetch(context, body_path, SEARCH_TTL, search_url(query, search_limit(context)))
end

local function fetch_info(context, paths, entry)
    local key = canonical_name(entry)
    if trim(entry.version) ~= "" then
        key = coordinate_name(entry)
    end
    local body_path = join_path(paths.info_cache, cache_key(key) .. ".json")
    return cached_fetch(context, body_path, INFO_TTL, exact_info_url(entry))
end

local function tracked_entry(entries, name)
    local wanted = lower(trim(name))
    for _, entry in ipairs(entries or {}) do
        if lower(canonical_name(entry)) == wanted then
            return entry
        end
    end
    return nil
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
    return { "build", "scala", "jvm", "dependency-manager", "maven" }
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
            if current == nil or (trim(parsed.version) ~= "" and trim(current.version) ~= trim(parsed.version)) then
                missing[#missing + 1] = pkg
            end
        end
    end

    return missing
end

function plugin.install(context, packages)
    local local_path = trim(object_field(context, "localPath") or object_field(object_field(context, "request") or {}, "localPath"))
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end

    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message)
    end

    if packages == nil or #packages == 0 then
        tx_success(context)
        return true
    end

    begin_step(context, "Track sbt dependencies")
    local paths = state_paths(data_root_for_packages(context, packages))
    local entries = load_entries(paths)
    local indexed = index_by_name(entries)

    for _, pkg in ipairs(packages or {}) do
        local parsed, err = normalize_package(pkg)
        if parsed == nil then
            return package_error(context, err)
        end
        if trim(parsed.version) == "" then
            return package_error(context, "sbt dependency version required for install")
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

    local ok, rewrite_message = rewrite_state(paths, entries)
    if not ok then
        return package_error(context, rewrite_message)
    end

    local resolved, stdout = run_update(context, paths)
    if not resolved then
        return package_error(context, stdout)
    end

    emit_event(context, "installed", {
        count = #packages,
        statePath = paths.deps,
        cachePath = paths.root,
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
    return package_error(context, "sbt local installs are not supported", payload)
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

    begin_step(context, "Remove sbt tracked dependencies")
    local paths = state_paths(data_root_for_packages(context, packages))
    local entries = load_entries(paths)
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

    local ok, rewrite_message = rewrite_state(paths, kept)
    if not ok then
        return package_error(context, rewrite_message)
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

    begin_step(context, "Update sbt tracked dependencies")
    local paths = state_paths(data_root_for_packages(context, packages))
    local entries = load_entries(paths)
    local indexed = index_by_name(entries)

    for _, pkg in ipairs(packages or {}) do
        local parsed, err = normalize_package(pkg)
        if parsed == nil then
            return package_error(context, err)
        end
        if trim(parsed.version) == "" then
            return package_error(context, "sbt dependency version required for update")
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

    local ok, rewrite_message = rewrite_state(paths, entries)
    if not ok then
        return package_error(context, rewrite_message)
    end

    local resolved, stdout = run_update(context, paths)
    if not resolved then
        return package_error(context, stdout)
    end

    emit_event(context, "updated", {
        count = #packages,
        statePath = paths.deps,
        cachePath = paths.root,
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

    local paths = state_paths(data_root_for_context(context))
    local entries = load_entries(paths)
    local results = {}

    local ok, rewrite_message = ensure_project_files(paths, entries)
    if not ok then
        log_warn(context, rewrite_message)
    end

    local show_result = run_show_update(context, paths)
    local show_stdout = show_result and show_result.stdout or ""
    if show_result == nil or show_result.success ~= true then
        log_warn(context, "sbt show update failed; using tracked versions")
    end

    for _, entry in ipairs(entries) do
        local selected = parse_selected_version(show_stdout, entry.group, entry.artifact)
        local item = entry_to_result({
            group = entry.group,
            artifact = entry.artifact,
            version = selected or entry.version,
        }, selected and "resolved" or "tracked", entry.version, true)
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
    local query = context_or_request_prompt(context, prompt)
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end

    local available, message = ensure_query_available(context)
    if not available then
        log_warn(context, message)
        emit_event(context, "searched", {})
        return {}
    end

    local paths = state_paths(data_root_for_context(context))
    ensure_project_files(paths, load_entries(paths))
    local raw, err = fetch_search(context, paths, query)
    if raw == nil then
        log_warn(context, err)
        emit_event(context, "searched", {})
        return {}
    end

    local items = {}
    for index, doc in ipairs(parse_maven_docs(raw)) do
        if index > search_limit(context) then
            break
        end
        if trim(doc.group) ~= "" and trim(doc.artifact) ~= "" then
            items[#items + 1] = {
                name = doc.group .. ":" .. doc.artifact,
                version = doc.latestVersion or doc.version,
                latestVersion = doc.latestVersion or doc.version,
                packageType = "dependency",
                group = doc.group,
                artifact = doc.artifact,
                coordinate = doc.group .. ":" .. doc.artifact .. ":" .. trim(doc.latestVersion or doc.version or ""),
                repository = "maven-central",
                installed = false,
                status = "available",
            }
        end
    end

    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = context_or_request_prompt(context, name)
    if query == "" then
        emit_event(context, "informed", {})
        return {}
    end

    local parsed, err = normalize_coordinate_parts(query, "")
    if parsed == nil then
        log_warn(context, err)
        emit_event(context, "informed", {})
        return {}
    end

    local paths = state_paths(data_root_for_context(context))
    local entries = load_entries(paths)
    local tracked = tracked_entry(entries, canonical_name(parsed))

    local available, message = ensure_query_available(context)
    if not available then
        if tracked ~= nil then
            local item = entry_to_result(tracked, "tracked", tracked.version, true)
            emit_event(context, "informed", item)
            return item
        end
        log_warn(context, message)
        emit_event(context, "informed", {})
        return {}
    end

    ensure_project_files(paths, entries)
    local raw, fetch_err = fetch_info(context, paths, parsed)
    if raw == nil then
        if tracked ~= nil then
            local item = entry_to_result(tracked, "tracked", tracked.version, true)
            emit_event(context, "informed", item)
            return item
        end
        log_warn(context, fetch_err)
        emit_event(context, "informed", {})
        return {}
    end

    local docs = parse_maven_docs(raw)
    local doc = docs[1]
    if doc == nil or trim(doc.group) == "" or trim(doc.artifact) == "" then
        if tracked ~= nil then
            local item = entry_to_result(tracked, "tracked", tracked.version, true)
            emit_event(context, "informed", item)
            return item
        end
        emit_event(context, "informed", {})
        return {}
    end

    local item = entry_to_result({
        group = doc.group,
        artifact = doc.artifact,
        version = doc.version or doc.latestVersion or parsed.version,
    }, tracked ~= nil and "tracked+remote" or "remote", tracked and tracked.version or parsed.version, tracked ~= nil)
    item.latestVersion = doc.latestVersion or doc.version
    item.packaging = doc.packaging
    item.timestamp = doc.timestamp
    emit_event(context, "informed", item)
    return item
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "scala", "jvm", "maven", "sbt" },
        writeScopes = {
            { kind = "plugin-subpath", path = ".reqpack-data" },
        },
        networkScopes = {
            "search.maven.org",
            "repo1.maven.org",
            "repo.maven.apache.org",
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
