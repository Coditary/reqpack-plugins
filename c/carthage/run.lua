plugin = {}

local PLUGIN_ID = "carthage"
local PLUGIN_NAME = "Carthage"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "carthage"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return tostring(value or ""):lower()
end

local function non_empty(value)
    local text = trim(value)
    if text == "" then
        return nil
    end
    return text
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
    if #lines > 0 and lines[#lines] == "" then
        lines[#lines] = nil
    end
    return lines
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function is_safe_token(value)
    return tostring(value or ""):match("^[A-Za-z0-9_./:@%%+=,%-%[%]]+$") ~= nil
end

local function command_quote(value)
    local text = tostring(value or "")
    if is_safe_token(text) then
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

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil and value ~= false then
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

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        local value = non_empty(os.getenv(name))
        if value ~= nil then
            return value
        end
    end
    return nil
end

local function home_dir()
    return first_nonempty(getenv("HOME"), getenv("USERPROFILE"), "/home/test", ".")
end

local function test_fixture_root()
    return trim(getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
end

local function object_flags(object)
    local value = read_field(object, "flags")
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end

    local flags = {}
    local ok = pcall(function()
        for _, flag in ipairs(value) do
            local cleaned = trim(flag)
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

local function append_unique(list, value, seen)
    local text = trim(value)
    if text == "" or seen[text] then
        return
    end
    seen[text] = true
    list[#list + 1] = text
end

local function read_file(context, path)
    local result = run_exec(context, "cat " .. shell_quote(path))
    if result ~= nil and result.success == true then
        return result.stdout
    end

    local handle = io.open(path, "r")
    if handle ~= nil then
        local content = handle:read("*a")
        handle:close()
        return content
    end

    return nil
end

local function write_file(context, path, content)
    local handle = io.open(path, "w")
    if handle ~= nil then
        handle:write(content)
        handle:close()
        return true
    end

    local dir = parent_dir(path)
    local escaped_path = tostring(path):gsub("\\", "\\\\"):gsub('"', '\\"')
    local escaped = tostring(content or "")
        :gsub("\\", "\\\\")
        :gsub("\n", "\\n")
        :gsub('"', '\\"')
    local command = "mkdir -p " .. shell_quote(dir or ".") .. " && python3 -c \"import pathlib; pathlib.Path(\"" .. escaped_path .. "\").write_text(\"" .. escaped .. "\")\""
    local result = run_exec(context, command)
    if result ~= nil and result.success == true then
        return true
    end
    return false
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
    for _, pkg in ipairs(packages or {}) do
        collect_from(pkg)
    end
    return flags
end

local function flag_value(flags, key)
    local prefix = lower(trim(key)) .. "="
    for _, flag in ipairs(flags or {}) do
        local text = trim(flag)
        local lowered = lower(text)
        if lowered:sub(1, #prefix) == prefix then
            return trim(text:sub(#prefix + 1))
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

local function project_dir_from_context(context, packages)
    local flags = collect_raw_flags(context, packages)
    local explicit = flag_value(flags, "dir")
    if explicit ~= nil and explicit ~= "" then
        return explicit
    end

    local env_project = trim(getenv("RQP_CARTHAGE_PROJECT_DIR") or "")
    if env_project ~= "" then
        return env_project
    end

    local fixture_root = test_fixture_root()
    if fixture_root ~= "" then
        return join_path(fixture_root, "project")
    end

    return first_nonempty(getenv("PWD"), ".")
end

local function shared_home_root(context, packages)
    local flags = collect_raw_flags(context, packages)
    local explicit = flag_value(flags, "home")
    if explicit ~= nil and explicit ~= "" then
        return explicit
    end

    local env_home = trim(getenv("RQP_CARTHAGE_HOME") or "")
    if env_home ~= "" then
        return env_home
    end

    local fixture_root = test_fixture_root()
    if fixture_root ~= "" then
        return join_path(fixture_root, "home")
    end

    return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID, "home")
end

local function shared_paths(context, packages)
    local home_root = shared_home_root(context, packages)
    return {
        home = home_root,
        cache = join_path(home_root, "Library", "Caches", "org.carthage.CarthageKit"),
    }
end

local function env_prefix(paths)
    return table.concat({
        "HOME=" .. shell_quote(paths.home),
        "NO_COLOR='1'",
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
    }, " ")
end

local function append_common_carthage_flags(args, flags)
    local platform = flag_value(flags, "platform")
    if platform ~= nil and platform ~= "" then
        args[#args + 1] = "--platform"
        args[#args + 1] = platform
    end

    local supported = {
        ["use-xcframeworks"] = "--use-xcframeworks",
        ["cache-builds"] = "--cache-builds",
        ["no-use-binaries"] = "--no-use-binaries",
        ["use-submodules"] = "--use-submodules",
        ["use-netrc"] = "--use-netrc",
        ["new-resolver"] = "--new-resolver",
        ["use-ssh"] = "--use-ssh",
    }
    for key, arg in pairs(supported) do
        if has_flag(flags, key) then
            args[#args + 1] = arg
        end
    end
end

local function append_outdated_flags(args, flags)
    if has_flag(flags, "use-netrc") then
        args[#args + 1] = "--use-netrc"
    end
    if has_flag(flags, "use-ssh") then
        args[#args + 1] = "--use-ssh"
    end
end

local function build_carthage_command(context, packages, args)
    local paths = shared_paths(context, packages)
    local parts = { env_prefix(paths), REQUIRED_BINARY }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = command_quote(arg)
    end
    return table.concat(parts, " "), paths
end

local function cartfile_path(project_dir)
    return join_path(project_dir, "Cartfile")
end

local function resolved_path(project_dir)
    return join_path(project_dir, "Cartfile.resolved")
end

local function source_basename(source)
    local text = tostring(source or ""):gsub("[?#].*$", "")
    local last = text:match("([^/]+)$") or text
    last = last:gsub("%.git$", "")
    last = last:gsub("%.json$", "")
    return last
end

local function infer_name(origin, source)
    if origin == "github" then
        return (tostring(source or ""):match("([^/]+)/?$")) or tostring(source or "")
    end
    return source_basename(source)
end

local function canonical_package_id(origin, source)
    return origin .. ":" .. tostring(source or "")
end

local function cartfile_quote(value)
    return '"' .. tostring(value or ""):gsub('"', '\\"') .. '"'
end

local function build_declaration(item)
    local line = tostring(item.origin) .. " " .. cartfile_quote(item.source)
    if trim(item.requirement or "") ~= "" then
        line = line .. " " .. trim(item.requirement)
    end
    return line
end

local function strip_inline_comment(line)
    local text = tostring(line or "")
    local quoted = false
    local escaped = false
    for index = 1, #text do
        local char = text:sub(index, index)
        if escaped then
            escaped = false
        elseif char == "\\" then
            escaped = true
        elseif char == '"' then
            quoted = not quoted
        elseif char == "#" and not quoted then
            return trim(text:sub(1, index - 1))
        end
    end
    return trim(text)
end

local function parse_dependency_line(line)
    local clean = strip_inline_comment(line)
    if clean == "" then
        return nil
    end

    local origin, source, requirement = clean:match('^(%a+)%s+"([^"]+)"%s*(.-)%s*$')
    if origin ~= "github" and origin ~= "git" and origin ~= "binary" then
        return nil
    end

    requirement = trim(requirement)
    if requirement == "" then
        requirement = nil
    end

    local item = {
        origin = origin,
        source = source,
        requirement = requirement,
        name = infer_name(origin, source),
        packageId = canonical_package_id(origin, source),
        packageType = origin,
        type = "package",
    }
    item.declaration = build_declaration(item)
    return item
end

local function parse_dependency_file(content)
    local lines = split_lines(content)
    local items = {}
    for index, line in ipairs(lines) do
        local item = parse_dependency_line(line)
        if item ~= nil then
            item.lineNumber = index
            item.line = line
            items[#items + 1] = item
        end
    end
    return lines, items
end

local function requirement_from_version(version)
    local text = trim(version)
    if text == "" then
        return nil
    end
    if text:match('^".*"$') ~= nil then
        return text
    end
    if text:match('^[~><=]') ~= nil then
        return text
    end
    return '== ' .. text
end

local function is_binary_source(name)
    local text = trim(name)
    return text:match('%.json$') ~= nil
end

local function is_url_like(name)
    local text = trim(name)
    return text:match('^[A-Za-z][A-Za-z0-9+.-]*://') ~= nil
end

local function is_path_like(name)
    local text = trim(name)
    return text:match('^/') ~= nil or text:match('^%.') ~= nil
end

local function normalize_local_source(path)
    local text = trim(path)
    if text:match('^file://') ~= nil then
        return text
    end
    return 'file://' .. text
end

local function normalize_github_source(name)
    local text = trim(name)
    if text == "" then
        return nil
    end

    local owner, repo = text:match('^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$')
    if owner ~= nil and repo ~= nil then
        return owner .. "/" .. repo
    end

    owner, repo = text:match('^git@github%.com:([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)%.git$')
    if owner ~= nil and repo ~= nil then
        return owner .. "/" .. repo
    end

    owner, repo = text:match('^ssh://git@github%.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)%.git$')
    if owner ~= nil and repo ~= nil then
        return owner .. "/" .. repo
    end

    owner, repo = text:match('^[A-Za-z][A-Za-z0-9+.-]*://www%.github%.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$')
    if owner ~= nil and repo ~= nil then
        return owner .. "/" .. repo
    end

    owner, repo = text:match('^[A-Za-z][A-Za-z0-9+.-]*://github%.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$')
    if owner ~= nil and repo ~= nil then
        return owner .. "/" .. repo
    end

    owner, repo = text:match('^[A-Za-z][A-Za-z0-9+.-]*://www%.github%.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)%.git$')
    if owner ~= nil and repo ~= nil then
        return owner .. "/" .. repo
    end

    owner, repo = text:match('^[A-Za-z][A-Za-z0-9+.-]*://github%.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)%.git$')
    if owner ~= nil and repo ~= nil then
        return owner .. "/" .. repo
    end

    return nil
end

local function normalize_package(raw_package, existing)
    local pkg = raw_package
    if type(raw_package) == "string" then
        pkg = { name = raw_package }
    end

    local name = trim(read_field(pkg, "name") or read_field(pkg, "packageId") or "")
    local version = trim(read_field(pkg, "version") or "")
    if name == "" then
        return nil, "missing carthage package name"
    end

    local parsed = parse_dependency_line(name)
    if parsed ~= nil then
        return parsed
    end

    if existing ~= nil then
        for _, item in ipairs(existing) do
            if lower(item.packageId) == lower(name)
                or lower(item.name) == lower(name)
                or lower(item.source) == lower(name) then
                local resolved = shallow_copy(item)
                if version ~= "" then
                    resolved.requirement = requirement_from_version(version)
                    resolved.declaration = build_declaration(resolved)
                end
                return resolved
            end
        end
    end

    local github_source = normalize_github_source(name)

    local item = nil
    if github_source ~= nil then
        item = {
            origin = "github",
            source = github_source,
            requirement = requirement_from_version(version),
        }
    elseif is_binary_source(name) then
        item = {
            origin = "binary",
            source = name,
            requirement = requirement_from_version(version),
        }
    elseif name:match('^git@') ~= nil or name:match('%.git$') ~= nil or is_url_like(name) then
        item = {
            origin = "git",
            source = name,
            requirement = requirement_from_version(version),
        }
    end

    if item == nil then
        return nil, "unable to normalize carthage dependency: " .. name
    end

    item.name = infer_name(item.origin, item.source)
    item.packageId = canonical_package_id(item.origin, item.source)
    item.packageType = item.origin
    item.type = "package"
    item.declaration = build_declaration(item)
    return item
end

local function normalize_local_package(path)
    local local_path = trim(path)
    if local_path == "" then
        return nil, "missing local Carthage path"
    end

    local item
    if is_binary_source(local_path) then
        item = {
            origin = "binary",
            source = local_path,
        }
    elseif is_path_like(local_path) or local_path:match('^file://') ~= nil then
        item = {
            origin = "git",
            source = normalize_local_source(local_path),
        }
    else
        return nil, "unsupported local Carthage path: " .. local_path
    end

    item.name = infer_name(item.origin, item.source)
    item.packageId = canonical_package_id(item.origin, item.source)
    item.packageType = item.origin
    item.type = "package"
    item.declaration = build_declaration(item)
    return item
end

local function dependency_matches(item, target)
    if item == nil or target == nil then
        return false
    end

    local item_id = lower(item.packageId or "")
    local target_id = lower(target.packageId or "")
    if item_id ~= "" and target_id ~= "" and item_id == target_id then
        return true
    end

    local item_source = lower(item.source or "")
    local target_source = lower(target.source or "")
    if item_source ~= "" and target_source ~= "" and item_source == target_source then
        return true
    end

    local item_name = lower(item.name or "")
    local target_name = lower(target.name or "")
    return item_name ~= "" and target_name ~= "" and item_name == target_name
end

local function serialize_lines(lines)
    if #lines == 0 then
        return ""
    end
    return table.concat(lines, "\n") .. "\n"
end

local function require_cartfile(context, project_dir)
    local content = read_file(context, cartfile_path(project_dir))
    if content == nil then
        return nil, "Cartfile not found in project directory: " .. tostring(project_dir)
    end
    return content
end

local function read_dependency_state(context, project_dir)
    local cartfile = read_file(context, cartfile_path(project_dir)) or ""
    local resolved = read_file(context, resolved_path(project_dir)) or ""
    local cartfile_lines, declared = parse_dependency_file(cartfile)
    local _, resolved_items = parse_dependency_file(resolved)
    return {
        cartfilePath = cartfile_path(project_dir),
        resolvedPath = resolved_path(project_dir),
        cartfileLines = cartfile_lines,
        declared = declared,
        resolved = resolved_items,
    }
end

local function rewrite_cartfile(context, project_dir, updater)
    local content, err = require_cartfile(context, project_dir)
    if content == nil then
        return false, err
    end

    local lines, items = parse_dependency_file(content)
    local new_lines, update_err = updater(lines, items)
    if new_lines == nil then
        return false, update_err or "failed to update Cartfile"
    end

    local ok = write_file(context, cartfile_path(project_dir), serialize_lines(new_lines))
    if not ok then
        return false, "failed to write Cartfile"
    end
    return true
end

local function upsert_dependencies(context, project_dir, targets)
    return rewrite_cartfile(context, project_dir, function(lines, items)
        local new_lines = shallow_copy(lines)
        local inserted = {}

        for _, target in ipairs(targets) do
            local replaced = false
            for _, item in ipairs(items) do
                if dependency_matches(item, target) then
                    new_lines[item.lineNumber] = target.declaration
                    replaced = true
                    break
                end
            end
            if not replaced then
                inserted[#inserted + 1] = target.declaration
            end
        end

        if #inserted > 0 then
            if #new_lines > 0 and trim(new_lines[#new_lines]) ~= "" then
                new_lines[#new_lines + 1] = ""
            end
            for _, line in ipairs(inserted) do
                new_lines[#new_lines + 1] = line
            end
        end

        return new_lines
    end)
end

local function remove_dependencies(context, project_dir, targets)
    return rewrite_cartfile(context, project_dir, function(lines, items)
        local remove_lines = {}
        for _, item in ipairs(items) do
            for _, target in ipairs(targets) do
                if dependency_matches(item, target) then
                    remove_lines[item.lineNumber] = true
                    break
                end
            end
        end

        local new_lines = {}
        for index, line in ipairs(lines) do
            if not remove_lines[index] then
                new_lines[#new_lines + 1] = line
            end
        end
        return new_lines
    end)
end

local function to_package_info(context, project_dir, declared_item, resolved_item, status_override, latest_version, extra)
    local base = resolved_item or declared_item or {}
    local paths = shared_paths(context, {})
    return {
        name = base.name,
        packageId = base.packageId,
        version = resolved_item and resolved_item.requirement or nil,
        latestVersion = latest_version,
        installed = resolved_item ~= nil,
        status = status_override or (resolved_item ~= nil and "installed" or "declared"),
        summary = "Carthage " .. tostring(base.origin or "dependency") .. " dependency",
        sourceUrl = base.source,
        packageType = base.origin,
        type = "package",
        extraFields = merge_tables(extra, {
            requirement = declared_item and declared_item.requirement or nil,
            source = base.source,
            origin = base.origin,
            projectDir = project_dir,
            cartfile = cartfile_path(project_dir),
            resolvedFile = resolved_path(project_dir),
            cacheRoot = paths.cache,
        }),
    }
end

local function list_from_state(context, project_dir)
    local state = read_dependency_state(context, project_dir)
    local resolved_by_id = {}
    for _, item in ipairs(state.resolved) do
        resolved_by_id[lower(item.packageId)] = item
    end

    local results = {}
    local seen = {}
    for _, item in ipairs(state.declared) do
        local key = lower(item.packageId)
        results[#results + 1] = to_package_info(context, project_dir, item, resolved_by_id[key])
        seen[key] = true
    end

    for _, item in ipairs(state.resolved) do
        local key = lower(item.packageId)
        if not seen[key] then
            results[#results + 1] = to_package_info(context, project_dir, nil, item)
        end
    end

    return results, state
end

local function find_item(items, query)
    local needle = lower(trim(query))
    if needle == "" then
        return nil
    end
    for _, item in ipairs(items or {}) do
        if lower(item.name or "") == needle
            or lower(item.packageId or "") == needle
            or lower(read_field(item, "sourceUrl") or "") == needle
            or lower(read_field(read_field(item, "extraFields"), "source") or "") == needle then
            return item
        end
    end
    return nil
end

local function parse_outdated_results(context, project_dir, raw)
    local current = list_from_state(context, project_dir)
    local results = {}
    for _, line in ipairs(split_lines(raw)) do
        local name, current_version, applicable, latest = line:match('^warning:%s+(.+)%s+is out of date%s+%((.-)%s+%-%>%s+(.-)%)%s+%(Latest:%s*(.-)%)%s*$')
        if name ~= nil then
            local existing = find_item(current, name)
            local declared = nil
            local resolved = nil
            if existing ~= nil then
                declared = {
                    name = existing.name,
                    packageId = existing.packageId,
                    origin = existing.packageType,
                    source = read_field(read_field(existing, "extraFields"), "source"),
                    requirement = read_field(read_field(existing, "extraFields"), "requirement"),
                }
                resolved = shallow_copy(declared)
                resolved.requirement = current_version
            else
                declared = {
                    name = name,
                    packageId = name,
                    origin = "github",
                    source = name,
                    requirement = nil,
                }
                resolved = shallow_copy(declared)
                resolved.requirement = current_version
            end
            results[#results + 1] = to_package_info(context, project_dir, declared, resolved, "outdated", applicable, {
                applicableVersion = applicable,
                latestAvailableVersion = latest,
            })
        end
    end
    return results
end

local function synthetic_info(context, project_dir, item)
    return to_package_info(context, project_dir, item, nil, "declared", nil, nil)
end

local function find_item_for_query(items, query)
    local direct = find_item(items, query)
    if direct ~= nil then
        return direct
    end

    local normalized = normalize_package({ name = query }, nil)
    if normalized == nil then
        return nil
    end

    return find_item(items, normalized.packageId)
        or find_item(items, normalized.name)
        or find_item(items, normalized.source)
end

local function require_binary(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true
    end
    return false, "carthage binary not found"
end

local function run_update_command(context, packages)
    local flags = collect_raw_flags(context, packages)
    local args = { "update", "--project-directory=" .. project_dir_from_context(context, packages) }
    append_common_carthage_flags(args, flags)
    local command = build_carthage_command(context, packages, args)
    return run_exec(context, command)
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
    return { "ios", "objc", "apple", "carthage" }
end

function plugin.getMissingPackages(packages)
    if not command_exists(nil, REQUIRED_BINARY) then
        return { REQUIRED_BINARY }
    end

    local project_dir = project_dir_from_context(nil, packages or {})
    local items = list_from_state(nil, project_dir)
    local missing = {}
    for _, raw_pkg in ipairs(packages or {}) do
        local action = lower(read_field(raw_pkg, "action") or "")
        local match = find_item(items, read_field(raw_pkg, "name") or read_field(raw_pkg, "packageId") or "")
        if action == "remove" then
            if match ~= nil then
                missing[#missing + 1] = raw_pkg
            end
        elseif action == "update" then
            if match ~= nil then
                missing[#missing + 1] = raw_pkg
            end
        else
            if match == nil then
                missing[#missing + 1] = raw_pkg
            else
                local wanted = requirement_from_version(read_field(raw_pkg, "version") or "")
                local current_req = read_field(read_field(match, "extraFields"), "requirement")
                if wanted ~= nil and wanted ~= trim(current_req or "") then
                    missing[#missing + 1] = raw_pkg
                end
            end
        end
    end
    return missing
end

function plugin.install(context, packages)
    local targets = packages or {}
    begin_step(context, "install Carthage dependencies")

    local ok, err = require_binary(context)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local project_dir = project_dir_from_context(context, targets)
    local existing_content, cart_err = require_cartfile(context, project_dir)
    if existing_content == nil then
        tx_failed(context, cart_err)
        return false
    end

    local _, existing = parse_dependency_file(existing_content)
    local normalized = {}
    for _, raw_pkg in ipairs(targets) do
        local item, item_err = normalize_package(raw_pkg, existing)
        if item == nil then
            tx_failed(context, item_err)
            return false
        end
        normalized[#normalized + 1] = item
    end

    if #normalized > 0 then
        local updated, update_err = upsert_dependencies(context, project_dir, normalized)
        if not updated then
            tx_failed(context, update_err)
            return false
        end
    end

    local result = run_update_command(context, targets)
    if result == nil or result.success ~= true then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "carthage update failed"))
        return false
    end

    emit_event(context, "installed", normalized)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.installLocal(context, path)
    begin_step(context, "install local Carthage dependency")

    local ok, err = require_binary(context)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local project_dir = project_dir_from_context(context, {})
    local content, cart_err = require_cartfile(context, project_dir)
    if content == nil then
        tx_failed(context, cart_err)
        return false
    end

    local local_path = trim(path)
    if local_path == "" and context ~= nil then
        local_path = trim(read_field(context, "path") or read_field(read_field(context, "request"), "path") or "")
    end

    local item, item_err = normalize_local_package(local_path)
    if item == nil then
        tx_failed(context, item_err)
        return false
    end

    local _, existing = parse_dependency_file(content)
    local resolved = nil
    for _, entry in ipairs(existing) do
        if dependency_matches(entry, item) then
            resolved = entry
            break
        end
    end
    if resolved ~= nil then
        item.name = resolved.name
    end

    local updated, update_err = upsert_dependencies(context, project_dir, { item })
    if not updated then
        tx_failed(context, update_err)
        return false
    end

    local result = run_update_command(context, {})
    if result == nil or result.success ~= true then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "carthage update failed"))
        return false
    end

    emit_event(context, "installed", { item })
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.remove(context, packages)
    local targets = packages or {}
    begin_step(context, "remove Carthage dependencies")

    local ok, err = require_binary(context)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local project_dir = project_dir_from_context(context, targets)
    local content, cart_err = require_cartfile(context, project_dir)
    if content == nil then
        tx_failed(context, cart_err)
        return false
    end

    local _, existing = parse_dependency_file(content)
    local normalized = {}
    for _, raw_pkg in ipairs(targets) do
        local item, item_err = normalize_package(raw_pkg, existing)
        if item == nil then
            tx_failed(context, item_err)
            return false
        end
        normalized[#normalized + 1] = item
    end

    if #normalized > 0 then
        local removed, remove_err = remove_dependencies(context, project_dir, normalized)
        if not removed then
            tx_failed(context, remove_err)
            return false
        end
    end

    local result = run_update_command(context, targets)
    if result == nil or result.success ~= true then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "carthage update failed"))
        return false
    end

    emit_event(context, "deleted", normalized)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.update(context, packages)
    local targets = packages or {}
    begin_step(context, "update Carthage dependencies")

    local ok, err = require_binary(context)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local project_dir = project_dir_from_context(context, targets)
    local content, cart_err = require_cartfile(context, project_dir)
    if content == nil then
        tx_failed(context, cart_err)
        return false
    end

    local _, existing = parse_dependency_file(content)
    local normalized = {}
    for _, raw_pkg in ipairs(targets) do
        local item, item_err = normalize_package(raw_pkg, existing)
        if item == nil then
            tx_failed(context, item_err)
            return false
        end
        normalized[#normalized + 1] = item
    end

    if #normalized > 0 then
        local updated, update_err = upsert_dependencies(context, project_dir, normalized)
        if not updated then
            tx_failed(context, update_err)
            return false
        end
    end

    local result = run_update_command(context, targets)
    if result == nil or result.success ~= true then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "carthage update failed"))
        return false
    end

    emit_event(context, "updated", #normalized > 0 and normalized or targets)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.list(context)
    local project_dir = project_dir_from_context(context, {})
    local items = list_from_state(context, project_dir)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local ok, err = require_binary(context)
    if not ok then
        log_warn(context, err)
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end

    local project_dir = project_dir_from_context(context, {})
    local flags = collect_raw_flags(context, {})
    local args = { "outdated", "--project-directory=" .. project_dir, "--xcode-warnings" }
    append_outdated_flags(args, flags)
    local command = build_carthage_command(context, {}, args)
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        log_warn(context, first_nonempty(result and result.stderr, result and result.stdout, "carthage outdated failed"))
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end

    local items = parse_outdated_results(context, project_dir, result.stdout)
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

    local project_dir = project_dir_from_context(context, {})
    local items = list_from_state(context, project_dir)
    local results = {}
    local needle = lower(cleaned_prompt)
    for _, item in ipairs(items) do
        local source = lower(read_field(read_field(item, "extraFields"), "source") or "")
        if lower(item.name or ""):find(needle, 1, true) ~= nil
            or lower(item.packageId or ""):find(needle, 1, true) ~= nil
            or source:find(needle, 1, true) ~= nil then
            results[#results + 1] = item
        end
    end

    if #results == 0 then
        local matched = find_item_for_query(items, cleaned_prompt)
        if matched ~= nil then
            results[#results + 1] = matched
        end
    end

    if #results == 0 then
        local normalized = normalize_package({ name = cleaned_prompt }, nil)
        if normalized ~= nil then
            results[#results + 1] = synthetic_info(context, project_dir, normalized)
        end
    end

    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local cleaned_name = trim(name)
    if cleaned_name == "" and context ~= nil then
        cleaned_name = trim(read_field(context, "package") or read_field(read_field(context, "request"), "package") or context.prompt)
    end
    if cleaned_name == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local project_dir = project_dir_from_context(context, {})
    local items = list_from_state(context, project_dir)
    local item = find_item_for_query(items, cleaned_name)
    if item ~= nil then
        emit_event(context, "informed", item)
        return item
    end

    local normalized = normalize_package({ name = cleaned_name }, nil)
    if normalized ~= nil then
        local synthetic = synthetic_info(context, project_dir, normalized)
        emit_event(context, "informed", synthetic)
        return synthetic
    end

    local empty = {}
    emit_event(context, "informed", empty)
    return empty
end

function plugin.resolvePackage(context, package)
    local project_dir = project_dir_from_context(context, type(package) == "table" and { package } or {})
    local items = list_from_state(context, project_dir)
    local normalized, err = normalize_package(package, read_dependency_state(context, project_dir).declared)
    if normalized == nil then
        return nil, err
    end

    local current = find_item(items, normalized.packageId) or find_item(items, normalized.name)
    if current ~= nil then
        if trim(normalized.requirement or "") ~= "" then
            current.extraFields = merge_tables(current.extraFields, { requirement = normalized.requirement })
        end
        return current
    end

    return synthetic_info(context, project_dir, normalized)
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
        ecosystemScopes = { "carthage", "ios", "objc", "apple" },
        writeScopes = {
            "user-home-subpath:.cache/reqpack/carthage",
            "project-relative:Cartfile",
            "project-relative:Cartfile.resolved",
            "project-relative:Carthage",
            "project-relative:.gitmodules",
            "project-relative:.git/config",
        },
        networkScopes = {
            { scheme = "https" },
            { scheme = "http" },
            { scheme = "ssh" },
            { scheme = "git" },
            { scheme = "file" },
        },
        privilegeLevel = "user",
        purlType = "generic",
        versionCaseInsensitive = false,
    }
end

return plugin
