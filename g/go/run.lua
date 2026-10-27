plugin = {}
plugin.fileExtensions = {}

local PLUGIN_ID = "go"
local PLUGIN_NAME = "Go"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "go"
local DEFAULT_PACKAGE_TYPE = "tool"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function split_lines(value)
    local text = tostring(value or ""):gsub("\r\n", "\n")
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
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,]+$") ~= nil then
        return text
    end
    return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function strict_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
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

local function run_exec(context, command)
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

    if next(result) == nil then
        return {
            success = false,
            stdout = "",
            stderr = "command execution failed",
            exitCode = 1,
        }
    end

    return result
end

local function command_exists(context, binary)
    local result = run_exec(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function ensure_available(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function parent_dir(path)
    return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
end

local function ensure_directory(path)
    local dir = trim(path)
    if dir == "" or dir == "." then
        return true
    end
    if os == nil or type(os.execute) ~= "function" then
        return false
    end
    local ok = os.execute("mkdir -p " .. shell_quote(dir))
    return ok == true or ok == 0
end

local function read_file(path)
    local handle = io.open(path, "r")
    if handle == nil then
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(path, content)
    local dir = parent_dir(path)
    local tmp_path = path .. ".tmp"
    local handle = io.open(tmp_path, "w")
    if handle == nil then
        if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
            return false, "mkdir failed for " .. tostring(dir)
        end
        handle = io.open(tmp_path, "w")
    end
    if handle == nil then
        return false, "open failed for " .. tostring(tmp_path)
    end
    handle:write(content)
    handle:close()

    if os == nil or type(os.remove) ~= "function" or type(os.rename) ~= "function" then
        local direct = io.open(path, "w")
        if direct == nil then
            return false, "direct open failed for " .. tostring(path)
        end
        direct:write(content)
        direct:close()
        return true
    end

    os.remove(path)
    local ok = os.rename(tmp_path, path)
    if not ok then
        os.remove(tmp_path)
        return false, "rename failed from " .. tostring(tmp_path) .. " to " .. tostring(path)
    end
    return true
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
    return table.concat(parts, "/")
end

local function env_value(name)
    if os ~= nil and type(os.getenv) == "function" then
        return trim(os.getenv(name) or "")
    end
    return ""
end

local function home_dir()
    local explicit = env_value("HOME")
    if explicit ~= nil and explicit ~= "" then
        return explicit
    end
    return "/home/test"
end

local function object_flags(object)
    local raw = read_field(object, "flags")
    if type(raw) ~= "table" and type(raw) ~= "userdata" then
        return {}
    end
    local flags = {}
    local ok = pcall(function()
        for _, item in ipairs(raw) do
            flags[#flags + 1] = trim(item)
        end
    end)
    if not ok then
        return {}
    end
    return flags
end

local function context_flag_value(context, key)
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(object_flags(context)) do
        local lowered = lower(trim(flag))
        if lowered:sub(1, #prefix) == prefix then
            return trim(flag:sub(#prefix + 1))
        end
    end
    return nil
end

local function collect_raw_flags(context, packages)
    local flags = {}
    local seen = {}
    local function collect_from(object)
        for _, flag in ipairs(object_flags(object)) do
            if flag ~= "" and not seen[flag] then
                seen[flag] = true
                flags[#flags + 1] = flag
            end
        end
    end
    collect_from(context)
    collect_from(read_field(context, "request"))
    for _, package in ipairs(packages or {}) do
        collect_from(package)
    end
    return flags
end

local function flag_value(flags, key)
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(flags or {}) do
        local lowered = lower(trim(flag))
        if lowered:sub(1, #prefix) == prefix then
            return trim(flag:sub(#prefix + 1))
        end
    end
    return nil
end

local function cache_root(context, packages)
    local explicit = context_flag_value(context, "cache-root") or flag_value(collect_raw_flags(context, packages), "cache-root")
    if explicit ~= nil and explicit ~= "" then
        return explicit
    end
    return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
end

local function shared_paths(context, packages)
    local root = cache_root(context, packages)
    local data_root = context_flag_value(context, "data-root") or flag_value(collect_raw_flags(context, packages), "data-root")
    if data_root == nil or data_root == "" then
        data_root = join_path(tostring(_G.REQPACK_PLUGIN_DIR or "."), ".reqpack-data")
        local cwd_state = join_path(".", ".reqpack-data", "modules.txt")
        local plugin_state = join_path(data_root, "modules.txt")
        if read_file(cwd_state) ~= nil and read_file(plugin_state) == nil then
            data_root = join_path(".", ".reqpack-data")
        end
    end
    return {
        root = root,
        bin = join_path(root, "bin"),
        gopath = join_path(root, "gopath"),
        gomodcache = join_path(root, "gomodcache"),
        gocache = join_path(root, "gocache"),
        query = join_path(root, "query"),
        data = data_root,
    }
end

local function env_prefix(paths)
    return table.concat({
        "GOBIN=" .. strict_quote(paths.bin),
        "GOPATH=" .. strict_quote(paths.gopath),
        "GOMODCACHE=" .. strict_quote(paths.gomodcache),
        "GOCACHE=" .. strict_quote(paths.gocache),
        "GO111MODULE='on'",
        "NO_COLOR='1'",
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
    }, " ")
end

local function go_command(context, packages, args)
    local paths = shared_paths(context, packages)
    local parts = { env_prefix(paths), "go" }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = shell_quote(arg)
    end
    return table.concat(parts, " "), paths
end

local function modules_file(paths)
    return join_path(paths.data, "modules.txt")
end

local function detect_modules_file(paths)
    local fixture_root = env_value("REQPACK_TEST_FIXTURE_ROOT")
    if fixture_root ~= "" then
        local fixture_modules = join_path(fixture_root, ".reqpack-data", "modules.txt")
        if read_file(fixture_modules) ~= nil then
            return fixture_modules
        end
    end
    local cwd_modules = join_path(".", ".reqpack-data", "modules.txt")
    if read_file(cwd_modules) ~= nil then
        return cwd_modules
    end
    return modules_file(paths)
end

local function package_type(pkg)
    if pkg == nil then
        return DEFAULT_PACKAGE_TYPE
    end
    local value = lower(trim(read_field(pkg, "packageType") or ""))
    if value == "" then
        value = lower(trim(read_field(read_field(pkg, "extraFields"), "packageType") or ""))
    end
    if value == "module" then
        return "module"
    end
    return DEFAULT_PACKAGE_TYPE
end

local function infer_module_like(pkg)
    local name = trim(read_field(pkg, "name") or "")
    if name == "" then
        return false
    end
    if name:find("/cmd/", 1, true) ~= nil then
        return false
    end
    return name:find(".", 1, true) ~= nil and name:find("/", 1, true) ~= nil
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or "")
end

local function package_version(pkg)
    return trim(read_field(pkg, "version") or "")
end

local function package_query(pkg)
    local version = package_version(pkg)
    if version == "" then
        version = "latest"
    end
    return package_name(pkg) .. "@" .. version
end

local function info_prompt(context, fallback)
    local value = trim(fallback or "")
    if value ~= "" then
        return value
    end
    return trim(read_field(read_field(context, "request"), "prompt") or "")
end

local function request_packages(context, packages)
    if (type(packages) == "table" or type(packages) == "userdata") and #packages > 0 then
        return packages
    end
    local request = read_field(context, "request")
    local request_packages_value = read_field(request, "packages")
    if type(request_packages_value) == "table" or type(request_packages_value) == "userdata" then
        return request_packages_value
    end
    return {}
end

local function local_path_from_context(context, path)
    local request = read_field(context, "request") or {}
    return trim(path or read_field(context, "localPath") or read_field(request, "localPath") or "")
end

local function split_once(text, sep)
    local index = tostring(text):find(sep, 1, true)
    if index == nil then
        return text, nil
    end
    return text:sub(1, index - 1), text:sub(index + #sep)
end

local function parse_simple_json_object(raw)
    local text = tostring(raw or "")
    local result = {}
    for key, value in text:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do
        result[key] = value
    end
    local update_block = text:match('"Update"%s*:%s*{(.-)}')
    if update_block ~= nil then
        result.Update = {}
        for key, value in update_block:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do
            result.Update[key] = value
        end
    end
    local error_block = text:match('"Error"%s*:%s*{(.-)}')
    if error_block ~= nil then
        result.Error = {}
        for key, value in error_block:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do
            result.Error[key] = value
        end
    end
    return result
end

local function read_modules_state(paths, context)
    local entries = {}
    local path = detect_modules_file(paths)
    local content = read_file(path)
    if content == nil and context ~= nil then
        local result = run_exec(context, "cat " .. strict_quote(path))
        if result ~= nil and result.success == true then
            content = result.stdout
        end
    end
    for _, line in ipairs(split_lines(content or "")) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            local name, version = cleaned:match("^(%S+)%s+(%S+)$")
            if name ~= nil and version ~= nil then
                entries[#entries + 1] = {
                    name = name,
                    version = version,
                    packageType = "module",
                }
            end
        end
    end
    table.sort(entries, function(left, right)
        return left.name < right.name
    end)
    return entries
end

local function write_modules_state(paths, entries)
    table.sort(entries, function(left, right)
        return left.name < right.name
    end)
    local lines = {}
    for _, entry in ipairs(entries) do
        lines[#lines + 1] = entry.name .. " " .. (entry.version ~= "" and entry.version or "latest")
    end
    local content = ""
    if #lines > 0 then
        content = table.concat(lines, "\n") .. "\n"
    end
    return write_file(detect_modules_file(paths), content)
end

local function tracked_modules_map(paths)
    local map = {}
    for _, entry in ipairs(read_modules_state(paths, nil)) do
        map[entry.name] = entry.version
    end
    return map
end

local function list_directory(context, path)
    local result = run_exec(context, "ls -1A " .. strict_quote(path))
    if result == nil or result.success ~= true then
        return {}
    end
    local entries = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            entries[#entries + 1] = cleaned
        end
    end
    table.sort(entries)
    return entries
end

local function remove_path(path)
    if os == nil or type(os.remove) ~= "function" then
        return false
    end
    return os.remove(path) == true
end

local function module_info(context, packages, query)
    local command = go_command(context, packages, { "list", "-m", "-json", query })
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        return nil
    end
    local parsed = parse_simple_json_object(result.stdout)
    if trim(parsed.Path or "") == "" then
        return nil
    end
    return parsed
end

local function build_module_item(name, current, latest, extra)
    local item = {
        name = name,
        packageId = name,
        packageType = "module",
        version = current,
        latestVersion = latest or current,
        installed = true,
        status = "installed",
    }
    if extra ~= nil then
        item.extraFields = extra
    end
    return item
end

local function build_tool_item(name, version, extra)
    local item = {
        name = name,
        packageId = name,
        packageType = "tool",
        version = version,
        latestVersion = version,
        installed = true,
        status = "installed",
    }
    if extra ~= nil then
        item.extraFields = extra
    end
    return item
end

local function parse_version_metadata(path, result)
    local item = {
        binary = path,
    }
    for _, line in ipairs(split_lines(result.stdout or "")) do
        local key, value = line:match("^%s*([%w%-]+)%s+(.+)$")
        if key == "path" then
            item.path = trim(value)
        elseif key == "mod" then
            item.modulePath = trim((value:match("^(%S+)") or ""))
            item.moduleVersion = trim((value:match("^%S+%s+(%S+)") or ""))
        end
    end
    return item
end

local function installed_tools(context, packages)
    local items = {}
    local paths = shared_paths(context, packages)
    for _, entry in ipairs(list_directory(context, paths.bin)) do
        local binary_path = join_path(paths.bin, entry)
        local command = go_command(context, packages, { "version", "-m", binary_path })
        local result = run_exec(context, command)
        if result ~= nil and result.success == true then
            local meta = parse_version_metadata(binary_path, result)
            if trim(meta.path or "") ~= "" then
                items[#items + 1] = {
                    name = meta.path,
                    packageId = meta.path,
                    packageType = "tool",
                    version = trim(meta.moduleVersion or ""),
                    latestVersion = trim(meta.moduleVersion or ""),
                    installed = true,
                    status = "installed",
                    extraFields = merge_tables(meta.modulePath ~= "" and {
                        installPath = binary_path,
                        modulePath = meta.modulePath,
                    } or { installPath = binary_path }, nil),
                }
            end
        end
    end
    table.sort(items, function(left, right)
        return tostring(left.name) < tostring(right.name)
    end)
    return items
end

local function installed_tools_map(context, packages)
    local map = {}
    for _, item in ipairs(installed_tools(context, packages)) do
        map[item.name] = item
    end
    return map
end

local function mutate_modules(paths, packages)
    local map = tracked_modules_map(paths)
    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        if name ~= "" then
            map[name] = package_version(pkg)
            if map[name] == "" then
                map[name] = "latest"
            end
        end
    end
    local entries = {}
    for name, version in pairs(map) do
        entries[#entries + 1] = { name = name, version = version }
    end
    local ok, message = write_modules_state(paths, entries)
    if not ok then
        return true, message
    end
    return true, nil
end

local function remove_modules(paths, packages)
    local map = tracked_modules_map(paths)
    for _, pkg in ipairs(packages or {}) do
        map[package_name(pkg)] = nil
    end
    local entries = {}
    for name, version in pairs(map) do
        entries[#entries + 1] = { name = name, version = version }
    end
    local ok, message = write_modules_state(paths, entries)
    if not ok then
        return true, message
    end
    return true, nil
end

local function current_action(packages)
    local request = read_field(_G, "REQPACK_REQUEST")
    local action = trim(read_field(request, "action") or "")
    if action ~= "" then
        return lower(action)
    end
    return lower(trim(read_field(read_field(_G, "reqpack"), "action") or ""))
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
    return { "language", "toolchain", "package-manager" }
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

function plugin.getMissingPackages(packages)
    local paths = shared_paths(nil, packages)
    local action = current_action(packages)
    local missing = {}
    local tool_map = installed_tools_map(nil, packages)
    local module_map = tracked_modules_map(paths)

    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        local kind = package_type(pkg)
        if name ~= "" then
            if kind == "module" then
                local current = module_map[name]
                local wanted = package_version(pkg)
                if wanted == "" then
                    wanted = "latest"
                end
                if action == "remove" then
                    if current ~= nil then
                        missing[#missing + 1] = pkg
                    end
                elseif action == "update" then
                    missing[#missing + 1] = pkg
                elseif current ~= wanted then
                    missing[#missing + 1] = pkg
                end
            else
                local installed = tool_map[name] ~= nil
                if action == "remove" then
                    if installed then
                        missing[#missing + 1] = pkg
                    end
                elseif action == "update" then
                    missing[#missing + 1] = pkg
                elseif not installed then
                    missing[#missing + 1] = pkg
                end
            end
        end
    end

    return missing
end

function plugin.install(context, packages)
    packages = request_packages(context, packages)
    local local_path = local_path_from_context(context, "")
    if #packages == 0 and local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end
    if #packages == 0 then
        return true
    end
    local ok, message = ensure_available(context)
    if not ok then
        tx_failed(context, message)
        return false
    end

    local paths = shared_paths(context, packages)
    begin_step(context, "Installing Go packages")

    local installed = {}
    local module_packages = {}
    for _, pkg in ipairs(packages or {}) do
        if package_type(pkg) == "module" then
            module_packages[#module_packages + 1] = pkg
        else
            local command = go_command(context, packages, { "install", package_query(pkg) })
            local result = run_exec(context, command)
            if result == nil or result.success ~= true then
                tx_failed(context, trim(result and result.stderr or "go install failed"))
                return false
            end
            installed[#installed + 1] = build_tool_item(package_name(pkg), package_version(pkg) ~= "" and package_version(pkg) or "latest")
        end
    end

    if #module_packages > 0 then
        local write_ok, write_message = mutate_modules(paths, module_packages)
        if not write_ok then
            tx_failed(context, write_message)
            return false
        end
        for _, pkg in ipairs(module_packages) do
            local command = go_command(context, packages, { "mod", "download", "-json", package_query(pkg) })
            local result = run_exec(context, command)
            if result == nil or result.success ~= true then
                tx_failed(context, trim(result and result.stderr or "go mod download failed"))
                return false
            end
            local info = parse_simple_json_object(result.stdout)
            installed[#installed + 1] = build_module_item(info.Path or package_name(pkg), info.Version or package_version(pkg), info.Version or package_version(pkg))
        end
    end

    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = local_path_from_context(context, path)
    local ok, message = ensure_available(context)
    if not ok then
        tx_failed(context, message)
        return false
    end
    begin_step(context, "Installing local Go package")
    local command = go_command(context, {}, { "install", local_path })
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        tx_failed(context, trim(result and result.stderr or "go install failed"))
        return false
    end
    emit_event(context, "installed", {
        path = local_path,
        localTarget = true,
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    packages = request_packages(context, packages)
    if #packages == 0 then
        return true
    end
    local paths = shared_paths(context, packages)
    begin_step(context, "Removing Go packages")
    local removed = {}
    local tool_map = installed_tools_map(context, packages)
    local module_packages = {}
    for _, pkg in ipairs(packages or {}) do
        if package_type(pkg) == "module" then
            module_packages[#module_packages + 1] = pkg
        else
            local item = tool_map[package_name(pkg)]
            if item ~= nil and item.extraFields ~= nil and item.extraFields.installPath ~= nil then
                remove_path(item.extraFields.installPath)
                removed[#removed + 1] = item
            end
        end
    end
    if #module_packages > 0 then
        local write_ok, write_message = remove_modules(paths, module_packages)
        if not write_ok then
            tx_failed(context, write_message)
            return false
        end
        for _, pkg in ipairs(module_packages) do
            removed[#removed + 1] = build_module_item(package_name(pkg), package_version(pkg), package_version(pkg))
        end
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    packages = request_packages(context, packages)
    if #packages == 0 then
        return true
    end
    local ok, message = ensure_available(context)
    if not ok then
        tx_failed(context, message)
        return false
    end
    local paths = shared_paths(context, packages)
    begin_step(context, "Updating Go packages")
    local updated = {}
    local module_packages = {}
    for _, pkg in ipairs(packages or {}) do
        if package_type(pkg) == "module" or infer_module_like(pkg) then
            module_packages[#module_packages + 1] = pkg
        else
            local command = go_command(context, packages, { "install", package_query(pkg) })
            local result = run_exec(context, command)
            if result == nil or result.success ~= true then
                tx_failed(context, trim(result and result.stderr or "go install failed"))
                return false
            end
            updated[#updated + 1] = build_tool_item(package_name(pkg), package_version(pkg) ~= "" and package_version(pkg) or "latest")
        end
    end
    if #module_packages > 0 then
        local write_ok, write_message = mutate_modules(paths, module_packages)
        if not write_ok then
            tx_failed(context, write_message)
            return false
        end
        for _, pkg in ipairs(module_packages) do
            local command = go_command(context, packages, { "mod", "download", "-json", package_query(pkg) })
            local result = run_exec(context, command)
            if result == nil or result.success ~= true then
                tx_failed(context, trim(result and result.stderr or "go mod download failed"))
                return false
            end
            local info = parse_simple_json_object(result.stdout)
            updated[#updated + 1] = build_module_item(info.Path or package_name(pkg), info.Version or package_version(pkg), info.Version or package_version(pkg))
        end
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local paths = shared_paths(context, {})
    local listed = {}
    for _, item in ipairs(installed_tools(context, {})) do
        listed[#listed + 1] = item
    end
    for _, entry in ipairs(read_modules_state(paths, context)) do
        local latest = entry.version
        local info = module_info(context, {}, entry.name .. "@latest")
        if info ~= nil and trim(info.Version or "") ~= "" then
            latest = info.Version
        end
        listed[#listed + 1] = build_module_item(entry.name, entry.version, latest)
    end
    table.sort(listed, function(left, right)
        if tostring(left.packageType) ~= tostring(right.packageType) then
            return tostring(left.packageType) < tostring(right.packageType)
        end
        return tostring(left.name) < tostring(right.name)
    end)
    emit_event(context, "listed", listed)
    return listed
end

function plugin.outdated(context)
    local items = {}
    local paths = shared_paths(context, {})
    for _, entry in ipairs(read_modules_state(paths, context)) do
        local info = module_info(context, {}, entry.name .. "@latest")
        if info ~= nil and trim(info.Version or "") ~= "" and trim(info.Version or "") ~= trim(entry.version or "") then
            items[#items + 1] = build_module_item(entry.name, entry.version, info.Version)
        end
    end
    for _, item in ipairs(installed_tools(context, {})) do
        local module_path = trim(read_field(read_field(item, "extraFields"), "modulePath") or "")
        if module_path ~= "" and trim(item.version or "") ~= "" then
            local info = module_info(context, {}, module_path .. "@latest")
            if info ~= nil and trim(info.Version or "") ~= "" and trim(info.Version or "") ~= trim(item.version or "") then
                local extra = shallow_copy(read_field(item, "extraFields") or {})
                items[#items + 1] = {
                    name = item.name,
                    packageId = item.packageId,
                    packageType = "tool",
                    version = item.version,
                    latestVersion = info.Version,
                    installed = true,
                    status = "installed",
                    extraFields = extra,
                }
            end
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned = trim(prompt)
    local items = {}
    if cleaned ~= "" then
        local info = module_info(context, {}, cleaned .. "@latest")
        if info ~= nil then
            items[#items + 1] = build_module_item(info.Path, info.Version, info.Version, { query = info.Query })
        end
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local cleaned = info_prompt(context, name)
    if cleaned == "" then
        local item = {}
        emit_event(context, "informed", item)
        return item
    end
    for _, item in ipairs(installed_tools(context, {})) do
        if item.name == cleaned then
            emit_event(context, "informed", item)
            return item
        end
    end
    local info = module_info(context, {}, cleaned .. "@latest")
    if info == nil then
        local item = {}
        emit_event(context, "informed", item)
        return item
    end
    local item = build_module_item(info.Path, info.Version, info.Version, { query = info.Query })
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, pkg)
    if package_type(pkg) == "module" then
        local info = module_info(context, { pkg }, package_query(pkg))
        if info ~= nil then
            return build_module_item(info.Path, info.Version, info.Version, { query = info.Query })
        end
    end
    return {
        name = package_name(pkg),
        packageId = package_name(pkg),
        packageType = package_type(pkg),
        version = package_version(pkg) ~= "" and package_version(pkg) or "latest",
        latestVersion = package_version(pkg) ~= "" and package_version(pkg) or "latest",
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "go", "golang", "modules" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".cache/reqpack/go" },
        },
        privilegeLevel = "user",
        osvEcosystem = "Go",
        purlType = "golang",
    }
end

return plugin
