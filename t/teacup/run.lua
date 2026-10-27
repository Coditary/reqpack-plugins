plugin = {}

local PLUGIN_ID = "teacup"
local PLUGIN_NAME = "Teacup"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "teacup"

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

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function home_dir()
    if os ~= nil and type(os.getenv) == "function" then
        local fixture_root = trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT"))
        if fixture_root ~= "" then
            return "/home/test"
        end
        local home = trim(os.getenv("HOME"))
        if home ~= "" then
            return home
        end
        local profile = trim(os.getenv("USERPROFILE"))
        if profile ~= "" then
            return profile
        end
    end
    return "/home/test"
end

local function cache_root()
    return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
end

local function repository_path()
    return join_path(cache_root(), "repository")
end

local function reqpack_cache_dir()
    return join_path(cache_root(), "reqpack")
end

local function list_cache_path()
    return join_path(reqpack_cache_dir(), "last-list.txt")
end

local function ensure_directory(context, path)
    local cleaned = trim(path)
    if cleaned == "" or cleaned == "." then
        return true
    end
    local result = exec_run(context, "mkdir -p " .. shell_quote(cleaned))
    return result ~= nil and result.success == true
end

local function write_text_file(context, path, content)
    local dir = trim(path):match("^(.*)[/\\][^/\\]+$")
    if dir ~= nil and dir ~= "" then
        if not ensure_directory(context, dir) then
            return false
        end
    end
    local result = exec_run(context, "printf %s " .. shell_quote(content or "") .. " > " .. shell_quote(path))
    return result ~= nil and result.success == true
end

local function read_text_file(context, path)
    local result = exec_run(context, "cat " .. shell_quote(path))
    if result == nil or result.success ~= true then
        return nil
    end
    return result.stdout or ""
end

local function ensure_repo(context)
    local root = cache_root()
    local repo = repository_path()
    if not ensure_directory(context, root) then
        tx_failed(context, "failed to prepare Teacup cache root")
        return false
    end
    local result = exec_run(context, "test -d " .. shell_quote(repo) .. " || teacup create " .. shell_quote(repo))
    if result == nil or result.success ~= true then
        tx_failed(context, "failed to initialize Teacup repository")
        return false
    end
    return true
end

local function package_name(package)
    return trim(read_field(package, "name") or package or "")
end

local function package_version(package)
    return trim(read_field(package, "version") or "")
end

local function package_entity(package)
    local direct = trim(read_field(package, "packageType") or read_field(package, "entity") or "")
    if direct ~= "" then
        return direct
    end
    for _, flag in ipairs(read_field(package, "flags") or {}) do
        local value = trim(flag)
        local entity = value:match("^entity=(.+)$")
        if entity ~= nil and trim(entity) ~= "" then
            return trim(entity)
        end
    end
    return ""
end

local function package_platform(package)
    local direct = trim(read_field(package, "architecture") or read_field(package, "platform") or "")
    if direct ~= "" then
        return direct
    end
    local extra = read_field(package, "extraFields")
    if type(extra) == "table" then
        return trim(extra.platform or "")
    end
    return ""
end

local function has_flag(package, wanted)
    local wanted_lower = lower(wanted)
    for _, flag in ipairs(read_field(package, "flags") or {}) do
        if lower(flag) == wanted_lower then
            return true
        end
    end
    return false
end

local function build_install_command(package, local_path)
    local parts = {
        "teacup install",
        "--at " .. shell_quote(repository_path()),
    }
    if package ~= nil and has_flag(package, "force") then
        parts[#parts + 1] = "--force"
    end
    local entity = package ~= nil and package_entity(package) or ""
    if entity ~= "" then
        parts[#parts + 1] = "-is " .. entity
    end
    if local_path ~= nil then
        parts[#parts + 1] = shell_quote(local_path)
    else
        local name = package_name(package)
        if name ~= "" then
            parts[#parts + 1] = shell_quote(name)
        end
        local version = package_version(package)
        if version ~= "" then
            parts[#parts + 1] = shell_quote(version)
        end
    end
    return table.concat(parts, " ")
end

local function build_remove_command(package)
    local parts = {
        "teacup remove",
        "--at " .. shell_quote(repository_path()),
    }
    local entity = package_entity(package)
    if entity ~= "" then
        parts[#parts + 1] = "--is " .. entity
    end
    local name = package_name(package)
    if name ~= "" then
        parts[#parts + 1] = shell_quote(name)
    end
    local version = package_version(package)
    if version ~= "" then
        parts[#parts + 1] = shell_quote(version)
    end
    local platform = package_platform(package)
    if platform ~= "" then
        parts[#parts + 1] = shell_quote(platform)
    end
    return table.concat(parts, " ")
end

local function build_list_command(installed_only, prompt, only_filter)
    local parts = { "teacup list" }
    if installed_only then
        parts[#parts + 1] = "--at-default"
        parts[#parts + 1] = "--at " .. shell_quote(repository_path())
    elseif only_filter ~= nil and only_filter ~= "" then
        parts[#parts + 1] = "--only " .. only_filter
        parts[#parts + 1] = "--at " .. shell_quote(repository_path())
    end
    local clean_prompt = trim(prompt)
    if clean_prompt ~= "" then
        parts[#parts + 1] = shell_quote(clean_prompt)
    end
    return table.concat(parts, " ")
end

local function build_describe_command(name)
    return "teacup describe --all " .. shell_quote(name)
end

local function parse_table_items(stdout, installed, latest_only)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        local lowered = lower(cleaned)
        if cleaned ~= ""
            and not lowered:match("^entity%s+name%s+version%s+platform")
            and not cleaned:match("^%-[%-%s]*$")
            and not lowered:match("^%d+%s+entit")
        then
            local entity, name, version, platform = cleaned:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$")
            if entity ~= nil then
                local item = {
                    name = name,
                    version = version,
                    packageId = entity .. ":" .. name .. "@" .. version .. "#" .. platform,
                    packageType = entity,
                    architecture = platform,
                    installed = installed == true,
                    status = installed == true and "installed" or nil,
                    extraFields = {
                        entity = entity,
                        platform = platform,
                    },
                }
                if latest_only then
                    item.latestVersion = version
                    item.installed = true
                    item.status = "outdated"
                end
                items[#items + 1] = item
            end
        end
    end
    table.sort(items, function(left, right)
        local left_name = lower(left.name)
        local right_name = lower(right.name)
        if left_name == right_name then
            if lower(left.version) == lower(right.version) then
                return lower(left.architecture) < lower(right.architecture)
            end
            return lower(left.version) < lower(right.version)
        end
        return left_name < right_name
    end)
    return items
end

local function append_continued_value(target, key, value)
    local current = trim(target[key] or "")
    local addition = trim(value)
    if addition == "" then
        return
    end
    if current == "" then
        target[key] = addition
    else
        target[key] = current .. "\n" .. addition
    end
end

local function parse_describe_output(stdout)
    local meta = {}
    local last_key = nil
    for _, line in ipairs(split_lines(stdout)) do
        local key, value = line:match("^([%w:][%w:%- ]-)%s*:%s*(.*)$")
        if key ~= nil then
            last_key = lower(key:gsub("%s+", " "))
            append_continued_value(meta, last_key, value)
        else
            local entity_name = line:match("^Entity%s+(.+)$")
            if entity_name ~= nil then
                meta.name = trim(entity_name)
                last_key = nil
            else
                local origin = line:match("^Origin%s+@%s+(.+)$") or line:match("^Description%s+@%s+(.+)$")
                if origin ~= nil then
                    meta.origin = trim(origin)
                    last_key = nil
                else
                    local continuation = line:match("^%|%s*(.*)$")
                    if continuation ~= nil and last_key ~= nil then
                        append_continued_value(meta, last_key, continuation)
                    end
                end
            end
        end
    end
    return meta
end

local function query_list(context, installed_only, prompt, only_filter)
    local result = exec_run(context, build_list_command(installed_only, prompt, only_filter))
    if result == nil or result.success ~= true then
        return nil, result
    end
    return parse_table_items(result.stdout or "", installed_only == true, only_filter == "newer" or only_filter == "update"), result
end

local function cache_installed_list(context, stdout)
    if not ensure_directory(context, reqpack_cache_dir()) then
        return false
    end
    return write_text_file(context, list_cache_path(), stdout or "")
end

local function read_cached_list(context)
    local raw = read_text_file(context, list_cache_path())
    if raw == nil then
        return {}
    end
    return parse_table_items(raw, true, false)
end

local function exact_match_installed(installed, package)
    local wanted_name = lower(package_name(package))
    local wanted_version = package_version(package)
    local wanted_entity = lower(package_entity(package))
    for _, item in ipairs(installed or {}) do
        if lower(item.name) == wanted_name then
            if wanted_entity ~= "" and lower(item.packageType or "") ~= wanted_entity then
                goto continue
            end
            if wanted_version == "" or trim(item.version) == wanted_version then
                return true
            end
        end
        ::continue::
    end
    return false
end

local function any_match_installed(installed, package)
    local wanted_name = lower(package_name(package))
    local wanted_entity = lower(package_entity(package))
    for _, item in ipairs(installed or {}) do
        if lower(item.name) == wanted_name then
            if wanted_entity == "" or lower(item.packageType or "") == wanted_entity then
                return true
            end
        end
    end
    return false
end

local function request_packages(context, packages)
    if packages ~= nil then
        return packages
    end
    local direct = read_field(context, "packages")
    if type(direct) == "table" then
        return direct
    end
    local request = read_field(context, "request")
    local nested = read_field(request, "packages")
    if type(nested) == "table" then
        return nested
    end
    return {}
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
    return { "language", "package-manager", "tcl" }
end

function plugin.init()
    return command_exists(nil, REQUIRED_BINARY)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "package-install", "package-remove", "package-update", "package-query" },
        ecosystemScopes = { "tcl", "teacup", "teapot" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".cache/reqpack/teacup" },
        },
        networkScopes = { "configured-teapot-archives" },
        privilegeLevel = "none",
        purlType = "generic",
    }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if not command_exists(nil, REQUIRED_BINARY) then
        return requested
    end
    local installed = read_cached_list(nil)
    if #installed == 0 then
        if not ensure_repo(nil) then
            return requested
        end
        local queried = query_list(nil, true, nil, nil)
        if queried ~= nil then
            installed = queried
        end
    end

    local filtered = {}
    for _, package in ipairs(requested) do
        local action = lower(read_field(package, "action") or "install")
        if action == "remove" then
            if any_match_installed(installed, package) then
                filtered[#filtered + 1] = package
            end
        elseif action == "update" then
            if any_match_installed(installed, package) then
                filtered[#filtered + 1] = package
            end
        else
            local version = package_version(package)
            if version == "" then
                if not any_match_installed(installed, package) then
                    filtered[#filtered + 1] = package
                end
            elseif not exact_match_installed(installed, package) then
                filtered[#filtered + 1] = package
            end
        end
    end
    return filtered
end

function plugin.install(context, packages)
    local requested = request_packages(context, packages)
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "teacup binary not available")
        return false
    end
    begin_step(context, "install Teacup packages")
    if not ensure_repo(context) then
        return false
    end
    for _, package in ipairs(requested) do
        if package_name(package) == "" then
            tx_failed(context, "Teacup install requires package name")
            return false
        end
        local result = exec_run(context, build_install_command(package, nil))
        if result == nil or result.success ~= true then
            tx_failed(context, "teacup install failed for " .. package_name(package))
            return false
        end
    end
    emit_event(context, "installed", requested)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local request = read_field(context, "request")
    local local_path = trim(path or read_field(request, "localPath") or read_field(request, "path") or "")
    begin_step(context, "install local Teacup artifact")
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "teacup binary not available")
        return false
    end
    if local_path == "" then
        tx_failed(context, "Teacup local install requires artifact path")
        return false
    end
    if not ensure_repo(context) then
        return false
    end
    local result = exec_run(context, build_install_command(nil, local_path))
    if result == nil or result.success ~= true then
        tx_failed(context, "teacup local install failed")
        return false
    end
    emit_event(context, "installed", { { name = local_path, packageId = local_path } })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = request_packages(context, packages)
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "teacup binary not available")
        return false
    end
    begin_step(context, "remove Teacup packages")
    if not ensure_repo(context) then
        return false
    end
    for _, package in ipairs(requested) do
        if package_name(package) == "" then
            tx_failed(context, "Teacup remove requires package name")
            return false
        end
        local result = exec_run(context, build_remove_command(package))
        if result == nil or result.success ~= true then
            tx_failed(context, "teacup remove failed for " .. package_name(package))
            return false
        end
    end
    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = request_packages(context, packages)
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "teacup binary not available")
        return false
    end
    begin_step(context, "update Teacup packages")
    if not ensure_repo(context) then
        return false
    end
    if #requested == 0 then
        local result = exec_run(context, "teacup update --at " .. shell_quote(repository_path()))
        if result == nil or result.success ~= true then
            tx_failed(context, "teacup update failed")
            return false
        end
        emit_event(context, "updated", requested)
        tx_success(context)
        return true
    end

    for _, package in ipairs(requested) do
        if package_name(package) == "" then
            tx_failed(context, "Teacup update requires package name")
            return false
        end
        local result = exec_run(context, build_install_command(package, nil))
        if result == nil or result.success ~= true then
            tx_failed(context, "teacup targeted update failed for " .. package_name(package))
            return false
        end
    end
    emit_event(context, "updated", requested)
    tx_success(context)
    return true
end

function plugin.list(context)
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "teacup binary not available")
        return {}
    end
    if not ensure_repo(context) then
        return {}
    end
    local items, result = query_list(context, true, nil, nil)
    if items == nil then
        tx_failed(context, "teacup list failed")
        return {}
    end
    cache_installed_list(context, result.stdout or "")
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "teacup binary not available")
        return {}
    end
    if not ensure_repo(context) then
        return {}
    end
    local items = query_list(context, false, nil, "newer")
    if items == nil then
        tx_failed(context, "teacup outdated query failed")
        return {}
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(read_field(context, "request"), "prompt") or "")
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "teacup binary not available")
        return {}
    end
    local items = query_list(context, false, query, nil)
    if items == nil then
        tx_failed(context, "teacup search failed")
        return {}
    end
    local filtered = {}
    local needle = lower(query)
    for _, item in ipairs(items) do
        if lower(item.name):find(needle, 1, true) ~= nil then
            filtered[#filtered + 1] = item
        end
    end
    emit_event(context, "searched", filtered)
    return filtered
end

function plugin.info(context, name)
    local target = trim(name or read_field(read_field(context, "request"), "prompt") or "")
    if target == "" then
        return {}
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, "teacup binary not available")
        return {}
    end

    local list_items, list_result = query_list(context, false, target, nil)
    if list_items == nil then
        log_warn(context, "teacup list probe failed during info")
        list_items = {}
    end

    local describe_result = exec_run(context, build_describe_command(target))
    if describe_result == nil or describe_result.success ~= true then
        if #list_items == 0 then
            tx_failed(context, "teacup info failed for " .. target)
            return {}
        end
        log_warn(context, "teacup describe failed; returning list-derived info only")
    end

    local metadata = parse_describe_output(describe_result and describe_result.stdout or "")
    local versions = {}
    local version_seen = {}
    local platforms = {}
    local platform_seen = {}
    for _, item in ipairs(list_items) do
        if not version_seen[item.version] then
            versions[#versions + 1] = item.version
            version_seen[item.version] = true
        end
        if not platform_seen[item.architecture] then
            platforms[#platforms + 1] = item.architecture
            platform_seen[item.architecture] = true
        end
    end

    local version = nil
    if #list_items > 0 then
        version = list_items[1].version
    else
        version = trim((metadata.version or ""):match("^([^%s]+)"))
    end

    local item = {
        name = trim(metadata.name or (#list_items > 0 and list_items[1].name) or target),
        version = version ~= "" and version or nil,
        packageId = (#list_items > 0 and list_items[1].packageId) or target,
        packageType = (#list_items > 0 and list_items[1].packageType) or trim(metadata.entity or ""),
        architecture = (#list_items > 0 and list_items[1].architecture) or nil,
        summary = trim(metadata.summary or ""),
        description = trim(metadata.description or ""),
        extraFields = shallow_copy(metadata),
    }
    if item.summary == "" then
        item.summary = trim((item.description or ""):match("^([^\n]+)"))
    end
    if item.description == "" then
        item.description = nil
    end
    if item.summary == "" then
        item.summary = nil
    end
    if #versions > 0 then
        item.extraFields.versions = table.concat(versions, " ")
    end
    if #platforms > 0 then
        item.extraFields.platforms = table.concat(platforms, " ")
    end
    if list_result ~= nil and list_result.stdout ~= nil and trim(list_result.stdout) ~= "" then
        item.extraFields.listOutput = list_result.stdout
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.shutdown()
    return true
end

return plugin
