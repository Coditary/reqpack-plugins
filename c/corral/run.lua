plugin = {}

local PLUGIN_NAME = "Corral"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "corral"

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
        local fixture_root = trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT"))
        if fixture_root ~= "" then
            return "/home/test"
        end
    end
    if os ~= nil and type(os.getenv) == "function" then
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
    local value = trim(path):gsub("[/\\]+$", "")
    return value:match("[^/\\]+$") or value
end

local function ensure_directory(path)
    local dir = trim(path)
    if dir == "" or dir == "." then
        return true
    end
    if os == nil or type(os.execute) ~= "function" then
        return true
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

local function write_file(path, content)
    local dir = parent_dir(path)
    if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
        return false
    end
    local tmp_path = path .. ".tmp"
    local handle = io.open(tmp_path, "w")
    if handle == nil then
        handle = io.open(path, "w")
        if handle == nil then
            return false
        end
        handle:write(content)
        handle:close()
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
        os.remove(tmp_path)
        return false
    end
    return true
end

local function file_exists(context, path)
    if context ~= nil then
        local result = exec_run(context, "test -e " .. shell_quote(path))
        return result ~= nil and result.success == true
    end
    local handle = io.open(path, "r")
    if handle ~= nil then
        handle:close()
        return true
    end
    return false
end

local function cache_bundle_dir()
    return join_path(home_dir(), ".cache", "reqpack", "corral", "bundle")
end

local function manifest_path()
    return join_path(cache_bundle_dir(), "corral.json")
end

local function lock_path()
    return join_path(cache_bundle_dir(), "lock.json")
end

local function repos_path()
    return join_path(cache_bundle_dir(), "_repos")
end

local function corral_path()
    return join_path(cache_bundle_dir(), "_corral")
end

local function json_error(message, index)
    error("invalid json at offset " .. tostring(index) .. ": " .. message)
end

local function json_decode(input)
    local source = tostring(input or "")
    local index = 1

    local function peek(offset)
        return source:sub(index + (offset or 0), index + (offset or 0))
    end

    local function advance(count)
        index = index + (count or 1)
    end

    local function skip_whitespace()
        while true do
            local char = peek()
            if char == " " or char == "\n" or char == "\r" or char == "\t" then
                advance(1)
            else
                return
            end
        end
    end

    local parse_value

    local function parse_string()
        if peek() ~= '"' then
            json_error("expected string", index)
        end
        advance(1)
        local parts = {}
        while true do
            local char = peek()
            if char == "" then
                json_error("unterminated string", index)
            elseif char == '"' then
                advance(1)
                return table.concat(parts)
            elseif char == "\\" then
                local escape = peek(1)
                if escape == '"' or escape == "\\" or escape == "/" then
                    parts[#parts + 1] = escape
                    advance(2)
                elseif escape == "b" then
                    parts[#parts + 1] = "\b"
                    advance(2)
                elseif escape == "f" then
                    parts[#parts + 1] = "\f"
                    advance(2)
                elseif escape == "n" then
                    parts[#parts + 1] = "\n"
                    advance(2)
                elseif escape == "r" then
                    parts[#parts + 1] = "\r"
                    advance(2)
                elseif escape == "t" then
                    parts[#parts + 1] = "\t"
                    advance(2)
                elseif escape == "u" then
                    local hex = source:sub(index + 2, index + 5)
                    if not hex:match("^%x%x%x%x$") then
                        json_error("invalid unicode escape", index)
                    end
                    local codepoint = tonumber(hex, 16)
                    if utf8 ~= nil and type(utf8.char) == "function" then
                        parts[#parts + 1] = utf8.char(codepoint)
                    elseif codepoint < 128 then
                        parts[#parts + 1] = string.char(codepoint)
                    else
                        json_error("unicode escape unsupported without utf8 library", index)
                    end
                    advance(6)
                else
                    json_error("invalid escape sequence", index)
                end
            else
                parts[#parts + 1] = char
                advance(1)
            end
        end
    end

    local function parse_number()
        local start = index
        if peek() == "-" then
            advance(1)
        end
        local char = peek()
        if char == "0" then
            advance(1)
        elseif char:match("%d") then
            repeat
                advance(1)
                char = peek()
            until not char:match("%d")
        else
            json_error("invalid number", index)
        end
        if peek() == "." then
            advance(1)
            if not peek():match("%d") then
                json_error("invalid number fraction", index)
            end
            repeat
                advance(1)
                char = peek()
            until not char:match("%d")
        end
        char = peek()
        if char == "e" or char == "E" then
            advance(1)
            char = peek()
            if char == "+" or char == "-" then
                advance(1)
            end
            if not peek():match("%d") then
                json_error("invalid number exponent", index)
            end
            repeat
                advance(1)
                char = peek()
            until not char:match("%d")
        end
        return tonumber(source:sub(start, index - 1))
    end

    local function parse_array()
        if peek() ~= "[" then
            json_error("expected array", index)
        end
        advance(1)
        skip_whitespace()
        local result = {}
        if peek() == "]" then
            advance(1)
            return result
        end
        while true do
            result[#result + 1] = parse_value()
            skip_whitespace()
            local char = peek()
            if char == "," then
                advance(1)
                skip_whitespace()
            elseif char == "]" then
                advance(1)
                return result
            else
                json_error("expected ',' or ']'", index)
            end
        end
    end

    local function parse_object()
        if peek() ~= "{" then
            json_error("expected object", index)
        end
        advance(1)
        skip_whitespace()
        local result = {}
        if peek() == "}" then
            advance(1)
            return result
        end
        while true do
            local key = parse_string()
            skip_whitespace()
            if peek() ~= ":" then
                json_error("expected ':'", index)
            end
            advance(1)
            skip_whitespace()
            result[key] = parse_value()
            skip_whitespace()
            local char = peek()
            if char == "," then
                advance(1)
                skip_whitespace()
            elseif char == "}" then
                advance(1)
                return result
            else
                json_error("expected ',' or '}'", index)
            end
        end
    end

    function parse_value()
        skip_whitespace()
        local char = peek()
        if char == '"' then
            return parse_string()
        elseif char == "{" then
            return parse_object()
        elseif char == "[" then
            return parse_array()
        elseif char == "-" or char:match("%d") then
            return parse_number()
        elseif source:sub(index, index + 3) == "true" then
            advance(4)
            return true
        elseif source:sub(index, index + 4) == "false" then
            advance(5)
            return false
        elseif source:sub(index, index + 3) == "null" then
            advance(4)
            return nil
        end
        json_error("unexpected token", index)
    end

    local decoded = parse_value()
    skip_whitespace()
    if index <= #source then
        json_error("trailing characters", index)
    end
    return decoded
end

local function try_json_decode(input)
    return pcall(json_decode, input)
end

local function json_escape(value)
    return tostring(value or "")
        :gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\b", "\\b")
        :gsub("\f", "\\f")
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
end

local function json_encode(value)
    local value_type = type(value)
    if value_type == "nil" then
        return "null"
    elseif value_type == "boolean" then
        return value and "true" or "false"
    elseif value_type == "number" then
        return tostring(value)
    elseif value_type == "string" then
        return '"' .. json_escape(value) .. '"'
    elseif value_type == "table" then
        local is_array = true
        local highest = 0
        for key in pairs(value) do
            if type(key) ~= "number" or key < 1 or math.floor(key) ~= key then
                is_array = false
                break
            end
            if key > highest then
                highest = key
            end
        end
        if is_array then
            local items = {}
            for index = 1, highest do
                items[#items + 1] = json_encode(value[index])
            end
            return "[" .. table.concat(items, ",") .. "]"
        end
        local keys = {}
        for key in pairs(value) do
            keys[#keys + 1] = key
        end
        table.sort(keys)
        local items = {}
        for _, key in ipairs(keys) do
            items[#items + 1] = json_encode(tostring(key)) .. ":" .. json_encode(value[key])
        end
        return "{" .. table.concat(items, ",") .. "}"
    end
    return "null"
end

local function default_state()
    return {
        bundle = {
            info = {
                name = "reqpack-corral-cache",
                description = "ReqPack Corral shared cache bundle",
            },
            packages = {},
            deps = {},
        },
        lock = {
            locks = {},
        },
    }
end

local function sort_dep_entries(entries)
    table.sort(entries, function(left, right)
        return lower(left.locator or "") < lower(right.locator or "")
    end)
end

local function sort_lock_entries(entries)
    table.sort(entries, function(left, right)
        return lower(left.locator or "") < lower(right.locator or "")
    end)
end

local function normalize_state(raw_bundle, raw_lock)
    local state = default_state()

    if type(raw_bundle) == "table" then
        if type(raw_bundle.info) == "table" then
            state.bundle.info = shallow_copy(raw_bundle.info)
        end
        if type(raw_bundle.packages) == "table" then
            state.bundle.packages = raw_bundle.packages
        end
        if type(raw_bundle.deps) == "table" then
            state.bundle.deps = {}
            for _, dep in ipairs(raw_bundle.deps) do
                local locator = trim(read_field(dep, "locator"))
                if locator ~= "" then
                    state.bundle.deps[#state.bundle.deps + 1] = {
                        locator = locator,
                        version = trim(read_field(dep, "version")),
                    }
                end
            end
        end
    end

    if type(raw_lock) == "table" and type(raw_lock.locks) == "table" then
        state.lock.locks = {}
        for _, lock_entry in ipairs(raw_lock.locks) do
            local locator = trim(read_field(lock_entry, "locator"))
            if locator ~= "" then
                state.lock.locks[#state.lock.locks + 1] = {
                    locator = locator,
                    revision = trim(read_field(lock_entry, "revision")),
                }
            end
        end
    end

    sort_dep_entries(state.bundle.deps)
    sort_lock_entries(state.lock.locks)
    return state
end

local function load_state(context)
    local bundle_raw = read_file(context, manifest_path())
    local lock_raw = read_file(context, lock_path())

    if bundle_raw == nil and lock_raw == nil then
        return default_state(), false
    end

    local decoded_bundle = nil
    local decoded_lock = nil

    if bundle_raw ~= nil and trim(bundle_raw) ~= "" then
        local ok, value = try_json_decode(bundle_raw)
        if ok then
            decoded_bundle = value
        end
    end

    if lock_raw ~= nil and trim(lock_raw) ~= "" then
        local ok, value = try_json_decode(lock_raw)
        if ok then
            decoded_lock = value
        end
    end

    return normalize_state(decoded_bundle, decoded_lock), true
end

local function state_dep_lookup(state)
    local lookup = {}
    for _, dep in ipairs((((state or {}).bundle or {}).deps) or {}) do
        lookup[dep.locator] = dep
    end
    return lookup
end

local function state_lock_lookup(state)
    local lookup = {}
    for _, lock_entry in ipairs((((state or {}).lock or {}).locks) or {}) do
        lookup[lock_entry.locator] = lock_entry
    end
    return lookup
end

local function package_flags(pkg)
    local value = read_field(pkg, "flags")
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local result = {}
    local ok = pcall(function()
        for _, item in ipairs(value) do
            local cleaned = trim(item)
            if cleaned ~= "" then
                result[#result + 1] = cleaned
            end
        end
    end)
    if not ok then
        return {}
    end
    return result
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageName") or read_field(pkg, "packageId"))
end

local function package_version(pkg)
    return trim(read_field(pkg, "version"))
end

local function package_revision(pkg)
    local direct = trim(read_field(pkg, "revision"))
    if direct ~= "" then
        return direct
    end
    for _, flag in ipairs(package_flags(pkg)) do
        if lower(flag):sub(1, 9) == "revision=" then
            return trim(flag:sub(10))
        end
    end
    return ""
end

local function package_action(pkg)
    local action = lower(read_field(pkg, "action"))
    if action == "" then
        return "install"
    end
    return action
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function corral_command(subcommand, args)
    local parts = {
        REQUIRED_BINARY,
        "--bundle_dir",
        shell_quote(cache_bundle_dir()),
        subcommand,
    }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = arg
    end
    return table.concat(parts, " ")
end

local function build_add_command(locator, version, revision)
    local parts = {}
    if trim(version) ~= "" then
        parts[#parts + 1] = "--version"
        parts[#parts + 1] = shell_quote(version)
    end
    if trim(revision) ~= "" then
        parts[#parts + 1] = "--revision"
        parts[#parts + 1] = shell_quote(revision)
    end
    parts[#parts + 1] = shell_quote(locator)
    return corral_command("add", parts)
end

local function build_remove_command(locator)
    return corral_command("remove", { shell_quote(locator) })
end

local function build_init_command()
    return corral_command("init", {})
end

local function build_update_command()
    return corral_command("update", {})
end

local function build_clean_command()
    return corral_command("clean", {})
end

local function ensure_bundle_initialized(context)
    if file_exists(context, manifest_path()) and file_exists(context, lock_path()) then
        return true
    end
    if not ensure_directory(cache_bundle_dir()) then
        tx_failed(context, "failed to create Corral cache directory")
        return false
    end
    local result = exec_run(context, build_init_command())
    if result == nil or result.success ~= true then
        tx_failed(context, "corral init failed")
        return false
    end
    return true
end

local function build_result_item(locator, dep, lock_entry)
    local extra = {
        cacheBundlePath = cache_bundle_dir(),
        manifestPath = manifest_path(),
        lockPath = lock_path(),
        reposPath = repos_path(),
        corralPath = corral_path(),
        locatorBasename = basename(locator),
    }
    if lock_entry ~= nil and trim(lock_entry.revision) ~= "" then
        extra.lockedRevision = trim(lock_entry.revision)
    end
    return {
        name = locator,
        packageId = locator,
        packageType = "bundle",
        version = dep ~= nil and trim(dep.version) or "",
        extraFields = extra,
    }
end

local function list_items_from_state(state)
    local items = {}
    local locks = state_lock_lookup(state)
    for _, dep in ipairs(state.bundle.deps or {}) do
        items[#items + 1] = build_result_item(dep.locator, dep, locks[dep.locator])
    end
    return items
end

local function info_item_from_state(state, prompt)
    local target = trim(prompt)
    if target == "" then
        return nil
    end
    local locks = state_lock_lookup(state)
    for _, dep in ipairs(state.bundle.deps or {}) do
        local locator = trim(dep.locator)
        if locator == target or basename(locator) == target then
            return build_result_item(locator, dep, locks[locator])
        end
    end
    for _, lock_entry in ipairs(state.lock.locks or {}) do
        if trim(lock_entry.locator) == target then
            return build_result_item(lock_entry.locator, { locator = lock_entry.locator, version = "" }, lock_entry)
        end
    end
    return nil
end

local function fail_action(context, message)
    tx_failed(context, message)
    return false
end

plugin.fileExtensions = {}

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
    return { "Pony", "Corral", "Package Manager" }
end

function plugin.init()
    return command_exists(nil, REQUIRED_BINARY)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "package-install", "package-remove", "package-update", "package-query" },
        ecosystemScopes = { "pony", "corral" },
        writeScopes = { "user-home-subpath:.cache/reqpack/corral" },
        networkScopes = {},
        privilegeLevel = "none",
        purlType = "generic",
    }
end

function plugin.getMissingPackages(context_or_packages, maybe_packages)
    local packages = maybe_packages
    if packages == nil then
        packages = context_or_packages
    end
    local state, exists = load_state(nil)
    local installed = state_dep_lookup(state)
    local missing = {}

    for _, pkg in ipairs(packages or {}) do
        local locator = package_name(pkg)
        local version = package_version(pkg)
        local revision = package_revision(pkg)
        local action = package_action(pkg)
        local present = installed[locator]

        if locator ~= "" then
            if action == "remove" then
                if present ~= nil then
                    missing[#missing + 1] = pkg
                end
            elseif action == "update" then
                missing[#missing + 1] = pkg
            elseif not exists then
                missing[#missing + 1] = pkg
            elseif present == nil then
                missing[#missing + 1] = pkg
            elseif trim(present.version) ~= trim(version) then
                missing[#missing + 1] = pkg
            else
                local lock_entry = state_lock_lookup(state)[locator]
                if revision ~= "" and trim(read_field(lock_entry, "revision")) ~= revision then
                    missing[#missing + 1] = pkg
                end
            end
        end
    end

    return missing
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        return fail_action(context, REQUIRED_BINARY .. " binary not available")
    end
    if not ensure_bundle_initialized(context) then
        return false
    end

    begin_step(context, "install Corral dependencies")

    for _, pkg in ipairs(requested) do
        local locator = package_name(pkg)
        if locator ~= "" then
            local result = exec_run(context, build_add_command(locator, package_version(pkg), package_revision(pkg)))
            if result == nil or result.success ~= true then
                return fail_action(context, "corral add failed for " .. locator)
            end
        end
    end

    local update_result = exec_run(context, build_update_command())
    if update_result == nil or update_result.success ~= true then
        return fail_action(context, "corral update failed")
    end

    emit_event(context, "installed", requested)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" then
        local request = read_field(context, "request")
        local_path = trim(read_field(context, "localPath") or read_field(request, "localPath"))
    end
    if local_path == "" then
        return fail_action(context, "missing local Corral bundle path")
    end
    if not command_exists(context, REQUIRED_BINARY) then
        return fail_action(context, REQUIRED_BINARY .. " binary not available")
    end
    if not ensure_bundle_initialized(context) then
        return false
    end

    begin_step(context, "install local Corral bundle")

    local add_result = exec_run(context, build_add_command(local_path, "", ""))
    if add_result == nil or add_result.success ~= true then
        return fail_action(context, "corral add failed for " .. local_path)
    end

    local update_result = exec_run(context, build_update_command())
    if update_result == nil or update_result.success ~= true then
        return fail_action(context, "corral update failed")
    end

    emit_event(context, "installed", { path = local_path, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if not command_exists(context, REQUIRED_BINARY) then
        return fail_action(context, REQUIRED_BINARY .. " binary not available")
    end

    local _, exists = load_state(context)
    if not exists then
        return true
    end

    begin_step(context, "remove Corral dependencies")

    for _, pkg in ipairs(requested) do
        local locator = package_name(pkg)
        if locator ~= "" then
            local result = exec_run(context, build_remove_command(locator))
            if result == nil or result.success ~= true then
                return fail_action(context, "corral remove failed for " .. locator)
            end
        end
    end

    local clean_result = exec_run(context, build_clean_command())
    if clean_result == nil or clean_result.success ~= true then
        return fail_action(context, "corral clean failed")
    end

    local update_result = exec_run(context, build_update_command())
    if update_result == nil or update_result.success ~= true then
        return fail_action(context, "corral update failed")
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    if not command_exists(context, REQUIRED_BINARY) then
        return fail_action(context, REQUIRED_BINARY .. " binary not available")
    end
    if not ensure_bundle_initialized(context) then
        return false
    end

    begin_step(context, "update Corral dependencies")

    if #requested > 0 then
        for _, pkg in ipairs(requested) do
            local locator = package_name(pkg)
            if locator ~= "" then
                local result = exec_run(context, build_add_command(locator, package_version(pkg), package_revision(pkg)))
                if result == nil or result.success ~= true then
                    return fail_action(context, "corral add failed for " .. locator)
                end
            end
        end

        local clean_result = exec_run(context, build_clean_command())
        if clean_result == nil or clean_result.success ~= true then
            return fail_action(context, "corral clean failed")
        end
    end

    local update_result = exec_run(context, build_update_command())
    if update_result == nil or update_result.success ~= true then
        return fail_action(context, "corral update failed")
    end

    emit_event(context, "updated", requested)
    tx_success(context)
    return true
end

function plugin.list(context)
    if not command_exists(context, REQUIRED_BINARY) then
        emit_event(context, "listed", {})
        return {}
    end
    local state = load_state(context)
    state = state
    local items = list_items_from_state(state)
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
    if not command_exists(context, REQUIRED_BINARY) then
        emit_event(context, "searched", {})
        return {}
    end
    local items = {}
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    if not command_exists(context, REQUIRED_BINARY) then
        emit_event(context, "informed", {})
        return {}
    end
    local target = trim(name)
    if target == "" then
        local request = read_field(context, "request")
        target = trim(read_field(request, "prompt") or read_field(request, "name") or read_field(context, "prompt"))
    end
    local state = load_state(context)
    local item = info_item_from_state(state, target)
    emit_event(context, "informed", item ~= nil and { item } or {})
    return item or {}
end

function plugin.shutdown()
    return true
end

return plugin
