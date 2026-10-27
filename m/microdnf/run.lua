plugin = {}

local PLUGIN_NAME = "microdnf"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "microdnf"
local RPM_QUERY_FORMAT = "%{NAME}|%{VERSION}-%{RELEASE}|%{ARCH}|%{LICENSE}|%{SUMMARY}\\n"
local REPOQUERY_FORMAT = "%{name}|%{version}-%{release}|%{arch}|%{reponame}|%{summary}\\n"
local RESOLVE_FORMAT = "%{name}|%{version}-%{release}|%{arch}|%{reponame}|%{license}|%{url}|%{summary}\\n"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function empty_to_nil(value)
    local normalized = trim(value)
    if normalized == "" or normalized == "(none)" then
        return nil
    end
    return normalized
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
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

local function split_lines(value)
    local lines = {}
    for line in (tostring(value or "") .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line:gsub("\r$", "")
    end
    return lines
end

local function split_fields(line, expected)
    local fields = {}
    local input = tostring(line or "")
    local start_index = 1

    for index = 1, expected - 1 do
        local separator_index = string.find(input, "|", start_index, true)
        if separator_index == nil then
            fields[index] = string.sub(input, start_index)
            for tail_index = index + 1, expected do
                fields[tail_index] = ""
            end
            return fields
        end

        fields[index] = string.sub(input, start_index, separator_index - 1)
        start_index = separator_index + 1
    end

    fields[expected] = string.sub(input, start_index)
    return fields
end

local function escape_pattern(value)
    return tostring(value or ""):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
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

local function read_env(name)
    if os ~= nil and type(os.getenv) == "function" then
        return empty_to_nil(os.getenv(name))
    end
    return nil
end

local function get_reqpack_path(name)
    local paths = type(reqpack) == "table" and get_field(reqpack, "paths") or nil
    if type(paths) ~= "table" then
        return nil
    end
    return empty_to_nil(get_field(paths, name))
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
    return table.concat(parts, "/")
end

local function cache_root()
    local data_root = get_reqpack_path("dataRoot")
    if data_root ~= nil then
        return join_path(data_root, "microdnf", "cache")
    end

    return join_path(first_nonempty(read_env("HOME"), "/home/test"), ".cache", "reqpack", "microdnf")
end

local function cache_opt(cache_dir)
    return "--setopt=cachedir=" .. shell_quote(cache_dir)
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
            for key, item in pairs(value) do
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

local function run_command(context, command)
    local first, second, third, fourth, fifth
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        first, second, third, fourth, fifth = context.exec.run(command)
        return normalize_run_result(first, second, third, fourth, fifth)
    end
    first, second, third, fourth, fifth = reqpack.exec.run(command)
    return normalize_run_result(first, second, third, fourth, fifth)
end

local function is_command_success(result, extra_exit_codes)
    if type(result) ~= "table" then
        return false
    end

    if result.success == true or result.ok == true then
        return true
    end

    local exit_code = result.exitCode
    if exit_code == nil then
        exit_code = result.exit_code
    end
    if exit_code == nil then
        exit_code = result.code
    end
    if exit_code == nil then
        exit_code = result.status
    end

    if exit_code == 0 then
        return true
    end

    for _, allowed in ipairs(extra_exit_codes or {}) do
        if exit_code == allowed then
            return true
        end
    end

    return false
end

local function command_exists(binary)
    return is_command_success(run_command(nil, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function ensure_cache_dir(context, cache_dir)
    local result = run_command(context, "mkdir -p " .. shell_quote(cache_dir))
    if is_command_success(result) then
        return true, nil
    end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to create cache directory")
end

local function prepare_cache(context)
    local cache_dir = cache_root()
    local ok, err = ensure_cache_dir(context, cache_dir)
    if not ok then
        return nil, err, nil
    end

    local command = "microdnf " .. cache_opt(cache_dir) .. " makecache"
    local result = run_command(context, command)
    if not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "microdnf makecache failed"), cache_dir
    end

    return true, nil, cache_dir
end

local function make_version(epoch, version, release)
    local current_version = trim(version)
    if current_version == "" then
        return nil
    end

    local current_release = trim(release)
    if current_release ~= "" and current_release ~= "(none)" then
        current_version = current_version .. "-" .. current_release
    end

    local current_epoch = trim(epoch)
    if current_epoch ~= "" and current_epoch ~= "0" and current_epoch ~= "(none)" then
        current_version = current_epoch .. ":" .. current_version
    end

    return current_version
end

local function strip_epoch(version)
    return trim(version):gsub("^%d+:", "")
end

local function requested_version(package)
    return trim(get_field(package, "version"))
end

local function package_name(package)
    local name = get_field(package, "name")
    if name ~= nil then
        return trim(name)
    end
    return trim(package)
end

local function package_spec(package)
    local name = package_name(package)
    if name == "" then
        return ""
    end

    local version = requested_version(package)
    if version ~= "" then
        return name .. "-" .. version
    end

    return name
end

local function make_package_id(name, version, architecture)
    local normalized_name = trim(name)
    local normalized_version = trim(version)
    local normalized_architecture = trim(architecture)

    if normalized_name == "" then
        return nil
    end
    if normalized_version == "" then
        return normalized_name
    end
    if normalized_architecture ~= "" then
        return normalized_name .. "." .. normalized_architecture .. "@" .. normalized_version
    end
    return normalized_name .. "@" .. normalized_version
end

local function parse_installed_rows(stdout)
    local items = {}

    for _, line in ipairs(split_lines(stdout)) do
        local normalized = trim(line)
        if normalized ~= "" then
            local fields = split_fields(normalized, 5)
            local name = trim(fields[1])
            local version = trim(fields[2])
            local architecture = empty_to_nil(fields[3])

            items[#items + 1] = {
                name = name,
                version = version,
                latestVersion = version,
                installed = true,
                status = "installed",
                packageType = "rpm",
                architecture = architecture,
                license = empty_to_nil(fields[4]),
                summary = empty_to_nil(fields[5]),
                repository = "@System",
                packageId = make_package_id(name, version, architecture),
            }
        end
    end

    return items
end

local function parse_repoquery_rows(stdout)
    local items = {}

    for _, line in ipairs(split_lines(stdout)) do
        local normalized = trim(line)
        if normalized ~= "" then
            local fields = split_fields(normalized, 5)
            local name = trim(fields[1])
            local version = trim(fields[2])
            local architecture = empty_to_nil(fields[3])

            items[#items + 1] = {
                name = name,
                version = version,
                latestVersion = version,
                installed = false,
                status = "available",
                packageType = "rpm",
                architecture = architecture,
                repository = empty_to_nil(fields[4]),
                summary = empty_to_nil(fields[5]),
                packageId = make_package_id(name, version, architecture),
            }
        end
    end

    return items
end

local function parse_resolve_rows(stdout)
    local items = {}

    for _, line in ipairs(split_lines(stdout)) do
        local normalized = trim(line)
        if normalized ~= "" then
            local fields = split_fields(normalized, 7)
            local name = trim(fields[1])
            local version = trim(fields[2])
            local architecture = empty_to_nil(fields[3])
            local extra = {}
            if empty_to_nil(fields[5]) ~= nil then
                extra.license = trim(fields[5])
            end
            if empty_to_nil(fields[6]) ~= nil then
                extra.url = trim(fields[6])
            end

            items[#items + 1] = {
                name = name,
                version = version,
                latestVersion = version,
                installed = false,
                status = "available",
                packageType = "rpm",
                architecture = architecture,
                repository = empty_to_nil(fields[4]),
                license = empty_to_nil(fields[5]),
                homepage = empty_to_nil(fields[6]),
                summary = empty_to_nil(fields[7]),
                description = empty_to_nil(fields[7]),
                extraFields = next(extra) ~= nil and extra or nil,
                packageId = make_package_id(name, version, architecture),
            }
        end
    end

    return items
end

local function parse_info_blocks(stdout)
    local blocks = {}
    local current = nil
    local in_description = false

    local function push_current()
        if current == nil or next(current) == nil then
            return
        end
        if current._description ~= nil then
            current.Description = trim(table.concat(current._description, "\n"))
            current._description = nil
        end
        blocks[#blocks + 1] = current
    end

    for _, line in ipairs(split_lines(stdout)) do
        local normalized = trim(line)

        if normalized == "" then
            if in_description and current ~= nil and current._description ~= nil and #current._description > 0 then
                current._description[#current._description + 1] = ""
            end
        elseif normalized == "Installed Packages" or normalized == "Available Packages" then
            push_current()
            current = { section = normalized, _description = {} }
            in_description = false
        elseif in_description and line:match("^%s") then
            current._description[#current._description + 1] = trim(line)
        else
            local key, value = line:match("^([^:][^:]*)%s*:%s*(.*)$")
            if key ~= nil then
                if current == nil then
                    current = { _description = {} }
                end
                key = trim(key)
                if key == "Description" then
                    current._description = {}
                    if trim(value) ~= "" then
                        current._description[#current._description + 1] = trim(value)
                    end
                    in_description = true
                else
                    current[key] = trim(value)
                    in_description = false
                end
            end
        end
    end

    push_current()
    return blocks
end

local function build_info_item(blocks)
    local installed_block = nil
    local available_block = nil

    for _, block in ipairs(blocks or {}) do
        if installed_block == nil and (block.section == "Installed Packages" or block["Install Date"] ~= nil or block.Repository == "@System") then
            installed_block = block
        elseif available_block == nil then
            available_block = block
        end
    end

    local primary = installed_block or available_block
    if primary == nil then
        return nil
    end

    local fallback = available_block or installed_block
    local item = {
        name = empty_to_nil(primary.Name),
        version = make_version(primary.Epoch, primary.Version, primary.Release),
        latestVersion = fallback ~= nil and make_version(fallback.Epoch, fallback.Version, fallback.Release) or nil,
        installed = installed_block ~= nil,
        status = installed_block ~= nil and "installed" or "available",
        packageType = "rpm",
        architecture = empty_to_nil(primary.Architecture),
        summary = empty_to_nil(primary.Summary),
        description = empty_to_nil(primary.Description),
        homepage = empty_to_nil(primary.URL),
        license = empty_to_nil(primary.License),
        repository = empty_to_nil(primary["From repo"] or primary.Repository),
    }

    if item.name == nil then
        return nil
    end
    if item.latestVersion == nil then
        item.latestVersion = item.version
    end
    if item.repository == nil and item.installed then
        item.repository = "@System"
    end

    local source_rpm = empty_to_nil(primary["Source RPM"])
    if source_rpm == nil and fallback ~= nil then
        source_rpm = empty_to_nil(fallback["Source RPM"])
    end
    if source_rpm ~= nil then
        item.extraFields = { sourceRpm = source_rpm }
    end

    item.packageId = make_package_id(item.name, item.version, item.architecture)
    return item
end

local function query_installed_version(context, name)
    local result = run_command(context, "rpm -q --queryformat '%{VERSION}-%{RELEASE}\\n' " .. shell_quote(name))
    if not is_command_success(result) then
        return nil
    end
    return empty_to_nil((result.stdout or ""):match("^([^\n]+)"))
end

local function version_matches(installed_version, wanted_version)
    local current_version = strip_epoch(installed_version)
    local expected_version = strip_epoch(wanted_version)

    if current_version == "" or expected_version == "" then
        return current_version ~= "" and expected_version == ""
    end
    if current_version == expected_version then
        return true
    end
    return current_version:match("^" .. escape_pattern(expected_version) .. "%-") ~= nil
end

local function is_installed(package)
    local name = package_name(package)
    if name == "" then
        return false
    end

    local version = requested_version(package)
    if version ~= "" then
        return version_matches(query_installed_version(nil, name), version)
    end

    return is_command_success(run_command(nil, "rpm -q " .. shell_quote(name) .. " >/dev/null 2>&1"))
end

local function query_upgrade_items(context)
    local ok, cache_error, cache_dir = prepare_cache(context)
    if not ok then
        return nil, cache_error
    end

    local command = "microdnf " .. cache_opt(cache_dir) .. " repoquery --upgrades --queryformat " .. shell_quote(REPOQUERY_FORMAT)
    local result = run_command(context, command)
    if not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "microdnf repoquery upgrades failed")
    end

    return parse_repoquery_rows(result.stdout), nil
end

local function pick_resolved_item(package, items)
    local name = package_name(package)
    local version = requested_version(package)
    local relaxed_match = nil

    for _, item in ipairs(items or {}) do
        if name == "" or item.name == name then
            if version == "" then
                return item
            end
            if strip_epoch(item.version) == strip_epoch(version) then
                return item
            end
            if relaxed_match == nil and version_matches(item.version, version) then
                relaxed_match = item
            end
        end
    end

    return relaxed_match
end

local function resolved_info_item_matches(package, item)
    if type(item) ~= "table" or item.name == nil then
        return false
    end

    local name = package_name(package)
    if name ~= "" and trim(item.name) ~= name then
        return false
    end

    local version = requested_version(package)
    if version ~= "" and not version_matches(item.version, version) then
        return false
    end

    return true
end

local function resolve_remote_items(context, package)
    local ok, cache_error, cache_dir = prepare_cache(context)
    if not ok then
        return nil, cache_error
    end

    local command = "microdnf " .. cache_opt(cache_dir) .. " repoquery "
    if requested_version(package) == "" then
        command = command .. "--latest-limit 1 "
    end

    command = command .. "--queryformat " .. shell_quote(RESOLVE_FORMAT) .. " " .. shell_quote(package_spec(package))
    local result = run_command(context, command)
    if not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "microdnf repoquery resolve failed")
    end

    return parse_resolve_rows(result.stdout), nil
end

local function search_remote_items(context, prompt)
    local query = trim(prompt)
    if query == "" then
        return {}
    end

    local ok, cache_error, cache_dir = prepare_cache(context)
    if not ok then
        return nil, cache_error
    end

    local command = "microdnf " .. cache_opt(cache_dir) .. " repoquery --available --latest-limit 1 --queryformat " .. shell_quote(REPOQUERY_FORMAT) .. " " .. shell_quote("*" .. query .. "*")
    local result = run_command(context, command)
    if not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "microdnf search failed")
    end

    return parse_repoquery_rows(result.stdout), nil
end

local function empty_result(context, event_name)
    local items = {}
    emit_event(context, event_name, items)
    return items
end

local function run_mutation(context, label, packages, builder, event_name, failure_message, needs_cache)
    if packages == nil or #packages == 0 then
        return true
    end

    begin_step(context, label)

    local cache_dir = nil
    if needs_cache then
        local ok, cache_error, resolved_cache_dir = prepare_cache(context)
        if not ok then
            tx_failed(context, cache_error)
            return false
        end
        cache_dir = resolved_cache_dir
    end

    for _, package in ipairs(packages) do
        local command = builder(package, cache_dir)
        if command ~= nil and trim(command) ~= "" then
            local result = run_command(context, command)
            if not is_command_success(result) then
                tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, failure_message))
                return false
            end
        end
    end

    emit_event(context, event_name, packages)
    tx_success(context)
    return true
end

plugin.fileExtensions = { ".rpm" }

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
    return { "System", "RPM", "Wrapper" }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end

    local missing = {}
    local upgrade_lookup = nil
    local upgrade_lookup_loaded = false
    local upgrade_lookup_failed = false

    for _, package in ipairs(packages) do
        local action = trim(get_field(package, "action"))

        if action == "remove" then
            if is_installed(package) then
                missing[#missing + 1] = package
            end
        elseif action == "update" then
            if not upgrade_lookup_loaded then
                local items = query_upgrade_items(nil)
                if items == nil then
                    upgrade_lookup_failed = true
                    upgrade_lookup = {}
                else
                    upgrade_lookup = {}
                    for _, item in ipairs(items) do
                        upgrade_lookup[item.name] = true
                    end
                end
                upgrade_lookup_loaded = true
            end

            if upgrade_lookup_failed or upgrade_lookup[package_name(package)] == true then
                missing[#missing + 1] = package
            end
        elseif not is_installed(package) then
            missing[#missing + 1] = package
        end
    end

    return missing
end

function plugin.install(context, packages)
    return run_mutation(
        context,
        "install microdnf packages",
        packages,
        function(package, cache_dir)
            local spec = package_spec(package)
            if spec == "" then
                return nil
            end
            return "microdnf " .. cache_opt(cache_dir) .. " -y install " .. shell_quote(spec)
        end,
        "installed",
        "microdnf install failed",
        true
    )
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" then
        tx_failed(context, "local package path missing")
        return false
    end

    begin_step(context, "install local rpm artifact")
    local ok, cache_error, cache_dir = prepare_cache(context)
    if not ok then
        tx_failed(context, cache_error)
        return false
    end

    local result = run_command(context, "microdnf " .. cache_opt(cache_dir) .. " -y install " .. shell_quote(local_path))
    if not is_command_success(result) then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "microdnf local install failed"))
        return false
    end

    emit_event(context, "installed", { path = local_path, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    return run_mutation(
        context,
        "remove microdnf packages",
        packages,
        function(package)
            local spec = package_spec(package)
            if spec == "" then
                return nil
            end
            return "microdnf -y remove " .. shell_quote(spec)
        end,
        "deleted",
        "microdnf remove failed",
        false
    )
end

function plugin.update(context, packages)
    return run_mutation(
        context,
        "update microdnf packages",
        packages,
        function(package, cache_dir)
            local name = package_name(package)
            if name == "" then
                return nil
            end
            return "microdnf " .. cache_opt(cache_dir) .. " -y upgrade " .. shell_quote(name)
        end,
        "updated",
        "microdnf upgrade failed",
        true
    )
end

function plugin.list(context)
    local result = run_command(context, "rpm -qa --queryformat " .. shell_quote(RPM_QUERY_FORMAT))
    if not is_command_success(result) then
        return empty_result(context, "listed")
    end

    local items = parse_installed_rows(result.stdout)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items, err = query_upgrade_items(context)
    if items == nil then
        return empty_result(context, "outdated")
    end

    for _, item in ipairs(items) do
        local installed_version = query_installed_version(context, item.name)
        if installed_version ~= nil then
            item.latestVersion = item.version
            item.version = installed_version
            item.installed = true
            item.status = "upgradable"
            item.packageId = make_package_id(item.name, item.version, item.architecture)
        end
    end

    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt)
    if query == "" then
        return empty_result(context, "searched")
    end

    local items = select(1, search_remote_items(context, query))
    if items == nil then
        return empty_result(context, "searched")
    end

    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = trim(name)
    if query == "" then
        emit_event(context, "informed", {})
        return {}
    end

    local installed_result = run_command(context, "rpm -qi " .. shell_quote(query))
    if is_command_success(installed_result) then
        local item = build_info_item(parse_info_blocks(installed_result.stdout))
        if item ~= nil then
            emit_event(context, "informed", item)
            return item
        end
    end

    local items = select(1, resolve_remote_items(context, { name = query }))
    if items ~= nil and items[1] ~= nil then
        emit_event(context, "informed", items[1])
        return items[1]
    end

    emit_event(context, "informed", {})
    return {}
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == "" then
        return nil
    end

    local items = select(1, resolve_remote_items(context, package))
    if items ~= nil then
        local resolved = pick_resolved_item(package, items)
        if resolved ~= nil then
            return resolved
        end
    end

    local info_result = plugin.info(context, name)
    if resolved_info_item_matches(package, info_result) then
        return info_result
    end

    return nil
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "rpm" },
        writeScopes = {
            { kind = "temp" },
            { kind = "user-home-subpath", value = ".cache/reqpack/microdnf" },
        },
        networkScopes = {},
        privilegeLevel = "sudo",
        osvEcosystem = "RPM",
        purlType = "rpm",
        versionComparatorProfile = "rpm-evr",
        versionTokenPattern = "[A-Za-z0-9._+~:-]+",
        versionCaseInsensitive = false,
    }
end

function plugin.init()
    return command_exists(REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

return plugin
