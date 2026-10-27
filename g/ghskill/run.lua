plugin = {}

local PLUGIN_NAME = "Ghskill"
local PLUGIN_VERSION = "0.1.0"
local APP_PACKAGE_NAME = "app:ghskill"
local APP_HOMEPAGE = "https://cli.github.com/manual/gh_skill"
local JSON_NULL = {}
local cached_json_decoder = nil

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function starts_with(value, prefix)
    local text = tostring(value or "")
    local expected = tostring(prefix or "")
    return text:sub(1, #expected) == expected
end

local function strip_trailing_slashes(value)
    return tostring(value or ""):gsub("/+$", "")
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil and value ~= JSON_NULL then
            if type(value) == "string" then
                local text = trim(value)
                if text ~= "" then return text end
            else
                return value
            end
        end
    end
    return nil
end

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do copy[key] = item end
    return copy
end

local function read_field(value, key)
    if value == nil then return nil end
    local ok, result = pcall(function() return value[key] end)
    if ok then return result end
    return nil
end

local function path_dirname(path)
    local text = strip_trailing_slashes(path)
    local dir = text:match("^(.*)/[^/]+$")
    if dir ~= nil and dir ~= "" then return dir end
    if starts_with(text, "/") then return "/" end
    return "."
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local raw = tostring(select(index, ...) or "")
        if raw ~= "" then
            if #parts == 0 then
                parts[#parts + 1] = strip_trailing_slashes(raw)
            else
                parts[#parts + 1] = strip_trailing_slashes(raw:gsub("^/+", ""))
            end
        end
    end
    return table.concat(parts, "/")
end

local function normalize_token(value)
    local text = trim(value)
    if text == "" then return "item" end
    text = text:gsub("[^%w._-]+", "_")
    text = text:gsub("_+", "_")
    text = text:gsub("^_+", "")
    text = text:gsub("_+$", "")
    return text ~= "" and text or "item"
end

local function emit_event(context, name, payload)
    if context == nil or context.events == nil then return end
    local fn = context.events[name]
    if type(fn) == "function" then fn(payload) end
end

local function begin_step(context, label)
    if context == nil or context.tx == nil then return end
    local fn = context.tx.begin_step
    if type(fn) == "function" then fn(label) end
end

local function tx_success(context)
    if context == nil or context.tx == nil then return end
    local fn = context.tx.success
    if type(fn) == "function" then fn() end
end

local function tx_failed(context, message)
    if context == nil or context.tx == nil then return end
    local fn = context.tx.failed
    if type(fn) == "function" then fn(message) end
    emit_event(context, "failed", message)
end

local function normalize_run_result(first, second, third, fourth, fifth)
    if type(first) == "table" and first.success ~= nil then return first end
    local result = {}
    local function merge_exec_like(value)
        local probes = { "success", "ok", "stdout", "stderr", "exitCode", "exit_code", "code", "status" }
        for _, key in ipairs(probes) do
            local ok, item = pcall(function() return value[key] end)
            if ok and item ~= nil and result[key] == nil then result[key] = item end
        end
    end
    local function merge_table(value)
        for key, item in pairs(value or {}) do result[key] = item end
    end
    local function apply_scalar(value)
        local value_type = type(value)
        if value_type == "table" then
            merge_table(value)
        elseif value_type == "userdata" then
            merge_exec_like(value)
        elseif value_type == "boolean" then
            if result.success == nil then result.success = value end
        elseif value_type == "number" then
            if result.exitCode == nil then result.exitCode = value end
        elseif value_type == "string" then
            if result.stdout == nil then result.stdout = value elseif result.stderr == nil then result.stderr = value end
        end
    end
    apply_scalar(first) apply_scalar(second) apply_scalar(third) apply_scalar(fourth) apply_scalar(fifth)
    if result.exitCode == nil then result.exitCode = result.exit_code or result.code or result.status end
    if result.success == nil and result.ok ~= nil then result.success = result.ok end
    if result.success == nil and result.exitCode ~= nil then result.success = result.exitCode == 0 end
    return result
end

local function is_command_success(result)
    if type(result) ~= "table" then return false end
    if result.success or result.ok then return true end
    local exit_code = result.exitCode or result.exit_code or result.code or result.status
    return exit_code == 0
end

local function run_command(context, command)
    local first, second, third, fourth, fifth
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        first, second, third, fourth, fifth = context.exec.run(command)
        return normalize_run_result(first, second, third, fourth, fifth)
    end
    first, second, third, fourth, fifth = reqpack.exec.run(command)
    return normalize_run_result(first, second, third, fourth, fifth)
end

local function ensure_directory(context, path)
    local result = run_command(context, "mkdir -p " .. shell_quote(path))
    if is_command_success(result) then return true, nil end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to create directory: " .. tostring(path))
end

local function path_exists(context, path)
    local result = run_command(context, "test -e " .. shell_quote(path))
    return is_command_success(result)
end

local function directory_exists(context, path)
    local result = run_command(context, "test -d " .. shell_quote(path))
    return is_command_success(result)
end

local function remove_path_if_exists(context, path)
    if not path_exists(context, path) then return true, nil end
    local result = run_command(context, "rm -rf " .. shell_quote(path))
    if is_command_success(result) then return true, nil end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to remove path: " .. tostring(path))
end

local function copy_path(context, source_path, target_path)
    local ok, err = ensure_directory(context, path_dirname(target_path))
    if not ok then return nil, err end
    local result = run_command(context, "cp -R " .. shell_quote(source_path) .. " " .. shell_quote(target_path))
    if is_command_success(result) then return true, nil end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to copy path")
end

local function read_text_file(path)
    local handle = io.open(path, "rb")
    if handle == nil then return nil end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function file_exists(context, path)
    local result = run_command(context, "test -f " .. shell_quote(path))
    return is_command_success(result)
end

local function write_text_file(context, path, content)
    local ok, err = ensure_directory(context, path_dirname(path))
    if not ok then return nil, err end
    local handle = io.open(path, "wb")
    if handle == nil then return nil, "failed to open file for write: " .. tostring(path) end
    local write_ok, write_err = handle:write(content)
    handle:close()
    if not write_ok then return nil, write_err end
    return true, nil
end

local function codepoint_to_utf8(codepoint)
    if codepoint <= 0x7F then return string.char(codepoint) end
    if codepoint <= 0x7FF then return string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + (codepoint % 0x40)) end
    if codepoint <= 0xFFFF then
        return string.char(0xE0 + math.floor(codepoint / 0x1000), 0x80 + (math.floor(codepoint / 0x40) % 0x40), 0x80 + (codepoint % 0x40))
    end
    return string.char(0xF0 + math.floor(codepoint / 0x40000), 0x80 + (math.floor(codepoint / 0x1000) % 0x40), 0x80 + (math.floor(codepoint / 0x40) % 0x40), 0x80 + (codepoint % 0x40))
end

local function normalize_json_tree(value, null_sentinel, seen)
    if value == nil then return nil end
    if null_sentinel ~= nil and value == null_sentinel then return JSON_NULL end
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] ~= nil then return seen[value] end
    local normalized = {}
    seen[value] = normalized
    for key, item in pairs(value) do normalized[key] = normalize_json_tree(item, null_sentinel, seen) end
    return normalized
end

local function decode_json_internal(raw)
    local text = tostring(raw or "")
    local length = #text
    local index = 1
    local function decode_error(message) error(message .. " at byte " .. tostring(index), 0) end
    local function peek() return text:sub(index, index) end
    local function skip_whitespace()
        while index <= length do
            local byte = text:byte(index)
            if byte == 32 or byte == 9 or byte == 10 or byte == 13 then index = index + 1 else break end
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
            elseif current == "\\" then
                parts[#parts + 1] = text:sub(segment_start, index - 1)
                index = index + 1
                if index > length then decode_error("unterminated escape sequence") end
                local escape = text:sub(index, index)
                if escape == '"' or escape == "\\" or escape == "/" then parts[#parts + 1] = escape index = index + 1
                elseif escape == "b" then parts[#parts + 1] = "\b" index = index + 1
                elseif escape == "f" then parts[#parts + 1] = "\f" index = index + 1
                elseif escape == "n" then parts[#parts + 1] = "\n" index = index + 1
                elseif escape == "r" then parts[#parts + 1] = "\r" index = index + 1
                elseif escape == "t" then parts[#parts + 1] = "\t" index = index + 1
                elseif escape == "u" then
                    local hex = text:sub(index + 1, index + 4)
                    if #hex ~= 4 or hex:match("^[0-9a-fA-F]+$") == nil then decode_error("invalid unicode escape") end
                    parts[#parts + 1] = codepoint_to_utf8(tonumber(hex, 16))
                    index = index + 5
                else decode_error("unsupported escape sequence") end
                segment_start = index
            else
                local byte = text:byte(index)
                if byte ~= nil and byte < 32 then decode_error("control character in string") end
                index = index + 1
            end
        end
        decode_error("unterminated string")
    end
    local function parse_number()
        local start_index = index
        if peek() == "-" then index = index + 1 end
        if peek() == "0" then index = index + 1 else
            if peek():match("%d") == nil then decode_error("invalid number") end
            repeat index = index + 1 until index > length or text:sub(index, index):match("%d") == nil
        end
        if peek() == "." then
            index = index + 1
            if peek():match("%d") == nil then decode_error("invalid number") end
            repeat index = index + 1 until index > length or text:sub(index, index):match("%d") == nil
        end
        local exponent = peek()
        if exponent == "e" or exponent == "E" then
            index = index + 1
            local sign = peek()
            if sign == "+" or sign == "-" then index = index + 1 end
            if peek():match("%d") == nil then decode_error("invalid number") end
            repeat index = index + 1 until index > length or text:sub(index, index):match("%d") == nil
        end
        local number = tonumber(text:sub(start_index, index - 1))
        if number == nil then decode_error("invalid number") end
        return number
    end
    local function parse_array()
        index = index + 1
        skip_whitespace()
        local array = {}
        if peek() == "]" then index = index + 1 return array end
        while true do
            array[#array + 1] = parse_value()
            skip_whitespace()
            local current = peek()
            if current == "]" then index = index + 1 return array end
            if current ~= "," then decode_error("expected ',' or ']' in array") end
            index = index + 1
            skip_whitespace()
        end
    end
    local function parse_object()
        index = index + 1
        skip_whitespace()
        local object = {}
        if peek() == "}" then index = index + 1 return object end
        while true do
            if peek() ~= '"' then decode_error("expected string key") end
            local key = parse_string()
            skip_whitespace()
            if peek() ~= ":" then decode_error("expected ':' after object key") end
            index = index + 1
            skip_whitespace()
            object[key] = parse_value()
            skip_whitespace()
            local current = peek()
            if current == "}" then index = index + 1 return object end
            if current ~= "," then decode_error("expected ',' or '}' in object") end
            index = index + 1
            skip_whitespace()
        end
    end
    parse_value = function()
        skip_whitespace()
        local current = peek()
        if current == '"' then return parse_string()
        elseif current == "{" then return parse_object()
        elseif current == "[" then return parse_array()
        elseif current == "-" or (current ~= "" and current:match("%d") ~= nil) then return parse_number()
        elseif text:sub(index, index + 3) == "true" then index = index + 4 return true
        elseif text:sub(index, index + 4) == "false" then index = index + 5 return false
        elseif text:sub(index, index + 3) == "null" then index = index + 4 return JSON_NULL end
        decode_error("unexpected token")
    end
    local value = parse_value()
    skip_whitespace()
    if index <= length then decode_error("trailing content") end
    return value
end

local function load_json_decoder()
    if cached_json_decoder ~= nil then return cached_json_decoder end
    local candidates = {
        function()
            local ok, module = pcall(require, "cjson.safe")
            if ok and module ~= nil and type(module.decode) == "function" then
                return function(raw)
                    local value, err = module.decode(raw)
                    if err ~= nil then error(err, 0) end
                    return normalize_json_tree(value, module.null)
                end
            end
        end,
        function()
            local ok, module = pcall(require, "cjson")
            if ok and module ~= nil and type(module.decode) == "function" then
                return function(raw) return normalize_json_tree(module.decode(raw), module.null) end
            end
        end,
    }
    for _, candidate in ipairs(candidates) do
        local ok, decoder = pcall(candidate)
        if ok and type(decoder) == "function" then cached_json_decoder = decoder return cached_json_decoder end
    end
    cached_json_decoder = decode_json_internal
    return cached_json_decoder
end

local function decode_json(raw)
    local ok, value = pcall(load_json_decoder(), raw)
    if not ok then return nil, tostring(value) end
    return value, nil
end

local function encode_json_string(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\b", "\\b"):gsub("\f", "\\f"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    return '"' .. text .. '"'
end

local function is_array_table(value)
    if type(value) ~= "table" then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key <= 0 or key % 1 ~= 0 then return false end
        if key > count then count = key end
    end
    for index = 1, count do if value[index] == nil then return false end end
    return true
end

local function encode_json(value)
    local t = type(value)
    if value == nil or value == JSON_NULL then return "null" end
    if t == "string" then return encode_json_string(value) end
    if t == "number" or t == "boolean" then return tostring(value) end
    if t ~= "table" then return encode_json_string(tostring(value)) end
    if is_array_table(value) then
        local parts = {}
        for _, item in ipairs(value) do parts[#parts + 1] = encode_json(item) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(left, right) return tostring(left) < tostring(right) end)
    local parts = {}
    for _, key in ipairs(keys) do parts[#parts + 1] = encode_json_string(tostring(key)) .. ":" .. encode_json(value[key]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function get_reqpack_path(name)
    local paths = type(reqpack) == "table" and read_field(reqpack, "paths") or nil
    if type(paths) ~= "table" then return nil end
    return first_nonempty(read_field(paths, name))
end

local function read_proc_environ_value(name)
    if os ~= nil and type(os.getenv) == "function" then
        local current = os.getenv(tostring(name or ""))
        if current ~= nil and current ~= "" then return trim(current) end
    end
    local handle = io.open("/proc/self/environ", "rb")
    if handle == nil then return nil end
    local payload = handle:read("*a")
    handle:close()
    if payload == nil or payload == "" then return nil end
    local prefix = tostring(name or "") .. "="
    for entry in tostring(payload):gmatch("[^%z]+") do
        if starts_with(entry, prefix) then return trim(entry:sub(#prefix + 1)) end
    end
    return nil
end

local function aicache_root()
    local data_root = get_reqpack_path("dataRoot")
    if data_root ~= nil then return join_path(data_root, "aicache") end
    local xdg = read_proc_environ_value("XDG_DATA_HOME")
    if xdg ~= nil and xdg ~= "" then return join_path(xdg, "aicache") end
    local home = read_proc_environ_value("HOME")
    if home ~= nil and home ~= "" then return join_path(home, ".local", "share", "aicache") end
    return nil
end

local function ghskill_root()
    local home = read_proc_environ_value("HOME")
    if home == nil or home == "" then return nil end
    return join_path(home, ".local", "share", "ghskill")
end

local function ghskill_reqpack_root()
    local root = ghskill_root()
    return root ~= nil and join_path(root, "reqpack") or nil
end

local function app_metadata_path()
    local root = ghskill_reqpack_root()
    return root ~= nil and join_path(root, "app.json") or nil
end

local function projections_metadata_path()
    local root = ghskill_reqpack_root()
    return root ~= nil and join_path(root, "projections.json") or nil
end

local function ensure_roots(context)
    local root = ghskill_root()
    local reqpack_root = ghskill_reqpack_root()
    local aicache = aicache_root()
    if root == nil or reqpack_root == nil or aicache == nil then return nil, "ghskill roots unavailable" end
    for _, path in ipairs({ root, reqpack_root, join_path(aicache, "artifacts"), join_path(aicache, "views") }) do
        local ok, err = ensure_directory(context, path)
        if not ok then return nil, err end
    end
    return { root = root, reqpack = reqpack_root, aicache = aicache }, nil
end

local function load_json_file(path)
    local content = read_text_file(path)
    if content == nil then return nil, nil end
    return decode_json(content)
end

local function save_json_file(context, path, payload)
    return write_text_file(context, path, encode_json(payload))
end

local function load_app_metadata()
    return load_json_file(app_metadata_path())
end

local function save_app_metadata(context, payload)
    return save_json_file(context, app_metadata_path(), payload)
end

local function empty_projections_payload() return { projections = {} } end

local function load_projections_payload()
    local payload, err = load_json_file(projections_metadata_path())
    if payload == nil then return empty_projections_payload(), err end
    if type(payload) ~= "table" or type(payload.projections) ~= "table" then return empty_projections_payload(), nil end
    return payload, nil
end

local function save_projections_payload(context, payload)
    return save_json_file(context, projections_metadata_path(), payload)
end

local function current_timestamp_utc(context)
    local result = run_command(context, "date -u +%Y-%m-%dT%H:%M:%SZ")
    if result == nil or not is_command_success(result) then return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to capture timestamp") end
    return trim(result.stdout), nil
end

local function package_name(package)
    local name = read_field(package, "name")
    return trim(name ~= nil and name or package)
end

local function package_flags(package)
    local flags = read_field(package, "flags")
    return type(flags) == "table" and flags or {}
end

local function is_app_package_name(name)
    return lower(trim(name)) == APP_PACKAGE_NAME
end

local function parse_package_flags(package)
    local opts = { agents = {}, scope = nil, dir = nil, pin = nil, force = false, allowHiddenDirs = false, upstream = false }
    for _, flag in ipairs(package_flags(package)) do
        local text = trim(flag)
        local agent = text:match("^agent=(.+)$")
        local scope = text:match("^scope=(.+)$")
        local dir = text:match("^dir=(.+)$")
        local pin = text:match("^pin=(.+)$")
        if agent ~= nil then
            opts.agents[#opts.agents + 1] = agent
        elseif scope ~= nil then
            opts.scope = scope
        elseif dir ~= nil then
            opts.dir = dir
        elseif pin ~= nil then
            opts.pin = pin
        elseif lower(text) == "force" then
            opts.force = true
        elseif lower(text) == "allow-hidden-dirs" then
            opts.allowHiddenDirs = true
        elseif lower(text) == "upstream" then
            opts.upstream = true
        end
    end
    return opts
end

local function parse_skill_package(name)
    local text = trim(name)
    if text == "" then return nil, "ghskill package missing name" end
    if is_app_package_name(text) then
        return { kind = "app", packageId = APP_PACKAGE_NAME }, nil
    end
    local owner, repo, selector = text:match("^([A-Za-z0-9_.%-]+)/([A-Za-z0-9_.%-]+)/(.+)$")
    if owner == nil then return nil, "ghskill package must use owner/repo/skill or owner/repo/skills/..." end
    if selector == nil or trim(selector) == "" then return nil, "ghskill install requires concrete skill selector" end
    return {
        kind = "skill",
        owner = owner,
        repo = repo,
        source = owner .. "/" .. repo,
        sourceUrl = "https://github.com/" .. owner .. "/" .. repo,
        selector = trim(selector),
        packageId = owner .. "/" .. repo .. "/" .. trim(selector),
    }, nil
end

local function static_app_item(version)
    return {
        name = APP_PACKAGE_NAME,
        packageId = APP_PACKAGE_NAME,
        version = version,
        latestVersion = version,
        summary = "GitHub CLI gh skill launcher",
        description = "GitHub CLI gh skill launcher",
        homepage = APP_HOMEPAGE,
        sourceUrl = APP_HOMEPAGE,
        packageType = "app",
        type = "package",
    }
end

local function app_item_from_metadata(metadata)
    local item = static_app_item(first_nonempty(read_field(metadata, "version")))
    item.extraFields = { detectedAt = read_field(metadata, "detected_at") }
    return item
end

local function build_skill_item(record)
    if type(record) ~= "table" then return nil end
    local package_id = trim(read_field(record, "package_id") or "")
    if package_id == "" then return nil end
    return {
        name = package_id,
        packageId = package_id,
        version = first_nonempty(read_field(record, "installed_revision"), read_field(record, "installed_at")),
        latestVersion = first_nonempty(read_field(record, "installed_revision"), read_field(record, "installed_at")),
        summary = "GitHub CLI skill projection",
        description = "GitHub CLI skill projection",
        homepage = read_field(record, "source_url"),
        sourceUrl = read_field(record, "source_url"),
        packageType = "skill",
        type = "package",
        extraFields = {
            source = read_field(record, "source"),
            selector = read_field(record, "selector"),
            skillName = read_field(record, "skill_name"),
            artifactId = read_field(record, "artifact_id"),
            artifactPath = read_field(record, "artifact_path"),
            scope = read_field(record, "scope"),
            agents = read_field(record, "agents"),
            targetPaths = read_field(record, "target_paths"),
            pin = read_field(record, "pin"),
            installedAt = read_field(record, "installed_at"),
        },
    }
end

local function detect_launcher(context)
    local help = run_command(context, "gh skill --help")
    if help == nil or not is_command_success(help) then return nil, "ghskill launcher unavailable: gh skill not found" end
    local version_result = run_command(context, "gh --version")
    if version_result == nil or not is_command_success(version_result) then return nil, "ghskill launcher unavailable: gh --version failed" end
    local version = trim((version_result.stdout or ""):match("gh version ([^%s]+)") or version_result.stdout)
    return { command = "gh skill", version = version }, nil
end

local function parse_search_results(raw)
    local decoded, err = decode_json(raw)
    if decoded == nil then return nil, err end
    if type(decoded) ~= "table" then return {}, nil end
    return decoded, nil
end

local function unquote_yaml_value(value)
    local text = trim(value)
    local quote = text:sub(1, 1)
    if #text >= 2 and (quote == '"' or quote == "'") and text:sub(-1) == quote then
        return text:sub(2, -2)
    end
    return text
end

local function parse_skill_frontmatter(raw)
    local text = tostring(raw or "")
    local lines = {}
    for line in text:gmatch("([^\n]*)\n?") do lines[#lines + 1] = line:gsub("\r$", "") end
    if trim(lines[1] or "") ~= "---" then return nil end
    local payload = { metadata = {} }
    local in_metadata = false
    for index = 2, #lines do
        local line = lines[index]
        if trim(line) == "---" then return payload end
        if in_metadata then
            local child_key, child_value = line:match("^%s%s([%w_.-]+):%s*(.-)%s*$")
            if child_key ~= nil then
                payload.metadata[child_key] = unquote_yaml_value(child_value)
            elseif trim(line) ~= "" then
                in_metadata = false
            end
        end
        if not in_metadata then
            local key, value = line:match("^([%w_.-]+):%s*(.-)%s*$")
            if key ~= nil then
                if key == "metadata" then
                    in_metadata = true
                else
                    payload[key] = unquote_yaml_value(value)
                end
            end
        end
    end
    return nil
end

local function read_selector_path(selector)
    local text = trim(selector)
    if starts_with(text, "skills/") then return text end
    return nil
end

local function default_skill_name(selector)
    local text = trim(selector)
    return text:match("([^/]+)$") or text
end

local function skill_markdown_path(target_path)
    local text = trim(target_path)
    if text == "" then return nil end
    if text:match("/SKILL%.md$") ~= nil then return text end
    return join_path(text, "SKILL.md")
end

local function frontmatter_metadata_from_projection(context, record)
    local target_paths = type(read_field(record, "target_paths")) == "table" and read_field(record, "target_paths") or {}
    for _, target_path in ipairs(target_paths) do
        local skill_path = skill_markdown_path(target_path)
        if skill_path ~= nil and file_exists(context, skill_path) then
            local parsed = parse_skill_frontmatter(read_text_file(skill_path))
            if parsed ~= nil then return parsed, skill_path end
        end
    end
    return nil, nil
end

local function revision_from_frontmatter(parsed)
    if type(parsed) ~= "table" then return nil end
    local metadata = type(read_field(parsed, "metadata")) == "table" and read_field(parsed, "metadata") or {}
    return first_nonempty(read_field(metadata, "github-tree-sha"), read_field(metadata, "github-ref"), read_field(metadata, "github-pinned"))
end

local function projection_target_paths(spec, options)
    local paths = {}
    if options.dir ~= nil and trim(options.dir) ~= "" then
        paths[#paths + 1] = join_path(options.dir, default_skill_name(spec.selector))
        return paths, "custom-dir"
    end
    if options.scope == "user" then
        local home = read_proc_environ_value("HOME")
        if home ~= nil and home ~= "" then
            local agents = #options.agents > 0 and options.agents or { "github-copilot" }
            for _, agent in ipairs(agents) do
                if agent == "opencode" then
                    paths[#paths + 1] = join_path(home, ".config", "opencode", "skills", default_skill_name(spec.selector))
                elseif agent == "claude-code" then
                    paths[#paths + 1] = join_path(home, ".claude", "skills", default_skill_name(spec.selector))
                else
                    paths[#paths + 1] = join_path(home, ".agents", "skills", default_skill_name(spec.selector))
                end
            end
            return paths, "user"
        end
    end
    paths[#paths + 1] = ".agents/skills/" .. default_skill_name(spec.selector)
    return paths, "project"
end

local function choose_installed_revision(options, installed_at)
    return first_nonempty(options.pin, installed_at)
end

local function artifact_dir(artifact_id)
    local root = aicache_root()
    if root == nil then return nil end
    return join_path(root, "artifacts", artifact_id)
end

local function repo_view_path(source)
    local root = aicache_root()
    if root == nil then return nil end
    return join_path(root, "views", "by-source", "ghskill", "repo", normalize_token(source), "current.json")
end

local function skill_view_path(source, selector)
    local root = aicache_root()
    if root == nil then return nil end
    return join_path(root, "views", "by-source", "ghskill", "skill", normalize_token(source), normalize_token(selector), "current.json")
end

local function write_current_view(context, path, payload)
    return write_text_file(context, path, encode_json(payload))
end

local function read_current_view(path)
    local content = read_text_file(path)
    if content == nil then return nil end
    return decode_json(content)
end

local function make_repo_artifact_id(source, revision)
    return join_path("ghskill", "repo", normalize_token(source) .. "@" .. normalize_token(revision))
end

local function make_skill_artifact_id(source, selector, revision)
    return join_path("ghskill", "skill", normalize_token(source), normalize_token(selector) .. "@" .. normalize_token(revision))
end

local function write_artifact(context, artifact_id, manifest, source_meta, files_payload)
    local root = artifact_dir(artifact_id)
    if root == nil then return nil, "ghskill artifact root unavailable" end
    local ok, err = ensure_directory(context, root)
    if not ok then return nil, err end
    ok, err = write_text_file(context, join_path(root, "manifest.json"), encode_json(manifest))
    if not ok then return nil, err end
    ok, err = write_text_file(context, join_path(root, "source.json"), encode_json(source_meta))
    if not ok then return nil, err end
    ok, err = write_text_file(context, join_path(root, "files.json"), encode_json(files_payload))
    if not ok then return nil, err end
    return root, nil
end

local function install_app(context)
    local roots, root_error = ensure_roots(context)
    if roots == nil then return nil, root_error end
    local launcher, launcher_error = detect_launcher(context)
    if launcher == nil then return nil, launcher_error end
    local detected_at, time_error = current_timestamp_utc(context)
    if detected_at == nil then return nil, time_error end
    local metadata = { version = launcher.version, detected_at = detected_at }
    local ok, err = save_app_metadata(context, metadata)
    if not ok then return nil, err end
    return app_item_from_metadata(metadata), nil
end

local function install_skill(context, package)
    local roots, root_error = ensure_roots(context)
    if roots == nil then return nil, root_error end
    local spec, spec_error = parse_skill_package(package_name(package))
    if spec == nil then return nil, spec_error end
    local options = parse_package_flags(package)
    local launcher, launcher_error = detect_launcher(context)
    if launcher == nil then return nil, launcher_error end
    local selector = spec.selector
    if trim(selector) == "" then return nil, "ghskill install requires concrete skill selector" end
    local command = "gh skill install " .. shell_quote(spec.source) .. " " .. shell_quote(selector)
    for _, agent in ipairs(options.agents) do command = command .. " --agent " .. shell_quote(agent) end
    if options.scope ~= nil then command = command .. " --scope " .. shell_quote(options.scope) end
    if options.dir ~= nil then command = command .. " --dir " .. shell_quote(options.dir) end
    if options.pin ~= nil then command = command .. " --pin " .. shell_quote(options.pin) end
    if options.force then command = command .. " --force" end
    if options.allowHiddenDirs then command = command .. " --allow-hidden-dirs" end
    if options.upstream then command = command .. " --upstream" end
    local result = run_command(context, command)
    if result == nil or not is_command_success(result) then return nil, first_nonempty(result and result.stderr, result and result.stdout, "ghskill install failed") end
    local installed_at, time_error = current_timestamp_utc(context)
    if installed_at == nil then return nil, time_error end
    local revision = choose_installed_revision(options, installed_at)
    local target_paths, effective_scope = projection_target_paths(spec, options)
    local parsed = select(1, frontmatter_metadata_from_projection(context, {
        package_id = spec.packageId,
        target_paths = target_paths,
    }))
    local frontmatter_revision = revision_from_frontmatter(parsed)
    if frontmatter_revision ~= nil and frontmatter_revision ~= "" then revision = frontmatter_revision end
    local repo_artifact_id = make_repo_artifact_id(spec.source, revision)
    local repo_artifact_path, repo_err = write_artifact(context, repo_artifact_id, {
        kind = "skill-repo",
        created_at = installed_at,
        source = { system = "ghskill", normalized_source = spec.source, source_url = spec.sourceUrl, revision = revision },
    }, {
        package_id = spec.source,
        package_kind = "repo",
        source = spec.source,
        source_url = spec.sourceUrl,
        selector = selector,
        skill_name = default_skill_name(selector),
        upstream_metadata = { launcher = "gh", version = launcher.version },
    }, { files = {} })
    if repo_artifact_path == nil then return nil, repo_err end
    local skill_artifact_id = make_skill_artifact_id(spec.source, selector, revision)
    local skill_artifact_path, skill_err = write_artifact(context, skill_artifact_id, {
        kind = "skill-bundle",
        created_at = installed_at,
        source = { system = "ghskill", normalized_source = spec.source, source_url = spec.sourceUrl, revision = revision, selector = selector, skill_name = default_skill_name(selector) },
    }, {
        package_id = spec.packageId,
        package_kind = "skill",
        source = spec.source,
        source_url = spec.sourceUrl,
        selector = selector,
        skill_name = default_skill_name(selector),
        upstream_metadata = { launcher = "gh", version = launcher.version },
    }, { files = {} })
    if skill_artifact_path == nil then return nil, skill_err end
    local projection = {
        package_id = spec.packageId,
        source = spec.source,
        source_url = spec.sourceUrl,
        selector = selector,
        skill_name = default_skill_name(selector),
        artifact_id = skill_artifact_id,
        artifact_path = skill_artifact_path,
        scope = effective_scope,
        agents = options.agents,
        target_paths = target_paths,
        installed_at = installed_at,
        installed_revision = revision,
        pin = options.pin,
    }
    local payload, payload_error = load_projections_payload()
    if payload == nil then return nil, payload_error end
    local replaced = false
    for index, record in ipairs(payload.projections or {}) do
        if trim(read_field(record, "package_id") or "") == spec.packageId then payload.projections[index] = projection replaced = true break end
    end
    if not replaced then payload.projections[#payload.projections + 1] = projection end
    local ok, err = save_projections_payload(context, payload)
    if not ok then return nil, err end
    ok, err = write_current_view(context, repo_view_path(spec.source), {
        artifact_id = repo_artifact_id,
        artifact_path = repo_artifact_path,
        source = spec.source,
        source_url = spec.sourceUrl,
        revision = revision,
        package_id = spec.source,
        kind = "repo",
    })
    if not ok then return nil, err end
    ok, err = write_current_view(context, skill_view_path(spec.source, selector), {
        artifact_id = skill_artifact_id,
        artifact_path = skill_artifact_path,
        source = spec.source,
        source_url = spec.sourceUrl,
        revision = revision,
        package_id = spec.packageId,
        kind = "skill",
        skill_name = default_skill_name(selector),
        selector = selector,
    })
    if not ok then return nil, err end
    return build_skill_item(projection), nil
end

local function remove_skill(context, package)
    local spec, spec_error = parse_skill_package(package_name(package))
    if spec == nil then return nil, spec_error end
    local payload, payload_error = load_projections_payload()
    if payload == nil then return nil, payload_error end
    local kept = {}
    local removed = nil
    for _, record in ipairs(payload.projections or {}) do
        if trim(read_field(record, "package_id") or "") == spec.packageId then
            removed = record
        else
            kept[#kept + 1] = record
        end
    end
    payload.projections = kept
    local ok, err = save_projections_payload(context, payload)
    if not ok then return nil, err end
    if removed ~= nil then
        for _, target_path in ipairs(read_field(removed, "target_paths") or {}) do
            local remove_ok, remove_err = remove_path_if_exists(context, target_path)
            if not remove_ok then return nil, remove_err end
        end
        return build_skill_item(removed), nil
    end
    return build_skill_item({ package_id = spec.packageId, source = spec.source, source_url = spec.sourceUrl, selector = spec.selector, skill_name = default_skill_name(spec.selector) }), nil
end

local function info_from_cached_view(spec)
    local path = skill_view_path(spec.source, spec.selector)
    local view = read_current_view(path)
    if type(view) ~= "table" then return nil end
    return build_skill_item({
        package_id = read_field(view, "package_id") or spec.packageId,
        source = read_field(view, "source") or spec.source,
        source_url = read_field(view, "source_url") or spec.sourceUrl,
        selector = read_field(view, "selector") or spec.selector,
        skill_name = read_field(view, "skill_name") or default_skill_name(spec.selector),
        artifact_id = read_field(view, "artifact_id"),
        artifact_path = read_field(view, "artifact_path"),
        installed_revision = read_field(view, "revision"),
    })
end

local function cached_view_root(kind)
    local root = aicache_root()
    if root == nil then return nil end
    return join_path(root, "views", "by-source", "ghskill", kind)
end

local function collect_cached_view_items(context, kind, items, seen)
    local root = cached_view_root(kind)
    if root == nil or not directory_exists(context, root) then return end
    local result = run_command(context, "find " .. shell_quote(root) .. " -type f -name current.json | LC_ALL=C sort")
    if result == nil or not is_command_success(result) then return end
    for line in tostring(result.stdout or ""):gmatch("[^\r\n]+") do
        local payload = read_current_view(trim(line))
        if type(payload) == "table" then
            local item = nil
            if kind == "skill" then
                item = build_skill_item({
                    package_id = read_field(payload, "package_id"),
                    source = read_field(payload, "source"),
                    source_url = read_field(payload, "source_url"),
                    selector = read_field(payload, "selector"),
                    skill_name = read_field(payload, "skill_name"),
                    artifact_id = read_field(payload, "artifact_id"),
                    artifact_path = read_field(payload, "artifact_path"),
                    installed_revision = read_field(payload, "revision"),
                })
            elseif kind == "repo" then
                item = build_skill_item({
                    package_id = read_field(payload, "package_id"),
                    source = read_field(payload, "source"),
                    source_url = read_field(payload, "source_url"),
                    selector = read_field(payload, "selector") or "repo",
                    skill_name = read_field(payload, "skill_name") or "repo",
                    artifact_id = read_field(payload, "artifact_id"),
                    artifact_path = read_field(payload, "artifact_path"),
                    installed_revision = read_field(payload, "revision"),
                })
            end
            local key = item and trim(item.packageId or item.name or "") or ""
            if item ~= nil and key ~= "" and not seen[key] then
                seen[key] = true
                items[#items + 1] = item
            end
        end
    end
end

local function apply_frontmatter_to_item(item, parsed, skill_path)
    if item == nil or type(parsed) ~= "table" then return item end
    item.summary = first_nonempty(read_field(parsed, "description"), read_field(parsed, "name"), item.summary)
    item.description = first_nonempty(read_field(parsed, "description"), item.description)
    local metadata = type(read_field(parsed, "metadata")) == "table" and read_field(parsed, "metadata") or {}
    item.version = first_nonempty(
        read_field(metadata, "github-tree-sha"),
        read_field(metadata, "github-ref"),
        read_field(metadata, "skillFolderHash"),
        item.version
    )
    item.latestVersion = item.version
    item.extraFields = type(item.extraFields) == "table" and item.extraFields or {}
    item.extraFields.frontmatterName = read_field(parsed, "name")
    item.extraFields.frontmatterDescription = read_field(parsed, "description")
    item.extraFields.frontmatterLicense = read_field(parsed, "license")
    item.extraFields.frontmatterAuthor = read_field(parsed, "author")
    item.extraFields.frontmatterHomepage = read_field(parsed, "homepage")
    item.extraFields.frontmatterMetadata = metadata
    item.extraFields.githubRepo = read_field(metadata, "github-repo")
    item.extraFields.githubRef = read_field(metadata, "github-ref")
    item.extraFields.githubTreeSha = read_field(metadata, "github-tree-sha")
    item.extraFields.githubPath = read_field(metadata, "github-path")
    item.extraFields.githubPinned = read_field(metadata, "github-pinned")
    item.extraFields.skillFolderHash = read_field(metadata, "skillFolderHash")
    item.extraFields.skillMarkdownPath = skill_path
    item.homepage = first_nonempty(read_field(parsed, "homepage"), item.homepage)
    item.sourceUrl = first_nonempty(read_field(parsed, "homepage"), item.sourceUrl)
    return item
end

function plugin.getName() return PLUGIN_NAME end
function plugin.getVersion() return PLUGIN_VERSION end
function plugin.getRequirements() return {} end
function plugin.getCategories() return { "AI", "Package Manager", "GitHub CLI" } end

function plugin.getMissingPackages(packages)
    local missing = {}
    local app_metadata = select(1, load_app_metadata())
    local payload = select(1, load_projections_payload()) or empty_projections_payload()
    for _, package in ipairs(packages or {}) do
        local name = package_name(package)
        if is_app_package_name(name) then
            if app_metadata == nil then missing[#missing + 1] = package end
        else
            local spec = select(1, parse_skill_package(name))
            local found = false
            if spec ~= nil then
                for _, record in ipairs(payload.projections or {}) do
                    if trim(read_field(record, "package_id") or "") == spec.packageId then found = true break end
                end
            end
            if not found then missing[#missing + 1] = package end
        end
    end
    return missing
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then return true end
    local installed = {}
    for _, package in ipairs(requested) do
        local name = package_name(package)
        local item, err
        if is_app_package_name(name) then
            begin_step(context, "install ghskill app")
            item, err = install_app(context)
        else
            begin_step(context, "install ghskill skill")
            item, err = install_skill(context, package)
        end
        if item == nil then tx_failed(context, err) return false end
        installed[#installed + 1] = item
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    tx_failed(context, "ghskill plugin does not support installLocal()")
    emit_event(context, "unavailable", { path = path, reason = "local-install-unsupported" })
    return false
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then return true end
    local removed = {}
    for _, package in ipairs(requested) do
        local name = package_name(package)
        if is_app_package_name(name) then
            begin_step(context, "remove ghskill app")
            local ok, err = remove_path_if_exists(context, app_metadata_path())
            if not ok then tx_failed(context, err) return false end
            removed[#removed + 1] = static_app_item(nil)
        else
            begin_step(context, "remove ghskill skill")
            local item, err = remove_skill(context, package)
            if item == nil then tx_failed(context, err) return false end
            removed[#removed + 1] = item
        end
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    if #requested == 0 then return true end
    local updated = {}
    for _, package in ipairs(requested) do
        local name = package_name(package)
        local item, err
        if is_app_package_name(name) then
            begin_step(context, "update ghskill app")
            item, err = install_app(context)
        else
            begin_step(context, "update ghskill skill")
            item, err = install_skill(context, package)
        end
        if item == nil then tx_failed(context, err) return false end
        updated[#updated + 1] = item
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = {}
    local seen = {}
    local app_metadata = select(1, load_app_metadata())
    if app_metadata ~= nil then
        local item = app_item_from_metadata(app_metadata)
        items[#items + 1] = item
        seen[item.packageId] = true
    else
        local launcher = select(1, detect_launcher(context))
        if launcher ~= nil then
            local item = static_app_item(launcher.version)
            items[#items + 1] = item
            seen[item.packageId] = true
        end
    end
    local payload = select(1, load_projections_payload()) or empty_projections_payload()
    for _, record in ipairs(payload.projections or {}) do
        local item = build_skill_item(record)
        local parsed, skill_path = frontmatter_metadata_from_projection(context, record)
        item = apply_frontmatter_to_item(item, parsed, skill_path)
        local key = item and trim(item.packageId or item.name or "") or ""
        if item ~= nil and key ~= "" and not seen[key] then seen[key] = true items[#items + 1] = item end
    end
    collect_cached_view_items(context, "repo", items, seen)
    collect_cached_view_items(context, "skill", items, seen)
    table.sort(items, function(left, right) return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "") end)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local results = {}
    local launcher = select(1, detect_launcher(context))
    if launcher == nil then
        emit_event(context, "outdated", results)
        return results
    end
    local payload = select(1, load_projections_payload()) or empty_projections_payload()
    for _, record in ipairs(payload.projections or {}) do
        local skill_name = trim(read_field(record, "skill_name") or "")
        if skill_name ~= "" then
            local command = "gh skill update " .. shell_quote(skill_name) .. " --dry-run"
            local result = run_command(context, command)
            local output = lower(trim(first_nonempty(result and result.stderr, result and result.stdout, "") or ""))
            if result ~= nil and is_command_success(result) and output ~= "" and output:find("up to date", 1, true) == nil and output:find("pinned", 1, true) == nil and output:find("no github metadata", 1, true) == nil then
                local item = build_skill_item(record)
                if item ~= nil then
                    item.extraFields = type(item.extraFields) == "table" and item.extraFields or {}
                    item.extraFields.updateCheckOutput = trim(first_nonempty(result.stderr, result.stdout, ""))
                    results[#results + 1] = item
                end
            end
        end
    end
    emit_event(context, "outdated", results)
    return results
end

function plugin.search(context, prompt)
    local query = trim(prompt)
    local lowered = lower(query)
    local results = {}
    if query == "" or lowered == APP_PACKAGE_NAME or lowered:find("gh skill", 1, true) ~= nil or lowered:find("github skill", 1, true) ~= nil or lowered:find("ghskill", 1, true) ~= nil then
        results[#results + 1] = static_app_item(nil)
    end
    if query ~= "" then
        local launcher = select(1, detect_launcher(context))
        if launcher ~= nil then
            local result = run_command(context, "gh skill search " .. shell_quote(query) .. " --json description,namespace,path,repo,skillName,stars --limit 15")
            if result ~= nil and is_command_success(result) then
                local decoded = select(1, parse_search_results(result.stdout or "[]")) or {}
                for _, entry in ipairs(decoded) do
                    local repo = trim(read_field(entry, "repo") or "")
                    local skill_name = trim(read_field(entry, "skillName") or "")
                    local path = trim(read_field(entry, "path") or "")
                    if repo ~= "" and skill_name ~= "" then
                        local selector = starts_with(path, "skills/") and path or skill_name
                        results[#results + 1] = {
                            name = repo .. "/" .. skill_name,
                            packageId = repo .. "/" .. selector,
                            version = nil,
                            latestVersion = nil,
                            summary = first_nonempty(read_field(entry, "description"), "GitHub skill"),
                            description = first_nonempty(read_field(entry, "description"), "GitHub skill"),
                            homepage = "https://github.com/" .. repo,
                            sourceUrl = "https://github.com/" .. repo,
                            packageType = "skill",
                            type = "package",
                            extraFields = { selector = selector, skillName = skill_name, repo = repo, path = path, stars = read_field(entry, "stars") },
                        }
                    end
                end
            end
        end
    end
    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local requested = trim(name)
    if requested == "" then return {} end
    if is_app_package_name(requested) then
        local metadata = select(1, load_app_metadata())
        local item = metadata ~= nil and app_item_from_metadata(metadata) or static_app_item(select(1, detect_launcher(context)) and select(1, detect_launcher(context)).version or nil)
        emit_event(context, "informed", item)
        return item
    end
    local spec = select(1, parse_skill_package(requested))
    if spec == nil then return {} end
    local payload = select(1, load_projections_payload()) or empty_projections_payload()
    for _, record in ipairs(payload.projections or {}) do
        if trim(read_field(record, "package_id") or "") == spec.packageId then
            local item = build_skill_item(record)
            local parsed, skill_path = frontmatter_metadata_from_projection(context, record)
            item = apply_frontmatter_to_item(item, parsed, skill_path)
            emit_event(context, "informed", item)
            return item
        end
    end
    local cached = info_from_cached_view(spec)
    if cached ~= nil then emit_event(context, "informed", cached) return cached end
    return {}
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == "" then return nil end
    if is_app_package_name(name) then return static_app_item(nil) end
    return plugin.info(context, name)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "gh-skill", "agent-skills" },
        writeScopes = {
            { kind = "temp" },
            { kind = "user-home-subpath", value = ".local/share/aicache" },
            { kind = "user-home-subpath", value = ".local/share/ghskill" },
            { kind = "user-home-subpath", value = ".config/opencode/skills" },
            { kind = "user-home-subpath", value = ".agents/skills" },
        },
        networkScopes = {
            { host = "github.com", scheme = "https" },
            { host = "api.github.com", scheme = "https" },
        },
        privilegeLevel = "user",
        purlType = "generic",
    }
end

function plugin.init() return true end
function plugin.shutdown() return true end

return plugin
