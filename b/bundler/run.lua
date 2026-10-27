plugin = {}

local PLUGIN_ID = "bundler"
local PLUGIN_NAME = "Bundler"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "bundle"
local GEM_BINARY = "gem"

local valid_project_dir

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function expand_placeholders(value)
    local text = tostring(value or "")
    local fixture_root = nil
    if os ~= nil and type(os.getenv) == "function" then
        fixture_root = os.getenv("REQPACK_TEST_FIXTURE_ROOT")
    end
    if fixture_root ~= nil and fixture_root ~= "" then
        text = text:gsub("%$%{fixtureRoot%}", fixture_root)
    end
    return text
end

local function lower(value)
    return tostring(value or ""):lower()
end

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil then
            if type(value) == "string" then
                local text = trim(value)
                if text ~= "" then
                    return text
                end
            else
                return value
            end
        end
    end
    return nil
end

local function non_empty(value)
    local text = trim(value)
    if text == "" then
        return nil
    end
    return text
end

local function shell_quote(value)
    return "'" .. expand_placeholders(value):gsub("'", "'\\''") .. "'"
end

local function is_safe_token(value)
    return tostring(value or ""):match("^[A-Za-z0-9_./:@%%+=,%-%[%]~]+$") ~= nil
end

local function command_quote(value)
    local text = expand_placeholders(value)
    if is_safe_token(text) then
        return text
    end
    return shell_quote(text)
end

local function split_lines(value)
    local lines = {}
    local text = tostring(value or ""):gsub("\r\n", "\n")
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

local function split_csv(value)
    local items = {}
    for item in tostring(value or ""):gmatch("([^,]+)") do
        local cleaned = trim(item)
        if cleaned ~= "" then
            items[#items + 1] = cleaned
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
    else
        first, second, third, fourth, fifth = reqpack.exec.run(command)
    end
    return normalize_run_result(first, second, third, fourth, fifth)
end

local function result_success(result)
    return type(result) == "table" and result.success == true
end

local function command_exists(context, binary)
    return result_success(exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(expand_placeholders(select(index, ...)))
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

local function parent_dir(path)
    return expand_placeholders(path):match("^(.*)[/\\][^/\\]+$")
end

local function ensure_directory(path)
    local dir = trim(expand_placeholders(path))
    if dir == "" or dir == "." then
        return true
    end
    if os == nil or type(os.execute) ~= "function" then
        return false
    end
    local ok, kind, code = os.execute("mkdir -p " .. shell_quote(dir))
    if ok == true then
        return true
    end
    if type(ok) == "number" then
        return ok == 0
    end
    return code == 0 or kind == "exit"
end

local function read_file(path)
    local handle = io.open(expand_placeholders(path), "r")
    if handle == nil then
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(path, content)
    path = expand_placeholders(path)
    local dir = parent_dir(path)
    if dir ~= nil then
        ensure_directory(dir)
    end
    local handle = io.open(path, "w")
    if handle == nil then
        return false
    end
    handle:write(content)
    handle:close()
    return true
end

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        local value = non_empty(os.getenv(name))
        if value ~= nil then
            return value
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
            return non_empty(entry:sub(#prefix + 1))
        end
    end

    return nil
end

local function home_dir()
    return first_nonempty(getenv("HOME"), getenv("USERPROFILE"), "/home/test", ".")
end

local function object_flags(object)
    local raw = read_field(object, "flags")
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

local function list_like_flags(value)
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
    if ok then
        return flags
    end
    return {}
end

local function append_unique(list, value, seen)
    local text = trim(value)
    if text == "" or seen[text] then
        return
    end
    seen[text] = true
    list[#list + 1] = text
end

local function collect_raw_flags(context, packages)
    local flags = {}
    local seen = {}

    local function collect_from(object)
        for _, flag in ipairs(object_flags(object)) do
            append_unique(flags, flag, seen)
        end
    end

    local function collect_list(value)
        for _, flag in ipairs(list_like_flags(value)) do
            append_unique(flags, flag, seen)
        end
    end

    collect_from(context)
    collect_from(read_field(context, "request"))
    collect_list(read_field(context, "flags"))
    collect_list(read_field(read_field(context, "request"), "flags"))
    for _, package in ipairs(packages or {}) do
        collect_from(package)
    end
    return flags
end

local function flag_value(flags, key)
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            return trim(expand_placeholders(cleaned:sub(#prefix + 1)))
        end
    end
    return nil
end

local function has_flag(flags, key)
    local wanted = lower(trim(key))
    for _, flag in ipairs(flags or {}) do
        if lower(trim(flag)) == wanted then
            return true
        end
    end
    return false
end

local function project_dir(context, packages)
    local env_dir = getenv("RQP_BUNDLER_PROJECT_DIR")
    if env_dir ~= nil and env_dir ~= "" then
        return env_dir
    end

    local fixture_root = getenv("REQPACK_TEST_FIXTURE_ROOT")
    if fixture_root ~= nil and fixture_root ~= "" then
        local explicit_test_dir = expand_placeholders(first_nonempty(
            read_field(context, "directory"),
            read_field(read_field(context, "request"), "directory"),
            read_field(context, "dir"),
            read_field(read_field(context, "request"), "dir")
        ))
        if explicit_test_dir ~= nil and explicit_test_dir ~= "" then
            return explicit_test_dir
        end
        return join_path(fixture_root, "project")
    end

    local flags = collect_raw_flags(context, packages)
    local explicit = expand_placeholders(first_nonempty(
        read_field(context, "directory"),
        read_field(read_field(context, "request"), "directory"),
        flag_value(flags, "dir"),
        read_field(context, "dir"),
        read_field(read_field(context, "request"), "dir")
    ))
    if explicit ~= nil and explicit ~= "" then
        return explicit
    end

    return expand_placeholders(first_nonempty(getenv("PWD"), "."))
end

local function fallback_project_dir(candidate)
    return expand_placeholders(candidate)
end

local function cache_root(context, packages)
    local env_root = getenv("RQP_BUNDLER_CACHE_ROOT")
    if env_root ~= nil and env_root ~= "" then
        return env_root
    end

    local fixture_root = getenv("REQPACK_TEST_FIXTURE_ROOT")
    if fixture_root ~= nil and fixture_root ~= "" then
        local explicit_test_root = expand_placeholders(first_nonempty(flag_value(collect_raw_flags(context, packages), "cache-root")))
        if explicit_test_root ~= nil and explicit_test_root ~= "" then
            return explicit_test_root
        end
        return join_path(fixture_root, "home", ".cache", "reqpack", PLUGIN_ID)
    end

    local flags = collect_raw_flags(context, packages)
    local explicit = expand_placeholders(first_nonempty(flag_value(flags, "cache-root")))
    if explicit ~= nil and explicit ~= "" then
        return explicit
    end

    return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
end

local function shared_paths(context, packages)
    local root = cache_root(context, packages)
    return {
        root = root,
        cache = join_path(root, "cache"),
        config = join_path(root, "config"),
        plugin = join_path(root, "plugin"),
        query = join_path(root, "query-project"),
        query_gemfile = join_path(root, "query-project", "Gemfile"),
        query_vendor_cache = join_path(root, "query-vendor-cache"),
        gem_spec_cache = join_path(root, "rubygems", "specs"),
    }
end

local function gemfile_path_for_dir(dir)
    return join_path(dir, "Gemfile")
end

local function lockfile_path_for_dir(dir)
    return join_path(dir, "Gemfile.lock")
end

local function env_prefix(paths, gemfile_path)
    local parts = {
        "BUNDLE_USER_HOME=" .. shell_quote(paths.root),
        "BUNDLE_USER_CACHE=" .. shell_quote(paths.cache),
        "BUNDLE_USER_CONFIG=" .. shell_quote(paths.config),
        "BUNDLE_USER_PLUGIN=" .. shell_quote(paths.plugin),
        "NO_COLOR='1'",
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
        "SHELL='/bin/sh'",
    }
    if gemfile_path ~= nil and gemfile_path ~= "" then
        parts[#parts + 1] = "BUNDLE_GEMFILE=" .. shell_quote(gemfile_path)
    end
    return table.concat(parts, " ")
end

local function build_bundle_command(context, packages, args, forced_dir)
    local paths = shared_paths(context, packages)
    local dir = fallback_project_dir(forced_dir or project_dir(context, packages))
    local gemfile = gemfile_path_for_dir(dir)
    local parts = { env_prefix(paths, gemfile), REQUIRED_BINARY }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = command_quote(arg)
    end
    return table.concat(parts, " "), paths, dir
end

local function build_gem_command(context, packages, args)
    local paths = shared_paths(context, packages)
    local parts = {
        env_prefix(paths, nil),
        "GEM_SPEC_CACHE=" .. shell_quote(paths.gem_spec_cache),
        "GEMRC=/dev/null",
        GEM_BINARY,
    }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = command_quote(arg)
    end
    return table.concat(parts, " ")
end

local function package_name(pkg)
    return trim(expand_placeholders(read_field(pkg, "name") or read_field(pkg, "packageName") or read_field(pkg, "packageId")))
end

local function package_version(pkg)
    local direct = trim(read_field(pkg, "version"))
    if direct ~= "" then
        return direct
    end
    local flags = object_flags(pkg)
    return trim(flag_value(flags, "version") or "")
end

local function context_packages(context)
    local direct = read_field(context, "packages")
    if type(direct) == "table" then
        return direct
    end
    local nested = read_field(read_field(context, "request"), "packages")
    if type(nested) == "table" then
        return nested
    end
    return nil
end

local function package_lookup_name(pkg)
    return lower(package_name(pkg))
end

valid_project_dir = function(dir)
    return read_file(gemfile_path_for_dir(dir)) ~= nil
end

local function parse_gemspec_name_from_path(path)
    local name = tostring(path or ""):match("([^/\\]+)%.gemspec$")
    return non_empty(name)
end

local function resolve_local_project(context, path)
    local cleaned = trim(expand_placeholders(path))
    if cleaned == "" then
        return nil, nil, "missing local path"
    end
    if lower(cleaned):sub(-4) == ".gem" then
        return nil, nil, "raw .gem artifacts are not supported by bundler installLocal"
    end
    if lower(cleaned):match("%.gemspec$") then
        return parent_dir(cleaned) or ".", parse_gemspec_name_from_path(cleaned), nil
    end

    local result = exec_run(context, "ls -1A " .. shell_quote(cleaned) .. " 2>/dev/null")
    if not result_success(result) then
        return nil, nil, "failed to inspect local path"
    end
    local output = result.stdout or ""
    local matches = {}
    for _, line in ipairs(split_lines(output)) do
        if lower(trim(line)):match("%.gemspec$") then
            matches[#matches + 1] = trim(line)
        end
    end
    if #matches == 1 then
        return cleaned, parse_gemspec_name_from_path(matches[1]), nil
    end
    if #matches == 0 then
        return nil, nil, "local directory contains no .gemspec"
    end
    return nil, nil, "local directory contains multiple .gemspec files"
end

local function query_project_gemfile(spec, source)
    local lines = {
        "source '" .. expand_placeholders(source or "https://rubygems.org") .. "'",
        "",
        "gem '" .. tostring(spec.name):gsub("'", "\\'") .. "'",
    }
    if spec.version ~= nil and spec.version ~= "" then
        lines[3] = "gem '" .. tostring(spec.name):gsub("'", "\\'") .. "', '" .. tostring(spec.version):gsub("'", "\\'") .. "'"
    end
    return table.concat(lines, "\n") .. "\n"
end

local function ensure_query_project(context, packages, spec)
    local paths = shared_paths(context, packages)
    ensure_directory(paths.query)
    ensure_directory(paths.cache)
    ensure_directory(paths.config)
    ensure_directory(paths.plugin)
    ensure_directory(paths.query_vendor_cache)
    ensure_directory(paths.gem_spec_cache)
    local source = flag_value(collect_raw_flags(context, packages), "source")
    if not write_file(paths.query_gemfile, query_project_gemfile(spec, source)) then
        return nil, "failed to write shared query Gemfile"
    end
    return paths, nil
end

local function sort_by_name(items)
    table.sort(items, function(left, right)
        return lower(read_field(left, "name")) < lower(read_field(right, "name"))
    end)
end

local function parse_remote_detail_blocks(raw)
    local items = {}
    local current = nil

    local function finish_current()
        if current == nil then
            return
        end
        items[#items + 1] = current
        current = nil
    end

    for _, line in ipairs(split_lines(raw)) do
        local name, version = line:match("^([^%s][^%(]-)%s*%((.+)%)%s*$")
        if name ~= nil then
            finish_current()
            current = {
                name = trim(name),
                packageId = trim(name),
                version = trim(version),
                latestVersion = trim(version),
                packageType = "gem",
                type = "package",
                extraFields = {
                    registry = "rubygems",
                },
            }
        elseif current ~= nil then
            local authors = line:match("^%s*Authors?:%s*(.+)$")
            local homepage = line:match("^%s*Homepage:%s*(.+)$")
            local license = line:match("^%s*Licenses?:%s*(.+)$") or line:match("^%s*License:%s*(.+)$")
            local cleaned = trim(line)
            if authors ~= nil then
                current.authors = trim(authors)
            elseif homepage ~= nil then
                current.homepage = trim(homepage)
            elseif license ~= nil then
                current.license = trim(license)
            elseif cleaned ~= "" and current.description == nil then
                current.description = cleaned
            end
        end
    end

    finish_current()
    sort_by_name(items)
    return items
end

local function strip_yaml_scalar(value)
    local cleaned = trim(value)
    cleaned = cleaned:gsub("^['\"]", ""):gsub("['\"]$", "")
    return cleaned
end

local function parse_yaml_spec(raw)
    local spec = {
        extraFields = {
            registry = "rubygems",
        },
        dependencies = {},
    }
    local section = nil
    local in_dependency = false

    for _, line in ipairs(split_lines(raw)) do
        local key, value = line:match("^([A-Za-z_][A-Za-z0-9_]*):%s*(.*)$")
        if key ~= nil then
            section = key
            in_dependency = false
            local scalar = strip_yaml_scalar(value)
            if key == "name" then
                spec.name = scalar
                spec.packageId = scalar
            elseif key == "homepage" then
                spec.homepage = scalar
            elseif key == "summary" then
                spec.summary = scalar
                if spec.description == nil then
                    spec.description = scalar
                end
            elseif key == "description" then
                spec.description = scalar
            elseif key == "licenses" and scalar == "[]" then
                section = nil
            elseif key == "authors" and scalar == "[]" then
                section = nil
            elseif key == "dependencies" and scalar == "[]" then
                section = nil
            end
        elseif section == "version" then
            local nested = line:match("^%s+version:%s*'?([^']+)'?%s*$")
            if nested ~= nil then
                spec.latestVersion = trim(nested)
                if spec.version == nil then
                    spec.version = trim(nested)
                end
                section = nil
            end
        elseif section == "authors" then
            local item = line:match("^%-%s*(.+)$")
            if item ~= nil then
                spec.authors = spec.authors or ""
                local extra = trim(item)
                spec.authors = spec.authors == "" and strip_yaml_scalar(extra) or (spec.authors .. ", " .. strip_yaml_scalar(extra))
            end
        elseif section == "licenses" then
            local item = line:match("^%-%s*(.+)$")
            if item ~= nil then
                spec.license = spec.license or ""
                local extra = strip_yaml_scalar(item)
                spec.license = spec.license == "" and extra or (spec.license .. ", " .. extra)
            end
        elseif section == "dependencies" then
            if line:match("^%-%s*!ruby/object:Gem::Dependency") then
                in_dependency = true
            elseif in_dependency then
                local dep_name = line:match("^%s+name:%s*(.+)$")
                if dep_name ~= nil then
                    spec.dependencies[#spec.dependencies + 1] = strip_yaml_scalar(dep_name)
                    in_dependency = false
                end
            end
        elseif section == "metadata" then
            local meta_key, meta_value = line:match("^%s+([A-Za-z_][A-Za-z0-9_]*):%s*(.+)$")
            if meta_key ~= nil then
                spec.extraFields[meta_key] = strip_yaml_scalar(meta_value)
            end
        end
    end

    if spec.name == nil then
        return nil
    end
    if #spec.dependencies == 0 then
        spec.dependencies = nil
    end
    spec.packageType = "gem"
    spec.type = "package"
    return spec
end

local function parse_lockfile(raw, project_dir_value)
    local items = {}
    local by_name = {}
    local dependencies = {}
    local platforms = {}
    local bundler_version = nil
    local section = nil
    local source_type = nil
    local source_meta = {}
    local current_spec = nil

    local function finish_source_spec()
        current_spec = nil
    end

    local function current_source_fields()
        return {
            sourceType = source_type,
            sourceRemote = source_meta.remote,
            sourceRevision = source_meta.revision,
            sourceBranch = source_meta.branch,
            sourcePath = source_meta.path,
        }
    end

    for _, line in ipairs(split_lines(raw)) do
        if line == "GEM" or line == "GIT" or line == "PATH" or line == "PLUGIN" then
            section = line
            source_type = lower(line)
            source_meta = {}
            finish_source_spec()
        elseif line == "DEPENDENCIES" or line == "PLATFORMS" or line == "BUNDLED WITH" or line == "RUBY VERSION" then
            section = line
            finish_source_spec()
        elseif section == "GEM" or section == "GIT" or section == "PATH" or section == "PLUGIN" then
            local meta_key, meta_value = line:match("^  ([a-z_]+):%s*(.+)$")
            local spec_name, spec_version = line:match("^    ([^%s]+) %(([^)]+)%)$")
            local dep_name = line:match("^      ([^%s(]+)")
            if meta_key ~= nil then
                source_meta[meta_key] = trim(meta_value)
            elseif spec_name ~= nil and spec_version ~= nil then
                current_spec = spec_name
                if by_name[current_spec] == nil then
                    local item = {
                        name = current_spec,
                        packageId = current_spec,
                        version = trim(spec_version),
                        latestVersion = trim(spec_version),
                        installed = true,
                        status = "installed",
                        packageType = "gem",
                        type = "package",
                        extraFields = merge_tables(current_source_fields(), {
                            projectDir = project_dir_value,
                        }),
                        dependencies = {},
                    }
                    by_name[current_spec] = item
                    items[#items + 1] = item
                end
            elseif dep_name ~= nil and current_spec ~= nil and by_name[current_spec] ~= nil then
                by_name[current_spec].dependencies[#by_name[current_spec].dependencies + 1] = trim(dep_name)
            end
        elseif section == "DEPENDENCIES" then
            local dep = line:match("^  ([^!( ]+)")
            if dep ~= nil then
                local constraint = line:match("^  [^ ]+ %((.+)%)")
                dependencies[trim(dep)] = constraint or true
            end
        elseif section == "PLATFORMS" then
            local platform = line:match("^  (.+)$")
            if platform ~= nil then
                platforms[#platforms + 1] = trim(platform)
            end
        elseif section == "BUNDLED WITH" then
            local version = line:match("^   (.+)$") or line:match("^  (.+)$")
            if version ~= nil then
                bundler_version = trim(version)
            end
        end
    end

    for _, item in ipairs(items) do
        local requested = dependencies[item.name]
        item.extraFields = merge_tables(item.extraFields, {
            requestedConstraint = requested ~= true and requested or nil,
            directDependency = requested ~= nil,
            platforms = #platforms > 0 and table.concat(platforms, ", ") or nil,
            bundlerVersion = bundler_version,
        })
        if item.dependencies ~= nil and #item.dependencies == 0 then
            item.dependencies = nil
        end
    end

    sort_by_name(items)
    return items
end

local function load_project_items(dir)
    local content = read_file(lockfile_path_for_dir(dir))
    if content == nil then
        return {}
    end
    return parse_lockfile(content, dir)
end

local function find_item_by_name(items, name)
    local wanted = lower(trim(name))
    for _, item in ipairs(items or {}) do
        if lower(read_field(item, "name")) == wanted then
            return item
        end
    end
    return nil
end

local function parse_outdated_parseable(raw, project_dir_value)
    local items = {}
    for _, line in ipairs(split_lines(raw)) do
        local name, newest, installed, requested = line:match("^([^%s]+) %(newest ([^,]+), installed ([^,%)]+), requested ([^)]+)%)$")
        if name == nil then
            name, newest, installed = line:match("^([^%s]+) %(newest ([^,]+), installed ([^)]+)%)$")
        end
        if name ~= nil then
            items[#items + 1] = {
                name = trim(name),
                packageId = trim(name),
                version = trim(installed),
                latestVersion = trim(newest),
                installed = true,
                status = "outdated",
                packageType = "gem",
                type = "package",
                extraFields = {
                    requestedConstraint = requested and trim(requested) or nil,
                    projectDir = project_dir_value,
                },
            }
        end
    end
    sort_by_name(items)
    return items
end

local function add_command_args(context, package, local_dir)
    local flags = collect_raw_flags(context, { package })
    local args = { "add" }
    local name = package_name(package)
    if local_dir ~= nil then
        args[#args + 1] = "--path"
        args[#args + 1] = local_dir
    end
    local value_flags = {
        { key = "group", option = "--group" },
        { key = "source", option = "--source" },
        { key = "path", option = "--path" },
        { key = "git", option = "--git" },
        { key = "github", option = "--github" },
        { key = "branch", option = "--branch" },
        { key = "ref", option = "--ref" },
        { key = "glob", option = "--glob" },
    }
    for _, spec in ipairs(value_flags) do
        local value = flag_value(flags, spec.key)
        if value ~= nil and value ~= "" and not (local_dir ~= nil and spec.key == "path") then
            args[#args + 1] = spec.option
            args[#args + 1] = value
        end
    end
    local version = package_version(package)
    if version ~= "" then
        args[#args + 1] = "--version"
        args[#args + 1] = version
    end
    for _, flag in ipairs({ "skip-install", "strict", "optimistic", "quiet" }) do
        if has_flag(flags, flag) then
            args[#args + 1] = "--" .. flag
        end
    end
    args[#args + 1] = name
    return args
end

local function update_command_args(context, packages)
    local flags = collect_raw_flags(context, packages)
    local args = { "update" }
    if packages == nil or #packages == 0 then
        args[#args + 1] = "--all"
    else
        for _, package in ipairs(packages) do
            local name = package_name(package)
            if name ~= "" then
                args[#args + 1] = name
            end
        end
    end
    local group = flag_value(flags, "group")
    if group ~= nil and group ~= "" then
        args[#args + 1] = "--group"
        args[#args + 1] = group
    end
    for _, flag in ipairs({ "local", "patch", "minor", "major", "pre", "strict", "conservative" }) do
        if has_flag(flags, flag) then
            args[#args + 1] = "--" .. flag
        end
    end
    return args
end

local function outdated_command_args(context, packages)
    local flags = collect_raw_flags(context, packages)
    local args = { "outdated", "--parseable" }
    local group = flag_value(flags, "group")
    if group ~= nil and group ~= "" then
        args[#args + 1] = "--group"
        args[#args + 1] = group
    end
    for _, flag in ipairs({ "local", "patch", "minor", "major", "pre", "strict" }) do
        if has_flag(flags, flag) then
            args[#args + 1] = "--" .. flag
        end
    end
    for _, package in ipairs(packages or {}) do
        local name = package_name(package)
        if name ~= "" then
            args[#args + 1] = name
        end
    end
    return args
end

local function project_required(context, packages)
    if not command_exists(context, REQUIRED_BINARY) then
        return nil, "bundle binary not available"
    end
    local dir = fallback_project_dir(project_dir(context, packages))
    if not valid_project_dir(dir) then
        return nil, "Gemfile not found in project directory: " .. tostring(dir)
    end
    return dir, nil
end

local function run_remote_info(context, spec)
    local paths, err = ensure_query_project(context, nil, spec)
    if paths == nil then
        return nil, err
    end
    local command = table.concat({
        env_prefix(paths, paths.query_gemfile),
        "BUNDLE_CACHE_PATH=" .. shell_quote(paths.query_vendor_cache),
        REQUIRED_BINARY,
        "lock",
        "--print",
    }, " ")
    local result = exec_run(context, command)
    if not result_success(result) then
        return nil, first_nonempty(result.stderr, result.stdout, "bundle lock --print failed")
    end
    local items = parse_lockfile(result.stdout or "", paths.query)
    return find_item_by_name(items, spec.name), nil
end

local function run_remote_spec(context, name)
    local command = build_gem_command(context, nil, { "specification", name, "--remote", "--yaml", "--norc" })
    local result = exec_run(context, command)
    if not result_success(result) then
        return nil, first_nonempty(result.stderr, result.stdout, "gem specification --remote failed")
    end
    return parse_yaml_spec(result.stdout or ""), nil
end

local function merge_info(installed, remote_lock, remote_spec, context, dir, name)
    local item = shallow_copy(installed or remote_lock or remote_spec or {})
    item.name = first_nonempty(read_field(item, "name"), name)
    item.packageId = first_nonempty(read_field(item, "packageId"), item.name)
    item.version = first_nonempty(read_field(installed, "version"), read_field(remote_lock, "version"), read_field(remote_spec, "version"), read_field(remote_spec, "latestVersion"))
    item.latestVersion = first_nonempty(read_field(remote_lock, "latestVersion"), read_field(remote_spec, "latestVersion"), read_field(installed, "version"))
    item.description = first_nonempty(read_field(remote_spec, "description"), read_field(installed, "description"), read_field(remote_lock, "description"))
    item.homepage = first_nonempty(read_field(remote_spec, "homepage"), read_field(installed, "homepage"), read_field(remote_lock, "homepage"))
    item.license = first_nonempty(read_field(remote_spec, "license"), read_field(installed, "license"), read_field(remote_lock, "license"))
    item.authors = first_nonempty(read_field(remote_spec, "authors"), read_field(installed, "authors"))
    item.dependencies = read_field(installed, "dependencies") or read_field(remote_lock, "dependencies") or read_field(remote_spec, "dependencies")
    item.packageType = "gem"
    item.type = "package"
    item.installed = installed ~= nil
    item.status = installed ~= nil and "installed" or "available"
    item.extraFields = merge_tables(read_field(remote_spec, "extraFields"), merge_tables(read_field(remote_lock, "extraFields"), read_field(installed, "extraFields")))

    if dir ~= nil and installed ~= nil then
        local command = build_bundle_command(context, nil, { "info", name, "--path" }, dir)
        local result = exec_run(context, command)
        if result_success(result) then
            item.extraFields = merge_tables(item.extraFields, {
                gemPath = trim(result.stdout),
            })
        end
    end

    return item
end

plugin.fileExtensions = { ".gem", ".gemspec", ".lock" }

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
    return { "Ruby", "Bundler", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end
    if not command_exists(nil, REQUIRED_BINARY) then
        return requested
    end

    local dir = fallback_project_dir(project_dir(nil, requested))
    if not valid_project_dir(dir) then
        return requested
    end

    local installed = load_project_items(dir)
    local installed_map = {}
    for _, item in ipairs(installed) do
        installed_map[lower(item.name)] = item
    end

    local outdated_map = nil
    local filtered = {}
    for _, package in ipairs(requested) do
        local action = lower(trim(read_field(package, "action") or "install"))
        local item = installed_map[package_lookup_name(package)]
        if action == "remove" then
            if item ~= nil then
                filtered[#filtered + 1] = package
            end
        elseif action == "update" then
            if outdated_map == nil then
                local command, _, actual_dir = build_bundle_command(nil, requested, outdated_command_args(nil, requested), dir)
                local result = exec_run(nil, command)
                outdated_map = {}
                if result ~= nil and (result.success == true or result.exitCode == 1) then
                    for _, outdated in ipairs(parse_outdated_parseable(result.stdout, actual_dir)) do
                        outdated_map[lower(outdated.name)] = true
                    end
                else
                    return requested
                end
            end
            if outdated_map[package_lookup_name(package)] == true then
                filtered[#filtered + 1] = package
            end
        elseif item == nil then
            filtered[#filtered + 1] = package
        end
    end
    return filtered
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    local dir, err = project_required(context, requested)
    if dir == nil then
        tx_failed(context, err)
        return false
    end

    begin_step(context, "install Bundler packages")
    for _, package in ipairs(requested) do
        local name = package_name(package)
        if name == "" then
            tx_failed(context, "bundler package name missing")
            return false
        end
        local command = build_bundle_command(context, { package }, add_command_args(context, package), dir)
        local result = exec_run(context, command)
        if not result_success(result) then
            tx_failed(context, first_nonempty(result.stderr, result.stdout, "bundle add failed"))
            return false
        end
    end

    emit_event(context, "installed", requested)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local target = trim(path)
    local dir, err = project_required(context, {})
    if dir == nil then
        tx_failed(context, err)
        return false
    end

    local local_dir, gem_name, local_err = resolve_local_project(context, target)
    begin_step(context, "install local Bundler package")
    if local_dir == nil or gem_name == nil then
        tx_failed(context, local_err)
        return false
    end

    local command = build_bundle_command(context, nil, { "add", "--path", local_dir, gem_name }, dir)
    local result = exec_run(context, command)
    if not result_success(result) then
        tx_failed(context, first_nonempty(result.stderr, result.stdout, "bundle add --path failed"))
        return false
    end

    emit_event(context, "installed", { path = target, name = gem_name, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    local dir, err = project_required(context, requested)
    if dir == nil then
        tx_failed(context, err)
        return false
    end

    local args = { "remove" }
    for _, package in ipairs(requested) do
        local name = package_name(package)
        if name == "" then
            tx_failed(context, "bundler package name missing")
            return false
        end
        args[#args + 1] = name
    end
    args[#args + 1] = "--install"

    begin_step(context, "remove Bundler packages")
    local command = build_bundle_command(context, requested, args, dir)
    local result = exec_run(context, command)
    if not result_success(result) then
        tx_failed(context, first_nonempty(result.stderr, result.stdout, "bundle remove failed"))
        return false
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    local dir, err = project_required(context, requested)
    if dir == nil then
        tx_failed(context, err)
        return false
    end

    begin_step(context, "update Bundler packages")
    local command = build_bundle_command(context, requested, update_command_args(context, requested), dir)
    local result = exec_run(context, command)
    if not result_success(result) then
        tx_failed(context, first_nonempty(result.stderr, result.stdout, "bundle update failed"))
        return false
    end

    emit_event(context, "updated", requested)
    tx_success(context)
    return true
end

function plugin.list(context)
    local dir = fallback_project_dir(project_dir(context, context_packages(context) or {}))
    if not valid_project_dir(dir) then
        log_warn(context, "Gemfile not found in project directory: " .. tostring(dir))
        emit_event(context, "listed", {})
        return {}
    end

    local items = load_project_items(dir)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local dir = fallback_project_dir(project_dir(context, context_packages(context) or {}))
    if not command_exists(context, REQUIRED_BINARY) or not valid_project_dir(dir) then
        emit_event(context, "outdated", {})
        return {}
    end

    local command = build_bundle_command(context, context_packages(context) or {}, outdated_command_args(context, context_packages(context) or {}), dir)
    local result = exec_run(context, command)
    if result == nil or (result.success ~= true and result.exitCode ~= 1) then
        log_warn(context, first_nonempty(result and result.stderr, result and result.stdout, "bundle outdated failed"))
        emit_event(context, "outdated", {})
        return {}
    end

    local items = parse_outdated_parseable(result.stdout, dir)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned = trim(prompt)
    if cleaned == "" then
        emit_event(context, "searched", {})
        return {}
    end
    if not command_exists(context, GEM_BINARY) then
        log_warn(context, "gem binary not available")
        emit_event(context, "searched", {})
        return {}
    end

    local command = build_gem_command(context, nil, { "search", "--remote", "--details", cleaned, "--norc" })
    local result = exec_run(context, command)
    if not result_success(result) then
        log_warn(context, first_nonempty(result.stderr, result.stdout, "gem search failed"))
        emit_event(context, "searched", {})
        return {}
    end

    local items = parse_remote_detail_blocks(result.stdout)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local target = trim(name)
    if target == "" and context ~= nil then
        target = trim(read_field(context, "prompt"))
    end
    if target == "" then
        emit_event(context, "informed", {})
        return {}
    end

    local dir = fallback_project_dir(project_dir(context, {}))
    local installed = nil
    if valid_project_dir(dir) then
        installed = find_item_by_name(load_project_items(dir), target)
    end

    local remote_lock = nil
    local remote_lock_error = nil
    if command_exists(context, REQUIRED_BINARY) then
        remote_lock, remote_lock_error = run_remote_info(context, { name = target, version = "" })
    end

    local remote_spec = nil
    if command_exists(context, GEM_BINARY) then
        remote_spec = select(1, run_remote_spec(context, target))
    end

    if installed == nil and remote_lock == nil and remote_spec == nil then
        if remote_lock_error ~= nil then
            log_warn(context, remote_lock_error)
        end
        emit_event(context, "informed", {})
        return {}
    end

    local item = merge_info(installed, remote_lock, remote_spec, context, valid_project_dir(dir) and dir or nil, target)
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end
    local name = package_name(package)
    if name == "" then
        return nil
    end
    local item = plugin.info(context, name)
    if type(item) ~= "table" or next(item) == nil then
        return nil
    end
    local version = package_version(package)
    if version ~= "" then
        item.version = version
    end
    return item
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "bundler", "ruby", "rubygems" },
        writeScopes = {
            { kind = "temp" },
            { kind = "user-home-subpath", value = ".cache/reqpack/bundler" },
            { kind = "project-relative", value = "Gemfile" },
            { kind = "project-relative", value = "Gemfile.lock" },
            { kind = "project-relative", value = "vendor/cache" },
        },
        networkScopes = {
            { host = "rubygems.org", scheme = "https", pathPrefix = "/" },
        },
        privilegeLevel = "user",
        osvEcosystem = "RubyGems",
        purlType = "gem",
    }
end

function plugin.init()
    return command_exists(nil, REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

return plugin
