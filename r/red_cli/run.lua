plugin = {}

local PLUGIN_ID = "red_cli"
local PLUGIN_NAME = "Red CLI"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "red-cli"
local COMMAND_ENV_PREFIX = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C"
local JSON_NULL = {}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return trim(value):lower()
end

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
end

local function split_lines(value)
    local lines = {}
    local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

local function normalize_separators(value)
    return tostring(value or ""):gsub("\\", "/")
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(normalize_separators(select(index, ...)))
        if part ~= "" then
            if #parts == 0 then
                parts[#parts + 1] = part:gsub("/+$", "")
            else
                parts[#parts + 1] = part:gsub("^/+", ""):gsub("/+$", "")
            end
        end
    end
    if #parts == 0 then
        return "."
    end
    return table.concat(parts, "/")
end

local function basename(path)
    local cleaned = trim(normalize_separators(path)):gsub("/+$", "")
    return cleaned:match("[^/]+$") or cleaned
end

local function dirname(path)
    local cleaned = trim(normalize_separators(path)):gsub("/+$", "")
    return cleaned:match("^(.*)/[^/]+$") or "."
end

local function ends_with(value, suffix)
    local text = tostring(value or "")
    return suffix ~= "" and text:sub(-#suffix) == suffix
end

local function is_absolute_path(path)
    local text = trim(normalize_separators(path))
    return text:sub(1, 1) == "/" or text:match("^%a:/") ~= nil
end

local function is_path_like(path)
    local text = trim(path)
    return text:find("/", 1, true) ~= nil or text:find("\\", 1, true) ~= nil or text:sub(1, 1) == "."
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

local function read_nested_field(value, ...)
    local current = value
    for _, key in ipairs({ ... }) do
        current = read_field(current, key)
        if current == nil then
            return nil
        end
    end
    return current
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

local function collect_flags(context, package)
    local flags = {}
    local seen = {}
    local function collect_from(object)
        for _, flag in ipairs(read_flags(object)) do
            if not seen[flag] then
                seen[flag] = true
                flags[#flags + 1] = flag
            end
        end
    end
    collect_from(context)
    collect_from(read_field(context, "request"))
    collect_from(package)
    return flags
end

local function has_flag(flags, key)
    local wanted = lower(key)
    for _, flag in ipairs(flags or {}) do
        if lower(flag) == wanted then
            return true
        end
    end
    return false
end

local function flag_value(flags, key)
    local prefix = lower(key) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            return trim(cleaned:sub(#prefix + 1))
        end
    end
    return ""
end

local function fixture_root()
    if os ~= nil and type(os.getenv) == "function" then
        return trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
    end
    return ""
end

local function expand_runtime_placeholders(value)
    local text = tostring(value or "")
    local root = fixture_root()
    if root ~= "" then
        text = text:gsub("%${fixtureRoot}", root)
    end
    return text
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
    local function apply(value)
        local value_type = type(value)
        if value_type == "table" then
            for key, item in pairs(value or {}) do
                result[key] = item
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
    apply(first)
    apply(second)
    apply(third)
    apply(fourth)
    apply(fifth)
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

local function package_error(context, message, payload)
    tx_failed(context, message)
    if payload ~= nil then
        emit_event(context, "error", payload)
    end
    return false
end

local function ensure_directory(path)
    local dir = trim(expand_runtime_placeholders(path))
    if dir == "" or dir == "." then
        return true
    end
    if os ~= nil and type(os.execute) == "function" then
        local ok = os.execute("mkdir -p " .. shell_quote(dir))
        if ok == true or ok == 0 then
            return true
        end
    end
    local probe = io.open(dir .. "/.", "r")
    if probe ~= nil then
        probe:close()
        return true
    end
    return true
end

local function read_file(path)
    path = expand_runtime_placeholders(path)
    local handle = io.open(path, "r")
    if handle == nil then
        if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
            local result = exec_run(nil, "cat " .. shell_quote(path))
            if result ~= nil and result.success == true then
                return result.stdout or ""
            end
        end
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(path, content)
    path = expand_runtime_placeholders(path)
    local parent = path:match("^(.*)/[^/]+$")
    if parent ~= nil and parent ~= "" and not ensure_directory(parent) then
        return false, "mkdir failed for " .. tostring(parent)
    end
    local handle = io.open(path, "w")
    if handle == nil then
        return true, nil
    end
    handle:write(content)
    handle:close()
    return true, nil
end

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        return os.getenv(name)
    end
    return nil
end

local function default_data_root()
    local home = trim(getenv("HOME") or "")
    if home == "" then
        return ".red-cli-reqpack"
    end
    return join_path(home, ".cache", "reqpack", PLUGIN_ID)
end

local function data_root_for_context(context, package)
    local flags = collect_flags(context, package)
    local root = flag_value(flags, "data-root")
    if root == "" then
        root = flag_value(flags, "cache-root")
    end
    if root == "" then
        root = default_data_root()
    end
    return expand_runtime_placeholders(root)
end

local function state_paths(root)
    return {
        root = root,
        tracked = join_path(root, "tracked-projects.txt"),
    }
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function ensure_available(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true, nil
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function codepoint_to_utf8(codepoint)
    if codepoint <= 0x7F then
        return string.char(codepoint)
    end
    if codepoint <= 0x7FF then
        return string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + (codepoint % 0x40))
    end
    if codepoint <= 0xFFFF then
        return string.char(
            0xE0 + math.floor(codepoint / 0x1000),
            0x80 + (math.floor(codepoint / 0x40) % 0x40),
            0x80 + (codepoint % 0x40)
        )
    end
    return string.char(
        0xF0 + math.floor(codepoint / 0x40000),
        0x80 + (math.floor(codepoint / 0x1000) % 0x40),
        0x80 + (math.floor(codepoint / 0x40) % 0x40),
        0x80 + (codepoint % 0x40)
    )
end

local function decode_json_internal(raw)
    local text = tostring(raw or "")
    local length = #text
    local index = 1

    local function decode_error(message)
        error(message .. " at byte " .. tostring(index), 0)
    end

    local function peek()
        return text:sub(index, index)
    end

    local function skip_whitespace()
        while index <= length do
            local byte = text:byte(index)
            if byte == 32 or byte == 9 or byte == 10 or byte == 13 then
                index = index + 1
            else
                break
            end
        end
    end

    local parse_value

    local function parse_string()
        index = index + 1
        local parts = {}
        local segment_start = index

        while index <= length do
            local current = text:sub(index, index)
            if current == '"' then
                parts[#parts + 1] = text:sub(segment_start, index - 1)
                index = index + 1
                return table.concat(parts)
            end

            if current == "\\" then
                parts[#parts + 1] = text:sub(segment_start, index - 1)
                index = index + 1
                if index > length then
                    decode_error("unterminated escape sequence")
                end

                local escape = text:sub(index, index)
                if escape == '"' or escape == "\\" or escape == "/" then
                    parts[#parts + 1] = escape
                    index = index + 1
                elseif escape == "b" then
                    parts[#parts + 1] = "\b"
                    index = index + 1
                elseif escape == "f" then
                    parts[#parts + 1] = "\f"
                    index = index + 1
                elseif escape == "n" then
                    parts[#parts + 1] = "\n"
                    index = index + 1
                elseif escape == "r" then
                    parts[#parts + 1] = "\r"
                    index = index + 1
                elseif escape == "t" then
                    parts[#parts + 1] = "\t"
                    index = index + 1
                elseif escape == "u" then
                    local hex = text:sub(index + 1, index + 4)
                    if #hex ~= 4 or hex:match("^[0-9a-fA-F]+$") == nil then
                        decode_error("invalid unicode escape")
                    end
                    parts[#parts + 1] = codepoint_to_utf8(tonumber(hex, 16))
                    index = index + 5
                else
                    decode_error("unsupported escape sequence")
                end
                segment_start = index
            else
                local byte = text:byte(index)
                if byte ~= nil and byte < 32 then
                    decode_error("control character in string")
                end
                index = index + 1
            end
        end

        decode_error("unterminated string")
    end

    local function parse_number()
        local start_index = index
        local current = peek()

        if current == "-" then
            index = index + 1
            current = peek()
        end

        if current == "0" then
            index = index + 1
        elseif current:match("%d") then
            repeat
                index = index + 1
                current = peek()
            until current == "" or not current:match("%d")
        else
            decode_error("invalid number")
        end

        current = peek()
        if current == "." then
            index = index + 1
            if not peek():match("%d") then
                decode_error("invalid number fraction")
            end
            repeat
                index = index + 1
                current = peek()
            until current == "" or not current:match("%d")
        end

        current = peek()
        if current == "e" or current == "E" then
            index = index + 1
            current = peek()
            if current == "+" or current == "-" then
                index = index + 1
            end
            if not peek():match("%d") then
                decode_error("invalid number exponent")
            end
            repeat
                index = index + 1
                current = peek()
            until current == "" or not current:match("%d")
        end

        return tonumber(text:sub(start_index, index - 1))
    end

    local function parse_array()
        index = index + 1
        skip_whitespace()
        local result = {}

        if peek() == "]" then
            index = index + 1
            return result
        end

        while true do
            result[#result + 1] = parse_value()
            skip_whitespace()

            local current = peek()
            if current == "]" then
                index = index + 1
                return result
            end
            if current ~= "," then
                decode_error("expected ',' or ']' in array")
            end
            index = index + 1
            skip_whitespace()
        end
    end

    local function parse_object()
        index = index + 1
        skip_whitespace()
        local result = {}

        if peek() == "}" then
            index = index + 1
            return result
        end

        while true do
            if peek() ~= '"' then
                decode_error("expected string key")
            end
            local key = parse_string()
            skip_whitespace()
            if peek() ~= ":" then
                decode_error("expected ':' after object key")
            end
            index = index + 1
            skip_whitespace()
            result[key] = parse_value()
            skip_whitespace()

            local current = peek()
            if current == "}" then
                index = index + 1
                return result
            end
            if current ~= "," then
                decode_error("expected ',' or '}' in object")
            end
            index = index + 1
            skip_whitespace()
        end
    end

    function parse_value()
        skip_whitespace()
        local current = peek()

        if current == '"' then
            return parse_string()
        elseif current == "{" then
            return parse_object()
        elseif current == "[" then
            return parse_array()
        elseif current == "-" or current:match("%d") then
            return parse_number()
        elseif text:sub(index, index + 3) == "true" then
            index = index + 4
            return true
        elseif text:sub(index, index + 4) == "false" then
            index = index + 5
            return false
        elseif text:sub(index, index + 3) == "null" then
            index = index + 4
            return JSON_NULL
        end

        decode_error("unexpected token")
    end

    local result = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("trailing characters")
    end
    return result
end

local function normalize_json_tree(value, seen)
    if value == JSON_NULL then
        return nil
    end
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] ~= nil then
        return seen[value]
    end
    local normalized = {}
    seen[value] = normalized
    for key, item in pairs(value) do
        normalized[key] = normalize_json_tree(item, seen)
    end
    return normalized
end

local function decode_json(raw)
    local ok, decoded = pcall(decode_json_internal, raw)
    if not ok then
        return nil, decoded
    end
    return normalize_json_tree(decoded), nil
end

local function file_exists(path)
    local cleaned = expand_runtime_placeholders(trim(path))
    if cleaned == "" then
        return false
    end
    local handle = io.open(cleaned, "r")
    if handle ~= nil then
        handle:close()
        return true
    end
    local result = exec_run(nil, "test -e " .. shell_quote(cleaned))
    return result ~= nil and result.success == true
end

local function normalize_project_root(raw)
    local path = trim(normalize_separators(expand_runtime_placeholders(raw)))
    if path == "" then
        return nil, "red-cli project path required"
    end
    if ends_with(lower(path), "/red.config.json") or lower(basename(path)) == "red.config.json" then
        return dirname(path), nil
    end
    return path:gsub("/+$", ""), nil
end

local function canonical_project_root(raw)
    local root = select(1, normalize_project_root(raw))
    return trim(root or "")
end

local function config_path_for_root(root)
    return join_path(canonical_project_root(root), "red.config.json")
end

local function load_config(root)
    local config_path = config_path_for_root(root)
    local raw = read_file(config_path)
    if raw == nil then
        return nil, "red.config.json not found in " .. tostring(root)
    end
    local decoded, err = decode_json(raw)
    if decoded == nil then
        return nil, "invalid red.config.json: " .. tostring(err)
    end
    return decoded, nil
end

local function default_string(value, fallback)
    local cleaned = trim(value)
    if cleaned == "" then
        return fallback
    end
    return cleaned
end

local function rooted_path(root, path, fallback)
    local cleaned = default_string(normalize_separators(path), fallback or "")
    if cleaned == "" then
        return ""
    end
    if is_absolute_path(cleaned) then
        return cleaned
    end
    return join_path(root, cleaned)
end

local function target_path(game, output, fallback, name)
    if trim(game) == "" then
        return ""
    end
    return join_path(game, default_string(normalize_separators(output), fallback), name)
end

local function build_missing_item(root, tracked)
    local cleaned = trim(root)
    return {
        name = basename(cleaned),
        packageId = lower(basename(cleaned)),
        installed = tracked == true,
        status = tracked == true and "missing-config" or "missing",
        summary = basename(cleaned),
        description = "Project root: " .. cleaned,
        packageType = "red-cli-project",
        extraFields = {
            projectRoot = cleaned,
            configPath = config_path_for_root(cleaned),
            stagePath = "",
            gamePath = "",
            installedTargets = {},
        },
    }
end

local function build_item_from_config(root, config, tracked)
    local name = default_string(read_field(config, "name"), basename(root))
    local version = default_string(read_field(config, "version"), "0.1.0")
    local stage = rooted_path(root, read_field(config, "stage"), "stage")
    local game = default_string(getenv("REDCLI_GAME"), trim(read_field(config, "game")))
    local redscript = read_nested_field(config, "scripts", "redscript")
    local cet = read_nested_field(config, "scripts", "cet")
    local plugin_cfg = read_field(config, "plugin")
    local targets = {}

    if redscript ~= nil then
        local target = target_path(game, read_field(redscript, "output"), "r6/scripts", name)
        if target ~= "" then
            targets[#targets + 1] = target
        end
        if trim(read_field(redscript, "storage") or "") ~= "" and trim(game) ~= "" then
            targets[#targets + 1] = join_path(game, "r6/storages", name)
        end
    end

    if cet ~= nil then
        local target = target_path(game, read_field(cet, "output"), "bin/x64/plugins/cyber_engine_tweaks/mods", name)
        if target ~= "" then
            targets[#targets + 1] = target
        end
    end

    if plugin_cfg ~= nil and trim(game) ~= "" then
        targets[#targets + 1] = join_path(game, "red4ext/plugins", name)
    end

    local item = {
        name = name,
        packageId = lower(name),
        version = version,
        installed = tracked == true,
        status = tracked == true and "tracked" or "available",
        summary = name .. " red-cli project",
        description = "Project root: " .. root,
        packageType = "red-cli-project",
        extraFields = {
            projectRoot = root,
            configPath = config_path_for_root(root),
            stagePath = stage,
            gamePath = game,
            installedTargets = targets,
            hasRedscript = redscript ~= nil,
            hasCET = cet ~= nil,
            hasPlugin = plugin_cfg ~= nil,
        },
    }
    return item
end

local function load_project_item(root, tracked)
    local cleaned = canonical_project_root(root)
    local config, err = load_config(cleaned)
    if config == nil then
        return build_missing_item(cleaned, tracked), err
    end
    return build_item_from_config(cleaned, config, tracked), nil
end

local function load_tracked_roots(paths)
    local roots = {}
    local seen = {}
    for _, line in ipairs(split_lines(read_file(paths.tracked) or "")) do
        local root = canonical_project_root(line)
        if root ~= "" and not seen[root] then
            seen[root] = true
            roots[#roots + 1] = root
        end
    end
    return roots
end

local function save_tracked_roots(paths, roots)
    if not ensure_directory(paths.root) then
        return false, "unable to create red_cli state root"
    end
    local lines = {}
    local seen = {}
    for _, root in ipairs(roots or {}) do
        local cleaned = canonical_project_root(root)
        if cleaned ~= "" and not seen[cleaned] then
            seen[cleaned] = true
            lines[#lines + 1] = cleaned
        end
    end
    return write_file(paths.tracked, (#lines > 0 and (table.concat(lines, "\n") .. "\n") or ""))
end

local function tracked_set(roots)
    local set = {}
    for _, root in ipairs(roots or {}) do
        local cleaned = canonical_project_root(root)
        if cleaned ~= "" then
            set[cleaned] = true
        end
    end
    return set
end

local function lookup_tracked_root(paths, raw)
    local target = lower(trim(raw))
    if target == "" then
        return nil
    end
    for _, root in ipairs(load_tracked_roots(paths)) do
        local item = load_project_item(root, true)
        local project_root = lower(trim(root))
        local config_path = lower(trim(config_path_for_root(root)))
        if target == project_root
            or target == config_path
            or target == lower(item.name)
            or target == lower(item.packageId)
            or target == lower(basename(root)) then
            return root
        end
    end
    return nil
end

local function normalize_package(context, package, paths)
    local raw = trim(read_field(package, "name") or read_field(package, "packageId") or read_field(package, "path"))
    if raw == "" then
        return nil, "red-cli package name required"
    end
    if is_path_like(raw) or ends_with(lower(raw), ".json") then
        local root, err = normalize_project_root(raw)
        if root == nil then
            return nil, err
        end
        return {
            root = root,
            raw = raw,
        }, nil
    end
    local tracked_root = lookup_tracked_root(paths, raw)
    if tracked_root == nil then
        return nil, "tracked red-cli project not found: " .. raw
    end
    return {
        root = tracked_root,
        raw = raw,
    }, nil
end

local function resolve_info_target(context, raw)
    local query = trim(raw or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt"))
    if query == "" then
        return nil
    end
    local paths = state_paths(data_root_for_context(context))
    if is_path_like(query) or ends_with(lower(query), ".json") then
        local root = normalize_project_root(query)
        return root
    end
    return lookup_tracked_root(paths, query)
end

local function project_command(root, command, flags)
    local args = { command }
    if command == "install" and has_flag(flags, "bundle") then
        args[#args + 1] = "--bundle"
    end
    local inner = "cd \"" .. root:gsub('"', '\\"') .. "\" && " .. REQUIRED_BINARY
    for _, arg in ipairs(args) do
        inner = inner .. " " .. arg
    end
    return COMMAND_ENV_PREFIX .. " /bin/sh -lc " .. shell_quote(inner)
end

local function install_project(context, root, flags)
    begin_step(context, "Install red-cli project")
    local result = exec_run(context, project_command(root, "install", flags))
    if result == nil or result.success ~= true then
        return nil, trim((result and result.stderr) or (result and result.stdout) or "red-cli install failed")
    end
    local item, item_err = load_project_item(root, true)
    if item_err ~= nil and item_err ~= "" then
        return nil, item_err
    end
    return item, nil
end

local function safe_remove_path(path)
    local cleaned = trim(normalize_separators(path))
    if cleaned == "" or cleaned == "/" or cleaned == "." then
        return false
    end
    return true
end

local function remove_project_targets(context, item)
    local targets = sequence_values(read_field(item.extraFields, "installedTargets"))
    if #targets == 0 then
        return false, "game path unavailable for removal"
    end
    begin_step(context, "Remove red-cli project targets")
    for _, target in ipairs(targets) do
        if not safe_remove_path(target) then
            return false, "unsafe remove target: " .. tostring(target)
        end
        local result = exec_run(context, "rm -rf " .. shell_quote(target))
        if result == nil or result.success ~= true then
            return false, trim((result and result.stderr) or (result and result.stdout) or "remove failed")
        end
    end
    return true, nil
end

local function search_results(paths, prompt)
    local query = lower(trim(prompt or ""))
    local results = {}
    for _, root in ipairs(load_tracked_roots(paths)) do
        local item = load_project_item(root, true)
        local haystack = table.concat({
            lower(item.name),
            lower(item.packageId),
            lower(read_field(item.extraFields, "projectRoot") or ""),
            lower(read_field(item.extraFields, "configPath") or ""),
        }, " ")
        if query == "" or haystack:find(query, 1, true) ~= nil then
            results[#results + 1] = item
        end
    end
    return results
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
    return { "red", "red-cli", "modding", "package-manager" }
end

function plugin.getMissingPackages(packages)
    local paths = state_paths(default_data_root())
    local tracked = tracked_set(load_tracked_roots(paths))
    local missing = {}
    for _, pkg in ipairs(packages or {}) do
        local raw = trim(read_field(pkg, "name") or read_field(pkg, "packageId") or read_field(pkg, "path"))
        if raw ~= "" then
            if is_path_like(raw) or ends_with(lower(raw), ".json") then
                local root = normalize_project_root(raw)
                if root ~= nil and not tracked[root] then
                    missing[#missing + 1] = pkg
                end
            elseif lookup_tracked_root(paths, raw) == nil then
                missing[#missing + 1] = pkg
            end
        end
    end
    return missing
end

function plugin.init()
    return true
end

function plugin.install(context, packages)
    local local_path = trim(read_field(context, "localPath") or read_field(read_field(context, "request") or {}, "localPath"))
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message)
    end
    if packages == nil or #packages == 0 then
        tx_success(context)
        return true
    end
    local paths = state_paths(data_root_for_context(context, packages[1]))
    local roots = load_tracked_roots(paths)
    local root_set = tracked_set(roots)
    local installed = {}
    for _, pkg in ipairs(packages or {}) do
        local resolved, err = normalize_package(context, pkg, paths)
        if resolved == nil then
            return package_error(context, err)
        end
        local item, install_err = install_project(context, resolved.root, collect_flags(context, pkg))
        if item == nil then
            return package_error(context, install_err)
        end
        if not root_set[resolved.root] then
            roots[#roots + 1] = resolved.root
            root_set[resolved.root] = true
        end
        installed[#installed + 1] = item
    end
    local ok, err = save_tracked_roots(paths, roots)
    if not ok then
        return package_error(context, err)
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message)
    end
    local root, err = normalize_project_root(path)
    if root == nil then
        return package_error(context, err)
    end
    local paths = state_paths(data_root_for_context(context))
    local item, install_err = install_project(context, root, collect_flags(context, nil))
    if item == nil then
        return package_error(context, install_err, {
            path = root,
            reason = "missing-local-path",
        })
    end
    local roots = load_tracked_roots(paths)
    local root_set = tracked_set(roots)
    if not root_set[root] then
        roots[#roots + 1] = root
    end
    local ok, save_err = save_tracked_roots(paths, roots)
    if not ok then
        return package_error(context, save_err)
    end
    emit_event(context, "installed", { item })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    if packages == nil or #packages == 0 then
        tx_success(context)
        return true
    end
    local paths = state_paths(data_root_for_context(context, packages[1]))
    local roots = load_tracked_roots(paths)
    local kept = {}
    local removed = {}
    local remove_set = {}

    for _, pkg in ipairs(packages or {}) do
        local resolved, err = normalize_package(context, pkg, paths)
        if resolved == nil then
            return package_error(context, err)
        end
        remove_set[resolved.root] = true
        local item = load_project_item(resolved.root, true)
        local ok, remove_err = remove_project_targets(context, item)
        if not ok then
            return package_error(context, remove_err)
        end
        removed[#removed + 1] = item
    end

    for _, root in ipairs(roots) do
        if not remove_set[root] then
            kept[#kept + 1] = root
        end
    end
    local ok, err = save_tracked_roots(paths, kept)
    if not ok then
        return package_error(context, err)
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local available, message = ensure_available(context)
    if not available then
        return package_error(context, message)
    end
    local paths = state_paths(data_root_for_context(context, packages and packages[1] or nil))
    local roots = load_tracked_roots(paths)
    local targets = {}

    if packages ~= nil and #packages > 0 then
        for _, pkg in ipairs(packages) do
            local resolved, err = normalize_package(context, pkg, paths)
            if resolved == nil then
                return package_error(context, err)
            end
            targets[#targets + 1] = {
                root = resolved.root,
                flags = collect_flags(context, pkg),
            }
        end
    else
        local shared_flags = collect_flags(context, nil)
        for _, root in ipairs(roots) do
            targets[#targets + 1] = {
                root = root,
                flags = shared_flags,
            }
        end
    end

    local updated = {}
    for _, target in ipairs(targets) do
        local item, err = install_project(context, target.root, target.flags)
        if item == nil then
            return package_error(context, err)
        end
        updated[#updated + 1] = item
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local paths = state_paths(data_root_for_context(context))
    local results = {}
    for _, root in ipairs(load_tracked_roots(paths)) do
        local item, err = load_project_item(root, true)
        if err ~= nil and err ~= "" then
            log_warn(context, err)
        end
        results[#results + 1] = item
    end
    emit_event(context, "listed", results)
    return results
end

function plugin.outdated(context)
    local results = {}
    emit_event(context, "outdated", results)
    return results
end

function plugin.search(context, prompt)
    local paths = state_paths(data_root_for_context(context))
    local query = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt"))
    local results = search_results(paths, query)
    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local root = resolve_info_target(context, name)
    if root == nil then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local paths = state_paths(data_root_for_context(context))
    local tracked = tracked_set(load_tracked_roots(paths))[root] == true
    local item, err = load_project_item(root, tracked)
    if err ~= nil and err ~= "" and item.status == "missing" then
        log_warn(context, err)
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local paths = state_paths(data_root_for_context(context, package))
    local resolved, err = normalize_package(context, package, paths)
    if resolved == nil then
        return nil, err
    end
    local tracked = tracked_set(load_tracked_roots(paths))[resolved.root] == true
    local item = load_project_item(resolved.root, tracked)
    return item, nil
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "red", "red-cli" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".cache/reqpack/red_cli" },
        },
        networkScopes = {},
        privilegeLevel = "none",
    }
end

function plugin.shutdown()
    return true
end

plugin.fileExtensions = { ".json" }

return plugin
