plugin = {}

local PLUGIN_ID = "flix"
local PLUGIN_NAME = "Flix"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "flix"
local GITHUB_API_BASE = "https://api.github.com"
local JSON_NULL = {}

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return tostring(value or ""):lower()
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function command_quote(value)
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,?&]+$") then
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

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil and value ~= JSON_NULL then
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

local function collect_flags(context, packages)
    local flags = {}
    local seen = {}
    local function collect_from(object)
        for _, flag in ipairs(object_flags(object)) do
            local cleaned = trim(flag)
            if cleaned ~= "" and not seen[cleaned] then
                seen[cleaned] = true
                flags[#flags + 1] = cleaned
            end
        end
    end
    collect_from(context)
    collect_from(read_field(context, "request"))
    for _, pkg in ipairs(packages or {}) do
        collect_from(pkg)
    end
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

local function context_flag_value(context, key)
    return flag_value(object_flags(context), key)
end

local function normalize_exec_result(...)
    local result = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        local value_type = type(value)
        if value_type == "table" then
            for key, item in pairs(value) do
                if result[key] == nil then
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
        elseif value_type == "userdata" then
            for _, key in ipairs({ "success", "ok", "stdout", "stderr", "exitCode", "exit_code", "code", "status", "stdoutText", "stderrText" }) do
                local ok, item = pcall(function()
                    return value[key]
                end)
                if ok and item ~= nil and result[key] == nil then
                    result[key] = item
                end
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

local function log_error(context, message)
    if context == nil or context.log == nil then
        return
    end
    local fn = context.log.error
    if type(fn) == "function" then
        fn(message)
    end
end

local function get_plugin_dir()
    return trim(_G.REQPACK_PLUGIN_DIR or ".")
end

local function env_value(name)
    if os ~= nil and type(os.getenv) == "function" then
        return trim(os.getenv(name) or "")
    end
    return ""
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
    if os ~= nil and type(os.rename) == "function" then
        local renamed = os.rename(dir, dir)
        if renamed == true then
            return true
        end
    end
    if os == nil or type(os.execute) ~= "function" then
        return true
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

local function read_text_file(context, path)
    local result = exec_run(context, "cat " .. shell_quote(path))
    if result ~= nil and result.success == true then
        return result.stdout
    end
    return read_file(path)
end

local function write_text_file(context, path, content)
    local dir = parent_dir(path) or "."
    local command = "mkdir -p " .. shell_quote(dir) .. " && printf %s " .. shell_quote(content or "") .. " > " .. shell_quote(path)
    local result = exec_run(context, command)
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
        local start_index = index
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
                decode_error("expected object key string")
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
        elseif current == "-" or (current ~= "" and current:match("%d") ~= nil) then
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

    local value = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("trailing characters")
    end
    return value
end

local function json_value(value)
    if value == JSON_NULL then
        return nil
    end
    return value
end

local function parse_json(raw)
    local ok, result = pcall(decode_json_internal, raw)
    if ok then
        return result
    end
    return nil, result
end

local function synthetic_project_dir(context, packages)
    local override = context_flag_value(context, "project-root") or flag_value(collect_flags(context, packages), "project-root")
    if override ~= nil and override ~= "" then
        return join_path(override, ".reqpack-data", "flix-cache")
    end
    local fixture_root = env_value("REQPACK_TEST_FIXTURE_ROOT")
    if fixture_root ~= "" then
        return join_path(fixture_root, ".reqpack-data", "flix-cache")
    end
    return join_path(get_plugin_dir(), ".reqpack-data", "flix-cache")
end

local function synthetic_manifest_path(context, packages)
    return join_path(synthetic_project_dir(context, packages), "flix.toml")
end

local function synthetic_source_dir(context, packages)
    return join_path(synthetic_project_dir(context, packages), "src")
end

local function synthetic_source_path(context, packages)
    return join_path(synthetic_source_dir(context, packages), "Main.flix")
end

local function github_cache_dir(context, packages)
    return join_path(synthetic_project_dir(context, packages), "github")
end

local function github_repo_cache_path(context, repo_id, packages)
    local safe = trim(repo_id):gsub("/", "__")
    return join_path(github_cache_dir(context, packages), safe .. ".json")
end

local function github_search_cache_path(context, query, packages)
    local safe = trim(query):gsub("[^%w%-_%.]", "_")
    return join_path(github_cache_dir(context, packages), "search-" .. safe .. ".json")
end

local function sort_keys(map)
    local keys = {}
    for key in pairs(map or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function normalize_version(value)
    local version = trim(value)
    if version:sub(1, 1) == "v" or version:sub(1, 1) == "V" then
        version = trim(version:sub(2))
    end
    return version
end

local function repo_id_from_package(pkg)
    local extra = read_field(pkg, "extraFields")
    local raw = trim(first_nonempty(
        read_field(pkg, "packageId"),
        read_field(pkg, "name"),
        read_field(extra, "owner") and (trim(read_field(extra, "owner")) .. "/" .. trim(read_field(extra, "repo"))) or nil,
        read_field(extra, "flix.repoId")
    ))
    if raw:match("^[^/]+/[^/]+$") then
        return raw
    end
    return ""
end

local function package_repo_name(pkg)
    local repo_id = repo_id_from_package(pkg)
    if repo_id ~= "" then
        return repo_id:match("/([^/]+)$") or repo_id
    end
    return trim(first_nonempty(read_field(pkg, "name"), read_field(pkg, "packageId")))
end

local function package_version(pkg)
    return normalize_version(first_nonempty(read_field(pkg, "version"), read_field(pkg, "latestVersion")) or "")
end

local function package_security(pkg)
    local extra = read_field(pkg, "extraFields")
    return trim(first_nonempty(read_field(pkg, "security"), read_field(extra, "flix.security")))
end

local function manifest_header_lines()
    return {
        "[package]",
        'name        = "reqpack-flix-cache"',
        'description = "ReqPack managed Flix dependency cache"',
        'version     = "0.0.0"',
        'flix        = "0.0.0"',
        'license     = "MIT"',
        'authors     = ["ReqPack <reqpack@example.invalid>"]',
        "",
        "[dependencies]",
    }
end

local function parse_manifest_dependencies(content)
    local dependencies = {}
    local in_dependencies = false
    for _, line in ipairs(split_lines(content or "")) do
        local stripped = trim(line)
        if stripped == "[dependencies]" then
            in_dependencies = true
        elseif stripped:match("^%[") then
            in_dependencies = false
        elseif in_dependencies then
            local dep_id, dep_version = stripped:match('^"(github:[^"]+)"%s*=%s*"([^"]+)"%s*$')
            if dep_id ~= nil then
                dependencies[dep_id] = { dependencyId = dep_id, version = normalize_version(dep_version) }
            else
                local record_dep, record_version, record_security = stripped:match('^"(github:[^"]+)"%s*=%s*{%s*version%s*=%s*"([^"]+)"%s*,%s*security%s*=%s*"([^"]+)"%s*}%s*$')
                if record_dep ~= nil then
                    dependencies[record_dep] = {
                        dependencyId = record_dep,
                        version = normalize_version(record_version),
                        security = trim(record_security),
                    }
                end
            end
        end
    end
    return dependencies
end

local function load_manifest_dependencies(context, packages)
    return parse_manifest_dependencies(read_text_file(context, synthetic_manifest_path(context, packages)) or "")
end

local function save_manifest_dependencies(context, packages, dependencies)
    local lines = manifest_header_lines()
    for _, dep_id in ipairs(sort_keys(dependencies)) do
        local entry = dependencies[dep_id]
        if entry ~= nil then
            local version = normalize_version(entry.version)
            local security = trim(entry.security)
            if security == "" then
                lines[#lines + 1] = '"' .. dep_id .. '" = "' .. version .. '"'
            else
                lines[#lines + 1] = '"' .. dep_id .. '" = { version = "' .. version .. '", security = "' .. security .. '" }'
            end
        end
    end
    lines[#lines + 1] = ""
    return write_text_file(context, synthetic_manifest_path(context, packages), table.concat(lines, "\n"))
end

local function ensure_synthetic_source(context, packages)
    local content = read_text_file(context, synthetic_source_path(context, packages))
    if content ~= nil and trim(content) ~= "" then
        return true
    end
    return write_text_file(context, synthetic_source_path(context, packages), "def main(): Unit \\ IO =\n    ()\n")
end

local function github_api_headers(context)
    local token = trim(first_nonempty(
        env_value("GITHUB_TOKEN"),
        context_flag_value(context, "github-token"),
        flag_value(object_flags(read_field(context, "request")), "github-token")
    ))
    if token ~= "" then
        return " -H " .. shell_quote("Authorization: Bearer " .. token)
    end
    return ""
end

local function github_get_command(context, url, output_path)
    return "curl -fsSL -H " .. shell_quote("Accept: application/vnd.github+json") .. github_api_headers(context) .. " " .. command_quote(url) .. " -o " .. command_quote(output_path)
end

local function github_search_url(query)
    return GITHUB_API_BASE .. "/search/repositories?q=" .. tostring(query or "")
end

local function github_repo_url(repo_id)
    return GITHUB_API_BASE .. "/repos/" .. repo_id
end

local function github_releases_url(repo_id)
    return GITHUB_API_BASE .. "/repos/" .. repo_id .. "/releases"
end

local function load_json_cache(context, path)
    local cached = read_text_file(context, path)
    if cached ~= nil and trim(cached) ~= "" then
        local decoded = parse_json(cached)
        if decoded ~= nil then
            return decoded
        end
    end
    return nil
end

local function ensure_github_json(context, url, cache_path)
    local decoded = load_json_cache(context, cache_path)
    if decoded ~= nil then
        return decoded
    end
    local result = exec_run(context, github_get_command(context, url, cache_path))
    if result == nil or result.success ~= true then
        log_warn(context, "GitHub request failed: " .. url)
        return nil
    end
    if trim(result.stdout or "") ~= "" then
        local parsed = parse_json(result.stdout)
        if parsed ~= nil then
            return parsed
        end
    end
    decoded = load_json_cache(context, cache_path)
    if decoded == nil then
        log_error(context, "GitHub JSON parse failed: " .. url)
    end
    return decoded
end

local function github_search(context, query)
    return ensure_github_json(context, github_search_url(query), github_search_cache_path(context, query))
end

local function github_repo(context, repo_id)
    return ensure_github_json(context, github_repo_url(repo_id), github_repo_cache_path(context, repo_id))
end

local function github_releases(context, repo_id)
    return ensure_github_json(context, github_releases_url(repo_id), github_repo_cache_path(context, repo_id .. "__releases"))
end

local function latest_release_version_from_payload(releases)
    if type(releases) ~= "table" then
        return ""
    end
    local first = releases[1]
    if type(first) ~= "table" then
        return ""
    end
    return normalize_version(first_nonempty(read_field(first, "tag_name"), read_field(first, "name")) or "")
end

local function repo_item_from_payload(repo, latest_version)
    if type(repo) ~= "table" then
        return nil
    end
    local full_name = trim(read_field(repo, "full_name"))
    if full_name == "" then
        return nil
    end
    local owner = trim(full_name:match("^([^/]+)/") or "")
    local name = trim(read_field(repo, "name"))
    local description = trim(read_field(repo, "description"))
    return {
        packageId = full_name,
        name = name ~= "" and name or full_name,
        version = latest_version,
        latestVersion = latest_version,
        installed = false,
        status = "available",
        summary = description,
        description = description,
        repository = trim(read_field(repo, "html_url")),
        homepage = trim(read_field(repo, "homepage")),
        stars = read_field(repo, "stargazers_count"),
        packageType = "library",
        extraFields = {
            owner = owner,
            repo = name,
            ["flix.dependencyId"] = "github:" .. full_name,
        },
    }
end

local function fetch_repo_item(context, repo_id)
    if trim(repo_id) == "" then
        return nil
    end
    local repo = github_repo(context, repo_id)
    if repo == nil then
        return nil
    end
    local latest_version = latest_release_version_from_payload(github_releases(context, repo_id))
    return repo_item_from_payload(repo, latest_version)
end

local function resolve_repo_id(context, pkg)
    local repo_id = repo_id_from_package(pkg)
    if repo_id ~= "" then
        return repo_id, nil
    end
    local prompt = package_repo_name(pkg)
    if prompt == "" then
        return nil, "package repository missing"
    end
    local payload = github_search(context, prompt .. "+topic:flix") or github_search(context, prompt)
    local items = type(payload) == "table" and json_value(read_field(payload, "items")) or nil
    if type(items) ~= "table" or #items == 0 then
        return nil, "package not found"
    end
    local exact = {}
    for _, item in ipairs(items) do
        local full_name = trim(read_field(item, "full_name"))
        local name = trim(read_field(item, "name"))
        if full_name ~= "" and (lower(name) == lower(prompt) or lower(full_name) == lower(prompt)) then
            exact[#exact + 1] = full_name
        end
    end
    if #exact == 1 then
        return exact[1], nil
    end
    return nil, "package repository ambiguous"
end

local function resolve_package_metadata(context, pkg)
    local repo_id, err = resolve_repo_id(context, pkg)
    if repo_id == nil then
        return nil, err
    end
    local item = fetch_repo_item(context, repo_id)
    if item == nil then
        return nil, "package metadata unavailable"
    end
    local requested_version = package_version(pkg)
    if requested_version ~= "" then
        item.version = requested_version
    else
        item.version = item.latestVersion
    end
    local security = package_security(pkg)
    if security ~= "" then
        item.extraFields["flix.security"] = security
    end
    return item, nil
end

local function dependency_id_for_repo(repo_id)
    if trim(repo_id) == "" then
        return ""
    end
    return "github:" .. repo_id
end

local function tracked_item_from_manifest(context, dep_id, entry)
    local repo_id = trim(dep_id:gsub("^github:", ""))
    local item = {
        packageId = repo_id,
        name = repo_id:match("/([^/]+)$") or repo_id,
        version = normalize_version(entry.version),
        latestVersion = normalize_version(entry.version),
        installed = true,
        status = "tracked",
        packageType = "library",
        repository = repo_id ~= "" and ("https://github.com/" .. repo_id) or "",
        extraFields = {
            ["flix.dependencyId"] = dep_id,
            ["flix.security"] = trim(entry.security),
        },
    }
    if repo_id ~= "" then
        local meta = fetch_repo_item(context, repo_id)
        if meta ~= nil then
            item.summary = meta.summary
            item.description = meta.description
            item.repository = meta.repository
            item.latestVersion = meta.latestVersion ~= "" and meta.latestVersion or item.latestVersion
            item.extraFields.owner = read_field(meta.extraFields, "owner")
            item.extraFields.repo = read_field(meta.extraFields, "repo")
        end
    end
    return item
end

local function list_from_manifest(context)
    local items = {}
    local dependencies = load_manifest_dependencies(context)
    for _, dep_id in ipairs(sort_keys(dependencies)) do
        items[#items + 1] = tracked_item_from_manifest(context, dep_id, dependencies[dep_id])
    end
    return items
end

local function run_in_directory_command(path, inner_command)
    return "cd " .. shell_quote(path) .. " && " .. inner_command
end

local function flix_check_command()
    return REQUIRED_BINARY .. " check --yes"
end

local function flix_build_pkg_command()
    return REQUIRED_BINARY .. " build-pkg"
end

local function ensure_synthetic_project(context, packages)
    local project_dir = synthetic_project_dir(context, packages)
    if not ensure_directory(project_dir) then
        return false
    end
    if not ensure_synthetic_source(context, packages) then
        return false
    end
    return true
end

local function refresh_dependencies(context, packages)
    if not ensure_synthetic_project(context, packages) then
        tx_failed(context, "flix synthetic project create failed")
        return false
    end
    local result = exec_run(context, run_in_directory_command(synthetic_project_dir(context, packages), flix_check_command()))
    if result == nil or result.success ~= true then
        tx_failed(context, "flix dependency resolution failed")
        return false
    end
    return true
end

local function merge_packages_into_manifest(context, packages, remove_mode, update_all)
    local dependencies = load_manifest_dependencies(context, packages)
    if update_all == true then
        for dep_id, entry in pairs(dependencies) do
            local repo_id = trim(dep_id:gsub("^github:", ""))
            local meta = fetch_repo_item(context, repo_id)
            if meta ~= nil and trim(meta.latestVersion) ~= "" then
                entry.version = trim(meta.latestVersion)
            end
        end
    end
    for _, pkg in ipairs(packages or {}) do
        local meta = pkg
        if remove_mode ~= true then
            local err = nil
            meta, err = resolve_package_metadata(context, pkg)
            if meta == nil then
                tx_failed(context, "flix package resolution failed")
                log_error(context, tostring(err or "resolution failed"))
                return nil
            end
        end
        local repo_id = remove_mode and (select(1, resolve_repo_id(context, pkg)) or repo_id_from_package(pkg)) or trim(read_field(meta, "packageId"))
        local dep_id = dependency_id_for_repo(repo_id)
        if dep_id ~= "github:" and dep_id ~= "" then
            if remove_mode then
                dependencies[dep_id] = nil
            else
                dependencies[dep_id] = {
                    dependencyId = dep_id,
                    version = normalize_version(read_field(meta, "version")),
                    security = trim(read_field(read_field(meta, "extraFields"), "flix.security")),
                }
            end
        end
    end
    if not save_manifest_dependencies(context, packages, dependencies) then
        tx_failed(context, "flix manifest write failed")
        return nil
    end
    return dependencies
end

plugin.fileExtensions = { ".fpkg" }

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
    return { "Cross Platform", "Flix", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    local missing = {}
    local dependencies = load_manifest_dependencies(nil, packages)
    for _, pkg in ipairs(packages or {}) do
        local action = lower(trim(read_field(pkg, "action")))
        local repo_id = repo_id_from_package(pkg)
        local dep_id = dependency_id_for_repo(repo_id)
        local current = dependencies[dep_id]
        local requested_version = package_version(pkg)
        local requested_security = package_security(pkg)
        if action == "remove" then
            if current ~= nil then
                missing[#missing + 1] = pkg
            end
        elseif action == "update" then
            missing[#missing + 1] = pkg
        elseif current == nil then
            missing[#missing + 1] = pkg
        elseif requested_version ~= "" and normalize_version(current.version) ~= requested_version then
            missing[#missing + 1] = pkg
        elseif requested_security ~= "" and trim(current.security) ~= requested_security then
            missing[#missing + 1] = pkg
        end
    end
    return missing
end

function plugin.install(context, packages)
    local request = read_field(context, "request") or {}
    local local_path = trim(first_nonempty(read_field(context, "localPath"), read_field(request, "localPath"), read_field(request, "path")))
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end
    if packages == nil or #packages == 0 then
        return true
    end
    begin_step(context, "cache flix dependencies")
    if merge_packages_into_manifest(context, packages, false, false) == nil then
        return false
    end
    if not refresh_dependencies(context, packages) then
        return false
    end
    emit_event(context, "installed", packages)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local request = read_field(context, "request") or {}
    local local_path = trim(first_nonempty(path, read_field(context, "localPath"), read_field(request, "localPath"), read_field(request, "path")))
    if local_path == "" then
        tx_failed(context, "flix local install failed")
        return false
    end
    begin_step(context, "build local flix package")
    local result = exec_run(context, run_in_directory_command(local_path, flix_build_pkg_command()))
    if result == nil or result.success ~= true then
        tx_failed(context, "flix local install failed")
        return false
    end
    emit_event(context, "installed", { path = local_path, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    if packages == nil or #packages == 0 then
        return true
    end
    begin_step(context, "remove tracked flix dependencies")
    if merge_packages_into_manifest(context, packages, true, false) == nil then
        return false
    end
    emit_event(context, "deleted", packages)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    begin_step(context, "refresh flix dependency cache")
    if packages ~= nil and #packages > 0 then
        if merge_packages_into_manifest(context, packages, false, false) == nil then
            return false
        end
    else
        if merge_packages_into_manifest(context, {}, false, true) == nil then
            return false
        end
    end
    if not refresh_dependencies(context, packages) then
        return false
    end
    emit_event(context, "updated", packages or {})
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = list_from_manifest(context)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items = {}
    for _, item in ipairs(list_from_manifest(context)) do
        local current = normalize_version(item.version)
        local latest = normalize_version(item.latestVersion)
        if current ~= "" and latest ~= "" and current ~= latest then
            item.status = "outdated"
            item.installed = true
            items[#items + 1] = item
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local request = read_field(context, "request") or {}
    local search_prompt = trim(first_nonempty(prompt, read_field(context, "prompt"), read_field(request, "prompt")))
    if search_prompt == "" then
        emit_event(context, "searched", {})
        return {}
    end
    local payload = github_search(context, search_prompt .. "+topic:flix") or github_search(context, search_prompt)
    local items = {}
    local repos = type(payload) == "table" and json_value(read_field(payload, "items")) or nil
    if type(repos) == "table" then
        for _, repo in ipairs(repos) do
            local item = repo_item_from_payload(repo, latest_release_version_from_payload(github_releases(context, trim(read_field(repo, "full_name")))))
            if item ~= nil then
                items[#items + 1] = item
            end
        end
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local request = read_field(context, "request") or {}
    local query = trim(first_nonempty(name, read_field(context, "prompt"), read_field(request, "name"), read_field(request, "prompt")))
    local item = {}
    if query ~= "" then
        local meta, err = resolve_package_metadata(context, { packageId = query, name = query })
        if meta ~= nil then
            item = meta
        elseif err ~= nil then
            log_warn(context, "flix info lookup failed: " .. err)
        end
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local resolved, _ = resolve_package_metadata(context, package)
    return resolved
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "flix", "github", "jvm" },
        writeScopes = {},
        networkScopes = {
            GITHUB_API_BASE .. "/search/repositories",
            GITHUB_API_BASE .. "/repos",
        },
        privilegeLevel = "user",
    }
end

function plugin.init()
    local result = exec_run(nil, "command -v " .. REQUIRED_BINARY .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

function plugin.shutdown()
end

return plugin
