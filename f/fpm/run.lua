plugin = {}

local PLUGIN_NAME = "Fortran Package Manager"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "fpm"
local REGISTRY_INDEX_URL = "https://github.com/fortran-lang/fpm-registry/raw/master/index.json"
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
    if text:match("^[%w%+%-%._/%:@=,]+$") then
        return text
    end
    return shell_quote(text)
end

local function toml_quote(value)
    return '"' .. tostring(value or ""):gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function split_lines(value)
    local lines = {}
    local text = tostring(value or ""):gsub("\r\n", "\n")
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
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

local function context_flag_value(context, key)
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(object_flags(context)) do
        local lowered = lower(trim(flag))
        if lowered:sub(1, #prefix) == prefix then
            return trim(flag:sub(#prefix + 1))
        end
    end
    return nil
end

local function collect_raw_flags(context, packages)
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
        local lowered = lower(trim(flag))
        if lowered:sub(1, #prefix) == prefix then
            return trim(flag:sub(#prefix + 1))
        end
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

local function run_exec(context, command, options)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        if options ~= nil then
            return context.exec.run(command, options)
        end
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
                table.insert(parts, (part:gsub("[/\\]+$", "")))
            else
                table.insert(parts, (part:gsub("^[/\\]+", ""):gsub("[/\\]+$", "")))
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
    local result = run_exec(context, "cat " .. shell_quote(path))
    if result ~= nil and result.success == true then
        return result.stdout
    end
    return read_file(path)
end

local function write_file(path, content)
    local dir = parent_dir(path)
    local tmp_path = path .. ".tmp"
    local handle = io.open(tmp_path, "w")
    if handle == nil then
        if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
            return false
        end
        handle = io.open(tmp_path, "w")
        if handle == nil then
            return false
        end
    end
    handle:write(content or "")
    handle:close()
    if os ~= nil and type(os.remove) == "function" then
        os.remove(path)
    end
    if os ~= nil and type(os.rename) == "function" then
        return os.rename(tmp_path, path)
    end
    local direct = io.open(path, "w")
    if direct == nil then
        return false
    end
    local tmp_content = read_file(tmp_path) or content or ""
    direct:write(tmp_content)
    direct:close()
    return true
end

local function write_text_file(context, path, content)
    local dir = parent_dir(path) or "."
    local command = "mkdir -p " .. shell_quote(dir) .. " && printf %s " .. shell_quote(content or "") .. " > " .. shell_quote(path)
    local result = run_exec(context, command)
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

local function package_name(pkg)
    return trim(first_nonempty(read_field(pkg, "name"), read_field(pkg, "packageId")))
end

local function package_version(pkg)
    local value = trim(first_nonempty(read_field(pkg, "version"), read_field(pkg, "latestVersion")))
    if value == "" then
        return "*"
    end
    return value
end

local function package_namespace(pkg)
    local extra = read_field(pkg, "extraFields")
    return trim(first_nonempty(read_field(pkg, "namespace"), read_field(extra, "namespace"), read_field(extra, "fpm.namespace")))
end

local function package_type(pkg)
    local kind = trim(read_field(pkg, "packageType"))
    if kind == "" then
        return "library"
    end
    return kind
end

local function synthetic_project_dir(context, packages)
    local override = context_flag_value(context, "project-root") or flag_value(collect_raw_flags(context, packages), "project-root")
    if override ~= nil and override ~= "" then
        return join_path(override, ".reqpack-data", "fpm-cache")
    end
    local fixture_root = env_value("REQPACK_TEST_FIXTURE_ROOT")
    if fixture_root ~= "" then
        return join_path(fixture_root, ".reqpack-data", "fpm-cache")
    end
    local plugin_dir_root = join_path(get_plugin_dir(), ".reqpack-data", "fpm-cache")
    local cwd_root = join_path(".", ".reqpack-data", "fpm-cache")
    if read_file(join_path(cwd_root, "fpm.toml")) ~= nil and read_file(join_path(plugin_dir_root, "fpm.toml")) == nil then
        return cwd_root
    end
    if read_file(join_path(cwd_root, "registry-index.json")) ~= nil and read_file(join_path(plugin_dir_root, "registry-index.json")) == nil then
        return cwd_root
    end
    return plugin_dir_root
end

local function synthetic_manifest_path(context, packages)
    return join_path(synthetic_project_dir(context, packages), "fpm.toml")
end

local function sort_keys(map)
    local keys = {}
    for key in pairs(map or {}) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

local function manifest_header_lines()
    return {
        'name = "reqpack-fpm-cache"',
        'version = "0.0.0"',
        'license = "MIT"',
        "",
        "[dependencies]",
    }
end

local function normalize_manifest_version(value)
    local version = trim(value)
    if version == "" then
        return "*"
    end
    return version
end

local function parse_manifest_dependencies(content)
    local dependencies = {}
    local in_dependencies = false
    local current_name = nil
    for _, line in ipairs(split_lines(content or "")) do
        local stripped = trim(line)
        if stripped == "[dependencies]" then
            in_dependencies = true
            current_name = nil
        elseif stripped:match("^%[") then
            in_dependencies = false
            current_name = nil
        elseif in_dependencies then
            local section_name = stripped:match("^([%w%-%._]+)%s*=%s*{%s*$")
            if section_name ~= nil then
                current_name = section_name
                dependencies[current_name] = dependencies[current_name] or { name = current_name, version = "*" }
            else
                local dot_name, dot_field, dot_value = stripped:match("^([%w%-%._]+)%.([%w%-_]+)%s*=%s*" .. '"(.-)"' .. "$")
                if dot_name ~= nil then
                    local entry = dependencies[dot_name] or { name = dot_name, version = "*" }
                    if dot_field == "namespace" then
                        entry.namespace = dot_value
                    elseif dot_field == "v" then
                        entry.version = normalize_manifest_version(dot_value)
                    end
                    dependencies[dot_name] = entry
                    current_name = nil
                else
                    local field_name, field_value = stripped:match("^([%w%-_]+)%s*=%s*" .. '"(.-)"' .. "$")
                    if current_name ~= nil and field_name ~= nil then
                        local entry = dependencies[current_name] or { name = current_name, version = "*" }
                        if field_name == "namespace" then
                            entry.namespace = field_value
                        elseif field_name == "v" then
                            entry.version = normalize_manifest_version(field_value)
                        end
                        dependencies[current_name] = entry
                    end
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
    for _, name in ipairs(sort_keys(dependencies)) do
        local entry = dependencies[name]
        if entry ~= nil then
            lines[#lines + 1] = name .. ".namespace = " .. toml_quote(trim(entry.namespace or ""))
            lines[#lines + 1] = name .. ".v = " .. toml_quote(normalize_manifest_version(entry.version or "*"))
        end
    end
    lines[#lines + 1] = ""
    return write_text_file(context, synthetic_manifest_path(context, packages), table.concat(lines, "\n"))
end

local function registry_cache_file_path(context, packages)
    return join_path(synthetic_project_dir(context, packages), "registry-index.json")
end

local function registry_download_command(url, output_path)
    return "curl -fsSL " .. command_quote(url) .. " -o " .. command_quote(output_path)
end

local function ensure_registry_index(context, packages)
    local cache_path = registry_cache_file_path(context, packages)
    local cached = read_text_file(context, cache_path)
    if cached ~= nil and trim(cached) ~= "" then
        local decoded = parse_json(cached)
        if decoded ~= nil then
            return decoded
        end
    end

    local result = run_exec(context, registry_download_command(REGISTRY_INDEX_URL, cache_path))
    if result ~= nil and result.success == true and trim(result.stdout or "") ~= "" then
        local decoded, err = parse_json(result.stdout)
        if decoded ~= nil then
            return decoded
        end
        log_error(context, "fpm registry index parse failed: " .. tostring(err or "unknown error"))
        return nil
    end

    if result == nil or result.success ~= true then
        log_warn(context, "fpm registry index download failed")
        return nil
    end

    local decoded, err = parse_json(read_text_file(context, cache_path) or "")
    if decoded == nil then
        log_error(context, "fpm registry index parse failed: " .. tostring(err or "unknown error"))
        return nil
    end
    return decoded
end

local function registry_packages(index)
    local packages = json_value(read_field(index, "packages"))
    if type(packages) == "table" then
        return packages
    end
    return {}
end

local function clone_entry(entry)
    local copy = shallow_copy(entry)
    if type(copy.extraFields) == "table" then
        copy.extraFields = shallow_copy(copy.extraFields)
    end
    return copy
end

local function package_record_to_item(package_key, version_key, record)
    if type(record) ~= "table" then
        return nil
    end
    local latest_version = trim(read_field(record, "version"))
    local namespace = trim(first_nonempty(read_field(record, "namespace"), package_key))
    local description = first_nonempty(read_field(record, "description"), read_field(record, "summary"))
    local dependencies = {}
    local dependency_table = json_value(read_field(record, "dependencies"))
    if type(dependency_table) == "table" then
        for dep_name in pairs(dependency_table) do
            table.insert(dependencies, dep_name)
        end
        table.sort(dependencies)
    end
    return {
        name = trim(first_nonempty(read_field(record, "name"), package_key)),
        packageId = package_key,
        version = version_key == "latest" and latest_version or trim(version_key),
        latestVersion = latest_version,
        installed = false,
        status = "available",
        summary = description,
        description = description,
        license = trim(read_field(record, "license")),
        repository = trim(read_field(record, "git")),
        packageType = "library",
        dependencies = dependencies,
        extraFields = {
            namespace = namespace,
            ["fpm.namespace"] = namespace,
            ["fpm.gitTag"] = trim(read_field(record, "git-tag")),
        },
    }
end

local function registry_candidates_for_name(index, name)
    local matches = {}
    local target = trim(name)
    if target == "" then
        return matches
    end
    for package_key, versions in pairs(registry_packages(index)) do
        local latest = type(versions) == "table" and read_field(versions, "latest") or nil
        local item = package_record_to_item(package_key, "latest", latest)
        if item ~= nil then
            local item_name = trim(item.name)
            if item_name == target or trim(package_key) == target then
                table.insert(matches, item)
            end
        end
    end
    table.sort(matches, function(left, right)
        return trim(left.name) < trim(right.name)
    end)
    return matches
end

local function resolve_registry_package_from_index(index, pkg)
    if index == nil then
        return nil, "registry unavailable"
    end

    local name = package_name(pkg)
    local namespace = package_namespace(pkg)
    local requested_version = package_version(pkg)
    if name == "" then
        return nil, "package name missing"
    end

    local matches = registry_candidates_for_name(index, name)
    if #matches == 0 then
        return nil, "package not found"
    end

    local selected = nil
    if namespace ~= "" then
        for _, item in ipairs(matches) do
            local item_namespace = trim(read_field(item.extraFields, "namespace"))
            if item_namespace == namespace then
                selected = item
                break
            end
        end
        if selected == nil then
            return nil, "package namespace not found"
        end
    else
        if #matches > 1 then
            return nil, "package namespace ambiguous"
        end
        selected = matches[1]
    end

    if requested_version == "*" then
        return clone_entry(selected)
    end

    local versions = read_field(registry_packages(index), trim(selected.packageId))
    local exact_record = type(versions) == "table" and read_field(versions, requested_version) or nil
    if type(exact_record) == "table" then
        local exact = package_record_to_item(trim(selected.packageId), requested_version, exact_record)
        if exact ~= nil then
            exact.latestVersion = selected.latestVersion
            return exact
        end
    end

    if type(versions) ~= "table" or next(versions) == nil or (read_field(versions, "latest") ~= nil and next(versions, "latest") == nil) then
        local exact = clone_entry(selected)
        exact.version = requested_version
        return exact
    end

    if trim(selected.latestVersion) == requested_version then
        local exact = clone_entry(selected)
        exact.version = requested_version
        return exact
    end

    return nil, "package version not found"
end

local function resolve_registry_package(context, pkg)
    local index = ensure_registry_index(context)
    return resolve_registry_package_from_index(index, pkg)
end

local function list_from_manifest(context)
    local index = ensure_registry_index(context)
    local items = {}
    local dependencies = load_manifest_dependencies(context)
    for _, name in ipairs(sort_keys(dependencies)) do
        local entry = dependencies[name]
        local item = {
            name = name,
            packageId = name,
            version = normalize_manifest_version(entry.version),
            latestVersion = normalize_manifest_version(entry.version),
            installed = true,
            status = "tracked",
            packageType = "library",
            extraFields = {
                namespace = trim(entry.namespace),
                ["fpm.namespace"] = trim(entry.namespace),
            },
        }
        if index ~= nil then
            local resolved, _ = resolve_registry_package_from_index(index, entry)
            if resolved ~= nil then
                item.summary = resolved.summary
                item.description = resolved.description
                item.license = resolved.license
                item.repository = resolved.repository
                item.latestVersion = resolved.latestVersion ~= "" and resolved.latestVersion or item.latestVersion
            end
        end
        table.insert(items, item)
    end
    return items
end

local function fpm_update_command()
    return REQUIRED_BINARY .. " update --fetch-only"
end

local function fpm_install_local_command()
    return REQUIRED_BINARY .. " install --profile release"
end

local function run_in_directory_command(path, inner_command)
    return "cd " .. shell_quote(path) .. " && " .. inner_command
end

local function fetch_manifest_dependencies(context)
    local project_dir = synthetic_project_dir(context)
    if not ensure_directory(project_dir) then
        tx_failed(context, "fpm manifest directory create failed")
        return false
    end
    local result = run_exec(context, run_in_directory_command(project_dir, fpm_update_command()))
    if result == nil or result.success ~= true then
        tx_failed(context, "fpm dependency fetch failed")
        return false
    end
    return true
end

local function merge_packages_into_manifest(context, packages, remove_mode)
    local dependencies = load_manifest_dependencies(context, packages)
    for _, pkg in ipairs(packages or {}) do
        local resolved = pkg
        if not remove_mode then
            local err = nil
            resolved, err = resolve_registry_package(context, pkg)
            if resolved == nil then
                tx_failed(context, "fpm package resolution failed")
                log_error(context, tostring(err or "resolution failed") .. ": " .. package_name(pkg))
                return nil
            end
        end
        local name = package_name(pkg)
        if name ~= "" then
            if remove_mode then
                dependencies[name] = nil
            else
                dependencies[name] = {
                    name = name,
                    namespace = package_namespace(resolved),
                    version = package_version(pkg),
                }
            end
        end
    end
    if not save_manifest_dependencies(context, packages, dependencies) then
        tx_failed(context, "fpm manifest write failed")
        return nil
    end
    return dependencies
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
    return { "Cross Platform", "Fortran", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    local missing = {}
    local dependencies = load_manifest_dependencies(nil, packages)
    for _, pkg in ipairs(packages or {}) do
        if package_type(pkg) == "library" or package_type(pkg) == "" then
            local name = package_name(pkg)
            local action = trim(read_field(pkg, "action"))
            local current = dependencies[name]
            local current_version = current ~= nil and normalize_manifest_version(current.version) or nil
            local current_namespace = current ~= nil and trim(current.namespace) or nil
            local requested_version = normalize_manifest_version(package_version(pkg))
            local requested_namespace = package_namespace(pkg)
            if action == "remove" then
                if current ~= nil then
                    table.insert(missing, pkg)
                end
            elseif action == "update" then
                table.insert(missing, pkg)
            elseif current == nil then
                table.insert(missing, pkg)
            elseif requested_version ~= "*" and current_version ~= requested_version then
                table.insert(missing, pkg)
            elseif requested_namespace ~= "" and current_namespace ~= requested_namespace then
                table.insert(missing, pkg)
            end
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
    begin_step(context, "cache fpm dependencies")
    if merge_packages_into_manifest(context, packages, false) == nil then
        return false
    end
    if not fetch_manifest_dependencies(context) then
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
        tx_failed(context, "fpm local install failed")
        return false
    end
    begin_step(context, "install local fpm project")
    local command = run_in_directory_command(local_path, fpm_install_local_command())
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        tx_failed(context, "fpm local install failed")
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
    begin_step(context, "remove tracked fpm dependencies")
    if merge_packages_into_manifest(context, packages, true) == nil then
        return false
    end
    emit_event(context, "deleted", packages)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    begin_step(context, "refresh fpm dependency cache")
    if packages ~= nil and #packages > 0 then
        if merge_packages_into_manifest(context, packages, false) == nil then
            return false
        end
    elseif not ensure_directory(synthetic_project_dir(context, packages)) then
        tx_failed(context, "fpm manifest directory create failed")
        return false
    elseif read_text_file(context, synthetic_manifest_path(context, packages)) == nil and not save_manifest_dependencies(context, packages, load_manifest_dependencies(context, packages)) then
        tx_failed(context, "fpm manifest write failed")
        return false
    end
    if not fetch_manifest_dependencies(context) then
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
        local current = normalize_manifest_version(item.version)
        local latest = trim(item.latestVersion or "")
        if current ~= "*" and latest ~= "" and current ~= latest then
            item.status = "outdated"
            item.installed = true
            table.insert(items, item)
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local request = read_field(context, "request") or {}
    local search_prompt = lower(trim(first_nonempty(prompt, read_field(context, "prompt"), read_field(request, "prompt"))))
    if search_prompt == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end
    local index = ensure_registry_index(context)
    local items = {}
    if index ~= nil then
        for package_key, versions in pairs(registry_packages(index)) do
            local item = package_record_to_item(package_key, "latest", type(versions) == "table" and read_field(versions, "latest") or nil)
            if item ~= nil then
                local haystack = lower(table.concat({
                    trim(item.name),
                    trim(item.summary),
                    trim(item.description),
                    trim(read_field(item.extraFields, "namespace")),
                }, "\n"))
                if haystack:find(search_prompt, 1, true) ~= nil then
                    table.insert(items, item)
                end
            end
        end
        table.sort(items, function(left, right)
            return trim(left.name) < trim(right.name)
        end)
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local request = read_field(context, "request") or {}
    local query = trim(first_nonempty(name, read_field(context, "prompt"), read_field(request, "name"), read_field(request, "prompt")))
    local item = {}
    if query ~= "" then
        local resolved, err = resolve_registry_package(context, { name = query })
        if resolved ~= nil then
            item = resolved
        elseif err == "package namespace ambiguous" then
            log_warn(context, "fpm package namespace ambiguous for " .. query)
        end
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local resolved, _ = resolve_registry_package(context, package)
    return resolved
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "fortran", "fpm", "fpm-registry" },
        writeScopes = {},
        networkScopes = { REGISTRY_INDEX_URL },
        privilegeLevel = "user",
    }
end

function plugin.init()
    local result = run_exec(nil, "command -v " .. REQUIRED_BINARY .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

function plugin.shutdown()
end

return plugin
