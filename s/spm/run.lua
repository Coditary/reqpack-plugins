plugin = {}

local PLUGIN_ID = "spm"
local PLUGIN_NAME = "Skill Package Manager"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "spm"
local JSON_NULL = {}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function non_empty(value)
    local text = trim(value)
    if text == "" then
        return nil
    end
    return text
end

local function lower(value)
    return tostring(value or ""):lower()
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function is_safe_token(value)
    return tostring(value or ""):match("^[A-Za-z0-9_./:@%%+=,-]+$") ~= nil
end

local function shell_arg(value)
    local text = tostring(value or "")
    if is_safe_token(text) then
        return text
    end
    return shell_quote(text)
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
    if type(first) == "table" and first.success ~= nil then
        return first
    end

    local result = {}

    local function merge_exec_like(value)
        for _, key in ipairs({ "success", "ok", "stdout", "stderr", "exitCode", "exit_code", "code", "status" }) do
            local ok, item = pcall(function()
                return value[key]
            end)
            if ok and item ~= nil and result[key] == nil then
                result[key] = item
            end
        end
    end

    local function merge_scalar(value)
        local value_type = type(value)
        if value_type == "table" then
            for key, item in pairs(value) do
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

    merge_scalar(first)
    merge_scalar(second)
    merge_scalar(third)
    merge_scalar(fourth)
    merge_scalar(fifth)

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
        return normalize_run_result(first, second, third, fourth, fifth)
    end
    first, second, third, fourth, fifth = reqpack.exec.run(command)
    return normalize_run_result(first, second, third, fourth, fifth)
end

local function command_exists(binary)
    local result = reqpack.exec.run("command -v " .. binary .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
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
        local start = index
        local current = peek()
        if current == "-" then
            index = index + 1
        end
        current = peek()
        if current == "0" then
            index = index + 1
        elseif current:match("%d") then
            repeat
                index = index + 1
                current = peek()
            until not current:match("%d")
        else
            decode_error("invalid number")
        end

        if peek() == "." then
            index = index + 1
            if not peek():match("%d") then
                decode_error("invalid number fraction")
            end
            repeat
                index = index + 1
                current = peek()
            until not current:match("%d")
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
            until not current:match("%d")
        end

        return tonumber(text:sub(start, index - 1))
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
                decode_error("expected ',' or ']' in array")
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
                decode_error("expected ':' after object key")
            end
            index = index + 1
            skip_whitespace()
            result[key] = parse_value()
            skip_whitespace()

            local current = peek()
            if current == "," then
                index = index + 1
                skip_whitespace()
            elseif current == "}" then
                index = index + 1
                return result
            else
                decode_error("expected ',' or '}' in object")
            end
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

    skip_whitespace()
    local decoded = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("trailing data")
    end
    return decoded
end

local function json_value(value)
    if value == JSON_NULL then
        return nil
    end
    return value
end

local function decode_json(raw)
    local ok, decoded = pcall(decode_json_internal, raw)
    if not ok then
        return nil, decoded
    end
    return decoded, nil
end

local function decode_result_json(result)
    local stdout = type(result) == "table" and tostring(result.stdout or "") or ""
    if trim(stdout) == "" then
        return nil, "empty stdout"
    end
    return decode_json(stdout)
end

local function read_text_file(path)
    local handle = io.open(path, "rb")
    if handle == nil then
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        local value = non_empty(os.getenv(name))
        if value ~= nil then
            return value
        end
    end

    local handle = io.open("/proc/self/environ", "rb")
    if handle == nil then
        return nil
    end

    local payload = handle:read("*a")
    handle:close()
    if payload == nil then
        return nil
    end

    local prefix = tostring(name or "") .. "="
    for entry in tostring(payload):gmatch("[^%z]+") do
        if entry:sub(1, #prefix) == prefix then
            return non_empty(entry:sub(#prefix + 1))
        end
    end

    return nil
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local raw = tostring(select(index, ...) or "")
        if raw ~= "" then
            raw = raw:gsub("/+$", "")
            if #parts == 0 then
                parts[#parts + 1] = raw
            else
                parts[#parts + 1] = raw:gsub("^/+", "")
            end
        end
    end
    return table.concat(parts, "/")
end

local function home_dir()
    return getenv("HOME") or "$HOME"
end

local function project_root()
    return getenv("PWD") or "."
end

local function project_manifest_path()
    return join_path(project_root(), "skills.json")
end

local function project_lockfile_path()
    return join_path(project_root(), "skills-lock.json")
end

local function spm_store_root()
    return join_path(home_dir(), ".spm", "skills")
end

local function spm_cache_root()
    return join_path(home_dir(), ".spm", "cache")
end

local function parse_json_file(path)
    local content = read_text_file(path)
    if content == nil then
        return nil
    end
    local decoded = select(1, decode_json(content))
    return decoded
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageId") or read_field(pkg, "id"))
end

local function package_version(pkg)
    return trim(read_field(pkg, "version"))
end

local function package_flags(pkg)
    local flags = read_field(pkg, "flags")
    if type(flags) ~= "table" then
        return {}
    end
    return flags
end

local function package_flag_lookup(pkg)
    local lookup = {}
    for _, flag in ipairs(package_flags(pkg)) do
        local text = trim(flag)
        if text ~= "" then
            local key, value = text:match("^([^=]+)=(.*)$")
            if key ~= nil then
                lookup[trim(key)] = trim(value)
            else
                lookup[text] = true
            end
        end
    end
    return lookup
end

local function install_specifier(pkg)
    local name = package_name(pkg)
    if name == "" then
        return nil
    end
    local version = package_version(pkg)
    if version ~= "" then
        return name .. "@" .. version
    end
    return name
end

local function load_project_manifest()
    local decoded = parse_json_file(project_manifest_path())
    if type(decoded) ~= "table" then
        return {}
    end
    local skills = read_field(decoded, "skills")
    if type(skills) ~= "table" then
        return {}
    end
    return skills
end

local function load_project_lockfile()
    local decoded = parse_json_file(project_lockfile_path())
    if type(decoded) ~= "table" then
        return {}
    end
    local skills = read_field(decoded, "skills")
    if type(skills) ~= "table" then
        return {}
    end
    return skills
end

local function read_manifest_range(manifest_skills, name)
    local value = read_field(manifest_skills, name)
    if type(value) == "string" then
        return non_empty(value)
    end
    if type(value) == "table" then
        return first_nonempty(read_field(value, "range"), read_field(value, "version"), read_field(value, "specifier"))
    end
    return nil
end

local function read_lock_entry(lock_skills, name)
    local value = read_field(lock_skills, name)
    if type(value) == "table" then
        return value
    end
    return nil
end

local function make_store_path(name, version)
    local clean_name = non_empty(name)
    local clean_version = non_empty(version)
    if clean_name == nil or clean_version == nil then
        return nil
    end
    return join_path(spm_store_root(), clean_name, clean_version)
end

local function base_extra_fields(name, version, manifest_skills, lock_skills)
    local extra = {
        ["spm.storeRoot"] = spm_store_root(),
        ["spm.cacheRoot"] = spm_cache_root(),
        ["spm.projectManifest"] = project_manifest_path(),
        ["spm.projectLockfile"] = project_lockfile_path(),
    }
    local range = read_manifest_range(manifest_skills or {}, name)
    local store_path = make_store_path(name, version)
    if range ~= nil then
        extra["spm.range"] = range
    end
    if store_path ~= nil then
        extra["spm.storePath"] = store_path
    end
    local lock_entry = read_lock_entry(lock_skills or {}, name)
    if lock_entry ~= nil then
        local integrity = first_nonempty(read_field(lock_entry, "integrity"), read_field(lock_entry, "source"))
        if integrity ~= nil then
            extra["spm.lockSource"] = integrity
        end
    end
    return extra
end

local function author_name(author)
    if type(author) == "table" then
        return first_nonempty(read_field(author, "username"), read_field(author, "name"), read_field(author, "handle"))
    end
    return non_empty(author)
end

local function author_trust_tier(author)
    if type(author) == "table" then
        return first_nonempty(read_field(author, "trust_tier"), read_field(author, "trustTier"))
    end
    return nil
end

local function list_to_csv(values)
    if type(values) ~= "table" then
        return nil
    end
    local items = {}
    for _, value in ipairs(values) do
        local text = non_empty(value)
        if text ~= nil then
            items[#items + 1] = text
        end
    end
    if #items == 0 then
        return nil
    end
    return table.concat(items, ",")
end

local function item_from_registry_payload(name, data, installed_lookup, manifest_skills, lock_skills)
    if type(data) ~= "table" then
        return {}
    end

    local canonical_name = first_nonempty(name, read_field(data, "name"), read_nested_field(data, "skill", "name"))
    if canonical_name == nil then
        return {}
    end

    local installed_item = installed_lookup ~= nil and installed_lookup[canonical_name] or nil
    local installed_version = installed_item and non_empty(read_field(installed_item, "version")) or nil
    local latest_version = first_nonempty(
        read_field(data, "version"),
        read_field(data, "latest_version"),
        read_field(data, "latestVersion"),
        read_nested_field(data, "dist-tags", "latest"),
        read_nested_field(data, "versions", "latest")
    )
    local version = first_nonempty(installed_version, latest_version)

    local extra = base_extra_fields(canonical_name, version, manifest_skills, lock_skills)
    local author = read_field(data, "author")
    local tags = read_field(data, "tags")
    local trust_tier = author_trust_tier(author) or first_nonempty(read_field(data, "trust_tier"), read_field(data, "trustTier"))
    local downloads = first_nonempty(read_field(data, "downloads"), read_field(data, "download_count"))
    local weekly_downloads = first_nonempty(read_field(data, "weekly_downloads"), read_field(data, "weeklyDownloads"))

    if author_name(author) ~= nil then
        extra["spm.author"] = author_name(author)
    end
    if trust_tier ~= nil then
        extra["spm.trustTier"] = trust_tier
    end
    if list_to_csv(tags) ~= nil then
        extra["spm.tags"] = list_to_csv(tags)
    end
    if downloads ~= nil then
        extra["spm.downloads"] = tostring(downloads)
    end
    if weekly_downloads ~= nil then
        extra["spm.weeklyDownloads"] = tostring(weekly_downloads)
    end
    if read_field(data, "signed") ~= nil then
        extra["spm.signed"] = tostring(read_field(data, "signed"))
    end

    return {
        name = canonical_name,
        packageId = canonical_name,
        version = version,
        latestVersion = latest_version,
        description = first_nonempty(read_field(data, "description"), read_field(data, "summary")),
        license = first_nonempty(read_field(data, "license")),
        homepage = first_nonempty(read_field(data, "homepage"), read_field(data, "url")),
        repository = first_nonempty(read_field(data, "repository"), read_nested_field(data, "links", "repository")),
        installed = installed_item ~= nil,
        type = "package",
        packageType = "skill",
        extraFields = extra,
    }
end

local function load_list_result(context)
    local result = run_exec(context, REQUIRED_BINARY .. " list --json")
    local decoded, decode_error = decode_result_json(result)
    if decoded == nil then
        return nil, decode_error
    end
    local skills = read_field(decoded, "skills")
    if type(skills) ~= "table" then
        return {}, nil
    end
    return skills, nil
end

local function installed_lookup(context)
    local list_items = select(1, load_list_result(context)) or {}
    local manifest_skills = load_project_manifest()
    local lock_skills = load_project_lockfile()
    local lookup = {}

    for _, item in ipairs(list_items) do
        local name = non_empty(read_field(item, "name"))
        if name ~= nil then
            lookup[name] = {
                name = name,
                version = first_nonempty(read_field(item, "version"), read_field(item, "latestVersion")),
                latestVersion = first_nonempty(read_field(item, "latestVersion")),
                range = first_nonempty(read_field(item, "range"), read_manifest_range(manifest_skills, name)),
                extraFields = base_extra_fields(name, read_field(item, "version"), manifest_skills, lock_skills),
            }
        end
    end
    return lookup
end

local function parse_list_items(context)
    local list_items, list_error = load_list_result(context)
    if list_items == nil then
        log_warn(context, "spm list failed: " .. tostring(list_error))
        return {}
    end

    local manifest_skills = load_project_manifest()
    local lock_skills = load_project_lockfile()
    local items = {}

    for _, item in ipairs(list_items) do
        local name = non_empty(read_field(item, "name"))
        if name ~= nil then
            local version = first_nonempty(read_field(item, "version"), read_nested_field(read_lock_entry(lock_skills, name), "version"))
            items[#items + 1] = {
                name = name,
                packageId = name,
                version = version,
                latestVersion = version,
                installed = true,
                type = "package",
                packageType = "skill",
                extraFields = base_extra_fields(name, version, manifest_skills, lock_skills),
            }
        end
    end

    return items
end

local function not_found_payload(decoded)
    return type(decoded) == "table" and first_nonempty(read_field(decoded, "error"), read_field(decoded, "code")) == "not_found"
end

local function select_info_payload(decoded)
    if type(read_field(decoded, "skill")) == "table" then
        return read_field(decoded, "skill")
    end
    if type(read_field(decoded, "package")) == "table" then
        return read_field(decoded, "package")
    end
    if type(read_field(decoded, "data")) == "table" then
        return read_field(decoded, "data")
    end
    return decoded
end

local function numeric_version_tokens(version)
    local text = non_empty(version)
    if text == nil then
        return nil
    end
    if text:match("^[0-9][0-9.]*$") == nil then
        return nil
    end
    local tokens = {}
    for token in text:gmatch("[^.]+") do
        if token:match("^%d+$") == nil then
            return nil
        end
        tokens[#tokens + 1] = tonumber(token)
    end
    return tokens
end

local function compare_versions(left, right)
    local left_tokens = numeric_version_tokens(left)
    local right_tokens = numeric_version_tokens(right)
    if left_tokens == nil or right_tokens == nil then
        return nil
    end
    local size = math.max(#left_tokens, #right_tokens)
    for index = 1, size do
        local left_value = left_tokens[index] or 0
        local right_value = right_tokens[index] or 0
        if left_value < right_value then
            return -1
        elseif left_value > right_value then
            return 1
        end
    end
    return 0
end

local function search_command(prompt, flags)
    local parts = { REQUIRED_BINARY, "search", shell_arg(prompt) }
    if flags.limit ~= nil and tonumber(flags.limit) ~= nil then
        parts[#parts + 1] = "--limit"
        parts[#parts + 1] = tostring(math.floor(tonumber(flags.limit)))
    end
    if flags.sort ~= nil then
        parts[#parts + 1] = "--sort"
        parts[#parts + 1] = shell_arg(flags.sort)
    end
    if flags.category ~= nil then
        parts[#parts + 1] = "--category"
        parts[#parts + 1] = shell_arg(flags.category)
    end
    if flags["trust-tier"] ~= nil then
        parts[#parts + 1] = "--trust-tier"
        parts[#parts + 1] = shell_arg(flags["trust-tier"])
    end
    parts[#parts + 1] = "--json"
    return table.concat(parts, " ")
end

local function package_request_flags(context, packages)
    if type(packages) == "table" and type(packages[1]) == "table" then
        return package_flag_lookup(packages[1])
    end
    if context ~= nil and type(context.flags) == "table" then
        return shallow_copy(context.flags)
    end
    return {}
end

local function search_items_from_result(decoded, context)
    local results = read_field(decoded, "results")
    if type(results) ~= "table" then
        return {}
    end

    local manifest_skills = load_project_manifest()
    local lock_skills = load_project_lockfile()
    local installed = installed_lookup(context)
    local items = {}
    for _, item in ipairs(results) do
        items[#items + 1] = item_from_registry_payload(read_field(item, "name"), item, installed, manifest_skills, lock_skills)
    end
    return items
end

local function info_item_with_lookup(context, name, installed, manifest_skills, lock_skills)
    local package_name_value = trim(name)
    if package_name_value == "" then
        return {}
    end

    local result = run_exec(context, REQUIRED_BINARY .. " info --json " .. shell_arg(package_name_value))
    local decoded, decode_error = decode_result_json(result)
    if decoded == nil then
        log_warn(context, "spm info failed: " .. tostring(decode_error))
        return {}
    end
    if not_found_payload(decoded) then
        return {}
    end

    local payload = select_info_payload(decoded)
    return item_from_registry_payload(
        package_name_value,
        payload,
        installed or installed_lookup(context),
        manifest_skills or load_project_manifest(),
        lock_skills or load_project_lockfile()
    )
end

local function info_item(context, name)
    return info_item_with_lookup(context, name, nil, nil, nil)
end

local function mutation_items_from_json(decoded)
    local skills = read_field(decoded, "skills")
    if type(skills) ~= "table" then
        return {}
    end
    return skills
end

local function has_observable_local_install(decoded)
    for _, item in ipairs(mutation_items_from_json(decoded)) do
        if non_empty(read_field(item, "name")) ~= nil then
            return true
        end
    end
    return false
end

local function run_package_mutation(context, packages, step_label, event_name, build_command)
    if #packages == 0 then
        return true
    end

    local emitted = {}
    begin_step(context, step_label)
    for _, pkg in ipairs(packages) do
        local command = build_command(pkg)
        if command ~= nil then
            local result = run_exec(context, command)
            if result == nil or result.success ~= true then
                tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, step_label .. " failed"))
                return false
            end
            emitted[#emitted + 1] = pkg
        end
    end

    emit_event(context, event_name, emitted)
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
    return { "AI", "Skill Manager", "Package Manager", "Registry" }
end

function plugin.getMissingPackages(packages)
    if not command_exists(REQUIRED_BINARY) then
        local passthrough = {}
        for _, pkg in ipairs(packages or {}) do
            passthrough[#passthrough + 1] = pkg
        end
        return passthrough
    end

    local installed = installed_lookup(nil)
    local missing = {}
    local outdated_names = nil

    local function load_outdated_names()
        if outdated_names ~= nil then
            return outdated_names
        end
        outdated_names = {}
        for _, item in ipairs(plugin.outdated(nil)) do
            local name = non_empty(read_field(item, "name"))
            if name ~= nil then
                outdated_names[name] = true
            end
        end
        return outdated_names
    end

    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        local version = package_version(pkg)
        local action = lower(read_field(pkg, "action"))
        local installed_item = installed[name]

        if action == "remove" then
            if installed_item ~= nil then
                missing[#missing + 1] = pkg
            end
        elseif action == "update" then
            if load_outdated_names()[name] == true then
                missing[#missing + 1] = pkg
            end
        else
            if installed_item == nil then
                missing[#missing + 1] = pkg
            elseif version ~= "" and trim(read_field(installed_item, "version")) ~= version then
                missing[#missing + 1] = pkg
            end
        end
    end

    return missing
end

function plugin.install(context, packages)
    return run_package_mutation(context, packages or {}, "install spm skills", "installed", function(pkg)
        local specifier = install_specifier(pkg)
        if specifier == nil then
            return nil
        end
        local flags = package_flag_lookup(pkg)
        local parts = { REQUIRED_BINARY, "install", "--json" }
        if flags["no-link"] == true then
            parts[#parts + 1] = "--no-link"
        end
        parts[#parts + 1] = shell_arg(specifier)
        return table.concat(parts, " ")
    end)
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" then
        tx_failed(context, "spm local install failed")
        return false
    end

    begin_step(context, "install local spm skill")
    local result = run_exec(context, REQUIRED_BINARY .. " install --json --no-link " .. shell_arg(local_path))
    if result == nil or result.success ~= true then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "spm local install failed"))
        return false
    end

    local decoded = select(1, decode_result_json(result))
    if decoded ~= nil and has_observable_local_install(decoded) then
        emit_event(context, "installed", { path = local_path, localTarget = true })
        tx_success(context)
        return true
    end

    emit_event(context, "unavailable", { path = local_path, reason = "local-install-no-observable-state" })
    tx_failed(context, "spm local install produced no observable installed state")
    return false
end

function plugin.remove(context, packages)
    return run_package_mutation(context, packages or {}, "remove spm skills", "deleted", function(pkg)
        local name = package_name(pkg)
        if name == "" then
            return nil
        end
        local flags = package_flag_lookup(pkg)
        local parts = { REQUIRED_BINARY, "uninstall", "--json", shell_arg(name) }
        if flags["keep-files"] == true then
            table.insert(parts, 4, "--keep-files")
        end
        return table.concat(parts, " ")
    end)
end

function plugin.update(context, packages)
    local targets = packages or {}
    begin_step(context, "update spm skills")

    if #targets == 0 then
        local result = run_exec(context, REQUIRED_BINARY .. " update --json")
        if result == nil or result.success ~= true then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "spm update failed"))
            return false
        end
        emit_event(context, "updated", {})
        tx_success(context)
        return true
    end

    for _, pkg in ipairs(targets) do
        local name = package_name(pkg)
        if name ~= "" then
            local result = run_exec(context, REQUIRED_BINARY .. " update --json " .. shell_arg(name))
            if result == nil or result.success ~= true then
                tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "spm update failed"))
                return false
            end
        end
    end

    emit_event(context, "updated", targets)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = parse_list_items(context)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local listed = parse_list_items(context)
    local manifest_skills = load_project_manifest()
    local lock_skills = load_project_lockfile()
    local installed = installed_lookup(context)
    local items = {}
    for _, item in ipairs(listed) do
        local name = non_empty(read_field(item, "name"))
        local installed_version = non_empty(read_field(item, "version"))
        if name ~= nil and installed_version ~= nil then
            local info = info_item_with_lookup(context, name, installed, manifest_skills, lock_skills)
            local latest_version = non_empty(read_field(info, "latestVersion"))
            if latest_version ~= nil then
                local comparison = compare_versions(installed_version, latest_version)
                if comparison == -1 then
                    local copy = shallow_copy(item)
                    copy.latestVersion = latest_version
                    items[#items + 1] = copy
                elseif comparison == nil then
                    log_warn(context, "spm outdated skipped non-comparable version for " .. name)
                end
            end
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local search_prompt = trim(prompt)
    if search_prompt == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local flags = package_request_flags(context, nil)
    local result = run_exec(context, search_command(search_prompt, flags))
    local decoded, decode_error = decode_result_json(result)
    if decoded == nil then
        log_warn(context, "spm search failed: " .. tostring(decode_error))
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local items = search_items_from_result(decoded, context)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local item = info_item(context, name)
    emit_event(context, "informed", item)
    return item
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network", "link-agent-skills" },
        ecosystemScopes = { "skillpkg-registry" },
        writeScopes = {
            "user-home-subpath:.spm",
            "user-home-subpath:.agents",
            "project-relative:skills.json",
            "project-relative:skills-lock.json",
        },
        networkScopes = { "registry.skillpkg.dev", "skillpkg.dev" },
        privilegeLevel = "none",
        purlType = "generic",
        versionCaseInsensitive = false,
    }
end

function plugin.init()
    return command_exists(REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

return plugin
