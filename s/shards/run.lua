plugin = {}

local PLUGIN_ID = "shards"
local PLUGIN_NAME = "Crystal Shards"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "shards"
local SEARCH_BASE_URL = "https://shards.info/search?query="
local DETAIL_BASE_URL = "https://shards.info/github/"
local SEARCH_TTL = 8 * 60 * 60
local INFO_TTL = 10 * 60

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        return os.getenv(name)
    end
    return nil
end

local function expand_placeholders(value)
    local text = tostring(value or "")
    local fixture_root = trim(getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
    if fixture_root ~= "" then
        text = text:gsub("%${fixtureRoot}", fixture_root)
    end
    return text
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
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

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
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

local function command_ok(ok, _, code)
    if ok == true then
        return true
    end
    if type(ok) == "number" then
        return ok == 0
    end
    return code == 0
end

local exec_run

local function ensure_directory(path)
    local dir = trim(path)
    if dir == "" or dir == "." then
        return true
    end
    if os == nil or type(os.execute) ~= "function" then
        return true
    end
    local ok, kind, code = os.execute("mkdir -p " .. shell_quote(dir))
    if command_ok(ok, kind, code) then
        return true
    end
    return true
end

local function read_file(path)
    local handle = io.open(path, "r")
    if handle == nil then
        local fixture_root = trim(getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
        if fixture_root ~= "" then
            local normalized = trim(expand_placeholders(path))
            if normalized:sub(1, 1) ~= "/" and normalized:sub(1, #fixture_root) ~= fixture_root then
                handle = io.open(join_path(fixture_root, normalized), "r")
            end
        end
        if handle == nil then
            return nil
        end
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(path, content)
    path = expand_placeholders(path)
    local fixture_root = trim(getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
    if fixture_root ~= "" and trim(path):sub(1, 1) ~= "/" and trim(path):sub(1, #fixture_root) ~= fixture_root then
        path = join_path(fixture_root, path)
    end
    local dir = parent_dir(path)
    local tmp_path = path .. ".tmp"
    if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
        return false
    end
    local handle = io.open(tmp_path, "w")
    if handle == nil then
        if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
            local command = "mkdir -p " .. shell_quote(dir or ".") .. " && printf %s " .. shell_quote(content) .. " > " .. shell_quote(path)
            local result = reqpack.exec.run(command)
            return result ~= nil and result.success == true
        end
        return false
    end
    handle:write(content)
    handle:close()
    if os ~= nil and type(os.remove) == "function" then
        os.remove(path)
    end
    if os == nil or type(os.rename) ~= "function" or not os.rename(tmp_path, path) then
        return false
    end
    return true
end

local function home_dir()
    if os ~= nil and type(os.getenv) == "function" then
        return first_nonempty(os.getenv("HOME"), os.getenv("USERPROFILE"), "/home/test", ".")
    end
    return "/home/test"
end

local function epoch_now()
    if os ~= nil and type(os.time) == "function" then
        return os.time()
    end
    return 0
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

exec_run = function(context, command)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return context.exec.run(command)
    end
    return reqpack.exec.run(command)
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
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

local function object_flags(object)
    local value = read_field(object, "flags")
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
            append_unique(flags, expand_placeholders(flag), seen)
        end
    end
    collect_from(context)
    collect_from(read_field(context, "request"))
    if type(packages) == "table" then
        for _, package in ipairs(packages) do
            collect_from(package)
        end
    end
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

local function cache_root(context, packages)
    local flags = collect_raw_flags(context, packages)
    local explicit = flag_value(flags, "cache-root")
    if explicit ~= nil and explicit ~= "" then
        return explicit
    end
    return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
end

local function shared_paths(context, packages)
    local root = cache_root(context, packages)
    return {
        root = root,
        shards_cache = join_path(root, "shards-cache"),
        search = join_path(root, "search"),
        info = join_path(root, "info"),
    }
end

local function path_exists_as_dir(path)
    if read_file(join_path(path, "shard.yml")) ~= nil then
        return true
    end
    if os ~= nil and type(os.execute) == "function" then
        local ok, _, code = os.execute("test -d " .. shell_quote(path))
        return command_ok(ok, nil, code)
    end
    return false
end

local function path_exists_as_file(path)
    if read_file(path) ~= nil then
        return true
    end
    if os ~= nil and type(os.execute) == "function" then
        local ok, _, code = os.execute("test -f " .. shell_quote(path))
        return command_ok(ok, nil, code)
    end
    return false
end

local function target_dir_from_context(context, packages)
    local flags = collect_raw_flags(context, packages)
    local dir = first_nonempty(
        read_field(context, "directory"),
        read_field(context, "dir"),
        read_field(read_field(context, "request") or {}, "directory"),
        read_field(read_field(context, "request") or {}, "dir"),
        flag_value(flags, "dir"),
        flag_value(flags, "path")
    )
    if dir ~= nil then
        return dir
    end
    if path_exists_as_file("shard.yml") then
        return "."
    end
    return nil
end

local function ensure_cache_dirs(paths)
    return ensure_directory(paths.root)
        and ensure_directory(paths.shards_cache)
        and ensure_directory(paths.search)
        and ensure_directory(paths.info)
end

local function package_name(package)
    return trim(read_field(package, "name") or "")
end

local function package_version(package)
    return trim(read_field(package, "version") or "")
end

local function package_action(package)
    return trim(read_field(package, "action") or "")
end

local function cache_key(value)
    local cleaned = lower(trim(value or ""))
    cleaned = cleaned:gsub("[^%w]+", "-")
    cleaned = cleaned:gsub("^-+", ""):gsub("-+$", "")
    if cleaned == "" then
        cleaned = "item"
    end
    return cleaned
end

local function is_cache_fresh(ts_path, ttl)
    local raw = read_file(ts_path)
    local ts = tonumber(trim(raw or ""))
    if ts == nil then
        return false
    end
    return (epoch_now() - ts) <= ttl
end

local function persist_cache(body_path, ts_path, body)
    if trim(getenv("REQPACK_TEST_FIXTURE_ROOT") or "") ~= "" then
        return true
    end
    if not write_file(body_path, body or "") then
        return false
    end
    if not write_file(ts_path, tostring(epoch_now())) then
        return false
    end
    return true
end

local function cached_fetch(context, body_path, ts_path, url, ttl)
    local cached = read_file(body_path)
    if cached ~= nil and is_cache_fresh(ts_path, ttl) then
        return cached, nil
    end
    local result = exec_run(context, "curl -fsSL " .. shell_quote(url))
    if result ~= nil and result.success == true then
        if trim(getenv("REQPACK_TEST_FIXTURE_ROOT") or "") == "" then
            persist_cache(body_path, ts_path, result.stdout or "")
        end
        return result.stdout or "", nil
    end
    if cached ~= nil then
        return cached, nil
    end
    return nil, trim(result and result.stderr or "fetch failed")
end

local function parse_manifest(content)
    local lines = split_lines(content)
    local manifest = {
        lines = lines,
        sections = {},
        order = {},
    }
    local current_section = nil
    local current_name = nil
    for index, line in ipairs(lines) do
        local top = line:match("^([%w_]+):%s*$")
        if top ~= nil then
            current_section = top
            current_name = nil
            if manifest.sections[top] == nil then
                manifest.sections[top] = { start_line = index, entries = {} }
                manifest.order[#manifest.order + 1] = top
            end
        else
            local name = line:match("^  ([%w_.%-]+):%s*$")
            if name ~= nil and (current_section == "dependencies" or current_section == "development_dependencies") then
                current_name = name
                manifest.sections[current_section].entries[name] = {
                    line_start = index,
                    line_end = index,
                    attributes = {},
                }
            else
                local key, value = line:match("^    ([%w_]+):%s*(.-)%s*$")
                if key ~= nil and current_section ~= nil and current_name ~= nil then
                    local entry = manifest.sections[current_section].entries[current_name]
                    entry.attributes[key] = value
                    entry.line_end = index
                elseif current_section ~= nil and manifest.sections[current_section] ~= nil then
                    manifest.sections[current_section].end_line = index
                end
            end
        end
        if current_section ~= nil and manifest.sections[current_section] ~= nil then
            manifest.sections[current_section].end_line = index
        end
    end
    return manifest
end

local function quote_yaml(value)
    local text = tostring(value or "")
    if text:match("^[%w%._/%-]+$") then
        return text
    end
    return '"' .. text:gsub('"', '\\"') .. '"'
end

local function package_resolver_attributes(package)
    local attrs = {}
    local flags = read_field(package, "flags") or {}
    local recognized = {
        github = true,
        gitlab = true,
        bitbucket = true,
        codeberg = true,
        git = true,
        path = true,
        version = true,
        branch = true,
        tag = true,
        commit = true,
    }
    for _, flag in ipairs(flags) do
        local key, value = tostring(flag):match("^([%w_]+)=(.+)$")
        if key ~= nil and recognized[key] then
            attrs[key] = expand_placeholders(trim(value))
        end
    end
    local version = package_version(package)
    if version ~= "" then
        attrs.version = version
    end
    if attrs.github == nil and attrs.git == nil and attrs.path == nil then
        local name = package_name(package)
        if name ~= "" and not name:find("/", 1, true) then
            attrs.github = name .. "/" .. name
        end
    end
    return attrs
end

local function entry_lines_for_package(package, local_path)
    local name = package_name(package)
    local attrs = package_resolver_attributes(package)
    if local_path ~= nil and local_path ~= "" then
        attrs = { path = local_path }
    end
    local lines = { "  " .. name .. ":" }
    local preferred_order = { "github", "gitlab", "bitbucket", "codeberg", "git", "path", "version", "branch", "tag", "commit" }
    for _, key in ipairs(preferred_order) do
        local value = trim(attrs[key] or "")
        if value ~= "" then
            lines[#lines + 1] = "    " .. key .. ": " .. quote_yaml(value)
        end
    end
    return lines
end

local function materialized_entry_text(lines)
    return table.concat(lines or {}, "\n")
end

local function rewrite_manifest_dependency(manifest_path, package, local_path)
    local content = read_file(manifest_path)
    if content == nil then
        return false, "missing shard.yml"
    end
    local manifest = parse_manifest(content)
    local lines = manifest.lines
    local section = manifest.sections.dependencies
    local new_entry_lines = entry_lines_for_package(package, local_path)
    local name = package_name(package)
    if name == "" then
        return false, "shards package name missing"
    end
    local output = {}
    if section == nil then
        for _, line in ipairs(lines) do
            output[#output + 1] = line
        end
        if #output > 0 and output[#output] ~= "" then
            output[#output + 1] = ""
        end
        output[#output + 1] = "dependencies:"
        for _, line in ipairs(new_entry_lines) do
            output[#output + 1] = line
        end
        return write_file(manifest_path, table.concat(output, "\n") .. "\n") and true or false, "failed to write shard.yml"
    end

    local existing = section.entries[name]
    if existing ~= nil then
        for index, line in ipairs(lines) do
            if index < existing.line_start or index > existing.line_end then
                output[#output + 1] = line
            elseif index == existing.line_start then
                for _, replacement in ipairs(new_entry_lines) do
                    output[#output + 1] = replacement
                end
            end
        end
    else
        for index, line in ipairs(lines) do
            output[#output + 1] = line
            if index == section.end_line then
                for _, addition in ipairs(new_entry_lines) do
                    output[#output + 1] = addition
                end
            end
        end
    end

    if materialized_entry_text(output) == materialized_entry_text(lines) then
        return true
    end
    if not write_file(manifest_path, table.concat(output, "\n") .. "\n") then
        return false, "failed to write shard.yml"
    end
    return true
end

local function remove_manifest_dependency(manifest_path, package)
    local content = read_file(manifest_path)
    if content == nil then
        return false, "missing shard.yml"
    end
    local manifest = parse_manifest(content)
    local lines = manifest.lines
    local name = package_name(package)
    if name == "" then
        return false, "shards package name missing"
    end
    local ranges = {}
    for _, section_name in ipairs({ "dependencies", "development_dependencies" }) do
        local section = manifest.sections[section_name]
        if section ~= nil and section.entries[name] ~= nil then
            ranges[#ranges + 1] = { start_line = section.entries[name].line_start, end_line = section.entries[name].line_end }
        end
    end
    if #ranges == 0 then
        return true
    end
    local output = {}
    for index, line in ipairs(lines) do
        local skip = false
        for _, range in ipairs(ranges) do
            if index >= range.start_line and index <= range.end_line then
                skip = true
                break
            end
        end
        if not skip then
            output[#output + 1] = line
        end
    end
    if not write_file(manifest_path, table.concat(output, "\n") .. "\n") then
        return false, "failed to write shard.yml"
    end
    return true
end

local function parse_lock_versions(content)
    local versions = {}
    local current = nil
    for _, line in ipairs(split_lines(content)) do
        local name = line:match("^([%w_.%-]+):%s*$")
        if name ~= nil then
            current = name
        else
            local version = line:match("^  version:%s*(.-)%s*$")
            if version ~= nil and current ~= nil then
                versions[current] = version:gsub('^"', ""):gsub('"$', "")
            end
        end
    end
    return versions
end

local function manifest_lookup(manifest_path)
    local content = read_file(manifest_path)
    if content == nil then
        return {}
    end
    local manifest = parse_manifest(content)
    local lookup = {}
    for _, section_name in ipairs({ "dependencies", "development_dependencies" }) do
        local section = manifest.sections[section_name]
        if section ~= nil then
            for name, entry in pairs(section.entries) do
                lookup[name] = {
                    section = section_name,
                    attributes = shallow_copy(entry.attributes),
                }
            end
        end
    end
    return lookup
end

local function build_env_prefix(paths, target_dir)
    return "SHARDS_CACHE_PATH=" .. shell_quote(paths.shards_cache)
        .. " SHARDS_INSTALL_PATH=" .. shell_quote(join_path(target_dir, "lib"))
end

local function build_project_command(target_dir, paths, args)
    local parts = {}
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = arg
    end
    return "cd " .. shell_quote(target_dir) .. " && " .. build_env_prefix(paths, target_dir) .. " shards " .. table.concat(parts, " ")
end

local function parse_list_output(stdout, manifest_map, lock_versions)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local name, version = line:match("^([%w_.%-]+)%s+%(([^)]+)%)")
        if name ~= nil then
            local manifest_item = manifest_map[name] or {}
            items[#items + 1] = {
                name = name,
                packageId = name,
                type = "package",
                packageType = "library",
                version = trim(version),
                latestVersion = lock_versions[name],
                installed = true,
                status = "installed",
                summary = name,
                extraFields = {
                    ["manifest.section"] = manifest_item.section,
                    resolver = first_nonempty(manifest_item.attributes and manifest_item.attributes.github and "github", manifest_item.attributes and manifest_item.attributes.git and "git", manifest_item.attributes and manifest_item.attributes.path and "path"),
                    ["source.github"] = manifest_item.attributes and manifest_item.attributes.github,
                    ["source.git"] = manifest_item.attributes and manifest_item.attributes.git,
                    ["source.path"] = manifest_item.attributes and manifest_item.attributes.path,
                },
            }
        end
    end
    return items
end

local function parse_outdated_output(stdout, manifest_map)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local name, installed, available = line:match("^%s*%*%s+([%w_.%-]+)%s+%(installed:%s*([^,]+),%s*available:%s*([^)]+)%)")
        if name ~= nil then
            local manifest_item = manifest_map[name] or {}
            items[#items + 1] = {
                name = name,
                packageId = name,
                type = "package",
                packageType = "library",
                version = trim(installed),
                latestVersion = trim(available),
                installed = true,
                status = "outdated",
                summary = name,
                extraFields = {
                    ["manifest.section"] = manifest_item.section,
                },
            }
        end
    end
    return items
end

local function parse_search_results(html)
    local items = {}
    local text = tostring(html or "")
    for owner, repo, desc in text:gmatch('<a href="/github/([^/]+)/([^/"]+)/">.-<p class="shards__shard_desc[^>]*>%s*(.-)%s*</p>') do
        local name = trim(repo)
        if name ~= "" then
            items[#items + 1] = {
                name = name,
                packageId = owner .. "/" .. repo,
                type = "package",
                packageType = "library",
                latestVersion = nil,
                installed = false,
                status = "available",
                summary = trim((desc:gsub("<.->", ""))),
                description = trim((desc:gsub("<.->", ""))),
                repository = "https://github.com/" .. owner .. "/" .. repo,
                homepage = DETAIL_BASE_URL .. owner .. "/" .. repo,
                extraFields = {
                    owner = owner,
                    repo = repo,
                    resolver = "github",
                    ["source.github"] = owner .. "/" .. repo,
                },
            }
        end
    end
    return items
end

local function parse_detail_page(html, fallback_name)
    local name = first_nonempty(tostring(html or ""):match("<h1 class=\"mb%-0\">%s*([^<%s]+)"), fallback_name)
    local version = first_nonempty(tostring(html or ""):match("<i class=\"page__subheading\">%s*v?([^<%s]+)"))
    local summary = first_nonempty(tostring(html or ""):match('<div class="shard__intro">%s*<span>%s*(.-)%s*</span>'))
    local owner = first_nonempty(tostring(html or ""):match('<a href="/github/([^/"]+)/">'))
    local repo = first_nonempty(tostring(html or ""):match('<div class="list__heading">Repository</div>%s*<p class="fw%-bold">%s*(.-)%s*</p>'))
    local license = first_nonempty(tostring(html or ""):match('<div class="list__heading">License</div>%s*<p>%s*(.-)%s*</p>'))
    local source_code = first_nonempty(tostring(html or ""):match('<a href="(https://github%.com/[^\"]+)">Source code</a>'))
    if name == nil then
        return nil
    end
    return {
        name = name,
        packageId = first_nonempty(owner and repo and (owner .. "/" .. repo), name),
        type = "package",
        packageType = "library",
        version = version,
        latestVersion = version,
        installed = false,
        status = "available",
        summary = summary,
        description = summary,
        repository = source_code,
        homepage = owner and repo and (DETAIL_BASE_URL .. owner .. "/" .. repo) or nil,
        license = license,
        extraFields = {
            owner = owner,
            repo = repo,
            resolver = owner ~= nil and repo ~= nil and "github" or nil,
            ["source.github"] = owner ~= nil and repo ~= nil and (owner .. "/" .. repo) or nil,
        },
    }
end

local function resolve_info_slug(name, paths, context)
    local clean = trim(name or "")
    if clean:match("^[^/]+/[^/]+$") then
        return clean
    end
    local search_body_path = join_path(paths.search, cache_key(clean) .. ".html")
    local search_ts_path = join_path(paths.search, cache_key(clean) .. ".ts")
    local html, err = cached_fetch(context, search_body_path, search_ts_path, SEARCH_BASE_URL .. clean, SEARCH_TTL)
    if html == nil then
        return nil, err
    end
    local items = parse_search_results(html)
    if #items == 0 then
        return nil, "no shard search results"
    end
    local best = items[1]
    return best.packageId, nil
end

local function installed_name_set(context, packages)
    local target_dir = target_dir_from_context(context, packages)
    if target_dir == nil then
        return nil
    end
    local lookup = manifest_lookup(join_path(target_dir, "shard.yml"))
    local set = {}
    for name in pairs(lookup) do
        set[lower(name)] = true
    end
    return set
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
    return { "Crystal", "Shards", "Package Manager" }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "dependency-install", "dependency-remove", "dependency-update", "dependency-query", "project-manifest-edit", "network" },
        ecosystemScopes = { "crystal", "shards.info" },
        writeScopes = {
            "user-home-subpath:.cache/reqpack/shards",
            "project-file:shard.yml",
            "project-file:shard.lock",
            "project-subpath:lib",
        },
        networkScopes = { "https://shards.info" },
        privilegeLevel = "none",
        purlType = "generic",
    }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end
    local installed = installed_name_set(nil, requested)
    if installed == nil then
        return requested
    end
    local missing = {}
    for _, package in ipairs(requested) do
        local action = package_action(package)
        local name = lower(package_name(package))
        local present = name ~= "" and installed[name] == true
        if action == "remove" then
            if present then
                missing[#missing + 1] = package
            end
        elseif action == "update" then
            if present then
                missing[#missing + 1] = package
            end
        elseif not present then
            missing[#missing + 1] = package
        end
    end
    return missing
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    begin_step(context, "install shards dependencies")
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end
    local target_dir = target_dir_from_context(context, requested)
    if target_dir == nil then
        tx_failed(context, "missing shards project directory with shard.yml; pass dir=<path>")
        return false
    end
    local manifest_path = join_path(target_dir, "shard.yml")
    for _, package in ipairs(requested) do
        local ok, err = rewrite_manifest_dependency(manifest_path, package, nil)
        if not ok and err ~= "missing shard.yml" then
            tx_failed(context, err)
            return false
        end
    end
    local paths = shared_paths(context, requested)
    if not ensure_cache_dirs(paths) then
        tx_failed(context, "failed to create shards cache directories")
        return false
    end
    local result = exec_run(context, build_project_command(target_dir, paths, { "install", "--no-color" }))
    if result == nil or result.success ~= true then
        tx_failed(context, trim(result and result.stderr or "shards install failed"))
        return false
    end
    emit_event(context, "installed", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path or read_field(context, "localPath") or read_field(read_field(context, "request") or {}, "localPath") or "")
    if local_path == "" then
        tx_failed(context, "missing local shards path")
        return false
    end
    local local_manifest = read_file(join_path(local_path, "shard.yml")) or ""
    local local_name = trim(local_manifest:match("\nname:%s*(.-)%s*\n") or local_manifest:match("^name:%s*(.-)%s*$") or "")
    if local_name == "" then
        local_name = trim(local_path:match("([^/]+)$") or "")
    end
    if local_name == "" then
        tx_failed(context, "local shard name missing in shard.yml")
        return false
    end
    local package = { name = local_name, flags = {} }
    begin_step(context, "install local shards dependency")
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end
    local target_dir = target_dir_from_context(context, { package })
    if target_dir == nil then
        tx_failed(context, "missing shards project directory with shard.yml; pass dir=<path>")
        return false
    end
    local ok, err = rewrite_manifest_dependency(join_path(target_dir, "shard.yml"), package, local_path)
    if not ok and err ~= "missing shard.yml" then
        tx_failed(context, err)
        return false
    end
    local paths = shared_paths(context, { package })
    if not ensure_cache_dirs(paths) then
        tx_failed(context, "failed to create shards cache directories")
        return false
    end
    local result = exec_run(context, build_project_command(target_dir, paths, { "install", "--no-color" }))
    if result == nil or result.success ~= true then
        tx_failed(context, trim(result and result.stderr or "shards install failed"))
        return false
    end
    emit_event(context, "installed", { { name = local_name, path = local_path, localTarget = true } })
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    begin_step(context, "remove shards dependencies")
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end
    local target_dir = target_dir_from_context(context, requested)
    if target_dir == nil then
        tx_failed(context, "missing shards project directory with shard.yml; pass dir=<path>")
        return false
    end
    local manifest_path = join_path(target_dir, "shard.yml")
    for _, package in ipairs(requested) do
        local ok, err = remove_manifest_dependency(manifest_path, package)
        if not ok and err ~= "missing shard.yml" then
            tx_failed(context, err)
            return false
        end
    end
    local paths = shared_paths(context, requested)
    if not ensure_cache_dirs(paths) then
        tx_failed(context, "failed to create shards cache directories")
        return false
    end
    local install_result = exec_run(context, build_project_command(target_dir, paths, { "install", "--no-color" }))
    if install_result == nil or install_result.success ~= true then
        tx_failed(context, trim(install_result and install_result.stderr or "shards install failed"))
        return false
    end
    local prune_result = exec_run(context, build_project_command(target_dir, paths, { "prune", "--no-color" }))
    if prune_result == nil or prune_result.success ~= true then
        tx_failed(context, trim(prune_result and prune_result.stderr or "shards prune failed"))
        return false
    end
    emit_event(context, "deleted", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    begin_step(context, "update shards dependencies")
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end
    local target_dir = target_dir_from_context(context, requested)
    if target_dir == nil then
        tx_failed(context, "missing shards project directory with shard.yml; pass dir=<path>")
        return false
    end
    local manifest_path = join_path(target_dir, "shard.yml")
    for _, package in ipairs(requested) do
        if package_version(package) ~= "" or next(package_resolver_attributes(package)) ~= nil then
            local ok, err = rewrite_manifest_dependency(manifest_path, package, nil)
            if not ok and err ~= "missing shard.yml" then
                tx_failed(context, err)
                return false
            end
        end
    end
    local paths = shared_paths(context, requested)
    if not ensure_cache_dirs(paths) then
        tx_failed(context, "failed to create shards cache directories")
        return false
    end
    local args = { "update" }
    if #requested > 0 then
        for _, package in ipairs(requested) do
            args[#args + 1] = package_name(package)
        end
    end
    args[#args + 1] = "--no-color"
    local result = exec_run(context, build_project_command(target_dir, paths, args))
    if result == nil or result.success ~= true then
        tx_failed(context, trim(result and result.stderr or "shards update failed"))
        return false
    end
    emit_event(context, "updated", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.list(context)
    if not command_exists(context, REQUIRED_BINARY) then
        log_warn(context, REQUIRED_BINARY .. " binary not available")
        emit_event(context, "listed", {})
        return {}
    end
    local target_dir = target_dir_from_context(context, {})
    if target_dir == nil then
        log_warn(context, "missing shards project directory with shard.yml; pass dir=<path>")
        emit_event(context, "listed", {})
        return {}
    end
    local paths = shared_paths(context, {})
    ensure_cache_dirs(paths)
    local result = exec_run(context, build_project_command(target_dir, paths, { "list", "--no-color" }))
    if result == nil or result.success ~= true then
        log_warn(context, trim(result and result.stderr or "shards list failed"))
        emit_event(context, "listed", {})
        return {}
    end
    local manifest_map = manifest_lookup(join_path(target_dir, "shard.yml"))
    local lock_versions = parse_lock_versions(read_file(join_path(target_dir, "shard.lock")) or "")
    local items = parse_list_output(result.stdout or "", manifest_map, lock_versions)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    if not command_exists(context, REQUIRED_BINARY) then
        log_warn(context, REQUIRED_BINARY .. " binary not available")
        emit_event(context, "outdated", {})
        return {}
    end
    local target_dir = target_dir_from_context(context, {})
    if target_dir == nil then
        log_warn(context, "missing shards project directory with shard.yml; pass dir=<path>")
        emit_event(context, "outdated", {})
        return {}
    end
    local paths = shared_paths(context, {})
    ensure_cache_dirs(paths)
    local result = exec_run(context, build_project_command(target_dir, paths, { "outdated", "--no-color" }))
    local items = parse_outdated_output(result and result.stdout or "", manifest_lookup(join_path(target_dir, "shard.yml")))
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end
    local paths = shared_paths(context, nil)
    if not ensure_cache_dirs(paths) then
        log_warn(context, "failed to create shards cache directories")
        emit_event(context, "searched", {})
        return {}
    end
    local body_path = join_path(paths.search, cache_key(query) .. ".html")
    local ts_path = join_path(paths.search, cache_key(query) .. ".ts")
    local html, err = cached_fetch(context, body_path, ts_path, SEARCH_BASE_URL .. query, SEARCH_TTL)
    if html == nil then
        log_warn(context, err)
        emit_event(context, "searched", {})
        return {}
    end
    local items = parse_search_results(html)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = trim(name or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
    if query == "" then
        emit_event(context, "informed", {})
        return {}
    end
    local target_dir = target_dir_from_context(context, {})
    if target_dir ~= nil then
        local installed = manifest_lookup(join_path(target_dir, "shard.yml"))
        local entry = installed[query]
        if entry ~= nil then
            local lock_versions = parse_lock_versions(read_file(join_path(target_dir, "shard.lock")) or "")
            local item = {
                name = query,
                packageId = query,
                type = "package",
                packageType = "library",
                version = lock_versions[query] or entry.attributes.version,
                latestVersion = lock_versions[query] or entry.attributes.version,
                installed = true,
                status = "installed",
                summary = query,
                extraFields = {
                    ["manifest.section"] = entry.section,
                    resolver = first_nonempty(entry.attributes.github and "github", entry.attributes.git and "git", entry.attributes.path and "path"),
                    ["source.github"] = entry.attributes.github,
                    ["source.git"] = entry.attributes.git,
                    ["source.path"] = entry.attributes.path,
                    branch = entry.attributes.branch,
                    tag = entry.attributes.tag,
                    commit = entry.attributes.commit,
                },
            }
            emit_event(context, "informed", item)
            return item
        end
    end
    local paths = shared_paths(context, nil)
    if not ensure_cache_dirs(paths) then
        log_warn(context, "failed to create shards cache directories")
        emit_event(context, "informed", {})
        return {}
    end
    local slug, slug_err = resolve_info_slug(query, paths, context)
    if slug == nil then
        log_warn(context, slug_err)
        emit_event(context, "informed", {})
        return {}
    end
    local body_path = join_path(paths.info, cache_key(slug) .. ".html")
    local ts_path = join_path(paths.info, cache_key(slug) .. ".ts")
    local html, err = cached_fetch(context, body_path, ts_path, DETAIL_BASE_URL .. slug, INFO_TTL)
    if html == nil then
        log_warn(context, err)
        emit_event(context, "informed", {})
        return {}
    end
    local item = parse_detail_page(html, query)
    if item == nil then
        emit_event(context, "informed", {})
        return {}
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
