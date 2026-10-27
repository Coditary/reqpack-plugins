plugin = {}

local PLUGIN_ID = "dotnet"
local PLUGIN_NAME = "Dotnet"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "dotnet"
local ENV_LOCALE = "LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en"
local SEARCH_LIMIT = 20

plugin.fileExtensions = { ".nupkg" }

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
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

local function run_command(context, command)
    local first, second, third, fourth, fifth

    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        first, second, third, fourth, fifth = context.exec.run(command)
    elseif reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
        first, second, third, fourth, fifth = reqpack.exec.run(command)
    else
        return {
            success = false,
            stdout = "",
            stderr = "reqpack.exec.run unavailable",
            exitCode = 127,
        }
    end

    return normalize_run_result(first, second, third, fourth, fifth)
end

local function is_command_success(result, extra_exit_codes)
    if type(result) ~= "table" then
        return false
    end

    if result.success == true or result.ok == true then
        return true
    end

    local exit_code = result.exitCode or result.exit_code or result.code or result.status
    if exit_code == 0 then
        return true
    end

    if type(extra_exit_codes) == "table" then
        for _, allowed in ipairs(extra_exit_codes) do
            if exit_code == allowed then
                return true
            end
        end
    end

    return false
end

local function command_exists(binary)
    return is_command_success(run_command(nil, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = trim(select(index, ...))
        if part ~= "" then
            if #parts == 0 then
                parts[#parts + 1] = part:gsub("/+$", "")
            else
                parts[#parts + 1] = part:gsub("^/+", ""):gsub("/+$", "")
            end
        end
    end
    if #parts == 0 then
        return "."
    end
    return table.concat(parts, "/")
end

local function build_command(parts)
    local quoted = {}
    for _, part in ipairs(parts or {}) do
        local text = trim(part)
        if text ~= "" then
            quoted[#quoted + 1] = shell_quote(text)
        end
    end
    return table.concat(quoted, " ")
end

local function append_option(args, flag, value)
    local text = trim(value)
    if text ~= "" then
        args[#args + 1] = flag
        args[#args + 1] = text
    end
end

local function append_unique(list, value, seen)
    local text = trim(value)
    if text == "" or seen[text] then
        return
    end
    seen[text] = true
    list[#list + 1] = text
end

local function sorted_items(items)
    table.sort(items, function(left, right)
        local left_key = lower((left and left.packageId) or (left and left.name) or "")
        local right_key = lower((right and right.packageId) or (right and right.name) or "")
        return left_key < right_key
    end)
    return items
end

local function object_flags(object)
    local value = read_field(object, "flags")
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return {}
    end

    local flags = {}
    local ok = pcall(function()
        for _, item in ipairs(value) do
            local text = trim(item)
            if text ~= "" then
                flags[#flags + 1] = text
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

    local function collect_from(object)
        for _, item in ipairs(object_flags(object)) do
            append_unique(flags, item, seen)
        end
    end

    collect_from(context)
    collect_from(read_field(context, "request"))
    collect_from(package)
    return flags
end

local function flag_present(flags, name)
    local wanted = lower(trim(name))
    for _, flag in ipairs(flags or {}) do
        if lower(trim(flag)) == wanted then
            return true
        end
    end
    return false
end

local function flag_value(flags, prefix)
    local wanted = lower(trim(prefix))
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if lower(cleaned):sub(1, #wanted) == wanted then
            return trim(cleaned:sub(#wanted + 1))
        end
    end
    return ""
end

local function get_plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR or "")
    if dir ~= "" then
        return dir
    end
    return "."
end

local function data_root(context)
    local override = flag_value(collect_flags(context, nil), "cache-root=")
    if override ~= "" then
        return override
    end
    return join_path(get_plugin_dir(), ".reqpack-data", PLUGIN_ID)
end

local function workspace_root(context)
    return join_path(data_root(context), "workspace")
end

local function dotnet_home_root(context)
    return join_path(workspace_root(context), "dotnet-home")
end

local function nuget_packages_root(context)
    return join_path(workspace_root(context), "nuget-packages")
end

local function tool_path_root(context)
    return join_path(workspace_root(context), "tool-path")
end

local function tool_local_root(context)
    return join_path(workspace_root(context), "tool-local")
end

local function tool_manifest_path(context)
    return join_path(tool_local_root(context), ".config", "dotnet-tools.json")
end

local function qsharp_host_root(context)
    return join_path(workspace_root(context), "qsharp-host")
end

local function qsharp_host_project(context)
    return join_path(qsharp_host_root(context), "QSharpHost.csproj")
end

local function template_cache_root(context)
    return join_path(workspace_root(context), "template-cache")
end

local function collect_cache_metadata(context)
    return {
        reqpackRoot = data_root(context),
        workspaceRoot = workspace_root(context),
        dotnetHome = dotnet_home_root(context),
        nugetPackages = nuget_packages_root(context),
        toolPath = tool_path_root(context),
        toolLocal = tool_local_root(context),
        qsharpHost = qsharp_host_project(context),
        templateCache = template_cache_root(context),
    }
end

local function ensure_directory(context, path)
    local result = run_command(context, "mkdir -p " .. shell_quote(path))
    return result ~= nil and result.success == true
end

local function ensure_directories(context, paths)
    local cleaned = {}
    local seen = {}
    for _, path in ipairs(paths or {}) do
        local value = trim(path)
        if value ~= "" and not seen[value] then
            seen[value] = true
            cleaned[#cleaned + 1] = value
        end
    end

    if #cleaned == 0 then
        return true
    end

    local quoted = {}
    for _, path in ipairs(cleaned) do
        quoted[#quoted + 1] = shell_quote(path)
    end
    return is_command_success(run_command(context, "mkdir -p " .. table.concat(quoted, " ")))
end

local function read_file(path)
    local handle = io.open(path, "rb")
    if handle == nil then
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(path, content)
    local handle = io.open(path, "wb")
    if handle == nil then
        return false
    end
    handle:write(content or "")
    handle:close()
    return true
end

local function ensure_workspace(context)
    return ensure_directories(context, {
        workspace_root(context),
        dotnet_home_root(context),
        nuget_packages_root(context),
        tool_path_root(context),
        join_path(tool_local_root(context), ".config"),
        qsharp_host_root(context),
        template_cache_root(context),
    })
end

local function ensure_qsharp_host(context)
    if not ensure_workspace(context) then
        return false
    end

    local path = qsharp_host_project(context)
    if read_file(path) ~= nil then
        return true
    end

    return write_file(path, table.concat({
        '<Project Sdk="Microsoft.NET.Sdk">',
        '  <PropertyGroup>',
        '    <TargetFramework>net8.0</TargetFramework>',
        '  </PropertyGroup>',
        '</Project>',
        '',
    }, "\n"))
end

local function env_prefix(context)
    local parts = {
        ENV_LOCALE,
        "DOTNET_CLI_HOME=" .. shell_quote(dotnet_home_root(context)),
        "NUGET_PACKAGES=" .. shell_quote(nuget_packages_root(context)),
    }
    return table.concat(parts, " ")
end

local function run_dotnet(context, args)
    if not ensure_workspace(context) then
        return { success = false, stdout = "", stderr = "failed to prepare dotnet workspace", exitCode = 1 }
    end
    return run_command(context, env_prefix(context) .. " " .. build_command({ REQUIRED_BINARY, table.unpack(args or {}) }))
end

local function parse_package_spec(value)
    local raw = trim(value)
    if raw == "" then
        return { kind = "tool", raw = "", name = "", packageId = "" }
    end

    local detected_kind, rest = raw:match("^(%a+):(.*)$")
    local kind = nil
    if detected_kind == "tool" or detected_kind == "template" or detected_kind == "package" then
        kind = detected_kind
    end

    if kind == nil then
        kind = "tool"
        rest = raw
    end

    return {
        kind = kind,
        raw = raw,
        name = trim(rest),
        packageId = kind .. ":" .. trim(rest),
    }
end

local function package_name(pkg)
    local spec = parse_package_spec(read_field(pkg, "name") or read_field(pkg, "packageId") or "")
    return spec.name, spec.kind, spec.packageId
end

local function package_version(pkg)
    return trim(read_field(pkg, "version") or "")
end

local function parse_tool_list(output, scope)
    local items = {}
    local started = false
    for _, line in ipairs(split_lines(output)) do
        local text = trim(line)
        if text:match("^Package Id%s+Version") then
            started = true
        elseif started and text ~= "" and not text:match("^%-+$") then
            local package_id, version, rest = text:match("^(%S+)%s+(%S+)%s+(.+)$")
            if package_id ~= nil then
                local commands = trim(rest:match("^(%S+)") or rest)
                local manifest = trim(rest:match("(%S+/%.config/dotnet%-tools%.json)$") or "")
                items[#items + 1] = {
                    name = package_id,
                    packageId = "tool:" .. package_id,
                    packageType = "dotnet-tool",
                    type = "package",
                    installed = true,
                    status = "installed",
                    version = version,
                    latestVersion = version,
                    repository = "nuget.org via dotnet tool",
                    extraFields = {
                        kind = "tool",
                        scope = scope,
                        commands = commands,
                        manifest = manifest,
                    },
                }
            end
        end
    end
    return items
end

local function parse_tool_search(output)
    local items = {}
    local lines = split_lines(output)
    local mode = ""
    local current = nil

    for _, line in ipairs(lines) do
        local text = trim(line)
        if text:match("^Package ID%s+Latest Version") then
            mode = "table"
        elseif mode == "table" and text ~= "" and not text:match("^%-+$") then
            local package_id, version = text:match("^(%S+)%s+(%S+)%s+")
            if package_id ~= nil then
                items[#items + 1] = {
                    name = package_id,
                    packageId = "tool:" .. package_id,
                    packageType = "dotnet-tool",
                    type = "package",
                    installed = false,
                    status = "available",
                    version = version,
                    latestVersion = version,
                    repository = "nuget.org via dotnet tool",
                    extraFields = { kind = "tool" },
                }
            end
        elseif text == "----------------" then
            if current ~= nil then
                items[#items + 1] = current
            end
            current = nil
            mode = "detail"
        elseif mode == "detail" and text ~= "" then
            if current == nil then
                current = {
                    name = text,
                    packageId = "tool:" .. text,
                    packageType = "dotnet-tool",
                    type = "package",
                    installed = false,
                    status = "available",
                    repository = "nuget.org via dotnet tool",
                    extraFields = { kind = "tool" },
                }
            else
                local key, value = text:match("^([^:]+):%s*(.*)$")
                if key ~= nil then
                    local normalized = lower(trim(key))
                    if normalized == "latest version" then
                        current.version = trim(value)
                        current.latestVersion = trim(value)
                    elseif normalized == "description" then
                        current.summary = trim(value)
                        current.description = trim(value)
                    elseif normalized == "authors" then
                        current.extraFields.authors = trim(value)
                    elseif normalized == "verified" then
                        current.extraFields.verified = trim(value)
                    end
                end
            end
        end
    end
    if current ~= nil then
        items[#items + 1] = current
    end
    return items
end

local function parse_template_uninstall(output)
    local items = {}
    local current = nil
    for _, line in ipairs(split_lines(output)) do
        local raw = tostring(line or "")
        local text = trim(raw)
        if text == "Currently installed items:" or text == "" then
        elseif raw:match("^%s+%S") and not raw:match("^%s+Version:") and not raw:match("^%s+Details:") and not raw:match("^%s+Templates:") and not raw:match("^%s+Uninstall Command:") and not raw:match("^%s%s%s%s+") then
            if current ~= nil then
                items[#items + 1] = current
            end
            current = {
                name = text,
                packageId = "template:" .. text,
                packageType = "dotnet-template",
                type = "package",
                installed = true,
                status = "installed",
                repository = "nuget.org via dotnet new",
                extraFields = { kind = "template" },
            }
        elseif current ~= nil then
            local version = text:match("^Version:%s*(.+)$")
            if version ~= nil then
                current.version = trim(version)
                current.latestVersion = trim(version)
            end
            local author = text:match("^Author:%s*(.+)$")
            if author ~= nil then
                current.extraFields.author = trim(author)
            end
            local source = text:match("^NuGetSource:%s*(.+)$")
            if source ~= nil then
                current.extraFields.nugetSource = trim(source)
            end
            local uninstall = text:match("^dotnet new uninstall .+$")
            if uninstall ~= nil then
                current.extraFields.uninstallCommand = uninstall
            end
        end
    end
    if current ~= nil then
        items[#items + 1] = current
    end
    return items
end

local function parse_template_search(output)
    local items = {}
    local started = false
    for _, line in ipairs(split_lines(output)) do
        local text = trim(line)
        if text:match("^Template Name%s+Short Name") then
            started = true
        elseif started and text ~= "" and not text:match("^%-+$") then
            local name, short_name, language, package = text:match("^(.-)%s%s+(%S+)%s%s+(.-)%s%s+(%S+)$")
            if name ~= nil and name ~= "" then
                items[#items + 1] = {
                    name = trim(name),
                    packageId = "template:" .. trim(package ~= nil and package or name),
                    packageType = "dotnet-template",
                    type = "package",
                    installed = false,
                    status = "available",
                    repository = "nuget.org via dotnet new",
                    extraFields = {
                        kind = "template",
                        shortName = trim(short_name or ""),
                        language = trim(language or ""),
                    },
                }
            end
        end
    end
    return items
end

local function decode_json(input)
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
        advance(1)
        local parts = {}
        while true do
            local char = peek()
            if char == "" then
                error("unterminated string")
            elseif char == '"' then
                advance(1)
                return table.concat(parts)
            elseif char == "\\" then
                local esc = peek(1)
                if esc == '"' or esc == "\\" or esc == "/" then
                    parts[#parts + 1] = esc
                    advance(2)
                elseif esc == "b" then
                    parts[#parts + 1] = "\b"
                    advance(2)
                elseif esc == "f" then
                    parts[#parts + 1] = "\f"
                    advance(2)
                elseif esc == "n" then
                    parts[#parts + 1] = "\n"
                    advance(2)
                elseif esc == "r" then
                    parts[#parts + 1] = "\r"
                    advance(2)
                elseif esc == "t" then
                    parts[#parts + 1] = "\t"
                    advance(2)
                else
                    error("unsupported escape")
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
        while peek():match("%d") do
            advance(1)
        end
        if peek() == "." then
            advance(1)
            while peek():match("%d") do
                advance(1)
            end
        end
        local char = peek()
        if char == "e" or char == "E" then
            advance(1)
            char = peek()
            if char == "+" or char == "-" then
                advance(1)
            end
            while peek():match("%d") do
                advance(1)
            end
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
            if peek() == "," then
                advance(1)
                skip_whitespace()
            elseif peek() == "]" then
                advance(1)
                return result
            else
                error("invalid array")
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
            advance(1)
            skip_whitespace()
            result[key] = parse_value()
            skip_whitespace()
            if peek() == "," then
                advance(1)
                skip_whitespace()
            elseif peek() == "}" then
                advance(1)
                return result
            else
                error("invalid object")
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
        error("unexpected token")
    end

    return parse_value()
end

local function try_decode_json(input)
    local ok, value = pcall(decode_json, input)
    if ok then
        return value
    end
    return nil
end

local function parse_package_list_json(output)
    local decoded = try_decode_json(output)
    if type(decoded) ~= "table" then
        return {}
    end

    local projects = read_field(decoded, "projects") or {}
    local items = {}
    for _, project in ipairs(projects) do
        local frameworks = read_field(project, "frameworks") or {}
        for _, framework in ipairs(frameworks) do
            local top = read_field(framework, "topLevelPackages") or {}
            for _, entry in ipairs(top) do
                local name = trim(read_field(entry, "id") or "")
                if name ~= "" then
                    local requested = trim(read_field(entry, "requestedVersion") or "")
                    local resolved = trim(read_field(entry, "resolvedVersion") or requested)
                    local latest = trim(read_field(entry, "latestVersion") or resolved)
                    local auto = trim(read_field(entry, "autoReferenced") or "")
                    items[#items + 1] = {
                        name = name,
                        packageId = "package:" .. name,
                        packageType = "nuget-package",
                        type = "package",
                        installed = true,
                        status = latest ~= "" and resolved ~= "" and latest ~= resolved and "outdated" or "installed",
                        version = resolved ~= "" and resolved or requested,
                        latestVersion = latest ~= "" and latest or nil,
                        repository = "nuget via dotnet package",
                        extraFields = {
                            kind = "package",
                            framework = trim(read_field(framework, "framework") or ""),
                            requestedVersion = requested,
                            autoReferenced = auto,
                        },
                    }
                end
            end
        end
    end
    return items
end

local function tool_scope(flags)
    local explicit = lower(trim(flag_value(flags, "scope=")))
    if explicit == "local" or explicit == "path" or explicit == "global" then
        return explicit
    end
    return "global"
end

local function tool_manifest(flags, context)
    local explicit = trim(flag_value(flags, "tool-manifest="))
    if explicit ~= "" then
        return explicit
    end
    return tool_manifest_path(context)
end

local function tool_path(flags, context)
    local explicit = trim(flag_value(flags, "tool-path="))
    if explicit ~= "" then
        return explicit
    end
    return tool_path_root(context)
end

local function build_tool_args(command_name, package, context)
    local name = package_name(package)
    local version = package_version(package)
    local flags = collect_flags(context, package)
    local scope = tool_scope(flags)
    local args = { "tool", command_name }

    if command_name ~= "list" then
        args[#args + 1] = name
    end

    if scope == "global" then
        args[#args + 1] = "--global"
    elseif scope == "path" then
        args[#args + 1] = "--tool-path"
        args[#args + 1] = tool_path(flags, context)
    else
        args[#args + 1] = "--local"
        args[#args + 1] = "--tool-manifest"
        args[#args + 1] = tool_manifest(flags, context)
        if command_name == "install" and flag_present(flags, "create-manifest-if-needed") then
            args[#args + 1] = "--create-manifest-if-needed"
        end
    end

    append_option(args, "--version", version)
    append_option(args, "--source", flag_value(flags, "source="))
    append_option(args, "--framework", flag_value(flags, "framework="))
    append_option(args, "--arch", flag_value(flags, "arch="))
    if flag_present(flags, "prerelease") then
        args[#args + 1] = "--prerelease"
    end
    if flag_present(flags, "allow-downgrade") then
        args[#args + 1] = "--allow-downgrade"
    end
    if flag_present(flags, "allow-roll-forward") then
        args[#args + 1] = "--allow-roll-forward"
    end
    if flag_present(flags, "no-cache") then
        args[#args + 1] = "--no-cache"
    end
    return args
end

local function installed_tool_items(context)
    local items = {}
    local global = run_dotnet(context, { "tool", "list", "--global" })
    if is_command_success(global, { 0 }) then
        for _, item in ipairs(parse_tool_list(global.stdout, "global")) do
            items[#items + 1] = item
        end
    end

    local path_result = run_dotnet(context, { "tool", "list", "--tool-path", tool_path_root(context) })
    if is_command_success(path_result, { 0 }) then
        for _, item in ipairs(parse_tool_list(path_result.stdout, "path")) do
            items[#items + 1] = item
        end
    end

    local local_result = run_dotnet(context, { "tool", "list", "--local", "--tool-manifest", tool_manifest_path(context) })
    if is_command_success(local_result, { 0 }) then
        for _, item in ipairs(parse_tool_list(local_result.stdout, "local")) do
            items[#items + 1] = item
        end
    end

    return sorted_items(items)
end

local function installed_template_items(context)
    local result = run_dotnet(context, { "new", "uninstall" })
    if not is_command_success(result, { 0 }) then
        return {}
    end
    return sorted_items(parse_template_uninstall(result.stdout))
end

local function package_project_from_flags(flags, context)
    local explicit = trim(flag_value(flags, "project="))
    if explicit ~= "" then
        return explicit
    end
    return qsharp_host_project(context)
end

local function build_package_list_args(package, context, outdated)
    local flags = collect_flags(context, package)
    local project = package_project_from_flags(flags, context)
    local args = { "package", "list", "--project", project, "--format", "json", "--output-version", "1" }
    append_option(args, "--framework", flag_value(flags, "framework="))
    append_option(args, "--source", flag_value(flags, "source="))
    if flag_present(flags, "include-prerelease") or flag_present(flags, "prerelease") then
        args[#args + 1] = "--include-prerelease"
    end
    if outdated then
        args[#args + 1] = "--outdated"
    end
    return args
end

local function installed_package_items(context)
    local flags = collect_flags(context, nil)
    if trim(flag_value(flags, "project=")) == "" and not ensure_qsharp_host(context) then
        return {}
    end
    local result = run_dotnet(context, build_package_list_args(nil, context, false))
    if not is_command_success(result, { 0 }) then
        return {}
    end
    return sorted_items(parse_package_list_json(result.stdout))
end

local function outdated_package_items(context)
    local flags = collect_flags(context, nil)
    if trim(flag_value(flags, "project=")) == "" and not ensure_qsharp_host(context) then
        return {}
    end
    local result = run_dotnet(context, build_package_list_args(nil, context, true))
    if not is_command_success(result, { 0 }) then
        return {}
    end
    local items = parse_package_list_json(result.stdout)
    local filtered = {}
    for _, item in ipairs(items) do
        if item.status == "outdated" then
            filtered[#filtered + 1] = item
        end
    end
    return sorted_items(filtered)
end

local function build_package_mutation_args(command_name, package, context)
    local name = package_name(package)
    local version = package_version(package)
    local flags = collect_flags(context, package)
    local project = package_project_from_flags(flags, context)
    local args = { "package", command_name, name, "--project", project }
    append_option(args, "--framework", flag_value(flags, "framework="))
    append_option(args, "--source", flag_value(flags, "source="))
    append_option(args, "--package-directory", flag_value(flags, "package-directory="))
    if command_name == "add" then
        append_option(args, "--version", version)
        if flag_present(flags, "prerelease") then
            args[#args + 1] = "--prerelease"
        end
        if flag_present(flags, "no-restore") then
            args[#args + 1] = "--no-restore"
        end
    end
    return args
end

local function template_search_items(context, prompt)
    local query = trim(prompt)
    if query == "" then
        return {}
    end
    local result = run_dotnet(context, { "new", "search", query })
    if not is_command_success(result, { 0 }) then
        return {}
    end
    return sorted_items(parse_template_search(result.stdout))
end

local function tool_search_items(context, prompt)
    local query = trim(prompt)
    if query == "" then
        return {}
    end
    local args = { "tool", "search", query, "--take", tostring(SEARCH_LIMIT) }
    if flag_present(collect_flags(context, nil), "prerelease") then
        args[#args + 1] = "--prerelease"
    end
    local result = run_dotnet(context, args)
    if not is_command_success(result, { 0 }) then
        return {}
    end
    return sorted_items(parse_tool_search(result.stdout))
end

local function list_all_items(context)
    local items = {}
    for _, item in ipairs(installed_tool_items(context)) do
        item.cache = shallow_copy(collect_cache_metadata(context))
        items[#items + 1] = item
    end
    for _, item in ipairs(installed_template_items(context)) do
        item.cache = shallow_copy(collect_cache_metadata(context))
        items[#items + 1] = item
    end
    for _, item in ipairs(installed_package_items(context)) do
        item.cache = shallow_copy(collect_cache_metadata(context))
        items[#items + 1] = item
    end
    return items
end

local function find_by_package_id(items, wanted)
    local target = lower(trim(wanted))
    for _, item in ipairs(items or {}) do
        if lower(trim(item.packageId or item.name or "")) == target or lower(trim(item.name or "")) == target then
            return item
        end
    end
    return nil
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
    return { "Cross Platform", "Dotnet", "Q#", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    local installed = list_all_items(nil)
    local missing = {}
    for _, pkg in ipairs(packages or {}) do
        local name, _, package_id = package_name(pkg)
        local action = lower(trim(read_field(pkg, "action") or "install"))
        local found = find_by_package_id(installed, package_id)
        if name ~= "" then
            if action == "remove" then
                if found ~= nil then
                    missing[#missing + 1] = pkg
                end
            elseif action == "update" then
                if found ~= nil then
                    missing[#missing + 1] = pkg
                end
            elseif found == nil then
                missing[#missing + 1] = pkg
            end
        end
    end
    return missing
end

function plugin.install(context, packages)
    local local_path = trim(read_field(context, "path") or read_field(context, "localPath") or read_field(read_field(context, "request"), "path") or read_field(read_field(context, "request"), "localPath") or "")
    if local_path ~= "" then
        return plugin.installLocal(context, local_path)
    end

    if packages == nil or #packages == 0 then
        return true
    end

    begin_step(context, "install dotnet packages")
    for _, pkg in ipairs(packages) do
        local name, kind = package_name(pkg)
        local result = nil
        if kind == "tool" then
            result = run_dotnet(context, build_tool_args("install", pkg, context))
        elseif kind == "template" then
            result = run_dotnet(context, { "new", "install", name .. (package_version(pkg) ~= "" and ("@" .. package_version(pkg)) or "") })
        else
            local flags = collect_flags(context, pkg)
            if trim(flag_value(flags, "project=")) == "" and not ensure_qsharp_host(context) then
                tx_failed(context, "failed to prepare shared Q# host project")
                return false
            end
            result = run_dotnet(context, build_package_mutation_args("add", pkg, context))
        end
        if not is_command_success(result, { 0 }) then
            tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "dotnet install failed")
            return false
        end
    end
    emit_event(context, "installed", packages)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    begin_step(context, "install local dotnet artifact")
    if lower(local_path):sub(-6) ~= ".nupkg" then
        tx_failed(context, "dotnet local install only supports template .nupkg packages")
        return false
    end

    local result = run_dotnet(context, { "new", "install", local_path })
    if not is_command_success(result, { 0 }) then
        tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "dotnet local install failed")
        return false
    end

    emit_event(context, "installed", { path = local_path, localTarget = true, packageType = "dotnet-template" })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    if packages == nil or #packages == 0 then
        return true
    end

    begin_step(context, "remove dotnet packages")
    for _, pkg in ipairs(packages) do
        local name, kind = package_name(pkg)
        local result = nil
        if kind == "tool" then
            result = run_dotnet(context, build_tool_args("uninstall", pkg, context))
        elseif kind == "template" then
            result = run_dotnet(context, { "new", "uninstall", name })
        else
            local flags = collect_flags(context, pkg)
            if trim(flag_value(flags, "project=")) == "" and not ensure_qsharp_host(context) then
                tx_failed(context, "failed to prepare shared Q# host project")
                return false
            end
            result = run_dotnet(context, build_package_mutation_args("remove", pkg, context))
        end
        if not is_command_success(result, { 0 }) then
            tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "dotnet remove failed")
            return false
        end
    end
    emit_event(context, "deleted", packages)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    if packages == nil or #packages == 0 then
        begin_step(context, "update dotnet packages")
        local result = run_dotnet(context, { "new", "update" })
        if not is_command_success(result, { 0 }) then
            tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "dotnet update failed")
            return false
        end
        emit_event(context, "updated", {})
        tx_success(context)
        return true
    end

    begin_step(context, "update dotnet packages")
    for _, pkg in ipairs(packages) do
        local _, kind = package_name(pkg)
        local result = nil
        if kind == "tool" then
            result = run_dotnet(context, build_tool_args("update", pkg, context))
        elseif kind == "template" then
            result = run_dotnet(context, { "new", "update" })
        else
            local flags = collect_flags(context, pkg)
            if trim(flag_value(flags, "project=")) == "" and not ensure_qsharp_host(context) then
                tx_failed(context, "failed to prepare shared Q# host project")
                return false
            end
            result = run_dotnet(context, build_package_mutation_args("add", pkg, context))
        end
        if not is_command_success(result, { 0 }) then
            tx_failed(context, trim(result.stderr) ~= "" and trim(result.stderr) or "dotnet update failed")
            return false
        end
    end
    emit_event(context, "updated", packages)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = list_all_items(context)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items = {}
    local template_check = run_dotnet(context, { "new", "update", "--check-only" })
    if is_command_success(template_check, { 0 }) then
        local updates = parse_template_uninstall(template_check.stdout)
        for _, item in ipairs(updates) do
            item.status = "outdated"
            items[#items + 1] = item
        end
    end
    for _, item in ipairs(outdated_package_items(context)) do
        items[#items + 1] = item
    end
    log_warn(context, "dotnet tool CLI has no reliable bulk outdated listing; tool updates omitted")
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
    local items = {}
    for _, item in ipairs(tool_search_items(context, query)) do
        item.cache = shallow_copy(collect_cache_metadata(context))
        items[#items + 1] = item
    end
    for _, item in ipairs(template_search_items(context, query)) do
        item.cache = shallow_copy(collect_cache_metadata(context))
        items[#items + 1] = item
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local spec = parse_package_spec(name or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
    local item = {}
    if spec.name ~= "" then
        if spec.kind == "tool" then
            item = find_by_package_id(installed_tool_items(context), spec.packageId)
            if item == nil then
                item = parse_tool_search(run_dotnet(context, { "tool", "search", spec.name, "--detail", "--take", "1" }).stdout)[1] or {}
            end
        elseif spec.kind == "template" then
            item = find_by_package_id(installed_template_items(context), spec.packageId)
            if item == nil then
                item = template_search_items(context, spec.name)[1] or {}
            end
        else
            local installed = installed_package_items(context)
            item = find_by_package_id(installed, spec.packageId) or {}
            if next(item) == nil then
                local outdated = outdated_package_items(context)
                item = find_by_package_id(outdated, spec.packageId) or {}
            end
        end
        if type(item) == "table" and next(item) ~= nil then
            item.cache = shallow_copy(collect_cache_metadata(context))
        end
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end
    local _, _, package_id = package_name(package)
    if package_id == "" then
        return nil
    end
    local item = plugin.info(context, package_id)
    if type(item) ~= "table" or next(item) == nil then
        return nil
    end
    local resolved = shallow_copy(package)
    for key, value in pairs(item) do
        resolved[key] = value
    end
    return resolved
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "filesystem.write", "filesystem.read", "network" },
        ecosystemScopes = { "dotnet", "nuget", "qsharp" },
        writeScopes = {
            {
                path = join_path(get_plugin_dir(), ".reqpack-data", PLUGIN_ID),
                reason = "ReqPack-managed dotnet shared workspace, tool manifests, host project, and NuGet cache",
            },
        },
        networkScopes = {
            {
                scheme = "https",
                host = "*",
                reason = "dotnet resolves tools, templates, and NuGet packages from configured package feeds",
            },
        },
        privilegeLevel = "none",
        osvEcosystem = "NuGet",
        purlType = "nuget",
    }
end

function plugin.init()
    return command_exists(REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

return plugin
