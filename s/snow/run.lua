plugin = {}

local PLUGIN_ID = "snow"
local PLUGIN_NAME = "snow"
local PLUGIN_VERSION = "0.1.0"
local CANDIDATE_BINARIES = { "snow", "snow-chibi" }

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return trim(value):lower()
end

local function non_empty(value)
    local cleaned = trim(value)
    if cleaned == "" then
        return nil
    end
    return cleaned
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

local function object_flags(value)
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
    local function collect_from(value)
        for _, flag in ipairs(object_flags(value)) do
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

local function flag_value(flags, key)
    local prefix = lower(key) .. "="
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            return trim(cleaned:sub(#prefix + 1))
        end
    end
    return nil
end

local function has_flag(flags, key)
    local wanted = lower(key)
    for _, flag in ipairs(flags or {}) do
        if lower(trim(flag)) == wanted then
            return true
        end
    end
    return false
end

local function normalize_exec_result(first, second, third, fourth, fifth)
    local result = {}
    local function apply(value)
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
    else
        first, second, third, fourth, fifth = reqpack.exec.run(command)
    end
    return normalize_exec_result(first, second, third, fourth, fifth)
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

local function read_proc_environ_value(name)
    if os ~= nil and type(os.getenv) == "function" then
        local value = os.getenv(tostring(name or ""))
        if value ~= nil and value ~= "" then
            return trim(value)
        end
    end

    local handle = io.open("/proc/self/environ", "rb")
    if handle == nil then
        return nil
    end
    local payload = handle:read("*a")
    handle:close()
    if payload == nil or payload == "" then
        return nil
    end

    local prefix = tostring(name or "") .. "="
    for entry in tostring(payload):gmatch("[^%z]+") do
        if entry:sub(1, #prefix) == prefix then
            return trim(entry:sub(#prefix + 1))
        end
    end
    return nil
end

local function get_reqpack_path(name)
    local paths = type(reqpack) == "table" and read_field(reqpack, "paths") or nil
    if type(paths) ~= "table" then
        return nil
    end
    return non_empty(read_field(paths, name))
end

local function xdg_root(kind)
    local home = non_empty(read_proc_environ_value("HOME")) or "/home/test"
    if kind == "data" then
        return non_empty(read_proc_environ_value("XDG_DATA_HOME")) or join_path(home, ".local", "share")
    end
    if kind == "cache" then
        return non_empty(read_proc_environ_value("XDG_CACHE_HOME")) or join_path(home, ".cache")
    end
    return non_empty(read_proc_environ_value("XDG_CONFIG_HOME")) or join_path(home, ".config")
end

local function reqpack_root(kind, context)
    local flags = collect_flags(context, nil)
    local override = flag_value(flags, kind .. "-root")
    if override ~= nil then
        return override
    end

    local fixture_root = non_empty(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT"))
    if fixture_root ~= nil then
        if kind == "data" then
            return join_path(fixture_root, ".reqpack-data")
        end
        if kind == "cache" then
            return join_path(fixture_root, ".reqpack-cache")
        end
        return join_path(fixture_root, ".reqpack-config")
    end

    if kind == "data" then
        return get_reqpack_path("dataRoot") or join_path(xdg_root("data"), "reqpack")
    end
    if kind == "cache" then
        return get_reqpack_path("cacheRoot") or join_path(xdg_root("cache"), "reqpack")
    end
    return get_reqpack_path("configRoot") or join_path(xdg_root("config"), "reqpack")
end

local function runtime_paths(context)
    local data_root = join_path(reqpack_root("data", context), PLUGIN_ID)
    local cache_root = join_path(reqpack_root("cache", context), PLUGIN_ID)
    local config_root = join_path(reqpack_root("config", context), PLUGIN_ID)
    return {
        dataRoot = data_root,
        cacheRoot = cache_root,
        configRoot = config_root,
        homeDir = join_path(data_root, "home"),
        repoDir = join_path(cache_root, "repo"),
        repoRootDir = join_path(cache_root, "repo-root"),
        repoFile = join_path(cache_root, "repo", "repo.scm"),
    }
end

local function ensure_directory(context, path)
    local result = exec_run(context, "mkdir -p " .. shell_quote(path))
    return result ~= nil and result.success == true
end

local function ensure_runtime_dirs(context)
    local paths = runtime_paths(context)
    for _, path in ipairs({ paths.homeDir, paths.repoDir, paths.repoRootDir, paths.configRoot }) do
        if not ensure_directory(context, path) then
            return nil, "failed to prepare snow runtime directories"
        end
    end
    return true, nil
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

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageId") or "")
end

local function package_version(pkg)
    return trim(read_field(pkg, "version") or "")
end

local function env_prefix(context)
    local paths = runtime_paths(context)
    return table.concat({
        "NO_COLOR=1",
        "LC_ALL=C",
        "LANG=C",
        "LANGUAGE=C",
        "HOME=" .. shell_quote(paths.homeDir),
    }, " ")
end

local function resolve_binary(context)
    local cached = read_field(context, "_snow_binary")
    if non_empty(cached) ~= nil then
        return trim(cached)
    end
    for _, binary in ipairs(CANDIDATE_BINARIES) do
        local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
        if result ~= nil and result.success then
            if type(context) == "table" then
                context._snow_binary = binary
            end
            return binary
        end
    end
    return nil
end

local function build_common_args(context, package, update_strategy)
    local flags = collect_flags(context, package)
    local paths = runtime_paths(context)
    local args = {
        "--local-user-repository=" .. paths.repoDir,
        "--local-root-repository=" .. paths.repoRootDir,
    }

    local function add_value(key)
        local value = flag_value(flags, key)
        if value ~= nil then
            args[#args + 1] = "--" .. key .. "=" .. value
        end
    end

    if update_strategy ~= nil then
        args[#args + 1] = "--update-strategy=" .. update_strategy
    else
        add_value("update-strategy")
    end

    add_value("impls")
    add_value("repo")
    add_value("host")
    add_value("install-prefix")
    add_value("install-source-dir")
    add_value("install-library-dir")
    add_value("install-binary-dir")
    add_value("install-data-dir")

    if has_flag(flags, "always-yes") then
        args[#args + 1] = "--always-yes"
    end
    if has_flag(flags, "ignore-sig") then
        args[#args + 1] = "--ignore-sig"
    end
    if has_flag(flags, "require-sig") then
        args[#args + 1] = "--require-sig"
    end

    return args
end

local function snow_command(context, package, subcommand, args, update_strategy)
    local binary = resolve_binary(context)
    if binary == nil then
        return nil, "snow not installed"
    end

    local parts = { env_prefix(context), shell_quote(binary) }
    for _, arg in ipairs(build_common_args(context, package, update_strategy)) do
        parts[#parts + 1] = shell_quote(arg)
    end
    parts[#parts + 1] = shell_quote(subcommand)
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = shell_quote(arg)
    end
    return table.concat(parts, " "), nil
end

local function fail_action(context, message)
    tx_failed(context, message)
    return false, message
end

local function split_version(value)
    local parts = {}
    local text = trim(value)
    if text == "" then
        return parts
    end
    for token in text:gmatch("[^%.%-_]+") do
        local start_index = 1
        while start_index <= #token do
            local number_start, number_end = token:find("%d+", start_index)
            if number_start == nil then
                local tail = token:sub(start_index)
                if tail ~= "" then
                    parts[#parts + 1] = tail
                end
                break
            end
            if number_start > start_index then
                parts[#parts + 1] = token:sub(start_index, number_start - 1)
            end
            parts[#parts + 1] = token:sub(number_start, number_end)
            start_index = number_end + 1
        end
    end
    return parts
end

local function compare_versions(left, right)
    local left_parts = split_version(left)
    local right_parts = split_version(right)
    local length = math.max(#left_parts, #right_parts)
    for index = 1, length do
        local a = left_parts[index]
        local b = right_parts[index]
        if a == nil then
            return -1
        end
        if b == nil then
            return 1
        end
        local a_num = tonumber(a)
        local b_num = tonumber(b)
        if a_num ~= nil and b_num ~= nil then
            if a_num < b_num then
                return -1
            end
            if a_num > b_num then
                return 1
            end
        else
            local a_text = tostring(a)
            local b_text = tostring(b)
            if a_text < b_text then
                return -1
            end
            if a_text > b_text then
                return 1
            end
        end
    end
    return 0
end

local function build_item(name, version, installed, status, latest_version, extra_fields)
    local item = {
        name = trim(name),
        packageId = trim(name),
        version = trim(version),
        manager = PLUGIN_ID,
        system = PLUGIN_ID,
        installed = installed == true,
        status = status,
        latestVersion = latest_version,
    }
    if type(extra_fields) == "table" and next(extra_fields) ~= nil then
        item.extraFields = extra_fields
    end
    return item
end

local function parse_summary_output(output, installed)
    local items = {}
    local current_impl = nil
    for _, raw_line in ipairs(split_lines(output)) do
        local line = trim(raw_line)
        if line ~= "" then
            local implementation = line:match("^([^%s][^\t]-):$")
            if implementation ~= nil then
                current_impl = trim(implementation)
            else
                local name, version = raw_line:match("^(.-)\t([^\t]+)%s*$")
                if name ~= nil and version ~= nil then
                    local extra = current_impl ~= nil and { implementation = current_impl } or nil
                    items[#items + 1] = build_item(name, version, installed, installed and "installed" or "available", nil, extra)
                end
            end
        end
    end
    return items
end

local function read_string_token(text, index)
    local pieces = {}
    index = index + 1
    while index <= #text do
        local char = text:sub(index, index)
        if char == '"' then
            return table.concat(pieces), index + 1
        end
        if char == "\\" then
            local next_char = text:sub(index + 1, index + 1)
            if next_char == "n" then
                pieces[#pieces + 1] = "\n"
            elseif next_char == "r" then
                pieces[#pieces + 1] = "\r"
            elseif next_char == "t" then
                pieces[#pieces + 1] = "\t"
            else
                pieces[#pieces + 1] = next_char
            end
            index = index + 2
        else
            pieces[#pieces + 1] = char
            index = index + 1
        end
    end
    return nil, index
end

local function tokenize_sexp(text)
    local tokens = {}
    local index = 1
    while index <= #text do
        local char = text:sub(index, index)
        if char:match("%s") then
            index = index + 1
        elseif char == ";" then
            local next_newline = text:find("\n", index, true)
            if next_newline == nil then
                break
            end
            index = next_newline + 1
        elseif char == "(" or char == ")" then
            tokens[#tokens + 1] = char
            index = index + 1
        elseif char == '"' then
            local value, next_index = read_string_token(text, index)
            if value == nil then
                return nil, "invalid string in snow repository"
            end
            tokens[#tokens + 1] = value
            index = next_index
        else
            local start_index = index
            while index <= #text do
                local current = text:sub(index, index)
                if current:match("[%s();]") or current == '"' then
                    break
                end
                index = index + 1
            end
            tokens[#tokens + 1] = text:sub(start_index, index - 1)
        end
    end
    return tokens, nil
end

local function parse_tokens(tokens)
    local index = 1

    local function parse_expr()
        local token = tokens[index]
        if token == nil then
            return nil, "unexpected end of repository data"
        end
        if token == "(" then
            index = index + 1
            local list = {}
            while tokens[index] ~= ")" do
                if tokens[index] == nil then
                    return nil, "unclosed list in repository data"
                end
                local value, err = parse_expr()
                if err ~= nil then
                    return nil, err
                end
                list[#list + 1] = value
            end
            index = index + 1
            return list, nil
        end
        if token == ")" then
            return nil, "unexpected closing paren in repository data"
        end
        index = index + 1
        return token, nil
    end

    local value, err = parse_expr()
    if err ~= nil then
        return nil, err
    end
    return value, nil
end

local function list_head(node)
    if type(node) ~= "table" then
        return nil
    end
    return node[1]
end

local function list_children(node, key)
    local items = {}
    if type(node) ~= "table" then
        return items
    end
    for _, child in ipairs(node) do
        if type(child) == "table" and child[1] == key then
            items[#items + 1] = child
        end
    end
    return items
end

local function first_child(node, key)
    for _, child in ipairs(list_children(node, key)) do
        return child
    end
    return nil
end

local function sexp_name_string(value)
    if type(value) ~= "table" then
        return trim(value)
    end
    local parts = {}
    for _, item in ipairs(value) do
        parts[#parts + 1] = trim(item)
    end
    return "(" .. table.concat(parts, " ") .. ")"
end

local function dotted_name_string(value)
    if type(value) ~= "table" then
        return trim(value)
    end
    local parts = {}
    for _, item in ipairs(value) do
        parts[#parts + 1] = trim(item)
    end
    return table.concat(parts, ".")
end

local function extract_list_strings(node)
    local items = {}
    if type(node) ~= "table" then
        return items
    end
    for index = 2, #node do
        items[#items + 1] = trim(node[index])
    end
    return items
end

local function collect_aliases(raw_name)
    local aliases = {}
    local seen = {}
    local function add(value)
        local cleaned = trim(value)
        if cleaned ~= "" and not seen[cleaned] then
            seen[cleaned] = true
            aliases[#aliases + 1] = cleaned
        end
    end
    if type(raw_name) == "table" then
        add(sexp_name_string(raw_name))
        add(dotted_name_string(raw_name))
    else
        add(raw_name)
    end
    return aliases
end

local function parse_repository_package(node)
    local name_node = first_child(node, "name")
    local raw_name = name_node ~= nil and name_node[2] or nil
    local package_name_value = raw_name ~= nil and sexp_name_string(raw_name) or nil
    local library_names = {}
    local aliases = {}
    local seen = {}

    local function add_alias(value)
        local cleaned = trim(value)
        if cleaned ~= "" and not seen[cleaned] then
            seen[cleaned] = true
            aliases[#aliases + 1] = cleaned
        end
    end

    if raw_name ~= nil then
        for _, alias in ipairs(collect_aliases(raw_name)) do
            add_alias(alias)
        end
    end

    for _, library in ipairs(list_children(node, "library")) do
        local library_name_node = first_child(library, "name")
        local library_raw_name = library_name_node ~= nil and library_name_node[2] or nil
        if library_raw_name ~= nil then
            local canonical = sexp_name_string(library_raw_name)
            library_names[#library_names + 1] = canonical
            for _, alias in ipairs(collect_aliases(library_raw_name)) do
                add_alias(alias)
            end
        end
    end

    local description_node = first_child(node, "description")
    local url_node = first_child(node, "url")
    local manual_node = first_child(node, "manual")
    local version_node = first_child(node, "version")
    local updated_node = first_child(node, "updated")
    local created_node = first_child(node, "created")
    local license_node = first_child(node, "license")
    local signature_node = first_child(node, "signature")
    local signature_email_node = signature_node ~= nil and first_child(signature_node, "email") or nil

    return {
        packageName = package_name_value,
        name = library_names[1] or package_name_value or "",
        version = version_node ~= nil and trim(version_node[2]) or "",
        description = description_node ~= nil and trim(description_node[2]) or nil,
        url = url_node ~= nil and trim(url_node[2]) or nil,
        manual = manual_node ~= nil and trim(manual_node[2]) or nil,
        updated = updated_node ~= nil and trim(updated_node[2]) or nil,
        created = created_node ~= nil and trim(created_node[2]) or nil,
        license = license_node ~= nil and trim(license_node[2]) or nil,
        signatureEmail = signature_email_node ~= nil and trim(signature_email_node[2]) or nil,
        authors = extract_list_strings(first_child(node, "authors") or {}),
        maintainers = extract_list_strings(first_child(node, "maintainers") or {}),
        libraryNames = library_names,
        aliases = aliases,
    }
end

local function load_repository(context)
    local payload = read_text_file(runtime_paths(context).repoFile)
    if payload == nil then
        return nil, "snow repository cache missing"
    end
    local tokens, token_error = tokenize_sexp(payload)
    if tokens == nil then
        return nil, token_error
    end
    local root, parse_error = parse_tokens(tokens)
    if root == nil then
        return nil, parse_error
    end
    if type(root) ~= "table" or root[1] ~= "repository" then
        return nil, "snow repository cache invalid"
    end

    local packages = {}
    for _, child in ipairs(root) do
        if type(child) == "table" and child[1] == "package" then
            packages[#packages + 1] = parse_repository_package(child)
        end
    end
    return packages, nil
end

local function matches_alias(meta, target)
    local wanted = lower(target)
    for _, alias in ipairs(meta.aliases or {}) do
        if lower(alias) == wanted then
            return alias
        end
    end
    return nil
end

local function preferred_name(meta, matched_alias)
    return non_empty(matched_alias) or non_empty(meta.name) or non_empty(meta.packageName) or ""
end

local function repository_item(meta, matched_alias, installed, latest_version, status)
    local extra = {}
    if meta.packageName ~= nil then
        extra.packageName = meta.packageName
    end
    if meta.description ~= nil then
        extra.description = meta.description
    end
    if meta.manual ~= nil then
        extra.manual = meta.manual
    end
    if meta.url ~= nil then
        extra.url = meta.url
    end
    if meta.updated ~= nil then
        extra.updated = meta.updated
    end
    if meta.created ~= nil then
        extra.created = meta.created
    end
    if meta.license ~= nil then
        extra.license = meta.license
    end
    if meta.signatureEmail ~= nil then
        extra.signatureEmail = meta.signatureEmail
    end
    if #(meta.authors or {}) > 0 then
        extra.authors = meta.authors
    end
    if #(meta.maintainers or {}) > 0 then
        extra.maintainers = meta.maintainers
    end
    if #(meta.libraryNames or {}) > 0 then
        extra.libraryNames = meta.libraryNames
    end

    local item = build_item(preferred_name(meta, matched_alias), meta.version, installed, status, latest_version, next(extra) ~= nil and extra or nil)
    item.description = meta.description
    item.homepage = meta.manual or meta.url
    return item
end

local function refresh_repository(context)
    local ok, err = ensure_runtime_dirs(context)
    if not ok then
        return nil, err
    end
    local command, command_error = snow_command(context, nil, "update", {}, nil)
    if command == nil then
        return nil, command_error
    end
    local result = exec_run(context, command)
    if result == nil or not result.success then
        return nil, non_empty(result and result.stderr) or non_empty(result and result.stdout) or "snow update failed"
    end
    return true, nil
end

local function repository_cache_exists(context)
    return read_text_file(runtime_paths(context).repoFile) ~= nil
end

local function query_status(context, names)
    local command, command_error = snow_command(context, nil, "status", names or {}, "never")
    if command == nil then
        return nil, command_error
    end
    local result = exec_run(context, command)
    if result == nil or not result.success then
        return nil, non_empty(result and result.stderr) or non_empty(result and result.stdout) or "snow status failed"
    end
    return parse_summary_output(result.stdout, true), nil
end

local function installed_status_map(context, names)
    local items, err = query_status(context, names)
    if items == nil then
        return nil, err
    end
    local map = {}
    for _, item in ipairs(items) do
        map[lower(item.name)] = item
    end
    return map, nil
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
    return { "programming-language", "package-manager", "scheme" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end
    if resolve_binary(nil) == nil then
        return requested
    end
    local installed, err = installed_status_map(nil, nil)
    if installed == nil then
        log_warn(nil, err)
        return requested
    end
    local missing = {}
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        local version = package_version(pkg)
        local current = installed[lower(name)]
        if current == nil then
            missing[#missing + 1] = pkg
        elseif version ~= "" and trim(current.version) ~= version then
            missing[#missing + 1] = pkg
        end
    end
    return missing
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if resolve_binary(context) == nil then
        return fail_action(context, "snow not installed")
    end
    local ok, err = ensure_runtime_dirs(context)
    if not ok then
        return fail_action(context, err)
    end

    begin_step(context, "install snow packages")
    local installed = {}
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        if name == "" then
            return fail_action(context, "snow package name missing")
        end
        local args = { name }
        local command, command_error = snow_command(context, pkg, "install", args, "cache")
        if command == nil then
            return fail_action(context, command_error)
        end
        local result = exec_run(context, command)
        if result == nil or not result.success then
            return fail_action(context, "snow install failed for " .. name)
        end
        installed[#installed + 1] = build_item(name, package_version(pkg), true, "installed", nil, nil)
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local target = trim(path)
    if target == "" then
        return fail_action(context, "snow local artifact path missing")
    end
    if resolve_binary(context) == nil then
        return fail_action(context, "snow not installed")
    end
    local ok, err = ensure_runtime_dirs(context)
    if not ok then
        return fail_action(context, err)
    end

    begin_step(context, "install local snow package")
    local command, command_error = snow_command(context, nil, "install", { target }, "never")
    if command == nil then
        return fail_action(context, command_error)
    end
    local result = exec_run(context, command)
    if result == nil or not result.success then
        return fail_action(context, "snow local install failed")
    end
    emit_event(context, "installed", { build_item(target, "", true, "installed", nil, { source = "local" }) })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if resolve_binary(context) == nil then
        return fail_action(context, "snow not installed")
    end
    local ok, err = ensure_runtime_dirs(context)
    if not ok then
        return fail_action(context, err)
    end

    begin_step(context, "remove snow packages")
    local removed = {}
    for _, pkg in ipairs(requested) do
        local name = package_name(pkg)
        if name == "" then
            return fail_action(context, "snow package name missing")
        end
        local command, command_error = snow_command(context, pkg, "remove", { name }, "never")
        if command == nil then
            return fail_action(context, command_error)
        end
        local result = exec_run(context, command)
        if result == nil or not result.success then
            return fail_action(context, "snow remove failed for " .. name)
        end
        removed[#removed + 1] = build_item(name, package_version(pkg), false, "deleted", nil, nil)
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    if resolve_binary(context) == nil then
        return fail_action(context, "snow not installed")
    end
    local ok, err = ensure_runtime_dirs(context)
    if not ok then
        return fail_action(context, err)
    end

    begin_step(context, "update snow packages")
    local refreshed, refresh_error = refresh_repository(context)
    if not refreshed then
        return fail_action(context, refresh_error)
    end

    local args = {}
    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        if name ~= "" then
            args[#args + 1] = name
        end
    end
    local command, command_error = snow_command(context, nil, "upgrade", args, "never")
    if command == nil then
        return fail_action(context, command_error)
    end
    local result = exec_run(context, command)
    if result == nil or not result.success then
        return fail_action(context, "snow upgrade failed")
    end
    emit_event(context, "updated", packages or {})
    tx_success(context)
    return true
end

function plugin.list(context)
    if resolve_binary(context) == nil then
        log_warn(context, "snow not installed")
        emit_event(context, "listed", {})
        return {}
    end
    local ok, err = ensure_runtime_dirs(context)
    if not ok then
        log_warn(context, err)
        emit_event(context, "listed", {})
        return {}
    end
    local items, query_error = query_status(context, {})
    if items == nil then
        log_warn(context, query_error)
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    if resolve_binary(context) == nil then
        log_warn(context, "snow not installed")
        emit_event(context, "outdated", {})
        return {}
    end
    local ok, err = ensure_runtime_dirs(context)
    if not ok then
        log_warn(context, err)
        emit_event(context, "outdated", {})
        return {}
    end
    local refreshed, refresh_error = refresh_repository(context)
    if not refreshed and not repository_cache_exists(context) then
        log_warn(context, refresh_error)
        emit_event(context, "outdated", {})
        return {}
    end
    local installed, installed_error = query_status(context, {})
    if installed == nil then
        log_warn(context, installed_error)
        emit_event(context, "outdated", {})
        return {}
    end
    local items = {}
    for _, current in ipairs(installed) do
        local command, command_error = snow_command(context, nil, "show", { current.name }, "never")
        if command == nil then
            log_warn(context, command_error)
        else
            local result = exec_run(context, command)
            if result ~= nil and result.success then
                local available = parse_summary_output(result.stdout, false)
                local remote = available[1]
                if remote ~= nil and compare_versions(current.version, remote.version) < 0 then
                    local item = build_item(current.name, current.version, true, "outdated", remote.version, read_field(remote, "extraFields"))
                    items[#items + 1] = item
                end
            end
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
    if query == "" then
        emit_event(context, "searched", {})
        return {}
    end
    if resolve_binary(context) == nil then
        log_warn(context, "snow not installed")
        emit_event(context, "searched", {})
        return {}
    end
    local ok, err = ensure_runtime_dirs(context)
    if not ok then
        log_warn(context, err)
        emit_event(context, "searched", {})
        return {}
    end
    local refreshed, refresh_error = refresh_repository(context)
    if not refreshed and not repository_cache_exists(context) then
        log_warn(context, refresh_error)
        emit_event(context, "searched", {})
        return {}
    end
    local command, command_error = snow_command(context, nil, "search", { query }, "never")
    if command == nil then
        log_warn(context, command_error)
        emit_event(context, "searched", {})
        return {}
    end
    local result = exec_run(context, command)
    if result == nil or not result.success then
        log_warn(context, non_empty(result and result.stderr) or non_empty(result and result.stdout) or "snow search failed")
        emit_event(context, "searched", {})
        return {}
    end
    local items = parse_summary_output(result.stdout, false)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local target = trim(name or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
    if target == "" then
        emit_event(context, "informed", {})
        return {}
    end
    if resolve_binary(context) == nil then
        log_warn(context, "snow not installed")
        emit_event(context, "informed", {})
        return {}
    end
    local ok, err = ensure_runtime_dirs(context)
    if not ok then
        log_warn(context, err)
        emit_event(context, "informed", {})
        return {}
    end
    local refreshed, refresh_error = refresh_repository(context)
    if not refreshed and not repository_cache_exists(context) then
        log_warn(context, refresh_error)
        emit_event(context, "informed", {})
        return {}
    end
    local installed_map, status_error = installed_status_map(context, { target })
    if installed_map == nil then
        log_warn(context, status_error)
        installed_map = {}
    end

    local command, command_error = snow_command(context, nil, "show", { target }, "never")
    if command ~= nil then
        local result = exec_run(context, command)
        if result ~= nil and result.success then
            local available = parse_summary_output(result.stdout, false)
            local item = available[1]
            if item ~= nil then
                item.installed = installed_map[lower(item.name)] ~= nil or installed_map[lower(target)] ~= nil
                item.status = item.installed and "installed" or "available"
                emit_event(context, "informed", item)
                return item
            end
        end
    else
        log_warn(context, command_error)
    end

    local installed_item = installed_map[lower(target)]
    if installed_item ~= nil then
        emit_event(context, "informed", installed_item)
        return installed_item
    end

    emit_event(context, "informed", {})
    return {}
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
        ecosystemScopes = { "scheme", "snow" },
        writeScopes = {
            { kind = "plugin-subpath", path = ".reqpack-data" },
            { kind = "plugin-subpath", path = ".reqpack-cache" },
            { kind = "plugin-subpath", path = ".reqpack-config" },
        },
        privilegeLevel = "user",
        purlType = "generic",
    }
end

return plugin
