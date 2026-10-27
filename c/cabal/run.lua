plugin = {}

local PLUGIN_ID = "cabal"
local PLUGIN_NAME = "Cabal"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "cabal"

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

local function is_safe_token(value)
    return tostring(value or ""):match("^[A-Za-z0-9_./:@%%+=,%-%[%]]+$") ~= nil
end

local function command_quote(value)
    local text = tostring(value or "")
    if is_safe_token(text) then
        return text
    end
    return shell_quote(text)
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

local function parent_dir(path)
    return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
end

local function basename(path)
    local cleaned = trim(path):gsub("[/\\]+$", "")
    return cleaned:match("[^/\\]+$") or cleaned
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
    if os ~= nil and type(os.getenv) == "function" then
        return trim(os.getenv("HOME")) ~= "" and trim(os.getenv("HOME")) or trim(os.getenv("USERPROFILE")) ~= "" and trim(os.getenv("USERPROFILE")) or "/home/test"
    end
    return "/home/test"
end

local function cache_root()
    return join_path(home_dir(), ".cache", "reqpack", "cabal")
end

local function cabal_dir()
    return join_path(cache_root(), "home")
end

local function reqpack_dir()
    return join_path(cabal_dir(), "reqpack")
end

local function installs_db_path()
    return join_path(reqpack_dir(), "installs.tsv")
end

local function library_env_path()
    return join_path(reqpack_dir(), "reqpack.env")
end

local function install_bin_dir()
    return join_path(cache_root(), "bin")
end

local function ensure_directory(path)
    local dir = trim(path)
    if dir == "" or dir == "." then
        return true
    end
    if os == nil or type(os.execute) ~= "function" then
        return false
    end
    local ok, kind, code = os.execute("mkdir -p " .. shell_quote(dir))
    if ok == true then
        return true
    end
    if type(ok) == "number" then
        return ok == 0
    end
    return code == 0 or kind == "exit"
end

local function read_file(context, path)
    if context ~= nil then
        local result = exec_run(context, "cat " .. shell_quote(path))
        if result ~= nil and result.success == true then
            return result.stdout
        end
    end
    local handle = io.open(path, "r")
    if handle == nil then
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(context, path, content)
    local dir = parent_dir(path)
    if context ~= nil and dir ~= nil and dir ~= "" then
        local result = exec_run(context, "mkdir -p " .. shell_quote(dir) .. " && printf %s " .. shell_quote(content) .. " > " .. shell_quote(path))
        return result ~= nil and result.success == true
    end
    local tmp_path = path .. ".tmp"
    if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
        local direct = io.open(path, "w")
        if direct == nil then
            return false
        end
        direct:write(content)
        direct:close()
        return true
    end
    local handle = io.open(tmp_path, "w")
    if handle == nil then
        local direct = io.open(path, "w")
        if direct == nil then
            return false
        end
        direct:write(content)
        direct:close()
        return true
    end
    handle:write(content)
    handle:close()
    if os == nil or type(os.remove) ~= "function" or type(os.rename) ~= "function" then
        local direct = io.open(path, "w")
        if direct == nil then
            return false
        end
        direct:write(content)
        direct:close()
        return true
    end
    os.remove(path)
    local ok = os.rename(tmp_path, path)
    if not ok then
        local direct = io.open(path, "w")
        if direct == nil then
            os.remove(tmp_path)
            return false
        end
        local tmp_handle = io.open(tmp_path, "r")
        if tmp_handle ~= nil then
            direct:write(tmp_handle:read("*a") or "")
            tmp_handle:close()
        else
            direct:write(content)
        end
        direct:close()
        os.remove(tmp_path)
        return true
    end
    return true
end

local function path_exists(context, path)
    local result = exec_run(context, "test -e " .. shell_quote(path))
    return result ~= nil and result.success == true
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function object_flags(object)
    local value = read_field(object, "flags")
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local flags = {}
    local ok = pcall(function()
        for _, item in ipairs(value) do
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
    local function append_from(object)
        for _, flag in ipairs(object_flags(object)) do
            if not seen[flag] then
                seen[flag] = true
                flags[#flags + 1] = flag
            end
        end
    end
    append_from(context)
    append_from(read_field(context, "request"))
    append_from(package)
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
    return nil
end

local function package_name(pkg)
    return trim(read_field(pkg, "name"))
end

local function package_version(pkg)
    return trim(read_field(pkg, "version"))
end

local function package_action(pkg)
    return lower(read_field(pkg, "action"))
end

local function package_kind(context, pkg)
    local flags = collect_flags(context, pkg)
    local explicit = lower(first_nonempty(flag_value(flags, "kind"), flag_value(flags, "type"), read_field(pkg, "kind"), read_field(pkg, "packageType"), read_field(pkg, "type")))
    if explicit == "library" or explicit == "lib" then
        return "library"
    end
    return "executable"
end

function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil then
            if type(value) == "string" then
                local text = trim(value)
                if text ~= "" then
                    return text
                end
            else
                return value
            end
        end
    end
    return nil
end

local function request_packages(context, packages)
    if type(packages) == "table" or type(packages) == "userdata" then
        return packages
    end
    local request = read_field(context, "request")
    local request_packages_value = read_field(request, "packages")
    if type(request_packages_value) == "table" or type(request_packages_value) == "userdata" then
        return request_packages_value
    end
    return {}
end

local function info_prompt(context, name)
    return first_nonempty(name, read_field(context, "prompt"), read_field(read_field(context, "request"), "prompt")) or ""
end

local function package_selector(pkg)
    local name = package_name(pkg)
    local version = package_version(pkg)
    if name == "" then
        return ""
    end
    if version ~= "" and name:find("/", 1, true) == nil and name:find("@", 1, true) == nil then
        return name .. "-" .. version
    end
    return name
end

local function env_prefix()
    return "CABAL_DIR=" .. shell_quote(cabal_dir()) .. " NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C'"
end

local function cabal_command(parts)
    local items = { env_prefix(), REQUIRED_BINARY }
    for _, part in ipairs(parts or {}) do
        local cleaned = trim(part)
        if cleaned ~= "" then
            items[#items + 1] = command_quote(cleaned)
        end
    end
    return table.concat(items, " ")
end

local function compare_versions(left, right)
    local a = trim(left)
    local b = trim(right)
    if a == b then
        return 0
    end

    local a_parts = {}
    for part in a:gmatch("[^%.%-_]+") do
        a_parts[#a_parts + 1] = part
    end
    local b_parts = {}
    for part in b:gmatch("[^%.%-_]+") do
        b_parts[#b_parts + 1] = part
    end
    local max_len = #a_parts > #b_parts and #a_parts or #b_parts
    for index = 1, max_len do
        local left_part = a_parts[index] or "0"
        local right_part = b_parts[index] or "0"
        local left_num = tonumber(left_part)
        local right_num = tonumber(right_part)
        if left_num ~= nil and right_num ~= nil then
            if left_num < right_num then
                return -1
            elseif left_num > right_num then
                return 1
            end
        else
            if left_part < right_part then
                return -1
            elseif left_part > right_part then
                return 1
            end
        end
    end
    if a < b then
        return -1
    end
    return 1
end

local function sort_items(items)
    table.sort(items, function(left, right)
        local left_name = lower(left.name)
        local right_name = lower(right.name)
        if left_name == right_name then
            return lower(left.version or "") < lower(right.version or "")
        end
        return left_name < right_name
    end)
end

local function parse_installs_db(context)
    local entries = {}
    local content = read_file(context, installs_db_path())
    if content == nil or content == "" then
        return entries
    end
    for _, line in ipairs(split_lines(content)) do
        if trim(line) ~= "" then
            local fields = {}
            for field in (line .. "\t"):gmatch("(.-)\t") do
                fields[#fields + 1] = field
            end
            entries[#entries + 1] = {
                kind = trim(fields[1]),
                name = trim(fields[2]),
                version = trim(fields[3]),
                packageId = trim(fields[4]),
                binaryName = trim(fields[5]),
                localTarget = trim(fields[6]) == "true",
                target = trim(fields[7]),
            }
        end
    end
    return entries
end

local function save_installs_db(context, entries)
    ensure_directory(reqpack_dir())
    local lines = {}
    for _, entry in ipairs(entries or {}) do
        lines[#lines + 1] = table.concat({
            trim(entry.kind),
            trim(entry.name),
            trim(entry.version),
            trim(entry.packageId),
            trim(entry.binaryName),
            entry.localTarget and "true" or "false",
            trim(entry.target),
        }, "\t")
    end
    return write_file(context, installs_db_path(), table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
end

local function find_entry(entries, kind, name)
    for index, entry in ipairs(entries or {}) do
        if lower(entry.kind) == lower(kind) and lower(entry.name) == lower(name) then
            return entry, index
        end
    end
    return nil, nil
end

local function upsert_entry(entry)
    local entries = parse_installs_db(entry._context)
    local _, index = find_entry(entries, entry.kind, entry.name)
    if index ~= nil then
        entries[index] = entry
    else
        entries[#entries + 1] = entry
    end
    return save_installs_db(entry._context, entries)
end

local function remove_entry(context, kind, name)
    local entries = parse_installs_db(context)
    local kept = {}
    for _, entry in ipairs(entries) do
        if not (lower(entry.kind) == lower(kind) and lower(entry.name) == lower(name)) then
            kept[#kept + 1] = entry
        end
    end
    return save_installs_db(context, kept)
end

local function library_entries(context)
    local items = {}
    for _, entry in ipairs(parse_installs_db(context)) do
        if entry.kind == "library" then
            items[#items + 1] = entry
        end
    end
    return items
end

local function install_command(selector)
    return cabal_command({ "install", selector, "--installdir=" .. install_bin_dir(), "--install-method=copy", "--overwrite-policy=always" })
end

local function install_library_command(selector)
    return cabal_command({ "install", "--lib", selector, "--package-env", library_env_path() })
end

local function cabal_update_command()
    return cabal_command({ "update" })
end

local function cabal_search_command(prompt)
    return cabal_command({ "list", "--simple-output", prompt })
end

local function cabal_info_command(name)
    return cabal_command({ "info", name })
end

local function latest_remote_version(context, name)
    local result = exec_run(context, cabal_search_command(name))
    if result == nil or result.success ~= true then
        return nil
    end
    local latest = nil
    for _, line in ipairs(split_lines(result.stdout)) do
        local item_name, item_version = line:match("^(%S+)%s+(%S+)%s*$")
        if item_name ~= nil and item_version ~= nil and lower(item_name) == lower(name) then
            if latest == nil or compare_versions(item_version, latest) > 0 then
                latest = item_version
            end
        end
    end
    return latest
end

local function parse_info(stdout)
    local item = {}
    local current_key = nil
    for _, line in ipairs(split_lines(stdout)) do
        local name, kind = line:match("^%*%s+(%S+)%s+%(([^)]+)%)")
        if name ~= nil then
            item.name = trim(name)
            item.packageId = trim(name)
            item.packageType = lower(kind) == "library" and "library" or "executable"
        else
            local key, value = line:match("^%s+([^:]+):%s*(.-)%s*$")
            if key ~= nil then
                current_key = lower(trim(key))
                item[current_key] = trim(value)
            elseif current_key ~= nil and line:match("^%s+") ~= nil then
                local extra = trim(line)
                if extra ~= "" then
                    item[current_key] = trim((item[current_key] or "") .. " " .. extra)
                end
            end
        end
    end

    local summary = first_nonempty(item.synopsis, item.description)
    local latest = nil
    if item["versions available"] ~= nil then
        for version in tostring(item["versions available"]):gmatch("[%w%.%-_]+") do
            if version ~= "and" and version ~= "others" and version:match("%d") then
                if latest == nil or compare_versions(version, latest) > 0 then
                    latest = version
                end
            end
        end
    end

    local installed_version = nil
    if item["versions installed"] ~= nil then
        for version in tostring(item["versions installed"]):gmatch("[%w%.%-_]+") do
            if lower(version) ~= "not" and lower(version) ~= "installed" then
                if installed_version == nil or compare_versions(version, installed_version) > 0 then
                    installed_version = version
                end
            end
        end
    end

    return {
        name = item.name,
        packageId = item.packageId or item.name,
        version = installed_version,
        latestVersion = latest,
        summary = summary,
        description = item.description,
        homepage = item.homepage,
        license = item.license,
        author = item.author,
        maintainer = item.maintainer,
        category = item.category,
        packageType = item.packageType or "executable",
        installed = installed_version ~= nil,
        status = installed_version ~= nil and "installed" or "available",
    }
end

local function refresh_index(context)
    exec_run(context, cabal_update_command())
end

local function rebuild_library_environment(context)
    local env_path = library_env_path()
    ensure_directory(parent_dir(env_path))
    if os ~= nil and type(os.remove) == "function" then
        os.remove(env_path)
    end
    for _, entry in ipairs(library_entries(context)) do
        local selector = trim(entry.packageId) ~= "" and entry.packageId or entry.name
        local result = exec_run(context, install_library_command(selector))
        if result == nil or result.success ~= true then
            return false, first_nonempty(result and result.stderr, result and result.stdout, "cabal library install failed")
        end
    end
    return true
end

local function item_from_entry(entry)
    return {
        name = entry.name,
        packageId = entry.packageId ~= "" and entry.packageId or entry.name,
        version = entry.version ~= "" and entry.version or nil,
        latestVersion = entry.version ~= "" and entry.version or nil,
        installed = true,
        status = "installed",
        packageType = entry.kind == "library" and "library" or "executable",
        extraFields = {
            binaryName = entry.binaryName ~= "" and entry.binaryName or nil,
            localTarget = entry.localTarget == true or nil,
            target = entry.target ~= "" and entry.target or nil,
        },
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
    return { "Haskell", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    local installed = parse_installs_db(nil)
    local missing = {}
    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        local kind = package_kind(nil, pkg)
        local version = package_version(pkg)
        local action = package_action(pkg)
        local entry = select(1, find_entry(installed, kind, name))
        if name ~= "" then
            if action == "remove" then
                if entry ~= nil then
                    missing[#missing + 1] = pkg
                end
            elseif action == "update" then
                if entry ~= nil then
                    missing[#missing + 1] = pkg
                end
            elseif entry == nil then
                missing[#missing + 1] = pkg
            elseif version ~= "" and trim(entry.version) ~= version then
                missing[#missing + 1] = pkg
            end
        end
    end
    return missing
end

function plugin.install(context, packages)
    local requested = request_packages(context, packages)
    local local_path = first_nonempty(read_field(read_field(context, "request"), "localPath"), read_field(read_field(context, "request"), "path")) or ""
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end
    ensure_directory(install_bin_dir())
    ensure_directory(reqpack_dir())
    refresh_index(context)

    begin_step(context, "install cabal packages")
    local installed = {}
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        local selector = package_selector(pkg)
        local kind = package_kind(context, pkg)
        if name == "" or selector == "" then
            tx_failed(context, "cabal package name missing")
            return false
        end

        local result
        if kind == "library" then
            result = exec_run(context, install_library_command(selector))
        else
            result = exec_run(context, install_command(selector))
        end
        if result == nil or result.success ~= true then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "cabal install failed"))
            return false
        end

        local version = package_version(pkg)
        if version == "" then
            version = latest_remote_version(context, name) or ""
        end
        local entry = {
            kind = kind,
            name = name,
            version = version,
            packageId = selector,
            binaryName = kind == "library" and "" or name,
            localTarget = false,
            target = selector,
        }
        entry._context = context
        if not upsert_entry(entry) then
            tx_failed(context, "cabal metadata write failed")
            return false
        end
        entry._context = nil
        installed[#installed + 1] = item_from_entry(entry)
    end

    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = first_nonempty(path, read_field(read_field(context, "request"), "localPath"), read_field(read_field(context, "request"), "path")) or ""
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end
    begin_step(context, "install local cabal package")
    if local_path == "" or not path_exists(context, local_path) then
        tx_failed(context, "cabal local install path missing")
        return false
    end

    local pkg = request_packages(context, nil)[1]
    local kind = package_kind(context, pkg)
    local result
    if kind == "library" then
        result = exec_run(context, install_library_command(local_path))
    else
        result = exec_run(context, install_command(local_path))
    end
    if result == nil or result.success ~= true then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "cabal local install failed"))
        return false
    end

    local entry = {
        kind = kind,
        name = package_name(pkg) ~= "" and package_name(pkg) or basename(local_path),
        version = package_version(pkg),
        packageId = local_path,
        binaryName = kind == "library" and "" or basename(local_path),
        localTarget = true,
        target = local_path,
    }
    entry._context = context
    if not upsert_entry(entry) then
        tx_failed(context, "cabal metadata write failed")
        return false
    end
    entry._context = nil
    emit_event(context, "installed", { path = local_path, localTarget = true, name = entry.name })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = request_packages(context, packages)
    if #requested == 0 then
        return true
    end

    begin_step(context, "remove cabal packages")
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        local kind = package_kind(context, pkg)
        local entry = select(1, find_entry(parse_installs_db(context), kind, name))
        if entry ~= nil then
            if kind == "library" then
                if not remove_entry(context, kind, name) then
                    tx_failed(context, "cabal metadata write failed")
                    return false
                end
                if command_exists(context, REQUIRED_BINARY) then
                    local ok, err = rebuild_library_environment(context)
                    if not ok then
                        tx_failed(context, err)
                        return false
                    end
                end
            else
                local binary_name = first_nonempty(entry.binaryName, name)
                local binary_path = join_path(install_bin_dir(), binary_name)
                if os ~= nil and type(os.remove) == "function" then
                    os.remove(binary_path)
                end
                if not remove_entry(context, kind, name) then
                    tx_failed(context, "cabal metadata write failed")
                    return false
                end
            end
        end
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = request_packages(context, packages)
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        tx_failed(context, REQUIRED_BINARY .. " binary not available")
        return false
    end
    refresh_index(context)

    begin_step(context, "update cabal packages")
    local updated = {}
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        local selector = package_selector(pkg)
        local kind = package_kind(context, pkg)
        local result
        if kind == "library" then
            result = exec_run(context, install_library_command(selector))
        else
            result = exec_run(context, install_command(selector))
        end
        if result == nil or result.success ~= true then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "cabal update failed"))
            return false
        end
        local version = package_version(pkg)
        if version == "" then
            version = latest_remote_version(context, name) or ""
        end
        local entry = {
            kind = kind,
            name = name,
            version = version,
            packageId = selector,
            binaryName = kind == "library" and "" or name,
            localTarget = false,
            target = selector,
        }
        entry._context = context
        if not upsert_entry(entry) then
            tx_failed(context, "cabal metadata write failed")
            return false
        end
        entry._context = nil
        updated[#updated + 1] = item_from_entry(entry)
    end

    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = {}
    for _, entry in ipairs(parse_installs_db(context)) do
        items[#items + 1] = item_from_entry(entry)
    end
    sort_items(items)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local entries = parse_installs_db(context)
    if #entries == 0 then
        emit_event(context, "outdated", {})
        return {}
    end
    if not command_exists(context, REQUIRED_BINARY) then
        log_warn(context, REQUIRED_BINARY .. " binary not available")
        emit_event(context, "outdated", {})
        return {}
    end

    local items = {}
    for _, entry in ipairs(entries) do
        if entry.version ~= "" then
            local latest = latest_remote_version(context, entry.name)
            if latest ~= nil and compare_versions(entry.version, latest) < 0 then
                local item = item_from_entry(entry)
                item.latestVersion = latest
                items[#items + 1] = item
            end
        end
    end
    sort_items(items)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned = trim(prompt)
    if cleaned == "" then
        emit_event(context, "searched", {})
        return {}
    end
    if not command_exists(context, REQUIRED_BINARY) then
        log_warn(context, REQUIRED_BINARY .. " binary not available")
        emit_event(context, "searched", {})
        return {}
    end

    refresh_index(context)
    local result = exec_run(context, cabal_search_command(cleaned))
    if result == nil or result.success ~= true then
        log_warn(context, first_nonempty(result and result.stderr, result and result.stdout, "cabal search failed"))
        emit_event(context, "searched", {})
        return {}
    end

    local grouped = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local name, version = line:match("^(%S+)%s+(%S+)%s*$")
        if name ~= nil and version ~= nil then
            if grouped[name] == nil or compare_versions(version, grouped[name].latestVersion or "") > 0 then
                grouped[name] = {
                    name = name,
                    packageId = name,
                    version = version,
                    latestVersion = version,
                    installed = false,
                    status = "available",
                    packageType = "executable",
                }
            end
        end
    end

    local items = {}
    for _, item in pairs(grouped) do
        items[#items + 1] = item
    end
    sort_items(items)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local cleaned = info_prompt(context, name)
    if cleaned == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local installed_entry = nil
    for _, entry in ipairs(parse_installs_db(context)) do
        if lower(entry.name) == lower(cleaned) then
            installed_entry = entry
            break
        end
    end

    if not command_exists(context, REQUIRED_BINARY) then
        local item = installed_entry ~= nil and item_from_entry(installed_entry) or {}
        emit_event(context, "informed", item)
        return item
    end

    local result = exec_run(context, cabal_info_command(cleaned))
    local remote = nil
    if result ~= nil and result.success == true then
        remote = parse_info(result.stdout)
    end

    if installed_entry == nil and (remote == nil or remote.name == nil) then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local item = installed_entry ~= nil and item_from_entry(installed_entry) or {}
    if remote ~= nil then
        for key, value in pairs(remote) do
            if value ~= nil and value ~= "" then
                item[key] = value
            end
        end
    end
    if installed_entry ~= nil then
        item.installed = true
        item.status = "installed"
        if trim(item.version) == "" then
            item.version = installed_entry.version ~= "" and installed_entry.version or nil
        end
        if installed_entry.kind == "library" then
            item.packageType = "library"
        end
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.init()
    return command_exists(nil, REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "haskell", "cabal", "hackage" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".cache/reqpack/cabal" },
        },
        networkScopes = {
            { host = "hackage.haskell.org", scheme = "https", pathPrefix = "/" },
        },
        privilegeLevel = "user",
        purlType = "hackage",
    }
end

return plugin
