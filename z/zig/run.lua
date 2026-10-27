plugin = {}

local PLUGIN_ID = "zig"
local PLUGIN_NAME = "Zig"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "zig"
local PACKAGE_TYPE = "zig-package"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function split_lines(value)
    local text = tostring(value or ""):gsub("\r\n", "\n")
    local lines = {}
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then
            lines[#lines + 1] = line
        end
    end
    return lines
end

local function get_field(value, key)
    if value == nil then
        return nil
    end
    local value_type = type(value)
    if value_type == "table" or value_type == "userdata" then
        local ok, field = pcall(function()
            return value[key]
        end)
        if ok then
            return field
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
        local probes = {
            "success",
            "ok",
            "stdout",
            "stderr",
            "exitCode",
            "exit_code",
            "code",
            "status",
            "stdoutText",
            "stderrText",
        }
        for _, key in ipairs(probes) do
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

local function run_exec(context, command)
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
    local result = run_exec(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        return os.getenv(name)
    end
    if reqpack ~= nil and reqpack.host ~= nil then
        local env = reqpack.host.env
        if type(env) == "table" then
            return env[name]
        end
    end
    return nil
end

local function now_timestamp()
    if os ~= nil and type(os.time) == "function" then
        return tostring(os.time())
    end
    return "0"
end

local function ensure_available(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function home_dir()
    return trim(getenv("HOME") or "/home/test")
end

local function reqpack_home()
    local explicit = trim(getenv("REQPACK_HOME"))
    if explicit ~= "" then
        return explicit
    end
    return home_dir() .. "/.cache/reqpack"
end

local function cache_root()
    return reqpack_home() .. "/" .. PLUGIN_ID
end

local function records_dir()
    return cache_root() .. "/records"
end

local function sources_dir()
    return cache_root() .. "/sources"
end

local function global_cache_dir()
    return cache_root() .. "/global-cache"
end

local function env_prefix()
    return "ZIG_GLOBAL_CACHE_DIR=" .. shell_quote(global_cache_dir())
        .. " NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C'"
end

local function ensure_directory(path)
    local dir = trim(path)
    if dir == "" or dir == "." then
        return true
    end
    local result = run_exec(nil, "mkdir -p " .. shell_quote(dir))
    if result ~= nil and result.success == true then
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
    local handle = io.open(path, "r")
    if handle ~= nil then
        local content = handle:read("*a")
        handle:close()
        return content
    end
    local result = run_exec(nil, "cat " .. shell_quote(path))
    if result ~= nil and result.success == true then
        return result.stdout
    end
    return nil
end

local function write_file(path, content)
    local dir = tostring(path or ""):match("^(.*)/[^/]+$")
    if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
        return false
    end
    local handle = io.open(path, "w")
    if handle ~= nil then
        handle:write(content)
        handle:close()
        return true
    end
    local command = "mkdir -p " .. shell_quote(dir or ".") .. " && printf %s " .. shell_quote(content) .. " > " .. shell_quote(path)
    local result = run_exec(nil, command)
    return result ~= nil and result.success == true
end

local function remove_file(path)
    if path == nil or trim(path) == "" then
        return true
    end
    local result = run_exec(nil, "rm -f " .. shell_quote(path))
    if result ~= nil and result.success == true then
        return true
    end
    if os ~= nil and type(os.remove) == "function" then
        os.remove(path)
    end
    return true
end

local function remove_tree(path)
    local target = trim(path)
    if target == "" then
        return true
    end
    if os == nil or type(os.execute) ~= "function" then
        return false
    end
    local ok, kind, code = os.execute("rm -rf " .. shell_quote(target))
    if ok == true then
        return true
    end
    if type(ok) == "number" then
        return ok == 0
    end
    return code == 0 or kind == "exit"
end

local function split_value(value, separator)
    local items = {}
    local text = tostring(value or "")
    if text == "" then
        return items
    end
    separator = separator or ","
    local pattern = "([^" .. separator:gsub("([%%%-%^%$%(%)%.%[%]%*%+%?])", "%%%1") .. "]+)"
    for item in text:gmatch(pattern) do
        items[#items + 1] = item
    end
    return items
end

local function package_flags(package)
    local flags = {}
    local raw = get_field(package, "flags")
    if type(raw) == "table" or type(raw) == "userdata" then
        local ok = pcall(function()
            for _, flag in ipairs(raw) do
                local text = trim(flag)
                if text ~= "" then
                    flags[#flags + 1] = text
                end
            end
        end)
        if ok then
            return flags
        end
    end
    return flags
end

local function flag_value(flags, prefix)
    local wanted = prefix .. "="
    for _, flag in ipairs(flags or {}) do
        if flag == prefix then
            return true
        end
        if flag:sub(1, #wanted) == wanted then
            return trim(flag:sub(#wanted + 1))
        end
    end
    return nil
end

local function path_exists(path)
    local handle = io.open(path, "r")
    if handle ~= nil then
        handle:close()
        return true
    end
    local result = run_exec(nil, "test -e " .. shell_quote(path))
    return result ~= nil and result.success == true
end

local function is_url(value)
    local text = trim(value)
    return text:match("^[A-Za-z][A-Za-z0-9+.-]*://") ~= nil
        or text:match("^git%+[A-Za-z][A-Za-z0-9+.-]*://") ~= nil
end

local function looks_like_path(value)
    local text = trim(value)
    if text == "" then
        return false
    end
    if text:sub(1, 1) == "/" or text:sub(1, 1) == "." or text:sub(1, 1) == "~" then
        return true
    end
    if text:find("/", 1, true) ~= nil or text:find("\\", 1, true) ~= nil then
        return true
    end
    return path_exists(text)
end

local function file_stem(value)
    local text = trim(value):gsub("%?.*$", "")
    local tail = text:match("([^/]+)$") or text
    tail = tail:gsub("%.tar%.gz$", "")
    tail = tail:gsub("%.tar%.xz$", "")
    tail = tail:gsub("%.tar%.zst$", "")
    tail = tail:gsub("%.tgz$", "")
    tail = tail:gsub("%.zip$", "")
    tail = tail:gsub("%.git$", "")
    return trim(tail)
end

local function derive_name(target, explicit_name)
    local preferred = trim(explicit_name)
    if preferred ~= "" and not is_url(preferred) and not looks_like_path(preferred) then
        return preferred
    end
    local stem = file_stem(target)
    if stem ~= "" then
        return stem
    end
    return trim(target)
end

local function safe_id(value)
    local text = lower(trim(value)):gsub("[^a-z0-9]+", "_")
    text = text:gsub("_+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if text == "" then
        return "item"
    end
    return text
end

local function record_path_for_id(id)
    return records_dir() .. "/" .. safe_id(id) .. ".tsv"
end

local function mirror_path_for_id(id)
    return sources_dir() .. "/" .. safe_id(id)
end

local function encode_record(record)
    local lines = {}
    local keys = {
        "id",
        "name",
        "sourceKind",
        "target",
        "hash",
        "installMode",
        "mirrorPath",
        "projectPath",
        "homepage",
        "requestedVersion",
        "flags",
        "updatedAt",
    }
    for _, key in ipairs(keys) do
        local value = record[key]
        if type(value) == "table" then
            value = table.concat(value, "\31")
        end
        if value ~= nil then
            lines[#lines + 1] = key .. "\t" .. tostring(value)
        end
    end
    return table.concat(lines, "\n") .. "\n"
end

local function decode_record(content)
    local record = {}
    for _, line in ipairs(split_lines(content)) do
        local key, value = line:match("^([^\t]+)\t(.*)$")
        if key ~= nil then
            record[key] = value
        end
    end
    if trim(record.flags) ~= "" then
        record.flags = split_value(record.flags, "\31")
    else
        record.flags = {}
    end
    return record
end

local function write_record(record)
    ensure_directory(records_dir())
    ensure_directory(sources_dir())
    return write_file(record_path_for_id(record.id), encode_record(record))
end

local function read_record(path)
    local content = read_file(path)
    if content == nil then
        return nil
    end
    return decode_record(content)
end

local function list_record_paths(context)
    local result = run_exec(context, "ls -1A " .. shell_quote(records_dir()))
    if result == nil or result.success ~= true then
        return {}
    end
    local paths = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        if line:match("%.tsv$") ~= nil then
            paths[#paths + 1] = records_dir() .. "/" .. trim(line)
        end
    end
    return paths
end

local function load_records(context)
    local records = {}
    for _, path in ipairs(list_record_paths(context)) do
        local record = read_record(path)
        if record ~= nil and trim(record.id) ~= "" then
            records[#records + 1] = record
        end
    end
    return records
end

local function find_record(context, name)
    local wanted = trim(name)
    if wanted == "" then
        return nil
    end
    for _, record in ipairs(load_records(context)) do
        if record.id == wanted or record.target == wanted or record.name == wanted then
            return record
        end
    end
    return nil
end

local function record_to_item(record)
    if record == nil then
        return nil
    end
    return {
        name = record.name,
        packageId = record.id,
        version = trim(record.hash) ~= "" and record.hash or nil,
        homepage = trim(record.homepage) ~= "" and record.homepage or nil,
        packageType = PACKAGE_TYPE,
        extraFields = {
            sourceKind = record.sourceKind,
            installMode = record.installMode,
            target = record.target,
            globalCacheDir = global_cache_dir(),
            recordsDir = records_dir(),
            mirrorPath = record.mirrorPath,
            projectPath = record.projectPath,
            requestedVersion = record.requestedVersion,
        },
    }
end

local function synthetic_item(target, explicit_name)
    local source_kind = is_url(target) and "url" or "path"
    return {
        name = derive_name(target, explicit_name),
        packageId = trim(target),
        homepage = source_kind == "url" and trim(target) or nil,
        packageType = PACKAGE_TYPE,
        extraFields = {
            sourceKind = source_kind,
            installMode = "fetch",
            target = trim(target),
            globalCacheDir = global_cache_dir(),
            recordsDir = records_dir(),
        },
    }
end

local function package_target(package)
    local url = trim(get_field(package, "url"))
    if url ~= "" then
        return url, "url"
    end
    local path = trim(get_field(package, "path"))
    if path ~= "" then
        return path, looks_like_path(path) and "path" or "project"
    end
    local name = trim(get_field(package, "name") or package)
    if name == "" then
        return nil, nil
    end
    if is_url(name) then
        return name, "url"
    end
    if looks_like_path(name) then
        return name, "path"
    end
    return name, "url"
end

local function build_fetch_mode(flags)
    local value = flag_value(flags, "build-fetch")
    if value == true then
        return "needed"
    end
    if value == "all" then
        return "all"
    end
    value = flag_value(flags, "fetch-tree")
    if value == true then
        return "needed"
    end
    if value == "all" then
        return "all"
    end
    return nil
end

local function fetch_command(target, flags)
    local args = {
        env_prefix(),
        REQUIRED_BINARY,
        "fetch",
        "--global-cache-dir",
        shell_quote(global_cache_dir()),
    }

    local save_name = flag_value(flags, "save")
    local save_exact_name = flag_value(flags, "save-exact")
    if save_name ~= nil then
        if save_name == true then
            args[#args + 1] = "--save"
        else
            args[#args + 1] = "--save=" .. shell_quote(save_name)
        end
    elseif save_exact_name ~= nil then
        if save_exact_name == true then
            args[#args + 1] = "--save-exact"
        else
            args[#args + 1] = "--save-exact=" .. shell_quote(save_exact_name)
        end
    end

    args[#args + 1] = shell_quote(target)
    return table.concat(args, " ")
end

local function build_fetch_command(project_path, mode)
    local project = trim(project_path)
    local fetch_mode = trim(mode) ~= "" and trim(mode) or "needed"
    return "cd " .. shell_quote(project)
        .. " && " .. env_prefix()
        .. " " .. REQUIRED_BINARY
        .. " build --fetch=" .. fetch_mode
        .. " --cache-dir " .. shell_quote(project .. "/.zig-cache")
        .. " --global-cache-dir " .. shell_quote(global_cache_dir())
end

local function fetch_hash(result)
    if result == nil or result.success ~= true then
        return nil
    end
    local text = trim(result.stdout)
    if text == "" then
        return nil
    end
    local lines = split_lines(text)
    return trim(lines[#lines] or text)
end

local function install_one(context, package, local_target)
    local flags = package_flags(package)
    local target, source_kind = package_target(package)
    if local_target == true then
        target = trim(get_field(package, "path") or target)
        source_kind = "path"
    end
    if target == nil or trim(target) == "" then
        return nil, "missing zig target"
    end

    local explicit_name = trim(get_field(package, "name"))
    local requested_version = trim(get_field(package, "version"))
    local fetch_mode = build_fetch_mode(flags)
    local command
    local install_mode
    local hash = nil

    ensure_directory(global_cache_dir())

    if fetch_mode ~= nil then
        begin_step(context, "fetch zig dependency tree " .. target)
        install_mode = fetch_mode == "all" and "build-fetch-all" or "build-fetch-needed"
        command = build_fetch_command(target, fetch_mode)
        local result = run_exec(context, command)
        if result == nil or result.success ~= true then
            return nil, "zig build --fetch failed"
        end
        source_kind = "project"
    else
        if source_kind ~= "url" then
            if flag_value(flags, "save") ~= nil or flag_value(flags, "save-exact") ~= nil then
                log_warn(context, "zig save flags ignored for local target " .. target)
            end
        end
        begin_step(context, "fetch zig package " .. target)
        install_mode = "fetch"
        if flag_value(flags, "save") ~= nil and source_kind == "url" then
            install_mode = "fetch-save"
        elseif flag_value(flags, "save-exact") ~= nil and source_kind == "url" then
            install_mode = "fetch-save-exact"
        end
        command = fetch_command(target, flags)
        local result = run_exec(context, command)
        if result == nil or result.success ~= true then
            return nil, "zig fetch failed"
        end
        hash = fetch_hash(result)
    end

    local canonical_id = source_kind == "project" and ("build-fetch:" .. trim(target)) or trim(target)
    local mirror_path = mirror_path_for_id(canonical_id)
    ensure_directory(mirror_path)
    local record = {
        id = canonical_id,
        name = derive_name(target, explicit_name),
        sourceKind = source_kind,
        target = trim(target),
        hash = hash,
        installMode = install_mode,
        mirrorPath = mirror_path,
        projectPath = source_kind == "project" and trim(target) or nil,
        homepage = source_kind == "url" and trim(target) or nil,
        requestedVersion = requested_version ~= "" and requested_version or nil,
        flags = shallow_copy(flags),
        updatedAt = now_timestamp(),
    }
    if not write_record(record) then
        return nil, "zig record write failed"
    end
    return record_to_item(record), nil
end

local function sort_items(items)
    table.sort(items, function(left, right)
        return lower(left.name or left.packageId or "") < lower(right.name or right.packageId or "")
    end)
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
    return { "package-manager", "programming-language" }
end

function plugin.getMissingPackages(packages)
    local missing = {}
    local installed = {}
    for _, item in ipairs(load_records(nil)) do
        installed[item.id] = item
        installed[item.target] = item
        installed[item.name] = item
    end
    for _, package in ipairs(packages or {}) do
        local target = select(1, package_target(package))
        local name = trim(get_field(package, "name") or "")
        if installed[target] == nil and installed[name] == nil then
            missing[#missing + 1] = package
        end
    end
    return missing
end

function plugin.install(context, packages)
    packages = packages or {}
    if #packages == 0 then
        return true
    end
    local ok, err = ensure_available(context)
    if not ok then
        tx_failed(context, err)
        return false
    end
    local items = {}
    for _, package in ipairs(packages) do
        local item, install_err = install_one(context, package, false)
        if item == nil then
            tx_failed(context, install_err or "zig install failed")
            return false
        end
        items[#items + 1] = item
    end
    emit_event(context, "installed", items)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" then
        tx_failed(context, "zig local install failed")
        return false
    end
    local ok, err = ensure_available(context)
    if not ok then
        tx_failed(context, err)
        return false
    end
    local item, install_err = install_one(context, { path = local_path }, true)
    if item == nil then
        tx_failed(context, install_err or "zig local install failed")
        return false
    end
    emit_event(context, "installed", item)
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    packages = packages or {}
    if #packages == 0 then
        return true
    end
    local removed = {}
    for _, package in ipairs(packages) do
        local target = select(1, package_target(package)) or trim(get_field(package, "name"))
        local record = find_record(context, target)
        if record ~= nil then
            begin_step(context, "remove zig managed state " .. tostring(record.name or record.id))
            remove_file(record_path_for_id(record.id))
            if trim(record.mirrorPath) ~= "" then
                remove_tree(record.mirrorPath)
            end
            removed[#removed + 1] = record_to_item(record)
        end
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    packages = packages or {}
    local ok, err = ensure_available(context)
    if not ok then
        tx_failed(context, err)
        return false
    end
    if #packages == 0 then
        local records = load_records(context)
        local derived = {}
        for _, record in ipairs(records) do
            derived[#derived + 1] = {
                name = record.name,
                path = record.sourceKind == "path" or record.sourceKind == "project" and record.target or nil,
                url = record.sourceKind == "url" and record.target or nil,
                flags = shallow_copy(record.flags),
                version = record.requestedVersion,
            }
        end
        packages = derived
    end

    local items = {}
    for _, package in ipairs(packages) do
        local item, update_err = install_one(context, package, false)
        if item == nil then
            tx_failed(context, update_err or "zig update failed")
            return false
        end
        items[#items + 1] = item
    end
    emit_event(context, "updated", items)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = {}
    for _, record in ipairs(load_records(context)) do
        items[#items + 1] = record_to_item(record)
    end
    sort_items(items)
    emit_event(context, "listed", items)
    return items
end

function plugin.search(context, prompt)
    local search_prompt = trim(prompt)
    if search_prompt == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    if is_url(search_prompt) or looks_like_path(search_prompt) then
        local items = { synthetic_item(search_prompt, nil) }
        emit_event(context, "searched", items)
        return items
    end
    log_warn(context, "zig has no native global search API; returning empty search result")
    local empty = {}
    emit_event(context, "searched", empty)
    return empty
end

function plugin.info(context, name)
    local target = trim(name)
    if target == "" then
        target = trim(get_field(context, "prompt"))
    end
    if target == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local record = find_record(context, target)
    if record ~= nil then
        local item = record_to_item(record)
        emit_event(context, "informed", item)
        return item
    end
    if is_url(target) or looks_like_path(target) then
        local item = synthetic_item(target, nil)
        emit_event(context, "informed", item)
        return item
    end
    local empty = {}
    emit_event(context, "informed", empty)
    return empty
end

function plugin.outdated(context)
    log_warn(context, "zig has no reliable outdated query across arbitrary package URLs")
    local empty = {}
    emit_event(context, "outdated", empty)
    return empty
end

function plugin.resolvePackage(context, package)
    local target = select(1, package_target(package))
    if target == nil or trim(target) == "" then
        return nil
    end
    local record = find_record(context, target)
    if record ~= nil then
        return record_to_item(record)
    end
    return synthetic_item(target, trim(get_field(package, "name")))
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "fs-read", "fs-write" },
        ecosystemScopes = { "zig" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".cache/reqpack/zig" },
        },
        networkScopes = { "any" },
        privilegeLevel = "user",
        purlType = "generic",
        versionComparatorProfile = "lexicographic",
    }
end

function plugin.init()
    return command_exists(nil, REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

return plugin
