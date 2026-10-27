plugin = {}

local PLUGIN_ID = "zplug"
local PLUGIN_NAME = "zplug"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_SHELL = "zsh"
local REQUIRED_GIT = "git"
local BOOTSTRAP_URL = "https://github.com/zplug/zplug"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return trim(value):lower()
end

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil then
            if type(value) == "string" then
                local cleaned = trim(value)
                if cleaned ~= "" then
                    return cleaned
                end
            else
                return value
            end
        end
    end
    return nil
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function double_quote(value)
    local cleaned = tostring(value or "")
    cleaned = cleaned:gsub("\\", "\\\\")
    cleaned = cleaned:gsub('"', '\\"')
    cleaned = cleaned:gsub("`", "\\`")
    cleaned = cleaned:gsub("%$", "\\$")
    return '"' .. cleaned .. '"'
end

local function is_safe_tag_value(value)
    return tostring(value or ""):match("^[A-Za-z0-9_./~@%%+=:-]+$") ~= nil
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(select(index, ...) or "")
        if part ~= "" then
            if #parts == 0 then
                parts[#parts + 1] = part:gsub("/+$", "")
            else
                parts[#parts + 1] = part:gsub("^/+", ""):gsub("/+$", "")
            end
        end
    end
    if #parts == 0 then
        return "."
    end
    return table.concat(parts, "/")
end

local function dirname(path)
    local value = trim(path)
    local dir = value:match("^(.*)/[^/]+$")
    if dir ~= nil and dir ~= "" then
        return dir
    end
    if value:sub(1, 1) == "/" then
        return "/"
    end
    return "."
end

local function basename(path)
    local value = trim(path)
    if value == "" then
        return ""
    end
    return value:match("([^/]+)$") or value
end

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
end

local function copy_array(values)
    local copy = {}
    for _, value in ipairs(values or {}) do
        copy[#copy + 1] = value
    end
    return copy
end

local function append_unique(values, value)
    local cleaned = trim(value)
    if cleaned == "" then
        return
    end
    for _, existing in ipairs(values) do
        if existing == cleaned then
            return
        end
    end
    values[#values + 1] = cleaned
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

local function request_sources(context)
    local sources = {}
    local function add(value)
        if value ~= nil then
            sources[#sources + 1] = value
        end
    end
    add(context)
    add(read_field(context, "request"))
    add(read_field(context, "input"))
    add(read_field(context, "payload"))
    add(read_field(context, "args"))
    return sources
end

local function request_field(context, key)
    for _, source in ipairs(request_sources(context)) do
        local value = read_field(source, key)
        if value ~= nil then
            return value
        end
    end
    return nil
end

local function split_lines(value)
    local lines = {}
    local normalized = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    for line in (normalized .. "\n"):gmatch("(.-)\n") do
        if line ~= "" or normalized ~= "" then
            lines[#lines + 1] = line
        end
    end
    if #lines > 0 and lines[#lines] == "" then
        table.remove(lines, #lines)
    end
    return lines
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

local function exec_run(context, command)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return context.exec.run(command)
    end
    return reqpack.exec.run(command)
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function default_home()
    local os_table = _G.os
    if type(os_table) == "table" and type(os_table.getenv) == "function" then
        return first_nonempty(os_table.getenv("HOME"), "/home/test")
    end
    return "/home/test"
end

local function flag_items(raw)
    local result = {}
    if type(raw) ~= "table" then
        return result
    end
    for _, item in ipairs(raw) do
        local cleaned = trim(item)
        if cleaned ~= "" then
            result[#result + 1] = cleaned
        end
    end
    return result
end

local function collect_flags(context, packages)
    local result = {}
    local function collect(value)
        for _, flag in ipairs(flag_items(read_field(value, "flags"))) do
            result[#result + 1] = flag
        end
    end
    for _, source in ipairs(request_sources(context)) do
        collect(source)
    end
    for _, package in ipairs(packages or {}) do
        collect(package)
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

local function has_flag(flags, key)
    local wanted = lower(key)
    for _, flag in ipairs(flags or {}) do
        if lower(flag) == wanted then
            return true
        end
    end
    return false
end

local function resolve_state(context, packages)
    local home = default_home()
    local flags = collect_flags(context, packages)
    local zplug_home = first_nonempty(flag_value(flags, "zplug-home"), join_path(home, ".zplug"))
    local cache_root = first_nonempty(flag_value(flags, "cache-root"), join_path(zplug_home, "cache"))
    local loadfile = first_nonempty(flag_value(flags, "loadfile"), join_path(zplug_home, "packages.zsh"))
    return {
        flags = flags,
        home = home,
        zplugHome = zplug_home,
        cacheRoot = cache_root,
        loadfile = loadfile,
        loadfileDir = dirname(loadfile),
        initPath = join_path(zplug_home, "init.zsh"),
    }
end

local function zsh_env_prefix(state)
    return table.concat({
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
        "NO_COLOR='1'",
        "ZPLUG_HOME=" .. shell_quote(state.zplugHome),
        "ZPLUG_CACHE_DIR=" .. shell_quote(state.cacheRoot),
        "ZPLUG_LOADFILE=" .. shell_quote(state.loadfile),
    }, " ")
end

local function zsh_command(state, script)
    return zsh_env_prefix(state) .. " " .. shell_quote(REQUIRED_SHELL) .. " -lc " .. shell_quote("source \"$ZPLUG_HOME/init.zsh\" >/dev/null 2>&1; " .. script)
end

local function ensure_runtime_dirs(context, state)
    local paths = {}
    append_unique(paths, state.cacheRoot)
    append_unique(paths, state.loadfileDir)
    if #paths == 0 then
        return true, nil
    end
    local parts = { "mkdir -p" }
    for _, path in ipairs(paths) do
        parts[#parts + 1] = shell_quote(path)
    end
    local result = exec_run(context, table.concat(parts, " "))
    if result ~= nil and result.success then
        return true, nil
    end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to create zplug runtime directories")
end

local function ensure_loadfile(state)
    return state ~= nil
end

local function bootstrap_zplug(context, state)
    local init_check = exec_run(context, "test -f " .. shell_quote(state.initPath))
    if init_check ~= nil and init_check.success then
        return true, nil
    end

    if not command_exists(context, REQUIRED_GIT) then
        return nil, "git binary not available for zplug bootstrap"
    end

    local parent = dirname(state.zplugHome)
    if trim(parent) ~= "" then
        local mkdir_result = exec_run(context, "mkdir -p " .. shell_quote(parent))
        if mkdir_result == nil or not mkdir_result.success then
            return nil, first_nonempty(mkdir_result and mkdir_result.stderr, mkdir_result and mkdir_result.stdout, "failed to prepare zplug home parent")
        end
    end

    local clone_result = exec_run(context, "git clone --depth 1 " .. shell_quote(BOOTSTRAP_URL) .. " " .. shell_quote(state.zplugHome))
    if clone_result == nil or not clone_result.success then
        return nil, first_nonempty(clone_result and clone_result.stderr, clone_result and clone_result.stdout, "failed to bootstrap zplug")
    end
    return true, nil
end

local function ensure_zplug(context, state)
    if not command_exists(context, REQUIRED_SHELL) then
        return nil, "zsh binary not available"
    end
    local ok, err = bootstrap_zplug(context, state)
    if not ok then
        return nil, err
    end
    ok, err = ensure_runtime_dirs(context, state)
    if not ok then
        return nil, err
    end
    if not ensure_loadfile(state) then
        return nil, "failed to create zplug loadfile"
    end
    return true, nil
end

local function split_tag_tokens(text)
    local tokens = {}
    local current = {}
    local quote = nil
    local escaped = false
    for index = 1, #text do
        local char = text:sub(index, index)
        if escaped then
            current[#current + 1] = char
            escaped = false
        elseif char == "\\" then
            current[#current + 1] = char
            escaped = true
        elseif quote ~= nil then
            current[#current + 1] = char
            if char == quote then
                quote = nil
            end
        elseif char == '"' or char == "'" then
            current[#current + 1] = char
            quote = char
        elseif char == "," then
            local token = trim(table.concat(current))
            if token ~= "" then
                tokens[#tokens + 1] = token
            end
            current = {}
        else
            current[#current + 1] = char
        end
    end
    local token = trim(table.concat(current))
    if token ~= "" then
        tokens[#tokens + 1] = token
    end
    return tokens
end

local function unquote_tag_value(value)
    local cleaned = trim(value)
    local first = cleaned:sub(1, 1)
    local last = cleaned:sub(-1)
    if (first == '"' and last == '"') or (first == "'" and last == "'") then
        cleaned = cleaned:sub(2, -2)
        cleaned = cleaned:gsub("\\([\\\"'])", "%1")
    end
    return cleaned
end

local function set_tag(entry, key, value)
    local cleaned_key = trim(key)
    if cleaned_key == "" then
        return
    end
    if entry.tags[cleaned_key] == nil then
        entry.tagOrder[#entry.tagOrder + 1] = cleaned_key
    end
    entry.tags[cleaned_key] = trim(value)
end

local function parse_loadfile_line(line)
    local cleaned = trim(line)
    if cleaned == "" or cleaned:sub(1, 1) == "#" then
        return nil
    end
    local _, _, quote, package_id, rest = cleaned:find("^zplug%s+(['\"])(.-)%1%s*(.*)$")
    if package_id == nil then
        return nil
    end
    local entry = {
        packageId = package_id,
        tags = {},
        tagOrder = {},
    }
    rest = trim(rest or "")
    if rest:sub(1, 1) == "," then
        rest = trim(rest:sub(2))
    end
    for _, token in ipairs(split_tag_tokens(rest)) do
        local key, value = token:match("^([^:]+):(.+)$")
        if key ~= nil then
            set_tag(entry, key, unquote_tag_value(value))
        else
            set_tag(entry, token, "true")
        end
    end
    return entry
end

local function read_loadfile_entries(context, path)
    local result = exec_run(context, "cat " .. shell_quote(path))
    if result == nil or not result.success or trim(result.stdout) == "" then
        return {}
    end
    local entries = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local entry = parse_loadfile_line(line)
        if entry ~= nil then
            entries[#entries + 1] = entry
        end
    end
    return entries
end

local function serialize_tag_value(value)
    local cleaned = trim(value)
    if is_safe_tag_value(cleaned) then
        return cleaned
    end
    return double_quote(cleaned)
end

local function serialize_entry(entry)
    local parts = { "zplug " .. double_quote(entry.packageId) }
    for _, key in ipairs(entry.tagOrder or {}) do
        local value = entry.tags[key]
        if trim(value) ~= "" then
            parts[#parts + 1] = key .. ":" .. serialize_tag_value(value)
        end
    end
    return table.concat(parts, ", ")
end

local function write_loadfile_entries(context, path, entries)
    local lines = {}
    for _, entry in ipairs(entries or {}) do
        lines[#lines + 1] = serialize_entry(entry)
    end
    local content = #lines > 0 and (table.concat(lines, "\n") .. "\n") or ""
    local command = "mkdir -p " .. shell_quote(dirname(path)) .. " && printf %s " .. shell_quote(content) .. " > " .. shell_quote(path)
    local result = exec_run(context, command)
    return result ~= nil and result.success == true
end

local function find_entry_index(entries, package_id)
    local wanted = trim(package_id)
    for index, entry in ipairs(entries or {}) do
        if trim(entry.packageId) == wanted then
            return index
        end
    end
    return nil
end

local function copy_entry(entry)
    return {
        packageId = entry.packageId,
        tags = shallow_copy(entry.tags or {}),
        tagOrder = copy_array(entry.tagOrder or {}),
    }
end

local function package_flags(package)
    return flag_items(read_field(package, "flags"))
end

local function package_id(package)
    return trim(first_nonempty(read_field(package, "name"), read_field(package, "packageId"), read_field(package, "packageName")))
end

local function build_entry_from_package(package, existing, force_local)
    local id = package_id(package)
    if id == "" then
        return nil
    end
    local entry = existing ~= nil and copy_entry(existing) or { packageId = id, tags = {}, tagOrder = {} }
    entry.packageId = id
    local saw_at = false
    local saw_from = false
    for _, flag in ipairs(package_flags(package)) do
        local key, value = flag:match("^([^=]+)=(.+)$")
        if key ~= nil then
            set_tag(entry, key, value)
            if trim(key) == "at" then
                saw_at = true
            elseif trim(key) == "from" then
                saw_from = true
            end
        else
            set_tag(entry, flag, "true")
        end
    end
    if trim(read_field(package, "version") or "") ~= "" and not saw_at and entry.tags["at"] == nil then
        set_tag(entry, "at", read_field(package, "version"))
    end
    if force_local and not saw_from and entry.tags["from"] == nil then
        set_tag(entry, "from", "local")
    end
    return entry
end

local function entry_matches_prompt(entry, prompt)
    local wanted = lower(prompt)
    if wanted == "" or entry == nil then
        return false
    end
    if lower(entry.packageId) == wanted then
        return true
    end
    if lower(basename(entry.packageId)) == wanted then
        return true
    end
    if lower(entry.packageId):find(wanted, 1, true) ~= nil then
        return true
    end
    return false
end

local function find_entry(entries, prompt)
    for _, entry in ipairs(entries or {}) do
        if entry_matches_prompt(entry, prompt) then
            return entry
        end
    end
    return nil
end

local function source_url_for_entry(entry)
    if entry == nil then
        return nil
    end
    local source = lower(entry.tags.from or "github")
    local package_id = trim(entry.packageId)
    if source == "local" or package_id:match("^[~/]") or package_id:match("^/") then
        return nil
    end
    if source == "gitlab" then
        return "https://gitlab.com/" .. package_id
    end
    if source == "bitbucket" then
        return "https://bitbucket.org/" .. package_id
    end
    if source == "gist" then
        return "https://gist.github.com/" .. package_id
    end
    if source == "oh-my-zsh" then
        return "https://github.com/ohmyzsh/ohmyzsh/tree/master/" .. package_id
    end
    if source == "prezto" then
        return "https://github.com/sorin-ionescu/prezto/tree/master/" .. package_id
    end
    return "https://github.com/" .. package_id
end

local function package_type_for_entry(entry, info_fields)
    local kind = lower(first_nonempty(entry and entry.tags.as, info_fields and info_fields.as, "plugin"))
    if kind == "command" then
        return "zsh-command"
    end
    if kind == "theme" then
        return "zsh-theme"
    end
    return "zsh-plugin"
end

local function parse_info_output(stdout)
    local info = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line):gsub("^[-*#]+%s*", "")
        local key, value = cleaned:match("^([A-Za-z][A-Za-z%-%s]+):%s*(.*)$")
        if key ~= nil then
            local normalized_key = lower(key):gsub("%s+", "-")
            info[normalized_key] = trim(value)
        end
    end
    return info
end

local function build_item(entry, installed, status, info_fields)
    local info = info_fields or {}
    local version = first_nonempty(read_field(info, "at"), entry and entry.tags.at)
    local item = {
        name = entry and entry.packageId or nil,
        packageId = entry and entry.packageId or nil,
        version = version,
        latestVersion = version,
        installed = installed == true,
        status = status or (installed and "installed" or "available"),
        packageType = package_type_for_entry(entry, info),
        type = "package",
        repository = first_nonempty(read_field(info, "from"), entry and entry.tags.from, "github"),
        homepage = first_nonempty(read_field(info, "url"), read_field(info, "repository"), source_url_for_entry(entry)),
        sourceUrl = first_nonempty(read_field(info, "url"), source_url_for_entry(entry)),
        extraFields = {},
    }

    for key, value in pairs(entry and entry.tags or {}) do
        item.extraFields[key] = value
    end
    if read_field(info, "use") ~= nil then
        item.extraFields.use = read_field(info, "use")
    end
    if read_field(info, "rename-to") ~= nil then
        item.extraFields["rename-to"] = read_field(info, "rename-to")
    end
    if read_field(info, "dir") ~= nil then
        item.extraFields.dir = read_field(info, "dir")
    end
    if next(item.extraFields) == nil then
        item.extraFields = nil
    end
    return item
end

local function scan_known_ids(output, entries)
    local matched = {}
    local found = {}
    for _, line in ipairs(split_lines(output)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            for _, entry in ipairs(entries or {}) do
                local package_id = trim(entry.packageId)
                if package_id ~= "" and (cleaned == package_id or cleaned:find(package_id, 1, true) ~= nil) then
                    if not found[package_id] then
                        found[package_id] = true
                        matched[#matched + 1] = package_id
                    end
                end
            end
        end
    end
    return matched
end

local function query_installed_ids(context, state, entries)
    if #entries == 0 then
        return {}, nil
    end
    local ok, err = ensure_zplug(context, state)
    if not ok then
        return nil, err
    end
    local result = exec_run(context, zsh_command(state, "zplug list"))
    if result == nil or not result.success then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "zplug list failed")
    end
    return scan_known_ids(result.stdout, entries), nil
end

local function query_status_ids(context, state, entries)
    if #entries == 0 then
        return {}, nil
    end
    local ok, err = ensure_zplug(context, state)
    if not ok then
        return nil, err
    end
    local result = exec_run(context, zsh_command(state, "zplug status"))
    if result == nil or not result.success then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "zplug status failed")
    end
    return scan_known_ids(result.stdout, entries), nil
end

local function query_info_fields(context, state, package_id)
    local ok, err = ensure_zplug(context, state)
    if not ok then
        return nil, err
    end
    local result = exec_run(context, zsh_command(state, "zplug info " .. double_quote(package_id)))
    if result == nil or not result.success then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "zplug info failed")
    end
    return parse_info_output(result.stdout), nil
end

local function sort_items(items)
    table.sort(items, function(left, right)
        return lower(first_nonempty(left.packageId, left.name) or "") < lower(first_nonempty(right.packageId, right.name) or "")
    end)
    return items
end

plugin.fileExtensions = { ".zsh", ".plugin.zsh", ".zsh-theme" }

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
    return { "shell", "zsh", "package-manager" }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end
    if not command_exists(nil, REQUIRED_SHELL) then
        local missing = {}
        for _, package in ipairs(packages) do
            local action = lower(read_field(package, "action") or "")
            if action ~= "remove" and action ~= "update" then
                missing[#missing + 1] = package
            end
        end
        return missing
    end

    local state = resolve_state(nil, packages)
    local entries = read_loadfile_entries(nil, state.loadfile)
    local installed_ids = query_installed_ids(nil, state, entries) or {}
    local outdated_ids = query_status_ids(nil, state, entries) or {}
    local installed_map = {}
    local outdated_map = {}
    for _, value in ipairs(installed_ids) do
        installed_map[value] = true
    end
    for _, value in ipairs(outdated_ids) do
        outdated_map[value] = true
    end

    local missing = {}
    for _, package in ipairs(packages) do
        local action = lower(read_field(package, "action") or "")
        local id = package_id(package)
        if action == "remove" then
            if installed_map[id] then
                missing[#missing + 1] = package
            end
        elseif action == "update" then
            if outdated_map[id] then
                missing[#missing + 1] = package
            end
        elseif not installed_map[id] then
            missing[#missing + 1] = package
        end
    end
    return missing
end

function plugin.install(context, packages)
    local local_path = first_nonempty(request_field(context, "localPath"), request_field(context, "path"))
    if local_path ~= nil then
        return plugin.installLocal(context, local_path)
    end

    local requested = packages or request_field(context, "packages") or {}
    if #requested == 0 then
        return true
    end

    local state = resolve_state(context, requested)
    local ok, err = ensure_zplug(context, state)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local entries = read_loadfile_entries(context, state.loadfile)
    for _, package in ipairs(requested) do
        local entry = build_entry_from_package(package, find_entry(entries, package_id(package)), false)
        if entry == nil then
            tx_failed(context, "zplug package identifier missing")
            return false
        end
        local index = find_entry_index(entries, entry.packageId)
        if index ~= nil then
            entries[index] = entry
        else
            entries[#entries + 1] = entry
        end
    end
    if not write_loadfile_entries(context, state.loadfile, entries) then
        tx_failed(context, "failed to write zplug loadfile")
        return false
    end

    for _, package in ipairs(requested) do
        local id = package_id(package)
        begin_step(context, "install zplug package " .. id)
        local result = exec_run(context, zsh_command(state, "zplug install " .. double_quote(id)))
        if result == nil or not result.success then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "zplug install failed"))
            return false
        end
        emit_event(context, "installed", build_item(find_entry(entries, id), true, "installed", {}))
    end

    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" then
        tx_failed(context, "missing local zplug path")
        return false
    end

    local package = {
        name = local_path,
        flags = copy_array(flag_items(request_field(context, "flags"))),
    }
    local packages = { package }
    local state = resolve_state(context, packages)
    local ok, err = ensure_zplug(context, state)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local entries = read_loadfile_entries(context, state.loadfile)
    local entry = build_entry_from_package(package, find_entry(entries, local_path), true)
    local index = find_entry_index(entries, local_path)
    if index ~= nil then
        entries[index] = entry
    else
        entries[#entries + 1] = entry
    end
    if not write_loadfile_entries(context, state.loadfile, entries) then
        tx_failed(context, "failed to write zplug loadfile")
        return false
    end

    begin_step(context, "install local zplug package")
    local result = exec_run(context, zsh_command(state, "zplug install " .. double_quote(local_path)))
    if result == nil or not result.success then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "zplug local install failed"))
        return false
    end

    local item = build_item(entry, true, "installed", {})
    item.localTarget = true
    item.path = local_path
    emit_event(context, "installed", item)
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or request_field(context, "packages") or {}
    if #requested == 0 then
        return true
    end

    local state = resolve_state(context, requested)
    local ok, err = ensure_zplug(context, state)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local entries = read_loadfile_entries(context, state.loadfile)
    for _, package in ipairs(requested) do
        local id = package_id(package)
        if id == "" then
            tx_failed(context, "zplug package identifier missing")
            return false
        end
        begin_step(context, "remove zplug package " .. id)
        local result = exec_run(context, zsh_command(state, "zplug clean --force " .. double_quote(id)))
        if result == nil or not result.success then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "zplug remove failed"))
            return false
        end
        local index = find_entry_index(entries, id)
        local removed_entry = index ~= nil and entries[index] or { packageId = id, tags = {}, tagOrder = {} }
        if index ~= nil then
            table.remove(entries, index)
        end
        emit_event(context, "deleted", build_item(removed_entry, false, "removed", {}))
    end

    if not write_loadfile_entries(context, state.loadfile, entries) then
        tx_failed(context, "failed to rewrite zplug loadfile")
        return false
    end

    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or request_field(context, "packages") or {}
    local state = resolve_state(context, requested)
    local ok, err = ensure_zplug(context, state)
    if not ok then
        tx_failed(context, err)
        return false
    end

    if #requested == 0 then
        begin_step(context, "update zplug packages")
        local result = exec_run(context, zsh_command(state, "zplug update --force"))
        if result == nil or not result.success then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "zplug update failed"))
            return false
        end
        emit_event(context, "updated", {})
        tx_success(context)
        return true
    end

    local entries = read_loadfile_entries(context, state.loadfile)
    for _, package in ipairs(requested) do
        local id = package_id(package)
        if id == "" then
            tx_failed(context, "zplug package identifier missing")
            return false
        end
        begin_step(context, "update zplug package " .. id)
        local result = exec_run(context, zsh_command(state, "zplug update --force " .. double_quote(id)))
        if result == nil or not result.success then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "zplug update failed"))
            return false
        end
        emit_event(context, "updated", build_item(find_entry(entries, id) or { packageId = id, tags = {}, tagOrder = {} }, true, "updated", {}))
    end

    tx_success(context)
    return true
end

function plugin.list(context)
    local state = resolve_state(context, {})
    local entries = read_loadfile_entries(context, state.loadfile)
    local installed_ids, err = query_installed_ids(context, state, entries)
    if installed_ids == nil then
        log_warn(context, err or "zplug list failed")
        emit_event(context, "listed", {})
        return {}
    end

    local items = {}
    for _, id in ipairs(installed_ids) do
        local entry = find_entry(entries, id)
        if entry ~= nil then
            items[#items + 1] = build_item(entry, true, "installed", {})
        end
    end
    sort_items(items)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local state = resolve_state(context, {})
    local entries = read_loadfile_entries(context, state.loadfile)
    local outdated_ids, err = query_status_ids(context, state, entries)
    if outdated_ids == nil then
        log_warn(context, err or "zplug status failed")
        emit_event(context, "outdated", {})
        return {}
    end

    local items = {}
    for _, id in ipairs(outdated_ids) do
        local entry = find_entry(entries, id)
        if entry ~= nil then
            items[#items + 1] = build_item(entry, true, "outdated", {})
        end
    end
    sort_items(items)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = lower(first_nonempty(prompt, request_field(context, "prompt"), ""))
    local state = resolve_state(context, {})
    local entries = read_loadfile_entries(context, state.loadfile)
    local items = {}
    for _, entry in ipairs(entries) do
        local haystack = lower(entry.packageId .. " " .. table.concat(entry.tagOrder or {}, " "))
        if query == "" or haystack:find(query, 1, true) ~= nil then
            items[#items + 1] = build_item(entry, false, "available", {})
        end
    end
    sort_items(items)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local prompt = first_nonempty(name, request_field(context, "prompt"), "")
    if trim(prompt) == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local state = resolve_state(context, {})
    local entries = read_loadfile_entries(context, state.loadfile)
    local entry = find_entry(entries, prompt)
    if entry == nil then
        entry = { packageId = trim(prompt), tags = {}, tagOrder = {} }
    end

    local installed_ids, list_error = query_installed_ids(context, state, { entry })
    if installed_ids == nil then
        log_warn(context, list_error or "zplug list failed before info")
    end
    local info_fields, info_error = query_info_fields(context, state, entry.packageId)
    if info_fields == nil then
        log_warn(context, info_error or "zplug info failed")
        local fallback = build_item(entry, installed_ids ~= nil and #installed_ids > 0, installed_ids ~= nil and #installed_ids > 0 and "installed" or "available", {})
        emit_event(context, "informed", fallback)
        return fallback
    end

    local installed = installed_ids ~= nil and #installed_ids > 0
    local item = build_item(entry, installed, installed and "installed" or "available", info_fields)
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local id = package_id(package)
    if id == "" then
        return nil
    end
    return plugin.info(context, id)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "zplug", "zsh" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".zplug" },
        },
        privilegeLevel = "user",
    }
end

function plugin.init()
    return command_exists(nil, REQUIRED_SHELL)
end

function plugin.shutdown()
    return true
end

return plugin
