plugin = {}

local PLUGIN_ID = "zinit"
local PLUGIN_NAME = "zinit"
local PLUGIN_VERSION = "0.1.0"
local ZINIT_REPO_URL = "https://github.com/zdharma-continuum/zinit.git"
local MANIFEST_FIELDS = {
    "name",
    "target",
    "teleid",
    "command",
    "packageType",
    "installPath",
    "source",
    "flags",
}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function non_empty(value)
    local cleaned = trim(value)
    if cleaned == "" then
        return nil
    end
    return cleaned
end

local function split_lines(value)
    local lines = {}
    local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

local function split_tsv(line)
    local fields = {}
    for field in (tostring(line or "") .. "\t"):gmatch("(.-)\t") do
        fields[#fields + 1] = field
    end
    return fields
end

local function split_csv(value)
    local items = {}
    for item in tostring(value or ""):gmatch("[^,]+") do
        local cleaned = trim(item)
        if cleaned ~= "" then
            items[#items + 1] = cleaned
        end
    end
    return items
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

local function basename(path)
    local cleaned = trim(path or "")
    cleaned = cleaned:gsub("/+$", "")
    if cleaned == "" then
        return ""
    end
    local name = cleaned:match("([^/]+)$")
    return name or cleaned
end

local function dirname(path)
    local cleaned = trim(path or "")
    local parent = cleaned:match("^(.*)/[^/]+$")
    return parent or "."
end

local function sanitize_field(value)
    return tostring(value or ""):gsub("[\t\r\n]", " ")
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

local function run_global(command)
    if reqpack == nil or reqpack.exec == nil or type(reqpack.exec.run) ~= "function" then
        return {
            success = false,
            stdout = "",
            stderr = "reqpack.exec.run unavailable",
            exitCode = 127,
        }
    end

    return reqpack.exec.run(command)
end

local function exec_run(context, command)
    local first, second, third, fourth, fifth
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        first, second, third, fourth, fifth = context.exec.run(command)
    else
        first, second, third, fourth, fifth = run_global(command)
    end
    return normalize_run_result(first, second, third, fourth, fifth)
end

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        return os.getenv(name)
    end

    local host = type(reqpack) == "table" and read_field(reqpack, "host") or nil
    local env = host and read_field(host, "env") or nil
    if type(env) == "table" then
        return env[name]
    end
    return nil
end

local function get_reqpack_path(name)
    local paths = type(reqpack) == "table" and read_field(reqpack, "paths") or nil
    if type(paths) ~= "table" then
        return nil
    end
    return non_empty(read_field(paths, name))
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

local function home_dir()
    return trim(getenv("HOME") or "/home/test")
end

local function flag_key(flag)
    local cleaned = trim(flag)
    local key, _ = cleaned:match("^([^=]+)=(.*)$")
    return lower(trim(key or cleaned))
end

local function object_flags(value)
    local raw = read_field(value, "flags")
    if type(raw) ~= "table" and type(raw) ~= "userdata" then
        return {}
    end

    local ordered = {}
    local indexes = {}
    local ok = pcall(function()
        for _, item in ipairs(raw) do
            local cleaned = trim(item)
            if cleaned ~= "" then
                local key = flag_key(cleaned)
                if indexes[key] ~= nil then
                    ordered[indexes[key]] = cleaned
                else
                    indexes[key] = #ordered + 1
                    ordered[#ordered + 1] = cleaned
                end
            end
        end
    end)
    if not ok then
        return {}
    end
    return ordered
end

local function merge_flags(base_flags, extra_flags)
    local merged = {}
    local indexes = {}

    local function add(flag)
        local cleaned = trim(flag)
        if cleaned == "" then
            return
        end
        local key = flag_key(cleaned)
        if indexes[key] ~= nil then
            merged[indexes[key]] = cleaned
        else
            indexes[key] = #merged + 1
            merged[#merged + 1] = cleaned
        end
    end

    for _, flag in ipairs(base_flags or {}) do
        add(flag)
    end
    for _, flag in ipairs(extra_flags or {}) do
        add(flag)
    end

    return merged
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

local function has_flag(flags, key)
    local wanted = lower(trim(key))
    for _, flag in ipairs(flags or {}) do
        if lower(trim(flag)) == wanted then
            return true
        end
    end
    return false
end

local function runtime_paths(flags)
    local data_root = first_nonempty(
        flag_value(flags, "data-root"),
        get_reqpack_path("dataRoot") and join_path(get_reqpack_path("dataRoot"), PLUGIN_ID),
        join_path(home_dir(), ".local", "share", "reqpack", PLUGIN_ID)
    )
    local cache_root = first_nonempty(
        flag_value(flags, "cache-root"),
        get_reqpack_path("cacheRoot") and join_path(get_reqpack_path("cacheRoot"), PLUGIN_ID),
        join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
    )
    local zinit_home = first_nonempty(flag_value(flags, "zinit-home"), join_path(data_root, "home"))
    local bin_dir = first_nonempty(flag_value(flags, "zinit-bin-dir"), join_path(zinit_home, "zinit.git"))

    return {
        dataRoot = data_root,
        cacheRoot = cache_root,
        homeDir = zinit_home,
        binDir = bin_dir,
        pluginsDir = join_path(zinit_home, "plugins"),
        snippetsDir = join_path(zinit_home, "snippets"),
        completionsDir = join_path(zinit_home, "completions"),
        polarisDir = join_path(zinit_home, "polaris"),
        zcompdumpPath = join_path(cache_root, "zcompdump"),
        manifestPath = first_nonempty(flag_value(flags, "manifest"), join_path(data_root, "packages.tsv")),
        loadfilePath = first_nonempty(flag_value(flags, "loadfile"), join_path(data_root, "packages.zsh")),
    }
end

local function ensure_runtime_dirs(context, paths)
    local command = "mkdir -p "
        .. shell_quote(paths.dataRoot) .. " "
        .. shell_quote(paths.cacheRoot) .. " "
        .. shell_quote(paths.homeDir) .. " "
        .. shell_quote(paths.pluginsDir) .. " "
        .. shell_quote(paths.snippetsDir) .. " "
        .. shell_quote(paths.completionsDir) .. " "
        .. shell_quote(paths.polarisDir)
    local result = exec_run(context, command)
    if result ~= nil and result.success then
        return true
    end
    return false, first_nonempty(result and result.stderr, result and result.stdout, "failed to create zinit runtime directories")
end

local function manager_exists(context, paths)
    local result = exec_run(context, "test -f " .. shell_quote(join_path(paths.binDir, "zinit.zsh")))
    return result ~= nil and result.success == true
end

local function bootstrap_manager(context, paths)
    local command = "mkdir -p " .. shell_quote(paths.homeDir) .. " && git clone --depth=1 " .. shell_quote(ZINIT_REPO_URL) .. " " .. shell_quote(paths.binDir)
    local result = exec_run(context, command)
    if result ~= nil and result.success then
        return true
    end
    return false, first_nonempty(result and result.stderr, result and result.stdout, "zinit bootstrap failed")
end

local function build_zinit_script(paths, body)
    return table.concat({
        "export LC_ALL=C",
        "export LANG=C",
        "export LANGUAGE=C",
        "export NO_COLOR=1",
        "export TERM=dumb",
        "export PAGER=cat",
        "typeset -gA ZINIT",
        "ZINIT[HOME_DIR]=" .. shell_quote(paths.homeDir),
        "ZINIT[BIN_DIR]=" .. shell_quote(paths.binDir),
        "ZINIT[PLUGINS_DIR]=" .. shell_quote(paths.pluginsDir),
        "ZINIT[SNIPPETS_DIR]=" .. shell_quote(paths.snippetsDir),
        "ZINIT[COMPLETIONS_DIR]=" .. shell_quote(paths.completionsDir),
        "ZINIT[ZCOMPDUMP_PATH]=" .. shell_quote(paths.zcompdumpPath),
        "ZINIT[ZPFX]=" .. shell_quote(paths.polarisDir),
        'ZPFX="$ZINIT[ZPFX]"',
        'source "$ZINIT[BIN_DIR]/zinit.zsh" >/dev/null 2>&1 || exit 1',
        body,
    }, "; ")
end

local function run_zinit(context, paths, body)
    return exec_run(context, "zsh -lc " .. shell_quote(build_zinit_script(paths, body)))
end

local function parse_single_value(stdout)
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            return cleaned
        end
    end
    return nil
end

local function normalize_identifier(value)
    local cleaned = lower(trim(value or ""))
    if cleaned == "" then
        return "unnamed"
    end
    cleaned = cleaned:gsub("[^a-z0-9._-]+", "_")
    cleaned = cleaned:gsub("_+", "_")
    cleaned = cleaned:gsub("^_+", "")
    cleaned = cleaned:gsub("_+$", "")
    return cleaned ~= "" and cleaned or "unnamed"
end

local function build_package_id(record)
    return PLUGIN_ID .. "/" .. normalize_identifier(record.packageType) .. "/" .. normalize_identifier(record.teleid or record.target or record.name)
end

local function is_url(value)
    local cleaned = trim(value)
    return cleaned:match("^[A-Za-z][A-Za-z0-9+.-]*://") ~= nil
end

local function looks_snippet_target(value)
    local cleaned = trim(value)
    if cleaned:match("^[A-Z][A-Z0-9]*::") ~= nil then
        return true
    end
    return is_url(cleaned)
end

local function detect_local_kind(context, path, flags)
    if has_flag(flags, "snippet") or looks_snippet_target(path) then
        return "local-snippet"
    end
    local result = exec_run(context, "test -d " .. shell_quote(path))
    if result ~= nil and result.success then
        return "local-plugin"
    end
    return "local-snippet"
end

local function apply_version_flag(flags, version)
    local cleaned = trim(version)
    if cleaned == "" or flag_value(flags, "ver") ~= nil then
        return flags
    end
    local copy = shallow_copy(flags)
    copy[#copy + 1] = "ver=" .. cleaned
    return copy
end

local function request_name(pkg)
    return trim(read_field(pkg, "name") or "")
end

local function package_name_from_target(target, package_type)
    if package_type == "local-plugin" or package_type == "local-snippet" then
        return basename(target)
    end
    return trim(target)
end

local function select_command(package_type, flags)
    if package_type == "snippet" or package_type == "local-snippet" or has_flag(flags, "snippet") then
        return "snippet"
    end
    if has_flag(flags, "light-mode") then
        return "light"
    end
    return "load"
end

local function visible_flags(flags)
    local rendered = {}
    for _, flag in ipairs(flags or {}) do
        local key = flag_key(flag)
        if key ~= "snippet" and key ~= "light-mode" and key ~= "data-root" and key ~= "cache-root" and key ~= "manifest" and key ~= "loadfile" and key ~= "zinit-home" and key ~= "zinit-bin-dir" then
            rendered[#rendered + 1] = flag
        end
    end
    return rendered
end

local function normalize_descriptor(context, target, flags, package_type)
    local effective_type = package_type
    if effective_type == nil then
        if looks_snippet_target(target) or has_flag(flags, "snippet") then
            effective_type = "snippet"
        else
            effective_type = "plugin"
        end
    end

    local effective_flags = visible_flags(flags)
    local teleid = first_nonempty(flag_value(effective_flags, "id-as"), trim(target))

    return {
        name = package_name_from_target(target, effective_type),
        target = trim(target),
        teleid = teleid,
        command = select_command(effective_type, flags),
        packageType = effective_type,
        installPath = "",
        source = trim(target),
        flags = effective_flags,
    }
end

local function descriptor_from_package(context, pkg, global_flags)
    local target = request_name(pkg)
    if target == "" then
        return nil, "zinit package name missing"
    end

    local flags = merge_flags(global_flags, object_flags(pkg))
    flags = apply_version_flag(flags, read_field(pkg, "version"))
    return normalize_descriptor(context, target, flags, nil)
end

local function descriptor_from_local(context, path, global_flags)
    local target = trim(path)
    if target == "" then
        return nil, "zinit local path missing"
    end

    local flags = shallow_copy(global_flags or {})
    flags = apply_version_flag(flags, read_field(context, "version") or read_field(read_field(context, "request"), "version"))
    local package_type = detect_local_kind(context, target, flags)
    return normalize_descriptor(context, target, flags, package_type)
end

local function normalize_request_flags(context, packages)
    local merged = {}
    merged = merge_flags(merged, object_flags(context))
    merged = merge_flags(merged, object_flags(read_field(context, "request")))
    if type(packages) == "table" then
        for _, pkg in ipairs(packages) do
            local package_flags = read_field(pkg, "sharedFlags")
            if type(package_flags) == "table" then
                merged = merge_flags(merged, package_flags)
            end
        end
    end
    return merged
end

local function ice_token(flag)
    local cleaned = trim(flag)
    local key, value = cleaned:match("^([^=]+)=(.*)$")
    if key == nil then
        return cleaned
    end
    return trim(key) .. double_quote(value)
end

local function install_body(record)
    local lines = {}
    if #record.flags > 0 then
        local tokens = {}
        for _, flag in ipairs(record.flags) do
            tokens[#tokens + 1] = ice_token(flag)
        end
        lines[#lines + 1] = "zinit ice " .. table.concat(tokens, " ")
    end
    lines[#lines + 1] = "zinit " .. record.command .. " " .. shell_quote(record.target)
    return table.concat(lines, "; ")
end

local function resolve_install_path(context, paths, record)
    if record.packageType == "local-plugin" then
        return record.target
    end

    local result = run_zinit(context, paths, "zinit cd " .. shell_quote(record.teleid or record.target) .. " >/dev/null 2>&1; pwd")
    if result ~= nil and result.success then
        local value = parse_single_value(result.stdout)
        if value ~= nil then
            return value
        end
    end

    if record.packageType == "plugin" then
        return join_path(paths.pluginsDir, (record.teleid or record.target):gsub("/", "---"))
    end
    return ""
end

local function serialize_record(record)
    local flags = table.concat(record.flags or {}, ",")
    local values = {
        record.name,
        record.target,
        record.teleid,
        record.command,
        record.packageType,
        record.installPath,
        record.source,
        flags,
    }

    for index, value in ipairs(values) do
        values[index] = sanitize_field(value)
    end
    return table.concat(values, "\t")
end

local function parse_record(line)
    local fields = split_tsv(line)
    if #fields < #MANIFEST_FIELDS then
        return nil
    end

    return {
        name = trim(fields[1]),
        target = trim(fields[2]),
        teleid = trim(fields[3]),
        command = trim(fields[4]),
        packageType = trim(fields[5]),
        installPath = trim(fields[6]),
        source = trim(fields[7]),
        flags = split_csv(fields[8]),
    }
end

local function read_manifest(context, paths)
    local result = exec_run(context, "cat " .. shell_quote(paths.manifestPath))
    if result == nil or not result.success then
        return {}
    end

    local records = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            local record = parse_record(cleaned)
            if record ~= nil then
                records[#records + 1] = record
            end
        end
    end
    return records
end

local function write_manifest(context, paths, records)
    local lines = {}
    for _, record in ipairs(records or {}) do
        lines[#lines + 1] = serialize_record(record)
    end
    local content = #lines > 0 and (table.concat(lines, "\n") .. "\n") or ""
    local command = "mkdir -p " .. shell_quote(dirname(paths.manifestPath))
        .. " && printf %s " .. shell_quote(content)
        .. " > " .. shell_quote(paths.manifestPath)
    local result = exec_run(context, command)
    if result ~= nil and result.success then
        return true, nil
    end
    return false, first_nonempty(result and result.stderr, result and result.stdout, "unable to write zinit manifest")
end

local function write_loadfile(context, paths, records)
    local lines = { "# Managed by ReqPack zinit plugin" }
    for _, record in ipairs(records or {}) do
        if #record.flags > 0 then
            local tokens = {}
            for _, flag in ipairs(record.flags) do
                tokens[#tokens + 1] = ice_token(flag)
            end
            lines[#lines + 1] = "zinit ice " .. table.concat(tokens, " ")
        end
        lines[#lines + 1] = "zinit " .. record.command .. " " .. shell_quote(record.target)
    end
    local content = table.concat(lines, "\n") .. "\n"
    local command = "mkdir -p " .. shell_quote(dirname(paths.loadfilePath))
        .. " && printf %s " .. shell_quote(content)
        .. " > " .. shell_quote(paths.loadfilePath)
    local result = exec_run(context, command)
    if result ~= nil and result.success then
        return true, nil
    end
    return false, first_nonempty(result and result.stderr, result and result.stdout, "unable to write zinit loadfile")
end

local function persist_state(context, paths, records)
    local ok, err = write_manifest(context, paths, records)
    if not ok then
        return false, err
    end
    ok, err = write_loadfile(context, paths, records)
    if not ok then
        return false, err
    end
    return true, nil
end

local function sort_records(records)
    table.sort(records, function(left, right)
        local left_key = trim(left.teleid or left.target or left.name or "")
        local right_key = trim(right.teleid or right.target or right.name or "")
        return left_key < right_key
    end)
    return records
end

local function record_matches(record, needle)
    local cleaned = trim(needle)
    if cleaned == "" then
        return false
    end

    for _, candidate in ipairs({ record.name, record.target, record.teleid, record.installPath }) do
        if trim(candidate) == cleaned then
            return true
        end
        if lower(candidate) == lower(cleaned) then
            return true
        end
    end
    return false
end

local function find_record(records, needle)
    for index, record in ipairs(records or {}) do
        if record_matches(record, needle) then
            return record, index
        end
    end
    return nil, nil
end

local function upsert_record(records, new_record)
    local _, index = find_record(records, new_record.teleid)
    if index == nil then
        _, index = find_record(records, new_record.target)
    end
    if index ~= nil then
        records[index] = new_record
    else
        records[#records + 1] = new_record
    end
    return records
end

local function path_exists(context, path)
    local cleaned = trim(path)
    if cleaned == "" then
        return false
    end
    local result = exec_run(context, "test -e " .. shell_quote(cleaned))
    return result ~= nil and result.success == true
end

local function git_head(context, path)
    local result = exec_run(context, "git -C " .. shell_quote(path) .. " rev-parse HEAD")
    if result == nil or not result.success then
        return nil
    end
    return parse_single_value(result.stdout)
end

local function git_remote_head(context, path)
    local result = exec_run(context, "git -C " .. shell_quote(path) .. " ls-remote origin HEAD")
    if result == nil or not result.success then
        return nil
    end
    local line = parse_single_value(result.stdout)
    if line == nil then
        return nil
    end
    local sha = trim(line:match("^(%S+)"))
    return non_empty(sha)
end

local function package_status(context, record)
    if not path_exists(context, record.installPath) then
        return false, "available", nil, nil
    end

    if record.packageType ~= "plugin" then
        return true, "installed", nil, nil
    end

    local current = git_head(context, record.installPath)
    local latest = git_remote_head(context, record.installPath)
    if current ~= nil and latest ~= nil and current ~= latest then
        return true, "outdated", current, latest
    end
    return true, "installed", current, latest
end

local function record_to_package(context, record, forced_status)
    local installed, status, current, latest = package_status(context, record)
    if forced_status ~= nil then
        status = forced_status
        if forced_status == "removed" then
            installed = false
        elseif forced_status == "available" then
            installed = false
        end
    end

    local extra = {
        command = record.command,
        installPath = record.installPath,
        source = record.source,
        flags = table.concat(record.flags or {}, ","),
        teleid = record.teleid,
    }
    if current ~= nil then
        extra.currentCommit = current
    end
    if latest ~= nil then
        extra.latestCommit = latest
    end

    return {
        name = record.name,
        packageId = build_package_id(record),
        version = current,
        latestVersion = latest,
        installed = installed,
        status = status,
        summary = "Managed zinit " .. record.packageType,
        description = record.target,
        packageType = record.packageType,
        type = "package",
        extraFields = extra,
    }
end

local function package_request_action(pkg)
    local action = read_field(pkg, "action")
    if type(action) == "number" then
        return ""
    end
    return lower(action or "")
end

plugin.fileExtensions = {}

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
    return { "Package Manager", "Zsh", "zinit" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end

    local paths = runtime_paths({})
    local records = read_manifest(nil, paths)
    local filtered = {}
    for _, pkg in ipairs(requested) do
        local target = request_name(pkg)
        local record = find_record(records, target)
        local action = package_request_action(pkg)
        if action == "remove" or action == "update" then
            if record ~= nil then
                filtered[#filtered + 1] = pkg
            end
        elseif record == nil or not path_exists(nil, record.installPath) then
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

    local shared_flags = normalize_request_flags(context, requested)
    local paths = runtime_paths(shared_flags)
    local ok, err = ensure_runtime_dirs(context, paths)
    if not ok then
        tx_failed(context, err)
        return false
    end

    if not manager_exists(context, paths) then
        ok, err = bootstrap_manager(context, paths)
        if not ok then
            tx_failed(context, err)
            return false
        end
    end

    begin_step(context, "install zinit packages")
    local records = read_manifest(context, paths)
    local installed = {}
    for _, pkg in ipairs(requested) do
        local record, descriptor_error = descriptor_from_package(context, pkg, shared_flags)
        if record == nil then
            tx_failed(context, descriptor_error or "zinit package resolve failed")
            return false
        end

        local result = run_zinit(context, paths, install_body(record))
        if result == nil or not result.success then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "zinit install failed for " .. record.target))
            return false
        end

        record.installPath = resolve_install_path(context, paths, record)
        upsert_record(records, record)
        installed[#installed + 1] = record_to_package(context, record, "installed")
    end

    sort_records(records)
    ok, err = persist_state(context, paths, records)
    if not ok then
        tx_failed(context, err)
        return false
    end

    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local shared_flags = normalize_request_flags(context, {})
    local paths = runtime_paths(shared_flags)
    local ok, err = ensure_runtime_dirs(context, paths)
    if not ok then
        tx_failed(context, err)
        return false
    end

    if not manager_exists(context, paths) then
        ok, err = bootstrap_manager(context, paths)
        if not ok then
            tx_failed(context, err)
            return false
        end
    end

    begin_step(context, "install local zinit target")
    local record, descriptor_error = descriptor_from_local(context, path, shared_flags)
    if record == nil then
        tx_failed(context, descriptor_error or "zinit local target resolve failed")
        return false
    end

    local result = run_zinit(context, paths, install_body(record))
    if result == nil or not result.success then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "zinit local install failed for " .. record.target))
        return false
    end

    record.installPath = resolve_install_path(context, paths, record)
    local records = read_manifest(context, paths)
    upsert_record(records, record)
    sort_records(records)
    ok, err = persist_state(context, paths, records)
    if not ok then
        tx_failed(context, err)
        return false
    end

    emit_event(context, "installed", { record_to_package(context, record, "installed") })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    local shared_flags = normalize_request_flags(context, requested)
    local paths = runtime_paths(shared_flags)
    local records = read_manifest(context, paths)
    begin_step(context, "remove zinit packages")

    local removed = {}
    for _, pkg in ipairs(requested) do
        local needle = request_name(pkg)
        local record, index = find_record(records, needle)
        if record ~= nil and index ~= nil then
            if record.packageType == "plugin" or record.packageType == "snippet" then
                local result = run_zinit(context, paths, "zinit delete " .. shell_quote(record.teleid or record.target))
                if result == nil or not result.success then
                    tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "zinit remove failed for " .. record.target))
                    return false
                end
            end

            table.remove(records, index)
            removed[#removed + 1] = record_to_package(context, record, "removed")
        end
    end

    sort_records(records)
    local ok, err = persist_state(context, paths, records)
    if not ok then
        tx_failed(context, err)
        return false
    end

    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    local shared_flags = normalize_request_flags(context, requested)
    local paths = runtime_paths(shared_flags)
    if not manager_exists(context, paths) then
        tx_failed(context, "zinit not installed")
        return false
    end

    local records = read_manifest(context, paths)
    local targets = {}
    if #requested == 0 then
        for _, record in ipairs(records) do
            if record.packageType == "plugin" or record.packageType == "snippet" then
                targets[#targets + 1] = record
            end
        end
    else
        for _, pkg in ipairs(requested) do
            local needle = request_name(pkg)
            local record = find_record(records, needle)
            if record ~= nil then
                targets[#targets + 1] = record
            end
        end
    end

    begin_step(context, "update zinit packages")
    local updated = {}
    for _, record in ipairs(targets) do
        local result = run_zinit(context, paths, "zinit update " .. shell_quote(record.teleid or record.target))
        if result == nil or not result.success then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "zinit update failed for " .. record.target))
            return false
        end
        record.installPath = resolve_install_path(context, paths, record)
        updated[#updated + 1] = record_to_package(context, record, "installed")
    end

    sort_records(records)
    local ok, err = persist_state(context, paths, records)
    if not ok then
        tx_failed(context, err)
        return false
    end

    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local paths = runtime_paths(normalize_request_flags(context, {}))
    local records = read_manifest(context, paths)
    local items = {}
    for _, record in ipairs(records) do
        if path_exists(context, record.installPath) then
            items[#items + 1] = record_to_package(context, record)
        end
    end
    sort_records(items)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local paths = runtime_paths(normalize_request_flags(context, {}))
    local records = read_manifest(context, paths)
    local items = {}
    for _, record in ipairs(records) do
        if record.packageType == "plugin" and path_exists(context, record.installPath) then
            local item = record_to_package(context, record)
            if item.status == "outdated" then
                items[#items + 1] = item
            end
        end
    end
    sort_records(items)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned_prompt = trim(prompt)
    if cleaned_prompt == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local paths = runtime_paths(normalize_request_flags(context, {}))
    local records = read_manifest(context, paths)
    local items = {}
    for _, record in ipairs(records) do
        local haystack = table.concat({ lower(record.name), lower(record.target), lower(record.teleid) }, " ")
        if haystack:find(lower(cleaned_prompt), 1, true) ~= nil then
            items[#items + 1] = record_to_package(context, record)
        end
    end
    sort_records(items)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local needle = trim(name)
    if needle == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local paths = runtime_paths(normalize_request_flags(context, {}))
    local record = find_record(read_manifest(context, paths), needle)
    if record == nil then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local item = record_to_package(context, record)
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if type(package) ~= "table" then
        return nil
    end

    local descriptor, err = descriptor_from_package(context, package, normalize_request_flags(context, { package }))
    if descriptor == nil then
        log_warn(context, err or "zinit package resolve failed")
        return nil
    end

    local resolved = shallow_copy(package)
    resolved.name = descriptor.name
    resolved.packageId = build_package_id(descriptor)
    resolved.packageType = descriptor.packageType
    resolved.type = "package"
    resolved.extraFields = {
        command = descriptor.command,
        source = descriptor.source,
        flags = table.concat(descriptor.flags or {}, ","),
        teleid = descriptor.teleid,
    }
    return resolved
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
        ecosystemScopes = { "zinit", "zsh" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".local/share/reqpack/zinit" },
            { kind = "user-home-subpath", value = ".cache/reqpack/zinit" },
        },
        networkScopes = { "*" },
        privilegeLevel = "user",
        purlType = "generic",
    }
end

return plugin
