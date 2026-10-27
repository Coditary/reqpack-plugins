plugin = {}

local PLUGIN_ID = "foundry"
local PLUGIN_NAME = "Foundry"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "forge"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return tostring(value or ""):lower()
end

local function non_empty(value)
    local text = trim(value)
    if text == "" then
        return nil
    end
    return text
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
    if #lines > 0 and lines[#lines] == "" then
        lines[#lines] = nil
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

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function is_safe_token(value)
    return tostring(value or ""):match("^[A-Za-z0-9_./:@%%+=,~%-]+$") ~= nil
end

local function shell_arg(value)
    local text = tostring(value or "")
    if is_safe_token(text) then
        return text
    end
    return shell_quote(text)
end

local function build_command(parts)
    local args = {}
    for _, part in ipairs(parts or {}) do
        args[#args + 1] = shell_arg(part)
    end
    return table.concat(args, " ")
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

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        local value = non_empty(os.getenv(name))
        if value ~= nil then
            return value
        end
    end
    return nil
end

local function home_dir()
    return getenv("HOME") or getenv("USERPROFILE") or "/home/test"
end

local function test_fixture_root()
    return trim(getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
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

local function parent_dir(path)
    return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
end

local function basename(path)
    local value = trim(path):gsub("[/\\]+$", "")
    return value:match("[^/\\]+$") or value
end

local function read_file(context, path)
    local result = exec_run(context, "cat " .. shell_quote(path))
    if result ~= nil and result.success == true then
        return result.stdout
    end

    local handle = io.open(path, "r")
    if handle == nil then
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function object_flags(object)
    local value = read_field(object, "flags")
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local flags = {}
    local ok = pcall(function()
        for _, flag in ipairs(value) do
            local cleaned = trim(flag)
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

local function collect_raw_flags(context, packages)
    local flags = {}
    local seen = {}

    local function collect_from(object)
        for _, flag in ipairs(object_flags(object)) do
            append_unique(flags, flag, seen)
        end
    end

    collect_from(context)
    collect_from(read_field(context, "request"))
    for _, pkg in ipairs(packages or {}) do
        collect_from(pkg)
    end
    return flags
end

local function flag_value(flags, key)
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(flags or {}) do
        local text = trim(flag)
        if lower(text):sub(1, #prefix) == prefix then
            return trim(text:sub(#prefix + 1))
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

local function project_dir_from_context(context, packages)
    local flags = collect_raw_flags(context, packages)
    local explicit = flag_value(flags, "dir")
    if explicit ~= nil and explicit ~= "" then
        return explicit
    end

    local env_project = trim(getenv("RQP_FOUNDRY_PROJECT_DIR") or "")
    if env_project ~= "" then
        return env_project
    end

    local fixture_root = test_fixture_root()
    if fixture_root ~= "" then
        return join_path(fixture_root, "project")
    end

    return getenv("PWD") or "."
end

local function shared_paths(context, packages)
    local flags = collect_raw_flags(context, packages)
    local project_dir = project_dir_from_context(context, packages)
    local home_override = flag_value(flags, "home") or getenv("RQP_FOUNDRY_HOME")
    local foundry_home = home_override and trim(home_override) or ""
    if foundry_home == "" then
        local fixture_root = test_fixture_root()
        if fixture_root ~= "" then
            foundry_home = join_path(fixture_root, "home", ".foundry")
        else
            foundry_home = join_path(home_dir(), ".foundry")
        end
    end

    return {
        projectDir = project_dir,
        configPath = join_path(project_dir, "foundry.toml"),
        gitmodulesPath = join_path(project_dir, ".gitmodules"),
        foundryHome = foundry_home,
        foundryCache = join_path(foundry_home, "cache"),
    }
end

local function parse_toml_string(value)
    local text = trim(value)
    if text:sub(1, 1) ~= '"' or text:sub(-1) ~= '"' then
        return nil
    end
    local inner = text:sub(2, -2)
    inner = inner:gsub('\\"', '"')
    inner = inner:gsub("\\n", "\n")
    inner = inner:gsub("\\t", "\t")
    inner = inner:gsub("\\r", "\r")
    inner = inner:gsub("\\\\", "\\")
    return inner
end

local function parse_toml_array_of_strings(value)
    local text = trim(value)
    if text:sub(1, 1) ~= "[" or text:sub(-1) ~= "]" then
        return nil
    end
    local items = {}
    for item in text:gmatch('"(.-)"') do
        items[#items + 1] = item
    end
    return items
end

local function strip_inline_comment(line)
    local text = tostring(line or "")
    local quoted = false
    local escaped = false
    for index = 1, #text do
        local char = text:sub(index, index)
        if escaped then
            escaped = false
        elseif char == "\\" then
            escaped = true
        elseif char == '"' then
            quoted = not quoted
        elseif char == "#" and not quoted then
            return trim(text:sub(1, index - 1))
        end
    end
    return trim(text)
end

local function load_project_config(context, packages)
    local paths = shared_paths(context, packages)
    local config = {
        libs = { "lib" },
        cache_path = "cache",
    }
    local content = read_file(context, paths.configPath)
    if content == nil then
        return config, paths
    end

    for _, raw_line in ipairs(split_lines(content)) do
        local line = strip_inline_comment(raw_line)
        if line ~= "" then
            local key, value = line:match("^([%w_%-]+)%s*=%s*(.+)$")
            if key == "cache_path" then
                config.cache_path = parse_toml_string(value) or config.cache_path
            elseif key == "libs" then
                local libs = parse_toml_array_of_strings(value)
                if libs ~= nil and #libs > 0 then
                    config.libs = libs
                end
            end
        end
    end

    return config, paths
end

local function parse_gitmodules(content)
    local entries = {}
    local current = nil
    for _, raw_line in ipairs(split_lines(content or "")) do
        local line = trim(raw_line)
        local section = line:match('^%[submodule%s+"([^"]+)"%]$')
        if section ~= nil then
            current = { section = section }
        else
            local key, value = line:match("^([%w%-]+)%s*=%s*(.+)$")
            if current ~= nil and key ~= nil then
                current[key] = trim(value)
                if key == "url" and current.path ~= nil then
                    entries[current.path] = current
                elseif key == "path" and current.url ~= nil then
                    entries[current.path] = current
                end
            end
        end
    end
    return entries
end

local function load_gitmodules(context, packages)
    local paths = shared_paths(context, packages)
    local content = read_file(context, paths.gitmodulesPath)
    if content == nil then
        return {}
    end
    return parse_gitmodules(content)
end

local function list_directory_names(context, path)
    local command = "bash -lc " .. shell_quote("if [ -d \"" .. path .. "\" ]; then find \"" .. path .. "\" -mindepth 1 -maxdepth 1 -type d -printf '%f\\n' | sort; fi")
    local result = exec_run(context, command)
    if result == nil or result.success ~= true then
        return {}
    end

    local items = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            items[#items + 1] = cleaned
        end
    end
    return items
end

local function query_git_value(context, path, args)
    local parts = { "git", "-C", path }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = arg
    end
    local result = exec_run(context, build_command(parts))
    if result == nil or result.success ~= true then
        return nil
    end
    for _, line in ipairs(split_lines(result.stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            return cleaned
        end
    end
    return nil
end

local function canonical_source(value)
    local text = trim(value)
    if text == "" then
        return nil
    end
    local github = text:match("github%.com[:/]([^%s]+)$")
    if github ~= nil then
        github = github:gsub("%.git$", "")
        return github
    end
    return text:gsub("%.git$", "")
end

local function infer_dependency_name(source, path)
    local canonical = canonical_source(source)
    if canonical ~= nil then
        return canonical:match("([^/]+)$") or canonical
    end
    return basename(path)
end

local function looks_like_dependency_spec(value)
    local text = trim(value)
    if text == "" then
        return false
    end
    if text:find("://", 1, true) ~= nil then
        return true
    end
    if text:find("/", 1, true) ~= nil then
        return true
    end
    if text:find("=", 1, true) ~= nil then
        return true
    end
    if text:find("@", 1, true) ~= nil then
        return true
    end
    return text:find("%s") == nil
end

local function normalize_package_request(pkg)
    local flags = collect_raw_flags(nil, type(pkg) == "table" and { pkg } or {})
    local raw = trim(read_field(pkg, "packageId") or read_field(pkg, "name") or pkg or "")
    local alias = flag_value(flags, "alias")
    local source = raw

    if source:find("=", 1, true) ~= nil then
        local left, right = source:match("^([^=]+)=(.+)$")
        if left ~= nil and right ~= nil then
            alias = alias or trim(left)
            source = trim(right)
        end
    end

    local source_without_ref = source
    local explicit_ref = nil
    if source_without_ref:find("@", 1, true) ~= nil then
        source_without_ref, explicit_ref = source_without_ref:match("^(.+)@(.+)$")
        source_without_ref = trim(source_without_ref or source)
        explicit_ref = trim(explicit_ref or "")
    end

    local version = trim(read_field(pkg, "version") or "")
    local ref = explicit_ref
    if ref == "" then
        ref = nil
    end
    if ref == nil then
        local tag = flag_value(flags, "tag")
        local branch = flag_value(flags, "branch")
        local rev = flag_value(flags, "rev")
        if tag ~= nil and tag ~= "" then
            ref = "tag=" .. tag
        elseif branch ~= nil and branch ~= "" then
            ref = "branch=" .. branch
        elseif rev ~= nil and rev ~= "" then
            ref = "rev=" .. rev
        elseif version ~= "" then
            ref = version
        end
    end

    return {
        raw = raw,
        alias = alias,
        source = source_without_ref,
        ref = ref,
        version = version,
        canonicalSource = canonical_source(source_without_ref),
    }
end

local function build_install_spec(pkg)
    local normalized = normalize_package_request(pkg)
    local source = trim(normalized.source)
    if source == "" then
        return nil, "foundry dependency name missing"
    end
    local spec = source
    if normalized.ref ~= nil and normalized.ref ~= "" and source:find("@", 1, true) == nil then
        spec = spec .. "@" .. normalized.ref
    end
    if normalized.alias ~= nil and normalized.alias ~= "" then
        spec = normalized.alias .. "=" .. spec
    end
    return spec, nil
end

local function package_match_keys(pkg)
    local normalized = normalize_package_request(pkg)
    local keys = {}
    local seen = {}
    local function add(value)
        local text = lower(trim(value))
        if text ~= "" and not seen[text] then
            seen[text] = true
            keys[#keys + 1] = text
        end
    end
    add(read_field(pkg, "name"))
    add(read_field(pkg, "packageId"))
    add(normalized.alias)
    add(normalized.source)
    add(normalized.canonicalSource)
    return keys, normalized
end

local function build_item(paths, lib_root, rel_path, installed_name, source, revision, version)
    local canonical = canonical_source(source)
    local display_name = trim(installed_name)
    local package_id = canonical or display_name
    local extra = {
        installPath = join_path(paths.projectDir, rel_path),
        relativePath = rel_path,
        libPath = join_path(paths.projectDir, lib_root),
        projectCachePath = join_path(paths.projectDir, "cache"),
        globalFoundryHome = paths.foundryHome,
        globalCachePath = paths.foundryCache,
    }
    if source ~= nil and trim(source) ~= "" then
        extra.source = source
    end
    if canonical ~= nil and canonical ~= package_id then
        extra.canonicalSource = canonical
    elseif canonical ~= nil then
        extra.canonicalSource = canonical
    end
    if revision ~= nil then
        extra.revision = revision
    end

    return {
        name = display_name,
        packageId = package_id,
        version = version or "",
        latestVersion = version or nil,
        installed = true,
        status = "installed",
        summary = "Installed Foundry dependency",
        description = "Installed Foundry dependency in current workspace",
        packageType = "dependency",
        type = "package",
        manager = PLUGIN_ID,
        system = PLUGIN_ID,
        extraFields = extra,
    }
end

local function sort_items(items)
    table.sort(items, function(left, right)
        local left_key = lower(left.packageId or left.name or "")
        local right_key = lower(right.packageId or right.name or "")
        if left_key == right_key then
            return lower(left.version or "") < lower(right.version or "")
        end
        return left_key < right_key
    end)
    return items
end

local function collect_installed_items(context)
    local config, paths = load_project_config(context, {})
    local gitmodules = load_gitmodules(context, {})
    local items = {}
    local seen = {}

    for rel_path, gitmodule in pairs(gitmodules or {}) do
        local dep_dir = join_path(paths.projectDir, rel_path)
        local lib_root = rel_path:match("^(.-)/[^/]+$") or "lib"
        local dir_name = basename(rel_path)
        local source = read_field(gitmodule, "url")
        local revision = query_git_value(context, dep_dir, { "rev-parse", "--short", "HEAD" })
        local tag = query_git_value(context, dep_dir, { "describe", "--tags", "--exact-match" })
        local version = tag or revision or ""
        local item = build_item(paths, lib_root, rel_path, dir_name, source, revision, version)
        local key = lower(item.packageId .. "|" .. (item.extraFields and item.extraFields.installPath or ""))
        if not seen[key] then
            seen[key] = true
            items[#items + 1] = item
        end
    end

    for _, lib_root in ipairs(config.libs or { "lib" }) do
        local lib_dir = join_path(paths.projectDir, lib_root)
        for _, dir_name in ipairs(list_directory_names(context, lib_dir)) do
            local rel_path = join_path(lib_root, dir_name)
            local dep_dir = join_path(paths.projectDir, rel_path)
            local gitmodule = gitmodules[rel_path]
            local source = read_field(gitmodule, "url") or query_git_value(context, dep_dir, { "config", "--get", "remote.origin.url" })
            local revision = query_git_value(context, dep_dir, { "rev-parse", "--short", "HEAD" })
            local tag = query_git_value(context, dep_dir, { "describe", "--tags", "--exact-match" })
            local version = tag or revision or ""
            local item = build_item(paths, lib_root, rel_path, dir_name, source, revision, version)
            local key = lower(item.packageId .. "|" .. (item.extraFields and item.extraFields.installPath or ""))
            if not seen[key] then
                seen[key] = true
                items[#items + 1] = item
            end
        end
    end
    return sort_items(items)
end

local function find_item_for_query(items, query)
    local needle = lower(trim(query))
    if needle == "" then
        return nil
    end
    for _, item in ipairs(items or {}) do
        local extra = read_field(item, "extraFields") or {}
        local haystacks = {
            item.name,
            item.packageId,
            read_field(extra, "source"),
            read_field(extra, "canonicalSource"),
            read_field(extra, "relativePath"),
            read_field(extra, "installPath"),
        }
        for _, candidate in ipairs(haystacks) do
            if lower(candidate or "") == needle then
                return item
            end
        end
        for _, candidate in ipairs(haystacks) do
            if lower(candidate or ""):find(needle, 1, true) ~= nil then
                return item
            end
        end
    end
    return nil
end

local function synthetic_item(context, query)
    local cleaned = trim(query)
    if cleaned == "" then
        return {}
    end
    local _, paths = load_project_config(context, {})
    local normalized = normalize_package_request({ name = cleaned })
    local display_name = normalized.alias or infer_dependency_name(normalized.source, cleaned)
    local package_id = normalized.canonicalSource or normalized.source or cleaned
    local extra = {
        source = normalized.source,
        canonicalSource = normalized.canonicalSource,
        projectCachePath = join_path(paths.projectDir, "cache"),
        globalFoundryHome = paths.foundryHome,
        globalCachePath = paths.foundryCache,
        installStrategy = "forge install",
    }
    if normalized.alias ~= nil and normalized.alias ~= "" then
        extra.alias = normalized.alias
    end
    if normalized.ref ~= nil and normalized.ref ~= "" then
        extra.requestedRef = normalized.ref
    end
    return {
        name = display_name,
        packageId = package_id,
        version = normalized.ref or "",
        latestVersion = normalized.ref or nil,
        installed = false,
        status = "available",
        summary = "Installable Foundry dependency spec",
        description = "Foundry dependency spec that can be installed with forge",
        packageType = "dependency-spec",
        type = "package",
        manager = PLUGIN_ID,
        system = PLUGIN_ID,
        extraFields = extra,
    }
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
    return { "package-manager", "solidity", "ethereum", "smart-contracts" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end

    local listed = collect_installed_items(nil)
    if type(listed) ~= "table" then
        return requested
    end

    local filtered = {}
    for _, pkg in ipairs(requested) do
        local keys, normalized = package_match_keys(pkg)
        local wanted_version = trim(normalized.version or normalized.ref or "")
        local found = false
        for _, item in ipairs(listed) do
            local extra = read_field(item, "extraFields") or {}
            local candidates = {
                lower(item.name or ""),
                lower(item.packageId or ""),
                lower(read_field(extra, "source") or ""),
                lower(read_field(extra, "canonicalSource") or ""),
            }
            for _, key in ipairs(keys) do
                for _, candidate in ipairs(candidates) do
                    if key ~= "" and candidate == key then
                        if wanted_version ~= "" and trim(item.version or "") ~= "" and trim(item.version or "") ~= wanted_version then
                            found = false
                        else
                            found = true
                        end
                        break
                    end
                end
                if found then
                    break
                end
            end
            if found then
                break
            end
        end
        if not found then
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
    if not command_exists(context, REQUIRED_BINARY) then
        return fail_action(context, REQUIRED_BINARY .. " binary not available")
    end

    begin_step(context, "install Foundry dependencies")
    local project_dir = project_dir_from_context(context, requested)
    for _, pkg in ipairs(requested) do
        local spec, err = build_install_spec(pkg)
        if spec == nil then
            return fail_action(context, err)
        end
        local flags = collect_raw_flags(context, { pkg })
        local parts = { REQUIRED_BINARY, "install", "--root", project_dir }
        if has_flag(flags, "shallow") then
            parts[#parts + 1] = "--shallow"
        end
        if has_flag(flags, "no-git") then
            parts[#parts + 1] = "--no-git"
        end
        if has_flag(flags, "commit") then
            parts[#parts + 1] = "--commit"
        end
        parts[#parts + 1] = spec
        local result = exec_run(context, build_command(parts))
        if result == nil or result.success ~= true then
            return fail_action(context, "forge install failed for " .. spec)
        end
    end

    emit_event(context, "installed", requested)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    begin_step(context, "install local Foundry dependency")
    tx_failed(context, "foundry does not support local artifact installs")
    emit_event(context, "failed", path)
    return false
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        return fail_action(context, REQUIRED_BINARY .. " binary not available")
    end

    begin_step(context, "remove Foundry dependencies")
    local project_dir = project_dir_from_context(context, requested)
    for _, pkg in ipairs(requested) do
        local target = trim(read_field(pkg, "packageId") or read_field(pkg, "name") or "")
        if target == "" then
            return fail_action(context, "foundry dependency name missing")
        end
        local result = exec_run(context, build_command({ REQUIRED_BINARY, "remove", "--root", project_dir, target }))
        if result == nil or result.success ~= true then
            return fail_action(context, "forge remove failed for " .. target)
        end
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    if not command_exists(context, REQUIRED_BINARY) then
        return fail_action(context, REQUIRED_BINARY .. " binary not available")
    end

    begin_step(context, "update Foundry dependencies")
    local project_dir = project_dir_from_context(context, requested)
    local flags = collect_raw_flags(context, requested)
    local base = { REQUIRED_BINARY, "update", "--root", project_dir }
    if has_flag(flags, "force") then
        base[#base + 1] = "--force"
    end
    if has_flag(flags, "recursive") then
        base[#base + 1] = "--recursive"
    end

    if #requested == 0 then
        local result = exec_run(context, build_command(base))
        if result == nil or result.success ~= true then
            return fail_action(context, "forge update failed")
        end
    else
        for _, pkg in ipairs(requested) do
            local target = trim(read_field(pkg, "packageId") or read_field(pkg, "name") or "")
            if target == "" then
                return fail_action(context, "foundry dependency name missing")
            end
            local parts = shallow_copy(base)
            parts[#parts + 1] = target
            local result = exec_run(context, build_command(parts))
            if result == nil or result.success ~= true then
                return fail_action(context, "forge update failed for " .. target)
            end
        end
    end

    emit_event(context, "updated", requested)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = collect_installed_items(context)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items = {}
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

    local items = {}
    local listed = collect_installed_items(context)
    local needle = lower(query)
    for _, item in ipairs(listed) do
        local extra = read_field(item, "extraFields") or {}
        local haystacks = {
            item.name,
            item.packageId,
            read_field(extra, "source"),
            read_field(extra, "canonicalSource"),
            read_field(extra, "relativePath"),
        }
        for _, candidate in ipairs(haystacks) do
            if lower(candidate or ""):find(needle, 1, true) ~= nil then
                items[#items + 1] = item
                break
            end
        end
    end

    if #items == 0 and looks_like_dependency_spec(query) then
        items[#items + 1] = synthetic_item(context, query)
    end

    emit_event(context, "searched", sort_items(items))
    return sort_items(items)
end

function plugin.info(context, name)
    local target = trim(name or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
    if target == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local listed = collect_installed_items(context)
    local item = find_item_for_query(listed, target)
    if item == nil then
        item = synthetic_item(context, target)
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local listed = collect_installed_items(context)
    local item = find_item_for_query(listed, read_field(package, "packageId") or read_field(package, "name") or "")
    if item ~= nil then
        return item
    end
    return synthetic_item(context, read_field(package, "packageId") or read_field(package, "name") or "")
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
        capabilities = { "exec", "network" },
        ecosystemScopes = { "foundry", "solidity", "ethereum" },
        writeScopes = {
            "project-relative:lib",
            "project-relative:cache",
            "project-relative:.gitmodules",
            "project-relative:.git/config",
            "user-home-subpath:.foundry",
        },
        networkScopes = {
            { scheme = "https" },
            { scheme = "http" },
            { scheme = "ssh" },
            { scheme = "git" },
            { scheme = "file" },
        },
        privilegeLevel = "user",
        purlType = "generic",
        versionComparatorProfile = "lexicographic",
    }
end

return plugin
