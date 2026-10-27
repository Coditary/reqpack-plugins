plugin = {}

local PLUGIN_ID = "poetry"
local PLUGIN_NAME = "poetry"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "poetry"
local JSON_NULL = {}

local ADD_BOOLEAN_FLAGS = {
    dev = "--dev",
    optional = "--optional",
    editable = "--editable",
    ["allow-prereleases"] = "--allow-prereleases",
    lock = "--lock",
}

local REMOVE_BOOLEAN_FLAGS = {
    dev = "--dev",
    lock = "--lock",
}

local UPDATE_BOOLEAN_FLAGS = {
    lock = "--lock",
    sync = "--sync",
}

local SHOW_BOOLEAN_FLAGS = {
    ["all-groups"] = "--all-groups",
    ["all-extras"] = "--all-extras",
    ["no-root"] = "--no-root",
    ["no-directory"] = "--no-directory",
}

local ADD_VALUE_FLAGS = {
    group = "--group",
    source = "--source",
    extras = "--extras",
    python = "--python",
    platform = "--platform",
    markers = "--markers",
}

local SHOW_VALUE_FLAGS = {
    ["with"] = "--with",
    ["without"] = "--without",
    only = "--only",
}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= JSON_NULL and value ~= nil then
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

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function command_quote(value)
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,%[%]%^#]+$") then
        return text
    end
    return shell_quote(text)
end

local function split_lines(value)
    local lines = {}
    local text = tostring(value or ""):gsub("\r\n", "\n")
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
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

local function json_value(value)
    if value == JSON_NULL then
        return nil
    end
    return value
end

local function object_flags(object)
    local value = read_field(object, "flags")
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local flags = {}
    local ok = pcall(function()
        for _, flag in ipairs(value) do
            flags[#flags + 1] = trim(flag)
        end
    end)
    if not ok then
        return {}
    end
    return flags
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
        return first
    end

    local result = {}

    local function merge_exec_like(value)
        local probes = { "success", "ok", "stdout", "stderr", "exitCode", "exit_code", "code", "status" }
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
    else
        first, second, third, fourth, fifth = reqpack.exec.run(command)
    end
    return normalize_run_result(first, second, third, fourth, fifth)
end

local function is_command_success(result)
    if type(result) ~= "table" then
        return false
    end
    if result.success == true or result.ok == true then
        return true
    end
    local exit_code = result.exitCode or result.exit_code or result.code or result.status
    return exit_code == 0
end

local function command_exists(context, binary)
    return is_command_success(exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(select(index, ...))
        if part ~= "" then
            if #parts == 0 then
                parts[#parts + 1] = (part:gsub("[/\\]+$", ""))
            else
                parts[#parts + 1] = (part:gsub("^[/\\]+", ""):gsub("[/\\]+$", ""))
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

local function command_ok(ok, _, code)
    if ok == true then
        return true
    end
    if type(ok) == "number" then
        return ok == 0
    end
    return code == 0
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
    return command_ok(ok, kind, code)
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
    local handle = io.open(path, "w")
    if handle == nil and dir ~= nil and dir ~= "" then
        ensure_directory(dir)
        handle = io.open(path, "w")
    end
    if handle == nil then
        return false
    end
    handle:write(content)
    handle:close()
    return true
end

local function remove_file(path)
    if os ~= nil and type(os.remove) == "function" then
        os.remove(path)
    end
end

local function home_dir()
    if os ~= nil and type(os.getenv) == "function" then
        return first_nonempty(os.getenv("HOME"), os.getenv("USERPROFILE"), "/home/test", ".")
    end
    return "/home/test"
end

local function normalize_name(value)
    return lower(trim(value)):gsub("_", "-")
end

local function append_unique(list, value, seen)
    if value == nil then
        return
    end
    local text = trim(value)
    if text == "" then
        return
    end
    if seen[text] then
        return
    end
    seen[text] = true
    list[#list + 1] = text
end

local function collect_raw_flags(context, packages)
    local flags = {}
    local seen = {}

    local function collect_from(object)
        for _, flag in ipairs(object_flags(object)) do
            append_unique(flags, flag, seen)
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
    local prefix = lower(key or "") .. "="
    for _, flag in ipairs(flags or {}) do
        local lowered = lower(flag)
        if lowered:sub(1, #prefix) == prefix then
            return trim(flag:sub(#prefix + 1))
        end
    end
    return nil
end

local function has_flag(flags, key)
    local target = lower(trim(key))
    for _, flag in ipairs(flags or {}) do
        if lower(trim(flag)) == target then
            return true
        end
    end
    return false
end

local function collect_command_flags(context, packages, boolean_flags, value_flags)
    local raw_flags = collect_raw_flags(context, packages)
    local args = {}
    local seen = {}
    local boolean_keys = {}
    local value_keys = {}

    for key in pairs(boolean_flags or {}) do
        boolean_keys[#boolean_keys + 1] = key
    end
    table.sort(boolean_keys)
    for _, key in ipairs(boolean_keys) do
        local option = boolean_flags[key]
        if has_flag(raw_flags, key) then
            append_unique(args, option, seen)
        end
    end

    for key in pairs(value_flags or {}) do
        value_keys[#value_keys + 1] = key
    end
    table.sort(value_keys)
    for _, key in ipairs(value_keys) do
        local option = value_flags[key]
        local value = flag_value(raw_flags, key)
        if value ~= nil and value ~= "" then
            append_unique(args, option, seen)
            append_unique(args, value, seen)
        end
    end

    return args
end

local function working_directory(context, packages)
    local raw_flags = collect_raw_flags(context, packages)
    local explicit = first_nonempty(
        read_field(context, "directory"),
        read_field(context, "dir"),
        read_field(read_field(context, "request"), "directory"),
        read_field(read_field(context, "request"), "dir"),
        flag_value(raw_flags, "dir")
    )
    return trim(explicit or "")
end

local function cache_root(context, packages)
    local raw_flags = collect_raw_flags(context, packages)
    local explicit = flag_value(raw_flags, "cache-root")
    if explicit ~= nil and explicit ~= "" then
        return explicit
    end
    return join_path(home_dir(), ".cache", "reqpack", "poetry")
end

local function shared_paths(context, packages)
    local root = cache_root(context, packages)
    return {
        root = root,
        cache = join_path(root, "cache"),
        config = join_path(root, "config"),
        data = join_path(root, "data"),
        query = join_path(root, "query-project"),
        lock = join_path(root, "query-project", "poetry.lock"),
        pyproject = join_path(root, "query-project", "pyproject.toml"),
    }
end

local function env_prefix(paths)
    return table.concat({
        "POETRY_CACHE_DIR=" .. shell_quote(paths.cache),
        "POETRY_CONFIG_DIR=" .. shell_quote(paths.config),
        "POETRY_DATA_DIR=" .. shell_quote(paths.data),
    }, " ")
end

local function build_poetry_command(context, packages, args, forced_dir)
    local paths = shared_paths(context, packages)
    local parts = { env_prefix(paths), "poetry" }
    local dir = forced_dir or working_directory(context, packages)
    if trim(dir) ~= "" then
        parts[#parts + 1] = "-C"
        parts[#parts + 1] = command_quote(dir)
    end
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = command_quote(arg)
    end
    return table.concat(parts, " "), paths
end

local function package_name(package)
    return trim(read_field(package, "name") or "")
end

local function extract_spec_name(spec)
    local text = trim(spec)
    if text == "" then
        return ""
    end
    local bare = text:gsub("%[.*$", "")
    bare = bare:gsub("==.*$", "")
    bare = bare:gsub("@.*$", "")
    bare = bare:gsub("[<>!=~].*$", "")
    return trim(bare)
end

local function package_spec(package)
    local name = package_name(package)
    local version = trim(read_field(package, "version") or "")
    local package_flags = object_flags(package)
    if name == "" then
        return ""
    end
    if has_flag(package_flags, "latest") or lower(version) == "latest" then
        return extract_spec_name(name) .. "@latest"
    end
    if version == "" then
        return name
    end
    if name:find("==", 1, true) ~= nil or name:find("@", 1, true) ~= nil then
        return name
    end
    if version:sub(1, 2) == "==" then
        return name .. version
    end
    if version:match("^[%^~=!<>]") then
        return name .. "@" .. version
    end
    return name .. "==" .. version
end

local function package_lookup_name(package)
    local spec = package_spec(package)
    if spec == "" then
        spec = package_name(package)
    end
    local name = extract_spec_name(spec)
    if name == "" then
        return ""
    end
    return normalize_name(name)
end

local function requested_group(packages)
    local group = nil
    for _, package in ipairs(packages or {}) do
        local flags = object_flags(package)
        local current = flag_value(flags, "group")
        if current == nil and has_flag(flags, "dev") then
            current = "dev"
        end
        current = trim(current or "")
        if current ~= "" then
            if group == nil then
                group = current
            elseif group ~= current then
                return nil
            end
        end
    end
    return group
end

local function context_packages(context)
    local direct = read_field(context, "packages")
    if type(direct) == "table" then
        return direct
    end

    local request = read_field(context, "request")
    local nested = read_field(request, "packages")
    if type(nested) == "table" then
        return nested
    end

    return nil
end

local function context_requested_group(context, packages)
    local raw_flags = collect_raw_flags(context, packages)
    local explicit = flag_value(raw_flags, "group")
    if explicit ~= nil and explicit ~= "" then
        return explicit
    end
    if has_flag(raw_flags, "dev") then
        return "dev"
    end
    return requested_group(packages)
end

local function package_names(packages)
    local names = {}
    for _, package in ipairs(packages or {}) do
        local name = package_name(package)
        if name ~= "" then
            names[#names + 1] = name
        end
    end
    return names
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
            if current == "," then
                index = index + 1
                skip_whitespace()
            elseif current == "]" then
                index = index + 1
                return result
            else
                decode_error("expected ',' or ']' ")
            end
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
                decode_error("expected ':'")
            end
            index = index + 1
            skip_whitespace()
            local value = parse_value()
            if value == nil then
                result[key] = JSON_NULL
            else
                result[key] = value
            end
            skip_whitespace()
            local current = peek()
            if current == "," then
                index = index + 1
                skip_whitespace()
            elseif current == "}" then
                index = index + 1
                return result
            else
                decode_error("expected ',' or '}'")
            end
        end
    end

    function parse_value()
        skip_whitespace()
        local current = peek()
        if current == '"' then
            return parse_string()
        end
        if current == "{" then
            return parse_object()
        end
        if current == "[" then
            return parse_array()
        end
        if current == "-" or current:match("%d") then
            return parse_number()
        end
        if text:sub(index, index + 3) == "true" then
            index = index + 4
            return true
        end
        if text:sub(index, index + 4) == "false" then
            index = index + 5
            return false
        end
        if text:sub(index, index + 3) == "null" then
            index = index + 4
            return nil
        end
        decode_error("unexpected token")
    end

    local parsed = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("trailing data")
    end
    return parsed
end

local function decode_json(raw)
    local ok, value = pcall(decode_json_internal, raw)
    if not ok then
        return nil, value
    end
    return value, nil
end

local function run_json_command(context, command)
    local result = exec_run(context, command)
    if not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "command failed")
    end
    local payload, err = decode_json(result.stdout)
    if payload == nil then
        return nil, "json decode failed: " .. tostring(err)
    end
    return payload, nil, result
end

local function query_project_toml()
    return table.concat({
        "[tool.poetry]",
        'name = "reqpack-poetry-query"',
        'version = "0.0.0"',
        'description = "ReqPack Poetry query cache"',
        "authors = []",
        "package-mode = false",
        "",
        "[tool.poetry.dependencies]",
        'python = "*"',
        "",
        "[build-system]",
        'requires = ["poetry-core>=1.0.0"]',
        'build-backend = "poetry.core.masonry.api"',
        "",
    }, "\n")
end

local function prepare_query_project(context, packages)
    local paths = shared_paths(context, packages)
    local existing = read_file(paths.pyproject)
    if existing == nil then
        write_file(paths.pyproject, query_project_toml())
    end
    remove_file(paths.lock)
    return paths, nil
end

local function parse_toml_string(value)
    local text = trim(value)
    if text:sub(1, 1) ~= '"' or text:sub(-1) ~= '"' then
        return nil
    end
    local inner = text:sub(2, -2)
    inner = inner:gsub('\\"', '"')
    inner = inner:gsub("\\n", "\n")
    inner = inner:gsub("\\t", "\t")
    inner = inner:gsub("\\r", "\r")
    inner = inner:gsub("\\\\", "\\")
    return inner
end

local function parse_toml_array_of_strings(value)
    local text = trim(value)
    if text:sub(1, 1) ~= "[" or text:sub(-1) ~= "]" then
        return nil
    end
    local values = {}
    for item in text:gmatch('"(.-)"') do
        values[#values + 1] = item
    end
    return values
end

local function parse_inline_file_entry(line)
    local item = {}
    for key, value in line:gmatch('([%w%-_]+)%s*=%s*"([^"]*)"') do
        item[key] = value
    end
    if next(item) == nil then
        return nil
    end
    return item
end

local function parse_poetry_lock(text)
    local packages = {}
    local current = nil
    local section = nil

    local function finish_current()
        if current ~= nil then
            packages[#packages + 1] = current
        end
        current = nil
        section = nil
    end

    for _, raw_line in ipairs(split_lines(text)) do
        local line = trim(raw_line)
        if line == "" or line:sub(1, 1) == "#" then
        elseif line == "[[package]]" then
            finish_current()
            current = {
                groups = {},
                dependencies = {},
                files = {},
                source = {},
            }
        elseif current ~= nil and line == "[package.source]" then
            section = "source"
        elseif current ~= nil and line == "[package.dependencies]" then
            section = "dependencies"
        elseif current ~= nil and line == "files = [" then
            section = "files"
        elseif current ~= nil and section == "files" then
            if line == "]" then
                section = nil
            else
                local entry = parse_inline_file_entry(line)
                if entry ~= nil then
                    current.files[#current.files + 1] = entry
                end
            end
        elseif current ~= nil then
            local key, raw_value = line:match("^([%w%-%._]+)%s*=%s*(.+)$")
            if key ~= nil then
                if section == "source" then
                    local string_value = parse_toml_string(raw_value)
                    current.source[key] = string_value or trim(raw_value)
                elseif section == "dependencies" then
                    local string_value = parse_toml_string(raw_value)
                    current.dependencies[key] = string_value or trim(raw_value)
                elseif key == "name" or key == "version" or key == "description" or key == "python-versions" or key == "license" or key == "homepage" then
                    current[key:gsub("-", "_")] = parse_toml_string(raw_value) or trim(raw_value)
                elseif key == "optional" then
                    current.optional = lower(raw_value) == "true"
                elseif key == "groups" then
                    current.groups = parse_toml_array_of_strings(raw_value) or {}
                elseif key == "files" and trim(raw_value) == "[" then
                    section = "files"
                end
            end
        end
    end

    finish_current()
    return packages
end

local function load_lock_package(paths, spec)
    local content = read_file(paths.lock)
    if content == nil then
        return nil
    end
    local wanted = normalize_name(extract_spec_name(spec))
    for _, item in ipairs(parse_poetry_lock(content)) do
        if normalize_name(item.name) == wanted then
            return item
        end
    end
    return nil
end

local function dependency_map_to_list(value)
    local items = {}
    if type(value) ~= "table" then
        return items
    end
    for key, item in pairs(value) do
        items[#items + 1] = { name = key, constraint = item }
    end
    table.sort(items, function(left, right)
        return left.name < right.name
    end)
    return items
end

local function base_item(name, version, description)
    return {
        name = name,
        packageId = PLUGIN_ID .. ":" .. tostring(name or ""),
        version = version,
        description = description,
        packageType = "python-package",
        manager = PLUGIN_ID,
    }
end

local function package_item_from_show(entry, extras)
    local name = first_nonempty(json_value(read_field(entry, "name")), "")
    local version = first_nonempty(json_value(read_field(entry, "version")), json_value(read_field(entry, "latest_version")), "")
    local item = base_item(name, version, json_value(read_field(entry, "description")))
    item.latestVersion = json_value(read_field(entry, "latest_version"))
    item.extraFields = merge_tables(extras, {
        installedStatus = json_value(read_field(entry, "installed_status")),
    })
    return item
end

local function enrich_project_metadata(context, packages)
    local extras = {}
    local config_command = build_poetry_command(context, packages, { "config", "cache-dir" })
    local config_result = exec_run(context, config_command)
    if is_command_success(config_result) then
        extras.cacheDir = trim(config_result.stdout)
    else
        log_warn(context, first_nonempty(config_result and config_result.stderr, "poetry config cache-dir failed"))
    end

    local env_command = build_poetry_command(context, packages, { "env", "info", "--path" })
    local env_result = exec_run(context, env_command)
    if is_command_success(env_result) then
        extras.virtualEnvPath = trim(env_result.stdout)
    else
        log_warn(context, first_nonempty(env_result and env_result.stderr, "poetry env info --path failed"))
    end

    return extras
end

local function parse_show_list(payload, context, packages)
    local items = {}
    if type(payload) ~= "table" then
        return items
    end
    local extras = enrich_project_metadata(context, packages)
    for _, entry in ipairs(payload) do
        items[#items + 1] = package_item_from_show(entry, extras)
    end
    return items
end

local function parse_search_text(output)
    local items = {}
    for _, line in ipairs(split_lines(output)) do
        local text = trim(line)
        if text ~= "" and not text:match("^Name%s+") and not text:match("^%-+") then
            local name, description = text:match("^([^%s]+)%s+(.+)$")
            if name ~= nil then
                local item = base_item(name, nil, trim(description))
                items[#items + 1] = item
            end
        end
    end
    return items
end

local function find_search_match(items, spec)
    local wanted = normalize_name(extract_spec_name(spec))
    for _, item in ipairs(items or {}) do
        if normalize_name(item.name) == wanted then
            return item
        end
    end
    return nil
end

local function query_project_search(context, spec, paths)
    local command = build_poetry_command(context, nil, { "search", spec }, paths.query)
    local result = exec_run(context, command)
    if not is_command_success(result) then
        return nil
    end
    return parse_search_text(result.stdout)
end

local function lock_item_to_package(lock_item, extras)
    local item = base_item(lock_item.name, lock_item.version, lock_item.description)
    item.extraFields = merge_tables(extras, {
        groups = lock_item.groups,
        dependencies = dependency_map_to_list(lock_item.dependencies),
        files = lock_item.files,
        homepage = lock_item.homepage,
        license = lock_item.license,
        pythonVersions = lock_item.python_versions,
        optional = lock_item.optional,
        sourceType = json_value(read_field(lock_item.source, "type")),
        sourceUrl = json_value(read_field(lock_item.source, "url")),
    })
    item.homepage = lock_item.homepage
    item.license = lock_item.license
    item.sourceUrl = json_value(read_field(lock_item.source, "url"))
    return item
end

local function info_from_query_project(context, spec)
    local paths, err = prepare_query_project(context, nil)
    if paths == nil then
        return nil, err
    end

    local add_command = build_poetry_command(context, nil, { "add", "--no-interaction", "--lock", spec }, paths.query)
    local add_result = exec_run(context, add_command)
    if not is_command_success(add_result) then
        return nil, first_nonempty(add_result and add_result.stderr, add_result and add_result.stdout, "poetry add --lock failed")
    end

    local show_command = build_poetry_command(context, nil, { "show", "--format", "json", extract_spec_name(spec) }, paths.query)
    local payload = select(1, run_json_command(context, show_command))
    if payload ~= nil and type(payload) == "table" then
        local item = package_item_from_show(payload, {
            cacheDir = paths.cache,
            queryProject = paths.query,
            dependencies = dependency_map_to_list(json_value(read_field(payload, "dependencies"))),
            requiredBy = dependency_map_to_list(json_value(read_field(payload, "required_by"))),
        })
        local lock_item = load_lock_package(paths, spec)
        if lock_item ~= nil then
            item.extraFields = merge_tables(item.extraFields, {
                groups = lock_item.groups,
                files = lock_item.files,
                homepage = lock_item.homepage,
                license = lock_item.license,
                pythonVersions = lock_item.python_versions,
                optional = lock_item.optional,
                sourceType = json_value(read_field(lock_item.source, "type")),
                sourceUrl = json_value(read_field(lock_item.source, "url")),
            })
            item.homepage = lock_item.homepage or item.homepage
            item.license = lock_item.license or item.license
            item.sourceUrl = json_value(read_field(lock_item.source, "url")) or item.sourceUrl
        end
        item.sourceUrl = json_value(read_field(payload, "homepage"))
        return item, nil
    end

    local lock_item = load_lock_package(paths, spec)
    if lock_item == nil then
        return nil, "poetry info fallback could not resolve package from shared lock"
    end

    local item = lock_item_to_package(lock_item, {
        cacheDir = paths.cache,
        queryProject = paths.query,
    })
    local search_items = query_project_search(context, extract_spec_name(spec), paths)
    local match = find_search_match(search_items, spec)
    if match ~= nil and first_nonempty(item.description, "") == "" then
        item.description = match.description
    end
    return item, nil
end

local function list_command_payload(context, packages, outdated)
    local args = { "show", "--top-level", "--format", "json" }
    if outdated then
        args[#args + 1] = "--latest"
        args[#args + 1] = "--outdated"
    end
    local extra_flags = collect_command_flags(context, packages, SHOW_BOOLEAN_FLAGS, SHOW_VALUE_FLAGS)
    for _, flag in ipairs(extra_flags) do
        args[#args + 1] = flag
    end
    local package_group = context_requested_group(context, packages)
    if package_group ~= nil and package_group ~= "" then
        args[#args + 1] = "--only"
        args[#args + 1] = package_group
    end
    return run_json_command(context, build_poetry_command(context, packages, args))
end

local function installed_names_map(packages)
    local payload = select(1, list_command_payload(nil, packages, false))
    if type(payload) ~= "table" then
        return nil
    end
    local map = {}
    for _, entry in ipairs(payload) do
        local name = trim(json_value(read_field(entry, "name")) or "")
        if name ~= "" then
            map[normalize_name(name)] = true
        end
    end
    return map
end

local function outdated_names_map(packages)
    local payload = select(1, list_command_payload(nil, packages, true))
    if type(payload) ~= "table" then
        return nil
    end
    local map = {}
    for _, entry in ipairs(payload) do
        local name = trim(json_value(read_field(entry, "name")) or "")
        if name ~= "" then
            map[normalize_name(name)] = true
        end
    end
    return map
end

plugin.fileExtensions = { ".whl", ".tar.gz", ".zip" }

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
    return { "Python", "PyPI", "Poetry", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end
    if not command_exists(nil, REQUIRED_BINARY) then
        return requested
    end

    local saw_explicit_action = false
    for _, package in ipairs(requested) do
        local raw_action = first_nonempty(read_field(package, "action"), read_field(read_field(package, "request"), "action"))
        if raw_action ~= nil then
            saw_explicit_action = true
        end
        local action = lower(raw_action or "install")
        if action ~= "install" and action ~= "remove" and action ~= "update" then
            return requested
        end
    end
    if not saw_explicit_action then
        return requested
    end

    local installed_map = installed_names_map(requested)
    if installed_map == nil then
        return requested
    end

    local outdated_map = outdated_names_map(requested)
    local filtered = {}
    for _, package in ipairs(requested) do
        local action = lower(read_field(package, "action") or read_field(read_field(package, "request"), "action") or "install")
        local name = package_lookup_name(package)
        if name == "" then
            filtered[#filtered + 1] = package
            goto continue
        end
        local installed = installed_map[name] == true
        local outdated = outdated_map ~= nil and outdated_map[name] == true

        if action == "remove" then
            if installed then
                filtered[#filtered + 1] = package
            end
        elseif action == "update" then
            if outdated then
                filtered[#filtered + 1] = package
            end
        elseif not installed then
            filtered[#filtered + 1] = package
        end

        ::continue::
    end
    return filtered
end

function plugin.install(context, packages)
    local local_path = trim(read_field(context, "localPath") or read_field(read_field(context, "request"), "localPath") or "")
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end

    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    begin_step(context, "install Poetry packages")
    for _, package in ipairs(requested) do
        local spec = package_spec(package)
        if spec == "" then
            tx_failed(context, "poetry package name missing")
            return false
        end
        local args = { "add", "--no-interaction" }
        local extra_flags = collect_command_flags(context, { package }, ADD_BOOLEAN_FLAGS, ADD_VALUE_FLAGS)
        for _, flag in ipairs(extra_flags) do
            args[#args + 1] = flag
        end
        args[#args + 1] = spec

        local result = exec_run(context, build_poetry_command(context, { package }, args))
        if not is_command_success(result) then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "poetry install failed"))
            return false
        end
    end

    emit_event(context, "installed", requested)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local target = trim(path)
    if target == "" then
        tx_failed(context, "poetry local install path missing")
        return false
    end

    local args = { "add", "--no-interaction" }
    local extra_flags = collect_command_flags(context, nil, ADD_BOOLEAN_FLAGS, ADD_VALUE_FLAGS)
    for _, flag in ipairs(extra_flags) do
        args[#args + 1] = flag
    end
    args[#args + 1] = target

    begin_step(context, "install local Poetry package")
    local result = exec_run(context, build_poetry_command(context, nil, args))
    if not is_command_success(result) then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "poetry local install failed"))
        return false
    end

    emit_event(context, "installed", { path = target, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    local args = { "remove", "--no-interaction" }
    local extra_flags = collect_command_flags(context, requested, REMOVE_BOOLEAN_FLAGS, ADD_VALUE_FLAGS)
    for _, flag in ipairs(extra_flags) do
        args[#args + 1] = flag
    end
    for _, name in ipairs(package_names(requested)) do
        args[#args + 1] = name
    end

    begin_step(context, "remove Poetry packages")
    local result = exec_run(context, build_poetry_command(context, requested, args))
    if not is_command_success(result) then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "poetry remove failed"))
        return false
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    local args = { "update", "--no-interaction" }
    local extra_flags = collect_command_flags(context, requested, UPDATE_BOOLEAN_FLAGS, SHOW_VALUE_FLAGS)
    for _, flag in ipairs(extra_flags) do
        args[#args + 1] = flag
    end
    for _, name in ipairs(package_names(requested)) do
        args[#args + 1] = name
    end

    begin_step(context, "update Poetry packages")
    local result = exec_run(context, build_poetry_command(context, requested, args))
    if not is_command_success(result) then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "poetry update failed"))
        return false
    end

    emit_event(context, "updated", requested)
    tx_success(context)
    return true
end

function plugin.list(context)
    local request_packages = context_packages(context)
    local payload, err = list_command_payload(context, request_packages, false)
    if payload == nil then
        log_warn(context, err)
        emit_event(context, "listed", {})
        return {}
    end
    local items = parse_show_list(payload, context, request_packages)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local request_packages = context_packages(context)
    local payload, err = list_command_payload(context, request_packages, true)
    if payload == nil then
        log_warn(context, err)
        emit_event(context, "outdated", {})
        return {}
    end
    local items = parse_show_list(payload, context, request_packages)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local spec = trim(prompt)
    if spec == "" then
        emit_event(context, "searched", {})
        return {}
    end

    local paths, err = prepare_query_project(context, nil)
    if paths == nil then
        log_warn(context, err)
        emit_event(context, "searched", {})
        return {}
    end

    local result = exec_run(context, build_poetry_command(context, nil, { "search", spec }, paths.query))
    if not is_command_success(result) then
        local message = first_nonempty(result and result.stderr, result and result.stdout, "poetry search failed")
        log_warn(context, message)
        emit_event(context, "searched", {})
        return {}
    end

    local items = parse_search_text(result.stdout)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local spec = trim(name)
    if spec == "" then
        emit_event(context, "informed", {})
        return {}
    end

    local item, err = info_from_query_project(context, spec)
    if item == nil then
        log_warn(context, err)
        emit_event(context, "informed", {})
        return {}
    end

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end
    local spec = package_spec(package)
    if spec == "" then
        return nil
    end
    local item = plugin.info(context, spec)
    if type(item) ~= "table" or next(item) == nil then
        return nil
    end
    return {
        name = item.name,
        packageId = item.packageId,
        version = item.version,
        description = item.description,
        sourceUrl = item.sourceUrl,
        extraFields = item.extraFields,
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "python", "pypi", "poetry" },
        writeScopes = {
            { kind = "temp" },
            { kind = "user-home-subpath", value = ".cache/reqpack/poetry" },
            { kind = "user-home-subpath", value = ".config/pypoetry" },
            { kind = "user-home-subpath", value = ".local/share/pypoetry" },
        },
        networkScopes = {
            { host = "pypi.org", scheme = "https", pathPrefix = "/" },
            { host = "files.pythonhosted.org", scheme = "https", pathPrefix = "/" },
        },
        privilegeLevel = "user",
        osvEcosystem = "PyPI",
        purlType = "pypi",
        versionComparatorProfile = "pep440",
    }
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

return plugin
