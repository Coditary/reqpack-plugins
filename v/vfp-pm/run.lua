plugin = {}

local PLUGIN_ID = "vfp-pm"
local PLUGIN_NAME = "vfp-pm"
local PLUGIN_VERSION = "0.1.0"
local DEFAULT_CATALOG_FILE = "packages.tsv"

plugin.fileExtensions = { ".prg" }

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function fixture_root()
    if os ~= nil and type(os.getenv) == "function" then
        return trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT"))
    end
    return ""
end

local function expand_placeholders(value)
    local text = tostring(value or "")
    local root = fixture_root()
    if root ~= "" then
        text = text:gsub("%${fixtureRoot}", root)
    end
    return text
end

local function lower(value)
    return trim(value):lower()
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

local function shell_quote(value)
    return "'" .. expand_placeholders(value):gsub("'", "'\\''") .. "'"
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(expand_placeholders(select(index, ...)))
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
    return expand_placeholders(path):match("^(.*)[/\\][^/\\]+$")
end

local function basename(path)
    return trim(expand_placeholders(path):match("[^/\\]+$") or "")
end

local function strip_extension(path)
    return expand_placeholders(path):gsub("%.[^.]+$", "")
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

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        return trim(os.getenv(name))
    end
    return ""
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

local function is_command_success(result)
    if type(result) ~= "table" then
        return false
    end
    if result.success ~= nil then
        return result.success == true
    end
    if result.exitCode ~= nil then
        return tonumber(result.exitCode) == 0
    end
    return false
end

local function read_flags(value)
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local flags = {}
    local ok = pcall(function()
        for _, item in ipairs(value) do
            local cleaned = trim(expand_placeholders(item))
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

    local function append_from(object)
        local raw = read_field(object, "flags")
        if raw == nil and object ~= nil then
            local ok, value = pcall(function()
                return object.flags
            end)
            if ok then
                raw = value
            end
        end
        for _, flag in ipairs(read_flags(raw)) do
            flags[#flags + 1] = flag
        end
    end

    append_from(context)
    append_from(context ~= nil and context.request or nil)
    if type(package) == "table" then
        append_from(package)
    end
    return flags
end

local function read_flag_value(flags, prefix)
    local wanted = lower(prefix) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #wanted) == wanted then
            return trim(expand_placeholders(cleaned:sub(#wanted + 1)))
        end
    end
    return ""
end

local function context_flag_value(context, prefix)
    local ok, raw_flags = pcall(function()
        return context ~= nil and context.flags or nil
    end)
    if ok then
        local value = read_flag_value(read_flags(raw_flags), prefix)
        if value ~= "" then
            return value
        end
    end
    return read_flag_value(collect_flags(context, nil), prefix)
end

local function xml_decode(value)
    local text = tostring(value or "")
    text = text:gsub("&lt;", "<")
    text = text:gsub("&gt;", ">")
    text = text:gsub("&quot;", '"')
    text = text:gsub("&apos;", "'")
    text = text:gsub("&amp;", "&")
    return text
end

local function pattern_escape(value)
    return tostring(value or ""):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

local function sanitize_name(value)
    local cleaned = lower(value):gsub("[^%w%-_]+", "-")
    cleaned = cleaned:gsub("%-+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
    if cleaned == "" then
        return "item"
    end
    return cleaned
end

local function ensure_directory(path)
    local dir = trim(path)
    if dir == "" or dir == "." then
        return true
    end
    local probe = exec_run(nil, "test -d " .. shell_quote(dir) .. " >/dev/null 2>&1")
    if is_command_success(probe) then
        return true
    end
    if os ~= nil and type(os.execute) == "function" then
        local ok, _, code = os.execute("mkdir -p " .. shell_quote(dir))
        if ok == true or ok == 0 or code == 0 then
            return true
        end
    end
    return false
end

local function read_file(context, path)
    path = expand_placeholders(path)
    if context ~= nil then
        local result = exec_run(context, "cat " .. shell_quote(path))
        if is_command_success(result) then
            return result.stdout
        end
    end
    local handle = io.open(path, "r")
    if handle ~= nil then
        local content = handle:read("*a")
        handle:close()
        return content
    end
    local result = exec_run(context, "cat " .. shell_quote(path))
    if is_command_success(result) then
        return result.stdout
    end
    return nil
end

local function write_file(path, content)
    path = expand_placeholders(path)
    local handle = io.open(path, "w")
    if handle == nil then
        local dir = parent_dir(path)
        if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
            return false
        end
        handle = io.open(path, "w")
        if handle == nil then
            return false
        end
    end
    handle:write(content or "")
    handle:close()
    return true
end

local function package_name(package)
    local value = trim(read_field(package, "name") or read_field(package, "packageId") or package)
    if value == "" then
        return ""
    end
    local base = value:match("^([^@]+)")
    return trim(base or value)
end

local function package_version(package)
    local explicit = trim(read_field(package, "version"))
    if explicit ~= "" then
        return explicit
    end
    local name = trim(read_field(package, "name") or read_field(package, "packageId") or package)
    local version = name:match("^[^@]+@(.+)$")
    return trim(version or "")
end

local function package_local_path(path, context)
    return trim(expand_placeholders(path or read_field(context, "localPath") or read_field(context, "path")))
end

local function home_dir()
    local home = getenv("HOME")
    if home ~= "" then
        return home
    end
    return "."
end

local function cache_root(context)
    local flags = collect_flags(context, nil)
    local flagged = read_flag_value(flags, "cache-root")
    if flagged ~= "" then
        return flagged
    end
    local explicit = trim(read_field(context, "cacheRoot") or "")
    if explicit ~= "" then
        return expand_placeholders(explicit)
    end
    local fixture = fixture_root()
    if fixture ~= "" then
        return join_path(fixture, "cache")
    end
    return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
end

local function project_root(context)
    local flagged = context_flag_value(context, "project")
    if flagged ~= "" then
        return flagged
    end
    local explicit = trim(
        read_field(context, "projectPath") or
        read_field(context, "projectRoot") or
        read_field(context, "workspaceRoot") or
        read_field(context, "cwd") or
        read_field(context, "workingDirectory") or
        ""
    )
    if explicit ~= "" then
        return expand_placeholders(explicit)
    end
    local fixture = fixture_root()
    if fixture ~= "" then
        return join_path(fixture, "project")
    end
    return ""
end

local function packages_xml_path(context)
    local flags = collect_flags(context, nil)
    local flagged = read_flag_value(flags, "packages-xml")
    if flagged ~= "" then
        return flagged
    end
    local explicit = trim(read_field(context, "packagesXmlPath") or "")
    if explicit ~= "" then
        return expand_placeholders(explicit)
    end
    local root = project_root(context)
    if root == "" then
        return ""
    end
    return join_path(root, "Packages", "packages.xml")
end

local function catalog_path(context)
    local flagged = context_flag_value(context, "catalog")
    if flagged ~= "" then
        return flagged
    end
    local explicit = trim(read_field(context, "catalogPath") or getenv("VFP_PM_CATALOG_TSV"))
    if explicit ~= "" then
        return expand_placeholders(explicit)
    end
    local fixture = fixture_root()
    if fixture ~= "" then
        return join_path(fixture, "cache", "catalog", DEFAULT_CATALOG_FILE)
    end
    return join_path(cache_root(context), "catalog", DEFAULT_CATALOG_FILE)
end

local function catalog_url(context)
    local flags = collect_flags(context, nil)
    local flagged = read_flag_value(flags, "catalog-url")
    if flagged ~= "" then
        return flagged
    end
    return trim(expand_placeholders(read_field(context, "catalogUrl") or getenv("VFP_PM_CATALOG_URL")))
end

local function bridge_command(context)
    local flagged = context_flag_value(context, "bridge")
    if flagged ~= "" then
        return flagged
    end
    local explicit = trim(expand_placeholders(read_field(context, "bridgeCommand") or getenv("VFP_PM_BRIDGE")))
    if explicit ~= "" then
        return explicit
    end
    if fixture_root() ~= "" then
        return "vfp-bridge"
    end
    return ""
end

local function split_csv_field(value)
    local items = {}
    for item in tostring(value or ""):gmatch("([^,]+)") do
        local cleaned = trim(item)
        if cleaned ~= "" then
            items[#items + 1] = cleaned
        end
    end
    return items
end

local function split_tsv(line)
    local parts = {}
    local text = tostring(line or "")
    if text == "" then
        return parts
    end
    text = text .. "\t"
    for part in text:gmatch("(.-)\t") do
        parts[#parts + 1] = part
    end
    return parts
end

local function tokenized_version(value)
    local tokens = {}
    for token in tostring(value or ""):gmatch("([0-9]+|[^0-9]+)") do
        if token:match("^[0-9]+$") then
            tokens[#tokens + 1] = tonumber(token)
        else
            local cleaned = lower(token:gsub("[%s%._%-/]+", ""))
            if cleaned ~= "" then
                tokens[#tokens + 1] = cleaned
            end
        end
    end
    return tokens
end

local function compare_versions(left, right)
    left = trim(left)
    right = trim(right)
    if left == right then
        return 0
    end
    local a = tokenized_version(left)
    local b = tokenized_version(right)
    local max_len = math.max(#a, #b)
    for index = 1, max_len do
        local av = a[index]
        local bv = b[index]
        if av == nil and bv == nil then
            break
        elseif av == nil then
            return -1
        elseif bv == nil then
            return 1
        elseif type(av) == "number" and type(bv) == "number" then
            if av ~= bv then
                return av < bv and -1 or 1
            end
        else
            local as = tostring(av)
            local bs = tostring(bv)
            if as ~= bs then
                return as < bs and -1 or 1
            end
        end
    end
    return left < right and -1 or 1
end

local function make_item(record, installed)
    if record == nil and installed == nil then
        return nil
    end
    local name = trim((installed and installed.name) or (record and record.name) or "")
    if name == "" then
        return nil
    end
    local installed_version = trim(installed and installed.version or "")
    local latest_version = trim(record and record.version or "")
    local item = {
        name = name,
        packageId = lower(name),
        packageType = "foxpro-package",
        version = installed_version ~= "" and installed_version or latest_version,
        latestVersion = latest_version ~= "" and latest_version or nil,
        installed = installed ~= nil,
        installedVersion = installed_version ~= "" and installed_version or nil,
        summary = trim((record and record.summary) or (record and record.description) or ""),
        description = trim((record and record.description) or ""),
        projectUrl = trim((record and record.projectUrl) or ""),
        homepage = trim((record and record.projectUrl) or ""),
        dependencies = shallow_copy((record and record.dependencies) or {}),
        tags = shallow_copy((record and record.tags) or {}),
        installPath = installed and installed.installPath or nil,
        installedDate = installed and installed.installedDate or nil,
        refCount = installed and installed.refCount or nil,
        extraFields = {
            installer = record and record.installer or nil,
            downloadUrl = record and record.downloadUrl or nil,
            installedPath = installed and installed.installPath or nil,
        },
    }
    if item.projectUrl == "" then
        item.projectUrl = nil
        item.homepage = nil
    end
    if item.summary == "" then
        item.summary = nil
    end
    if item.description == "" then
        item.description = nil
    end
    return item
end

local function extract_xml_field(block, name)
    local pattern = "<" .. name .. "[^>]*>(.-)</" .. name .. ">"
    local value = block:match(pattern)
    if value ~= nil then
        return xml_decode(trim(value))
    end
    local lower_name = lower(name)
    pattern = "<" .. lower_name .. "[^>]*>(.-)</" .. lower_name .. ">"
    value = block:match(pattern)
    if value ~= nil then
        return xml_decode(trim(value))
    end
    return ""
end

local function parse_packages_xml(content, context)
    local results = {}
    local path = packages_xml_path(context)
    local packages_dir = ""
    if path ~= "" then
        local xml_dir = parent_dir(path)
        if xml_dir ~= nil and xml_dir ~= "" then
            packages_dir = xml_dir
        end
    end
    for block in tostring(content or ""):gmatch("<Packages>(.-)</Packages>") do
        local name = extract_xml_field(block, "Name")
        if name ~= "" then
            results[#results + 1] = {
                name = name,
                version = extract_xml_field(block, "Version"),
                installedDate = extract_xml_field(block, "Date"),
                refCount = tonumber(extract_xml_field(block, "RefCount")) or 1,
                installPath = packages_dir ~= "" and join_path(packages_dir, name) or nil,
            }
        end
    end
    return results
end

local function load_installed_items(context)
    local path = packages_xml_path(context)
    if path == "" then
        return {}
    end
    local content = read_file(context, path)
    if content == nil then
        return {}
    end
    return parse_packages_xml(content, context)
end

local function installed_lookup(context)
    local lookup = {}
    for _, item in ipairs(load_installed_items(context)) do
        lookup[lower(item.name)] = item
    end
    return lookup
end

local function parse_catalog_tsv(content)
    local results = {}
    local header = nil
    for _, line in ipairs(split_lines(content)) do
        if trim(line) ~= "" then
            local columns = split_tsv(line)
            local first = lower(columns[1] or "")
            if header == nil and first == "name" then
                header = columns
            else
                local function column(index, fallback_name)
                    if header == nil then
                        return trim(columns[index] or "")
                    end
                    for header_index, name in ipairs(header) do
                        if lower(name) == lower(fallback_name) then
                            return trim(columns[header_index] or "")
                        end
                    end
                    return ""
                end

                local name = column(1, "Name")
                if name ~= "" then
                    results[#results + 1] = {
                        name = name,
                        version = column(2, "Version"),
                        description = column(3, "Description"),
                        summary = column(3, "Description"),
                        projectUrl = column(4, "ProjectURL"),
                        downloadUrl = column(5, "InstallURL"),
                        installer = column(5, "InstallURL"),
                        tags = split_csv_field(column(6, "Tags")),
                        dependencies = split_csv_field(column(7, "Dependent")),
                    }
                end
            end
        end
    end
    return results
end

local function load_catalog(context)
    local path = catalog_path(context)
    local content = read_file(context, path)
    if content ~= nil then
        return parse_catalog_tsv(content), nil
    end

    local url = catalog_url(context)
    if url == "" then
        return nil, "catalog snapshot not available at " .. path .. "; set catalogPath, VFP_PM_CATALOG_TSV, or VFP_PM_CATALOG_URL"
    end

    local result = exec_run(context, "curl -fsSL " .. shell_quote(url))
    if not is_command_success(result) then
        return nil, "failed to download catalog snapshot"
    end
    if not write_file(path, result.stdout or "") then
        return nil, "failed to write catalog snapshot cache"
    end
    return parse_catalog_tsv(result.stdout or ""), nil
end

local function catalog_lookup(context)
    local items, err = load_catalog(context)
    if items == nil then
        return nil, err
    end
    local lookup = {}
    for _, item in ipairs(items) do
        lookup[lower(item.name)] = item
    end
    return lookup, nil
end

local function search_catalog(context, prompt)
    local items, err = load_catalog(context)
    if items == nil then
        return nil, err
    end
    local query = lower(prompt)
    local matches = {}
    for _, item in ipairs(items) do
        local haystack = table.concat({
            lower(item.name),
            lower(item.description),
            lower(table.concat(item.tags or {}, " ")),
        }, " ")
        if haystack:find(query, 1, true) ~= nil then
            matches[#matches + 1] = item
        end
    end
    return matches, nil
end

local function resolve_catalog_package(context, package)
    local name = package_name(package)
    if name == "" then
        return nil, "missing package name"
    end
    local lookup, err = catalog_lookup(context)
    if lookup == nil then
        return nil, err
    end
    local item = lookup[lower(name)]
    if item == nil then
        return nil, "package not found in catalog: " .. name
    end
    return item, nil
end

local function encode_json_string(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\")
    text = text:gsub('"', '\\"')
    text = text:gsub("\n", "\\n")
    text = text:gsub("\r", "\\r")
    return text
end

local function read_json_bool(text, key)
    local match = tostring(text or ""):match('"' .. pattern_escape(key) .. '"%s*:%s*(true)')
    if match == "true" then
        return true
    end
    match = tostring(text or ""):match('"' .. pattern_escape(key) .. '"%s*:%s*(false)')
    if match == "false" then
        return false
    end
    return nil
end

local function read_json_string(text, key)
    local value = tostring(text or ""):match('"' .. pattern_escape(key) .. '"%s*:%s*"(.-)"')
    if value == nil then
        return nil
    end
    value = value:gsub('\\n', '\n'):gsub('\\r', '\r'):gsub('\\"', '"'):gsub('\\\\', '\\')
    return value
end

local function load_bridge_result(context, path)
    local content = read_file(context, path)
    if content == nil then
        return nil, "bridge result not found"
    end
    local success = read_json_bool(content, "success")
    local message = read_json_string(content, "message")
    return {
        success = success ~= false,
        message = message,
        name = read_json_string(content, "name"),
        version = read_json_string(content, "version"),
    }, nil
end

local function bridge_paths(context, action, name)
    local safe = sanitize_name(name)
    local bridge_root = join_path(cache_root(context), "bridge")
    return {
        script = join_path(bridge_root, action .. "-" .. safe .. ".prg"),
        result = join_path(bridge_root, action .. "-" .. safe .. ".json"),
    }
end

local function write_bridge_script(path, content)
    if fixture_root() ~= "" then
        return true
    end
    if io == nil or type(io.open) ~= "function" then
        return true
    end
    return write_file(path, content)
end

local function build_bridge_script(action, project_path, package_record, installer_path, result_path, class_name)
    local package_name_value = package_record ~= nil and package_record.name or ""
    local version_value = package_record ~= nil and package_record.version or ""
    local lines = {
        "* Generated by ReqPack vfp-pm plugin",
        "local llOK, lcMessage, loInstaller",
        "llOK = .F.",
        "lcMessage = ''",
        "set safety off",
    }
    if trim(project_path) ~= "" then
        lines[#lines + 1] = "modify project " .. '"' .. encode_json_string(project_path) .. '"' .. " nowait"
    end
    lines[#lines + 1] = "set procedure to " .. '"' .. encode_json_string(installer_path) .. '"' .. " additive"
    lines[#lines + 1] = "loInstaller = createobject(" .. '"' .. encode_json_string(class_name) .. '"' .. ")"
    lines[#lines + 1] = "if vartype(loInstaller) = 'O'"
    lines[#lines + 1] = "  loInstaller.cInstaller = " .. '"' .. encode_json_string(installer_path) .. '"'
    if action == "remove" then
        lines[#lines + 1] = "  llOK = loInstaller.Uninstall()"
    else
        lines[#lines + 1] = "  llOK = loInstaller.Install()"
    end
    lines[#lines + 1] = "endif"
    lines[#lines + 1] = "if llOK"
    lines[#lines + 1] = "  strtofile('{\"success\":true,\"name\":\"" .. encode_json_string(package_name_value) .. "\",\"version\":\"" .. encode_json_string(version_value) .. "\"}', '" .. encode_json_string(result_path) .. "')"
    lines[#lines + 1] = "else"
    lines[#lines + 1] = "  strtofile('{\"success\":false,\"message\":\"bridge action failed\"}', '" .. encode_json_string(result_path) .. "')"
    lines[#lines + 1] = "endif"
    return table.concat(lines, "\n") .. "\n"
end

local function run_bridge_action(context, action, package_record, installer_path, class_name)
    local bridge = bridge_command(context)
    if bridge == "" then
        return nil, "missing VFP bridge command; set VFP_PM_BRIDGE or bridgeCommand"
    end
    local project = project_root(context)
    if project == "" then
        return nil, "missing project path; set project=<path> or projectPath"
    end

    local paths = bridge_paths(context, action, package_record.name or class_name or action)
    local script = build_bridge_script(action, project, package_record, installer_path, paths.result, class_name)
    write_bridge_script(paths.script, script)

    local command = bridge .. " --script " .. shell_quote(paths.script) .. " --result " .. shell_quote(paths.result)
    local result = exec_run(context, command)
    if not is_command_success(result) then
        return nil, "bridge command failed"
    end

    local bridge_result, err = load_bridge_result(context, paths.result)
    if bridge_result == nil then
        return nil, err
    end
    if bridge_result.success ~= true then
        return nil, trim(bridge_result.message) ~= "" and bridge_result.message or "bridge action failed"
    end
    return bridge_result, nil
end

local function package_class_name_from_path(path)
    return strip_extension(basename(path))
end

local function package_name_from_installer_class(class_name)
    return trim(tostring(class_name or ""):gsub("Installer$", ""))
end

local function refresh_item_after_mutation(context, name, fallback_record)
    local installed = installed_lookup(context)[lower(name)]
    return make_item(fallback_record, installed) or make_item(fallback_record, nil)
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
    return { "Visual FoxPro", "FoxGet", "Package Manager" }
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

function plugin.getMissingPackages(packages)
    local missing = {}
    local action = trim(read_field(packages, "action") or "")
    local installed = installed_lookup(nil)
    for _, package in ipairs(packages or {}) do
        local package_action = trim(read_field(package, "action") or action)
        local name = lower(package_name(package))
        local item = installed[name]
        if package_action == "remove" then
            if item ~= nil then
                missing[#missing + 1] = package
            end
        elseif package_action == "update" then
            if item ~= nil then
                missing[#missing + 1] = package
            end
        else
            local wanted_version = package_version(package)
            if item == nil then
                missing[#missing + 1] = package
            elseif wanted_version ~= "" and trim(item.version) ~= wanted_version then
                missing[#missing + 1] = package
            end
        end
    end
    return missing
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(context, "prompt") or "")
    if query == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    local matches, err = search_catalog(context, query)
    if matches == nil then
        log_warn(context, "vfp-pm search unavailable: " .. tostring(err or "unknown error"))
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    local installed = installed_lookup(context)
    local results = {}
    for _, record in ipairs(matches) do
        results[#results + 1] = make_item(record, installed[lower(record.name)])
    end
    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local query = trim(name or read_field(context, "prompt") or "")
    if query == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local lookup, err = catalog_lookup(context)
    if lookup == nil then
        log_warn(context, "vfp-pm info unavailable: " .. tostring(err or "unknown error"))
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local installed = installed_lookup(context)
    local item = make_item(lookup[lower(query)], installed[lower(query)])
    if item == nil then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.list(context)
    local installed = load_installed_items(context)
    local catalog = nil
    local lookup, _ = catalog_lookup(context)
    catalog = lookup or {}
    local results = {}
    for _, item in ipairs(installed) do
        results[#results + 1] = make_item(catalog[lower(item.name)], item)
    end
    emit_event(context, "listed", results)
    return results
end

function plugin.outdated(context)
    local installed = load_installed_items(context)
    local lookup, err = catalog_lookup(context)
    if lookup == nil then
        if #installed > 0 then
            log_warn(context, "vfp-pm outdated unavailable: " .. tostring(err or "unknown error"))
        end
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end
    local results = {}
    for _, item in ipairs(installed) do
        local remote = lookup[lower(item.name)]
        if remote ~= nil and trim(remote.version) ~= "" and trim(item.version) ~= "" then
            local comparison = compare_versions(remote.version, item.version)
            if comparison > 0 then
                results[#results + 1] = make_item(remote, item)
            elseif comparison < 0 and trim(remote.version) ~= trim(item.version) then
                results[#results + 1] = make_item(remote, item)
            end
        end
    end
    emit_event(context, "outdated", results)
    return results
end

function plugin.install(context, packages)
    local local_path = package_local_path(nil, context)
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end
    packages = packages or {}
    if #packages == 0 then
        return true
    end
    begin_step(context, "install vfp-pm packages")
    local installed = {}
    for _, package in ipairs(packages) do
        local record, err = resolve_catalog_package(context, package)
        if record == nil then
            tx_failed(context, "vfp-pm install failed: " .. tostring(err))
            return false
        end
        local installer_path = trim(record.installer or record.downloadUrl)
        if installer_path == "" then
            tx_failed(context, "vfp-pm install failed: missing installer for " .. record.name)
            return false
        end
        local class_name = record.name .. "Installer"
        local bridge_result, bridge_err = run_bridge_action(context, "install", record, installer_path, class_name)
        if bridge_result == nil then
            tx_failed(context, "vfp-pm install failed: " .. tostring(bridge_err))
            return false
        end
        installed[#installed + 1] = refresh_item_after_mutation(context, record.name, record)
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = package_local_path(path, context)
    if local_path == "" then
        tx_failed(context, "vfp-pm installLocal failed: missing path")
        return false
    end
    if lower(local_path):sub(-4) ~= ".prg" then
        tx_failed(context, "vfp-pm installLocal supports only .prg installers")
        return false
    end
    begin_step(context, "install local vfp-pm package")
    local class_name = package_class_name_from_path(local_path)
    local package_name_value = package_name_from_installer_class(class_name)
    local record = {
        name = package_name_value ~= "" and package_name_value or class_name,
        version = package_version({ name = package_name_value }),
        installer = local_path,
        downloadUrl = local_path,
    }
    local bridge_result, err = run_bridge_action(context, "install-local", record, local_path, class_name)
    if bridge_result == nil then
        tx_failed(context, "vfp-pm installLocal failed: " .. tostring(err))
        return false
    end
    emit_event(context, "installed", refresh_item_after_mutation(context, record.name, record))
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    packages = packages or {}
    if #packages == 0 then
        return true
    end
    begin_step(context, "remove vfp-pm packages")
    local installed = installed_lookup(context)
    for _, package in ipairs(packages) do
        local name = package_name(package)
        if name == "" then
            tx_failed(context, "vfp-pm remove failed: missing package name")
            return false
        end
        local installed_item = installed[lower(name)]
        local canonical_name = installed_item ~= nil and installed_item.name or name
        local installer_path = join_path(project_root(context), "Packages", canonical_name, canonical_name .. "Installer.prg")
        local record = { name = canonical_name, version = installed_item and installed_item.version or "", installer = installer_path }
        local bridge_result, err = run_bridge_action(context, "remove", record, installer_path, canonical_name .. "Installer")
        if bridge_result == nil then
            tx_failed(context, "vfp-pm remove failed: " .. tostring(err))
            return false
        end
    end
    emit_event(context, "deleted", packages)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    packages = packages or {}
    if #packages == 0 then
        return true
    end
    begin_step(context, "update vfp-pm packages")
    if not plugin.remove(context, packages) then
        return false
    end
    if not plugin.install(context, packages) then
        return false
    end
    emit_event(context, "updated", packages)
    tx_success(context)
    return true
end

function plugin.resolvePackage(context, package)
    local record = resolve_catalog_package(context, package)
    if type(record) ~= "table" then
        return package
    end
    local installed = installed_lookup(context)
    local item = make_item(record, installed[lower(record.name)])
    if type(package) ~= "table" then
        return item
    end
    local merged = shallow_copy(package)
    for key, value in pairs(item or {}) do
        merged[key] = value
    end
    return merged
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "foxpro", "vfp", "vfpx" },
        writeScopes = {
            { kind = "user-home-subpath", path = ".cache/reqpack/vfp-pm" },
            { kind = "project-subpath", path = "Packages" },
        },
        networkScopes = {},
        privilegeLevel = "none",
        purlType = "generic",
        versionComparatorProfile = "lexicographic",
    }
end

return plugin
