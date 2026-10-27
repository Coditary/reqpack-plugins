plugin = {}

local PLUGIN_NAME = "V Package Manager"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "v"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function non_empty(value)
    local text = trim(value)
    if text == "" then
        return nil
    end
    return text
end

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil then
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

local function object_flags(object)
    local raw = read_field(object, "flags")
    if type(raw) ~= "table" and type(raw) ~= "userdata" then
        return {}
    end
    local flags = {}
    local ok = pcall(function()
        for _, item in ipairs(raw) do
            local cleaned = trim(expand_placeholders(item))
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

local function append_unique(list, seen, value)
    local cleaned = trim(value)
    if cleaned == "" or seen[cleaned] then
        return
    end
    seen[cleaned] = true
    list[#list + 1] = cleaned
end

local function collect_raw_flags(context, packages)
    local flags = {}
    local seen = {}
    for _, flag in ipairs(object_flags(context)) do
        append_unique(flags, seen, flag)
    end
    for _, flag in ipairs(object_flags(read_field(context, "request"))) do
        append_unique(flags, seen, flag)
    end
    for _, pkg in ipairs(packages or {}) do
        for _, flag in ipairs(object_flags(pkg)) do
            append_unique(flags, seen, flag)
        end
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

local function shell_quote(value)
    local text = tostring(value or "")
    if text:match("^[%w%+%-%._/%:@=,]+$") ~= nil then
        return text
    end
    return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function strict_quote(value)
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

local function env_raw(name)
    if os ~= nil and type(os.getenv) == "function" then
        return os.getenv(name)
    end
    return nil
end

local function expand_placeholders(value)
    local text = tostring(value or "")
    local fixture_root = trim(env_raw("REQPACK_TEST_FIXTURE_ROOT") or "")
    if fixture_root ~= "" then
        text = text:gsub("%${fixtureRoot}", fixture_root)
    end
    return text
end

local function env_value(name)
    return trim(expand_placeholders(env_raw(name) or ""))
end

local function home_dir()
    return first_nonempty(env_value("HOME"), env_value("USERPROFILE"), "/home/test")
end

local function path_delimiter(value)
    local text = tostring(value or "")
    if text:find(";", 1, true) ~= nil and text:find(":", 1, true) == nil then
        return ";"
    end
    return ":"
end

local function split_path_list(value)
    local text = trim(value)
    local parts = {}
    if text == "" then
        return parts
    end
    local delimiter = path_delimiter(text)
    local pattern = "([^" .. delimiter .. "]+)"
    for part in text:gmatch(pattern) do
        local cleaned = trim(expand_placeholders(part))
        if cleaned ~= "" then
            parts[#parts + 1] = cleaned
        end
    end
    return parts
end

local function directory_exists(path)
    local handle = io.open(join_path(path, "."), "rb")
    if handle ~= nil then
        handle:close()
        return true
    end
    return false
end

local function exec_like_result(value)
    if type(value) == "table" then
        return {
            success = value.success == true or value.ok == true or value.exitCode == 0 or value.exit_code == 0 or value.code == 0,
            stdout = tostring(value.stdout or value.stdoutText or ""),
            stderr = tostring(value.stderr or value.stderrText or ""),
            exitCode = value.exitCode or value.exit_code or value.code or value.status,
        }
    end
    if type(value) == "userdata" then
        local result = {
            success = false,
            stdout = "",
            stderr = "",
            exitCode = nil,
        }
        local function read_prop(key)
            local ok, item = pcall(function()
                return value[key]
            end)
            if ok then
                return item
            end
            return nil
        end
        result.stdout = tostring(read_prop("stdout") or read_prop("stdoutText") or "")
        result.stderr = tostring(read_prop("stderr") or read_prop("stderrText") or "")
        result.exitCode = read_prop("exitCode") or read_prop("exit_code") or read_prop("code") or read_prop("status")
        local success = read_prop("success")
        local ok_value = read_prop("ok")
        if success ~= nil then
            result.success = success == true
        elseif ok_value ~= nil then
            result.success = ok_value == true
        elseif result.exitCode ~= nil then
            result.success = result.exitCode == 0
        end
        return result
    end
    return {
        success = false,
        stdout = "",
        stderr = "",
        exitCode = nil,
    }
end

local function read_file(path)
    local handle = io.open(path, "r")
    if handle == nil then
        if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
            local result = exec_like_result(reqpack.exec.run("cat " .. strict_quote(path)))
            if result ~= nil and result.success == true then
                return result.stdout
            end
        end
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
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
    if next(result) == nil then
        return {
            success = false,
            stdout = "",
            stderr = "command execution failed",
            exitCode = 1,
        }
    end
    return result
end

local function run_exec(context, command)
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

local function resolve_vmodules(context, packages)
    local raw = flag_value(collect_raw_flags(context, packages), "vmodules") or env_value("VMODULES")
    if raw == "" then
        raw = join_path(home_dir(), ".vmodules")
    end
    local roots = split_path_list(raw)
    if #roots == 0 then
        roots[1] = join_path(home_dir(), ".vmodules")
        raw = roots[1]
    end
    return {
        raw = raw,
        roots = roots,
        canonical = roots[1],
    }
end

local function list_dir(context, path)
    local result = run_exec(context, "ls -1A " .. strict_quote(path))
    if result == nil or result.success ~= true then
        return {}
    end
    local items = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" and cleaned ~= "." and cleaned ~= ".." then
            items[#items + 1] = cleaned
        end
    end
    return items
end

local function detect_v_binary(context)
    local result = run_exec(context, "command -v " .. REQUIRED_BINARY .. " 2>/dev/null")
    if result == nil or result.success ~= true then
        return nil
    end
    return non_empty(result.stdout)
end

local function v_env_prefix(vmodules)
    return table.concat({
        "NO_COLOR='1'",
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
        "VMODULES=" .. strict_quote(vmodules.raw),
    }, " ")
end

local function v_command(binary, vmodules, args)
    local parts = { v_env_prefix(vmodules), shell_quote(binary) }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = shell_quote(arg)
    end
    return table.concat(parts, " ")
end

local function parse_bool(value)
    local text = lower(trim(value))
    return text == "true" or text == "yes" or text == "1"
end

local function repository_from_url(url)
    local text = trim(url or "")
    if text:match("^https?://") ~= nil then
        return text
    end
    return nil
end

local function extract_module_id(line)
    local cleaned = trim(tostring(line or ""):gsub("^[-*]%s*", ""))
    if cleaned == "" then
        return nil
    end
    if cleaned:sub(-1) == ":" then
        return nil
    end
    local quoted = cleaned:match('^"([^"]+)"') or cleaned:match("^'([^']+)'")
    if quoted ~= nil then
        return trim(quoted)
    end
    local dotted = cleaned:match("^([%w_%-]+%.[%w_%-%.]+)")
    if dotted ~= nil then
        return dotted
    end
    local bare = cleaned:match("^([%w_%-]+)")
    return bare
end

local function parse_bracket_list(text)
    local items = {}
    local body = tostring(text or "")
    for value in body:gmatch("'([^']+)'") do
        items[#items + 1] = trim(value)
    end
    for value in body:gmatch('"([^"]+)"') do
        items[#items + 1] = trim(value)
    end
    if #items > 0 then
        return items
    end
    local inner = body:match("%[(.*)%]") or body
    for part in inner:gmatch("[^,%[%]]+") do
        local cleaned = trim(part)
        if cleaned ~= "" then
            items[#items + 1] = cleaned
        end
    end
    return items
end

local function parse_vmod_string(raw)
    local text = trim(raw or "")
    text = text:gsub(",%s*$", "")
    local quoted = text:match("^'(.*)'$") or text:match('^"(.*)"$')
    if quoted ~= nil then
        return trim(quoted)
    end
    return trim(text)
end

local function field_from_vmod(content, key)
    local raw = tostring(content or "")
    if raw == "" then
        return nil
    end
    local matched = nil
    local dependency_parts = {}
    local collecting_dependencies = false
    for _, line in ipairs(split_lines(raw)) do
        local cleaned = trim(line)
        if collecting_dependencies then
            dependency_parts[#dependency_parts + 1] = cleaned
            if cleaned:find("]", 1, true) ~= nil then
                matched = table.concat(dependency_parts, " ")
                break
            end
        else
            local current_key, current_value = cleaned:match("^(%w+)%s*:%s*(.+)$")
            if current_key == key then
                if key == "dependencies" and current_value:find("]", 1, true) == nil then
                    collecting_dependencies = true
                    dependency_parts = { current_value }
                else
                    matched = current_value
                    break
                end
            end
        end
    end
    if key == "dependencies" then
        return parse_bracket_list(matched)
    end
    return parse_vmod_string(matched)
end

local function package_name(pkg)
    if type(pkg) == "table" or type(pkg) == "userdata" then
        return trim(read_field(pkg, "packageId") or read_field(pkg, "name") or read_field(pkg, "id") or read_field(pkg, "package") or "")
    end
    return trim(pkg)
end

local function package_base_id(value)
    local text = package_name(value)
    local at_index = text:find("@", 1, true)
    if at_index ~= nil then
        text = text:sub(1, at_index - 1)
    end
    return trim(text)
end

local function package_query(pkg)
    if type(pkg) ~= "table" and type(pkg) ~= "userdata" then
        return trim(pkg)
    end
    local identifier = package_name(pkg)
    local version = trim(read_field(pkg, "version") or "")
    if identifier == "" then
        return ""
    end
    if identifier:find("@", 1, true) ~= nil then
        return identifier
    end
    if version ~= "" then
        return identifier .. "@" .. version
    end
    return identifier
end

local function request_local_path(context)
    return first_nonempty(
        read_field(context, "localPath"),
        read_field(read_field(context, "request"), "localPath"),
        read_field(read_field(context, "request"), "path")
    )
end

local function info_name(context, name)
    return first_nonempty(
        name,
        read_field(context, "prompt"),
        read_field(context, "package"),
        read_field(read_field(context, "request"), "package"),
        read_field(read_field(context, "request"), "prompt"),
        read_field(read_field(context, "request"), "packageName"),
        read_field(read_field(context, "request"), "name")
    )
end

local function prompt_value(context, prompt)
    return first_nonempty(prompt, read_field(read_field(context, "request"), "prompt"))
end

local function module_path_candidates(vmodules, identifier)
    local candidates = {}
    local clean = trim(identifier or "")
    if clean == "" then
        return candidates
    end
    local first, rest = clean:match("^([^.]+)%.(.+)$")
    for _, root in ipairs(vmodules.roots) do
        if first ~= nil and rest ~= nil then
            candidates[#candidates + 1] = join_path(root, first, rest:gsub("%.", "/"))
            candidates[#candidates + 1] = join_path(root, first, rest)
        end
        candidates[#candidates + 1] = join_path(root, clean)
    end
    return candidates
end

local function installed_path_for_identifier(vmodules, identifier)
    for _, path in ipairs(module_path_candidates(vmodules, identifier)) do
        if directory_exists(path) then
            return path
        end
    end
    return nil
end

local function status_for_item(item)
    if item == nil then
        return nil
    end
    if item.latestVersion ~= nil and trim(item.latestVersion) ~= "" and trim(item.version or "") ~= "" and trim(item.latestVersion) ~= trim(item.version) then
        return "outdated"
    end
    if item.installed then
        return "installed"
    end
    return "available"
end

local function inspect_module_path(context, vmodules, root, module_path, author, module_name)
    local entries = list_dir(context, module_path)
    local manifest_content = read_file(join_path(module_path, "v.mod"))
    local local_name = first_nonempty(field_from_vmod(manifest_content, "name"), author ~= nil and module_name ~= nil and (author .. "." .. module_name), module_name)
    local package_id = local_name
    if package_id == nil then
        return nil
    end
    local vcs = nil
    local has_git = false
    local has_hg = false
    for _, entry in ipairs(entries) do
        if entry == ".git" then
            has_git = true
            vcs = "git"
        elseif entry == ".hg" then
            has_hg = true
            if vcs == nil then
                vcs = "hg"
            end
        end
    end
    local extra = {
        moduleRoot = module_path,
        vmodulesRoot = root,
        vmodulesEnv = vmodules.raw,
        hasGit = has_git,
        hasHg = has_hg,
    }
    if vcs ~= nil then
        extra.vcs = vcs
    end
    local local_version = field_from_vmod(manifest_content, "version")
    local local_description = field_from_vmod(manifest_content, "description")
    local local_license = field_from_vmod(manifest_content, "license")
    local local_repo_url = first_nonempty(field_from_vmod(manifest_content, "homepage"), field_from_vmod(manifest_content, "repo_url"))
    local local_dependencies = field_from_vmod(manifest_content, "dependencies")
    local item = {
        name = local_name,
        packageId = package_id,
        packageType = "library",
        version = local_version,
        installed = true,
        summary = local_description,
        description = local_description,
        homepage = local_repo_url,
        repository = repository_from_url(local_repo_url),
        license = local_license,
        dependencies = local_dependencies,
        extraFields = extra,
    }
    item.status = status_for_item(item)
    return item
end

local function collect_installed_items(context, vmodules)
    local items = {}
    local seen = {}
    for _, root in ipairs(vmodules.roots) do
        for _, author in ipairs(list_dir(context, root)) do
            local author_clean = trim(author)
            if author_clean ~= "" and author_clean:sub(1, 1) ~= "." and author_clean ~= "cache" and author_clean ~= "vlib" then
                local author_path = join_path(root, author_clean)
                for _, module_name in ipairs(list_dir(context, author_path)) do
                    local module_clean = trim(module_name)
                    if module_clean ~= "" and module_clean:sub(1, 1) ~= "." then
                        local module_path = join_path(author_path, module_clean)
                        local item = inspect_module_path(context, vmodules, root, module_path, author_clean, module_clean)
                        local key = lower(trim(read_field(item, "packageId") or ""))
                        if item ~= nil and key ~= "" and not seen[key] then
                            seen[key] = true
                            items[#items + 1] = item
                        end
                    end
                end
            end
        end
    end
    table.sort(items, function(left, right)
        return tostring(left.packageId or left.name or "") < tostring(right.packageId or right.name or "")
    end)
    return items
end

local function find_installed_item(items, identifier)
    local wanted = lower(trim(identifier or ""))
    if wanted == "" then
        return nil
    end
    for _, item in ipairs(items or {}) do
        if lower(trim(read_field(item, "packageId") or read_field(item, "name") or "")) == wanted then
            return item
        end
    end
    return nil
end

local function parse_show_output(name, stdout)
    local fields = {}
    for _, line in ipairs(split_lines(stdout)) do
        local key, value = line:match("^%s*([^:]+):%s*(.-)%s*$")
        if key ~= nil then
            fields[lower(trim(key))] = trim(value)
        end
    end
    local resolved_name = first_nonempty(fields.name, name)
    if resolved_name == nil then
        return nil
    end
    local item = {
        name = resolved_name,
        packageId = resolved_name,
        packageType = "library",
        version = non_empty(fields.version),
        latestVersion = non_empty(fields.version),
        installed = parse_bool(fields.installed),
        homepage = non_empty(fields.homepage),
        repository = repository_from_url(fields.homepage),
        summary = first_nonempty(fields.description, fields.summary),
        description = first_nonempty(fields.description, fields.summary),
        extraFields = {},
    }
    if non_empty(fields.downloads) ~= nil then
        item.extraFields.downloads = fields.downloads
    end
    if next(item.extraFields) == nil then
        item.extraFields = nil
    end
    item.status = status_for_item(item)
    return item
end

local function merge_package_records(remote_item, local_item, vmodules)
    if remote_item == nil then
        if local_item ~= nil then
            local clone = shallow_copy(local_item)
            clone.extraFields = merge_tables(read_field(local_item, "extraFields"), {
                vmodulesRoot = vmodules.canonical,
                vmodulesEnv = vmodules.raw,
            })
            clone.status = status_for_item(clone)
            return clone
        end
        return nil
    end
    if local_item == nil then
        local clone = shallow_copy(remote_item)
        clone.installed = clone.installed == true or installed_path_for_identifier(vmodules, clone.packageId or clone.name) ~= nil
        clone.extraFields = merge_tables(read_field(remote_item, "extraFields"), {
            vmodulesRoot = vmodules.canonical,
            vmodulesEnv = vmodules.raw,
        })
        clone.status = status_for_item(clone)
        return clone
    end
    local merged = shallow_copy(remote_item)
    merged.name = first_nonempty(local_item.name, remote_item.name)
    merged.packageId = first_nonempty(local_item.packageId, remote_item.packageId, merged.name)
    merged.packageType = first_nonempty(local_item.packageType, remote_item.packageType, "library")
    merged.version = first_nonempty(local_item.version, remote_item.version)
    merged.latestVersion = nil
    local remote_version = trim(remote_item.version or remote_item.latestVersion or "")
    local local_version = trim(local_item.version or "")
    if remote_version ~= "" and local_version ~= "" and remote_version ~= local_version then
        merged.latestVersion = remote_version
    elseif trim(remote_item.latestVersion or "") ~= "" then
        merged.latestVersion = remote_item.latestVersion
    end
    if local_version ~= "" then
        merged.version = local_version
    end
    merged.installed = true
    merged.summary = first_nonempty(local_item.summary, remote_item.summary)
    merged.description = first_nonempty(local_item.description, remote_item.description, merged.summary)
    merged.homepage = first_nonempty(local_item.homepage, remote_item.homepage)
    merged.repository = first_nonempty(local_item.repository, remote_item.repository)
    merged.license = first_nonempty(local_item.license, remote_item.license)
    merged.dependencies = local_item.dependencies or remote_item.dependencies
    merged.extraFields = merge_tables(read_field(remote_item, "extraFields"), read_field(local_item, "extraFields"))
    merged.extraFields = merge_tables(merged.extraFields, {
        vmodulesRoot = vmodules.canonical,
        vmodulesEnv = vmodules.raw,
    })
    merged.status = status_for_item(merged)
    return merged
end

local function fetch_remote_info(context, binary, vmodules, name)
    local clean = trim(name or "")
    if clean == "" then
        return nil
    end
    local result = run_exec(context, v_command(binary, vmodules, { "show", clean }))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_show_output(clean, result.stdout)
end

local function parse_outdated_ids(stdout)
    local items = {}
    local seen = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        local lower_clean = lower(cleaned)
        if cleaned ~= "" and lower_clean ~= "outdated modules:" and lower_clean:find("modules are up to date", 1, true) == nil then
            local identifier = extract_module_id(cleaned)
            if identifier ~= nil and not seen[lower(identifier)] then
                seen[lower(identifier)] = true
                items[#items + 1] = identifier
            end
        end
    end
    return items
end

local function query_outdated_ids(context, binary, vmodules)
    local result = run_exec(context, v_command(binary, vmodules, { "outdated" }))
    if result == nil or result.success ~= true then
        return {}
    end
    return parse_outdated_ids(result.stdout)
end

local function query_info_item(context, binary, vmodules, name, installed_items)
    local local_item = find_installed_item(installed_items, package_base_id(name))
    local remote_item = fetch_remote_info(context, binary, vmodules, package_base_id(name))
    if remote_item == nil and local_item == nil then
        return nil
    end
    return merge_package_records(remote_item, local_item, vmodules)
end

local function query_search_items(context, binary, vmodules, prompt, installed_items)
    local clean = trim(prompt or "")
    if clean == "" then
        return {}
    end
    local result = run_exec(context, v_command(binary, vmodules, { "search", clean }))
    if result == nil or result.success ~= true then
        return {}
    end
    local items = {}
    local seen = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            local identifier = extract_module_id(cleaned)
            if identifier ~= nil and not seen[lower(identifier)] then
                seen[lower(identifier)] = true
                local item = query_info_item(context, binary, vmodules, identifier, installed_items)
                if item == nil then
                    item = {
                        name = identifier,
                        packageId = identifier,
                        packageType = "library",
                        installed = find_installed_item(installed_items, identifier) ~= nil,
                        status = find_installed_item(installed_items, identifier) ~= nil and "installed" or "available",
                        extraFields = {
                            vmodulesRoot = vmodules.canonical,
                            vmodulesEnv = vmodules.raw,
                        },
                    }
                end
                items[#items + 1] = item
            end
        end
    end
    return items
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
    return { "Package Manager", "V", "Wrapper" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    local vmodules = resolve_vmodules(nil, requested)
    local binary = detect_v_binary(nil)
    local outdated_lookup = {}
    if binary ~= nil then
        for _, identifier in ipairs(query_outdated_ids(nil, binary, vmodules)) do
            outdated_lookup[lower(identifier)] = true
        end
    end
    local missing = {}
    for _, pkg in ipairs(requested) do
        local action = lower(read_field(pkg, "action") or "install")
        local identifier = package_base_id(pkg)
        local installed = identifier ~= "" and installed_path_for_identifier(vmodules, identifier) ~= nil
        if action == "remove" then
            if installed then
                missing[#missing + 1] = pkg
            end
        elseif action == "update" then
            if identifier ~= "" and outdated_lookup[lower(identifier)] then
                missing[#missing + 1] = pkg
            end
        elseif not installed then
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
    local binary = detect_v_binary(context)
    if binary == nil then
        tx_failed(context, "v binary not available")
        emit_event(context, "unavailable", { reason = "v-not-installed" })
        return false
    end
    local local_path = request_local_path(context)
    if local_path ~= nil then
        return plugin.installLocal(context, local_path)
    end
    local vmodules = resolve_vmodules(context, requested)
    local installed = {}
    begin_step(context, "install vpm packages")
    for _, pkg in ipairs(requested) do
        local target = package_query(pkg)
        if target == "" then
            tx_failed(context, "missing package name")
            return false
        end
        local result = run_exec(context, v_command(binary, vmodules, { "install", target }))
        if result == nil or result.success ~= true then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "v install failed"))
            return false
        end
        local installed_items = collect_installed_items(context, vmodules)
        local item = find_installed_item(installed_items, package_base_id(pkg))
        installed[#installed + 1] = item or {
            name = package_base_id(pkg),
            packageId = package_base_id(pkg),
            packageType = "library",
            installed = true,
            status = "installed",
            extraFields = {
                vmodulesRoot = vmodules.canonical,
                vmodulesEnv = vmodules.raw,
            },
        }
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    begin_step(context, "install local vpm package")
    tx_failed(context, "vpm local installs are not supported")
    emit_event(context, "unavailable", {
        path = path,
        reason = "local-install-unsupported",
    })
    return false
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    local binary = detect_v_binary(context)
    if binary == nil then
        tx_failed(context, "v binary not available")
        emit_event(context, "unavailable", { reason = "v-not-installed" })
        return false
    end
    local vmodules = resolve_vmodules(context, requested)
    local installed_items = collect_installed_items(context, vmodules)
    local removed = {}
    begin_step(context, "remove vpm packages")
    for _, pkg in ipairs(requested) do
        local identifier = package_base_id(pkg)
        local item = find_installed_item(installed_items, identifier)
        if item ~= nil then
            local result = run_exec(context, v_command(binary, vmodules, { "remove", identifier }))
            if result == nil or result.success ~= true then
                tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "v remove failed"))
                return false
            end
            removed[#removed + 1] = item
        end
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    local binary = detect_v_binary(context)
    if binary == nil then
        tx_failed(context, "v binary not available")
        emit_event(context, "unavailable", { reason = "v-not-installed" })
        return false
    end
    local vmodules = resolve_vmodules(context, requested)
    local updated = {}
    begin_step(context, "update vpm packages")
    if #requested == 0 then
        local result = run_exec(context, v_command(binary, vmodules, { "update" }))
        if result == nil or result.success ~= true then
            tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "v update failed"))
            return false
        end
        updated = collect_installed_items(context, vmodules)
    else
        local installed_items = collect_installed_items(context, vmodules)
        for _, pkg in ipairs(requested) do
            local identifier = package_base_id(pkg)
            if find_installed_item(installed_items, identifier) ~= nil then
                local result = run_exec(context, v_command(binary, vmodules, { "update", identifier }))
                if result == nil or result.success ~= true then
                    tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "v update failed"))
                    return false
                end
                installed_items = collect_installed_items(context, vmodules)
                local item = find_installed_item(installed_items, identifier)
                if item ~= nil then
                    updated[#updated + 1] = item
                end
            end
        end
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local vmodules = resolve_vmodules(context, nil)
    local items = collect_installed_items(context, vmodules)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local binary = detect_v_binary(context)
    if binary == nil then
        log_warn(context, "v binary not available for outdated query")
        emit_event(context, "outdated", {})
        return {}
    end
    local vmodules = resolve_vmodules(context, nil)
    local installed_items = collect_installed_items(context, vmodules)
    local items = {}
    for _, identifier in ipairs(query_outdated_ids(context, binary, vmodules)) do
        local item = find_installed_item(installed_items, identifier)
        if item ~= nil then
            local clone = shallow_copy(item)
            clone.status = "outdated"
            items[#items + 1] = clone
        else
            items[#items + 1] = {
                name = identifier,
                packageId = identifier,
                packageType = "library",
                installed = true,
                status = "outdated",
                extraFields = {
                    vmodulesRoot = vmodules.canonical,
                    vmodulesEnv = vmodules.raw,
                },
            }
        end
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local clean = trim(prompt_value(context, prompt) or "")
    if clean == "" then
        emit_event(context, "searched", {})
        return {}
    end
    local binary = detect_v_binary(context)
    if binary == nil then
        log_warn(context, "v binary not available for search")
        emit_event(context, "searched", {})
        return {}
    end
    local vmodules = resolve_vmodules(context, nil)
    local installed_items = collect_installed_items(context, vmodules)
    local items = query_search_items(context, binary, vmodules, clean, installed_items)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local clean = trim(info_name(context, name) or "")
    if clean == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    local vmodules = resolve_vmodules(context, nil)
    local installed_items = collect_installed_items(context, vmodules)
    local binary = detect_v_binary(context)
    if binary == nil then
        local local_item = find_installed_item(installed_items, package_base_id(clean)) or {}
        emit_event(context, "informed", local_item)
        return local_item
    end
    local item = query_info_item(context, binary, vmodules, clean, installed_items) or {}
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, pkg)
    local identifier = package_base_id(pkg)
    if identifier == "" then
        return nil
    end
    local vmodules = resolve_vmodules(context, { pkg })
    local installed_items = collect_installed_items(context, vmodules)
    local binary = detect_v_binary(context)
    if binary == nil then
        return find_installed_item(installed_items, identifier)
    end
    return query_info_item(context, binary, vmodules, identifier, installed_items)
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
        ecosystemScopes = { "vpm", "vlang" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".vmodules" },
        },
        networkScopes = {
            { scheme = "https", host = "vpm.vlang.io" },
            { scheme = "https", host = "github.com" },
            { scheme = "https", host = "gitlab.com" },
            { scheme = "https", host = "codeberg.org" },
        },
        privilegeLevel = "user",
        osvEcosystem = "Generic",
        purlType = "generic",
    }
end

return plugin
