plugin = {}

local PLUGIN_ID = "uv"
local PLUGIN_NAME = "uv"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "uv"
local DEFAULT_SEARCH_LIMIT = 20
local JSON_NULL = {}

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
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function command_quote(value)
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,%[%]]+$") ~= nil then
        return text
    end
    return shell_quote(text)
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
    return normalize_run_result(first, second, third, fourth, fifth)
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
    local handle = io.open(path, "r")
    if handle ~= nil then
        local content = handle:read("*a")
        handle:close()
        return content
    end

    local result = run_exec(context, "cat " .. shell_quote(path))
    if result ~= nil and result.success == true then
        return result.stdout
    end

    return nil
end

local function home_dir()
    if os ~= nil and type(os.getenv) == "function" then
        local value = trim(os.getenv("HOME") or os.getenv("USERPROFILE") or "")
        if value ~= "" then
            return value
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

local function normalize_package_name(value)
    return lower(trim(value)):gsub("_", "-")
end

local function append_unique(list, value, seen)
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
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(flags or {}) do
        local lowered = lower(trim(flag))
        if lowered:sub(1, #prefix) == prefix then
            return trim(flag:sub(#prefix + 1))
        end
    end
    return nil
end

local function has_flag(flags, key)
    local wanted = lower(trim(key))
    for _, flag in ipairs(flags or {}) do
        if lower(trim(flag)) == wanted then
            return true
        end
    end
    return false
end

local function cache_root(context, packages)
    local raw_flags = collect_raw_flags(context, packages)
    local explicit = flag_value(raw_flags, "cache-root")
    if explicit ~= nil and explicit ~= "" then
        return explicit
    end
    return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
end

local function shared_paths(context, packages)
    local root = cache_root(context, packages)
    return {
        root = root,
        cache = join_path(root, "cache"),
        tools = join_path(root, "tools"),
        bin = join_path(root, "bin"),
        query = join_path(root, "query"),
    }
end

local function env_prefix(paths)
    return table.concat({
        "UV_CACHE_DIR=" .. shell_quote(paths.cache),
        "UV_TOOL_DIR=" .. shell_quote(paths.tools),
        "UV_TOOL_BIN_DIR=" .. shell_quote(paths.bin),
        "UV_NO_PROGRESS='1'",
        "NO_COLOR='1'",
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
    }, " ")
end

local function build_uv_command(context, packages, args)
    local paths = shared_paths(context, packages)
    local parts = { env_prefix(paths), "uv" }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = command_quote(arg)
    end
    return table.concat(parts, " "), paths
end

local function list_directory(context, path)
    local result = run_exec(context, "ls -1A " .. shell_quote(path))
    if result == nil or result.success ~= true then
        return {}
    end
    local entries = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local text = trim(line)
        if text ~= "" then
            entries[#entries + 1] = text
        end
    end
    table.sort(entries)
    return entries
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

local function package_name(package)
    return trim(read_field(package, "name") or "")
end

local function package_version(package)
    return trim(read_field(package, "version") or "")
end

local function package_lookup_name(package)
    local name = package_name(package)
    if name == "" then
        return ""
    end
    return normalize_package_name(extract_spec_name(name))
end

local function package_spec(package)
    local name = package_name(package)
    local version = package_version(package)
    if name == "" then
        return ""
    end
    if name:find("==", 1, true) ~= nil or name:find("@", 1, true) ~= nil or name:find("<", 1, true) ~= nil or name:find(">", 1, true) ~= nil or name:find("~", 1, true) ~= nil or name:find("!", 1, true) ~= nil then
        return name
    end
    if version == "" then
        return name
    end
    if version:match("^[<>=!~]") ~= nil then
        return name .. version
    end
    return name .. "==" .. version
end

local function parse_uv_receipt(content)
    local receipt = {
        requirements = {},
        entrypoints = {},
    }

    local requirements_blob = content:match("requirements%s*=%s*%[(.-)%]%s*")
    for item in tostring(requirements_blob or ""):gmatch("{(.-)}") do
        local requirement = {}
        requirement.name = trim(item:match('name%s*=%s*"([^"]+)"') or "")
        requirement.marker = trim(item:match('marker%s*=%s*"([^"]+)"') or "")
        requirement.extras = trim(item:match('extras%s*=%s*"([^"]+)"') or "")
        if requirement.name ~= "" then
            receipt.requirements[#receipt.requirements + 1] = requirement
        end
    end

    local entrypoints_blob = content:match("entrypoints%s*=%s*%[(.-)%]%s*$") or content:match("entrypoints%s*=%s*%[(.-)%]%s*")
    for item in tostring(entrypoints_blob or ""):gmatch("{(.-)}") do
        local entrypoint = {
            name = trim(item:match('name%s*=%s*"([^"]+)"') or ""),
            installPath = trim(item:match('install%-path%s*=%s*"([^"]+)"') or ""),
            from = trim(item:match('from%s*=%s*"([^"]+)"') or ""),
        }
        if entrypoint.name ~= "" or entrypoint.installPath ~= "" then
            receipt.entrypoints[#receipt.entrypoints + 1] = entrypoint
        end
    end

    return receipt
end

local function parse_metadata(content)
    local result = {
        dependencies = {},
        projectUrls = {},
    }
    local current_key = nil

    for _, line in ipairs(split_lines(content)) do
        if line:match("^%S") ~= nil then
            local key, value = line:match("^([%w%-]+):%s*(.*)$")
            current_key = key
            if key == "Name" then
                result.name = trim(value)
            elseif key == "Version" then
                result.version = trim(value)
            elseif key == "Summary" then
                result.summary = trim(value)
            elseif key == "Home-page" then
                result.homepage = trim(value)
            elseif key == "License" then
                result.license = trim(value)
            elseif key == "Requires-Python" then
                result.python = trim(value)
            elseif key == "Requires-Dist" then
                result.dependencies[#result.dependencies + 1] = trim(value)
            elseif key == "Project-URL" then
                local label, url = tostring(value or ""):match("^([^,]+),%s*(.+)$")
                if label ~= nil and url ~= nil then
                    result.projectUrls[trim(label)] = trim(url)
                end
            end
        elseif current_key == "Summary" and trim(line) ~= "" and result.summary ~= nil then
            result.summary = trim(result.summary .. " " .. trim(line))
        end
    end

    if trim(result.homepage or "") == "" then
        result.homepage = result.projectUrls.Homepage or result.projectUrls.homepage or result.projectUrls.Source or result.projectUrls.source
    end

    return result
end

local function find_python_dir(context, tool_path)
    for _, lib_entry in ipairs(list_directory(context, join_path(tool_path, "lib"))) do
        if lib_entry:match("^python") ~= nil then
            return lib_entry
        end
    end
    return nil
end

local function read_tool_metadata(context, tool_path)
    local python_dir = find_python_dir(context, tool_path)
    if python_dir == nil then
        return nil, nil
    end
    local site_packages = join_path(tool_path, "lib", python_dir, "site-packages")
    for _, entry in ipairs(list_directory(context, site_packages)) do
        if entry:match("%.dist%-info$") ~= nil then
            local metadata_path = join_path(site_packages, entry, "METADATA")
            local content = read_file(context, metadata_path)
            if content ~= nil then
                return parse_metadata(content), python_dir:gsub("^python", "")
            end
        end
    end
    return nil, python_dir:gsub("^python", "")
end

local function package_page_url(name)
    return "https://pypi.org/project/" .. tostring(name or "") .. "/"
end

local function build_installed_item(tool_name, tool_path, paths, receipt, metadata, python_version)
    local requirement_name = tool_name
    if receipt.requirements[1] ~= nil and trim(receipt.requirements[1].name) ~= "" then
        requirement_name = trim(receipt.requirements[1].name)
    elseif metadata ~= nil and trim(metadata.name or "") ~= "" then
        requirement_name = trim(metadata.name)
    end

    local binaries = {}
    local entrypoints = {}
    for _, entry in ipairs(receipt.entrypoints or {}) do
        if trim(entry.name) ~= "" then
            binaries[#binaries + 1] = trim(entry.name)
        end
        entrypoints[#entrypoints + 1] = {
            name = trim(entry.name),
            installPath = trim(entry.installPath),
            from = trim(entry.from),
        }
    end

    return {
        name = requirement_name,
        packageId = normalize_package_name(requirement_name),
        version = trim(metadata and metadata.version or ""),
        installed = true,
        status = "installed",
        packageType = "python-tool",
        summary = trim(metadata and metadata.summary or ""),
        homepage = trim(metadata and metadata.homepage or package_page_url(requirement_name)),
        license = trim(metadata and metadata.license or ""),
        dependencies = metadata and metadata.dependencies or {},
        binaries = binaries,
        extraFields = merge_tables(nil, {
            requirements = receipt.requirements,
            entrypoints = entrypoints,
            toolPath = tool_path,
            binDir = paths.bin,
            cacheDir = paths.cache,
            python = python_version,
            source = package_page_url(requirement_name),
        }),
    }
end

local function load_installed_items(context, packages)
    local paths = shared_paths(context, packages)
    local items = {}
    for _, entry in ipairs(list_directory(context, paths.tools)) do
        local tool_path = join_path(paths.tools, entry)
        local receipt_path = join_path(tool_path, "uv-receipt.toml")
        local receipt_content = read_file(context, receipt_path)
        if receipt_content ~= nil then
            local receipt = parse_uv_receipt(receipt_content)
            local metadata, python_version = read_tool_metadata(context, tool_path)
            items[#items + 1] = build_installed_item(entry, tool_path, paths, receipt, metadata, python_version)
        else
            log_warn(context, "skipping uv tool without receipt: " .. entry)
        end
    end
    table.sort(items, function(left, right)
        return lower(trim(left.name)) < lower(trim(right.name))
    end)
    return items, paths
end

local function installed_lookup(context, packages)
    local map = {}
    local items = load_installed_items(context, packages)
    for _, item in ipairs(items) do
        map[normalize_package_name(item.name)] = item
        map[normalize_package_name(item.packageId)] = item
    end
    return map
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
                    decode_error("unsupported escape")
                end
                segment_start = index
            else
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
        end
        current = peek()
        if current == "0" then
            index = index + 1
        elseif current:match("%d") ~= nil then
            repeat
                index = index + 1
                current = peek()
            until current == "" or current:match("%d") == nil
        else
            decode_error("invalid number")
        end
        current = peek()
        if current == "." then
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
            if current == "]" then
                index = index + 1
                return result
            end
            if current ~= "," then
                decode_error("expected array separator")
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
                decode_error("expected object key")
            end
            local key = parse_string()
            skip_whitespace()
            if peek() ~= ":" then
                decode_error("expected key separator")
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
                decode_error("expected object separator")
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
        end
        if current == "{" then
            return parse_object()
        end
        if current == "[" then
            return parse_array()
        end
        if current == "-" or current:match("%d") ~= nil then
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
            return JSON_NULL
        end
        decode_error("unexpected token")
    end

    local result = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("trailing content")
    end
    return result
end

local function decode_json(raw)
    local ok, result = pcall(decode_json_internal, raw)
    if not ok then
        return nil, result
    end
    return result, nil
end

local function url_encode_component(value)
    return tostring(value or ""):gsub("([^%w%-%._~])", function(char)
        return string.format("%%%02X", string.byte(char))
    end)
end

local function html_unescape(text)
    local value = tostring(text or "")
    value = value:gsub("&quot;", '"')
    value = value:gsub("&#39;", "'")
    value = value:gsub("&apos;", "'")
    value = value:gsub("&amp;", "&")
    value = value:gsub("&lt;", "<")
    value = value:gsub("&gt;", ">")
    value = value:gsub("&#x([0-9A-Fa-f]+);", function(hex)
        return codepoint_to_utf8(tonumber(hex, 16))
    end)
    value = value:gsub("&#([0-9]+);", function(num)
        return codepoint_to_utf8(tonumber(num, 10))
    end)
    return value
end

local function fetch_url(context, url)
    local result = run_exec(context, "curl -fsSL " .. shell_quote(url))
    if result == nil or result.success ~= true then
        return nil, trim(result and result.stderr or "fetch failed")
    end
    return result.stdout, nil
end

local function parse_pypi_info_json(raw)
    local data = decode_json(raw)
    if type(data) ~= "table" then
        return nil
    end
    local info = read_field(data, "info")
    if type(info) ~= "table" then
        return nil
    end
    local project_urls = read_field(info, "project_urls")
    local homepage = trim(read_field(info, "home_page") or "")
    if homepage == "" and type(project_urls) == "table" then
        homepage = trim(read_field(project_urls, "Homepage") or read_field(project_urls, "Source") or read_field(project_urls, "Documentation") or "")
    end
    return {
        name = trim(read_field(info, "name") or ""),
        packageId = normalize_package_name(trim(read_field(info, "name") or "")),
        version = trim(read_field(info, "version") or ""),
        latestVersion = trim(read_field(info, "version") or ""),
        summary = trim(read_field(info, "summary") or ""),
        description = trim(read_field(info, "summary") or ""),
        homepage = homepage,
        license = trim(read_field(info, "license") or ""),
        packageType = "python-tool",
        extraFields = merge_tables(nil, {
            source = package_page_url(trim(read_field(info, "name") or "")),
        }),
    }
end

local function merge_remote_with_installed(remote_item, installed_item, latest_version)
    if installed_item == nil then
        if remote_item ~= nil and latest_version ~= nil and latest_version ~= "" then
            remote_item.latestVersion = latest_version
        end
        return remote_item
    end

    local item = shallow_copy(installed_item)
    if remote_item ~= nil then
        item.summary = trim(remote_item.summary or item.summary or "")
        item.description = trim(remote_item.description or item.description or "")
        item.homepage = trim(remote_item.homepage or item.homepage or "")
        item.license = trim(remote_item.license or item.license or "")
        item.latestVersion = trim(remote_item.latestVersion or remote_item.version or latest_version or "")
        item.extraFields = merge_tables(item.extraFields, remote_item.extraFields)
    elseif latest_version ~= nil and latest_version ~= "" then
        item.latestVersion = latest_version
    end
    if trim(item.latestVersion or "") == "" then
        item.latestVersion = trim(item.version or "")
    end
    return item
end

local function remote_info(context, name)
    local package_name_value = trim(name)
    if package_name_value == "" then
        return nil
    end
    local raw, err = fetch_url(context, "https://pypi.org/pypi/" .. url_encode_component(package_name_value) .. "/json")
    if raw == nil then
        return nil, err
    end
    local item = parse_pypi_info_json(raw)
    if item == nil then
        return nil, "invalid PyPI JSON"
    end
    return item, nil
end

local function search_remote(context, prompt)
    local raw, err = fetch_url(context, "https://pypi.org/search/?q=" .. url_encode_component(prompt))
    if raw == nil then
        return nil, err
    end
    local items = {}
    local seen = {}
    for name, summary in raw:gmatch('package%-snippet__name[^>]*>%s*([^<]+)%s*</span>.-package%-snippet__description[^>]*>%s*([^<]-)%s*</p>') do
        local package_name_value = html_unescape(trim(name))
        if package_name_value ~= "" and not seen[package_name_value] then
            seen[package_name_value] = true
            items[#items + 1] = {
                name = package_name_value,
                packageId = normalize_package_name(package_name_value),
                packageType = "python-tool",
                summary = html_unescape(trim(summary)),
                homepage = package_page_url(package_name_value),
                extraFields = {
                    source = package_page_url(package_name_value),
                },
            }
            if #items >= DEFAULT_SEARCH_LIMIT then
                break
            end
        end
    end
    return items, nil
end

local function parse_outdated_names(raw)
    local names = {}
    local seen = {}
    for _, line in ipairs(split_lines(raw)) do
        local name = trim(line:match("^([%w%._%-]+)%s+v[%w%._%-]+$") or "")
        if name ~= "" and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    return names
end

local function install_flags(context, package, include_path_flags)
    local flags = collect_raw_flags(context, package ~= nil and { package } or {})
    local args = {}
    if has_flag(flags, "editable") then
        args[#args + 1] = "--editable"
    end
    if has_flag(flags, "force") then
        args[#args + 1] = "--force"
    end
    if has_flag(flags, "refresh") then
        args[#args + 1] = "--refresh"
    end
    local with_value = flag_value(flags, "with")
    if with_value ~= nil and with_value ~= "" then
        args[#args + 1] = "--with"
        args[#args + 1] = with_value
    end
    local with_exec_from = flag_value(flags, "with-executables-from")
    if with_exec_from ~= nil and with_exec_from ~= "" then
        args[#args + 1] = "--with-executables-from"
        args[#args + 1] = with_exec_from
    end
    local python = flag_value(flags, "python")
    if python ~= nil and python ~= "" then
        args[#args + 1] = "--python"
        args[#args + 1] = python
    end
    local prerelease = flag_value(flags, "prerelease")
    if prerelease ~= nil and prerelease ~= "" then
        args[#args + 1] = "--prerelease"
        args[#args + 1] = prerelease
    end
    if include_path_flags ~= true then
        return args
    end
    return args
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
    return { "Cross Platform", "Python", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    local missing = {}
    local action = ""
    if read_field(packages, "action") ~= nil then
        action = trim(read_field(packages, "action") or "")
    end
    local lookup = installed_lookup(nil, packages)
    if not command_exists(nil, REQUIRED_BINARY) then
        for _, package in ipairs(packages or {}) do
            local package_action = trim(read_field(package, "action") or action)
            if package_action == "install" or package_action == "" then
                missing[#missing + 1] = package
            end
        end
        return missing
    end
    for _, package in ipairs(packages or {}) do
        local name = package_lookup_name(package)
        local package_action = trim(read_field(package, "action") or action)
        local installed = lookup[name] ~= nil
        if package_action == "remove" then
            if installed then
                missing[#missing + 1] = package
            end
        elseif package_action == "update" then
            if installed then
                missing[#missing + 1] = package
            end
        elseif not installed then
            missing[#missing + 1] = package
        end
    end
    return missing
end

function plugin.install(context, packages)
    packages = packages or {}
    if #packages == 0 then
        return true
    end
    local ok, err = ensure_available(context)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local installed = {}
    for _, package in ipairs(packages or {}) do
        local spec = package_spec(package)
        if spec ~= "" then
            begin_step(context, "install uv tool " .. spec)
            local args = { "tool", "install" }
            for _, flag in ipairs(install_flags(context, package, false)) do
                args[#args + 1] = flag
            end
            args[#args + 1] = spec
            local command = build_uv_command(context, packages, args)
            local result = run_exec(context, command)
            if result == nil or result.success ~= true then
                tx_failed(context, "uv tool install failed")
                return false
            end
            local lookup = installed_lookup(context, packages)
            local item = lookup[normalize_package_name(extract_spec_name(spec))]
            installed[#installed + 1] = item or {
                name = extract_spec_name(spec),
                packageId = normalize_package_name(extract_spec_name(spec)),
                packageType = "python-tool",
            }
        end
    end

    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" then
        tx_failed(context, "uv local install failed")
        return false
    end
    local ok, err = ensure_available(context)
    if not ok then
        tx_failed(context, err)
        return false
    end
    begin_step(context, "install local uv tool")
    local args = { "tool", "install" }
    for _, flag in ipairs(install_flags(context, nil, true)) do
        args[#args + 1] = flag
    end
    args[#args + 1] = local_path
    local command = build_uv_command(context, nil, args)
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        tx_failed(context, "uv local install failed")
        return false
    end

    local items = load_installed_items(context, nil)
    local payload = items[#items] or { path = local_path, localTarget = true }
    emit_event(context, "installed", payload)
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    packages = packages or {}
    if #packages == 0 then
        return true
    end
    local ok, err = ensure_available(context)
    if not ok then
        tx_failed(context, err)
        return false
    end
    local lookup = installed_lookup(context, packages)
    local names = {}
    for _, package in ipairs(packages or {}) do
        local item = lookup[package_lookup_name(package)]
        if item ~= nil then
            names[#names + 1] = item.packageId
        end
    end
    if #names == 0 then
        return true
    end
    begin_step(context, "remove uv tools")
    local args = { "tool", "uninstall" }
    for _, name in ipairs(names) do
        args[#args + 1] = name
    end
    local command = build_uv_command(context, packages, args)
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        tx_failed(context, "uv tool uninstall failed")
        return false
    end
    emit_event(context, "deleted", packages)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    packages = packages or {}
    local ok, err = ensure_available(context)
    if not ok then
        tx_failed(context, err)
        return false
    end
    local raw_flags = collect_raw_flags(context, packages)
    local args = { "tool", "upgrade" }
    if #packages == 0 and has_flag(raw_flags, "all") then
        args[#args + 1] = "--all"
    else
        local lookup = installed_lookup(context, packages)
        for _, package in ipairs(packages or {}) do
            local item = lookup[package_lookup_name(package)]
            if item ~= nil then
                args[#args + 1] = item.packageId
            end
        end
        if #args == 2 then
            return true
        end
    end
    begin_step(context, "update uv tools")
    local command = build_uv_command(context, packages, args)
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        tx_failed(context, "uv tool upgrade failed")
        return false
    end
    emit_event(context, "updated", packages)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = load_installed_items(context, nil)
    emit_event(context, "listed", items)
    return items
end

function plugin.search(context, prompt)
    local search_prompt = trim(prompt)
    if search_prompt == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    local remote_items, err = search_remote(context, search_prompt)
    if remote_items == nil then
        log_warn(context, "uv search fallback failed: " .. tostring(err or "unknown error"))
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    local lookup = installed_lookup(context, nil)
    for index, item in ipairs(remote_items) do
        remote_items[index] = merge_remote_with_installed(item, lookup[item.packageId])
    end
    emit_event(context, "searched", remote_items)
    return remote_items
end

function plugin.info(context, name)
    local package_name_value = trim(name)
    if package_name_value == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local lookup = installed_lookup(context, nil)
    local installed_item = lookup[normalize_package_name(package_name_value)]
    local remote_item, err = remote_info(context, package_name_value)
    if remote_item == nil and installed_item == nil then
        if err ~= nil and err ~= "" then
            log_warn(context, "uv info fallback failed: " .. err)
        end
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local item = merge_remote_with_installed(remote_item, installed_item)
    emit_event(context, "informed", item)
    return item
end

function plugin.outdated(context)
    local ok = ensure_available(context)
    if not ok then
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end
    local command = build_uv_command(context, nil, { "tool", "list", "--outdated", "-v" })
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end
    local lookup = installed_lookup(context, nil)
    local items = {}
    for _, name in ipairs(parse_outdated_names(result.stdout)) do
        local installed_item = lookup[normalize_package_name(name)]
        local remote_item = nil
        if installed_item ~= nil then
            remote_item = remote_info(context, installed_item.name)
        else
            remote_item = remote_info(context, name)
        end
        local item = merge_remote_with_installed(remote_item, installed_item)
        if item ~= nil then
            items[#items + 1] = item
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == "" then
        return nil
    end
    local lookup = installed_lookup(context, nil)
    local installed_item = lookup[package_lookup_name(package)]
    local remote_item = remote_info(context, extract_spec_name(name))
    return merge_remote_with_installed(remote_item, installed_item)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "pypi" },
        writeScopes = {
            { kind = "user-home-subpath", path = ".cache/reqpack/uv" },
        },
        networkScopes = {
            { host = "pypi.org", scheme = "https", pathPrefix = "/" },
            { host = "files.pythonhosted.org", scheme = "https", pathPrefix = "/" },
        },
        privilegeLevel = "none",
        osvEcosystem = "PyPI",
        purlType = "pypi",
    }
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

return plugin
