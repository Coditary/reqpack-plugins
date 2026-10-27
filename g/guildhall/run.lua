plugin = {}

local PLUGIN_ID = "guildhall"
local PLUGIN_NAME = "Guildhall"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "guild"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
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
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
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

local function dirname(path)
    local text = trim(path)
    local parent = text:match("^(.*)[/\\][^/\\]+$")
    if parent == nil or parent == "" then
        return "."
    end
    return parent
end

local function basename(path)
    local cleaned = trim(path):gsub("[/\\]+$", "")
    return cleaned:match("[^/\\]+$") or cleaned
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

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil then
            local cleaned = trim(value)
            if cleaned ~= "" then
                return cleaned
            end
        end
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

local function append_unique(list, seen, value)
    local cleaned = trim(value)
    if cleaned == "" or seen[cleaned] then
        return
    end
    seen[cleaned] = true
    list[#list + 1] = cleaned
end

local function collect_flags(context, package)
    local flags = {}
    local seen = {}
    local function collect_from(object)
        for _, flag in ipairs(read_flags(object)) do
            append_unique(flags, seen, flag)
        end
    end
    collect_from(context)
    collect_from(read_field(context, "request"))
    collect_from(package)
    return flags
end

local function has_flag(flags, name)
    local wanted = lower(name)
    for _, flag in ipairs(flags or {}) do
        if lower(flag) == wanted then
            return true
        end
    end
    return false
end

local function flag_values(flags, key)
    local values = {}
    local prefix = lower(key) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            local value = trim(cleaned:sub(#prefix + 1))
            if value ~= "" then
                values[#values + 1] = value
            end
        end
    end
    return values
end

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        return os.getenv(name)
    end
    return nil
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

local function home_dir()
    local home = trim(getenv("HOME") or "")
    if home ~= "" then
        return home
    end
    return "/home/test"
end

local function cache_root()
    return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
end

local function isolated_home()
    return join_path(cache_root(), "home")
end

local function install_prefix()
    return join_path(isolated_home(), ".local")
end

local function config_file_path()
    return join_path(isolated_home(), ".config", "guildhall", "config.scm")
end

local function list_cache_path()
    return join_path(cache_root(), "reqpack", "last-list.txt")
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function env_prefix()
    local home = isolated_home()
    return "HOME=" .. shell_quote(home)
        .. " NO_COLOR=1"
        .. " LC_ALL=C"
        .. " LANG=C"
        .. " LANGUAGE=C"
end

local function ensure_parent_directory(context, path)
    local parent = dirname(path)
    if parent == "." then
        return true
    end
    local result = exec_run(context, "mkdir -p " .. shell_quote(parent))
    return result ~= nil and result.success == true
end

local function ensure_empty_config_file(context)
    local path = config_file_path()
    if not ensure_parent_directory(context, path) then
        return false
    end
    local result = exec_run(context, "test -e " .. shell_quote(path) .. " || printf %s '' > " .. shell_quote(path))
    return result ~= nil and result.success == true
end

local function request_packages(context, fallback)
    local request = read_field(context, "request")
    return sequence_values(read_field(request, "packages") or read_field(context, "packages") or fallback or {})
end

local function request_prompt(context, fallback)
    local request = read_field(context, "request")
    return first_nonempty(fallback, read_field(request, "prompt"), read_field(context, "prompt")) or ""
end

local function request_local_path(context, fallback)
    local request = read_field(context, "request")
    return first_nonempty(fallback, read_field(request, "localPath"), read_field(request, "path"), read_field(context, "localPath"), read_field(context, "path"))
end

local function package_name(pkg)
    return first_nonempty(read_field(pkg, "name"), read_field(pkg, "packageId"))
end

local function package_version(pkg)
    return first_nonempty(read_field(pkg, "version"))
end

local function package_selector(pkg)
    local name = package_name(pkg)
    if name == nil then
        return nil
    end
    local version = package_version(pkg)
    if version ~= nil then
        return name .. "=" .. version
    end
    return name
end

local function repo_values(context, package)
    local values = {}
    local seen = {}
    local function add_many(flags)
        for _, value in ipairs(flag_values(flags, "repo")) do
            append_unique(values, seen, value)
        end
    end
    add_many(read_flags(context))
    add_many(read_flags(read_field(context, "request")))
    add_many(read_flags(package))
    local env_repo = first_nonempty(getenv("REQPACK_GUILDHALL_REPO"))
    if env_repo ~= nil then
        for item in tostring(env_repo):gmatch("[^,]+") do
            append_unique(values, seen, item)
        end
    end
    return values
end

local function base_command_parts(context, package, include_repos)
    local parts = { env_prefix(), REQUIRED_BINARY }
    if include_repos then
        for _, repo in ipairs(repo_values(context, package)) do
            parts[#parts + 1] = "--repo=" .. shell_quote(repo)
        end
    end
    parts[#parts + 1] = "--no-config"
    parts[#parts + 1] = "--prefix=" .. shell_quote(install_prefix())
    return parts
end

local function build_command(context, package, include_repos, subcommand, extra_parts)
    local parts = base_command_parts(context, package, include_repos)
    parts[#parts + 1] = subcommand
    for _, part in ipairs(extra_parts or {}) do
        parts[#parts + 1] = part
    end
    return table.concat(parts, " ")
end

local function require_binary(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true
    end
    tx_failed(context, "guild command not available")
    return false
end

local function ensure_remote_repos(context, package, action)
    local repos = repo_values(context, package)
    if #repos > 0 then
        return true
    end
    tx_failed(context, action .. " requires repo=<uri> flag or REQPACK_GUILDHALL_REPO")
    return false
end

local function run_update_catalog(context, package)
    if not ensure_empty_config_file(context) then
        tx_failed(context, "failed to prepare guildhall config")
        return false
    end
    local command = build_command(context, package, true, "update", {})
    local result = exec_run(context, command)
    if result == nil or result.success ~= true then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "guild update failed"))
        return false
    end
    return true
end

local function compare_version_tokens(left, right)
    local left_number = tonumber(left)
    local right_number = tonumber(right)
    if left_number ~= nil and right_number ~= nil then
        if left_number < right_number then
            return -1
        end
        if left_number > right_number then
            return 1
        end
        return 0
    end
    if left < right then
        return -1
    end
    if left > right then
        return 1
    end
    return 0
end

local function version_tokens(value)
    local tokens = {}
    local normalized = trim(value):gsub("[-_.]+", ".")
    for token in normalized:gmatch("[^.]+") do
        tokens[#tokens + 1] = token
    end
    if #tokens == 0 and normalized ~= "" then
        tokens[1] = normalized
    end
    return tokens
end

local function compare_versions(left, right)
    local left_tokens = version_tokens(left)
    local right_tokens = version_tokens(right)
    local max_count = math.max(#left_tokens, #right_tokens)
    for index = 1, max_count do
        local left_token = left_tokens[index] or "0"
        local right_token = right_tokens[index] or "0"
        local cmp = compare_version_tokens(left_token, right_token)
        if cmp ~= 0 then
            return cmp
        end
    end
    return 0
end

local function sort_items_by_name_and_version(items)
    table.sort(items, function(left, right)
        local left_name = lower(read_field(left, "name") or "")
        local right_name = lower(read_field(right, "name") or "")
        if left_name == right_name then
            return compare_versions(read_field(left, "version") or "", read_field(right, "version") or "") < 0
        end
        return left_name < right_name
    end)
end

local function parse_list_line(line)
    local status, name, version, summary = trim(line):match("^(%S+)%s+(%S+)%s+(%S+)%s*(.*)$")
    if status == nil then
        return nil
    end
    local item = {
        name = name,
        packageId = name,
        version = version,
        summary = trim(summary),
        status = status,
        installed = status == "i" or status == "U",
        packageType = "guile-package",
        type = "package",
    }
    return item
end

local function parse_list_output(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local item = parse_list_line(line)
        if item ~= nil then
            items[#items + 1] = item
        end
    end
    sort_items_by_name_and_version(items)
    return items
end

local function parse_show_blocks(stdout)
    local blocks = {}
    local current = {}
    for _, line in ipairs(split_lines(stdout)) do
        if trim(line) == "" then
            if #current > 0 then
                blocks[#blocks + 1] = current
                current = {}
            end
        else
            current[#current + 1] = line
        end
    end
    if #current > 0 then
        blocks[#blocks + 1] = current
    end
    return blocks
end

local function finalize_package_record(item)
    item.name = first_nonempty(item.name, item.packageId)
    item.packageId = first_nonempty(item.packageId, item.name)
    item.packageType = first_nonempty(item.packageType, "guile-package")
    item.type = first_nonempty(item.type, "package")
    if item.summary == nil and item.description ~= nil then
        item.summary = first_nonempty(item.description:match("^([^\n]+)"))
    end
    return item
end

local function parse_show_block(lines)
    local item = {
        depends = {},
        provides = {},
        categories = {},
        files = {},
        extraFields = {},
        installed = false,
        packageType = "guile-package",
        type = "package",
    }
    local in_description = false
    local description_lines = {}
    for _, line in ipairs(lines or {}) do
        if in_description and line:match("^%s") then
            description_lines[#description_lines + 1] = trim(line)
        else
            local key, value = line:match("^([A-Za-z][A-Za-z ]+):%s*(.*)$")
            if key ~= nil then
                local normalized = lower(key)
                if normalized == "package" then
                    item.name = value
                    item.packageId = value
                elseif normalized == "version" then
                    item.version = value
                elseif normalized == "status" then
                    item.status = lower(value)
                    item.installed = item.status == "installed" or item.status == "unpacked"
                elseif normalized == "depends" then
                    item.dependsText = value
                elseif normalized == "provides" then
                    item.providesText = value
                elseif normalized == "homepage" then
                    item.homepage = value
                elseif normalized == "description" then
                    description_lines[#description_lines + 1] = value
                    in_description = true
                elseif normalized == "category" then
                    item.categories[#item.categories + 1] = value
                    in_description = false
                else
                    item.extraFields[normalized] = value
                    in_description = false
                end
            elseif trim(line) ~= "" then
                if in_description then
                    description_lines[#description_lines + 1] = trim(line)
                elseif line:match("^%s") then
                    item.files[#item.files + 1] = trim(line)
                end
            end
        end
    end
    if #description_lines > 0 then
        item.description = table.concat(description_lines, "\n")
    end
    return finalize_package_record(item)
end

local function parse_show_output(stdout)
    local items = {}
    for _, block in ipairs(parse_show_blocks(stdout)) do
        local item = parse_show_block(block)
        if item.name ~= nil then
            items[#items + 1] = item
        end
    end
    sort_items_by_name_and_version(items)
    return items
end

local function parse_bundle_names(stdout)
    local names = {}
    local seen = {}
    for _, item in ipairs(parse_show_output(stdout)) do
        append_unique(names, seen, item.name)
    end
    return names
end

local function cache_list_output(context, stdout)
    if not ensure_parent_directory(context, list_cache_path()) then
        return
    end
    exec_run(context, "printf %s " .. shell_quote(stdout or "") .. " > " .. shell_quote(list_cache_path()))
end

local function query_list(context, include_all, package)
    if not ensure_empty_config_file(context) then
        return nil, "failed to prepare guildhall config"
    end
    local extra = {}
    if include_all then
        extra[#extra + 1] = "--all"
    end
    local command = build_command(context, package, include_all, "list-packages", extra)
    local result = exec_run(context, command)
    if result == nil or result.success ~= true then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "guild list-packages failed")
    end
    if not include_all then
        cache_list_output(context, result.stdout or "")
    end
    return parse_list_output(result.stdout or "")
end

local function select_info_item(items, query)
    if items == nil or #items == 0 then
        return {}
    end
    local name, version = tostring(query or ""):match("^([^=]+)=([^=]+)$")
    if version ~= nil then
        for _, item in ipairs(items) do
            if item.name == name and trim(item.version or "") == trim(version) then
                return item
            end
        end
    end
    for _, item in ipairs(items) do
        if item.installed then
            return item
        end
    end
    local best = items[1]
    for index = 2, #items do
        if compare_versions(items[index].version or "", best.version or "") > 0 then
            best = items[index]
        end
    end
    return best
end

local function read_cached_list(context)
    local result = exec_run(context, "cat " .. shell_quote(list_cache_path()))
    if result == nil or result.success ~= true then
        return {}
    end
    return parse_list_output(result.stdout or "")
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
    return { "language", "package-manager", "guile" }
end

function plugin.init()
    return command_exists(nil, REQUIRED_BINARY)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "guile", "guildhall", "scheme" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".cache/reqpack/guildhall" },
        },
        networkScopes = { "configured-guildhall-repositories" },
        privilegeLevel = "none",
        purlType = "generic",
    }
end

function plugin.getMissingPackages(packages)
    if not command_exists(nil, REQUIRED_BINARY) then
        return packages or {}
    end
    local installed = read_cached_list(nil)
    if #installed == 0 then
        local items = query_list(nil, false, nil)
        if items ~= nil then
            installed = items
        end
    end
    local installed_map = {}
    for _, item in ipairs(installed) do
        installed_map[lower(item.name or "")] = item.version or true
    end
    local missing = {}
    for _, pkg in ipairs(packages or {}) do
        local action = lower(read_field(pkg, "action") or "")
        local name = package_name(pkg)
        local version = package_version(pkg)
        local installed_version = name ~= nil and installed_map[lower(name)] or nil
        if name ~= nil then
            if action == "install" then
                if installed_version == nil then
                    missing[#missing + 1] = pkg
                elseif version ~= nil and trim(installed_version) ~= trim(version) then
                    missing[#missing + 1] = pkg
                end
            elseif action == "remove" or action == "update" then
                if installed_version ~= nil then
                    missing[#missing + 1] = pkg
                end
            end
        end
    end
    return missing
end

function plugin.install(context, packages)
    packages = request_packages(context, packages)
    if packages == nil or #packages == 0 then
        return true
    end
    if not require_binary(context) then
        return false
    end
    if not ensure_remote_repos(context, packages[1], "guildhall install") then
        return false
    end
    if not run_update_catalog(context, packages[1]) then
        return false
    end
    for _, pkg in ipairs(packages) do
        local selector = package_selector(pkg)
        if selector == nil then
            tx_failed(context, "guildhall install requires package name")
            return false
        end
        local extra = {}
        if has_flag(collect_flags(context, pkg), "no-depends") then
            extra[#extra + 1] = "--no-depends"
        end
        extra[#extra + 1] = shell_quote(selector)
        begin_step(context, "Installing " .. selector)
        local result = exec_run(context, build_command(context, pkg, true, "install", extra))
        if result == nil or result.success ~= true then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "guild install failed"))
            return false
        end
    end
    emit_event(context, "installed", packages)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.installLocal(context, path)
    local local_path = request_local_path(context, path)
    if local_path == nil then
        tx_failed(context, "missing local bundle path")
        return false
    end
    if not require_binary(context) then
        return false
    end
    if not ensure_empty_config_file(context) then
        tx_failed(context, "failed to prepare guildhall config")
        return false
    end
    local exists = exec_run(context, "test -e " .. shell_quote(local_path))
    if exists == nil or exists.success ~= true then
        tx_failed(context, "local bundle path does not exist")
        return false
    end
    local show_result = exec_run(context, build_command(context, nil, false, "show-bundle", { shell_quote(local_path) }))
    if show_result == nil or show_result.success ~= true then
        tx_failed(context, first_nonempty(show_result and show_result.stderr, show_result and show_result.stdout, "guild show-bundle failed"))
        return false
    end
    local bundle_packages = parse_bundle_names(show_result.stdout or "")
    if #bundle_packages == 0 then
        tx_failed(context, "bundle contains no packages")
        return false
    end
    local extra = { "--bundle=" .. shell_quote(local_path) }
    for _, name in ipairs(bundle_packages) do
        extra[#extra + 1] = shell_quote(name)
    end
    begin_step(context, "Installing local Guildhall bundle")
    local install_result = exec_run(context, build_command(context, nil, false, "install", extra))
    if install_result == nil or install_result.success ~= true then
        tx_failed(context, first_nonempty(install_result and install_result.stderr, install_result and install_result.stdout, "guild install --bundle failed"))
        return false
    end
    local installed = {}
    for _, name in ipairs(bundle_packages) do
        installed[#installed + 1] = {
            name = name,
            packageId = name,
            source = local_path,
            localTarget = true,
            packageType = "guile-package",
            type = "package",
        }
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.remove(context, packages)
    packages = request_packages(context, packages)
    if packages == nil or #packages == 0 then
        return true
    end
    if not require_binary(context) then
        return false
    end
    if not ensure_empty_config_file(context) then
        tx_failed(context, "failed to prepare guildhall config")
        return false
    end
    for _, pkg in ipairs(packages) do
        local name = package_name(pkg)
        if name == nil then
            tx_failed(context, "guildhall remove requires package name")
            return false
        end
        local extra = {}
        if has_flag(collect_flags(context, pkg), "no-depends") then
            extra[#extra + 1] = "--no-depends"
        end
        extra[#extra + 1] = shell_quote(name)
        begin_step(context, "Removing " .. name)
        local result = exec_run(context, build_command(context, pkg, false, "remove", extra))
        if result == nil or result.success ~= true then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "guild remove failed"))
            return false
        end
    end
    emit_event(context, "deleted", packages)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.update(context, packages)
    packages = request_packages(context, packages)
    if not require_binary(context) then
        return false
    end
    if not ensure_empty_config_file(context) then
        tx_failed(context, "failed to prepare guildhall config")
        return false
    end
    if packages == nil or #packages == 0 then
        if not ensure_remote_repos(context, nil, "guildhall update") then
            return false
        end
        if not run_update_catalog(context, nil) then
            return false
        end
        begin_step(context, "Upgrading Guildhall packages")
        local result = exec_run(context, build_command(context, nil, true, "upgrade", {}))
        if result == nil or result.success ~= true then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "guild upgrade failed"))
            return false
        end
        emit_event(context, "updated", {})
        tx_success(context)
        emit_event(context, "success", "")
        return true
    end
    if not ensure_remote_repos(context, packages[1], "guildhall update") then
        return false
    end
    if not run_update_catalog(context, packages[1]) then
        return false
    end
    for _, pkg in ipairs(packages) do
        local selector = package_selector(pkg)
        if selector == nil then
            tx_failed(context, "guildhall update requires package name")
            return false
        end
        begin_step(context, "Updating " .. selector)
        local result = exec_run(context, build_command(context, pkg, true, "install", { shell_quote(selector) }))
        if result == nil or result.success ~= true then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "guild install update failed"))
            return false
        end
    end
    emit_event(context, "updated", packages)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.list(context)
    if not require_binary(context) then
        return {}
    end
    local items, message = query_list(context, false, nil)
    if items == nil then
        log_warn(context, message)
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    if not require_binary(context) then
        local items = {}
        emit_event(context, "outdated", items)
        return items
    end
    if not ensure_remote_repos(context, nil, "guildhall outdated") then
        return {}
    end
    if not run_update_catalog(context, nil) then
        return {}
    end
    local installed, message = query_list(context, false, nil)
    if installed == nil then
        log_warn(context, message)
        installed = {}
    end
    local outdated = {}
    for _, pkg in ipairs(installed) do
        local show_result = exec_run(context, build_command(context, pkg, true, "show", { shell_quote(pkg.name) }))
        if show_result ~= nil and show_result.success == true then
            local versions = parse_show_output(show_result.stdout or "")
            local best = select_info_item(versions, pkg.name)
            local latest = nil
            for _, item in ipairs(versions) do
                latest = latest or item.version
                if compare_versions(item.version or "", latest or "") > 0 then
                    latest = item.version
                end
            end
            if latest ~= nil and compare_versions(latest, pkg.version or "") > 0 then
                outdated[#outdated + 1] = {
                    name = pkg.name,
                    packageId = pkg.name,
                    version = pkg.version,
                    latestVersion = latest,
                    summary = best.summary,
                    packageType = "guile-package",
                    type = "package",
                }
            end
        else
            log_warn(context, "skipping outdated check for " .. tostring(pkg.name))
        end
    end
    sort_items_by_name_and_version(outdated)
    emit_event(context, "outdated", outdated)
    return outdated
end

function plugin.search(context, prompt)
    local query = lower(request_prompt(context, prompt))
    if not require_binary(context) then
        local items = {}
        emit_event(context, "searched", items)
        return items
    end
    if not ensure_remote_repos(context, nil, "guildhall search") then
        local items = {}
        emit_event(context, "searched", items)
        return items
    end
    if not run_update_catalog(context, nil) then
        local items = {}
        emit_event(context, "searched", items)
        return items
    end
    local items, message = query_list(context, true, nil)
    if items == nil then
        log_warn(context, message)
        items = {}
    end
    local filtered = {}
    for _, item in ipairs(items) do
        if query == "" or lower(item.name or ""):find(query, 1, true) ~= nil or lower(item.summary or ""):find(query, 1, true) ~= nil then
            filtered[#filtered + 1] = item
        end
    end
    emit_event(context, "searched", filtered)
    return filtered
end

function plugin.info(context, name)
    local query = request_prompt(context, name)
    if query == "" then
        local item = {}
        emit_event(context, "informed", item)
        return item
    end
    if not require_binary(context) then
        local item = {}
        emit_event(context, "informed", item)
        return item
    end
    if not ensure_remote_repos(context, nil, "guildhall info") then
        local item = {}
        emit_event(context, "informed", item)
        return item
    end
    if not run_update_catalog(context, nil) then
        local item = {}
        emit_event(context, "informed", item)
        return item
    end
    local result = exec_run(context, build_command(context, nil, true, "show", { shell_quote(query) }))
    if result == nil or result.success ~= true then
        local item = {}
        emit_event(context, "informed", item)
        return item
    end
    local items = parse_show_output(result.stdout or "")
    local item = select_info_item(items, query)
    if next(item) ~= nil then
        local versions = {}
        for _, record in ipairs(items) do
            versions[#versions + 1] = record.version
        end
        item.extraFields = shallow_copy(item.extraFields or {})
        item.extraFields.availableVersions = versions
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end
    local query = package_selector(package) or package_name(package)
    if query == nil then
        return nil
    end
    local item = plugin.info(context, query)
    if type(item) == "table" and next(item) ~= nil then
        return item
    end
    return {
        name = package_name(package),
        packageId = package_name(package),
        version = package_version(package),
        packageType = "guile-package",
        type = "package",
    }
end

function plugin.shutdown()
    return true
end

return plugin
