plugin = {}

local PLUGIN_NAME = "Gentoo Portage"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "emerge"
local READ_ENV_PREFIX = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C"
local INFO_MISSING_PATTERNS = {
    "no matches found",
    "nothing found",
    "no results found",
    "masked by",
}
local SUPPORTED_LOCAL_EXTENSIONS = { ".gpkg.tar", ".tbz2", ".xpak" }

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

local function join_quoted(values)
    local parts = {}
    for _, value in ipairs(values or {}) do
        local cleaned = trim(value)
        if cleaned ~= "" then
            parts[#parts + 1] = shell_quote(cleaned)
        end
    end
    return table.concat(parts, " ")
end

local function split_lines(value)
    local lines = {}
    for line in tostring(value or ""):gsub("\r\n", "\n"):gmatch("([^\n]*)\n?") do
        if line == "" and #lines > 0 and lines[#lines] == nil then
            break
        end
        lines[#lines + 1] = line:gsub("\r$", "")
    end

    if #lines > 0 and lines[#lines] == "" then
        table.remove(lines, #lines)
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

local function merge_extra_fields(left, right)
    local merged = shallow_copy(type(left) == "table" and left or {})
    for key, value in pairs(type(right) == "table" and right or {}) do
        merged[key] = value
    end
    if next(merged) == nil then
        return nil
    end
    return merged
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

local function get_field(value, key)
    local value_type = type(value)
    if value_type ~= "table" and value_type ~= "userdata" then
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

local function normalize_result(result)
    local value_type = type(result)
    if value_type == "table" then
        return result
    end

    if value_type == "userdata" then
        local normalized = {}
        for _, key in ipairs({ "success", "ok", "exitCode", "exit_code", "code", "status", "stdout", "stdoutText", "stderr", "stderrText" }) do
            local ok, value = pcall(function()
                return result[key]
            end)
            if ok and value ~= nil then
                normalized[key] = value
            end
        end

        if normalized.stdout == nil then
            normalized.stdout = normalized.stdoutText or ""
        end
        if normalized.stderr == nil then
            normalized.stderr = normalized.stderrText or ""
        end
        if normalized.exitCode == nil then
            normalized.exitCode = normalized.exit_code or normalized.code or normalized.status
        end
        if normalized.success == nil and normalized.ok ~= nil then
            normalized.success = normalized.ok
        end
        if normalized.success == nil and normalized.exitCode ~= nil then
            normalized.success = normalized.exitCode == 0
        end
        return normalized
    end

    return {
        success = false,
        exitCode = 1,
        stdout = "",
        stderr = "command execution failed",
    }
end

local function is_command_success(result)
    if type(result) ~= "table" then
        return false
    end
    if result.success == true then
        return true
    end

    local exit_code = result.exitCode or result.exit_code or result.code or result.status
    return exit_code == 0
end

local function run_command(context, command)
    local result = nil
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        result = context.exec.run(command)
    else
        result = reqpack.exec.run(command)
    end
    return normalize_result(result)
end

local function command_exists(binary, context)
    return is_command_success(run_command(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function build_read_command(command)
    return READ_ENV_PREFIX .. " " .. command
end

local function is_effective_root(context)
    local result = run_command(context, "id -u")
    return is_command_success(result) and trim(result.stdout) == "0"
end

local function select_write_prefix(context)
    if is_effective_root(context) then
        return ""
    end

    if command_exists("doas", context) then
        local probe = run_command(context, "doas -n " .. REQUIRED_BINARY .. " --info >/dev/null 2>&1")
        if is_command_success(probe) then
            return "doas -n "
        end
    end

    if command_exists("sudo", context) then
        local probe = run_command(context, "sudo -n " .. REQUIRED_BINARY .. " --info >/dev/null 2>&1")
        if is_command_success(probe) then
            return "sudo -n "
        end
    end

    return nil, "portage write action requires root, doas -n, or sudo -n"
end

local function run_write_command(context, prefix, arguments)
    return run_command(context, prefix .. REQUIRED_BINARY .. " " .. arguments)
end

local function package_name(package)
    local name = get_field(package, "name")
    if name ~= nil then
        return trim(name)
    end
    return trim(package)
end

local function package_version(package)
    local version = get_field(package, "version")
    if version ~= nil then
        return trim(version)
    end
    return ""
end

local function package_action(package)
    local action = get_field(package, "action")
    if action ~= nil then
        return lower(trim(action))
    end
    return ""
end

local function package_has_file_source(package)
    local local_target = get_field(package, "localTarget")
    if local_target == true then
        return true
    end

    local source_path = get_field(package, "sourcePath")
    return non_empty(source_path) ~= nil
end

local function is_supported_local_path(path)
    local cleaned = lower(trim(path))
    for _, suffix in ipairs(SUPPORTED_LOCAL_EXTENSIONS) do
        if cleaned:sub(-#suffix) == suffix then
            return true
        end
    end
    return false
end

local function supported_local_extensions_message()
    return ".gpkg.tar, .tbz2, and .xpak"
end

local function is_raw_atom_syntax(value)
    local cleaned = trim(value)
    if cleaned == "" then
        return false
    end

    return cleaned:match("^[<>=~]") ~= nil
        or cleaned:find(":", 1, true) ~= nil
        or cleaned:find("[", 1, true) ~= nil
        or cleaned:find("::", 1, true) ~= nil
        or cleaned:find("%*", 1) ~= nil
        or cleaned:find("%[", 1) ~= nil
end

local function strip_atom_operators(value)
    return trim((trim(value):gsub("^[<>=~]+", "")))
end

local function normalize_package_name(value)
    local cleaned = strip_atom_operators(value)
    if cleaned == "" then
        return ""
    end

    cleaned = cleaned:gsub("::[^:]+$", "")
    cleaned = cleaned:gsub("%[.*$", "")
    cleaned = cleaned:gsub(":[^/]+$", "")
    return trim(cleaned)
end

local function split_package_token(token)
    local cleaned = trim(token)
    if cleaned == "" then
        return nil, nil
    end

    cleaned = cleaned:gsub("::[^:]+$", "")

    local category, package_part = cleaned:match("^([^/]+)/(.+)$")
    if category == nil or package_part == nil then
        return cleaned, ""
    end

    local start_index = nil
    local search_from = 1
    while true do
        local index = package_part:find("%-%d", search_from)
        if index == nil then
            break
        end
        start_index = index
        search_from = index + 1
    end

    if start_index == nil then
        return cleaned, ""
    end

    return category .. "/" .. package_part:sub(1, start_index - 1), package_part:sub(start_index + 1)
end

local function atom_base_name(value)
    local normalized = normalize_package_name(value)
    local name = split_package_token(normalized)
    if name == nil then
        return normalized
    end
    return name
end

local function build_exact_atom(name, version)
    local cleaned_name = trim(name)
    local cleaned_version = trim(version)
    if cleaned_name == "" then
        return nil
    end
    if cleaned_version == "" then
        return cleaned_name
    end
    return "=" .. cleaned_name .. "-" .. cleaned_version
end

local function build_install_spec(package)
    if package_has_file_source(package) then
        return nil
    end

    local name = package_name(package)
    local version = package_version(package)
    if name == "" then
        return nil
    end
    if is_raw_atom_syntax(name) then
        return name
    end
    if version ~= "" then
        return build_exact_atom(name, version)
    end
    return name
end

local function collect_nonempty_lines(lines)
    local items = {}
    for _, raw_line in ipairs(lines or {}) do
        local line = trim(raw_line)
        if line ~= "" then
            items[#items + 1] = line
        end
    end
    return items
end

local function first_nonempty_line(lines)
    for _, line in ipairs(collect_nonempty_lines(lines)) do
        return line
    end
    return nil
end

local function join_paragraphs(lines)
    local paragraphs = {}
    local current = {}

    for _, raw_line in ipairs(lines or {}) do
        local line = trim(raw_line)
        if line == "" then
            if #current > 0 then
                paragraphs[#paragraphs + 1] = table.concat(current, " ")
                current = {}
            end
        else
            current[#current + 1] = line
        end
    end

    if #current > 0 then
        paragraphs[#paragraphs + 1] = table.concat(current, " ")
    end

    return table.concat(paragraphs, "\n\n")
end

local function first_paragraph(value)
    local text = trim(value)
    if text == "" then
        return nil
    end
    return text:match("^([^\n]+)") or text
end

local function parse_installed_token(token)
    local name, version = split_package_token(token)
    if non_empty(name) == nil then
        return nil
    end
    return {
        name = name,
        packageId = name,
        version = trim(version or ""),
        installed = true,
        status = "installed",
        type = "package",
        packageType = "ebuild",
    }
end

local function parse_qlist_output(output)
    local items = {}
    for _, raw_line in ipairs(split_lines(output)) do
        local cleaned = trim(raw_line)
        if cleaned ~= "" then
            local item = parse_installed_token(cleaned)
            if item ~= nil then
                items[#items + 1] = item
            end
        end
    end
    return items
end

local function parse_equery_list_output(output)
    local items = {}
    for _, raw_line in ipairs(split_lines(output)) do
        local cleaned = trim(raw_line)
        if cleaned ~= "" and cleaned ~= "*" then
            local token = cleaned:match("^%*?%s*(%S+)") or cleaned
            local item = parse_installed_token(token)
            if item ~= nil then
                items[#items + 1] = item
            end
        end
    end
    return items
end

local function maybe_finalize_search_item(items, current)
    if current ~= nil and non_empty(current.name) ~= nil then
        items[#items + 1] = current
    end
end

local function parse_search_output(output)
    local items = {}
    local current = nil

    for _, raw_line in ipairs(split_lines(output)) do
        local line = trim(raw_line)
        local item_name = line:match("^%*%s+(%S+)%s*$")
        if item_name ~= nil then
            maybe_finalize_search_item(items, current)
            current = {
                name = item_name,
                packageId = item_name,
                installed = false,
                status = "available",
                type = "package",
                packageType = "ebuild",
            }
        elseif current ~= nil then
            local label, value = line:match("^([%a][%a%s]-):%s*(.*)$")
            if label ~= nil then
                local key = lower(trim(label))
                local cleaned_value = trim(value)
                if key == "latest version available" then
                    current.version = cleaned_value
                    current.latestVersion = cleaned_value
                elseif key == "latest version installed" then
                    if cleaned_value ~= "[ Not Installed ]" and cleaned_value ~= "[Not Installed]" then
                        current.installed = true
                        current.status = "installed"
                        if non_empty(current.version) == nil then
                            current.version = cleaned_value:gsub("^%[", ""):gsub("%]$", "")
                        end
                    end
                elseif key == "homepage" then
                    current.homepage = cleaned_value
                elseif key == "description" then
                    current.description = cleaned_value
                    current.summary = cleaned_value
                elseif key == "license" then
                    current.license = cleaned_value
                end
            end
        end
    end

    maybe_finalize_search_item(items, current)
    return items
end

local function parse_equery_meta_output(output)
    local item = {
        extraFields = {},
    }

    for _, raw_line in ipairs(split_lines(output)) do
        local line = trim(raw_line)
        if line ~= "" then
            local headline, repo = line:match("^%*%s+(%S+)%s+%[(.-)%]%s*$")
            if headline ~= nil then
                item.name = normalize_package_name(headline)
                item.packageId = item.name
                item.repository = non_empty(repo)
            else
                local label, value = line:match("^([%a][%a%s]-):%s*(.*)$")
                if label ~= nil then
                    local key = lower(trim(label))
                    local cleaned_value = trim(value)
                    if key == "homepage" then
                        item.homepage = cleaned_value
                    elseif key == "license" then
                        item.license = cleaned_value
                    elseif key == "location" then
                        item.extraFields.location = cleaned_value
                    elseif key == "keywords" then
                        item.extraFields.keywords = cleaned_value
                        local version = cleaned_value:match("^([^:]+):")
                        if version ~= nil then
                            item.version = version
                        end
                    end
                end
            end
        end
    end

    if next(item.extraFields) == nil then
        item.extraFields = nil
    end

    if non_empty(item.name) == nil then
        return {}
    end

    item.installed = false
    item.status = "available"
    item.type = "package"
    item.packageType = "ebuild"
    return item
end

local function parse_outdated_line(line)
    local status_flags, target_token, current_token = trim(line):match("^%[ebuild%s+([A-Z]+)%s*%]%s+(%S+).-%[(.-)%]%s*$")
    if status_flags == nil or target_token == nil or current_token == nil then
        return nil
    end

    if not status_flags:find("U", 1, true) then
        return nil
    end

    local status = status_flags:find("D", 1, true) and "downgradable" or "upgradable"
    local target_name, target_version = split_package_token(target_token)
    local current_clean = trim(current_token):gsub("::[^:]+$", "")
    local current_name, current_version = nil, nil
    if current_clean:find("/", 1, true) ~= nil then
        current_name, current_version = split_package_token(current_clean)
    else
        current_version = current_clean
    end
    local name = non_empty(target_name) or non_empty(current_name)
    if name == nil then
        return nil
    end

    local repo = target_token:match("::([^:]+)$") or current_token:match("::([^:]+)$")
    return {
        name = name,
        packageId = name,
        version = trim(current_version or ""),
        latestVersion = trim(target_version or ""),
        repository = non_empty(repo),
        installed = true,
        status = status,
        type = "package",
        packageType = "ebuild",
    }
end

local function parse_outdated_output(output)
    local items = {}
    for _, raw_line in ipairs(split_lines(output)) do
        local item = parse_outdated_line(raw_line)
        if item ~= nil then
            items[#items + 1] = item
        end
    end
    return items
end

local function empty_result(context, event_name)
    local items = {}
    emit_event(context, event_name, items)
    return items
end

local function installed_lookup(context)
    local items = plugin.list(context)
    local lookup = {}
    for _, item in ipairs(items or {}) do
        lookup[item.name] = item
    end
    return lookup
end

local function outdated_lookup(context)
    local items = plugin.outdated(context)
    local lookup = {}
    for _, item in ipairs(items or {}) do
        lookup[item.name] = item
    end
    return lookup
end

local function query_installed_items(context)
    if command_exists("qlist", context) then
        local result = run_command(context, build_read_command("qlist -ICv"))
        if is_command_success(result) then
            return parse_qlist_output(result.stdout)
        end
        log_warn(context, "portage qlist failed; falling back to equery")
    end

    if command_exists("equery", context) then
        local result = run_command(context, build_read_command("equery -q list '*'"))
        if is_command_success(result) then
            return parse_equery_list_output(result.stdout)
        end
    end

    return nil
end

local function query_search_items(context, prompt)
    local query = trim(prompt)
    if query == "" then
        return {}
    end

    local result = run_command(context, build_read_command("emerge --searchdesc " .. shell_quote(query)))
    if not is_command_success(result) then
        return nil
    end
    return parse_search_output(result.stdout)
end

local function is_missing_info_output(result)
    if result == nil then
        return true
    end

    local text = lower((result.stdout or "") .. "\n" .. (result.stderr or ""))
    for _, pattern in ipairs(INFO_MISSING_PATTERNS) do
        if text:find(pattern, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function query_info_item(context, name)
    local query = normalize_package_name(name)
    if query == "" then
        return {}
    end

    if command_exists("equery", context) then
        local meta_result = run_command(context, build_read_command("equery meta -- " .. shell_quote(query)))
        local desc_result = run_command(context, build_read_command("equery meta --description -- " .. shell_quote(query)))
        if is_command_success(meta_result) and not is_missing_info_output(meta_result) then
            local item = parse_equery_meta_output(meta_result.stdout)
            local description = is_command_success(desc_result) and join_paragraphs(split_lines(desc_result.stdout)) or ""
            if description ~= "" then
                item.description = description
                item.summary = first_paragraph(description)
            end
            if non_empty(item.name) ~= nil then
                return item
            end
        end
    end

    local items = query_search_items(context, query)
    if items == nil then
        return {}
    end

    local fallback = nil
    for _, item in ipairs(items) do
        if item.name == query then
            return item
        end
        if fallback == nil and item.name:find(query, 1, true) ~= nil then
            fallback = item
        end
    end

    return fallback or {}
end

local function collect_install_specs(packages)
    local specs = {}
    for _, package in ipairs(packages or {}) do
        local spec = build_install_spec(package)
        if spec ~= nil and trim(spec) ~= "" then
            specs[#specs + 1] = spec
        end
    end
    return specs
end

local function collect_update_specs(packages)
    local names = {}
    for _, package in ipairs(packages or {}) do
        if not package_has_file_source(package) then
            local raw_name = package_name(package)
            if raw_name ~= "" then
                if is_raw_atom_syntax(raw_name) then
                    names[#names + 1] = raw_name
                else
                    names[#names + 1] = normalize_package_name(raw_name)
                end
            end
        end
    end
    return names
end

local function collect_remove_specs(packages)
    local names = {}
    for _, package in ipairs(packages or {}) do
        if not package_has_file_source(package) then
            local raw_name = package_name(package)
            if raw_name ~= "" then
                names[#names + 1] = normalize_package_name(raw_name)
            end
        end
    end
    return names
end

local function search_match(items, name, version)
    local wanted_name = trim(name)
    local wanted_version = trim(version)
    local fallback = nil
    for _, item in ipairs(items or {}) do
        if trim(item.name) == wanted_name then
            if wanted_version == "" or trim(item.version) == wanted_version or trim(item.latestVersion) == wanted_version then
                return item
            end
            if fallback == nil then
                fallback = item
            end
        end
    end
    return fallback
end

plugin.fileExtensions = { ".gpkg.tar", ".tbz2", ".xpak" }

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
    return { "Gentoo", "Linux", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    local installed = installed_lookup(nil)
    local outdated = outdated_lookup(nil)
    if installed == nil or outdated == nil then
        local passthrough = {}
        for _, package in ipairs(packages or {}) do
            passthrough[#passthrough + 1] = package
        end
        return passthrough
    end

    local missing = {}
    for _, package in ipairs(packages or {}) do
        local action = package_action(package)
        local raw_name = package_name(package)
        local normalized_name = atom_base_name(raw_name)

        if action == "remove" then
            if normalized_name ~= "" and installed[normalized_name] ~= nil then
                missing[#missing + 1] = package
            end
        elseif action == "update" then
            if normalized_name ~= "" and outdated[normalized_name] ~= nil then
                missing[#missing + 1] = package
            end
        elseif is_raw_atom_syntax(raw_name) then
            missing[#missing + 1] = package
        else
            local installed_item = installed[normalized_name]
            local requested_version = package_version(package)
            if installed_item == nil then
                missing[#missing + 1] = package
            elseif requested_version ~= "" and trim(installed_item.version) ~= requested_version then
                missing[#missing + 1] = package
            end
        end
    end

    return missing
end

function plugin.install(context, packages)
    local specs = collect_install_specs(packages)
    if #specs == 0 then
        return true
    end

    local prefix, prefix_error = select_write_prefix(context)
    if prefix == nil then
        tx_failed(context, prefix_error)
        return false
    end

    begin_step(context, "install portage packages")
    local result = run_write_command(context, prefix, "--quiet-build=y --color=n -- " .. join_quoted(specs))
    if not is_command_success(result) then
        tx_failed(context, "portage install failed")
        return false
    end

    emit_event(context, "installed", packages or {})
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" then
        tx_failed(context, "local portage package path is required")
        return false
    end

    if not is_supported_local_path(local_path) then
        tx_failed(context, "installLocal only supports " .. supported_local_extensions_message())
        return false
    end

    local prefix, prefix_error = select_write_prefix(context)
    if prefix == nil then
        tx_failed(context, prefix_error)
        return false
    end

    begin_step(context, "install local portage binary package")
    local result = run_write_command(context, prefix, "--usepkg --quiet-build=y --color=n -- " .. shell_quote(local_path))
    if not is_command_success(result) then
        tx_failed(context, "portage local install failed")
        return false
    end

    emit_event(context, "installed", { path = local_path, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local specs = collect_remove_specs(packages)
    if #specs == 0 then
        return true
    end

    local prefix, prefix_error = select_write_prefix(context)
    if prefix == nil then
        tx_failed(context, prefix_error)
        return false
    end

    begin_step(context, "deselect portage packages")
    local deselect = run_write_command(context, prefix, "--deselect --quiet-build=y --color=n -- " .. join_quoted(specs))
    if not is_command_success(deselect) then
        tx_failed(context, "portage remove failed")
        return false
    end

    begin_step(context, "depclean portage packages")
    local depclean = run_write_command(context, prefix, "--depclean --quiet-build=y --color=n")
    if not is_command_success(depclean) then
        tx_failed(context, "portage remove failed")
        return false
    end

    emit_event(context, "deleted", packages or {})
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local prefix, prefix_error = select_write_prefix(context)
    if prefix == nil then
        tx_failed(context, prefix_error)
        return false
    end

    local specs = collect_update_specs(packages)
    if #specs == 0 then
        begin_step(context, "sync portage repositories")
        local sync_result = run_write_command(context, prefix, "--sync")
        if not is_command_success(sync_result) then
            tx_failed(context, "portage sync failed")
            return false
        end

        begin_step(context, "update portage world")
        local result = run_write_command(context, prefix, "--update --deep --newuse --quiet-build=y --color=n @world")
        if not is_command_success(result) then
            tx_failed(context, "portage update failed")
            return false
        end

        emit_event(context, "updated", {})
        tx_success(context)
        return true
    end

    begin_step(context, "update selected portage packages")
    local result = run_write_command(context, prefix, "--update --quiet-build=y --color=n -- " .. join_quoted(specs))
    if not is_command_success(result) then
        tx_failed(context, "portage update failed")
        return false
    end

    emit_event(context, "updated", packages or {})
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = query_installed_items(context)
    if items == nil then
        log_warn(context, "portage list failed")
        return empty_result(context, "listed")
    end

    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local result = run_command(context, build_read_command("emerge --pretend --update --deep --newuse @world"))
    if not is_command_success(result) then
        log_warn(context, "portage outdated check failed")
        return empty_result(context, "outdated")
    end

    local items = parse_outdated_output(result.stdout)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt)
    if query == "" then
        return empty_result(context, "searched")
    end

    local items = query_search_items(context, query)
    if items == nil then
        return empty_result(context, "searched")
    end

    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local item = query_info_item(context, name)
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local normalized_name = atom_base_name(package_name(package))
    if normalized_name == "" then
        return nil
    end

    local requested_version = package_version(package)
    local item = query_info_item(context, normalized_name)
    if type(item) == "table" and non_empty(item.name) ~= nil then
        if non_empty(item.version) == nil and requested_version ~= "" then
            item.version = requested_version
        end
        return item
    end

    local search_items = query_search_items(context, normalized_name)
    local resolved = search_match(search_items or {}, normalized_name, requested_version)
    if resolved ~= nil then
        return resolved
    end

    return nil
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "portage", "gentoo", "ebuild" },
        writeScopes = {
            { kind = "system-package-paths" },
        },
        networkScopes = {},
        privilegeLevel = "sudo",
        osvEcosystem = "Gentoo",
        purlType = "ebuild",
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
