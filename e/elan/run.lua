plugin = {}

local PLUGIN_ID = "elan"
local PLUGIN_NAME = "elan"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "elan"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return tostring(value or ""):lower()
end

local function non_empty(value)
    local cleaned = trim(value)
    if cleaned == "" then
        return nil
    end
    return cleaned
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
        if line ~= "" then
            lines[#lines + 1] = line
        end
    end
    return lines
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

local function normalize_exec_result(...)
    local result = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        local value_type = type(value)
        if value_type == "table" then
            for key, item in pairs(value) do
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

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. binary .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function request_object(context)
    return read_field(context, "request")
end

local function sequence_values(value)
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local items = {}
    local seen = {}
    local function append(item)
        if item == nil or seen[item] then
            return
        end
        seen[item] = true
        items[#items + 1] = item
    end
    local ok = pcall(function()
        for _, item in ipairs(value) do
            append(item)
        end
    end)
    if ok and #items > 0 then
        return items
    end
    local index = 1
    while true do
        local item = read_field(value, index)
        if item == nil then
            break
        end
        append(item)
        index = index + 1
    end
    if #items > 0 then
        return items
    end
    local pair_items = {}
    ok = pcall(function()
        for key, item in pairs(value) do
            pair_items[#pair_items + 1] = {
                key = key,
                item = item,
            }
        end
    end)
    if ok and #pair_items > 0 then
        table.sort(pair_items, function(left, right)
            if type(left.key) == "number" and type(right.key) == "number" then
                return left.key < right.key
            end
            return tostring(left.key) < tostring(right.key)
        end)
        for _, entry in ipairs(pair_items) do
            append(entry.item)
        end
    end
    return items
end

local function request_packages(context, fallback)
    local candidates = {
        read_field(request_object(context), "packages"),
        read_field(context, "packages"),
        fallback,
    }
    for _, candidate in ipairs(candidates) do
        local items = sequence_values(candidate)
        if #items > 0 then
            return items
        end
    end
    return {}
end

local function mutation_packages(context, packages)
    local items = request_packages(context, packages)
    if #items > 0 then
        return items
    end
    local request = request_object(context)
    local synthetic = {}
    local name = non_empty(read_field(request, "name")) or non_empty(read_field(context, "name"))
    local version = non_empty(read_field(request, "version")) or non_empty(read_field(context, "version"))
    if name ~= nil then
        synthetic[1] = {
            action = non_empty(read_field(request, "action")) or non_empty(read_field(context, "action")),
            name = name,
            version = version,
            extraFields = shallow_copy(extra_fields(request)),
        }
    end
    return synthetic
end

local function iter_packages(packages)
    local items = {}
    local ok = pcall(function()
        for _, pkg in ipairs(packages or {}) do
            items[#items + 1] = pkg
        end
    end)
    if ok and #items > 0 then
        return items
    end
    return nil
end

local function request_prompt(context, fallback)
    return non_empty(fallback) or non_empty(read_field(request_object(context), "prompt")) or non_empty(read_field(context, "prompt")) or ""
end

local function request_local_path(context, fallback)
    return non_empty(fallback)
        or non_empty(read_field(request_object(context), "localPath"))
        or non_empty(read_field(request_object(context), "path"))
        or non_empty(read_field(context, "localPath"))
        or non_empty(read_field(context, "path"))
end

local function extra_fields(value)
    local extra = read_field(value, "extraFields")
    if type(extra) == "table" then
        return extra
    end
    return {}
end

local function boolish(value)
    local cleaned = lower(trim(value))
    return cleaned == "1" or cleaned == "true" or cleaned == "yes" or cleaned == "on"
end

local function toolchain_from_request(pkg)
    if type(pkg) ~= "table" and type(pkg) ~= "userdata" then
        return nil
    end
    local name = non_empty(read_field(pkg, "name"))
    local version = non_empty(read_field(pkg, "version"))
    if name == nil then
        return nil
    end
    if version ~= nil and not name:find(":", 1, true) and not name:find("/", 1, true) and not name:match("^v?%d") and name ~= version then
        return name .. ":" .. version
    end
    return name
end

local function basename(path)
    local cleaned = trim(path)
    cleaned = cleaned:gsub("[/\\]+$", "")
    local name = cleaned:match("([^/\\]+)$")
    if name == nil or name == "" then
        return "local-toolchain"
    end
    return name
end

local function sort_items(items)
    table.sort(items, function(left, right)
        local left_key = trim(left.packageId or left.name or "")
        local right_key = trim(right.packageId or right.name or "")
        return left_key < right_key
    end)
    return items
end

local function build_package_id(name)
    local cleaned = trim(name)
    if cleaned == "" then
        return nil
    end
    return PLUGIN_ID .. "/" .. cleaned
end

local function elan_home()
    if os ~= nil and type(os.getenv) == "function" then
        local from_env = non_empty(os.getenv("ELAN_HOME"))
        if from_env ~= nil then
            return from_env
        end
        local home = non_empty(os.getenv("HOME"))
        if home ~= nil then
            return home .. "/.elan"
        end
    end
    return "$HOME/.elan"
end

local function parse_toolchain_list(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" and lower(cleaned) ~= "no installed toolchains" then
            items[#items + 1] = {
                name = cleaned,
                rawLine = line,
            }
        end
    end
    return items
end

local function parse_show(stdout)
    local info = {
        installed = {},
        active = nil,
    }
    local section = nil
    local lines = split_lines(stdout)
    local index = 1
    while index <= #lines do
        local line = trim(lines[index])
        if line == "installed toolchains" then
            section = "installed"
            index = index + 2
        elseif line == "active toolchain" then
            section = "active"
            index = index + 2
        elseif line ~= "" then
            if section == "installed" then
                local name = trim(line:gsub("%s+%(.+$", ""))
                local entry = info.installed[name] or { name = name }
                if line:find("%(default%)", 1, false) ~= nil then
                    entry.isDefault = true
                end
                local linked_path = line:match("%((linked to local path .-)%)$")
                if linked_path ~= nil then
                    entry.linkedPath = trim(linked_path:gsub("^linked to local path", ""))
                end
                entry.rawLine = trim(line)
                info.installed[name] = entry
            elseif section == "active" and info.active == nil then
                if line ~= "no active toolchain" then
                    local active_name = trim(line:gsub("%s+%(.+$", ""))
                    local reason = line:match("%((.+)%)")
                    info.active = {
                        name = active_name,
                        reason = non_empty(reason),
                    }
                else
                    info.active = false
                end
            end
        end
        index = index + 1
    end
    return info
end

local function decode_json_string(value)
    local quoted = tostring(value or "")
    quoted = quoted:gsub('\\u(%x%x%x%x)', function(hex)
        local code = tonumber(hex, 16)
        if code == nil then
            return ""
        end
        if code <= 0x7F then
            return string.char(code)
        elseif code <= 0x7FF then
            return string.char(0xC0 + math.floor(code / 0x40), 0x80 + (code % 0x40))
        else
            local b1 = 0xE0 + math.floor(code / 0x1000)
            local b2 = 0x80 + (math.floor(code / 0x40) % 0x40)
            local b3 = 0x80 + (code % 0x40)
            return string.char(b1, b2, b3)
        end
    end)
    quoted = quoted:gsub('\\"', '"')
    quoted = quoted:gsub('\\/', '/')
    quoted = quoted:gsub('\\b', '\b')
    quoted = quoted:gsub('\\f', '\f')
    quoted = quoted:gsub('\\n', '\n')
    quoted = quoted:gsub('\\r', '\r')
    quoted = quoted:gsub('\\t', '\t')
    quoted = quoted:gsub('\\\\', '\\')
    return quoted
end

local function parse_dump_state(stdout)
    local text = trim(stdout)
    if text == "" then
        return nil
    end

    local state = {
        installed = {},
        defaultUnresolved = nil,
        defaultResolvedCached = nil,
        activeOverrideUnresolved = nil,
        activeOverrideReason = nil,
        activeResolvedCached = nil,
    }

    for resolved_name, path in text:gmatch('{%s*"resolved_name"%s*:%s*"(.-)"%s*,%s*"path"%s*:%s*"(.-)"%s*}') do
        state.installed[#state.installed + 1] = {
            name = decode_json_string(resolved_name),
            path = decode_json_string(path),
        }
    end

    local default_block = text:match('"default"%s*:%s*({.-})%s*,%s*"active_override"')
    if default_block ~= nil then
        local unresolved = default_block:match('"unresolved"%s*:%s*"(.-)"')
        local cached = default_block:match('"cached"%s*:%s*"(.-)"')
        state.defaultUnresolved = unresolved and decode_json_string(unresolved) or nil
        state.defaultResolvedCached = cached and decode_json_string(cached) or nil
    end

    local override_block = text:match('"active_override"%s*:%s*(%b{})')
    if override_block ~= nil then
        local unresolved = override_block:match('"unresolved"%s*:%s*"(.-)"')
        local reason = override_block:match('"reason"%s*:%s*"(.-)"')
        state.activeOverrideUnresolved = unresolved and decode_json_string(unresolved) or nil
        state.activeOverrideReason = reason and decode_json_string(reason) or nil
    end

    local resolved_active_block = text:match('"resolved_active"%s*:%s*(%b{})')
    if resolved_active_block ~= nil then
        local cached = resolved_active_block:match('"cached"%s*:%s*"(.-)"')
        state.activeResolvedCached = cached and decode_json_string(cached) or nil
    end

    return state
end

local function query_dump_state(context)
    local result = exec_run(context, "elan dump-state --no-net")
    if result == nil or result.success ~= true then
        return nil, "elan dump-state failed"
    end
    local parsed = parse_dump_state(result.stdout)
    if parsed == nil then
        return nil, "elan dump-state parse failed"
    end
    return parsed, nil
end

local function query_toolchain_list(context)
    local result = exec_run(context, "elan toolchain list")
    if result == nil or result.success ~= true then
        return nil, "elan toolchain list failed"
    end
    return parse_toolchain_list(result.stdout), nil
end

local function query_show(context)
    local result = exec_run(context, "elan show")
    if result == nil or result.success ~= true then
        return nil, "elan show failed"
    end
    return parse_show(result.stdout), nil
end

local function installed_name_set(context)
    local listed, err = query_toolchain_list(context)
    if listed == nil then
        return nil, err
    end
    local set = {}
    for _, item in ipairs(listed) do
        set[lower(item.name)] = true
    end
    return set, nil
end

local function build_item(name, show_info, dump_state)
    local cleaned = trim(name)
    if cleaned == "" then
        return nil
    end

    local entry = show_info ~= nil and show_info.installed[cleaned] or nil
    local active = show_info ~= nil and type(show_info.active) == "table" and show_info.active.name == cleaned
    local extra = {
        elanHome = elan_home(),
    }
    if entry ~= nil and entry.isDefault then
        extra.default = "true"
    end
    if active then
        extra.active = "true"
    end
    if show_info ~= nil and type(show_info.active) == "table" and show_info.active.name == cleaned and show_info.active.reason ~= nil then
        extra.activeReason = show_info.active.reason
    end
    if entry ~= nil and entry.linkedPath ~= nil then
        extra.linkedPath = entry.linkedPath
        extra.installPath = entry.linkedPath
    end
    if entry ~= nil and entry.rawLine ~= nil then
        extra.rawLine = entry.rawLine
    end
    if dump_state ~= nil and dump_state.activeOverrideUnresolved == cleaned and dump_state.activeOverrideReason ~= nil then
        extra.overrideReason = dump_state.activeOverrideReason
    end

    local status = "installed"
    local summary = "Installed Lean toolchain managed by elan"
    if active then
        status = "active"
        summary = "Active Lean toolchain managed by elan"
    elseif entry ~= nil and entry.isDefault then
        status = "default"
        summary = "Default Lean toolchain managed by elan"
    end

    return {
        name = cleaned,
        packageId = build_package_id(cleaned),
        version = cleaned,
        installed = true,
        status = status,
        summary = summary,
        description = summary,
        installPath = extra.installPath,
        packageType = "toolchain",
        type = "package",
        extraFields = next(extra) ~= nil and extra or nil,
    }
end

local function standard_channel_items()
    local items = {}
    for _, name in ipairs({ "stable", "beta", "nightly" }) do
        items[#items + 1] = {
            name = name,
            packageId = build_package_id(name),
            version = name,
            installed = false,
            status = "available",
            summary = "Well-known elan Lean toolchain channel",
            description = "Well-known elan Lean toolchain channel",
            packageType = "toolchain",
            type = "package",
            extraFields = { elanHome = elan_home() },
        }
    end
    return items
end

local function request_override_path(pkg, context)
    local extra = extra_fields(pkg)
    return non_empty(extra.overridePath)
        or non_empty(read_field(request_object(context), "overridePath"))
        or non_empty(read_field(context, "overridePath"))
end

local function request_set_default(pkg, context)
    local extra = extra_fields(pkg)
    if extra.setDefault ~= nil then
        return extra.setDefault == true or boolish(extra.setDefault)
    end
    local request = request_object(context)
    if request ~= nil and read_field(request, "setDefault") ~= nil then
        return read_field(request, "setDefault") == true or boolish(read_field(request, "setDefault"))
    end
    return false
end

local function run_override_set(context, toolchain, path)
    if non_empty(path) == nil then
        local result = exec_run(context, "elan override set " .. shell_quote(toolchain))
        return result ~= nil and result.success == true
    end
    local script = "cd " .. shell_quote(path) .. " && elan override set " .. shell_quote(toolchain)
    local result = exec_run(context, "sh -lc " .. shell_quote(script))
    return result ~= nil and result.success == true
end

local function make_install_event_item(toolchain)
    return {
        name = toolchain,
        packageId = build_package_id(toolchain),
        version = toolchain,
        packageType = "toolchain",
        type = "package",
    }
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
    return { "language", "package-manager", "lean" }
end

function plugin.init()
    return command_exists(nil, REQUIRED_BINARY)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "lean" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".elan" },
        },
        networkScopes = {},
        privilegeLevel = "none",
        purlType = "generic",
    }
end

function plugin.getMissingPackages(packages)
    local requested = iter_packages(packages) or mutation_packages(nil, packages)
    local installed, err = installed_name_set(nil)
    if installed == nil then
        return requested
    end
    local missing = {}
    for _, pkg in ipairs(requested) do
        local action = lower(read_field(pkg, "action") or "")
        local toolchain = toolchain_from_request(pkg)
        if toolchain ~= nil then
            local present = installed[lower(toolchain)] == true
            if action == "install" then
                if not present then
                    missing[#missing + 1] = pkg
                end
            elseif action == "remove" then
                if present then
                    missing[#missing + 1] = pkg
                end
            elseif action == "update" then
                missing[#missing + 1] = pkg
            end
        end
    end
    return missing
end

function plugin.install(context, packages)
    local requested = iter_packages(packages) or mutation_packages(context, packages)
    if #requested == 0 then
        return true
    end
    local installed = {}
    for _, pkg in ipairs(requested) do
        local toolchain = toolchain_from_request(pkg)
        if toolchain ~= nil then
            begin_step(context, "Installing " .. toolchain)
            local result = exec_run(context, "elan toolchain install " .. shell_quote(toolchain))
            if result == nil or result.success ~= true then
                tx_failed(context, "elan install failed for " .. toolchain)
                return false
            end
            if request_set_default(pkg, context) then
                local default_result = exec_run(context, "elan default " .. shell_quote(toolchain))
                if default_result == nil or default_result.success ~= true then
                    tx_failed(context, "elan default failed for " .. toolchain)
                    return false
                end
            end
            local override_path = request_override_path(pkg, context)
            if override_path ~= nil then
                if not run_override_set(context, toolchain, override_path) then
                    tx_failed(context, "elan override set failed for " .. toolchain)
                    return false
                end
            end
            installed[#installed + 1] = make_install_event_item(toolchain)
        end
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = request_local_path(context, path)
    if local_path == nil then
        tx_failed(context, "missing local path")
        return false
    end
    local packages = request_packages(context, {})
    local pkg = packages[1] or request_object(context) or context or {}
    local extra = extra_fields(pkg)
    local link_name = non_empty(read_field(pkg, "name")) or non_empty(extra.linkName) or basename(local_path)
    begin_step(context, "Linking local toolchain " .. link_name)
    local result = exec_run(context, "elan toolchain link " .. shell_quote(link_name) .. " " .. shell_quote(local_path))
    if result == nil or result.success ~= true then
        tx_failed(context, "elan local link failed")
        return false
    end
    emit_event(context, "installed", {
        {
            name = link_name,
            packageId = build_package_id(link_name),
            version = link_name,
            localTarget = true,
            packageType = "toolchain",
            type = "package",
            extraFields = {
                linkedPath = local_path,
                elanHome = elan_home(),
            },
        }
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = iter_packages(packages) or mutation_packages(context, packages)
    if #requested == 0 then
        return true
    end
    local removed = {}
    for _, pkg in ipairs(requested) do
        local toolchain = toolchain_from_request(pkg)
        if toolchain ~= nil then
            begin_step(context, "Removing " .. toolchain)
            local result = exec_run(context, "elan toolchain uninstall " .. shell_quote(toolchain))
            if result == nil or result.success ~= true then
                tx_failed(context, "elan uninstall failed for " .. toolchain)
                return false
            end
            removed[#removed + 1] = make_install_event_item(toolchain)
        end
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local targets = iter_packages(packages) or mutation_packages(context, packages)
    if #targets == 0 then
        local listed = select(1, query_toolchain_list(context))
        if type(listed) == "table" then
            targets = {}
            for _, item in ipairs(listed) do
                targets[#targets + 1] = { name = item.name, action = "update" }
            end
        else
            targets = {}
        end
    end
    local updated = {}
    for _, pkg in ipairs(targets) do
        local toolchain = toolchain_from_request(pkg)
        if toolchain ~= nil then
            begin_step(context, "Updating " .. toolchain)
            local result = exec_run(context, "elan toolchain install " .. shell_quote(toolchain))
            if result == nil or result.success ~= true then
                tx_failed(context, "elan update failed for " .. toolchain)
                return false
            end
            local override_path = request_override_path(pkg, context)
            if override_path ~= nil then
                if not run_override_set(context, toolchain, override_path) then
                    tx_failed(context, "elan override set failed for " .. toolchain)
                    return false
                end
            end
            updated[#updated + 1] = make_install_event_item(toolchain)
        end
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    if not command_exists(context, REQUIRED_BINARY) then
        emit_event(context, "listed", {})
        return {}
    end
    local listed, list_error = query_toolchain_list(context)
    if listed == nil then
        log_warn(context, list_error)
        emit_event(context, "listed", {})
        return {}
    end
    local show_info = nil
    local dump_state = nil
    show_info = select(1, query_show(context))
    dump_state = select(1, query_dump_state(context))
    local items = {}
    for _, item in ipairs(listed) do
        local built = build_item(item.name, show_info, dump_state)
        if built ~= nil then
            items[#items + 1] = built
        end
    end
    sort_items(items)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    if not command_exists(context, REQUIRED_BINARY) then
        emit_event(context, "outdated", {})
        return {}
    end
    local items = {}
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned = request_prompt(context, prompt)
    if cleaned == "" then
        emit_event(context, "searched", {})
        return {}
    end
    local lowered_prompt = lower(cleaned)
    local list_items = plugin.list(context)
    local seen = {}
    local results = {}
    for _, item in ipairs(list_items or {}) do
        if lower(item.name or ""):find(lowered_prompt, 1, true) ~= nil then
            seen[item.name] = true
            results[#results + 1] = item
        end
    end
    for _, item in ipairs(standard_channel_items()) do
        local search_blob = lower((item.name or "") .. " " .. (item.summary or ""))
        if search_blob:find(lowered_prompt, 1, true) ~= nil and not seen[item.name] then
            results[#results + 1] = item
            seen[item.name] = true
        end
    end
    sort_items(results)
    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local target = request_prompt(context, name)
    if target == "" then
        emit_event(context, "informed", {})
        return {}
    end
    local list_items = plugin.list(context)
    for _, item in ipairs(list_items or {}) do
        if item.name == target then
            emit_event(context, "informed", item)
            return item
        end
    end
    for _, item in ipairs(standard_channel_items()) do
        if item.name == target then
            emit_event(context, "informed", item)
            return item
        end
    end
    emit_event(context, "informed", {})
    return {}
end

function plugin.resolvePackage(context, package)
    if type(package) ~= "table" and type(package) ~= "userdata" then
        return nil
    end
    local toolchain = toolchain_from_request(package)
    if toolchain == nil then
        return nil
    end
    local resolved = shallow_copy(package)
    resolved.name = toolchain
    resolved.version = toolchain
    resolved.packageId = build_package_id(toolchain)
    resolved.packageType = "toolchain"
    resolved.type = "package"
    return resolved
end

function plugin.shutdown()
    return true
end

return plugin
