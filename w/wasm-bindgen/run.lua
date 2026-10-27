plugin = {}

local PLUGIN_ID = "wasm-bindgen"
local PLUGIN_NAME = "wasm-bindgen"
local PLUGIN_VERSION = "0.1.0"
local TOOL_PACKAGE = "wasm-bindgen-cli"
local TOOL_BINARY = "wasm-bindgen"
local CARGO_BINARY = "cargo"
local DEFAULT_TARGET = "bundler"
local JSON_NULL = {}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return trim(value):lower()
end

local function starts_with(value, prefix)
    local text = tostring(value or "")
    local wanted = tostring(prefix or "")
    return wanted == "" or text:sub(1, #wanted) == wanted
end

local function ends_with(value, suffix)
    local text = tostring(value or "")
    local wanted = tostring(suffix or "")
    return wanted ~= "" and text:sub(-#wanted) == wanted
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function shell_arg(value)
    local text = trim(value)
    if text == "" then
        return "''"
    end
    if text:match("^[%w%+%-%._/%:@=,]+$") then
        return text
    end
    return shell_quote(text)
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim((tostring(select(index, ...) or ""):gsub("\\", "/")))
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

local function dirname(path)
    local text = trim((tostring(path or ""):gsub("\\", "/"))):gsub("/+$", "")
    local dir = text:match("^(.*)/[^/]+$")
    if dir ~= nil and dir ~= "" then
        return dir
    end
    return "."
end

local function basename(path)
    local text = trim((tostring(path or ""):gsub("\\", "/"))):gsub("/+$", "")
    return text:match("([^/]+)$") or text
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

local function read_flags(object)
    local flags = {}
    for _, item in ipairs(sequence_values(read_field(object, "flags"))) do
        local text = trim(item)
        if text ~= "" then
            flags[#flags + 1] = text
        end
    end
    return flags
end

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        return os.getenv(name)
    end
    return nil
end

local function fixture_root()
    return trim(getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
end

local function expand_runtime_placeholders(value)
    local text = tostring(value or "")
    local root = fixture_root()
    if root ~= "" then
        local needle = "${fixtureRoot}"
        local start_index = 1
        while true do
            local first, last = text:find(needle, start_index, true)
            if first == nil then
                break
            end
            text = text:sub(1, first - 1) .. root .. text:sub(last + 1)
            start_index = first + #root
        end
    end
    return text
end

local function resolve_fs_path(path)
    local text = expand_runtime_placeholders(path)
    if fixture_root() == "" then
        local prefix = "${fixtureRoot}/"
        if starts_with(text, prefix) then
            return text:sub(#prefix + 1)
        end
        if text == "${fixtureRoot}" then
            return "."
        end
    end
    return text
end

local function collect_flags(context, package)
    local flags = {}
    local seen = {}
    local function collect(object)
        for _, flag in ipairs(read_flags(object)) do
            local expanded = expand_runtime_placeholders(flag)
            if not seen[expanded] then
                seen[expanded] = true
                flags[#flags + 1] = expanded
            end
        end
    end
    collect(context)
    collect(read_field(context, "request"))
    collect(package)
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
        local text = trim(flag)
        if lower(text):sub(1, #prefix) == prefix then
            return trim(text:sub(#prefix + 1))
        end
    end
    return ""
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
    if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
        return reqpack.exec.run(command)
    end
    return {
        success = false,
        stdout = "",
        stderr = "missing ReqPack exec runner",
        exitCode = 127,
    }
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. binary .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function get_reqpack_path(name)
    local paths = type(reqpack) == "table" and read_field(reqpack, "paths") or nil
    if type(paths) ~= "table" then
        return nil
    end
    return trim(read_field(paths, name) or "")
end

local function default_cache_root()
    local root = fixture_root()
    if root ~= "" then
        return join_path(root, ".reqpack-data", PLUGIN_ID)
    end
    local data_root = get_reqpack_path("dataRoot")
    if data_root ~= "" then
        return join_path(data_root, PLUGIN_ID)
    end
    local home = trim(getenv("HOME") or "")
    if home ~= "" then
        return join_path(home, ".cache", "reqpack", PLUGIN_ID)
    end
    return join_path(".", ".reqpack-data", PLUGIN_ID)
end

local function cache_root_for(context, package)
    local flags = collect_flags(context, package)
    local override = flag_value(flags, "cache-root")
    if override == "" then
        override = flag_value(flags, "data-root")
    end
    if override ~= "" then
        return expand_runtime_placeholders(override)
    end
    return default_cache_root()
end

local function generated_root(cache_root)
    return join_path(cache_root, "generated")
end

local function candidate_cache_roots(context, package)
    local roots = {}
    local seen = {}
    local function add(path)
        local cleaned = trim(path)
        if cleaned ~= "" and not seen[cleaned] then
            seen[cleaned] = true
            roots[#roots + 1] = cleaned
        end
    end
    add(cache_root_for(context, package))
    add(join_path(".", ".reqpack-data", PLUGIN_ID))
    return roots
end

local function path_exists(path)
    local cleaned = resolve_fs_path(path)
    local file = io.open(cleaned, "rb")
    if file ~= nil then
        file:close()
        return true
    end
    local dir = io.open(join_path(cleaned, "."), "rb")
    if dir ~= nil then
        dir:close()
        return true
    end
    return false
end

local function ensure_directory(path)
    local cleaned = resolve_fs_path(path)
    if cleaned == "" or cleaned == "." then
        return true
    end
    if os ~= nil and type(os.execute) == "function" then
        local ok = os.execute("mkdir -p " .. shell_quote(cleaned))
        if ok == true or ok == 0 then
            return true
        end
    end
    return true
end

local function read_file(path)
    local cleaned = resolve_fs_path(path)
    local handle = io.open(cleaned, "rb")
    if handle == nil then
        local result = exec_run(nil, "cat " .. shell_quote(path))
        if result ~= nil and result.success == true then
            return result.stdout or ""
        end
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(path, content)
    local cleaned = resolve_fs_path(path)
    if not ensure_directory(dirname(cleaned)) then
        return false
    end
    local handle = io.open(cleaned, "wb")
    if handle == nil then
        return false
    end
    handle:write(content)
    handle:close()
    return true
end

local function remove_path(path)
    local cleaned = resolve_fs_path(path)
    if not path_exists(cleaned) then
        return true
    end
    if os ~= nil and type(os.execute) == "function" then
        local ok = os.execute("rm -rf " .. shell_quote(cleaned))
        return ok == true or ok == 0
    end
    return false
end

local function normalize_token(value)
    return tostring(value or ""):gsub("\\", "/"):gsub("/", "__"):gsub("[^%w%._%-]+", "_")
end

local function split_lines(value)
    local lines = {}
    local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then
            lines[#lines + 1] = line
        end
    end
    return lines
end

local function sorted_keys(value)
    local keys = {}
    for key in pairs(value or {}) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)
    return keys
end

local function is_array_table(value)
    if type(value) ~= "table" then
        return false
    end
    local max_index = 0
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or math.floor(key) ~= key then
            return false
        end
        if key > max_index then
            max_index = key
        end
        count = count + 1
    end
    return max_index == count
end

local function encode_json_string(value)
    local text = tostring(value or "")
    local replacements = {
        ["\\"] = "\\\\",
        ['"'] = '\\"',
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
    }
    return '"' .. text:gsub('[%z\1-\31\\"]', function(char)
        return replacements[char] or string.format("\\u%04x", string.byte(char))
    end) .. '"'
end

local function encode_json(value)
    local value_type = type(value)
    if value == nil or value == JSON_NULL then
        return "null"
    end
    if value_type == "string" then
        return encode_json_string(value)
    end
    if value_type == "number" or value_type == "boolean" then
        return tostring(value)
    end
    if value_type ~= "table" then
        return encode_json_string(tostring(value))
    end
    if is_array_table(value) then
        local items = {}
        for index = 1, #value do
            items[#items + 1] = encode_json(value[index])
        end
        return "[" .. table.concat(items, ",") .. "]"
    end
    local pairs_json = {}
    for _, key in ipairs(sorted_keys(value)) do
        pairs_json[#pairs_json + 1] = encode_json_string(key) .. ":" .. encode_json(value[key])
    end
    return "{" .. table.concat(pairs_json, ",") .. "}"
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
        return nil
    end
    return value
end

local function cargo_list_command()
    return "cargo install --list --quiet --color never"
end

local function cargo_info_command()
    return "cargo info wasm-bindgen-cli --quiet --color never"
end

local function cargo_install_command(version, force)
    local parts = { "cargo", "install", "--color", "never" }
    if force then
        parts[#parts + 1] = "--force"
    end
    if trim(version) ~= "" then
        parts[#parts + 1] = "--version"
        parts[#parts + 1] = trim(version)
    end
    parts[#parts + 1] = TOOL_PACKAGE
    local command_parts = {}
    for _, part in ipairs(parts) do
        command_parts[#command_parts + 1] = shell_arg(part)
    end
    return table.concat(command_parts, " ")
end

local function cargo_uninstall_command()
    return "cargo uninstall wasm-bindgen-cli --color never"
end

local function parse_tool_list_output(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local text = trim(line)
        local name, version = text:match("^([^%s]+)%s+v([^%s:]+).-:%s*$")
        if name ~= nil and version ~= nil then
            items[#items + 1] = {
                name = name,
                packageId = name,
                version = version,
                installed = true,
                status = "installed",
                type = "package",
                packageType = "tool",
            }
        end
    end
    return items
end

local function parse_info_output(stdout)
    local lines = {}
    for _, line in ipairs(split_lines(stdout)) do
        local text = trim(line)
        if text ~= "" then
            lines[#lines + 1] = text
        end
    end
    if #lines == 0 then
        return {}
    end
    local item = {
        name = TOOL_PACKAGE,
        packageId = TOOL_PACKAGE,
        type = "package",
        packageType = "tool",
    }
    if lines[2] ~= nil and lines[2]:match("^[%w%-%.]+:%s*") == nil then
        item.summary = lines[2]
        item.description = lines[2]
    end
    for _, line in ipairs(lines) do
        local key, value = line:match("^([%w%-%.]+):%s*(.*)$")
        if key ~= nil then
            local normalized_key = lower(key)
            local normalized_value = trim(value)
            if normalized_key == "version" then
                item.latestVersion = normalized_value
            elseif normalized_key == "license" then
                item.license = normalized_value
            elseif normalized_key == "homepage" then
                item.homepage = normalized_value
            elseif normalized_key == "repository" then
                item.repository = normalized_value
            elseif normalized_key == "documentation" then
                item.documentation = normalized_value
            elseif normalized_key == "rust-version" then
                item.rustVersion = normalized_value
            elseif normalized_key == "crates.io" then
                item.registryUrl = normalized_value
            end
        end
    end
    return item
end

local function tool_alias_matches(name)
    local normalized = lower(name)
    return normalized == "wasm-bindgen" or normalized == "wasm-bindgen-cli"
end

local function normalize_tool_request_name(name)
    if tool_alias_matches(name) then
        return TOOL_PACKAGE
    end
    return trim(name)
end

local function parse_binary_version(stdout)
    local text = trim(stdout)
    local version = text:match("([0-9]+%.[0-9]+%.[0-9]+[%w%.-]*)")
    return trim(version or "")
end

local function installed_tool_item(context)
    if command_exists(context, CARGO_BINARY) then
        local result = exec_run(context, cargo_list_command())
        if result ~= nil and result.success == true then
            for _, item in ipairs(parse_tool_list_output(result.stdout)) do
                if item.name == TOOL_PACKAGE then
                    return item
                end
            end
        end
    end
    if command_exists(context, TOOL_BINARY) then
        local result = exec_run(context, "wasm-bindgen --version")
        if result ~= nil and result.success == true then
            local version = parse_binary_version(result.stdout)
            return {
                name = TOOL_PACKAGE,
                packageId = TOOL_PACKAGE,
                version = version ~= "" and version or nil,
                installed = true,
                status = "installed",
                type = "package",
                packageType = "tool",
            }
        end
    end
    return nil
end

local function tool_info_item(context)
    local installed = installed_tool_item(context)
    local result = nil
    if command_exists(context, CARGO_BINARY) then
        result = exec_run(context, cargo_info_command())
    end
    if result ~= nil and result.success == true then
        local info = parse_info_output(result.stdout)
        if installed ~= nil then
            info.version = installed.version
            info.installed = true
            info.status = "installed"
        else
            info.version = info.latestVersion
            info.installed = false
            info.status = "available"
        end
        return info
    end
    if installed ~= nil then
        local fallback = shallow_copy(installed)
        fallback.summary = "Command line interface for wasm-bindgen"
        fallback.description = fallback.summary
        return fallback
    end
    return {
        name = TOOL_PACKAGE,
        packageId = TOOL_PACKAGE,
        type = "package",
        packageType = "tool",
        installed = false,
        status = "available",
        summary = "Command line interface for wasm-bindgen",
        description = "Command line interface for the #[wasm_bindgen] project",
    }
end

local function build_generation_options(context)
    local flags = collect_flags(context, nil)
    local options = {
        target = flag_value(flags, "target"),
        outDir = expand_runtime_placeholders(flag_value(flags, "out-dir")),
        typescript = not has_flag(flags, "typescript=false"),
        debug = has_flag(flags, "debug=true"),
        browser = has_flag(flags, "browser=true"),
        keepDebug = has_flag(flags, "keep-debug=true"),
        keepLldExports = has_flag(flags, "keep-lld-exports=true"),
        omitDefaultModulePath = has_flag(flags, "omit-default-module-path=true"),
        omitImports = has_flag(flags, "omit-imports=true"),
        splitLinkedModules = has_flag(flags, "split-linked-modules=true"),
        noDemangle = has_flag(flags, "no-demangle=true"),
        noModulesGlobal = flag_value(flags, "no-modules-global"),
        resetState = has_flag(flags, "reset-state=true"),
    }
    if options.target == "" then
        options.target = DEFAULT_TARGET
    end
    return options
end

local function option_fingerprint(options)
    local parts = {
        options.target,
        options.typescript and "ts" or "no-ts",
        options.debug and "debug" or "nodebug",
        options.browser and "browser" or "nobrowser",
        options.keepDebug and "keep-debug" or "",
        options.keepLldExports and "keep-lld-exports" or "",
        options.omitDefaultModulePath and "omit-default-module-path" or "",
        options.omitImports and "omit-imports" or "",
        options.splitLinkedModules and "split-linked-modules" or "",
        options.noDemangle and "no-demangle" or "",
        options.noModulesGlobal,
        options.resetState and "reset-state" or "",
    }
    return normalize_token(table.concat(parts, "__"))
end

local function file_size(path)
    local handle = io.open(resolve_fs_path(path), "rb")
    if handle == nil then
        return "0"
    end
    local size = handle:seek("end")
    handle:close()
    return tostring(size or 0)
end

local function build_cache_key(path, options)
    return normalize_token(expand_runtime_placeholders(path)) .. "__" .. file_size(path) .. "__" .. option_fingerprint(options)
end

local function generation_entry_paths(cache_root, cache_key)
    local base = join_path(generated_root(cache_root), cache_key)
    return {
        base = base,
        manifest = join_path(base, "manifest.json"),
        out = join_path(base, "out"),
    }
end

local function generated_package_id(cache_key)
    return "generated:" .. cache_key
end

local function manifest_to_item(manifest)
    if type(manifest) ~= "table" then
        return nil
    end
    return {
        name = trim(read_field(manifest, "name") or basename(read_field(manifest, "sourcePath") or "generated")),
        packageId = trim(read_field(manifest, "packageId") or ""),
        version = trim(read_field(manifest, "target") or "") ~= "" and trim(read_field(manifest, "target")) or nil,
        installed = true,
        status = "cached",
        type = "package",
        packageType = "generated",
        summary = "Generated wasm-bindgen output",
        description = "Cached local wasm-bindgen generation output",
        extraFields = {
            sourcePath = read_field(manifest, "sourcePath"),
            outputPath = read_field(manifest, "outputPath"),
            target = read_field(manifest, "target"),
            managedOutput = tostring(read_field(manifest, "managedOutput") == true),
            typescript = tostring(read_field(manifest, "typescript") == true),
        },
    }
end

local function read_manifest(path)
    local raw = read_file(path)
    if raw == nil then
        return nil
    end
    local decoded = decode_json(raw)
    if type(decoded) ~= "table" then
        return nil
    end
    return decoded
end

local function write_manifest(path, manifest)
    return write_file(path, encode_json(manifest))
end

local function list_manifest_paths(context, cache_root)
    local root = generated_root(cache_root)
    local fs_root = resolve_fs_path(root)
    local paths = {}

    if path_exists(fs_root) and io.popen ~= nil then
        local handle = io.popen("find " .. shell_quote(fs_root) .. " -type f -name 'manifest.json' | LC_ALL=C sort 2>/dev/null")
        if handle ~= nil then
            local output = handle:read("*a") or ""
            handle:close()
            for _, line in ipairs(split_lines(output)) do
                local text = trim(line)
                if text ~= "" then
                    paths[#paths + 1] = text
                end
            end
            if #paths > 0 then
                return paths
            end
        end
    end

    local command = "find " .. shell_quote(root) .. " -type f -name 'manifest.json' | LC_ALL=C sort"
    local result = exec_run(context, command)
    if result == nil or result.success ~= true then
        return {}
    end
    for _, line in ipairs(split_lines(result.stdout)) do
        local text = trim(expand_runtime_placeholders(line))
        if text ~= "" then
            paths[#paths + 1] = text
        end
    end
    return paths
end

local function generated_items(context, cache_root)
    local items = {}
    for _, path in ipairs(list_manifest_paths(context, cache_root)) do
        local manifest = read_manifest(path)
        local item = manifest_to_item(manifest)
        if item ~= nil and trim(item.packageId) ~= "" then
            items[#items + 1] = item
        end
    end
    return items
end

local function all_generated_items(context, package)
    local items = {}
    local seen = {}
    for _, root in ipairs(candidate_cache_roots(context, package)) do
        for _, item in ipairs(generated_items(context, root)) do
            local id = trim(item.packageId or "")
            if id ~= "" and not seen[id] then
                seen[id] = true
                items[#items + 1] = item
            end
        end
    end
    return items
end

local function find_generated_manifest_by_id(context, cache_root, package_id)
    for _, path in ipairs(list_manifest_paths(context, cache_root)) do
        local manifest = read_manifest(path)
        if type(manifest) == "table" and trim(read_field(manifest, "packageId") or "") == trim(package_id) then
            return manifest, path
        end
    end
    return nil, nil
end

local function find_generated_manifest(context, package, package_id)
    for _, root in ipairs(candidate_cache_roots(context, package)) do
        local manifest, manifest_path = find_generated_manifest_by_id(context, root, package_id)
        if manifest ~= nil then
            return manifest, manifest_path
        end
    end
    return nil, nil
end

local function supported_tool_package(name)
    return normalize_tool_request_name(name) == TOOL_PACKAGE
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageId"))
end

local function package_version(pkg)
    return trim(read_field(pkg, "version"))
end

local function package_action(pkg)
    return lower(read_field(pkg, "action") or "install")
end

local function sort_items(items)
    table.sort(items, function(left, right)
        return trim(left.packageId or left.name or "") < trim(right.packageId or right.name or "")
    end)
end

plugin.fileExtensions = { ".wasm" }

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
    return { "WebAssembly", "Rust", "Build Tool" }
end

function plugin.getMissingPackages(packages)
    local installed = installed_tool_item(nil)
    local installed_version = trim(installed and installed.version or "")
    local missing = {}
    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        local action = package_action(pkg)
        local version = package_version(pkg)
        if supported_tool_package(name) then
            if action == "remove" then
                if installed ~= nil then
                    missing[#missing + 1] = pkg
                end
            elseif action == "update" then
                if installed ~= nil then
                    missing[#missing + 1] = pkg
                end
            elseif installed == nil then
                missing[#missing + 1] = pkg
            elseif version ~= "" and installed_version ~= version then
                missing[#missing + 1] = pkg
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
    if not command_exists(context, CARGO_BINARY) then
        tx_failed(context, "cargo binary not available")
        return false
    end
    begin_step(context, "install wasm-bindgen tool")
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        if not supported_tool_package(name) then
            tx_failed(context, "unsupported wasm-bindgen package: " .. tostring(name))
            return false
        end
        local result = exec_run(context, cargo_install_command(package_version(pkg), false))
        if result == nil or result.success ~= true then
            tx_failed(context, "wasm-bindgen install failed")
            return false
        end
    end
    emit_event(context, "installed", requested)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local source_path = expand_runtime_placeholders(trim(path))
    if source_path == "" or not ends_with(lower(source_path), ".wasm") then
        tx_failed(context, "wasm-bindgen local install supports only .wasm files")
        return false
    end
    if not command_exists(context, TOOL_BINARY) then
        tx_failed(context, "wasm-bindgen binary not available")
        return false
    end

    local options = build_generation_options(context)
    local cache_root = cache_root_for(context, nil)
    local cache_key = build_cache_key(source_path, options)
    local paths = generation_entry_paths(cache_root, cache_key)
    local managed_output = trim(options.outDir) == ""
    local output_path = managed_output and paths.out or options.outDir
    local command_parts = {
        "wasm-bindgen",
        shell_quote(source_path),
        "--out-dir",
        shell_quote(output_path),
        "--target",
        shell_arg(options.target),
    }

    if not options.typescript then
        command_parts[#command_parts + 1] = "--no-typescript"
    end
    if options.debug then
        command_parts[#command_parts + 1] = "--debug"
    end
    if options.browser then
        command_parts[#command_parts + 1] = "--browser"
    end
    if options.keepDebug then
        command_parts[#command_parts + 1] = "--keep-debug"
    end
    if options.keepLldExports then
        command_parts[#command_parts + 1] = "--keep-lld-exports"
    end
    if options.omitDefaultModulePath then
        command_parts[#command_parts + 1] = "--omit-default-module-path"
    end
    if options.omitImports then
        command_parts[#command_parts + 1] = "--omit-imports"
    end
    if options.splitLinkedModules then
        command_parts[#command_parts + 1] = "--split-linked-modules"
    end
    if options.noDemangle then
        command_parts[#command_parts + 1] = "--no-demangle"
    end
    if options.noModulesGlobal ~= "" then
        command_parts[#command_parts + 1] = "--no-modules-global"
        command_parts[#command_parts + 1] = shell_quote(options.noModulesGlobal)
    end
    if options.resetState then
        command_parts[#command_parts + 1] = "--experimental-reset-state-function"
    end

    begin_step(context, "generate wasm-bindgen bindings")
    if not ensure_directory(dirname(paths.manifest)) then
        tx_failed(context, "wasm-bindgen cache directory setup failed")
        return false
    end
    if not ensure_directory(output_path) then
        tx_failed(context, "wasm-bindgen output directory setup failed")
        return false
    end

    local result = exec_run(context, table.concat(command_parts, " "))
    if result == nil or result.success ~= true then
        tx_failed(context, "wasm-bindgen local generation failed")
        return false
    end

    local manifest = {
        packageId = generated_package_id(cache_key),
        name = basename(source_path),
        sourcePath = source_path,
        outputPath = output_path,
        target = options.target,
        typescript = options.typescript,
        managedOutput = managed_output,
    }
    if not write_manifest(paths.manifest, manifest) then
        log_warn(context, "wasm-bindgen cache manifest write skipped")
    end

    emit_event(context, "installed", {
        path = source_path,
        localTarget = true,
        packageId = manifest.packageId,
        outputPath = output_path,
        target = options.target,
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    begin_step(context, "remove wasm-bindgen targets")
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        if supported_tool_package(name) then
            if not command_exists(context, CARGO_BINARY) then
                tx_failed(context, "cargo binary not available")
                return false
            end
            local result = exec_run(context, cargo_uninstall_command())
            if result == nil or result.success ~= true then
                tx_failed(context, "wasm-bindgen remove failed")
                return false
            end
        elseif starts_with(name, "generated:") then
            local manifest, manifest_path = find_generated_manifest(context, pkg, name)
            if manifest ~= nil then
                if read_field(manifest, "managedOutput") == true then
                    remove_path(read_field(manifest, "outputPath"))
                end
                remove_path(manifest_path)
                remove_path(dirname(manifest_path))
            end
        else
            tx_failed(context, "unsupported wasm-bindgen package: " .. tostring(name))
            return false
        end
    end
    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    if not command_exists(context, CARGO_BINARY) then
        if #requested == 0 then
            return true
        end
        tx_failed(context, "cargo binary not available")
        return false
    end

    local effective = requested
    if #effective == 0 then
        if installed_tool_item(context) == nil then
            return true
        end
        effective = { { name = TOOL_PACKAGE } }
    end

    begin_step(context, "update wasm-bindgen tool")
    for _, pkg in ipairs(effective) do
        local name = package_name(pkg)
        if not supported_tool_package(name) then
            tx_failed(context, "unsupported wasm-bindgen package: " .. tostring(name))
            return false
        end
        local result = exec_run(context, cargo_install_command(package_version(pkg), true))
        if result == nil or result.success ~= true then
            tx_failed(context, "wasm-bindgen update failed")
            return false
        end
    end
    emit_event(context, "updated", effective)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = {}
    local tool = installed_tool_item(context)
    if tool ~= nil then
        items[#items + 1] = tool
    end
    for _, item in ipairs(all_generated_items(context, nil)) do
        items[#items + 1] = item
    end
    sort_items(items)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items = {}
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local text = lower(prompt)
    local items = {}
    if text ~= "" and (text:find("wasm", 1, true) ~= nil or text:find("bindgen", 1, true) ~= nil) then
        items[#items + 1] = tool_info_item(context)
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local requested_name = trim(name)
    local item = {}
    if tool_alias_matches(requested_name) then
        item = tool_info_item(context)
    elseif starts_with(requested_name, "generated:") then
        local manifest = find_generated_manifest(context, nil, requested_name)
        item = manifest_to_item(manifest) or {}
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if tool_alias_matches(name) then
        return tool_info_item(context)
    end
    if starts_with(name, "generated:") then
        local manifest = find_generated_manifest(context, package, name)
        return manifest_to_item(manifest)
    end
    return nil
end

function plugin.init()
    return command_exists(nil, CARGO_BINARY) or command_exists(nil, TOOL_BINARY)
end

function plugin.shutdown()
    return true
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "rust", "cargo", "webassembly", "wasm-bindgen" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".cargo" },
            { kind = "user-home-subpath", value = ".cache/reqpack/wasm-bindgen" },
        },
        privilegeLevel = "user",
        osvEcosystem = "crates.io",
        purlType = "cargo",
    }
end

return plugin
