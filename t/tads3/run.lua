plugin = {}

local PLUGIN_ID = "tads3"
local PLUGIN_NAME = "TADS 3"
local PLUGIN_VERSION = "0.1.0"
local INDEX_URLS = {
    core = "https://www.ifarchive.org/indexes/if-archive/programming/tads3/library/",
    contributions = "https://www.ifarchive.org/indexes/if-archive/programming/tads3/library/contributions/",
}
local IFARCHIVE_BASE_URL = "https://www.ifarchive.org"
local SUPPORTED_EXTENSIONS = {
    ["zip"] = true,
    ["tl"] = true,
    ["t"] = true,
    ["h"] = true,
}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return tostring(value or ""):lower()
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

local function normalize_exec_result(...)
    local result = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        local value_type = type(value)
        if value_type == "table" then
            for key, item in pairs(value or {}) do
                if result[key] == nil then
                    result[key] = item
                end
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
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return normalize_exec_result(context.exec.run(command))
    end
    if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
        return normalize_exec_result(reqpack.exec.run(command))
    end
    return {
        success = false,
        stdout = "",
        stderr = "missing ReqPack exec runner",
        exitCode = 127,
    }
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

local function read_text_file(context, path)
    if context == nil then
        local handle = io.open(path, "rb")
        if handle == nil then
            return nil
        end
        local content = handle:read("*a")
        handle:close()
        return content
    end

    local result = exec_run(context, "cat " .. shell_quote(path))
    if result.success ~= true then
        return nil
    end
    return result.stdout or ""
end

local function write_text_file(context, path, content)
    if context == nil then
        local handle = io.open(path, "wb")
        if handle == nil then
            return false
        end
        handle:write(content or "")
        handle:close()
        return true
    end

    local parent = trim(path):match("^(.*)/[^/]+$") or "."
    local result = exec_run(
        context,
        "mkdir -p " .. shell_quote(parent)
        .. " && printf '%s' " .. shell_quote(content or "")
        .. " > " .. shell_quote(path)
    )
    return result.success == true
end

local function file_exists(context, path)
    if context == nil then
        local handle = io.open(path, "rb")
        if handle ~= nil then
            handle:close()
            return true
        end
        return false
    end

    return exec_run(context, "test -f " .. shell_quote(path)).success == true
end

local function get_reqpack_path(name)
    local paths = type(reqpack) == "table" and read_field(reqpack, "paths") or nil
    if type(paths) ~= "table" then
        return nil
    end
    return trim(read_field(paths, name) or "") ~= "" and trim(read_field(paths, name)) or nil
end

local function object_flags(value)
    local raw = read_field(value, "flags")
    if type(raw) ~= "table" and type(raw) ~= "userdata" then
        return {}
    end
    local flags = {}
    local ok = pcall(function()
        for _, item in ipairs(raw) do
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
    local function collect_from(value)
        for _, item in ipairs(object_flags(value)) do
            if not seen[item] then
                seen[item] = true
                flags[#flags + 1] = item
            end
        end
    end
    collect_from(context)
    collect_from(read_field(context, "request"))
    collect_from(package)
    return flags
end

local function flag_value(flags, key)
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            return trim(cleaned:sub(#prefix + 1))
        end
    end
    return nil
end

local function command_exists(context, binary)
    return exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1").success == true
end

local function default_root()
    local data_root = get_reqpack_path("dataRoot")
    if data_root ~= nil then
        return join_path(data_root, PLUGIN_ID)
    end
    local xdg_data_home = trim((os ~= nil and type(os.getenv) == "function") and (os.getenv("XDG_DATA_HOME") or "") or "")
    if xdg_data_home ~= "" then
        return join_path(xdg_data_home, "reqpack", PLUGIN_ID)
    end
    local home = trim((os ~= nil and type(os.getenv) == "function") and (os.getenv("HOME") or "") or "")
    if home ~= "" then
        return join_path(home, ".local", "share", "reqpack", PLUGIN_ID)
    end
    return join_path(".reqpack-data", PLUGIN_ID)
end

local function state_paths(context, package)
    local root = flag_value(collect_flags(context, package), "data-root") or default_root()
    return {
        root = root,
        cache = join_path(root, "cache"),
        archives = join_path(root, "archives"),
        packages = join_path(root, "packages"),
        state = join_path(root, "state"),
        stateFile = join_path(root, "state", "installed.json"),
        coreIndexCache = join_path(root, "cache", "index-core.html"),
        contributionsIndexCache = join_path(root, "cache", "index-contributions.html"),
    }
end

local function ensure_storage(context, paths)
    local command = "mkdir -p "
        .. shell_quote(paths.cache) .. " "
        .. shell_quote(paths.archives) .. " "
        .. shell_quote(paths.packages) .. " "
        .. shell_quote(paths.state)
    local result = exec_run(context, command)
    if result.success ~= true then
        return false, trim(result.stderr) ~= "" and trim(result.stderr) or "failed to create storage directories"
    end
    return true, nil
end

local function basename(path)
    local cleaned = trim(path)
    return cleaned:match("([^/]+)$") or cleaned
end

local function dirname(path)
    local cleaned = trim(path)
    local parent = cleaned:match("^(.*)/[^/]+$")
    if parent == nil or parent == "" then
        return "."
    end
    return parent
end

local function ensure_parent_dir(context, path)
    local parent = trim(path):match("^(.*)/[^/]+$") or "."
    local result = exec_run(context, "mkdir -p " .. shell_quote(parent))
    if result.success ~= true then
        return false, trim(result.stderr) ~= "" and trim(result.stderr) or ("failed to create parent directory for " .. path)
    end
    return true, nil
end

local function strip_extension(name)
    local cleaned = trim(name)
    return cleaned:gsub("%.[^%.]+$", "")
end

local function file_extension(name)
    return lower((tostring(name or ""):match("%.([^%.]+)$") or ""))
end

local function is_supported_filename(name)
    return SUPPORTED_EXTENSIONS[file_extension(name)] == true
end

local function normalize_name(name)
    return lower(strip_extension(basename(name)))
end

local function canonical_package_id(section, name)
    return lower(trim(section or "")) .. "/" .. normalize_name(name)
end

local function html_unescape(value)
    local text = tostring(value or "")
    text = text:gsub("&nbsp;", " ")
    text = text:gsub("&amp;", "&")
    text = text:gsub("&quot;", '"')
    text = text:gsub("&#39;", "'")
    text = text:gsub("&lt;", "<")
    text = text:gsub("&gt;", ">")
    return text
end

local function sanitize_html_text(value)
    local text = html_unescape(value)
    text = text:gsub("<br%s*/?>", "\n")
    text = text:gsub("</p>", "\n")
    text = text:gsub("<[^>]+>", " ")
    text = text:gsub("%s+", " ")
    return trim(text)
end

local function extract_version(description, file_name)
    local text = tostring(description or "")
    local version = text:match("[Vv]ersion%s+([%w%._%-]+)")
    if version ~= nil then
        return trim(version)
    end

    local base = strip_extension(file_name)
    local major, minor, patch = base:match("tads_lib_(%d)(%d)(%d+)")
    if major ~= nil then
        return major .. "." .. minor .. "." .. patch
    end
    return nil
end

local function make_summary(description)
    local text = trim(description)
    if text == "" then
        return "TADS 3 library entry from IF Archive"
    end
    local first = text:match("^(.-%.)%s")
    return trim(first or text)
end

local function parse_index_html(html, section, index_url)
    local entries = {}
    local seen = {}
    local text = tostring(html or "")
    local search_from = 1

    while true do
        local start_pos, end_pos, href, label = text:find('<a%s+href="([^"]+)"[^>]*>([^<]+)</a>', search_from)
        if start_pos == nil then
            break
        end
        search_from = end_pos + 1

        local file_name = trim(html_unescape(label))
        local next_anchor = text:find('<a%s+href="', search_from)
        local block = text:sub(end_pos + 1, next_anchor and (next_anchor - 1) or #text)
        local section_name = section

        if href:find("/if%-archive/programming/tads3/library/", 1, false) and is_supported_filename(file_name) then
            if href:find("/contributions/", 1, true) then
                section_name = "contributions"
            else
                section_name = "core"
            end

            local date = block:match("%[(%d%d%-%a%a%a%-%d%d%d%d)%]")
            local description = sanitize_html_text(block)
            description = description:gsub("^%[[^%]]+%]%s*", "")
            description = description:gsub("^View contents%s*", "")
            description = trim(description)

            local package_id = canonical_package_id(section_name, file_name)
            if not seen[package_id] then
                seen[package_id] = true
                entries[#entries + 1] = {
                    name = strip_extension(file_name),
                    packageId = package_id,
                    fileName = file_name,
                    section = section_name,
                    modifiedDate = trim(date or ""),
                    version = extract_version(description, file_name),
                    summary = make_summary(description),
                    description = description ~= "" and description or "TADS 3 library entry from IF Archive",
                    homepage = index_url,
                    sourceUrl = href:match("^https?://") and href or (IFARCHIVE_BASE_URL .. href),
                    indexUrl = index_url,
                    repository = "ifarchive",
                    packageType = "library",
                    type = "package",
                }
            end
        end
    end

    table.sort(entries, function(left, right)
        return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "")
    end)
    return entries
end

local function fetch_url(context, url)
    local result = exec_run(context, "curl -fsSL " .. shell_quote(url))
    if result.success ~= true then
        return nil, trim(result.stderr) ~= "" and trim(result.stderr) or ("failed to fetch " .. url)
    end
    return result.stdout or "", nil
end

local function load_index(context, paths, section)
    local index_url = INDEX_URLS[section]
    local cache_path = section == "core" and paths.coreIndexCache or paths.contributionsIndexCache
    local content = nil

    if command_exists(context, "curl") then
        local fetched, fetch_error = fetch_url(context, index_url)
        if fetched ~= nil then
            content = fetched
            if context == nil then
                write_text_file(nil, cache_path, fetched)
            end
        elseif file_exists(context, cache_path) then
            content = read_text_file(context, cache_path)
        else
            return nil, fetch_error
        end
    elseif file_exists(context, cache_path) then
        content = read_text_file(context, cache_path)
    else
        return nil, "missing required binary: curl"
    end

    return parse_index_html(content, section, index_url), nil
end

local function load_catalog(context, paths)
    local items = {}
    local errors = {}
    for _, section in ipairs({ "core", "contributions" }) do
        local section_items, err = load_index(context, paths, section)
        if section_items ~= nil then
            for _, item in ipairs(section_items) do
                items[#items + 1] = item
            end
        elseif err ~= nil then
            errors[#errors + 1] = err
        end
    end
    if #items == 0 and #errors > 0 then
        return nil, errors[1]
    end
    table.sort(items, function(left, right)
        return lower(left.packageId or "") < lower(right.packageId or "")
    end)
    return items, nil
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

local function encode_json_string(value)
    local replacements = {
        ["\\"] = "\\\\",
        ['"'] = '\\"',
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
    }
    return '"' .. tostring(value or ""):gsub('[%z\1-\31\\"]', function(char)
        return replacements[char] or string.format("\\u%04x", string.byte(char))
    end) .. '"'
end

local function is_array(value)
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

local function sorted_keys(value)
    local keys = {}
    for key in pairs(value or {}) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)
    return keys
end

local function encode_json(value)
    local value_type = type(value)
    if value == nil then
        return "null"
    elseif value_type == "string" then
        return encode_json_string(value)
    elseif value_type == "number" or value_type == "boolean" then
        return tostring(value)
    elseif value_type ~= "table" then
        return encode_json_string(tostring(value))
    end
    if is_array(value) then
        local parts = {}
        for index = 1, #value do
            parts[#parts + 1] = encode_json(value[index])
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local pairs_json = {}
    for _, key in ipairs(sorted_keys(value)) do
        pairs_json[#pairs_json + 1] = encode_json_string(key) .. ":" .. encode_json(value[key])
    end
    return "{" .. table.concat(pairs_json, ",") .. "}"
end

local function read_state(context, paths)
    if not file_exists(context, paths.stateFile) then
        return {}
    end
    local content = read_text_file(context, paths.stateFile)
    if content == nil or trim(content) == "" then
        return {}
    end
    local ok, decoded = pcall(json_decode, content)
    if not ok or type(decoded) ~= "table" then
        return {}
    end
    return decoded
end

local function write_state(context, paths, records)
    return write_text_file(context, paths.stateFile, encode_json(records))
end

local function package_request_name(value)
    return trim(read_field(value, "name") or read_field(value, "packageId") or "")
end

local function parse_request(value)
    local name = type(value) == "string" and trim(value) or package_request_name(value)
    if name == "" then
        return nil
    end
    local section, rest = name:match("^([^/]+)/(.+)$")
    return {
        raw = name,
        section = section and lower(section) or nil,
        name = rest or name,
        version = type(value) == "table" and trim(read_field(value, "version") or "") or "",
    }
end

local function find_record(records, query)
    local parsed = parse_request(query) or { raw = trim(tostring(query or "")), name = trim(tostring(query or "")) }
    local wanted = lower(parsed.raw or parsed.name or "")
    local wanted_name = normalize_name(parsed.name or wanted)

    for _, record in ipairs(records or {}) do
        local package_id = lower(trim(record.packageId or ""))
        local record_name = normalize_name(record.name or record.fileName or package_id)
        if package_id == wanted or record_name == wanted_name or lower(trim(record.fileName or "")) == lower(trim(parsed.name or "")) then
            if parsed.section == nil or lower(trim(record.section or "")) == parsed.section then
                return record
            end
        end
    end
    return nil
end

local function replace_record(records, replacement)
    local updated = {}
    local replaced = false
    for _, record in ipairs(records or {}) do
        if lower(trim(record.packageId or "")) == lower(trim(replacement.packageId or "")) then
            updated[#updated + 1] = replacement
            replaced = true
        else
            updated[#updated + 1] = record
        end
    end
    if not replaced then
        updated[#updated + 1] = replacement
    end
    table.sort(updated, function(left, right)
        return lower(left.packageId or "") < lower(right.packageId or "")
    end)
    return updated
end

local function remove_record(records, package_id)
    local updated = {}
    local removed = nil
    for _, record in ipairs(records or {}) do
        if lower(trim(record.packageId or "")) == lower(trim(package_id or "")) then
            removed = record
        else
            updated[#updated + 1] = record
        end
    end
    return updated, removed
end

local function find_catalog_entry(entries, query)
    local parsed = parse_request(query) or { raw = trim(tostring(query or "")), name = trim(tostring(query or "")) }
    local wanted = lower(parsed.raw or parsed.name or "")
    local wanted_name = normalize_name(parsed.name or wanted)

    for _, entry in ipairs(entries or {}) do
        if lower(entry.packageId or "") == wanted then
            return entry
        end
    end
    for _, entry in ipairs(entries or {}) do
        if normalize_name(entry.name or "") == wanted_name or lower(entry.fileName or "") == lower(trim(parsed.name or "")) then
            if parsed.section == nil or lower(entry.section or "") == parsed.section then
                return entry
            end
        end
    end
    for _, entry in ipairs(entries or {}) do
        local haystack = lower(table.concat({ entry.packageId or "", entry.name or "", entry.fileName or "", entry.summary or "", entry.description or "" }, " "))
        if wanted ~= "" and haystack:find(wanted, 1, true) ~= nil then
            return entry
        end
    end
    return nil
end

local function archive_path_for(paths, entry)
    return join_path(paths.archives, entry.section, entry.fileName)
end

local function install_path_for(paths, package_id)
    return join_path(paths.packages, package_id)
end

local function detect_main_library_file(context, install_path)
    local command = [=[find ]=] .. shell_quote(install_path) .. [=[ -type f \\(-name '*.tl' -o -name '*.t' -o -name '*.h' \\) | LC_ALL=C sort]=]
    local result = exec_run(context, command)
    if result.success ~= true then
        return nil
    end
    local found = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            found[#found + 1] = cleaned
        end
    end
    local function pick(extension)
        for _, path in ipairs(found) do
            if lower(path):sub(-#extension) == extension then
                return path
            end
        end
        return nil
    end
    local selected = pick(".tl") or pick(".t") or pick(".h")
    if selected == nil then
        return nil
    end
    local relative = selected:gsub("^" .. install_path:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") .. "/?", "")
    return trim(relative)
end

local function current_timestamp()
    if os ~= nil and type(os.date) == "function" then
        return os.date("!%Y-%m-%dT%H:%M:%SZ")
    end
    return ""
end

local function build_record_from_entry(entry, archive_path, install_path, main_library_file)
    return {
        name = entry.name,
        packageId = entry.packageId,
        section = entry.section,
        fileName = entry.fileName,
        modifiedDate = entry.modifiedDate,
        version = entry.version,
        summary = entry.summary,
        description = entry.description,
        homepage = entry.homepage,
        sourceUrl = entry.sourceUrl,
        repository = entry.repository,
        packageType = entry.packageType,
        origin = "remote",
        archivePath = archive_path,
        installPath = install_path,
        mainLibraryFile = main_library_file,
        installedAt = current_timestamp(),
    }
end

local function build_record_from_local(name, source_path, archive_path, install_path, main_library_file)
    return {
        name = name,
        packageId = "local/" .. lower(name),
        section = "local",
        fileName = basename(source_path),
        modifiedDate = "",
        version = nil,
        summary = "Local TADS 3 library install",
        description = "ReqPack-managed local TADS 3 library install.",
        homepage = "",
        sourceUrl = source_path,
        repository = "local",
        packageType = "library",
        origin = "local",
        archivePath = archive_path,
        installPath = install_path,
        mainLibraryFile = main_library_file,
        installedAt = current_timestamp(),
    }
end

local function remote_change(record, entry)
    if record == nil or entry == nil or lower(trim(record.origin or "")) ~= "remote" then
        return false
    end
    if trim(record.fileName or "") ~= trim(entry.fileName or "") then
        return true
    end
    if trim(record.sourceUrl or "") ~= trim(entry.sourceUrl or "") then
        return true
    end
    local record_version = trim(record.version or "")
    local entry_version = trim(entry.version or "")
    if record_version ~= "" and entry_version ~= "" and record_version ~= entry_version then
        return true
    end
    if trim(record.modifiedDate or "") ~= "" and trim(entry.modifiedDate or "") ~= "" and trim(record.modifiedDate or "") ~= trim(entry.modifiedDate or "") then
        return true
    end
    return false
end

local function item_from_record(record, remote_entry)
    local installed = shallow_copy(record)
    installed.installed = true
    installed.type = "package"
    installed.status = "installed"
    installed.latestVersion = trim(record.version or "") ~= "" and record.version or nil
    installed.extraFields = {
        archivePath = trim(record.archivePath or ""),
        installPath = trim(record.installPath or ""),
        mainLibraryFile = trim(record.mainLibraryFile or ""),
        section = trim(record.section or ""),
        modifiedDate = trim(record.modifiedDate or ""),
        origin = trim(record.origin or ""),
    }
    if remote_entry ~= nil and remote_change(record, remote_entry) then
        installed.status = "outdated"
        installed.latestVersion = trim(remote_entry.version or "") ~= "" and remote_entry.version or installed.latestVersion
        installed.extraFields.latestModifiedDate = trim(remote_entry.modifiedDate or "")
    elseif remote_entry ~= nil and trim(remote_entry.version or "") ~= "" then
        installed.latestVersion = remote_entry.version
    end
    return installed
end

local function install_remote_entry(context, paths, records, entry, event_name)
    local archive_path = archive_path_for(paths, entry)
    local install_path = install_path_for(paths, entry.packageId)

    local ok, err = ensure_parent_dir(context, archive_path)
    if not ok then
        tx_failed(context, err)
        return false, records
    end

    ok, err = ensure_parent_dir(context, install_path)
    if not ok then
        tx_failed(context, err)
        return false, records
    end

    begin_step(context, "download " .. entry.packageId)
    local payload, fetch_error = fetch_url(context, entry.sourceUrl)
    if payload == nil then
        tx_failed(context, fetch_error)
        return false, records
    end
    if not write_text_file(context, archive_path, payload) then
        tx_failed(context, "failed to write archive: " .. archive_path)
        return false, records
    end

    local extension = file_extension(entry.fileName)
    if extension == "zip" then
        if not command_exists(context, "unzip") then
            tx_failed(context, "missing required binary: unzip")
            return false, records
        end
        begin_step(context, "extract " .. entry.packageId)
        local unpack = exec_run(context,
            "rm -rf " .. shell_quote(install_path)
            .. " && mkdir -p " .. shell_quote(install_path)
            .. " && unzip -oq " .. shell_quote(archive_path)
            .. " -d " .. shell_quote(install_path)
        )
        if unpack.success ~= true then
            tx_failed(context, trim(unpack.stderr) ~= "" and trim(unpack.stderr) or "failed to extract archive")
            return false, records
        end
    else
        begin_step(context, "copy " .. entry.packageId)
        local copy = exec_run(context,
            "rm -rf " .. shell_quote(install_path)
            .. " && mkdir -p " .. shell_quote(install_path)
            .. " && cp " .. shell_quote(archive_path)
            .. " " .. shell_quote(join_path(install_path, entry.fileName))
        )
        if copy.success ~= true then
            tx_failed(context, trim(copy.stderr) ~= "" and trim(copy.stderr) or "failed to copy downloaded file")
            return false, records
        end
    end

    local main_library_file = extension == "zip" and detect_main_library_file(context, install_path) or entry.fileName
    local record = build_record_from_entry(entry, archive_path, install_path, main_library_file)
    local updated_records = replace_record(records, record)
    if not write_state(context, paths, updated_records) then
        tx_failed(context, "failed to write installed state")
        return false, records
    end
    emit_event(context, event_name, { record })
    return true, updated_records
end

local function local_path_exists(context, path)
    if exec_run(context, "test -d " .. shell_quote(path)).success == true then
        return "dir"
    end
    if exec_run(context, "test -f " .. shell_quote(path)).success == true then
        return "file"
    end
    return nil
end

local function install_local_path(context, paths, records, source_path)
    local kind = local_path_exists(context, source_path)
    if kind == nil then
        tx_failed(context, "local TADS 3 path not found")
        return false, records
    end

    local local_name = strip_extension(basename(source_path))
    if kind == "dir" then
        local_name = basename(source_path)
    end
    local package_id = "local/" .. lower(local_name)
    local install_path = install_path_for(paths, package_id)
    local archive_path = kind == "file" and join_path(paths.archives, "local", basename(source_path)) or ""
    local main_library_file = nil

    local ok, err = ensure_parent_dir(context, install_path)
    if not ok then
        tx_failed(context, err)
        return false, records
    end

    if archive_path ~= "" then
        ok, err = ensure_parent_dir(context, archive_path)
        if not ok then
            tx_failed(context, err)
            return false, records
        end
    end

    if kind == "dir" then
        begin_step(context, "copy local tads3 directory")
        local copy = exec_run(context,
            "rm -rf " .. shell_quote(install_path)
            .. " && mkdir -p " .. shell_quote(dirname(install_path))
            .. " && cp -R " .. shell_quote(source_path)
            .. " " .. shell_quote(install_path)
        )
        if copy.success ~= true then
            tx_failed(context, trim(copy.stderr) ~= "" and trim(copy.stderr) or "failed to copy local directory")
            return false, records
        end
        main_library_file = detect_main_library_file(context, install_path)
    else
        local extension = file_extension(source_path)
        if extension == "zip" then
            if not command_exists(context, "unzip") then
                tx_failed(context, "missing required binary: unzip")
                return false, records
            end
            begin_step(context, "stage local tads3 archive")
            local copy_archive = exec_run(context,
                "mkdir -p " .. shell_quote(dirname(archive_path))
                .. " && cp " .. shell_quote(source_path)
                .. " " .. shell_quote(archive_path)
            )
            if copy_archive.success ~= true then
                tx_failed(context, trim(copy_archive.stderr) ~= "" and trim(copy_archive.stderr) or "failed to stage local archive")
                return false, records
            end
            begin_step(context, "extract local tads3 archive")
            local unpack = exec_run(context,
                "rm -rf " .. shell_quote(install_path)
                .. " && mkdir -p " .. shell_quote(install_path)
                .. " && unzip -oq " .. shell_quote(archive_path)
                .. " -d " .. shell_quote(install_path)
            )
            if unpack.success ~= true then
                tx_failed(context, trim(unpack.stderr) ~= "" and trim(unpack.stderr) or "failed to extract local archive")
                return false, records
            end
            main_library_file = detect_main_library_file(context, install_path)
        else
            begin_step(context, "copy local tads3 file")
            local copy_file = exec_run(context,
                "rm -rf " .. shell_quote(install_path)
                .. " && mkdir -p " .. shell_quote(dirname(archive_path))
                .. " " .. shell_quote(install_path)
                .. " && cp " .. shell_quote(source_path)
                .. " " .. shell_quote(archive_path)
                .. " && cp " .. shell_quote(source_path)
                .. " " .. shell_quote(join_path(install_path, basename(source_path)))
            )
            if copy_file.success ~= true then
                tx_failed(context, trim(copy_file.stderr) ~= "" and trim(copy_file.stderr) or "failed to copy local file")
                return false, records
            end
            main_library_file = basename(source_path)
        end
    end

    local record = build_record_from_local(local_name, source_path, archive_path, install_path, main_library_file)
    local updated_records = replace_record(records, record)
    if not write_state(context, paths, updated_records) then
        tx_failed(context, "failed to write installed state")
        return false, records
    end
    emit_event(context, "installed", { record })
    return true, updated_records
end

local function query_remote_entry(context, paths, value)
    local catalog, err = load_catalog(context, paths)
    if catalog == nil then
        return nil, err
    end
    return find_catalog_entry(catalog, value), nil
end

plugin.fileExtensions = { ".zip", ".tl", ".t", ".h" }

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
    return { "Package Manager", "TADS 3", "Interactive Fiction" }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end

    local paths = state_paths(nil, nil)
    local records = read_state(nil, paths)
    local catalog = nil
    local load_remote = false
    for _, package in ipairs(packages) do
        if lower(trim(read_field(package, "action") or "")) == "update" then
            load_remote = true
            break
        end
    end
    if load_remote then
        catalog = select(1, load_catalog(nil, paths))
    end

    local filtered = {}
    for _, package in ipairs(packages) do
        local action = lower(trim(read_field(package, "action") or "install"))
        local record = find_record(records, package)
        if action == "remove" then
            if record ~= nil then
                filtered[#filtered + 1] = package
            end
        elseif action == "update" then
            if record ~= nil then
                if catalog == nil then
                    filtered[#filtered + 1] = package
                else
                    local entry = find_catalog_entry(catalog, record.packageId)
                    if entry ~= nil and remote_change(record, entry) then
                        filtered[#filtered + 1] = package
                    end
                end
            end
        elseif record == nil then
            filtered[#filtered + 1] = package
        end
    end
    return filtered
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if not command_exists(context, "curl") then
        tx_failed(context, "missing required binary: curl")
        return false
    end

    local paths = state_paths(context, requested[1])
    local ok, err = ensure_storage(context, paths)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local records = read_state(context, paths)
    for _, package in ipairs(requested) do
        local entry, resolve_error = query_remote_entry(context, paths, package)
        if entry == nil then
            tx_failed(context, resolve_error or ("package not found: " .. package_request_name(package)))
            return false
        end
        local success
        success, records = install_remote_entry(context, paths, records, entry, "installed")
        if not success then
            return false
        end
    end
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path or read_field(context, "localPath") or read_field(read_field(context, "request"), "localPath") or "")
    if local_path == "" then
        tx_failed(context, "missing local TADS 3 path")
        return false
    end

    local paths = state_paths(context, { name = local_path })
    local ok, err = ensure_storage(context, paths)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local records = read_state(context, paths)
    local success
    success, records = install_local_path(context, paths, records, local_path)
    if not success then
        return false
    end
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    local paths = state_paths(context, requested[1])
    local records = read_state(context, paths)
    local removed = {}

    for _, package in ipairs(requested) do
        local record = find_record(records, package)
        if record ~= nil then
            begin_step(context, "remove " .. record.packageId)
            local result = exec_run(context, "rm -rf " .. shell_quote(record.installPath or ""))
            if result.success ~= true then
                tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "failed to remove installed package")
                return false
            end
            records = select(1, remove_record(records, record.packageId))
            removed[#removed + 1] = record
        end
    end

    if not write_state(context, paths, records) then
        tx_failed(context, "failed to write installed state")
        return false
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local paths = state_paths(context, packages ~= nil and packages[1] or nil)
    local requested = packages or {}
    local records = read_state(context, paths)
    if #requested == 0 then
        requested = shallow_copy(records)
    end
    if #requested == 0 then
        return true
    end
    if not command_exists(context, "curl") then
        tx_failed(context, "missing required binary: curl")
        return false
    end

    local ok, err = ensure_storage(context, paths)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local updated = {}
    for _, package in ipairs(requested) do
        local record = find_record(records, package)
        if record ~= nil and lower(trim(record.origin or "")) == "remote" then
            local entry, resolve_error = query_remote_entry(context, paths, record.packageId)
            if entry == nil then
                tx_failed(context, resolve_error or ("package not found: " .. tostring(record.packageId)))
                return false
            end
            if remote_change(record, entry) then
                local success
                success, records = install_remote_entry(context, paths, records, entry, "updated")
                if not success then
                    return false
                end
                updated[#updated + 1] = entry
            end
        end
    end
    if #updated == 0 then
        emit_event(context, "updated", {})
    end
    tx_success(context)
    return true
end

function plugin.list(context)
    local paths = state_paths(context, nil)
    local records = read_state(context, paths)
    local catalog = nil
    if command_exists(context, "curl") then
        catalog = select(1, load_catalog(context, paths))
    end

    local items = {}
    for _, record in ipairs(records) do
        local remote_entry = catalog ~= nil and find_catalog_entry(catalog, record.packageId) or nil
        items[#items + 1] = item_from_record(record, remote_entry)
    end
    table.sort(items, function(left, right)
        return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "")
    end)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local paths = state_paths(context, nil)
    if not command_exists(context, "curl") then
        log_warn(context, "tads3 outdated requires curl")
        emit_event(context, "outdated", {})
        return {}
    end

    local records = read_state(context, paths)
    local catalog, err = load_catalog(context, paths)
    if catalog == nil then
        log_warn(context, err or "failed to load TADS 3 catalog")
        emit_event(context, "outdated", {})
        return {}
    end

    local items = {}
    for _, record in ipairs(records) do
        if lower(trim(record.origin or "")) == "remote" then
            local remote_entry = find_catalog_entry(catalog, record.packageId)
            if remote_entry ~= nil and remote_change(record, remote_entry) then
                items[#items + 1] = item_from_record(record, remote_entry)
            end
        end
    end
    table.sort(items, function(left, right)
        return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "")
    end)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end

    local paths = state_paths(context, nil)
    local catalog, err = load_catalog(context, paths)
    if catalog == nil then
        log_warn(context, err or "failed to load TADS 3 catalog")
        emit_event(context, "searched", {})
        return {}
    end

    local wanted = lower(query)
    local items = {}
    for _, entry in ipairs(catalog) do
        local haystack = lower(table.concat({ entry.packageId or "", entry.name or "", entry.fileName or "", entry.summary or "", entry.description or "" }, " "))
        if haystack:find(wanted, 1, true) ~= nil then
            items[#items + 1] = shallow_copy(entry)
        end
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = trim(
        name
        or read_field(context, "name")
        or read_field(context, "prompt")
        or read_field(read_field(context, "request"), "name")
        or read_field(read_field(context, "request"), "prompt")
        or ""
    )
    if query == "" then
        emit_event(context, "informed", {})
        return {}
    end

    local paths = state_paths(context, nil)
    local entry = select(1, query_remote_entry(context, paths, query))
    if entry ~= nil then
        emit_event(context, "informed", entry)
        return entry
    end

    local record = find_record(read_state(context, paths), query)
    if record ~= nil then
        local item = item_from_record(record, nil)
        emit_event(context, "informed", item)
        return item
    end

    emit_event(context, "informed", {})
    return {}
end

function plugin.resolvePackage(context, package)
    local paths = state_paths(context, package)
    local entry = select(1, query_remote_entry(context, paths, package))
    if entry ~= nil then
        return entry
    end
    local record = find_record(read_state(context, paths), package)
    if record ~= nil then
        return item_from_record(record, nil)
    end
    return nil
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "tads3", "interactive-fiction" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".local/share/reqpack/tads3" },
            { kind = "user-home-subpath", value = ".cache/reqpack/tads3" },
            { kind = "temp" },
        },
        networkScopes = {
            { host = "www.ifarchive.org", scheme = "https", pathPrefix = "/indexes/if-archive/programming/tads3/library/" },
            { host = "www.ifarchive.org", scheme = "https", pathPrefix = "/if-archive/programming/tads3/library/" },
        },
        privilegeLevel = "user",
        osvEcosystem = "Generic",
        purlType = "generic",
        versionComparatorProfile = "lexicographic",
    }
end

return plugin
