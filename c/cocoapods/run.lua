plugin = {}

local PLUGIN_ID = "cocoapods"
local PLUGIN_NAME = "CocoaPods"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "pod"
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
        if value ~= JSON_NULL and value ~= nil and value ~= false then
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

local function write_file(path, content)
    local dir = parent_dir(path)
    if dir ~= nil then
        ensure_directory(dir)
    end
    local handle = io.open(path, "w")
    if handle ~= nil then
        handle:write(content)
        handle:close()
        return true
    end

    local escaped_path = tostring(path):gsub("\\", "\\\\"):gsub('"', '\\"')
    local escaped = tostring(content or "")
        :gsub("\\", "\\\\")
        :gsub("\n", "\\n")
        :gsub("\"", "\\\"")
    local command = "mkdir -p " .. shell_quote(dir or ".") .. " && python3 -c \"import pathlib; pathlib.Path(\"" .. escaped_path .. "\").write_text(\"" .. escaped .. "\")\""
    local result = run_exec(nil, command)
    return result ~= nil and result.success == true
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
    if text == "" then
        return
    end
    if seen[text] then
        return
    end
    seen[text] = true
    list[#list + 1] = text
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
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #prefix) == prefix then
            return trim(cleaned:sub(#prefix + 1))
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

    local env_project = trim(getenv("RQP_COCOAPODS_PROJECT_DIR") or "")
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
    local env_home = trim(getenv("RQP_COCOAPODS_HOME") or "")
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
        cp_home = join_path(home_root, ".cocoapods"),
        cache = join_path(home_root, "Library", "Caches", "CocoaPods"),
    }
end

local function env_prefix(paths)
    return table.concat({
        "HOME=" .. shell_quote(paths.home),
        "CP_HOME_DIR=" .. shell_quote(paths.cp_home),
        "COCOAPODS_DISABLE_STATS='true'",
        "COCOAPODS_SKIP_UPDATE_MESSAGE='true'",
        "NO_COLOR='1'",
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
    }, " ")
end

local function build_pod_command(context, packages, args)
    local paths = shared_paths(context, packages)
    local parts = { env_prefix(paths), REQUIRED_BINARY }
    for _, arg in ipairs(args or {}) do
        parts[#parts + 1] = command_quote(arg)
    end
    return table.concat(parts, " "), paths
end

local function codepoint_to_utf8(codepoint)
    if codepoint <= 0x7F then
        return string.char(codepoint)
    end
    if codepoint <= 0x7FF then
        return string.char(
            0xC0 + math.floor(codepoint / 0x40),
            0x80 + (codepoint % 0x40)
        )
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
                decode_error("expected ':' after key")
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

    local value = parse_value()
    skip_whitespace()
    if index <= length then
        decode_error("unexpected trailing content")
    end
    return value
end

local function decode_json(raw)
    local ok, value = pcall(decode_json_internal, raw)
    if not ok then
        return nil, value
    end
    return value, nil
end

local function escape_pattern(value)
    return tostring(value or ""):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

local function root_name(value)
    local name = trim(value)
    return name:match("^([^/]+)") or name
end

local function sort_by_name(items)
    table.sort(items, function(left, right)
        return lower(read_field(left, "name")) < lower(read_field(right, "name"))
    end)
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageName") or read_field(pkg, "packageId"))
end

local function package_version(pkg)
    return trim(read_field(pkg, "version"))
end

local function normalize_package(pkg)
    local name = package_name(pkg)
    if name == "" then
        return nil, "missing pod name"
    end
    return {
        name = name,
        version = package_version(pkg),
        flags = object_flags(pkg),
        raw = pkg,
    }, nil
end

local function podfile_path(project_dir)
    return join_path(project_dir, "Podfile")
end

local function lockfile_path(project_dir)
    return join_path(project_dir, "Podfile.lock")
end

local function project_has_podfile(project_dir)
    return read_file(nil, podfile_path(project_dir)) ~= nil
end

local function require_project_podfile(context, packages)
    local project_dir = project_dir_from_context(context, packages or {})
    if not project_has_podfile(project_dir) then
        return nil, "Podfile not found in project directory: " .. tostring(project_dir)
    end
    return project_dir, nil
end

local function declaration_for_package(pkg)
    if pkg.version ~= "" then
        return "  pod '" .. pkg.name .. "', '" .. pkg.version .. "'"
    end
    return "  pod '" .. pkg.name .. "'"
end

local function declaration_for_local(name, local_path, use_podspec)
    local key = use_podspec and ":podspec" or ":path"
    return "  pod '" .. name .. "', " .. key .. " => '" .. tostring(local_path):gsub("'", "\\'") .. "'"
end

local function find_target_insert_index(lines)
    local target_start = nil
    local depth = 0
    for index, line in ipairs(lines) do
        if target_start == nil and (line:match("^%s*target%s+['\"].+['\"]%s+do%s*$") or line:match("^%s*abstract_target%s+['\"].+['\"]%s+do%s*$")) then
            target_start = index
            depth = 1
        elseif target_start ~= nil then
            if line:match("%f[%a]do%s*$") or line:match("%f[%a]do%s+|.*|%s*$") then
                depth = depth + 1
            end
            if line:match("^%s*end%s*$") then
                depth = depth - 1
                if depth == 0 then
                    return index
                end
            end
        end
    end
    return #lines + 1
end

local function replace_direct_pod_lines(content, removed_names, inserted_lines)
    local lines = split_lines(content)
    if #lines == 0 then
        lines = { "" }
    end

    local filtered = {}
    for _, line in ipairs(lines) do
        local matched = false
        for name, _ in pairs(removed_names or {}) do
            if line:match("^%s*pod%s+['\"]" .. escape_pattern(name) .. "['\"]%s*[,)]?.*$") then
                matched = true
                break
            end
        end
        if not matched then
            filtered[#filtered + 1] = line
        end
    end

    local insert_index = find_target_insert_index(filtered)
    local updated = {}
    for index = 1, #filtered do
        if index == insert_index then
            for _, line in ipairs(inserted_lines or {}) do
                updated[#updated + 1] = line
            end
        end
        updated[#updated + 1] = filtered[index]
    end
    if insert_index == (#filtered + 1) then
        for _, line in ipairs(inserted_lines or {}) do
            updated[#updated + 1] = line
        end
    end

    local joined = table.concat(updated, "\n")
    if joined ~= "" and joined:sub(-1) ~= "\n" then
        joined = joined .. "\n"
    end
    return joined
end

local function write_updated_podfile(project_dir, removed_names, inserted_lines)
    local path = podfile_path(project_dir)
    local content = read_file(nil, path)
    if content == nil then
        return false, "Podfile not found in project directory"
    end
    local updated = replace_direct_pod_lines(content, removed_names, inserted_lines)
    if not write_file(path, updated) then
        return false, "failed to write Podfile"
    end
    return true, nil
end

local function parse_lockfile(content, project_dir)
    local items = {}
    local dependencies = {}
    local repo_by_pod = {}
    local section = nil
    local current_repo = nil

    for _, line in ipairs(split_lines(content)) do
        local header = line:match("^([A-Z][A-Z%s]+):$")
        if header ~= nil then
            section = header
            current_repo = nil
        elseif section == "PODS" then
            local name, version = line:match("^  %- ([^ ]+) %(([^)]+)%)")
            if name ~= nil then
                items[#items + 1] = {
                    name = name,
                    packageId = name,
                    version = version,
                    latestVersion = version,
                    packageType = "pod",
                    type = "package",
                    extraFields = {
                        rootName = root_name(name),
                        projectDir = project_dir,
                        lockfile = lockfile_path(project_dir),
                    },
                }
            end
        elseif section == "DEPENDENCIES" then
            local value = line:match("^  %- (.+)$")
            if value ~= nil then
                local name = trim(value:gsub(" %(.*$", ""))
                dependencies[name] = value
            end
        elseif section == "SPEC REPOS" then
            local repo = line:match("^  ([^:]+):$")
            if repo ~= nil then
                current_repo = trim(repo)
            elseif current_repo ~= nil then
                local pod_name = line:match("^    %- (.+)$")
                if pod_name ~= nil then
                    repo_by_pod[trim(pod_name)] = current_repo
                end
            end
        end
    end

    for _, item in ipairs(items) do
        local exact_constraint = dependencies[item.name]
        local root_constraint = dependencies[root_name(item.name)]
        local root_repo = repo_by_pod[item.name] or repo_by_pod[root_name(item.name)]
        item.extraFields = merge_tables(item.extraFields, {
            directDependency = exact_constraint ~= nil or root_constraint ~= nil,
            requestedConstraint = exact_constraint or root_constraint,
            specRepo = root_repo,
        })
    end

    sort_by_name(items)
    return items
end

local function list_from_lockfile(project_dir)
    local content = read_file(nil, lockfile_path(project_dir))
    if content == nil then
        return {}
    end
    return parse_lockfile(content, project_dir)
end

local function exact_or_first(items, name)
    local wanted = lower(trim(name))
    local first = nil
    for _, item in ipairs(items or {}) do
        local item_name = lower(read_field(item, "name") or read_field(item, "packageId"))
        if first == nil then
            first = item
        end
        if item_name == wanted then
            return item
        end
    end
    return first
end

local function parse_outdated_results(raw, project_dir)
    local items = {}
    for _, line in ipairs(split_lines(raw)) do
        local name, from_version, matching_version, latest_version = line:match("^%- ([^ ]+) ([^ ]+) %-%> ([^ ]+) %(latest version ([^)]+)%)$")
        if name ~= nil then
            items[#items + 1] = {
                name = name,
                packageId = name,
                version = from_version,
                latestVersion = latest_version,
                packageType = "pod",
                type = "package",
                extraFields = {
                    matchingVersion = matching_version,
                    projectDir = project_dir,
                },
            }
        end
    end
    sort_by_name(items)
    return items
end

local function parse_search_results(raw)
    local items = {}
    local current = nil

    local function finish_current()
        if current == nil then
            return
        end
        current.extraFields = merge_tables(current.extraFields, {
            versions = current.versions,
            subspecs = (#current.subspecs > 0) and table.concat(current.subspecs, ", ") or nil,
            source = current.source,
            installSnippet = current.installSnippet,
        })
        current.versions = nil
        current.subspecs = nil
        current.source = nil
        current.installSnippet = nil
        items[#items + 1] = current
        current = nil
    end

    for _, raw_line in ipairs(split_lines(raw)) do
        local line = raw_line:gsub("\r", "")
        local name, version = line:match("^%s*%-%>%s+(.+)%s+%(([^)]+)%)%s*$")
        if name ~= nil then
            finish_current()
            current = {
                name = trim(name),
                packageId = trim(name),
                version = trim(version),
                latestVersion = trim(version),
                packageType = "pod",
                type = "package",
                extraFields = {},
                subspecs = {},
            }
        elseif current ~= nil then
            local homepage = line:match("^%s*%- Homepage:%s*(.+)$")
            local source = line:match("^%s*%- Source:%s*(.+)$")
            local versions = line:match("^%s*%- Versions:%s*(.+)$")
            local install = line:match("^%s*pod%s+.+$")
            local subspec = line:match("^%s*%- ([^ ]+/[^ ]+) %(([^)]+)%)$")
            local summary = trim(line)

            if homepage ~= nil then
                current.homepage = trim(homepage)
            elseif source ~= nil then
                current.source = trim(source)
            elseif versions ~= nil then
                current.versions = trim(versions)
            elseif install ~= nil then
                current.installSnippet = trim(install)
            elseif subspec ~= nil then
                current.subspecs[#current.subspecs + 1] = trim(subspec)
            elseif summary ~= "" and current.description == nil and not summary:match("^%- Subspecs:") then
                current.description = summary
            end
        end
    end
    finish_current()
    sort_by_name(items)
    return items
end

local function authors_text(value)
    local kind = type(value)
    if kind == "string" then
        return non_empty(value)
    end
    if kind ~= "table" then
        return nil
    end

    local items = {}
    local seen = {}
    for key, item in pairs(value) do
        if type(key) == "number" then
            append_unique(items, item, seen)
        else
            append_unique(items, key, seen)
            append_unique(items, item, seen)
        end
    end
    if #items == 0 then
        return nil
    end
    return table.concat(items, ", ")
end

local function license_text(value)
    local kind = type(value)
    if kind == "string" then
        return non_empty(value)
    end
    if kind ~= "table" then
        return nil
    end

    local license_type = non_empty(read_field(value, "type"))
    if license_type ~= nil then
        return license_type
    end
    local items = {}
    for _, item in ipairs(value) do
        append_unique(items, item, {})
    end
    if #items == 0 then
        return nil
    end
    return table.concat(items, ", ")
end

local function source_text(value)
    if type(value) == "string" then
        return non_empty(value)
    end
    if type(value) ~= "table" then
        return nil
    end
    local source = read_field(value, "git") or read_field(value, "http") or read_field(value, "svn")
    return non_empty(source)
end

local function platforms_text(value)
    if type(value) ~= "table" then
        return nil
    end
    local items = {}
    local seen = {}
    for key, item in pairs(value) do
        append_unique(items, key .. "=" .. tostring(item), seen)
    end
    if #items == 0 then
        return nil
    end
    table.sort(items)
    return table.concat(items, ", ")
end

local function dependency_names(value)
    if type(value) ~= "table" then
        return nil
    end
    local items = {}
    local seen = {}
    for key, _ in pairs(value) do
        append_unique(items, key, seen)
    end
    if #items == 0 then
        return nil
    end
    table.sort(items)
    return table.concat(items, ", ")
end

local function item_from_spec(spec, existing)
    if type(spec) ~= "table" then
        return existing or {}
    end

    local name = non_empty(read_field(spec, "name")) or non_empty(existing and existing.name)
    local latest_version = non_empty(read_field(spec, "version")) or non_empty(existing and existing.latestVersion)
    local installed_version = non_empty(existing and existing.version)
    local summary = non_empty(read_field(spec, "summary"))
    local description = non_empty(read_field(spec, "description")) or summary
    local item = {
        name = name,
        packageId = name,
        version = installed_version or latest_version,
        latestVersion = latest_version,
        description = description,
        homepage = non_empty(read_field(spec, "homepage")) or non_empty(existing and existing.homepage),
        authors = authors_text(read_field(spec, "authors")) or non_empty(existing and existing.authors),
        license = license_text(read_field(spec, "license")) or non_empty(existing and existing.license),
        packageType = "pod",
        type = "package",
        extraFields = merge_tables(existing and existing.extraFields, {
            summary = summary,
            source = source_text(read_field(spec, "source")),
            platforms = platforms_text(read_field(spec, "platforms")),
            swiftVersions = type(read_field(spec, "swift_versions")) == "table" and table.concat(read_field(spec, "swift_versions"), ", ") or nil,
            moduleName = non_empty(read_field(spec, "module_name")),
            dependencies = dependency_names(read_field(spec, "dependencies")),
        }),
    }
    return item
end

local function first_output_line(raw)
    for _, line in ipairs(split_lines(raw)) do
        local text = trim(line)
        if text ~= "" then
            return text
        end
    end
    return nil
end

local function load_spec_json(context, packages, spec_path)
    local command = build_pod_command(context, packages, { "ipc", "spec", spec_path, "--no-ansi" })
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "pod ipc spec failed")
    end
    return decode_json(result.stdout)
end

local function remote_spec_for_name(context, packages, name)
    local which_command = build_pod_command(context, packages, { "spec", "which", name, "--no-ansi" })
    local which_result = run_exec(context, which_command)
    if which_result == nil or which_result.success ~= true then
        return nil, first_nonempty(which_result and which_result.stderr, which_result and which_result.stdout, "pod spec which failed")
    end

    local path = first_output_line(which_result.stdout)
    if path == nil then
        return nil, "pod spec which returned no path"
    end

    return load_spec_json(context, packages, path)
end

local function resolve_local_spec_path(context, packages, local_path)
    local cleaned = trim(local_path)
    if cleaned == "" then
        return nil, "missing local path"
    end
    if cleaned:match("%.podspec$") or cleaned:match("%.podspec%.json$") then
        return cleaned, cleaned:match("%.podspec") ~= nil
    end

    local command = "ls -1A " .. shell_quote(cleaned)
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to inspect local path")
    end

    local matches = {}
    for _, line in ipairs(split_lines(result.stdout)) do
        local entry = trim(line)
        if entry:match("%.podspec$") or entry:match("%.podspec%.json$") then
            matches[#matches + 1] = join_path(cleaned, entry)
        end
    end
    if #matches == 1 then
        return matches[1], false
    end
    if #matches == 0 then
        return nil, "directory contains no podspec"
    end
    return nil, "directory contains multiple podspec files"
end

local function local_spec_info(context, local_path)
    local spec_path, err = resolve_local_spec_path(context, {}, local_path)
    if spec_path == nil then
        return nil, err
    end
    local spec, decode_err = load_spec_json(context, {}, spec_path)
    if spec == nil then
        return nil, decode_err
    end
    local name = non_empty(read_field(spec, "name"))
    if name == nil then
        return nil, "local podspec missing name"
    end
    return {
        name = name,
        specPath = spec_path,
        usePodspec = trim(local_path):match("%.podspec") ~= nil,
    }, nil
end

local function require_binary(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true
    end
    emit_event(context, "unavailable", { reason = "cocoapods-not-installed" })
    return false, REQUIRED_BINARY .. " binary not available"
end

local function install_command_args(context, packages)
    local project_dir = project_dir_from_context(context, packages)
    local flags = collect_raw_flags(context, packages)
    local args = { "install", "--project-directory=" .. project_dir, "--no-ansi" }
    if has_flag(flags, "repo-update") then
        args[#args + 1] = "--repo-update"
    end
    if has_flag(flags, "clean-install") then
        args[#args + 1] = "--clean-install"
    end
    if has_flag(flags, "deployment") then
        args[#args + 1] = "--deployment"
    end
    return args
end

local function update_command_args(context, packages)
    local project_dir = project_dir_from_context(context, packages)
    local flags = collect_raw_flags(context, packages)
    local args = { "update" }
    for _, pkg in ipairs(packages or {}) do
        local name = package_name(pkg)
        if name ~= "" then
            args[#args + 1] = name
        end
    end
    args[#args + 1] = "--project-directory=" .. project_dir
    args[#args + 1] = "--no-ansi"
    if has_flag(flags, "repo-update") then
        args[#args + 1] = "--repo-update"
    else
        args[#args + 1] = "--no-repo-update"
    end
    if has_flag(flags, "clean-install") then
        args[#args + 1] = "--clean-install"
    end
    local sources = flag_value(flags, "sources")
    if sources ~= nil and sources ~= "" then
        args[#args + 1] = "--sources=" .. sources
    end
    local exclude_pods = flag_value(flags, "exclude-pods")
    if exclude_pods ~= nil and exclude_pods ~= "" then
        args[#args + 1] = "--exclude-pods=" .. exclude_pods
    end
    return args
end

local function outdated_command_args(context)
    local project_dir = project_dir_from_context(context, {})
    local flags = collect_raw_flags(context, {})
    local args = { "outdated", "--project-directory=" .. project_dir, "--no-ansi" }
    if has_flag(flags, "repo-update") then
        args[#args + 1] = "--repo-update"
    else
        args[#args + 1] = "--no-repo-update"
    end
    if has_flag(flags, "ignore-prerelease") then
        args[#args + 1] = "--ignore-prerelease"
    end
    return args
end

local function search_command_args(context, prompt)
    local cleaned_prompt = trim(prompt)
    local flags = collect_raw_flags(context, {})
    local args = { "search", cleaned_prompt }
    if has_flag(flags, "full") then
        -- default CocoaPods search already covers metadata.
    else
        args[#args + 1] = "--simple"
    end
    if has_flag(flags, "stats") then
        args[#args + 1] = "--stats"
    end
    for _, platform in ipairs({ "ios", "osx", "watchos", "visionos", "tvos" }) do
        if has_flag(flags, platform) then
            args[#args + 1] = "--" .. platform
        end
    end
    args[#args + 1] = "--no-pager"
    args[#args + 1] = "--no-ansi"
    return args
end

function plugin.getName()
    return PLUGIN_ID
end

function plugin.getVersion()
    return PLUGIN_VERSION
end

function plugin.getRequirements()
    return {}
end

function plugin.getCategories()
    return { "ios", "swift", "objc", "apple" }
end

function plugin.getMissingPackages()
    if command_exists(nil, REQUIRED_BINARY) then
        return {}
    end
    return { "cocoapods" }
end

function plugin.install(context, packages)
    local targets = packages or {}
    begin_step(context, "install CocoaPods dependencies")

    local ok, err = require_binary(context)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local project_dir, project_err = require_project_podfile(context, targets)
    if project_dir == nil then
        tx_failed(context, project_err)
        return false
    end

    local declarations = {}
    local removed = {}
    for _, raw_pkg in ipairs(targets) do
        local pkg, pkg_err = normalize_package(raw_pkg)
        if pkg == nil then
            tx_failed(context, pkg_err)
            return false
        end
        removed[pkg.name] = true
        declarations[#declarations + 1] = declaration_for_package(pkg)
    end

    if #targets > 0 then
        local write_ok, write_err = write_updated_podfile(project_dir, removed, declarations)
        if not write_ok then
            tx_failed(context, write_err)
            return false
        end
    end

    local command = build_pod_command(context, targets, install_command_args(context, targets))
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "pod install failed"))
        return false
    end

    emit_event(context, "installed", targets)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    begin_step(context, "install local CocoaPods dependency")

    local ok, err = require_binary(context)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local project_dir, project_err = require_project_podfile(context, {})
    if project_dir == nil then
        tx_failed(context, project_err)
        return false
    end

    local info, info_err = local_spec_info(context, local_path)
    if info == nil then
        tx_failed(context, info_err)
        return false
    end

    local write_ok, write_err = write_updated_podfile(project_dir, { [info.name] = true }, {
        declaration_for_local(info.name, local_path, info.usePodspec),
    })
    if not write_ok then
        tx_failed(context, write_err)
        return false
    end

    local command = build_pod_command(context, {}, install_command_args(context, {}))
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "pod install failed"))
        return false
    end

    emit_event(context, "installed", { path = local_path, name = info.name, localTarget = true })
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.remove(context, packages)
    local targets = packages or {}
    begin_step(context, "remove CocoaPods dependencies")

    local ok, err = require_binary(context)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local project_dir, project_err = require_project_podfile(context, targets)
    if project_dir == nil then
        tx_failed(context, project_err)
        return false
    end

    local removed = {}
    for _, raw_pkg in ipairs(targets) do
        local name = package_name(raw_pkg)
        if name == "" then
            tx_failed(context, "missing pod name")
            return false
        end
        removed[name] = true
    end

    if #targets > 0 then
        local write_ok, write_err = write_updated_podfile(project_dir, removed, {})
        if not write_ok then
            tx_failed(context, write_err)
            return false
        end
    end

    local command = build_pod_command(context, targets, install_command_args(context, targets))
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "pod install failed"))
        return false
    end

    emit_event(context, "deleted", targets)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.update(context, packages)
    local targets = packages or {}
    begin_step(context, "update CocoaPods dependencies")

    local ok, err = require_binary(context)
    if not ok then
        tx_failed(context, err)
        return false
    end

    local project_dir, project_err = require_project_podfile(context, targets)
    if project_dir == nil then
        tx_failed(context, project_err)
        return false
    end

    local declarations = {}
    local removed = {}
    local changed = false
    for _, raw_pkg in ipairs(targets) do
        local pkg, pkg_err = normalize_package(raw_pkg)
        if pkg == nil then
            tx_failed(context, pkg_err)
            return false
        end
        if pkg.version ~= "" then
            removed[pkg.name] = true
            declarations[#declarations + 1] = declaration_for_package(pkg)
            changed = true
        end
    end

    if changed then
        local write_ok, write_err = write_updated_podfile(project_dir, removed, declarations)
        if not write_ok then
            tx_failed(context, write_err)
            return false
        end
    end

    local command = build_pod_command(context, targets, update_command_args(context, targets))
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "pod update failed"))
        return false
    end

    emit_event(context, "updated", targets)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.list(context)
    local project_dir = project_dir_from_context(context, {})
    local items = list_from_lockfile(project_dir)
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

    local command = build_pod_command(context, {}, outdated_command_args(context))
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        log_warn(context, first_nonempty(result and result.stderr, result and result.stdout, "pod outdated failed"))
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end

    local items = parse_outdated_results(result.stdout, project_dir)
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

    local ok, err = require_binary(context)
    if not ok then
        log_warn(context, err)
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local command = build_pod_command(context, {}, search_command_args(context, cleaned_prompt))
    local result = run_exec(context, command)
    if result == nil or result.success ~= true then
        log_warn(context, first_nonempty(result and result.stderr, result and result.stdout, "pod search failed"))
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local items = parse_search_results(result.stdout)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local cleaned_name = trim(name)
    if cleaned_name == "" and context ~= nil then
        cleaned_name = trim(context.prompt)
    end
    if cleaned_name == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local project_dir = project_dir_from_context(context, {})
    local installed = exact_or_first(list_from_lockfile(project_dir), cleaned_name)

    if not command_exists(context, REQUIRED_BINARY) then
        local item = installed or {}
        emit_event(context, "informed", item)
        return item
    end

    local spec, err = remote_spec_for_name(context, {}, cleaned_name)
    local item = nil
    if spec ~= nil then
        item = item_from_spec(spec, installed)
    else
        log_warn(context, err)
        local search_item = exact_or_first(parse_search_results((run_exec(context, build_pod_command(context, {}, search_command_args(context, cleaned_name))) or {}).stdout or ""), cleaned_name)
        item = search_item or installed or {}
    end

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local pkg, err = normalize_package(package)
    if pkg == nil then
        return nil, err
    end

    local info = plugin.info(context, pkg.name)
    if type(info) == "table" and next(info) ~= nil then
        if pkg.version ~= "" then
            info.version = pkg.version
        end
        return info
    end

    return {
        name = pkg.name,
        packageId = pkg.name,
        version = pkg.version ~= "" and pkg.version or nil,
        packageType = "pod",
        type = "package",
    }
end

function plugin.init()
    return command_exists(nil, REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "cocoapods", "ios", "swift", "objc" },
        writeScopes = {
            "user-home-subpath:.cache/reqpack/cocoapods",
            "project-relative:Podfile",
            "project-relative:Podfile.lock",
            "project-relative:Pods",
            "project-relative:*.xcworkspace",
        },
        networkScopes = {
            { scheme = "https" },
            { scheme = "http" },
        },
        privilegeLevel = "user",
        purlType = "cocoapods",
        versionCaseInsensitive = false,
    }
end

return plugin
