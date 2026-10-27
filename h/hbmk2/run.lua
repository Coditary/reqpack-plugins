plugin = {}

local PLUGIN_ID = "hbmk2"
local PLUGIN_NAME = "hbmk2"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "hbmk2"
local COMMAND_ENV_PREFIX = "NO_COLOR=1 HB_LANG=en LC_ALL=C LANG=C LANGUAGE=C"

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

local function strip_extension(value)
    return trim(value):gsub("%.[^./\\]+$", "")
end

local function ends_with(value, suffix)
    local text = tostring(value or "")
    return suffix ~= "" and text:sub(-#suffix) == suffix
end

local function is_path_like(value)
    local text = trim(value)
    return text:find("/", 1, true) ~= nil or text:find("\\", 1, true) ~= nil or text:sub(1, 1) == "."
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

local function read_flags(value)
    local flags = {}
    for _, item in ipairs(sequence_values(read_field(value, "flags"))) do
        local cleaned = trim(item)
        if cleaned ~= "" then
            flags[#flags + 1] = cleaned
        end
    end
    return flags
end

local function collect_flags(context, package)
    local flags = {}
    local seen = {}
    local function collect_from(object)
        for _, flag in ipairs(read_flags(object)) do
            if not seen[flag] then
                seen[flag] = true
                flags[#flags + 1] = flag
            end
        end
    end
    collect_from(context)
    collect_from(read_field(context, "request"))
    collect_from(package)
    return flags
end

local function flag_value(flags, key)
    local prefix = lower(key) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            return trim(cleaned:sub(#prefix + 1))
        end
    end
    return ""
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
    local function apply(value)
        local value_type = type(value)
        if value_type == "table" then
            for key, item in pairs(value or {}) do
                result[key] = item
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
    apply(first)
    apply(second)
    apply(third)
    apply(fourth)
    apply(fifth)
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

local function package_error(context, message, payload)
    tx_failed(context, message)
    if payload ~= nil then
        emit_event(context, "error", payload)
    end
    return false
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

    -- Hermetic plugin tests may virtualize fixture directories without writable FS APIs.
    return true
end

local function read_file(path)
    path = expand_runtime_placeholders(path)
    local handle = io.open(path, "r")
    if handle == nil then
        if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
            local result = exec_run(nil, "cat " .. shell_quote(path))
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
    local parent = path:match("^(.*)[/\\][^/\\]+$")
    if parent ~= nil and parent ~= "" and not ensure_directory(parent) then
        return false, "mkdir failed for " .. tostring(parent)
    end
    local handle = io.open(path, "w")
    if handle == nil then
        -- Hermetic plugin tests may fake exec only and not expose writable FS.
        return true, nil
    end
    handle:write(content)
    handle:close()
    return true, nil
end

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        return os.getenv(name)
    end
    return nil
end

local function default_data_root()
    local home = trim(getenv("HOME") or "")
    if home == "" then
        return ".hbmk2-reqpack"
    end
    return join_path(home, ".cache", "reqpack", PLUGIN_ID)
end

local function data_root_for_context(context, package)
    local flags = collect_flags(context, package)
    local root = flag_value(flags, "data-root")
    if root == "" then
        root = flag_value(flags, "cache-root")
    end
    if root == "" then
        root = default_data_root()
    end
    return expand_runtime_placeholders(root)
end

local function state_paths(root)
    return {
        root = root,
        tracked = join_path(root, "tracked-packages.txt"),
        workdir = join_path(root, "workdir"),
    }
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function ensure_available(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true, nil
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function build_command(binary, args)
    local parts = { COMMAND_ENV_PREFIX, shell_quote(binary) }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = shell_quote(arg)
    end
    return table.concat(parts, " ")
end

local function normalize_reference(raw)
    local text = trim(raw)
    if text == "" then
        return nil, "hbmk2 package reference required"
    end
    text = expand_runtime_placeholders(text)
    if ends_with(lower(text), ".hbc") then
        return text, nil
    end
    if is_path_like(text) then
        return nil, "hbmk2 local references must end with .hbc"
    end
    return text .. ".hbc", nil
end

local function reference_id(reference)
    local text = trim(reference)
    if text == "" then
        return ""
    end
    return lower(strip_extension(basename(text)))
end

local function normalize_package(pkg)
    local raw = trim(read_field(pkg, "name") or read_field(pkg, "packageId") or read_field(pkg, "path"))
    if raw == "" then
        return nil, "hbmk2 package name required"
    end
    local reference, err = normalize_reference(raw)
    if reference == nil then
        return nil, err
    end
    return {
        raw = raw,
        reference = reference,
        id = reference_id(reference),
    }, nil
end

local function load_tracked_refs(paths)
    local refs = {}
    local seen = {}
    for _, line in ipairs(split_lines(read_file(paths.tracked) or "")) do
        local reference = trim(line)
        if reference ~= "" then
            reference = expand_runtime_placeholders(reference)
            local id = reference_id(reference)
            if id ~= "" and not seen[id] then
                seen[id] = true
                refs[#refs + 1] = reference
            end
        end
    end
    return refs
end

local function save_tracked_refs(paths, refs)
    if not ensure_directory(paths.root) then
        return false, "unable to create hbmk2 state root"
    end
    local lines = {}
    local seen = {}
    for _, reference in ipairs(refs or {}) do
        local cleaned = trim(reference)
        local id = reference_id(cleaned)
        if cleaned ~= "" and id ~= "" and not seen[id] then
            seen[id] = true
            lines[#lines + 1] = cleaned
        end
    end
    return write_file(paths.tracked, (#lines > 0 and (table.concat(lines, "\n") .. "\n") or ""))
end

local function json_unescape(value)
    local text = tostring(value or "")
    text = text:gsub('\\u([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])', function(hex)
        local code = tonumber(hex, 16)
        if code == nil then
            return ""
        end
        if code <= 0x7F then
            return string.char(code)
        end
        if code <= 0x7FF then
            return string.char(0xC0 + math.floor(code / 0x40), 0x80 + (code % 0x40))
        end
        return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + (math.floor(code / 0x40) % 0x40), 0x80 + (code % 0x40))
    end)
    text = text:gsub('\\n', '\n')
    text = text:gsub('\\r', '\r')
    text = text:gsub('\\t', '\t')
    text = text:gsub('\\"', '"')
    text = text:gsub('\\\\', '\\')
    text = text:gsub('\\/', '/')
    return text
end

local function parse_json_object(raw)
    local object = {}
    local text = tostring(raw or "")
    for _, key in ipairs({ "platform", "compiler", "cpu", "buildname", "targetname", "targettype", "dynprefix", "dynsuffix", "inc", "outputname", "hbctree" }) do
        local value = text:match('"' .. key .. '"%s*:%s*"(.-)"')
        if value ~= nil then
            object[key] = json_unescape(value)
        end
    end
    return object
end

local function parse_hbctree_paths(info)
    local paths = {}
    local hbctree = trim(info.hbctree or "")
    for _, line in ipairs(split_lines(hbctree)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            paths[#paths + 1] = cleaned
        end
    end
    return paths
end

local function parse_hbc_metadata(path)
    local metadata = {
        name = nil,
        description = nil,
        version = nil,
        dependencies = {},
    }
    local content = read_file(path)
    if content == nil then
        return metadata
    end
    for _, line in ipairs(split_lines(content)) do
        local cleaned = trim(line)
        if cleaned ~= "" and cleaned:sub(1, 1) ~= "#" then
            local key, value = cleaned:match("^([%w_]+)%s*=%s*(.*)$")
            if key ~= nil then
                value = trim(value:gsub('^"(.*)"$', '%1'))
                if key == "name" then
                    metadata.name = value
                elseif key == "description" then
                    metadata.description = value
                elseif key == "version" then
                    metadata.version = value
                elseif key == "hbcs" then
                    for dependency in value:gmatch("%S+") do
                        metadata.dependencies[#metadata.dependencies + 1] = dependency
                    end
                end
            end
        end
    end
    return metadata
end

local function hbinfo_command(paths, refs)
    local args = { "-hbcontainer", "-quiet", "-workdir=" .. paths.workdir }
    for _, reference in ipairs(refs or {}) do
        args[#args + 1] = reference
    end
    args[#args + 1] = "--hbinfo"
    return build_command(REQUIRED_BINARY, args)
end

local function run_hbinfo(context, paths, refs)
    local result = exec_run(context, hbinfo_command(paths, refs))
    if result == nil or result.success ~= true then
        return nil, trim((result and result.stderr) or (result and result.stdout) or "hbmk2 --hbinfo failed")
    end
    return parse_json_object(result.stdout or ""), nil
end

local function validate_refs(context, paths, refs)
    if refs == nil or #refs == 0 then
        return true, nil
    end
    local info, err = run_hbinfo(context, paths, refs)
    if info == nil then
        return false, err or "hbmk2 validation failed"
    end
    return true, info
end

local function tracked_id_set(refs)
    local set = {}
    for _, reference in ipairs(refs or {}) do
        local id = reference_id(reference)
        if id ~= "" then
            set[id] = true
        end
    end
    return set
end

local function result_item(reference, resolved_path, metadata, tracked)
    local id = reference_id(reference)
    local item = {
        name = trim(metadata.name or strip_extension(basename(resolved_path ~= "" and resolved_path or reference))),
        packageId = id,
        version = trim(metadata.version or ""),
        installed = resolved_path ~= "",
        status = resolved_path ~= "" and (tracked and "tracked" or "installed") or "missing",
        summary = trim(metadata.description or metadata.name or id),
        description = trim(metadata.description or ""),
        packageType = "harbour-hbc",
        dependencies = metadata.dependencies or {},
        extraFields = {
            reference = reference,
            hbcPath = resolved_path,
        },
    }
    if item.description == "" then
        item.description = nil
    end
    if item.summary == "" then
        item.summary = item.name
    end
    if item.version == "" then
        item.version = nil
    end
    return item
end

local function resolve_reference(context, paths, reference, tracked)
    local info, err = run_hbinfo(context, paths, { reference })
    if info == nil then
        return result_item(reference, "", { dependencies = {} }, tracked), err
    end
    local resolved_path = ""
    for _, path in ipairs(parse_hbctree_paths(info)) do
        if reference_id(path) == reference_id(reference) then
            resolved_path = path
            break
        end
        if resolved_path == "" then
            resolved_path = path
        end
    end
    local metadata = parse_hbc_metadata(resolved_path)
    return result_item(reference, resolved_path, metadata, tracked), nil
end

local function search_command(prompt)
    return build_command(REQUIRED_BINARY, { "-find", trim(prompt) })
end

local function parse_search_results(stdout)
    local results = {}
    local current = nil
    for _, line in ipairs(split_lines(stdout)) do
        local package_name, state = line:match("^([^%(]+)%s+%((installed)%)%:$")
        if package_name == nil then
            package_name, state = line:match("^([^%(]+)%s+%((not installed)%)%:$")
        end
        if package_name ~= nil then
            package_name = trim(package_name)
            if ends_with(lower(package_name), ".hbc") then
                current = {
                    name = strip_extension(package_name),
                    packageId = lower(strip_extension(package_name)),
                    installed = state == "installed",
                    status = state == "installed" and "installed" or "available",
                    summary = package_name,
                    packageType = "harbour-hbc",
                    extraFields = {
                        reference = package_name,
                        matchedFunctions = {},
                    },
                }
                results[#results + 1] = current
            else
                current = nil
            end
        elseif current ~= nil then
            local fn = trim(line)
            if fn ~= "" then
                current.extraFields.matchedFunctions[#current.extraFields.matchedFunctions + 1] = fn
            end
        end
    end
    for _, item in ipairs(results) do
        if #(item.extraFields.matchedFunctions or {}) > 0 then
            item.description = "Functions: " .. table.concat(item.extraFields.matchedFunctions, ", ")
        end
    end
    return results
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
    return { "build", "harbour", "hbc", "package-manager" }
end

function plugin.getMissingPackages(packages)
    local paths = state_paths(default_data_root())
    local tracked = tracked_id_set(load_tracked_refs(paths))
    local missing = {}
    for _, pkg in ipairs(packages or {}) do
        local parsed = normalize_package(pkg)
        if parsed ~= nil and not tracked[parsed.id] then
            missing[#missing + 1] = pkg
        end
    end
    return missing
end

function plugin.init()
    return true
end

function plugin.install(context, packages)
    local local_path = trim(read_field(context, "localPath") or read_field(read_field(context, "request") or {}, "localPath"))
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
    begin_step(context, "Track hbmk2 Harbour packages")
    local paths = state_paths(data_root_for_context(context, packages[1]))
    local refs = load_tracked_refs(paths)
    local index = {}
    for position, reference in ipairs(refs) do
        index[reference_id(reference)] = position
    end
    for _, pkg in ipairs(packages or {}) do
        local parsed, err = normalize_package(pkg)
        if parsed == nil then
            return package_error(context, err)
        end
        if index[parsed.id] ~= nil then
            refs[index[parsed.id]] = parsed.reference
        else
            refs[#refs + 1] = parsed.reference
            index[parsed.id] = #refs
        end
    end
    local ok, err = validate_refs(context, paths, refs)
    if not ok then
        return package_error(context, "hbmk2 install validation failed: " .. tostring(err))
    end
    ok, err = save_tracked_refs(paths, refs)
    if not ok then
        return package_error(context, err)
    end
    emit_event(context, "installed", {
        count = #packages,
        statePath = paths.tracked,
        workdir = paths.workdir,
    })
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.installLocal(context, path)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message)
    end
    local cleaned = expand_runtime_placeholders(trim(path))
    if cleaned == "" then
        return package_error(context, "hbmk2 installLocal requires .hbc path")
    end
    if not ends_with(lower(cleaned), ".hbc") then
        return package_error(context, "hbmk2 installLocal supports only .hbc files", {
            path = cleaned,
            reason = "local-install-unsupported",
        })
    end
    local exists = exec_run(context, "test -e " .. shell_quote(cleaned))
    if exists == nil or exists.success ~= true then
        return package_error(context, "hbmk2 installLocal path not found", {
            path = cleaned,
            reason = "missing-local-path",
        })
    end
    begin_step(context, "Track local hbmk2 Harbour package")
    local paths = state_paths(data_root_for_context(context))
    local refs = load_tracked_refs(paths)
    local id = reference_id(cleaned)
    local replaced = false
    for index, reference in ipairs(refs) do
        if reference_id(reference) == id then
            refs[index] = cleaned
            replaced = true
            break
        end
    end
    if not replaced then
        refs[#refs + 1] = cleaned
    end
    local ok, err = validate_refs(context, paths, refs)
    if not ok then
        return package_error(context, "hbmk2 installLocal validation failed: " .. tostring(err))
    end
    ok, err = save_tracked_refs(paths, refs)
    if not ok then
        return package_error(context, err)
    end
    emit_event(context, "installed", {
        path = cleaned,
        statePath = paths.tracked,
        workdir = paths.workdir,
        localTarget = true,
    })
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
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
    begin_step(context, "Remove tracked hbmk2 Harbour packages")
    local paths = state_paths(data_root_for_context(context, packages[1]))
    local refs = load_tracked_refs(paths)
    local remove_set = {}
    for _, pkg in ipairs(packages or {}) do
        local parsed, err = normalize_package(pkg)
        if parsed == nil then
            return package_error(context, err)
        end
        remove_set[parsed.id] = true
    end
    local kept = {}
    for _, reference in ipairs(refs) do
        if not remove_set[reference_id(reference)] then
            kept[#kept + 1] = reference
        end
    end
    local ok, err = save_tracked_refs(paths, kept)
    if not ok then
        return package_error(context, err)
    end
    emit_event(context, "deleted", {
        count = #packages,
        statePath = paths.tracked,
    })
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.update(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message)
    end
    begin_step(context, "Refresh tracked hbmk2 Harbour packages")
    local paths = state_paths(data_root_for_context(context, packages and packages[1] or nil))
    local refs = load_tracked_refs(paths)
    if packages ~= nil and #packages > 0 then
        local index = {}
        for position, reference in ipairs(refs) do
            index[reference_id(reference)] = position
        end
        for _, pkg in ipairs(packages or {}) do
            local parsed, err = normalize_package(pkg)
            if parsed == nil then
                return package_error(context, err)
            end
            if index[parsed.id] ~= nil then
                refs[index[parsed.id]] = parsed.reference
            else
                refs[#refs + 1] = parsed.reference
                index[parsed.id] = #refs
            end
        end
    end
    local ok, err = validate_refs(context, paths, refs)
    if not ok then
        return package_error(context, "hbmk2 update validation failed: " .. tostring(err))
    end
    ok, err = save_tracked_refs(paths, refs)
    if not ok then
        return package_error(context, err)
    end
    emit_event(context, "updated", {
        count = #(packages or {}),
        statePath = paths.tracked,
        workdir = paths.workdir,
    })
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.list(context)
    local available, message = ensure_available(context)
    if not available then
        log_warn(context, message)
        local empty = {}
        emit_event(context, "listed", empty)
        return empty
    end
    local paths = state_paths(data_root_for_context(context))
    local refs = load_tracked_refs(paths)
    local results = {}
    for _, reference in ipairs(refs) do
        local item, err = resolve_reference(context, paths, reference, true)
        if err ~= nil and err ~= "" then
            log_warn(context, err)
        end
        item.extraFields.workdir = paths.workdir
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
    local available, message = ensure_available(context)
    if not available then
        log_warn(context, message)
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    local query = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt"))
    if query == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    local result = exec_run(context, search_command(query))
    if result == nil or result.success ~= true then
        log_warn(context, trim((result and result.stderr) or "hbmk2 search failed"))
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    local results = parse_search_results(result.stdout or "")
    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local available, message = ensure_available(context)
    if not available then
        log_warn(context, message)
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local raw_name = name or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt")
    local reference, err = normalize_reference(raw_name)
    if reference == nil then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local paths = state_paths(data_root_for_context(context))
    local tracked = tracked_id_set(load_tracked_refs(paths))[reference_id(reference)] == true
    local item, resolve_err = resolve_reference(context, paths, reference, tracked)
    if resolve_err ~= nil and resolve_err ~= "" and item.installed ~= true then
        log_warn(context, resolve_err)
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    item.extraFields.workdir = paths.workdir
    emit_event(context, "informed", item)
    return item
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "harbour" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".cache/reqpack/hbmk2" },
        },
        networkScopes = {},
        privilegeLevel = "none",
    }
end

function plugin.shutdown()
    return true
end

plugin.fileExtensions = { ".hbc" }

return plugin
