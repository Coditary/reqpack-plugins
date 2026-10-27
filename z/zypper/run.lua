plugin = {}

local PLUGIN_NAME = "Zypper"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "zypper"
local RPM_QUERY_FORMAT = "%{NAME}|%{VERSION}-%{RELEASE}|%{ARCH}|%{LICENSE}|%{SUMMARY}\\n"

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
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
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

local function split_lines(value)
    local text = tostring(value or ""):gsub("\r\n", "\n")
    local lines = {}

    for line in (text .. "\n"):gmatch("(.-)\n") do
        local normalized = line:gsub("\r$", "")
        table.insert(lines, normalized)
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

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = trim(select(index, ...))
        if value ~= "" then
            return value
        end
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

    local function merge_table(value)
        for key, item in pairs(value or {}) do
            result[key] = item
        end
    end

    local function apply_scalar(value)
        local value_type = type(value)
        if value_type == "table" then
            merge_table(value)
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

local function is_command_success(result, extra_exit_codes)
    if type(result) ~= "table" then
        return false
    end

    if result.success then
        return true
    end

    if result.ok then
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

    if type(extra_exit_codes) == "table" and exit_code ~= nil then
        for _, allowed in ipairs(extra_exit_codes) do
            if exit_code == allowed then
                return true
            end
        end
    end

    return false
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

local function command_exists(binary, context)
    if trim(binary) == "" then
        return false
    end

    return is_command_success(run_command(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
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

local function package_architecture(package)
    return trim(get_field(package, "architecture"))
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

local function normalize_extra_fields(extra)
    if type(extra) ~= "table" or next(extra) == nil then
        return nil
    end

    return extra
end

local function build_command_args(packages, formatter)
    local args = {}

    for _, package in ipairs(packages or {}) do
        local spec = trim(formatter(package))
        if spec ~= "" then
            table.insert(args, shell_quote(spec))
        end
    end

    return table.concat(args, " ")
end

local function parse_installed_rows(stdout)
    local items = {}

    for _, line in ipairs(split_lines(stdout)) do
        local normalized_line = trim(line)
        if normalized_line ~= "" then
            local fields = split_fields(normalized_line, 5)
            local name = trim(fields[1])
            local version = trim(fields[2])
            local architecture = empty_to_nil(fields[3])

            table.insert(items, {
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
            })
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

        table.insert(blocks, current)
    end

    for _, line in ipairs(split_lines(stdout)) do
        local normalized_line = trim(line)

        if normalized_line == "" then
            if in_description and current ~= nil and current._description ~= nil and #current._description > 0 then
                table.insert(current._description, "")
            end
        elseif normalized_line == "Installed Packages" or normalized_line == "Available Packages" then
            push_current()
            current = { section = normalized_line, _description = {} }
            in_description = false
        elseif in_description and line:match("^%s") then
            table.insert(current._description, trim(line))
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
                        table.insert(current._description, trim(value))
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

local function build_rpm_info_item(blocks)
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
        architecture = empty_to_nil(primary.Architecture or primary.Arch),
        summary = empty_to_nil(primary.Summary),
        description = empty_to_nil(primary.Description),
        homepage = empty_to_nil(primary.URL or primary["Upstream URL"]),
        license = empty_to_nil(primary.License),
        repository = empty_to_nil(primary["From repo"] or primary.Repository),
    }

    if item.name == nil then
        return nil
    end

    if item.latestVersion == nil then
        item.latestVersion = item.version
    end
    if item.repository == nil and fallback ~= nil then
        item.repository = empty_to_nil(fallback["From repo"] or fallback.Repository)
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

local function xml_unescape(value)
    local text = tostring(value or "")
    text = text:gsub("&quot;", '"')
    text = text:gsub("&apos;", "'")
    text = text:gsub("&lt;", "<")
    text = text:gsub("&gt;", ">")
    text = text:gsub("&amp;", "&")
    return text
end

local function parse_xml_attributes(fragment)
    local attributes = {}
    local text = tostring(fragment or "")

    for key, value in text:gmatch("([%w_:%-]+)%s*=%s*\"(.-)\"") do
        attributes[key] = xml_unescape(value)
    end
    for key, value in text:gmatch("([%w_:%-]+)%s*=%s*'(.-)'") do
        if attributes[key] == nil then
            attributes[key] = xml_unescape(value)
        end
    end

    return attributes
end

local function collect_xml_attrs(stdout, tag_name)
    local items = {}
    local pattern = "<" .. tag_name .. "%f[%s/>]([^>]*)/?>"

    for fragment in tostring(stdout or ""):gmatch(pattern) do
        table.insert(items, parse_xml_attributes(fragment))
    end

    return items
end

local function is_installed_status(status)
    return lower(status):match("^installed") ~= nil
end

local function parse_search_xml(stdout)
    local items = {}
    local seen = {}

    for _, attrs in ipairs(collect_xml_attrs(stdout, "solvable")) do
        local kind = trim(attrs.kind)
        local name = trim(attrs.name)
        local version = empty_to_nil(attrs.edition or attrs.version)
        local architecture = empty_to_nil(attrs.arch or attrs.architecture)
        local installed = is_installed_status(attrs.status)

        if name ~= "" and (kind == "" or kind == "package") then
            local item = {
                name = name,
                version = version,
                latestVersion = version,
                installed = installed,
                status = installed and "installed" or "available",
                packageType = "rpm",
                architecture = architecture,
                repository = empty_to_nil(attrs.repository),
                summary = empty_to_nil(attrs.summary or attrs["display-summary"]),
                packageId = make_package_id(name, version, architecture),
            }

            local key = item.packageId or name
            if not seen[key] then
                seen[key] = true
                table.insert(items, item)
            end
        end
    end

    return items
end

local function parse_outdated_xml(stdout)
    local items = {}
    local raw_items = collect_xml_attrs(stdout, "update")

    if #raw_items == 0 then
        raw_items = collect_xml_attrs(stdout, "solvable")
    end

    for _, attrs in ipairs(raw_items) do
        local kind = trim(attrs.kind)
        local name = trim(attrs.name)
        local latest_version = empty_to_nil(attrs.edition or attrs.version)
        local architecture = empty_to_nil(attrs.arch or attrs.architecture)

        if name ~= "" and latest_version ~= nil and (kind == "" or kind == "package") then
            table.insert(items, {
                name = name,
                version = latest_version,
                latestVersion = latest_version,
                oldVersion = empty_to_nil(attrs.oldedition or attrs.oldversion),
                installed = true,
                status = "upgradable",
                packageType = "rpm",
                architecture = architecture,
                repository = empty_to_nil(attrs.source or attrs.source_alias or attrs.repository),
                packageId = make_package_id(name, latest_version, architecture),
            })
        end
    end

    return items
end

local function parse_zypper_info_item(stdout)
    local fields = {}
    local description_lines = {}
    local in_description = false

    for _, line in ipairs(split_lines(stdout)) do
        local normalized_line = trim(line)

        if normalized_line == "" then
            if in_description and #description_lines > 0 then
                table.insert(description_lines, "")
            end
        elseif normalized_line:match("^Information for package ") then
            in_description = false
        else
            local key, value = line:match("^([%w][%w%s/%-]+)%s*:%s*(.*)$")
            if key ~= nil then
                key = trim(key)
                if key == "Description" then
                    description_lines = {}
                    if trim(value) ~= "" then
                        table.insert(description_lines, trim(value))
                    end
                    in_description = true
                else
                    fields[key] = trim(value)
                    in_description = false
                end
            elseif in_description and line:match("^%s") then
                table.insert(description_lines, trim(line))
            end
        end
    end

    while #description_lines > 0 and description_lines[1] == "" do
        table.remove(description_lines, 1)
    end
    while #description_lines > 0 and description_lines[#description_lines] == "" do
        table.remove(description_lines, #description_lines)
    end

    local name = empty_to_nil(fields.Name)
    if name == nil then
        return nil
    end

    local version = empty_to_nil(fields.Version)
    local architecture = empty_to_nil(fields.Arch or fields.Architecture)
    local installed = lower(fields.Installed):match("^yes") ~= nil
    local status_text = lower(fields.Status)
    local item = {
        name = name,
        version = version,
        latestVersion = version,
        installed = installed,
        status = installed and "installed" or "available",
        packageType = "rpm",
        architecture = architecture,
        repository = empty_to_nil(fields.Repository),
        summary = empty_to_nil(fields.Summary),
        description = #description_lines > 0 and table.concat(description_lines, "\n") or nil,
        homepage = empty_to_nil(fields.URL or fields["Upstream URL"]),
        license = empty_to_nil(fields.License),
    }

    if status_text:match("out%-of%-date") ~= nil then
        item.status = "upgradable"
        item.installed = true
    end

    local extra = {}
    if empty_to_nil(fields.Vendor) ~= nil then
        extra.vendor = fields.Vendor
    end
    if empty_to_nil(fields["Support Level"]) ~= nil then
        extra.supportLevel = fields["Support Level"]
    end
    if empty_to_nil(fields["Source package"]) ~= nil then
        extra.sourcePackage = fields["Source package"]
    end
    if empty_to_nil(fields["Installed Size"]) ~= nil then
        extra.installedSize = fields["Installed Size"]
    end
    if empty_to_nil(fields["Download Size"]) ~= nil then
        extra.downloadSize = fields["Download Size"]
    end
    if empty_to_nil(fields.Status) ~= nil then
        extra.rawStatus = fields.Status
    end

    item.extraFields = normalize_extra_fields(extra)
    item.packageId = make_package_id(item.name, item.version, item.architecture)
    return item
end

local function query_installed_version(name, architecture)
    local normalized_name = trim(name)
    local normalized_architecture = trim(architecture)
    if normalized_name == "" then
        return nil
    end

    local query_name = normalized_architecture ~= "" and (normalized_name .. "." .. normalized_architecture) or normalized_name
    local result = run_command(nil, "rpm -q --queryformat '%{VERSION}-%{RELEASE}\\n' " .. shell_quote(query_name))
    if not is_command_success(result) then
        return nil
    end

    local version = trim(result.stdout)
    if version == "" then
        return nil
    end

    local first_line = version:match("([^\n]+)")
    return empty_to_nil(first_line)
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
        local installed_version = query_installed_version(name, package_architecture(package))
        return version_matches(installed_version, version)
    end

    return is_command_success(run_command(nil, "rpm -q --quiet " .. shell_quote(name)))
end

local function query_outdated_lookup()
    local result = run_command(nil, "zypper --xmlout --non-interactive list-updates --type package")
    if not is_command_success(result) then
        return nil
    end

    local lookup = {}
    for _, item in ipairs(parse_outdated_xml(result.stdout or "")) do
        lookup[item.name] = true
        if item.architecture ~= nil then
            lookup[item.name .. "." .. item.architecture] = true
        end
    end

    return lookup
end

local function has_update(package)
    local name = package_name(package)
    if name == "" then
        return false
    end

    local lookup = query_outdated_lookup() or {}
    if lookup[name] then
        return true
    end

    local architecture = package_architecture(package)
    if architecture ~= "" and lookup[name .. "." .. architecture] then
        return true
    end

    return false
end

local function run_mutation(context, label, command, event_name, payload, failure_message)
    begin_step(context, label)

    local result = run_command(context, command)
    if not is_command_success(result) then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, failure_message))
        return false
    end

    emit_event(context, event_name, payload)
    tx_success(context)
    return true
end

local function empty_result(context, event_name)
    local items = {}
    emit_event(context, event_name, items)
    return items
end

local function query_search_items(context, prompt)
    local query = trim(prompt)
    if query == "" then
        return {}
    end

    local result = run_command(
        context,
        "zypper --xmlout --non-interactive search --details --type package " .. shell_quote(query)
    )
    if not is_command_success(result) then
        return {}
    end

    return parse_search_xml(result.stdout)
end

local function query_info_item(context, name)
    local query = trim(name)
    if query == "" then
        return nil
    end

    local installed_result = run_command(context, "rpm -qi " .. shell_quote(query))
    if is_command_success(installed_result) then
        local installed_item = build_rpm_info_item(parse_info_blocks(installed_result.stdout))
        if installed_item ~= nil then
            return installed_item
        end
    end

    local available_result = run_command(context, "zypper --non-interactive info --type package " .. shell_quote(query))
    if not is_command_success(available_result) then
        return nil
    end

    return parse_zypper_info_item(available_result.stdout)
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
    local missing = {}
    local outdated_lookup = nil
    local outdated_checked = false

    for _, package in ipairs(packages or {}) do
        local action = trim(get_field(package, "action"))

        if action == "remove" then
            if is_installed(package) then
                table.insert(missing, package)
            end
        elseif action == "update" then
            if not outdated_checked then
                outdated_lookup = query_outdated_lookup() or {}
                outdated_checked = true
            end

            local name = package_name(package)
            local architecture = package_architecture(package)
            if outdated_lookup[name] or (architecture ~= "" and outdated_lookup[name .. "." .. architecture]) then
                table.insert(missing, package)
            end
        elseif not is_installed(package) then
            table.insert(missing, package)
        end
    end

    return missing
end

function plugin.install(context, packages)
    local args = build_command_args(packages, package_spec)
    if args == "" then
        return true
    end

    return run_mutation(
        context,
        "install zypper packages",
        "zypper --non-interactive install " .. args,
        "installed",
        packages or {},
        "zypper install failed"
    )
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" then
        tx_failed(context, "local package path missing")
        return false
    end

    return run_mutation(
        context,
        "install local rpm artifact",
        "zypper --non-interactive install " .. shell_quote(local_path),
        "installed",
        { path = local_path, localTarget = true },
        "zypper local install failed"
    )
end

function plugin.remove(context, packages)
    local args = build_command_args(packages, function(package)
        if requested_version(package) == "" then
            return package_name(package)
        end
        return package_spec(package)
    end)

    if args == "" then
        return true
    end

    return run_mutation(
        context,
        "remove zypper packages",
        "zypper --non-interactive remove " .. args,
        "deleted",
        packages or {},
        "zypper remove failed"
    )
end

function plugin.update(context, packages)
    local args = build_command_args(packages, function(package)
        return package_name(package)
    end)

    if args == "" then
        return true
    end

    return run_mutation(
        context,
        "update zypper packages",
        "zypper --non-interactive update " .. args,
        "updated",
        packages or {},
        "zypper update failed"
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
    local result = run_command(context, "zypper --xmlout --non-interactive list-updates --type package")
    if not is_command_success(result) then
        return empty_result(context, "outdated")
    end

    local items = parse_outdated_xml(result.stdout)
    for _, item in ipairs(items) do
        local installed_version = query_installed_version(item.name, item.architecture)
        if installed_version ~= nil then
            item.latestVersion = item.version
            item.version = installed_version
        elseif item.oldVersion ~= nil then
            item.version = item.oldVersion
        else
            item.latestVersion = item.version
        end

        item.oldVersion = nil
        item.packageId = make_package_id(item.name, item.version, item.architecture)
        item.installed = true
        item.status = "upgradable"
    end

    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local items = query_search_items(context, prompt)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = trim(name)
    if query == "" then
        emit_event(context, "informed", {})
        return {}
    end

    local item = query_info_item(context, query)
    if item == nil then
        emit_event(context, "informed", {})
        return {}
    end

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == "" then
        return nil
    end

    local resolved = pick_resolved_item(package, query_search_items(context, name))
    if resolved ~= nil then
        return resolved
    end

    local info_item = query_info_item(context, name)
    if resolved_info_item_matches(package, info_item) then
        return info_item
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
        },
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
