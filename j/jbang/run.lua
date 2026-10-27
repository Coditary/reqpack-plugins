plugin = {}

local PLUGIN_ID = "jbang"
local PLUGIN_NAME = "JBang"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "jbang"
local JSON_NULL = {}
local APP_LIST_COMMAND = "jbang app list --format json"
local ALIAS_LIST_COMMAND = "jbang alias list --format json"
local JBANG_ROOT_EXPR = '"${JBANG_DIR:-$HOME/.jbang}"'
local JBANG_BIN_EXPR = '"${JBANG_DIR:-$HOME/.jbang}/bin/"'

plugin.fileExtensions = {
    ".java",
    ".jsh",
    ".kt",
    ".kts",
    ".groovy",
    ".gvy",
    ".md",
    ".jar",
}

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

local function first_non_empty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        local cleaned = non_empty(value)
        if cleaned ~= nil then
            return cleaned
        end
    end
    return nil
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function split_lines(value)
    local lines = {}
    for line in tostring(value or ""):gmatch("[^\r\n]+") do
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

local function exec_run(context, command)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return context.exec.run(command)
    end
    return reqpack.exec.run(command)
end

local function command_exists(binary)
    local result = reqpack.exec.run("command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function codepoint_to_utf8(codepoint)
    if codepoint <= 0x7F then
        return string.char(codepoint)
    end
    if codepoint <= 0x7FF then
        return string.char(
            0xC0 + math.floor(codepoint / 0x40),
            0x80 + (codepoint % 0x40)
        )
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

        if peek() == "-" then
            index = index + 1
        end

        local current = peek()
        if current == "0" then
            index = index + 1
        elseif current:match("%d") then
            repeat
                index = index + 1
                current = peek()
            until current == "" or current:match("%d") == nil
        else
            decode_error("invalid number")
        end

        if peek() == "." then
            index = index + 1
            if peek():match("%d") == nil then
                decode_error("invalid fraction")
            end
            repeat
                index = index + 1
                current = peek()
            until current == "" or current:match("%d") == nil
        end

        current = peek()
        if current == "e" or current == "E" then
            index = index + 1
            current = peek()
            if current == "+" or current == "-" then
                index = index + 1
            end
            if peek():match("%d") == nil then
                decode_error("invalid exponent")
            end
            repeat
                index = index + 1
                current = peek()
            until current == "" or current:match("%d") == nil
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

local function normalize_flags(flags)
    local result = {}
    if type(flags) == "table" then
        for _, flag in ipairs(flags) do
            local text = trim(flag)
            if text ~= "" then
                result[#result + 1] = text
            end
        end
    elseif type(flags) == "string" then
        local text = trim(flags)
        if text ~= "" then
            result[#result + 1] = text
        end
    end
    return result
end

local function flag_value(package, key)
    for _, flag in ipairs(normalize_flags(read_field(package, "flags"))) do
        local flag_key, flag_val = flag:match("^([^=]+)=(.+)$")
        if flag_key == key then
            return trim(flag_val)
        end
    end
    return nil
end

local function has_flag(package, key)
    for _, flag in ipairs(normalize_flags(read_field(package, "flags"))) do
        if flag == key then
            return true
        end
    end
    return false
end

local function package_action(package)
    return lower(read_field(package, "action") or "install")
end

local function local_path_from_context(context)
    local request = read_field(context, "request") or {}
    return trim(read_field(context, "localPath") or read_field(request, "localPath") or "")
end

local function join_command(parts)
    return table.concat(parts, " ")
end

local function append_arg(parts, value)
    parts[#parts + 1] = shell_quote(value)
end

local function append_option(parts, name, value)
    parts[#parts + 1] = name
    append_arg(parts, value)
end

local function looks_like_url(value)
    local cleaned = trim(value)
    return cleaned:match("^https?://") ~= nil
end

local function looks_like_gav(value)
    local cleaned = trim(value)
    if cleaned:find("://", 1, true) ~= nil then
        return false
    end
    local first, second, third = cleaned:match("^([^:]+):([^:]+):([^:]+)$")
    return first ~= nil and second ~= nil and third ~= nil
end

local function basename(value)
    local cleaned = trim(value)
    cleaned = cleaned:gsub("[?#].*$", "")
    return cleaned:match("([^/\\]+)$") or cleaned
end

local function strip_known_extension(value)
    return tostring(value or ""):gsub("(%.[^.]+)$", "")
end

local function default_command_name_from_ref(ref)
    local cleaned = trim(ref)
    if cleaned == "" then
        return nil
    end
    if cleaned:find("@", 1, true) ~= nil and not looks_like_url(cleaned) then
        return trim(cleaned:match("^([^@]+)@") or cleaned)
    end
    if looks_like_gav(cleaned) then
        local _, artifact = cleaned:match("^([^:]+):([^:]+):[^:]+$")
        return trim(artifact or cleaned)
    end
    return strip_known_extension(basename(cleaned))
end

local function version_from_ref(ref)
    local cleaned = trim(ref)
    if looks_like_gav(cleaned) then
        return cleaned:match("^[^:]+:[^:]+:([^:]+)$")
    end
    local tag = cleaned:match("/blob/([^/]+)/") or cleaned:match("/raw/([^/]+)/")
    return non_empty(tag)
end

local function package_type_for_ref(ref)
    local cleaned = trim(ref)
    if cleaned == "" then
        return "app"
    end
    if cleaned:find("@", 1, true) ~= nil and not looks_like_url(cleaned) then
        return "alias"
    end
    if looks_like_gav(cleaned) then
        return "gav"
    end
    if looks_like_url(cleaned) then
        return "url"
    end
    if lower(cleaned):match("%.jar$") then
        return "jar"
    end
    return "script"
end

local function resolved_jbang_home()
    return "$HOME/.jbang"
end

local function resolved_jbang_cache_dir()
    return resolved_jbang_home() .. "/cache"
end

local function resolved_jbang_bin_dir()
    return resolved_jbang_home() .. "/bin"
end

local function parse_shell_words(text)
    local tokens = {}
    local current = {}
    local state = "plain"
    local index = 1
    local length = #text

    local function push_current()
        if #current > 0 then
            tokens[#tokens + 1] = table.concat(current)
            current = {}
        end
    end

    while index <= length do
        local char = text:sub(index, index)
        if state == "plain" then
            if char:match("%s") then
                push_current()
            elseif char == "'" then
                state = "single"
            elseif char == '"' then
                state = "double"
            elseif char == "\\" and index < length then
                index = index + 1
                current[#current + 1] = text:sub(index, index)
            else
                current[#current + 1] = char
            end
        elseif state == "single" then
            if char == "'" then
                state = "plain"
            else
                current[#current + 1] = char
            end
        else
            if char == '"' then
                state = "plain"
            elseif char == "\\" and index < length then
                index = index + 1
                current[#current + 1] = text:sub(index, index)
            else
                current[#current + 1] = char
            end
        end
        index = index + 1
    end
    push_current()
    return tokens
end

local OPTIONS_WITH_VALUE = {
    ["-T"] = true,
    ["-j"] = true,
    ["-m"] = true,
    ["-s"] = true,
    ["-R"] = true,
    ["-C"] = true,
    ["-N"] = true,
    ["-d"] = true,
    ["--build-dir"] = true,
    ["--catalog"] = true,
    ["--config"] = true,
    ["--cp"] = true,
    ["--class-path"] = true,
    ["--debug"] = true,
    ["--deps"] = true,
    ["--files"] = true,
    ["--java"] = true,
    ["--javaagent"] = true,
    ["--jfr"] = true,
    ["--main"] = true,
    ["--manifest"] = true,
    ["--module"] = true,
    ["--repos"] = true,
    ["--runtime-option"] = true,
    ["--source-type"] = true,
    ["--sources"] = true,
}

local function parse_wrapper_descriptor(command_name, text)
    local shell_line = nil
    for _, line in ipairs(split_lines(text)) do
        if trim(line):match("^exec%s+jbang%s+run%s+") then
            shell_line = trim(line)
            break
        end
    end
    if shell_line == nil then
        return nil
    end

    local tokens = parse_shell_words(shell_line)
    if #tokens < 4 or tokens[1] ~= "exec" or tokens[2] ~= "jbang" or tokens[3] ~= "run" then
        return nil
    end

    local run_options = {}
    local run_args = {}
    local script_ref = nil
    local index = 4
    while index <= #tokens do
        local token = tokens[index]
        if token == "$@" then
            break
        end

        if script_ref == nil then
            if token == "--" then
                index = index + 1
                script_ref = tokens[index]
            elseif token:sub(1, 1) ~= "-" then
                script_ref = token
            else
                run_options[#run_options + 1] = token
                if token:match("^%-%-.-=") or token:match("^%-[%w]=$") or token:match("^%-D.+") then
                    -- value already embedded
                elseif OPTIONS_WITH_VALUE[token] and index + 1 <= #tokens and tokens[index + 1] ~= "$@" then
                    run_options[#run_options + 1] = tokens[index + 1]
                    index = index + 1
                end
            end
        else
            run_args[#run_args + 1] = token
        end
        index = index + 1
    end

    if script_ref == nil then
        return nil
    end

    return {
        commandName = command_name,
        scriptRef = script_ref,
        runOptions = run_options,
        runArgs = run_args,
    }
end

local function decode_json_result(raw)
    local decoded, err = decode_json(raw)
    if decoded == nil then
        return nil, err
    end
    return decoded, nil
end

local function parse_app_list_output(raw)
    local decoded = select(1, decode_json_result(raw))
    if type(decoded) ~= "table" then
        return {}
    end
    local names = {}
    for _, item in ipairs(decoded) do
        local name = non_empty(json_value(read_field(item, "name")))
        if name ~= nil then
            names[#names + 1] = name
        end
    end
    return names
end

local function parse_alias_list_output(raw)
    local decoded = select(1, decode_json_result(raw))
    if type(decoded) ~= "table" then
        return {}
    end
    return decoded
end

local function query_installed_names(context)
    local result = exec_run(context, APP_LIST_COMMAND)
    if result == nil or not result.success then
        return nil
    end
    return parse_app_list_output(result.stdout)
end

local function query_aliases(context)
    local result = exec_run(context, ALIAS_LIST_COMMAND)
    if result == nil or not result.success then
        return {}
    end
    return parse_alias_list_output(result.stdout)
end

local function read_wrapper_script(context, command_name)
    local command = "cat " .. JBANG_BIN_EXPR .. shell_quote(command_name)
    local result = exec_run(context, command)
    if result == nil or not result.success then
        return nil
    end
    return result.stdout
end

local function read_wrapper_descriptor(context, command_name)
    local text = read_wrapper_script(context, command_name)
    if text == nil then
        return nil
    end
    return parse_wrapper_descriptor(command_name, text)
end

local function alias_install_ref(alias)
    return first_non_empty(
        json_value(read_field(alias, "fullName")),
        json_value(read_field(alias, "name"))
    )
end

local function alias_matches_name(alias, name)
    local cleaned = lower(name)
    return cleaned == lower(json_value(read_field(alias, "name")) or "")
        or cleaned == lower(json_value(read_field(alias, "fullName")) or "")
        or cleaned == lower(json_value(read_field(alias, "scriptRef")) or "")
end

local function find_alias_for_descriptor(aliases, descriptor)
    local command_name = lower(read_field(descriptor, "commandName") or "")
    local script_ref = lower(read_field(descriptor, "scriptRef") or "")
    for _, alias in ipairs(aliases or {}) do
        local alias_name = lower(json_value(read_field(alias, "name")) or "")
        local full_name = lower(json_value(read_field(alias, "fullName")) or "")
        local alias_script_ref = lower(json_value(read_field(alias, "scriptRef")) or "")
        if script_ref ~= "" and (script_ref == alias_script_ref or script_ref == full_name) then
            return alias
        end
        if command_name ~= "" and (command_name == alias_name or command_name == full_name) then
            return alias
        end
    end
    return nil
end

local function find_alias(aliases, identifier)
    local cleaned = trim(identifier)
    if cleaned == "" then
        return nil
    end
    for _, alias in ipairs(aliases or {}) do
        if alias_matches_name(alias, cleaned) then
            return alias
        end
    end
    return nil
end

local function make_extra_fields(source)
    local extra = shallow_copy(type(source) == "table" and source or {})
    extra.jbangHome = resolved_jbang_home()
    extra.jbangCacheDir = resolved_jbang_cache_dir()
    extra.jbangBinDir = resolved_jbang_bin_dir()
    return extra
end

local function alias_to_item(alias)
    local install_ref = alias_install_ref(alias)
    local script_ref = json_value(read_field(alias, "scriptRef"))
    local description = json_value(read_field(alias, "description"))
    local extra = make_extra_fields({
        aliasName = json_value(read_field(alias, "name")),
        catalogName = json_value(read_field(alias, "catalogName")),
        scriptRef = script_ref,
        installRef = install_ref,
        javaVersion = json_value(read_field(alias, "javaVersion")),
        mainClass = json_value(read_field(alias, "mainClass")),
    })
    return {
        name = install_ref,
        packageId = install_ref,
        version = version_from_ref(script_ref),
        latestVersion = version_from_ref(script_ref),
        summary = description or install_ref,
        description = description,
        sourceUrl = looks_like_url(script_ref or "") and script_ref or nil,
        installed = false,
        status = "available",
        packageType = "alias",
        type = "package",
        extraFields = extra,
    }
end

local function installed_item_from_descriptor(descriptor, alias)
    local script_ref = read_field(descriptor, "scriptRef")
    local command_name = read_field(descriptor, "commandName")
    local description = alias ~= nil and json_value(read_field(alias, "description")) or nil
    local extra = make_extra_fields({
        commandName = command_name,
        installRef = alias ~= nil and alias_install_ref(alias) or script_ref,
        scriptRef = script_ref,
        wrapperScriptRef = script_ref,
        runOptions = table.concat(read_field(descriptor, "runOptions") or {}, " "),
        runArguments = table.concat(read_field(descriptor, "runArgs") or {}, " "),
        javaVersion = alias ~= nil and json_value(read_field(alias, "javaVersion")) or nil,
        mainClass = alias ~= nil and json_value(read_field(alias, "mainClass")) or nil,
    })
    return {
        name = command_name,
        packageId = command_name,
        version = version_from_ref(script_ref),
        latestVersion = version_from_ref(script_ref),
        summary = description or script_ref or command_name,
        description = description,
        sourceUrl = looks_like_url(script_ref or "") and script_ref or nil,
        installed = true,
        status = "installed",
        packageType = package_type_for_ref(script_ref or ""),
        type = "package",
        extraFields = extra,
    }
end

local function minimal_installed_item(command_name)
    return {
        name = command_name,
        packageId = command_name,
        summary = command_name,
        installed = true,
        status = "installed",
        packageType = "app",
        type = "package",
        extraFields = make_extra_fields({ commandName = command_name }),
    }
end

local function sort_items(items)
    table.sort(items, function(left, right)
        return lower(left.name or left.packageId or "") < lower(right.name or right.packageId or "")
    end)
    return items
end

local function list_installed_items(context)
    local names = query_installed_names(context)
    if names == nil then
        return {}
    end

    local aliases = query_aliases(context)
    local items = {}
    for _, command_name in ipairs(names) do
        local descriptor = read_wrapper_descriptor(context, command_name)
        if descriptor ~= nil then
            items[#items + 1] = installed_item_from_descriptor(descriptor, find_alias_for_descriptor(aliases, descriptor))
        else
            items[#items + 1] = minimal_installed_item(command_name)
        end
    end
    return sort_items(items)
end

local function matches_prompt(alias, prompt)
    local query = lower(prompt)
    local fields = {
        json_value(read_field(alias, "name")),
        json_value(read_field(alias, "fullName")),
        json_value(read_field(alias, "scriptRef")),
        json_value(read_field(alias, "description")),
    }
    for _, value in ipairs(fields) do
        if lower(value or ""):find(query, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function requested_install_ref(package)
    local extra = type(read_field(package, "extraFields")) == "table" and read_field(package, "extraFields") or {}
    return first_non_empty(
        json_value(read_field(extra, "installRef")),
        json_value(read_field(extra, "scriptRef")),
        read_field(package, "sourcePath"),
        read_field(package, "sourceUrl"),
        read_field(package, "packageId"),
        read_field(package, "name")
    )
end

local function requested_command_name(package)
    return first_non_empty(
        flag_value(package, "name"),
        type(read_field(package, "extraFields")) == "table" and json_value(read_field(read_field(package, "extraFields"), "commandName")) or nil,
        default_command_name_from_ref(requested_install_ref(package) or ""),
        read_field(package, "name")
    )
end

local function build_install_descriptor_from_package(package)
    local install_ref = requested_install_ref(package)
    if install_ref == nil then
        return nil
    end

    local extra = type(read_field(package, "extraFields")) == "table" and read_field(package, "extraFields") or {}
    local descriptor = {
        commandName = requested_command_name(package),
        scriptRef = first_non_empty(json_value(read_field(extra, "wrapperScriptRef")), json_value(read_field(extra, "scriptRef")), install_ref),
        runOptions = {},
        runArgs = {},
    }

    return descriptor
end

local function add_generated_install_flags(parts, package)
    local command_name = flag_value(package, "name")
    if command_name ~= nil then
        append_option(parts, "--name", command_name)
    end

    local java_version = flag_value(package, "java")
    if java_version ~= nil then
        append_option(parts, "--java", java_version)
    end

    local main_class = flag_value(package, "main")
    if main_class ~= nil then
        append_option(parts, "--main", main_class)
    end

    local catalog_path = flag_value(package, "catalog")
    if catalog_path ~= nil then
        append_option(parts, "--catalog", catalog_path)
    end

    local source_type = flag_value(package, "source-type") or flag_value(package, "type")
    if source_type ~= nil then
        append_option(parts, "--source-type", source_type)
    end

    if has_flag(package, "native") then
        parts[#parts + 1] = "--native"
    end
    if has_flag(package, "preview") then
        parts[#parts + 1] = "--enable-preview"
    end
    if has_flag(package, "interactive") then
        parts[#parts + 1] = "--interactive"
    end
    if has_flag(package, "no-build") then
        parts[#parts + 1] = "--no-build"
    end
    if has_flag(package, "fresh") then
        parts[#parts + 1] = "--fresh"
    end
    if has_flag(package, "offline") then
        parts[#parts + 1] = "--offline"
    end
    if has_flag(package, "insecure") then
        parts[#parts + 1] = "--insecure"
    end
end

local function build_install_command_for_descriptor(descriptor, package, force, include_name)
    local parts = { "jbang", "app", "install" }
    if force then
        parts[#parts + 1] = "--force"
    end

    if include_name and non_empty(read_field(descriptor, "commandName")) ~= nil then
        append_option(parts, "--name", read_field(descriptor, "commandName"))
    elseif package ~= nil then
        add_generated_install_flags(parts, package)
    end

    if include_name then
        for _, token in ipairs(read_field(descriptor, "runOptions") or {}) do
            parts[#parts + 1] = token
        end
    end

    append_arg(parts, read_field(descriptor, "scriptRef"))

    if include_name then
        for _, token in ipairs(read_field(descriptor, "runArgs") or {}) do
            append_arg(parts, token)
        end
    end

    return join_command(parts)
end

local function install_command_for_package(package)
    local descriptor = build_install_descriptor_from_package(package)
    if descriptor == nil then
        return nil
    end
    return build_install_command_for_descriptor(descriptor, package, has_flag(package, "force"), false)
end

local function installed_name_set(context)
    local names = query_installed_names(context)
    if names == nil then
        return nil
    end
    local result = {}
    for _, name in ipairs(names) do
        result[name] = true
    end
    return result
end

local function resolve_installed_descriptor(context, package)
    local command_name = requested_command_name(package)
    if command_name ~= nil then
        local descriptor = read_wrapper_descriptor(context, command_name)
        if descriptor ~= nil then
            return descriptor
        end
    end

    local descriptor = build_install_descriptor_from_package(package)
    if descriptor ~= nil then
        return descriptor
    end
    return nil
end

local function run_mutation_commands(context, step_label, packages, command_builder, event_name)
    if packages == nil or #packages == 0 then
        return true
    end

    begin_step(context, step_label)
    for _, package in ipairs(packages) do
        local command = command_builder(package)
        if command == nil then
            tx_failed(context, "jbang command could not be resolved")
            return false
        end

        local result = exec_run(context, command)
        if result == nil or not result.success then
            tx_failed(context, "jbang command failed")
            return false
        end
    end

    emit_event(context, event_name, packages)
    tx_success(context)
    return true
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
    return { "JVM", "Java", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end

    local installed = installed_name_set(nil)
    if installed == nil then
        return packages
    end

    local filtered = {}
    for _, package in ipairs(packages) do
        local command_name = requested_command_name(package)
        local is_installed = command_name ~= nil and installed[command_name] == true
        local action = package_action(package)

        if action == "remove" or action == "update" then
            if is_installed then
                filtered[#filtered + 1] = package
            end
        elseif not is_installed then
            filtered[#filtered + 1] = package
        end
    end

    return filtered
end

function plugin.install(context, packages)
    local local_path = local_path_from_context(context)
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end

    return run_mutation_commands(
        context,
        "install jbang apps",
        packages,
        install_command_for_package,
        "installed"
    )
end

function plugin.installLocal(context, path)
    local cleaned_path = trim(path)
    if cleaned_path == "" then
        tx_failed(context, "local JBang path is required")
        return false
    end

    begin_step(context, "install local jbang app")
    local result = exec_run(context, "jbang app install " .. shell_quote(cleaned_path))
    if result == nil or not result.success then
        tx_failed(context, "jbang local install failed")
        return false
    end

    emit_event(context, "installed", { path = cleaned_path, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    return run_mutation_commands(
        context,
        "remove jbang apps",
        packages,
        function(package)
            local command_name = requested_command_name(package)
            if command_name == nil then
                return nil
            end
            return "jbang app uninstall " .. shell_quote(command_name)
        end,
        "deleted"
    )
end

function plugin.update(context, packages)
    local targets = packages
    if targets == nil or #targets == 0 then
        targets = {}
        for _, item in ipairs(list_installed_items(context)) do
            targets[#targets + 1] = item
        end
        if #targets == 0 then
            return true
        end
    end

    begin_step(context, "update jbang apps")
    for _, package in ipairs(targets) do
        local descriptor = resolve_installed_descriptor(context, package)
        if descriptor == nil then
            tx_failed(context, "jbang update target could not be resolved")
            return false
        end

        local command = build_install_command_for_descriptor(descriptor, package, true, true)
        local result = exec_run(context, command)
        if result == nil or not result.success then
            tx_failed(context, "jbang update failed")
            return false
        end
    end

    emit_event(context, "updated", targets)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = list_installed_items(context)
    if #items == 0 then
        log_warn(context, "jbang app list returned no installed apps or query failed")
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items = {}
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned_prompt = trim(prompt)
    if cleaned_prompt == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local items = {}
    for _, alias in ipairs(query_aliases(context)) do
        if matches_prompt(alias, cleaned_prompt) then
            items[#items + 1] = alias_to_item(alias)
        end
    end
    sort_items(items)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local identifier = trim(name)
    if identifier == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local descriptor = read_wrapper_descriptor(context, identifier)
    local aliases = query_aliases(context)
    if descriptor ~= nil then
        local item = installed_item_from_descriptor(descriptor, find_alias_for_descriptor(aliases, descriptor))
        emit_event(context, "informed", item)
        return item
    end

    local alias = find_alias(aliases, identifier)
    if alias ~= nil then
        local item = alias_to_item(alias)
        emit_event(context, "informed", item)
        return item
    end

    local empty = {}
    emit_event(context, "informed", empty)
    return empty
end

function plugin.resolvePackage(context, package)
    local installed_items = list_installed_items(context)
    local command_name = requested_command_name(package)
    for _, item in ipairs(installed_items) do
        if lower(item.name or "") == lower(command_name or "") then
            return item
        end
    end

    local alias = find_alias(query_aliases(context), requested_install_ref(package) or "")
    if alias ~= nil then
        return alias_to_item(alias)
    end
    return nil
end

function plugin.init()
    return command_exists(REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "jbang", "java", "jvm" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".jbang" },
            { kind = "user-home-subpath", value = ".jbang/cache" },
            { kind = "user-home-subpath", value = ".jbang/bin" },
        },
        networkScopes = { "*" },
        privilegeLevel = "user",
        osvEcosystem = "Generic",
        purlType = "generic",
        versionComparatorProfile = "lexicographic",
    }
end

return plugin
