plugin = {}

local PLUGIN_ID = "fan"
local PLUGIN_NAME = "Fantom Repository Manager"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "fanr"
local DEFAULT_ENV_QUERY = "*"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return tostring(value or ""):lower()
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
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

local function object_flags(value)
    local raw = read_field(value, "flags")
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

local function collect_flags(context, package)
    local flags = {}
    local seen = {}
    local function collect_from(object)
        for _, flag in ipairs(object_flags(object)) do
            local cleaned = trim(flag)
            if cleaned ~= "" and not seen[cleaned] then
                seen[cleaned] = true
                flags[#flags + 1] = cleaned
            end
        end
    end
    collect_from(context)
    collect_from(context ~= nil and context.request or nil)
    collect_from(package)
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
        elseif value_type == "userdata" then
            for _, key in ipairs({ "success", "ok", "stdout", "stderr", "exitCode", "exit_code", "code", "status", "stdoutText", "stderrText" }) do
                local ok, item = pcall(function()
                    return value[key]
                end)
                if ok and item ~= nil and result[key] == nil then
                    result[key] = item
                end
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
    return exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1").success == true
end

local function package_name(package)
    return trim(
        read_field(package, "name")
        or read_field(package, "packageId")
        or read_field(package, "id")
        or package
        or ""
    )
end

local function package_version(package)
    return trim(read_field(package, "version") or "")
end

local function package_action(package)
    return lower(read_field(package, "action") or "")
end

local function make_package_id(name, version)
    local cleaned_name = trim(name)
    local cleaned_version = trim(version)
    if cleaned_name == "" then
        return nil
    end
    if cleaned_version == "" then
        return cleaned_name
    end
    return cleaned_name .. "@" .. cleaned_version
end

local function package_query(package_or_name, maybe_version)
    local value_type = type(package_or_name)
    local structured = value_type == "table" or value_type == "userdata"
    local name = trim(structured and package_name(package_or_name) or package_or_name)
    local version = trim(structured and package_version(package_or_name) or maybe_version)
    if name == "" then
        return nil
    end
    if version ~= "" then
        return name .. " " .. version
    end
    return name
end

local function request_name(context, explicit_name)
    local request = read_field(context, "request")
    return trim(
        explicit_name
        or read_field(context, "name")
        or read_field(request, "name")
        or read_field(context, "prompt")
        or read_field(request, "prompt")
        or ""
    )
end

local function request_local_path(context, explicit_path)
    local request = read_field(context, "request")
    return trim(
        explicit_path
        or read_field(context, "localPath")
        or read_field(request, "localPath")
        or read_field(context, "path")
        or read_field(request, "path")
        or ""
    )
end

local function parse_version_line(line)
    local cleaned = trim(line)
    if cleaned == "" then
        return nil
    end
    local version, details = cleaned:match("^([%d][%w%._%-%+]*)%s*%((.*)%)%s*$")
    if version == nil then
        version = cleaned:match("^([%d][%w%._%-%+]*)%s*$")
    end
    if version == nil then
        return nil
    end

    local item = {
        version = version,
        rawDetails = trim(details or ""),
    }

    if item.rawDetails ~= "" then
        local pieces = {}
        for piece in item.rawDetails:gmatch("[^,]+") do
            pieces[#pieces + 1] = trim(piece)
        end
        if #pieces > 0 then
            item.publishedAt = pieces[1]
        end
        if #pieces > 1 then
            item.size = pieces[2]
        end
    end

    return item
end

local function parse_fanr_blocks(stdout)
    local blocks = {}
    local current = nil

    local function push_current()
        if current ~= nil and trim(current.name) ~= "" and #current.versions > 0 then
            blocks[#blocks + 1] = current
        end
        current = nil
    end

    for _, raw_line in ipairs(split_lines(stdout)) do
        local line = raw_line:gsub("%s+$", "")
        local cleaned = trim(line)
        if cleaned == "" then
            push_current()
        elseif cleaned == "No pods found" or cleaned == "No install pods matched" then
            -- ignore sentinel text
        elseif line:match("^%S+$") ~= nil then
            push_current()
            current = {
                name = cleaned,
                summary = nil,
                versions = {},
            }
        elseif current ~= nil and current.summary == nil and line:match("^%s+") then
            local parsed_version = parse_version_line(cleaned)
            if parsed_version ~= nil then
                current.versions[#current.versions + 1] = parsed_version
            else
                current.summary = cleaned
            end
        elseif current ~= nil and line:match("^%s+") then
            local parsed_version = parse_version_line(cleaned)
            if parsed_version ~= nil then
                current.versions[#current.versions + 1] = parsed_version
            end
        end
    end

    push_current()
    return blocks
end

local function make_item(name, summary, version_item, extra_fields)
    local version = trim(version_item and version_item.version or "")
    local extra = merge_tables(extra_fields, {
        publishedAt = trim(version_item and version_item.publishedAt or ""),
        size = trim(version_item and version_item.size or ""),
        rawDetails = trim(version_item and version_item.rawDetails or ""),
    })
    if extra ~= nil then
        for key, value in pairs(shallow_copy(extra)) do
            if type(value) == "string" and trim(value) == "" then
                extra[key] = nil
            end
        end
        if next(extra) == nil then
            extra = nil
        end
    end

    return {
        name = name,
        packageId = make_package_id(name, version),
        version = version ~= "" and version or nil,
        summary = trim(summary),
        description = trim(summary),
        packageType = "library",
        extraFields = extra,
    }
end

local function blocks_to_latest_items(blocks, installed)
    local items = {}
    for _, block in ipairs(blocks or {}) do
        local latest = block.versions[1]
        if latest ~= nil then
            local item = make_item(block.name, block.summary, latest)
            item.installed = installed == true
            item.status = installed == true and "installed" or "available"
            items[#items + 1] = item
        end
    end
    return items
end

local function parse_info_block(block)
    if block == nil or trim(block.name) == "" then
        return {}
    end
    local latest = block.versions[1]
    local versions = {}
    for _, version_item in ipairs(block.versions or {}) do
        versions[#versions + 1] = trim(version_item.version)
    end
    local item = make_item(block.name, block.summary, latest, {
        availableVersions = versions,
    })
    item.installed = false
    item.status = "available"
    return item
end

local function parse_config(stdout)
    local config = {}
    for _, line in ipairs(split_lines(stdout)) do
        local key, value = line:match("^([%w%._%-]+):%s*(.-)%s*$")
        if key ~= nil and value ~= nil and value ~= "" then
            config[key] = value
        end
    end
    return config
end

local function fanr_config(context)
    local result = exec_run(context, "fanr config")
    if result.success ~= true then
        return nil, result.stderr ~= "" and result.stderr or "fanr config failed"
    end
    return parse_config(result.stdout), nil
end

local function repo_prefix(context, package)
    local flags = collect_flags(context, package)
    local repo = flag_value(flags, "repo")
    if repo ~= nil and repo ~= "" then
        return "fanr -r " .. shell_quote(repo)
    end
    return "fanr"
end

local function work_pod_dir(context)
    local config, err = fanr_config(context)
    if config == nil then
        return nil, err
    end
    local work = trim(config["env.work"] or "")
    if work == "" then
        return nil, "fanr config missing env.work"
    end
    return work .. "/lib/fan", nil
end

local function query_remote(context, query, num_versions, package)
    local command = repo_prefix(context, package) .. " query -n " .. tostring(num_versions or 1) .. " " .. shell_quote(query)
    local result = exec_run(context, command)
    if result.success ~= true then
        return nil, result.stderr ~= "" and result.stderr or "fanr query failed", command
    end
    return parse_fanr_blocks(result.stdout), nil, command
end

local function query_installed(context, query)
    local command = "fanr env " .. shell_quote(query or DEFAULT_ENV_QUERY)
    local result = exec_run(context, command)
    if result.success ~= true then
        return nil, result.stderr ~= "" and result.stderr or "fanr env failed"
    end
    return blocks_to_latest_items(parse_fanr_blocks(result.stdout), true), nil
end

local function outdated_for_items(context, items)
    local outdated = {}
    for _, item in ipairs(items or {}) do
        local blocks, err = query_remote(context, item.name, 1)
        if blocks == nil then
            log_warn(context, "fan query failed for outdated check: " .. trim(err))
        else
            local latest = blocks[1] and blocks[1].versions[1]
            if latest ~= nil and trim(latest.version) ~= trim(item.version) then
                local result = make_item(item.name, blocks[1].summary, latest, {
                    installedVersion = item.version,
                })
                result.installed = true
                result.status = "outdated"
                result.latestVersion = latest.version
                outdated[#outdated + 1] = result
            end
        end
    end
    return outdated
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
    return { "fantom", "package-manager", "language" }
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
        capabilities = { "exec", "local-install" },
        ecosystemScopes = { "fantom", "fanr" },
        writeScopes = { "env.work/lib/fan" },
        networkScopes = {},
        privilegeLevel = "none",
        versionComparatorProfile = "lexicographic",
    }
end

function plugin.resolvePackage(context, package)
    local query = package_query(package)
    if query == nil then
        return {}
    end
    local blocks = nil
    blocks = select(1, query_remote(context, query, 5, package))
    if blocks == nil or #blocks == 0 then
        return {
            name = package_name(package),
            packageId = make_package_id(package_name(package), package_version(package)),
            version = package_version(package) ~= "" and package_version(package) or nil,
            packageType = "library",
        }
    end
    return parse_info_block(blocks[1])
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end
    if not command_exists(nil, REQUIRED_BINARY) then
        return requested
    end
    local installed, err = query_installed(nil, DEFAULT_ENV_QUERY)
    if installed == nil then
        return requested
    end
    local installed_map = {}
    for _, item in ipairs(installed) do
        installed_map[lower(item.name)] = item.version or true
    end
    local filtered = {}
    for _, package in ipairs(requested) do
        local action = package_action(package)
        local name = package_name(package)
        local wanted = package_version(package)
        local current = installed_map[lower(name)]
        if action == "remove" then
            if current ~= nil then
                filtered[#filtered + 1] = package
            end
        elseif action == "update" then
            filtered[#filtered + 1] = package
        elseif current == nil then
            filtered[#filtered + 1] = package
        elseif wanted ~= "" and trim(current) ~= wanted then
            filtered[#filtered + 1] = package
        end
    end
    return filtered
end

function plugin.install(context, packages)
    local local_path = request_local_path(context)
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end

    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "fan install failed: missing fanr")
        return false
    end

    begin_step(context, "install fan pods")
    for _, package in ipairs(requested) do
        local query = package_query(package)
        if query == nil then
            tx_failed(context, "fan install failed: missing package name")
            return false
        end
        local command = repo_prefix(context, package) .. " install -y " .. shell_quote(query)
        local result = exec_run(context, command)
        if result.success ~= true then
            tx_failed(context, "fan install failed for " .. query)
            return false
        end
    end

    emit_event(context, "installed", requested)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local source = request_local_path(context, path)
    if source == "" then
        tx_failed(context, "fan installLocal failed: missing path")
        return false
    end
    if lower(source):sub(-4) ~= ".pod" then
        tx_failed(context, "fan installLocal supports only .pod archives")
        return false
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "fan installLocal failed: missing fanr")
        return false
    end
    local pod_dir, err = work_pod_dir(context)
    if pod_dir == nil then
        tx_failed(context, "fan installLocal failed: " .. trim(err))
        return false
    end

    begin_step(context, "install local fan pod")
    local command = "mkdir -p " .. shell_quote(pod_dir) .. " && cp " .. shell_quote(source) .. " " .. shell_quote(pod_dir .. "/")
    local result = exec_run(context, command)
    if result.success ~= true then
        tx_failed(context, "fan local install failed")
        return false
    end

    emit_event(context, "installed", {
        path = source,
        localTarget = true,
        packageType = "library",
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "fan remove failed: missing fanr")
        return false
    end

    begin_step(context, "remove fan pods")
    for _, package in ipairs(requested) do
        local query = package_query(package)
        if query == nil then
            tx_failed(context, "fan remove failed: missing package name")
            return false
        end
        local command = repo_prefix(context, package) .. " uninstall -y " .. shell_quote(query)
        local result = exec_run(context, command)
        if result.success ~= true then
            tx_failed(context, "fan remove failed for " .. query)
            return false
        end
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "fan update failed: missing fanr")
        return false
    end

    local requested = packages or {}
    if #requested == 0 then
        local outdated = plugin.outdated(context)
        if #outdated == 0 then
            emit_event(context, "updated", {})
            tx_success(context)
            return true
        end
        requested = {}
        for _, item in ipairs(outdated) do
            requested[#requested + 1] = { name = item.name }
        end
    end

    begin_step(context, "update fan pods")
    for _, package in ipairs(requested) do
        local query = package_query(package)
        if query == nil then
            tx_failed(context, "fan update failed: missing package name")
            return false
        end
        local command = repo_prefix(context, package) .. " install -y " .. shell_quote(query)
        local result = exec_run(context, command)
        if result.success ~= true then
            tx_failed(context, "fan update failed for " .. query)
            return false
        end
    end

    emit_event(context, "updated", requested)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items, err = query_installed(context, DEFAULT_ENV_QUERY)
    if items == nil then
        log_warn(context, "fan list failed: " .. trim(err))
        emit_event(context, "listed", {})
        return {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local installed, err = query_installed(context, DEFAULT_ENV_QUERY)
    if installed == nil then
        log_warn(context, "fan outdated failed: " .. trim(err))
        emit_event(context, "outdated", {})
        return {}
    end
    local items = outdated_for_items(context, installed)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt)
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end
    local blocks, err = query_remote(context, query, 1)
    if blocks == nil then
        log_warn(context, "fan search failed: " .. trim(err))
        emit_event(context, "searched", {})
        return {}
    end
    local items = blocks_to_latest_items(blocks, false)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = request_name(context, name)
    if query == "" then
        return {}
    end
    local blocks, err = query_remote(context, query, 5)
    if blocks == nil or #blocks == 0 then
        if err ~= nil then
            log_warn(context, "fan info failed: " .. trim(err))
        end
        return {}
    end
    local item = parse_info_block(blocks[1])
    emit_event(context, "informed", item)
    return item
end

return plugin
