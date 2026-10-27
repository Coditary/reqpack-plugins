plugin = {}

local PLUGIN_NAME = "odpkg"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "odpkg"
local CONFIG_FILE = "odpkg.toml"
local LOCK_FILE = "odpkg.lock"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function read_proc_environ_value(name)
    if os ~= nil and type(os.getenv) == "function" then
        local current = os.getenv(tostring(name or ""))
        if current ~= nil and current ~= "" then
            return trim(current)
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

local function runtime_expand(value)
    local text = tostring(value or "")
    local fixture_root = trim(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT") or read_proc_environ_value("fixtureRoot") or "")
    if fixture_root ~= nil then
        text = text:gsub("%${fixtureRoot}", fixture_root)
    end
    return text
end

local function escaped_pattern(text)
    return tostring(text or ""):gsub("([%(%)%%%.%+%-%*%?%[%]%^%$])", "%%%1")
end

local function lower(value)
    return tostring(value or ""):lower()
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
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
            local cleaned = trim(value)
            if cleaned ~= "" then
                return cleaned
            end
        end
    end
    return nil
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

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(runtime_expand(select(index, ...)))
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

local function list_flags(object)
    local flags = {}
    for _, item in ipairs(sequence_values(read_field(object, "flags"))) do
        local cleaned = trim(item)
        if cleaned ~= "" then
            flags[#flags + 1] = cleaned
        end
    end
    return flags
end

local function append_unique(list, seen, value)
    local cleaned = trim(value)
    if cleaned == "" or seen[cleaned] then
        return
    end
    seen[cleaned] = true
    list[#list + 1] = cleaned
end

local function collect_flags(context, packages)
    local result = {}
    local seen = {}
    local function add_from(object)
        for _, flag in ipairs(list_flags(object)) do
            append_unique(result, seen, flag)
        end
    end
    add_from(context)
    for _, package in ipairs(packages or {}) do
        add_from(package)
    end
    return result
end

local function flag_value(flags, key)
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            return trim(runtime_expand(cleaned:sub(#prefix + 1)))
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

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function is_success(result)
    return type(result) == "table" and (result.success == true or result.ok == true or result.exitCode == 0)
end

local function env_prefix(context, packages)
    local flags = collect_flags(context, packages or {})
    local parts = {
        "NO_COLOR=1",
        "LC_ALL=C",
        "LANG=C",
        "LANGUAGE=C",
    }
    local cache_home = flag_value(flags, "cache-home")
    if cache_home ~= nil then
        parts[#parts + 1] = "XDG_CACHE_HOME=" .. shell_quote(cache_home)
    end
    return table.concat(parts, " ")
end

local function join_args(args)
    local parts = {}
    for _, arg in ipairs(args or {}) do
        if arg ~= nil then
            parts[#parts + 1] = tostring(arg)
        end
    end
    return table.concat(parts, " ")
end

local function build_global_command(context, packages, args)
    return env_prefix(context, packages) .. " odpkg " .. join_args(args)
end

local function build_project_command(context, packages, args)
    local root = first_nonempty(flag_value(collect_flags(context, packages or {}), "cwd"), ".")
    local inner = "cd " .. shell_quote(runtime_expand(root)) .. " && odpkg " .. join_args(args)
    return env_prefix(context, packages) .. " sh -lc \"" .. inner:gsub('"', '\\"') .. "\""
end

local function read_file(context, path)
    path = runtime_expand(path)
    local handle = io.open(path, "r")
    if handle ~= nil then
        local content = handle:read("*a")
        handle:close()
        return content
    end
    local result = exec_run(context, "cat " .. shell_quote(path))
    if is_success(result) then
        return result.stdout or ""
    end
    return nil
end

local function dir_exists(context, path)
    path = runtime_expand(path)
    local result = exec_run(context, "test -d " .. shell_quote(path))
    return is_success(result)
end

local function project_root(context, packages)
    local fixture_root = trim(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT") or "")
    return first_nonempty(
        flag_value(collect_flags(context, packages or {}), "cwd"),
        -- Test runner only gives env + flags, not cwd/workspace fields.
        fixture_root ~= "" and join_path(fixture_root, "project") or nil,
        "."
    )
end

local function ensure_project(context, packages)
    local root = project_root(context, packages)
    if read_file(context, join_path(root, CONFIG_FILE)) ~= nil then
        return true, root
    end
    return false, root, "odpkg plugin requires project root containing odpkg.toml"
end

local function repo_name_from(repo)
    local cleaned = trim(repo):gsub("%.git$", "")
    return cleaned:match("([^/]+)$") or cleaned
end

local function parse_repo_spec(spec)
    local value = trim(spec)
    if value == "" then
        return nil, nil
    end
    if value:match("^https://github%.com/") then
        value = value:sub(#"https://github.com/" + 1)
    elseif value:match("^http://github%.com/") then
        value = value:sub(#"http://github.com/" + 1)
    elseif value:match("^github%.com/") then
        value = value:sub(#"github.com/" + 1)
    elseif value:match("://") then
        return nil, nil
    end
    local ref = nil
    local at = value:find("@", 1, true)
    if at ~= nil then
        ref = trim(value:sub(at + 1))
        value = trim(value:sub(1, at - 1))
    end
    value = value:gsub("%.git$", "")
    if value == "" or value:find("/", 1, true) == nil then
        return nil, nil
    end
    return value, ref
end

local function parse_inline_dep(raw)
    local text = trim(raw)
    if not text:match("^%b{}$") then
        return nil, nil
    end
    text = trim(text:sub(2, -2))
    local repo = nil
    local ref = nil
    for part in (text .. ","):gmatch("(.-),") do
        local key, value = part:match("^%s*([%w_%-]+)%s*=%s*(.-)%s*$")
        if key ~= nil and value ~= nil then
            value = trim(value)
            if value:match('^".*"$') or value:match("^'.*'$") then
                value = value:sub(2, -2)
            end
            if key == "repo" then
                repo = value
            elseif key == "ref" then
                ref = value
            end
        end
    end
    if repo == nil then
        return nil, nil
    end
    local normalized_repo, inferred_ref = parse_repo_spec(repo)
    if normalized_repo == nil then
        return nil, nil
    end
    return normalized_repo, first_nonempty(ref, inferred_ref)
end

local function parse_dep_value(raw)
    local text = trim(raw)
    if text:match("^%b{}$") then
        return parse_inline_dep(text)
    end
    if text:match('^".*"$') or text:match("^'.*'$") then
        text = text:sub(2, -2)
    end
    return parse_repo_spec(text)
end

local function parse_config(text)
    local config = {
        name = nil,
        version = nil,
        odinVersion = nil,
        vendorDir = "vendor",
        deps = {},
    }
    local section = ""
    for _, line in ipairs(split_lines(text)) do
        local cleaned = trim(line)
        if cleaned ~= "" and cleaned:sub(1, 1) ~= "#" then
            local comment = cleaned:find("#", 1, true)
            if comment ~= nil then
                cleaned = trim(cleaned:sub(1, comment - 1))
            end
            if cleaned:match("^%[.-%]$") then
                section = cleaned:sub(2, -2)
            else
                local key, raw = cleaned:match("^([%w_%-]+)%s*=%s*(.-)%s*$")
                if key ~= nil then
                    if section == "odpkg" then
                        local value = raw
                        if value:match('^".*"$') or value:match("^'.*'$") then
                            value = value:sub(2, -2)
                        end
                        if key == "name" then
                            config.name = value
                        elseif key == "version" then
                            config.version = value
                        elseif key == "odin_version" then
                            config.odinVersion = value
                        elseif key == "vendor_dir" and trim(value) ~= "" then
                            config.vendorDir = value
                        end
                    elseif section == "dependencies" then
                        local repo, ref = parse_dep_value(raw)
                        if repo ~= nil then
                            config.deps[#config.deps + 1] = {
                                name = key,
                                packageId = key,
                                repo = repo,
                                ref = ref,
                            }
                        end
                    end
                end
            end
        end
    end
    return config
end

local function parse_lock(text)
    local blocks = {}
    local current = nil
    for _, line in ipairs(split_lines(text)) do
        local cleaned = trim(line)
        if cleaned == "[[deps]]" then
            current = {}
            blocks[#blocks + 1] = current
        elseif current ~= nil then
            local key, value = cleaned:match("^([%w_%-]+)%s*=%s*(.-)%s*$")
            if key ~= nil then
                if value:match('^".*"$') or value:match("^'.*'$") then
                    value = value:sub(2, -2)
                end
                current[key] = value
            end
        end
    end
    return blocks
end

local function lock_lookup(blocks)
    local lookup = {}
    for _, block in ipairs(blocks or {}) do
        local name = trim(block.name)
        if name ~= "" then
            lookup[lower(name)] = block
        end
    end
    return lookup
end

local function parse_registry_rows(text)
    local items = {}
    for _, line in ipairs(split_lines(text)) do
        local slug, repo, status = line:match("^%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*$")
        if slug ~= nil and repo ~= nil and status ~= nil then
            items[#items + 1] = {
                name = trim(slug),
                packageId = trim(slug),
                source = trim(repo),
                homepage = trim(repo),
                status = trim(status),
                packageType = "odin-package",
                type = "package",
            }
        end
    end
    return items
end

local function json_unescape(value)
    local text = tostring(value or "")
    text = text:gsub('\\"', '"')
    text = text:gsub("\\/", "/")
    text = text:gsub("\\n", "\n")
    text = text:gsub("\\r", "\r")
    text = text:gsub("\\t", "\t")
    text = text:gsub("\\\\", "\\")
    return text
end

local function json_object_chunks(text)
    local chunks = {}
    local depth = 0
    local start_index = nil
    local in_string = false
    local escaped = false
    for index = 1, #text do
        local ch = text:sub(index, index)
        if in_string then
            if escaped then
                escaped = false
            elseif ch == "\\" then
                escaped = true
            elseif ch == '"' then
                in_string = false
            end
        else
            if ch == '"' then
                in_string = true
            elseif ch == "{" then
                depth = depth + 1
                if depth == 1 then
                    start_index = index
                end
            elseif ch == "}" then
                if depth > 0 then
                    depth = depth - 1
                    if depth == 0 and start_index ~= nil then
                        chunks[#chunks + 1] = text:sub(start_index, index)
                        start_index = nil
                    end
                end
            end
        end
    end
    return chunks
end

local function json_field(object_text, key)
    local escaped_key = escaped_pattern(key)
    local prefix = '"' .. escaped_key .. '"%s*:%s*"'
    local start_index, end_index = object_text:find(prefix)
    if start_index == nil then
        return nil
    end
    local index = end_index + 1
    local parts = {}
    local escaped = false
    while index <= #object_text do
        local ch = object_text:sub(index, index)
        if escaped then
            parts[#parts + 1] = "\\" .. ch
            escaped = false
        elseif ch == "\\" then
            escaped = true
        elseif ch == '"' then
            return json_unescape(table.concat(parts))
        else
            parts[#parts + 1] = ch
        end
        index = index + 1
    end
    return nil
end

local function json_number_field(object_text, key)
    return object_text:match('"' .. escaped_pattern(key) .. '"%s*:%s*(%-?%d+)')
end

local function parse_registry_cache(text)
    local items = {}
    for _, object_text in ipairs(json_object_chunks(text or "")) do
        local slug = json_field(object_text, "slug")
        if slug ~= nil then
            items[#items + 1] = {
                id = json_number_field(object_text, "id"),
                slug = slug,
                displayName = json_field(object_text, "display_name"),
                description = json_field(object_text, "description"),
                status = json_field(object_text, "status"),
                packageKind = json_field(object_text, "type"),
                repositoryUrl = json_field(object_text, "repository_url"),
                license = json_field(object_text, "license"),
            }
        end
    end
    return items
end

local function registry_cache_path(context, packages)
    local flags = collect_flags(context, packages or {})
    local cache_home = flag_value(flags, "cache-home")
    if cache_home ~= nil then
        return join_path(cache_home, "odpkg", "packages.json")
    end
    local home = nil
    if os ~= nil and type(os.getenv) == "function" then
        home = first_nonempty(os.getenv("HOME"), os.getenv("USERPROFILE"))
    end
    home = home or "/home/test"
    return join_path(home, ".cache", "odpkg", "packages.json")
end

local function read_project_state(context, packages)
    local ok, root = ensure_project(context, packages)
    if not ok then
        return nil, nil, nil
    end
    local config_text = read_file(context, join_path(root, CONFIG_FILE))
    local config = parse_config(config_text)
    local lock_text = read_file(context, join_path(root, LOCK_FILE))
    local locks = lock_lookup(lock_text ~= nil and parse_lock(lock_text) or {})
    local items = {}
    for _, dep in ipairs(config.deps or {}) do
        local locked = locks[lower(dep.name)] or {}
        local installed = dir_exists(context, join_path(root, config.vendorDir or "vendor", dep.name))
        items[#items + 1] = {
            name = dep.name,
            packageId = dep.name,
            version = first_nonempty(locked.commit, dep.ref),
            requestedVersion = dep.ref,
            source = dep.repo ~= nil and ("https://github.com/" .. dep.repo) or nil,
            repository = dep.repo,
            commit = locked.commit,
            hash = locked.hash,
            installed = installed,
            status = installed and "installed" or "configured",
            packageType = "odin-package",
            type = "package",
            extraFields = {
                repo = dep.repo,
                ref = dep.ref,
                commit = locked.commit,
                hash = locked.hash,
                vendorDir = config.vendorDir,
                projectRoot = root,
            },
        }
    end
    return config, items, root
end

local function alias_from_package(package, context, all_packages)
    local flags = collect_flags(context, all_packages or {})
    local raw_name = first_nonempty(read_field(package, "name"), read_field(package, "packageId"))
    local repo = first_nonempty(read_field(package, "repo"), read_field(package, "repository"), read_field(package, "url"))
    local alias = first_nonempty(read_field(package, "alias"), read_field(package, "target"))
    local registry_mode = has_flag(collect_flags(context, { package }), "registry") or lower(read_field(package, "source")) == "registry"
    if alias ~= nil then
        return alias
    end
    if registry_mode then
        return raw_name
    end
    if repo ~= nil then
        if raw_name ~= nil then
            local parsed_name = parse_repo_spec(raw_name)
            if parsed_name == nil then
                return raw_name
            end
        end
        return repo_name_from(repo)
    end
    if raw_name ~= nil then
        local parsed_repo = parse_repo_spec(raw_name)
        if parsed_repo ~= nil then
            return repo_name_from(raw_name)
        end
        return raw_name
    end
    if #sequence_values(all_packages or {}) == 1 then
        return flag_value(flags, "alias")
    end
    return nil
end

local function install_spec_from_package(package, context, all_packages)
    local raw_name = first_nonempty(read_field(package, "name"), read_field(package, "packageId"))
    local version = first_nonempty(read_field(package, "version"), read_field(package, "ref"))
    local repo = first_nonempty(read_field(package, "repo"), read_field(package, "repository"), read_field(package, "url"))
    local registry_mode = has_flag(collect_flags(context, { package }), "registry") or lower(read_field(package, "source")) == "registry"
    local alias = alias_from_package(package, context, all_packages)
    if registry_mode then
        local slug = first_nonempty(read_field(package, "slug"), raw_name)
        if slug == nil then
            return nil, nil, nil, "missing registry slug"
        end
        return "registry", slug, alias, nil
    end
    if repo == nil then
        repo = raw_name
    end
    local normalized_repo, embedded_ref = parse_repo_spec(repo)
    if normalized_repo == nil then
        return nil, nil, nil, "missing repo spec"
    end
    local final_ref = first_nonempty(version, embedded_ref)
    local selector = normalized_repo
    if final_ref ~= nil and selector:find("@", 1, true) == nil then
        selector = selector .. "@" .. final_ref
    end
    return "repo", selector, alias, nil
end

local function package_name(package)
    return first_nonempty(read_field(package, "name"), read_field(package, "packageId"), read_field(package, "alias"))
end

local function find_project_item(items, name)
    local query = lower(trim(name))
    for _, item in ipairs(items or {}) do
        if lower(item.name or "") == query or lower(item.packageId or "") == query then
            return item
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
    return { "odin", "package-manager", "vendor" }
end

function plugin.init()
    return command_exists(nil, REQUIRED_BINARY)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "odin", "odpkg", "git", "github" },
        writeScopes = {
            "project-file:odpkg.toml",
            "project-file:odpkg.lock",
            "project-subpath:vendor",
            "user-home-subpath:.cache/odpkg",
        },
        networkScopes = { "api.pkg-odin.org", "github.com" },
        privilegeLevel = "none",
        purlType = "generic",
    }
end

function plugin.getMissingPackages(packages)
    packages = packages or {}
    if #packages == 0 then
        return {}
    end
    local config, items = read_project_state(nil, packages)
    if config == nil or items == nil then
        return packages
    end
    local missing = {}
    for _, package in ipairs(packages) do
        local action = lower(read_field(package, "action") or "install")
        local alias = alias_from_package(package, nil, packages)
        local item = alias ~= nil and find_project_item(items, alias) or nil
        if action == "remove" or action == "update" then
            if item ~= nil then
                missing[#missing + 1] = package
            end
        else
            if item == nil or item.installed ~= true then
                missing[#missing + 1] = package
            end
        end
    end
    return missing
end

function plugin.install(context, packages)
    packages = packages or {}
    if #packages == 0 then
        tx_success(context)
        emit_event(context, "success", "ok")
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "odpkg binary not available")
        return false
    end
    local ok, _, err = ensure_project(context, packages)
    if not ok then
        tx_failed(context, err)
        return false
    end
    for _, package in ipairs(packages) do
        local mode, selector, alias, package_err = install_spec_from_package(package, context, packages)
        if mode == nil then
            tx_failed(context, "odpkg install failed: " .. tostring(package_err or "invalid package"))
            return false
        end
        begin_step(context, "Add odpkg dependency " .. tostring(alias or selector))
        local args = { "add" }
        if mode == "registry" then
            args[#args + 1] = "--registry"
            args[#args + 1] = shell_quote(selector)
        else
            args[#args + 1] = shell_quote(selector)
        end
        if alias ~= nil and alias ~= selector then
            args[#args + 1] = shell_quote(alias)
        end
        local result = exec_run(context, build_project_command(context, packages, args))
        if not is_success(result) then
            tx_failed(context, first_nonempty(result.stderr, result.stdout, "odpkg add failed"))
            return false
        end
    end
    begin_step(context, "Install odpkg dependencies")
    local install_result = exec_run(context, build_project_command(context, packages, { "install" }))
    if not is_success(install_result) then
        tx_failed(context, first_nonempty(install_result.stderr, install_result.stdout, "odpkg install failed"))
        return false
    end
    local _, items = read_project_state(context, packages)
    local installed = {}
    for _, package in ipairs(packages) do
        local alias = alias_from_package(package, context, packages)
        local item = alias ~= nil and find_project_item(items or {}, alias) or nil
        installed[#installed + 1] = item or {
            name = alias or package_name(package),
            packageId = alias or package_name(package),
            packageType = "odin-package",
            type = "package",
        }
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.installLocal(context, path)
    tx_failed(context, "odpkg installLocal is not supported")
    return false
end

function plugin.remove(context, packages)
    packages = packages or {}
    if #packages == 0 then
        tx_success(context)
        emit_event(context, "success", "ok")
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "odpkg binary not available")
        return false
    end
    local ok, _, err = ensure_project(context, packages)
    if not ok then
        tx_failed(context, err)
        return false
    end
    local deleted = {}
    for _, package in ipairs(packages) do
        local name = alias_from_package(package, context, packages) or package_name(package)
        if name == nil then
            tx_failed(context, "odpkg remove requires dependency alias")
            return false
        end
        begin_step(context, "Remove odpkg dependency " .. name)
        local result = exec_run(context, build_project_command(context, packages, { "remove", shell_quote(name) }))
        if not is_success(result) then
            tx_failed(context, first_nonempty(result.stderr, result.stdout, "odpkg remove failed"))
            return false
        end
        deleted[#deleted + 1] = {
            name = name,
            packageId = name,
            packageType = "odin-package",
            type = "package",
        }
    end
    emit_event(context, "deleted", deleted)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.update(context, packages)
    packages = packages or {}
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "odpkg binary not available")
        return false
    end
    local ok, _, err = ensure_project(context, packages)
    if not ok then
        tx_failed(context, err)
        return false
    end
    local _, items = read_project_state(context, packages)
    for _, package in ipairs(packages) do
        local name = alias_from_package(package, context, packages) or package_name(package)
        if name == nil or find_project_item(items or {}, name) == nil then
            tx_failed(context, "odpkg update requires configured dependency aliases")
            return false
        end
    end
    begin_step(context, "Update odpkg dependencies")
    local result = exec_run(context, build_project_command(context, packages, { "update" }))
    if not is_success(result) then
        tx_failed(context, first_nonempty(result.stderr, result.stdout, "odpkg update failed"))
        return false
    end
    local _, updated_items = read_project_state(context, packages)
    emit_event(context, "updated", updated_items or {})
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.list(context)
    local flags = collect_flags(context, {})
    local force_registry = has_flag(flags, "registry")
    local refresh = has_flag(flags, "refresh")
    local config, items = read_project_state(context, {})
    if not force_registry and config ~= nil then
        emit_event(context, "listed", items or {})
        return items or {}
    end
    if not command_exists(context, REQUIRED_BINARY) then
        local cache_text = read_file(context, registry_cache_path(context, {}))
        if cache_text ~= nil and not refresh then
            local cached = {}
            for _, pkg in ipairs(parse_registry_cache(cache_text)) do
                cached[#cached + 1] = {
                    name = pkg.slug,
                    packageId = pkg.slug,
                    source = pkg.repositoryUrl,
                    homepage = pkg.repositoryUrl,
                    status = pkg.status,
                    description = pkg.description,
                    packageType = "odin-package",
                    type = "package",
                }
            end
            emit_event(context, "listed", cached)
            return cached
        end
        emit_event(context, "listed", {})
        return {}
    end
    local args = { "list", "--registry" }
    if refresh then
        args[#args + 1] = "--refresh"
    end
    local result = exec_run(context, build_global_command(context, {}, args))
    local listed = is_success(result) and parse_registry_rows(result.stdout or "") or {}
    emit_event(context, "listed", listed)
    return listed
end

function plugin.outdated(context)
    local empty = {}
    emit_event(context, "outdated", empty)
    return empty
end

function plugin.search(context, prompt)
    local query = trim(prompt)
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end
    if not command_exists(context, REQUIRED_BINARY) then
        emit_event(context, "searched", {})
        return {}
    end
    local args = { "search", shell_quote(query) }
    if has_flag(collect_flags(context, {}), "refresh") then
        args[#args + 1] = "--refresh"
    end
    local result = exec_run(context, build_global_command(context, {}, args))
    local items = is_success(result) and parse_registry_rows(result.stdout or "") or {}
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = trim(name)
    local flags = collect_flags(context, {})
    local refresh = has_flag(flags, "refresh")
    if query == "" then
        emit_event(context, "informed", {})
        return {}
    end
    local config, items = read_project_state(context, {})
    if config ~= nil then
        local item = find_project_item(items or {}, query)
        if item ~= nil then
            emit_event(context, "informed", item)
            return item
        end
    end
    local cache_path = registry_cache_path(context, {})
    local cache_text = read_file(context, cache_path)
    if cache_text == nil or refresh then
        if command_exists(context, REQUIRED_BINARY) then
            local warm_args = { "list", "--registry" }
            if refresh then
                warm_args[#warm_args + 1] = "--refresh"
            end
            local warm = exec_run(context, build_global_command(context, {}, warm_args))
            if warm ~= nil then
                cache_text = read_file(context, cache_path)
            end
        end
    end
    if cache_text ~= nil then
        for _, pkg in ipairs(parse_registry_cache(cache_text)) do
            if lower(pkg.slug) == lower(query) then
                local item = {
                    name = pkg.slug,
                    packageId = pkg.slug,
                    displayName = pkg.displayName,
                    description = pkg.description,
                    source = pkg.repositoryUrl,
                    repositoryUrl = pkg.repositoryUrl,
                    homepage = pkg.repositoryUrl,
                    license = pkg.license,
                    status = pkg.status,
                    packageKind = pkg.packageKind,
                    packageType = "odin-package",
                    type = "package",
                }
                emit_event(context, "informed", item)
                return item
            end
        end
    end
    emit_event(context, "informed", {})
    return {}
end

function plugin.shutdown()
    return true
end

return plugin
