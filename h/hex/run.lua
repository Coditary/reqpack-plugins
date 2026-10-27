plugin = {}

local PLUGIN_ID = "hex"
local PLUGIN_NAME = "Hex"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "mix"
local QUERY_APP = "reqpack_hex_query"

local function getenv(name)
    if os ~= nil and type(os.getenv) == "function" then
        local value = os.getenv(name)
        if value ~= nil and value ~= "" then
            return value
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
            local value = entry:sub(#prefix + 1)
            if value ~= "" then
                return value
            end
        end
    end
    return nil
end

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function expand_placeholders(value)
    local text = tostring(value or "")
    local fixture_root = getenv("REQPACK_TEST_FIXTURE_ROOT")
    if fixture_root ~= nil and fixture_root ~= "" then
        text = text:gsub("%$%{fixtureRoot%}", fixture_root)
    end
    return text
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

local function starts_with(value, prefix)
    local text = tostring(value or "")
    return text:sub(1, #prefix) == prefix
end

local function shell_quote(value)
    return "'" .. expand_placeholders(value):gsub("'", "'\\''") .. "'"
end

local function command_quote(value)
    local text = expand_placeholders(value)
    if text:match("^[%w%+%-%._/%:@=,%[%]]+$") ~= nil then
        return text
    end
    return shell_quote(text)
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(expand_placeholders(select(index, ...)))
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
    return expand_placeholders(path):match("^(.*)[/\\][^/\\]+$")
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
    local value = read_field(object, "flags")
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end
    local flags = {}
    local ok = pcall(function()
        for _, item in ipairs(value) do
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
        if first.stdout == nil then
            first.stdout = first.stdoutText or ""
        end
        if first.stderr == nil then
            first.stderr = first.stderrText or ""
        end
        if first.exitCode == nil then
            first.exitCode = first.exit_code or first.code or first.status
        end
        if first.success == nil and first.ok ~= nil then
            first.success = first.ok
        end
        if first.success == nil and first.exitCode ~= nil then
            first.success = first.exitCode == 0
        end
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

local function exec_run(context, command)
    local first, second, third, fourth, fifth
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        first, second, third, fourth, fifth = context.exec.run(command)
    else
        first, second, third, fourth, fifth = reqpack.exec.run(command)
    end
    return normalize_run_result(first, second, third, fourth, fifth)
end

local function is_command_success(result)
    if type(result) ~= "table" then
        return false
    end
    if result.success == true or result.ok == true then
        return true
    end
    return (result.exitCode or result.exit_code or result.code or result.status) == 0
end

local function command_exists(context, binary)
    return is_command_success(exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
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

local function read_file(path)
    local expanded = expand_placeholders(path)
    local handle = io.open(expanded, "r")
    if handle == nil then
        local result = exec_run(nil, "cat " .. shell_quote(expanded))
        if is_command_success(result) then
            return result.stdout
        end
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(path, content)
    path = expand_placeholders(path)
    local dir = parent_dir(path)
    local handle = io.open(path, "w")
    if handle ~= nil then
        handle:write(content)
        handle:close()
        return true, nil
    end
    local command = "mkdir -p " .. shell_quote(dir or ".") .. " && printf %s " .. shell_quote(content) .. " > " .. shell_quote(path)
    local result = exec_run(nil, command)
    if is_command_success(result) then
        return true, nil
    end
    return false, trim(result.stderr) ~= "" and trim(result.stderr) or "failed to write file"
end

local function split_table_columns(line)
    local columns = {}
    local normalized = trim(line):gsub("%s%s+", "\t")
    for value in normalized:gmatch("([^\t]+)") do
        columns[#columns + 1] = trim(value)
    end
    return columns
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
        mix_home = join_path(root, "mix"),
        mix_archives = join_path(root, "mix", "archives"),
        hex_home = join_path(root, "hex"),
        query_project = join_path(root, "query-project"),
        query_mix_exs = join_path(root, "query-project", "mix.exs"),
    }
end

local function env_prefix(paths)
    return table.concat({
        "MIX_HOME=" .. shell_quote(paths.mix_home),
        "MIX_ARCHIVES=" .. shell_quote(paths.mix_archives),
        "HEX_HOME=" .. shell_quote(paths.hex_home),
        "MIX_ENV='prod'",
        "NO_COLOR='1'",
        "LC_ALL='C'",
        "LANG='C'",
        "LANGUAGE='C'",
    }, " ")
end

local function project_directory(context, packages)
    local raw_flags = collect_raw_flags(context, packages)
    local explicit = trim(
        expand_placeholders(read_field(context, "directory")
            or read_field(context, "dir")
            or read_field(read_field(context, "request"), "directory")
            or read_field(read_field(context, "request"), "dir")
            or flag_value(raw_flags, "dir")
            or ""
        )
    )
    if explicit ~= "" then
        return explicit
    end
    return shared_paths(context, packages).query_project
end

local function build_mix_command(context, packages, args, forced_dir)
    local paths = shared_paths(context, packages)
    local quoted = { env_prefix(paths), REQUIRED_BINARY }
    for _, arg in ipairs(args or {}) do
        quoted[#quoted + 1] = command_quote(arg)
    end
    local command = table.concat(quoted, " ")
    local dir = trim(forced_dir or project_directory(context, packages) or "")
    if dir ~= "" then
        command = "cd " .. shell_quote(dir) .. " && " .. command
    end
    return command, paths
end

local function build_global_mix_command(context, packages, args)
    local paths = shared_paths(context, packages)
    local quoted = { env_prefix(paths), REQUIRED_BINARY }
    for _, arg in ipairs(args or {}) do
        quoted[#quoted + 1] = command_quote(arg)
    end
    return table.concat(quoted, " "), paths
end

local function ensure_hex_available(context, packages)
    if not command_exists(context, REQUIRED_BINARY) then
        return false, REQUIRED_BINARY .. " binary not available"
    end
    local bootstrap = exec_run(context, build_global_mix_command(context, packages, { "local.hex", "--if-missing", "--force" }))
    if is_command_success(bootstrap) then
        return true, nil
    end
    return false, trim(bootstrap.stderr) ~= "" and trim(bootstrap.stderr) or "failed to bootstrap Hex"
end

local function query_project_mix_exs()
    return table.concat({
        "defmodule ReqpackHexQuery.MixProject do",
        "  use Mix.Project",
        "",
        "  def project do",
        "    [",
        "      app: :" .. QUERY_APP .. ",",
        "      version: \"0.0.0\",",
        "      deps: deps()",
        "    ]",
        "  end",
        "",
        "  defp deps do",
        "    [",
        "    ]",
        "  end",
        "end",
        "",
    }, "\n")
end

local function ensure_project_ready(context, packages)
    local dir = project_directory(context, packages)
    local mix_exs = join_path(dir, "mix.exs")
    local paths = shared_paths(context, packages)
    if dir == paths.query_project then
        local current = read_file(paths.query_mix_exs)
        if current == nil or trim(current) == "" then
            local ok, message = write_file(paths.query_mix_exs, query_project_mix_exs())
            if not ok then
                return nil, "failed to write shared query project: " .. tostring(message)
            end
        end
        return { dir = dir, mix_exs = mix_exs, shared = true }, nil
    end
    if read_file(mix_exs) == nil then
        return nil, "mix.exs not found in " .. dir
    end
    return { dir = dir, mix_exs = mix_exs, shared = false }, nil
end

local function package_name(package)
    return trim(read_field(package, "name") or read_field(package, "packageName") or read_field(package, "packageId") or "")
end

local function package_version(package)
    return trim(read_field(package, "version") or "")
end

local function package_action(package)
    return lower(trim(read_field(package, "action") or read_field(package, "requestedAction") or "install"))
end

local function normalize_dep_name(value)
    return lower(trim(value))
end

local function extract_dep_key(chunk)
    local atom_name = chunk:match("{%s*:([%a_][%w_]*)%s*,")
    if atom_name ~= nil then
        return atom_name
    end
    local string_name = chunk:match('{%s*"([^"]+)"%s*,')
    if string_name ~= nil then
        return string_name
    end
    return nil
end

local function find_deps_list(lines)
    local deps_index = nil
    for index, line in ipairs(lines or {}) do
        if line:match("^%s*defp%s+deps%s+do") or line:match("^%s*def%s+deps%s+do") then
            deps_index = index
            break
        end
    end
    if deps_index == nil then
        return nil, nil
    end
    local started = false
    local depth = 0
    local start_index = nil
    for line_index = deps_index, #lines do
        local line = lines[line_index]
        for char_index = 1, #line do
            local ch = line:sub(char_index, char_index)
            if ch == "[" then
                if not started then
                    started = true
                    start_index = line_index
                end
                depth = depth + 1
            elseif ch == "]" and started then
                depth = depth - 1
                if depth == 0 then
                    return start_index, line_index
                end
            end
        end
    end
    return nil, nil
end

local function parse_dep_entries(lines, list_start, list_end)
    local entries = {}
    local brace_depth = 0
    local chunk_start = nil
    for line_index = list_start, list_end do
        local line = lines[line_index]
        for char_index = 1, #line do
            local ch = line:sub(char_index, char_index)
            if ch == "{" then
                if brace_depth == 0 then
                    chunk_start = chunk_start or line_index
                end
                brace_depth = brace_depth + 1
            elseif ch == "}" and brace_depth > 0 then
                brace_depth = brace_depth - 1
                if brace_depth == 0 and chunk_start ~= nil then
                    local chunk_lines = {}
                    for current = chunk_start, line_index do
                        chunk_lines[#chunk_lines + 1] = lines[current]
                    end
                    local chunk = table.concat(chunk_lines, "\n")
                    entries[#entries + 1] = {
                        start_line = chunk_start,
                        end_line = line_index,
                        chunk = chunk,
                        name = normalize_dep_name(extract_dep_key(chunk) or ""),
                    }
                    chunk_start = nil
                end
            end
        end
    end
    return entries
end

local function replace_range(lines, start_line, end_line, replacement)
    local updated = {}
    for index = 1, start_line - 1 do
        updated[#updated + 1] = lines[index]
    end
    for _, line in ipairs(replacement or {}) do
        updated[#updated + 1] = line
    end
    for index = end_line + 1, #lines do
        updated[#updated + 1] = lines[index]
    end
    return updated
end

local function insert_before(lines, before_index, replacement)
    return replace_range(lines, before_index, before_index - 1, replacement)
end

local function dep_indent(lines, entries, list_end)
    if #(entries or {}) > 0 then
        return (lines[entries[1].start_line] or ""):match("^(%s*)") or "    "
    end
    local closing_indent = (lines[list_end] or ""):match("^(%s*)") or "  "
    return closing_indent .. "  "
end

local function parse_config_snippet(snippet)
    local text = trim(snippet)
    local name, requirement, rest = text:match('^%{%s*:([%a_][%w_]*)%s*,%s*"([^"]+)"%s*,%s*(.-)%s*%}$')
    if name ~= nil then
        return { app = name, requirement = requirement, options = trim(rest) }
    end
    name, requirement = text:match('^%{%s*:([%a_][%w_]*)%s*,%s*"([^"]+)"%s*%}$')
    if name ~= nil then
        return { app = name, requirement = requirement, options = "" }
    end
    return nil
end

local function normalize_requirement(version)
    local text = trim(version)
    if text == "" or lower(text) == "latest" then
        return nil
    end
    if text:match("^[<>~=!]") or text:find(",", 1, true) ~= nil then
        return text
    end
    return "== " .. text
end

local function parse_mix_info(stdout)
    local info = {
        description = "",
        config = nil,
        locked_version = nil,
        releases = {},
        licenses = {},
        links = {},
        dependencies = {},
        released = nil,
        documentation = nil,
    }
    local lines = split_lines(stdout)
    local description_lines = {}
    local in_releases = false
    local in_links = false
    local in_dependencies = false
    for _, line in ipairs(lines) do
        local trimmed = trim(line)
        if starts_with(trimmed, "Config:") then
            info.config = trim(trimmed:sub(#"Config:" + 1))
            in_releases = false
            in_links = false
            in_dependencies = false
        elseif starts_with(trimmed, "Locked version:") then
            info.locked_version = trim(trimmed:sub(#"Locked version:" + 1))
        elseif trimmed == "Recent releases:" or trimmed == "Releases:" then
            in_releases = true
            in_links = false
            in_dependencies = false
        elseif starts_with(trimmed, "Licenses:") then
            in_releases = false
            in_links = false
            in_dependencies = false
            for item in trim(trimmed:sub(#"Licenses:" + 1)):gmatch("([^,]+)") do
                info.licenses[#info.licenses + 1] = trim(item)
            end
        elseif trimmed == "Links:" then
            in_releases = false
            in_links = true
            in_dependencies = false
        elseif starts_with(trimmed, "Released:") then
            info.released = trim(trimmed:sub(#"Released:" + 1))
            in_releases = false
            in_links = false
            in_dependencies = false
        elseif starts_with(trimmed, "Documentation at:") then
            info.documentation = trim(trimmed:sub(#"Documentation at:" + 1))
        elseif trimmed == "Dependencies:" then
            in_dependencies = true
            in_releases = false
            in_links = false
        elseif in_releases and line:match("^%s+") ~= nil and trimmed ~= "" then
            local version = trim(line):match("^([%w%._%-]+)")
            if version ~= nil and version ~= "..." then
                info.releases[#info.releases + 1] = version
            end
        elseif in_links and line:match("^%s+") ~= nil and trimmed ~= "" then
            local key, value = trim(line):match("^([^:]+):%s*(.+)$")
            if key ~= nil and value ~= nil then
                info.links[trim(key)] = trim(value)
            end
        elseif in_dependencies and line:match("^%s+") ~= nil and trimmed ~= "" then
            info.dependencies[#info.dependencies + 1] = trim(line)
        elseif info.config == nil and trimmed ~= "" then
            description_lines[#description_lines + 1] = trimmed
        else
            in_releases = false
            in_links = false
            in_dependencies = false
        end
    end
    info.description = table.concat(description_lines, " ")
    return info
end

local function run_mix_info(context, packages, name, version)
    local raw_flags = collect_raw_flags(context, packages)
    local args = { "hex.info", name }
    if trim(version or "") ~= "" then
        args[#args + 1] = version
    end
    local organization = flag_value(raw_flags, "organization")
    if organization ~= nil and organization ~= "" then
        args[#args + 1] = "--organization"
        args[#args + 1] = organization
    end
    return exec_run(context, build_global_mix_command(context, packages, args))
end

local function atom_literal(name)
    return ":" .. trim(name)
end

local function render_option_value(key, value)
    if key == "hex" then
        return string.format('%q', tostring(value))
    end
    if key == "only" then
        local items = {}
        for item in tostring(value or ""):gmatch("([^,]+)") do
            local cleaned = trim(item)
            if cleaned ~= "" then
                items[#items + 1] = atom_literal(cleaned)
            end
        end
        if #items == 1 then
            return items[1]
        end
        return "[" .. table.concat(items, ", ") .. "]"
    end
    if value == true or value == "true" then
        return "true"
    end
    if value == false or value == "false" then
        return "false"
    end
    return string.format('%q', tostring(value))
end

local function build_dependency_options(app_name, hex_name, package_flags)
    local options = {}
    if trim(hex_name) ~= "" and trim(hex_name) ~= trim(app_name) then
        options[#options + 1] = { key = "hex", value = hex_name }
    end
    for _, key in ipairs({ "organization", "repo", "only" }) do
        local value = flag_value(package_flags, key)
        if value ~= nil and value ~= "" then
            options[#options + 1] = { key = key, value = value }
        end
    end
    for _, key in ipairs({ "optional", "runtime", "override" }) do
        local value = flag_value(package_flags, key)
        if value ~= nil and value ~= "" then
            options[#options + 1] = { key = key, value = lower(value) == "true" }
        end
    end
    return options
end

local function render_dependency_line(entry, indent)
    local parts = { indent .. "{" .. atom_literal(entry.app) }
    if entry.requirement ~= nil and entry.requirement ~= "" then
        parts[#parts + 1] = string.format('%q', entry.requirement)
    end
    for _, option in ipairs(entry.options or {}) do
        parts[#parts + 1] = option.key .. ": " .. render_option_value(option.key, option.value)
    end
    return table.concat(parts, ", ") .. "},"
end

local function resolve_remote_entry(context, package, packages)
    local raw_name = package_name(package)
    if raw_name == "" then
        return nil, "missing Hex package name"
    end
    local package_flags = collect_raw_flags(context, { package })
    local info = nil
    local version = package_version(package)
    if trim(version) == "" or lower(version) == "latest" then
        local info_result = run_mix_info(context, packages or { package }, raw_name, nil)
        if is_command_success(info_result) then
            info = parse_mix_info(info_result.stdout)
        end
    end
    local parsed = info ~= nil and info.config ~= nil and parse_config_snippet(info.config) or nil
    local app_name = parsed ~= nil and trim(parsed.app or "") or raw_name
    local requirement = normalize_requirement(version)
    if requirement == nil then
        requirement = parsed ~= nil and trim(parsed.requirement or "") or "*"
    end
    return {
        app = app_name,
        requirement = requirement,
        options = build_dependency_options(app_name, raw_name, package_flags),
    }, nil
end

local function local_app_name(path)
    local content = read_file(join_path(path, "mix.exs"))
    if content == nil then
        return nil
    end
    return trim(content:match("app:%s*:([%a_][%w_]*)") or content:match('app:%s*"([^"]+)"') or "")
end

local function resolve_local_entry(context, path, packages)
    local raw_flags = collect_raw_flags(context, packages or {})
    local explicit_name = flag_value(raw_flags, "name")
    local app_name = trim(explicit_name or "")
    if app_name == "" then
        app_name = trim(local_app_name(path) or "")
    end
    if app_name == "" then
        return nil, "failed to resolve local Mix app name"
    end
    return {
        app = app_name,
        requirement = nil,
        options = {
            { key = "path", value = path },
        },
    }, nil
end

local function rewrite_mix_deps(mix_exs_path, mutator)
    local content = read_file(mix_exs_path)
    if content == nil then
        return false, "failed to read mix.exs"
    end
    local lines = split_lines(content)
    local list_start, list_end = find_deps_list(lines)
    if list_start == nil or list_end == nil then
        return false, "failed to locate deps list in mix.exs"
    end
    local entries = parse_dep_entries(lines, list_start, list_end)
    local updated_lines, changed = mutator(lines, entries, list_start, list_end)
    if changed ~= true then
        return true, nil
    end
    return write_file(mix_exs_path, table.concat(updated_lines, "\n") .. "\n")
end

local function apply_entries(lines, entries, list_start, list_end, updates, removals)
    local current = lines
    local changed = false

    local removed = {}
    for key in pairs(removals or {}) do
        removed[key] = true
    end

    local ordered = {}
    for _, entry in ipairs(entries or {}) do
        ordered[#ordered + 1] = entry
    end
    table.sort(ordered, function(left, right)
        return left.start_line > right.start_line
    end)

    for _, entry in ipairs(ordered) do
        if removed[entry.name] then
            current = replace_range(current, entry.start_line, entry.end_line, {})
            changed = true
        elseif updates[entry.name] ~= nil then
            current = replace_range(current, entry.start_line, entry.end_line, { updates[entry.name] })
            changed = true
            updates[entry.name] = nil
        end
    end

    local remaining = {}
    for key, value in pairs(updates or {}) do
        if value ~= nil then
            remaining[#remaining + 1] = value
        end
    end
    if #remaining > 0 then
        local fresh_start, fresh_end = find_deps_list(current)
        local fresh_entries = parse_dep_entries(current, fresh_start, fresh_end)
        local indent = dep_indent(current, fresh_entries, fresh_end)
        local insertion = {}
        for _, value in ipairs(remaining) do
            insertion[#insertion + 1] = indent .. value:match("^%s*(.-)%s*$")
        end
        current = insert_before(current, fresh_end, insertion)
        changed = true
    end
    return current, changed
end

local function load_declared_dep_map(mix_exs_path)
    local content = read_file(mix_exs_path)
    if content == nil then
        return {}
    end
    local lines = split_lines(content)
    local list_start, list_end = find_deps_list(lines)
    if list_start == nil or list_end == nil then
        return {}
    end
    local entries = parse_dep_entries(lines, list_start, list_end)
    local map = {}
    for _, entry in ipairs(entries) do
        if entry.name ~= "" then
            map[entry.name] = entry.chunk
        end
    end
    return map
end

local function parse_mix_deps(stdout)
    local items = {}
    local current = nil
    local function flush()
        if current ~= nil and current.is_hex then
            current.is_hex = nil
            items[#items + 1] = current
        end
        current = nil
    end
    for _, line in ipairs(split_lines(stdout)) do
        local trimmed = trim(line)
        if starts_with(trimmed, "*") then
            flush()
            local header = trim(trimmed:gsub("^%*%s*", ""))
            local name, version = header:match("^([%w_]+)%s+([^%s]+)")
            current = {
                name = trim(name or ""),
                packageId = trim(name or ""),
                version = trim(version or ""),
                latestVersion = trim(version or ""),
                installed = true,
                status = "installed",
                packageType = "dependency",
                is_hex = header:find("(Hex package)", 1, true) ~= nil,
            }
        elseif current ~= nil and trimmed ~= "" and not starts_with(trimmed, "locked at") then
            current.extraFields = current.extraFields or {}
            current.extraFields.mixStatus = trimmed
        end
    end
    flush()
    return items
end

local function column_positions(header)
    local positions = {}
    for _, name in ipairs({ "Organization", "Package", "Description", "Version", "URL", "Dependency", "Only", "Current", "Latest", "Status", "Source", "Requirement", "Up-to-date" }) do
        local start_index = header:find(name, 1, true)
        if start_index ~= nil then
            positions[name] = start_index
        end
    end
    return positions
end

local function extract_column(line, start_index, end_index)
    if start_index == nil then
        return nil
    end
    if end_index == nil then
        return trim(line:sub(start_index))
    end
    return trim(line:sub(start_index, end_index - 1))
end

local function parse_search_results(stdout)
    if stdout:find("No packages found", 1, true) ~= nil then
        return {}
    end
    local items = {}
    local header_seen = false
    for _, line in ipairs(split_lines(stdout)) do
        local trimmed = trim(line)
        if not header_seen then
            if line:find("Package", 1, true) ~= nil and line:find("Version", 1, true) ~= nil and line:find("URL", 1, true) ~= nil then
                header_seen = true
            end
        elseif trimmed ~= "" then
            local columns = split_table_columns(line)
            if #columns == 4 or #columns == 5 then
                local offset = #columns == 5 and 1 or 0
                items[#items + 1] = {
                    name = columns[1 + offset],
                    packageId = columns[1 + offset],
                    description = columns[2 + offset],
                    version = columns[3 + offset],
                    latestVersion = columns[3 + offset],
                    homepage = columns[4 + offset],
                    repository = offset == 1 and columns[1] or nil,
                    status = "available",
                    installed = false,
                    packageType = "dependency",
                }
            end
        end
    end
    return items
end

local function parse_outdated_results(stdout)
    local lines = split_lines(stdout)
    local header_index = nil
    for index, line in ipairs(lines) do
        if line:find("Dependency", 1, true) ~= nil and line:find("Current", 1, true) ~= nil and line:find("Latest", 1, true) ~= nil and line:find("Status", 1, true) ~= nil then
            header_index = index
            break
        end
    end
    if header_index == nil then
        return {}
    end
    local positions = column_positions(lines[header_index])
    local items = {}
    for index = header_index + 1, #lines do
        local line = lines[index]
        local trimmed = trim(line)
        if trimmed == "" or starts_with(trimmed, "Run `") or starts_with(trimmed, "To view") or starts_with(trimmed, "Versions in cooldown") then
            goto continue
        end
        if trimmed:find("eligible ", 1, true) ~= nil then
            goto continue
        end
        local columns = split_table_columns(line)
        local name, only, current, latest, status
        if #columns >= 5 then
            name = columns[1]
            only = columns[2]
            current = columns[3]
            latest = columns[4]
            status = table.concat({ table.unpack(columns, 5) }, " ")
        elseif #columns >= 4 then
            name = columns[1]
            current = columns[2]
            latest = columns[3]
            status = table.concat({ table.unpack(columns, 4) }, " ")
        end
        if trim(name or "") ~= "" and trim(current or "") ~= "" and trim(latest or "") ~= "" and lower(status or ""):find("up%-to%-date", 1, false) == nil then
            items[#items + 1] = {
                name = name,
                packageId = name,
                version = current,
                latestVersion = latest,
                installed = true,
                status = status,
                packageType = "dependency",
                extraFields = only ~= nil and only ~= "" and { only = only } or nil,
            }
        end
        ::continue::
    end
    return items
end

local function info_item_from_output(name, version, stdout)
    local parsed = parse_mix_info(stdout)
    local resolved_version = trim(version or "")
    if resolved_version == "" then
        resolved_version = trim(parsed.locked_version or parsed.releases[1] or "")
    end
    local license = nil
    if #parsed.licenses > 0 then
        license = table.concat(parsed.licenses, ", ")
    end
    local homepage = parsed.links.GitHub or parsed.links.Website or parsed.links.Homepage or parsed.documentation
    return {
        name = trim(name),
        packageId = name,
        version = resolved_version,
        latestVersion = trim(parsed.releases[1] or resolved_version),
        description = parsed.description,
        installed = parsed.locked_version ~= nil,
        status = parsed.locked_version ~= nil and "installed" or "available",
        packageType = "dependency",
        license = license,
        homepage = homepage,
        dependencies = #parsed.dependencies > 0 and parsed.dependencies or nil,
        extraFields = {
            config = parsed.config,
            released = parsed.released,
            documentation = parsed.documentation,
            links = parsed.links,
        },
    }
end

local function outdated_name_map(context)
    local result = {}
    local items = plugin.outdated(context) or {}
    for _, item in ipairs(items) do
        result[normalize_dep_name(item.name)] = true
    end
    return result
end

function plugin.init()
    return true
end

function plugin.shutdown()
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
    return { "Elixir", "Hex", "Mix", "Package Manager" }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "dependency-install", "dependency-remove", "dependency-update", "dependency-query", "project-manifest-edit" },
        ecosystemScopes = { "hexpm", "elixir" },
        writeScopes = {
            "user-home-subpath:.cache/reqpack/hex",
            "project-file:mix.exs",
            "project-file:mix.lock",
            "project-subpath:deps",
            "project-subpath:_build",
        },
        networkScopes = { "hex.pm" },
        privilegeLevel = "none",
        osvEcosystem = "Hex",
        purlType = "hex",
    }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end
    if not command_exists(nil, REQUIRED_BINARY) then
        return requested
    end
    local target, err = ensure_project_ready(nil, requested)
    if target == nil then
        return requested
    end
    local declared = load_declared_dep_map(target.mix_exs)
    local outdated = nil
    local filtered = {}
    for _, package in ipairs(requested) do
        local name = normalize_dep_name(package_name(package))
        local action = package_action(package)
        local declared_chunk = declared[name]
        if action == "remove" then
            if declared_chunk ~= nil then
                filtered[#filtered + 1] = package
            end
        elseif action == "update" then
            outdated = outdated or outdated_name_map({ flags = { "dir=" .. target.dir } })
            if outdated[name] == true then
                filtered[#filtered + 1] = package
            end
        elseif declared_chunk == nil then
            filtered[#filtered + 1] = package
        else
            local version = package_version(package)
            if version ~= "" and declared_chunk:find(version, 1, true) == nil then
                filtered[#filtered + 1] = package
            end
        end
    end
    return filtered
end

function plugin.install(context, packages)
    local local_path = trim(read_field(context, "localPath") or read_field(read_field(context, "request"), "localPath") or "")
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    begin_step(context, "install Hex dependencies")
    local available, err = ensure_hex_available(context, requested)
    if not available then
        tx_failed(context, err)
        return false
    end
    local target, target_err = ensure_project_ready(context, requested)
    if target == nil then
        tx_failed(context, target_err)
        return false
    end
    local updates = {}
    local lines = split_lines(read_file(target.mix_exs) or "")
    local list_start, list_end = find_deps_list(lines)
    local entries = parse_dep_entries(lines, list_start, list_end)
    local indent = dep_indent(lines, entries, list_end)
    for _, package in ipairs(requested) do
        local entry, entry_err = resolve_remote_entry(context, package, requested)
        if entry == nil then
            tx_failed(context, entry_err)
            return false
        end
        updates[normalize_dep_name(entry.app)] = render_dependency_line(entry, indent)
    end
    local ok, write_err = rewrite_mix_deps(target.mix_exs, function(current_lines, current_entries, current_start, current_end)
        local applied, changed = apply_entries(current_lines, current_entries, current_start, current_end, updates, {})
        return applied, changed
    end)
    if not ok then
        tx_failed(context, write_err)
        return false
    end
    local result = exec_run(context, build_mix_command(context, requested, { "deps.get" }, target.dir))
    if not is_command_success(result) then
        tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "mix deps.get failed")
        return false
    end
    emit_event(context, "installed", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path or "")
    if local_path == "" then
        tx_failed(context, "missing local path")
        return false
    end
    begin_step(context, "install local Hex dependency")
    local available, err = ensure_hex_available(context, {})
    if not available then
        tx_failed(context, err)
        return false
    end
    local target, target_err = ensure_project_ready(context, {})
    if target == nil then
        tx_failed(context, target_err)
        return false
    end
    local entry, entry_err = resolve_local_entry(context, local_path, {})
    if entry == nil then
        tx_failed(context, entry_err)
        return false
    end
    local ok, write_err = rewrite_mix_deps(target.mix_exs, function(current_lines, current_entries, current_start, current_end)
        local indent = dep_indent(current_lines, current_entries, current_end)
        local updates = {
            [normalize_dep_name(entry.app)] = render_dependency_line(entry, indent),
        }
        local applied, changed = apply_entries(current_lines, current_entries, current_start, current_end, updates, {})
        return applied, changed
    end)
    if not ok then
        tx_failed(context, write_err)
        return false
    end
    local result = exec_run(context, build_mix_command(context, {}, { "deps.get" }, target.dir))
    if not is_command_success(result) then
        tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "mix deps.get failed")
        return false
    end
    emit_event(context, "installed", { { name = entry.app, path = local_path } })
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    begin_step(context, "remove Hex dependencies")
    local available, err = ensure_hex_available(context, requested)
    if not available then
        tx_failed(context, err)
        return false
    end
    local target, target_err = ensure_project_ready(context, requested)
    if target == nil then
        tx_failed(context, target_err)
        return false
    end
    local removals = {}
    for _, package in ipairs(requested) do
        removals[normalize_dep_name(package_name(package))] = true
    end
    local ok, write_err = rewrite_mix_deps(target.mix_exs, function(current_lines, current_entries, current_start, current_end)
        local applied, changed = apply_entries(current_lines, current_entries, current_start, current_end, {}, removals)
        return applied, changed
    end)
    if not ok then
        tx_failed(context, write_err)
        return false
    end
    local result = exec_run(context, build_mix_command(context, requested, { "deps.clean", "--unlock", "--unused" }, target.dir))
    if not is_command_success(result) then
        tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "mix deps.clean failed")
        return false
    end
    emit_event(context, "deleted", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    begin_step(context, "update Hex dependencies")
    local available, err = ensure_hex_available(context, requested)
    if not available then
        tx_failed(context, err)
        return false
    end
    local target, target_err = ensure_project_ready(context, requested)
    if target == nil then
        tx_failed(context, target_err)
        return false
    end
    if #requested > 0 then
        local versioned = false
        for _, package in ipairs(requested) do
            if package_version(package) ~= "" then
                versioned = true
                break
            end
        end
        if versioned then
            local ok, write_err = rewrite_mix_deps(target.mix_exs, function(current_lines, current_entries, current_start, current_end)
                local indent = dep_indent(current_lines, current_entries, current_end)
                local updates = {}
                for _, package in ipairs(requested) do
                    if package_version(package) ~= "" then
                        local entry = assert(resolve_remote_entry(context, package, requested))
                        updates[normalize_dep_name(entry.app)] = render_dependency_line(entry, indent)
                    end
                end
                local applied, changed = apply_entries(current_lines, current_entries, current_start, current_end, updates, {})
                return applied, changed
            end)
            if not ok then
                tx_failed(context, write_err)
                return false
            end
        end
    end
    local args = { "deps.update" }
    if #requested == 0 then
        args[#args + 1] = "--all"
    else
        for _, package in ipairs(requested) do
            local name = package_name(package)
            if name ~= "" then
                args[#args + 1] = name
            end
        end
    end
    local result = exec_run(context, build_mix_command(context, requested, args, target.dir))
    if not is_command_success(result) then
        tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "mix deps.update failed")
        return false
    end
    emit_event(context, "updated", requested)
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
end

function plugin.list(context)
    local available, err = ensure_hex_available(context, {})
    if not available then
        log_warn(context, err)
        return {}
    end
    local target, target_err = ensure_project_ready(context, {})
    if target == nil then
        log_warn(context, target_err)
        return {}
    end
    local result = exec_run(context, build_mix_command(context, {}, { "deps", "--all" }, target.dir))
    if not is_command_success(result) then
        log_warn(context, trim(result.stderr) ~= "" and trim(result.stderr) or "mix deps --all failed")
        return {}
    end
    local items = parse_mix_deps(result.stdout)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local available, err = ensure_hex_available(context, {})
    if not available then
        log_warn(context, err)
        return {}
    end
    local target, target_err = ensure_project_ready(context, {})
    if target == nil then
        log_warn(context, target_err)
        return {}
    end
    local result = exec_run(context, build_mix_command(context, {}, { "hex.outdated", "--all", "--within-requirements" }, target.dir))
    local items = parse_outdated_results(result.stdout or "")
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
    if query == "" then
        return {}
    end
    local available, err = ensure_hex_available(context, {})
    if not available then
        log_warn(context, err)
        return {}
    end
    local raw_flags = collect_raw_flags(context, {})
    local args = { "hex.package", "search", query }
    local organization = flag_value(raw_flags, "organization")
    if organization ~= nil and organization ~= "" then
        args[#args + 1] = "--organization"
        args[#args + 1] = organization
    end
    local result = exec_run(context, build_global_mix_command(context, {}, args))
    if not is_command_success(result) then
        log_warn(context, trim(result.stderr) ~= "" and trim(result.stderr) or "mix hex.package search failed")
        return {}
    end
    local items = parse_search_results(result.stdout)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = trim(name or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
    if query == "" then
        emit_event(context, "informed", {})
        return {}
    end
    local available, err = ensure_hex_available(context, {})
    if not available then
        log_warn(context, err)
        emit_event(context, "informed", {})
        return {}
    end
    local requested_version = trim(flag_value(collect_raw_flags(context, {}), "version") or "")
    local result = run_mix_info(context, {}, query, requested_version)
    if not is_command_success(result) then
        log_warn(context, trim(result.stderr) ~= "" and trim(result.stderr) or "mix hex.info failed")
        emit_event(context, "informed", {})
        return {}
    end
    local item = info_item_from_output(query, requested_version, result.stdout)
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end
    if read_field(package, "localTarget") == true or trim(read_field(package, "sourcePath") or "") ~= "" then
        return nil
    end

    local name = package_name(package)
    if name == "" then
        return nil
    end

    local requested_version = package_version(package)
    local info_context = context or {}
    local info_flags = collect_raw_flags(context, { package })
    if requested_version ~= "" then
        local seen = false
        for _, flag in ipairs(info_flags) do
            if lower(flag):sub(1, #"version=") == "version=" then
                seen = true
                break
            end
        end
        if not seen then
            info_flags[#info_flags + 1] = "version=" .. requested_version
        end
    end
    info_context.flags = info_flags

    local item = plugin.info(info_context, name)
    if type(item) ~= "table" or next(item) == nil then
        return nil
    end

    local resolved = {
        name = trim(item.name or name),
        packageId = trim(item.packageId or name),
        packageType = item.packageType,
        version = requested_version ~= "" and requested_version or trim(item.version or item.latestVersion or ""),
        latestVersion = trim(item.latestVersion or item.version or ""),
        homepage = item.homepage,
        license = item.license,
        extraFields = item.extraFields,
    }

    if resolved.version == "" then
        resolved.version = nil
    end
    if resolved.latestVersion == "" then
        resolved.latestVersion = nil
    end

    return resolved
end

return plugin
