plugin = {}
plugin.fileExtensions = { ".tar.gz", ".tgz", ".zip" }

local PLUGIN_NAME = "CRAN"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "Rscript"
local DEFAULT_REPOSITORY = "https://cloud.r-project.org"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
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
        if line ~= "" then
            lines[#lines + 1] = line
        end
    end
    return lines
end

local function split_tabs(line)
    local fields = {}
    for field in (tostring(line or "") .. "\t"):gmatch("(.-)\t") do
        fields[#fields + 1] = field
    end
    return fields
end

local function split_csv(value)
    local items = {}
    for item in tostring(value or ""):gmatch("([^,]+)") do
        local cleaned = trim(item)
        if cleaned ~= "" then
            items[#items + 1] = cleaned
        end
    end
    return items
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
    return table.concat(parts, "/")
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function r_quote(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\")
    text = text:gsub('"', '\\"')
    text = text:gsub("\n", "\\n")
    text = text:gsub("\r", "\\r")
    return '"' .. text .. '"'
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

local function run_exec(context, command)
    local result = nil
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        result = context.exec.run(command)
    elseif reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
        result = reqpack.exec.run(command)
    else
        result = {
            success = false,
            stdout = "",
            stderr = "missing ReqPack exec runner",
            exitCode = 127,
        }
    end

    local value_type = type(result)
    if value_type == "table" then
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

    if value_type == "userdata" then
        local normalized = {}
        for _, key in ipairs({ "success", "ok", "exitCode", "exit_code", "code", "status", "stdout", "stdoutText", "stderr", "stderrText" }) do
            local ok, value = pcall(function()
                return result[key]
            end)
            if ok and value ~= nil then
                normalized[key] = value
            end
        end

        if normalized.stdout == nil then
            normalized.stdout = normalized.stdoutText or ""
        end
        if normalized.stderr == nil then
            normalized.stderr = normalized.stderrText or ""
        end
        if normalized.exitCode == nil then
            normalized.exitCode = normalized.exit_code or normalized.code or normalized.status
        end
        if normalized.success == nil and normalized.ok ~= nil then
            normalized.success = normalized.ok
        end
        if normalized.success == nil and normalized.exitCode ~= nil then
            normalized.success = normalized.exitCode == 0
        end
        return normalized
    end

    return {
        success = false,
        stdout = "",
        stderr = "command execution failed",
        exitCode = 1,
    }
end

local function command_exists(context, binary)
    local result = run_exec(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function get_plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR)
    if dir ~= "" then
        return dir
    end
    return "."
end

local function flag_value(flags, prefix)
    local needle = trim(prefix)
    for _, flag in ipairs(flags or {}) do
        local cleaned = trim(flag)
        if cleaned:sub(1, #needle) == needle then
            return trim(cleaned:sub(#needle + 1))
        end
    end
    return ""
end

local function package_name(pkg)
    return trim(read_field(pkg, "name") or read_field(pkg, "packageName") or read_field(pkg, "packageId"))
end

local function package_version(pkg)
    return trim(read_field(pkg, "version"))
end

local function package_action(pkg)
    return lower(trim(read_field(pkg, "action") or read_field(pkg, "requestedAction")))
end

local function normalize_package(pkg)
    local name = package_name(pkg)
    if name == "" then
        return nil, "missing CRAN package name"
    end
    return {
        name = name,
        version = package_version(pkg),
        raw = pkg,
    }, nil
end

local function data_root_from_context(context, packages)
    local context_flags = context and context.flags or {}
    local from_context = flag_value(context_flags, "data-root=")
    if from_context ~= "" then
        return from_context
    end

    for _, pkg in ipairs(packages or {}) do
        local from_package = flag_value(object_flags(pkg), "data-root=")
        if from_package ~= "" then
            return from_package
        end
    end

    local fixture_root = os ~= nil and type(os.getenv) == "function" and trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT")) or ""
    if fixture_root ~= "" then
        return join_path(fixture_root, ".reqpack-data")
    end

    return join_path(get_plugin_dir(), ".reqpack-data")
end

local function state_paths(root)
    local base = trim(root)
    if base == "" then
        base = join_path(get_plugin_dir(), ".reqpack-data")
    end
    return {
        root = base,
        library = join_path(base, "library"),
        cache = join_path(base, "cache"),
        config = join_path(base, "config"),
        tmp = join_path(base, "tmp"),
    }
end

local function repository_from_context(context, packages)
    local context_flags = context and context.flags or {}
    local repo = flag_value(context_flags, "repo=")
    if repo == "" then
        repo = flag_value(context_flags, "repos=")
    end
    if repo ~= "" then
        return repo
    end

    for _, pkg in ipairs(packages or {}) do
        local flags = object_flags(pkg)
        repo = flag_value(flags, "repo=")
        if repo == "" then
            repo = flag_value(flags, "repos=")
        end
        if repo ~= "" then
            return repo
        end
    end

    return DEFAULT_REPOSITORY
end

local function dependencies_expression(context, packages)
    local context_flags = context and context.flags or {}
    local value = lower(flag_value(context_flags, "dependencies="))
    if value == "" then
        for _, pkg in ipairs(packages or {}) do
            value = lower(flag_value(object_flags(pkg), "dependencies="))
            if value ~= "" then
                break
            end
        end
    end

    if value == "true" or value == "yes" or value == "1" then
        return "TRUE"
    end
    if value == "false" or value == "no" or value == "0" then
        return "FALSE"
    end
    return "NA"
end

local function env_prefix(paths)
    return table.concat({
        "R_LIBS_USER=" .. shell_quote(paths.library),
        "XDG_CACHE_HOME=" .. shell_quote(paths.cache),
        "XDG_CONFIG_HOME=" .. shell_quote(paths.config),
        "TMPDIR=" .. shell_quote(paths.tmp),
        "R_PACKAGES_CACHE_USER_DIR=TRUE",
        "R_ENVIRON_USER=/dev/null",
        "R_PROFILE_USER=/dev/null",
        "LC_ALL=C",
        "LANG=C",
        "LANGUAGE=C",
    }, " ")
end

local function r_setup(paths, repository)
    return table.concat({
        "lib <- " .. r_quote(paths.library) .. ";",
        "repo <- " .. r_quote(repository) .. ";",
        "dir.create(lib, recursive = TRUE, showWarnings = FALSE);",
        "dir.create(Sys.getenv(\"XDG_CACHE_HOME\"), recursive = TRUE, showWarnings = FALSE);",
        "dir.create(Sys.getenv(\"XDG_CONFIG_HOME\"), recursive = TRUE, showWarnings = FALSE);",
        "dir.create(Sys.getenv(\"TMPDIR\"), recursive = TRUE, showWarnings = FALSE);",
        "options(repos = c(CRAN = repo));",
        "field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(\"\"); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(\"\"); gsub(\"[\\t\\r\\n]+\", \" \", value); };",
        "row_out <- function(values) { cat(paste(vapply(values, field, \"\"), collapse = \"\\t\"), \"\\n\", sep = \"\"); };",
    }, " ")
end

local function rscript_command(paths, repository, body)
    local code = r_setup(paths, repository) .. " " .. body
    return env_prefix(paths) .. " " .. REQUIRED_BINARY .. " --vanilla -e " .. shell_quote(code)
end

local function append_unique(target, value)
    local cleaned = trim(value)
    if cleaned == "" then
        return
    end
    for _, existing in ipairs(target) do
        if existing == cleaned then
            return
        end
    end
    target[#target + 1] = cleaned
end

local function parse_dependencies(...)
    local items = {}
    for index = 1, select("#", ...) do
        local raw = trim(select(index, ...))
        if raw ~= "" and raw ~= "NA" then
            for _, part in ipairs(split_csv(raw)) do
                local cleaned = trim(part:gsub("%s*%b()", ""))
                cleaned = trim(cleaned:gsub("%s*%[.*%]", ""))
                if cleaned ~= "" and lower(cleaned) ~= "r" then
                    append_unique(items, cleaned)
                end
            end
        end
    end
    return items
end

local function make_extra_fields(values)
    local extra = {}
    for key, value in pairs(values or {}) do
        if value ~= nil and trim(value) ~= "" then
            extra[key] = value
        end
    end
    if next(extra) == nil then
        return nil
    end
    return extra
end

local function map_installed_record(record, repository)
    return {
        name = record.name,
        packageId = record.name,
        version = record.version,
        latestVersion = record.version,
        installed = true,
        status = "installed",
        summary = record.description,
        description = record.description,
        license = trim(record.license) ~= "" and record.license or nil,
        homepage = trim(record.url) ~= "" and record.url or nil,
        repository = repository,
        packageType = "r-package",
        dependencies = parse_dependencies(record.depends, record.imports, record.suggests),
        extraFields = make_extra_fields({
            libPath = record.libPath,
            priority = record.priority,
            needsCompilation = record.needsCompilation,
            built = record.built,
        }),
    }
end

local function map_remote_record(record, repository, installed_version)
    local installed = trim(installed_version) ~= ""
    return {
        name = record.name,
        packageId = record.name,
        version = installed and installed_version or record.version,
        latestVersion = record.version,
        installed = installed,
        status = installed and "installed" or "available",
        summary = record.description,
        description = record.description,
        license = trim(record.license) ~= "" and record.license or nil,
        homepage = trim(record.url) ~= "" and record.url or nil,
        repository = trim(record.repository) ~= "" and record.repository or repository,
        packageType = "r-package",
        dependencies = parse_dependencies(record.depends, record.imports, record.suggests),
        extraFields = make_extra_fields({
            needsCompilation = record.needsCompilation,
            priority = record.priority,
        }),
    }
end

local function parse_installed_items(raw, repository)
    local items = {}
    for _, line in ipairs(split_lines(raw)) do
        local fields = split_tabs(line)
        if #fields >= 12 then
            items[#items + 1] = map_installed_record({
                name = fields[1],
                version = fields[2],
                libPath = fields[3],
                priority = fields[4],
                description = fields[5],
                license = fields[6],
                url = fields[7],
                needsCompilation = fields[8],
                built = fields[9],
                depends = fields[10],
                imports = fields[11],
                suggests = fields[12],
            }, repository)
        end
    end
    return items
end

local function parse_outdated_items(raw)
    local items = {}
    for _, line in ipairs(split_lines(raw)) do
        local fields = split_tabs(line)
        if #fields >= 13 then
            items[#items + 1] = {
                name = fields[1],
                packageId = fields[1],
                version = fields[2],
                latestVersion = fields[3],
                installed = true,
                status = "outdated",
                summary = fields[6],
                description = fields[6],
                license = trim(fields[7]) ~= "" and fields[7] or nil,
                homepage = trim(fields[8]) ~= "" and fields[8] or nil,
                repository = trim(fields[4]) ~= "" and fields[4] or nil,
                packageType = "r-package",
                dependencies = parse_dependencies(fields[10], fields[11], fields[12]),
                extraFields = make_extra_fields({
                    libPath = fields[5],
                    needsCompilation = fields[9],
                    built = fields[13],
                }),
            }
        end
    end
    return items
end

local function parse_search_items(raw, repository)
    local items = {}
    for _, line in ipairs(split_lines(raw)) do
        local fields = split_tabs(line)
        if #fields >= 11 then
            items[#items + 1] = {
                name = fields[1],
                packageId = fields[1],
                version = fields[2],
                latestVersion = fields[2],
                installed = fields[3] == "true",
                status = fields[3] == "true" and "installed" or "available",
                summary = fields[4],
                description = fields[4],
                license = trim(fields[5]) ~= "" and fields[5] or nil,
                homepage = trim(fields[6]) ~= "" and fields[6] or nil,
                repository = trim(fields[7]) ~= "" and fields[7] or repository,
                packageType = "r-package",
                dependencies = parse_dependencies(fields[9], fields[10], fields[11]),
                extraFields = make_extra_fields({
                    needsCompilation = fields[8],
                }),
            }
        end
    end
    return items
end

local function combine_info_records(local_record, remote_record, repository)
    if local_record == nil and remote_record == nil then
        return {}
    end
    if local_record ~= nil and remote_record == nil then
        return map_installed_record(local_record, repository)
    end
    if local_record == nil and remote_record ~= nil then
        return map_remote_record(remote_record, repository, nil)
    end

    local item = map_remote_record(remote_record, repository, local_record.version)
    item.status = item.latestVersion ~= local_record.version and "outdated" or "installed"
    item.summary = trim(remote_record.description) ~= "" and remote_record.description or local_record.description
    item.description = item.summary
    item.license = trim(remote_record.license) ~= "" and remote_record.license or (trim(local_record.license) ~= "" and local_record.license or nil)
    item.homepage = trim(remote_record.url) ~= "" and remote_record.url or (trim(local_record.url) ~= "" and local_record.url or nil)
    item.dependencies = parse_dependencies(remote_record.depends, remote_record.imports, remote_record.suggests, local_record.depends, local_record.imports, local_record.suggests)
    item.extraFields = make_extra_fields({
        libPath = local_record.libPath,
        priority = local_record.priority,
        needsCompilation = trim(remote_record.needsCompilation) ~= "" and remote_record.needsCompilation or local_record.needsCompilation,
        built = local_record.built,
    })
    return item
end

local function installed_query_command(paths, repository)
    local fields = r_quote("c(\"Priority\",\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Built\",\"Depends\",\"Imports\",\"Suggests\")")
    local body = table.concat({
        "fields <- eval(parse(text = " .. fields .. "));",
        "db <- utils::installed.packages(lib.loc = lib, noCache = TRUE, fields = fields);",
        "if (nrow(db) > 0L) { for (i in seq_len(nrow(db))) row_out(list(db[i, \"Package\"], db[i, \"Version\"], db[i, \"LibPath\"], db[i, \"Priority\"], db[i, \"Description\"], db[i, \"License\"], db[i, \"URL\"], db[i, \"NeedsCompilation\"], db[i, \"Built\"], db[i, \"Depends\"], db[i, \"Imports\"], db[i, \"Suggests\"])); }",
    }, " ")
    return rscript_command(paths, repository, body)
end

local function search_query_command(paths, repository, prompt)
    local body = table.concat({
        "target <- tolower(" .. r_quote(prompt) .. ");",
        "fields <- c(\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Repository\",\"Depends\",\"Imports\",\"Suggests\");",
        "avail <- utils::available.packages(repos = repo, fields = fields, cache_user_dir = TRUE);",
        "installed <- utils::installed.packages(lib.loc = lib, noCache = TRUE);",
        "installed_names <- if (nrow(installed) > 0L) rownames(installed) else character();",
        "if (nrow(avail) > 0L) { desc <- ifelse(is.na(avail[, \"Description\"]), \"\", avail[, \"Description\"]); mask <- grepl(target, tolower(avail[, \"Package\"]), fixed = TRUE) | grepl(target, tolower(desc), fixed = TRUE); rows <- which(mask); if (length(rows) > 0L) { rows <- rows[order(avail[rows, \"Package\"])]; if (length(rows) > 50L) rows <- rows[seq_len(50L)]; for (i in rows) row_out(list(avail[i, \"Package\"], avail[i, \"Version\"], if (avail[i, \"Package\"] %in% installed_names) \"true\" else \"false\", avail[i, \"Description\"], avail[i, \"License\"], avail[i, \"URL\"], avail[i, \"Repository\"], avail[i, \"NeedsCompilation\"], avail[i, \"Depends\"], avail[i, \"Imports\"], avail[i, \"Suggests\"])); } } }",
    }, " ")
    return rscript_command(paths, repository, body)
end

local function outdated_query_command(paths, repository)
    local body = table.concat({
        "fields <- c(\"Priority\",\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Built\",\"Depends\",\"Imports\",\"Suggests\");",
        "inst <- utils::installed.packages(lib.loc = lib, noCache = TRUE, fields = fields);",
        "if (nrow(inst) > 0L) { avail <- utils::available.packages(repos = repo, fields = c(\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Repository\",\"Depends\",\"Imports\",\"Suggests\"), cache_user_dir = TRUE); old <- utils::old.packages(lib.loc = lib, repos = repo, instPkgs = inst, available = avail); if (!is.null(old) && nrow(old) > 0L) { for (i in seq_len(nrow(old))) { name <- old[i, \"Package\"]; row_out(list(name, old[i, \"Installed\"], old[i, \"ReposVer\"], old[i, \"Repository\"], old[i, \"LibPath\"], inst[name, \"Description\"], inst[name, \"License\"], inst[name, \"URL\"], inst[name, \"NeedsCompilation\"], inst[name, \"Depends\"], inst[name, \"Imports\"], inst[name, \"Suggests\"], inst[name, \"Built\"])); } } }",
    }, " ")
    return rscript_command(paths, repository, body)
end

local function info_query_command(paths, repository, name)
    local body = table.concat({
        "target <- " .. r_quote(name) .. ";",
        "fields <- c(\"Priority\",\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Built\",\"Depends\",\"Imports\",\"Suggests\");",
        "inst <- utils::installed.packages(lib.loc = lib, noCache = TRUE, fields = fields);",
        "if (nrow(inst) > 0L && target %in% rownames(inst)) row_out(list(\"local\", target, inst[target, \"Version\"], inst[target, \"LibPath\"], inst[target, \"Priority\"], inst[target, \"Description\"], inst[target, \"License\"], inst[target, \"URL\"], inst[target, \"NeedsCompilation\"], inst[target, \"Built\"], inst[target, \"Depends\"], inst[target, \"Imports\"], inst[target, \"Suggests\"]));",
        "avail <- utils::available.packages(repos = repo, fields = c(\"Priority\",\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Repository\",\"Depends\",\"Imports\",\"Suggests\"), cache_user_dir = TRUE);",
        "if (nrow(avail) > 0L && target %in% rownames(avail)) row_out(list(\"remote\", target, avail[target, \"Version\"], avail[target, \"Repository\"], avail[target, \"Priority\"], avail[target, \"Description\"], avail[target, \"License\"], avail[target, \"URL\"], avail[target, \"NeedsCompilation\"], \"\", avail[target, \"Depends\"], avail[target, \"Imports\"], avail[target, \"Suggests\"]));",
    }, " ")
    return rscript_command(paths, repository, body)
end

local function query_installed(context, paths, repository)
    local result = run_exec(context, installed_query_command(paths, repository))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_installed_items(result.stdout, repository)
end

local function query_outdated(context, paths, repository)
    local result = run_exec(context, outdated_query_command(paths, repository))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_outdated_items(result.stdout)
end

local function query_search(context, paths, repository, prompt)
    local result = run_exec(context, search_query_command(paths, repository, prompt))
    if result == nil or result.success ~= true then
        return nil
    end
    return parse_search_items(result.stdout, repository)
end

local function query_info(context, paths, repository, name)
    local result = run_exec(context, info_query_command(paths, repository, name))
    if result == nil or result.success ~= true then
        return nil
    end

    local local_record = nil
    local remote_record = nil
    for _, line in ipairs(split_lines(result.stdout)) do
        local fields = split_tabs(line)
        if #fields >= 13 then
            local record = {
                name = fields[2],
                version = fields[3],
                libPath = fields[4],
                priority = fields[5],
                description = fields[6],
                license = fields[7],
                url = fields[8],
                needsCompilation = fields[9],
                built = fields[10],
                depends = fields[11],
                imports = fields[12],
                suggests = fields[13],
                repository = fields[4],
            }
            if fields[1] == "local" then
                local_record = record
            elseif fields[1] == "remote" then
                remote_record = record
            end
        end
    end

    return combine_info_records(local_record, remote_record, repository)
end

local function failure(context, message)
    tx_failed(context, message)
    return false
end

local function read_available(context)
    local ok = command_exists(context, REQUIRED_BINARY)
    if ok then
        return true, nil
    end
    return false, REQUIRED_BINARY .. " binary not available"
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
    return { "R", "Package Manager" }
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
        ecosystemScopes = { "cran" },
        writeScopes = {},
        networkScopes = { "https://cloud.r-project.org" },
        privilegeLevel = "none",
        osvEcosystem = "CRAN",
        purlType = "cran",
    }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end

    local available = command_exists(nil, REQUIRED_BINARY)
    if not available then
        local filtered = {}
        for _, pkg in ipairs(packages) do
            local action = package_action(pkg)
            if action == "install" or action == "" then
                filtered[#filtered + 1] = pkg
            end
        end
        return filtered
    end

    local paths = state_paths(data_root_from_context(nil, packages))
    local repository = repository_from_context(nil, packages)
    local installed_items = query_installed(nil, paths, repository)
    if installed_items == nil then
        return packages
    end

    local installed_set = {}
    for _, item in ipairs(installed_items) do
        installed_set[lower(item.name)] = true
    end

    local outdated_set = {}
    local need_outdated = false
    for _, pkg in ipairs(packages) do
        if package_action(pkg) == "update" then
            need_outdated = true
            break
        end
    end
    if need_outdated then
        local outdated_items = query_outdated(nil, paths, repository)
        if outdated_items == nil then
            return packages
        end
        for _, item in ipairs(outdated_items) do
            outdated_set[lower(item.name)] = true
        end
    end

    local filtered = {}
    for _, pkg in ipairs(packages) do
        local action = package_action(pkg)
        local name = lower(package_name(pkg))
        if action == "remove" then
            if installed_set[name] == true then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "update" then
            if outdated_set[name] == true then
                filtered[#filtered + 1] = pkg
            end
        elseif installed_set[name] ~= true then
            filtered[#filtered + 1] = pkg
        end
    end
    return filtered
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end

    local available, message = read_available(context)
    if not available then
        return failure(context, message)
    end

    local normalized = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return failure(context, err)
        end
        normalized[#normalized + 1] = pkg
    end

    begin_step(context, "install CRAN packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local repository = repository_from_context(context, requested)
    local package_names = {}
    for _, pkg in ipairs(normalized) do
        package_names[#package_names + 1] = r_quote(pkg.name)
    end
    local body = table.concat({
        "utils::install.packages(pkgs = c(" .. table.concat(package_names, ",") .. "), lib = lib, repos = repo, quiet = TRUE, dependencies = " .. dependencies_expression(context, requested) .. ");",
    }, " ")
    local result = run_exec(context, rscript_command(paths, repository, body))
    if result == nil or result.success ~= true then
        return failure(context, "CRAN install failed")
    end

    local installed = {}
    for _, pkg in ipairs(normalized) do
        installed[#installed + 1] = {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "r-package",
        }
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.installLocal(context, path)
    local source_path = trim(path or read_field(context, "localPath") or read_field(context, "path"))
    if source_path == "" then
        return failure(context, "missing local CRAN package path")
    end

    local available, message = read_available(context)
    if not available then
        return failure(context, message)
    end

    begin_step(context, "install local CRAN package")
    local paths = state_paths(data_root_from_context(context, {}))
    local repository = repository_from_context(context, {})
    local body = "utils::install.packages(pkgs = " .. r_quote(source_path) .. ", lib = lib, repos = NULL, quiet = TRUE);"
    local result = run_exec(context, rscript_command(paths, repository, body))
    if result == nil or result.success ~= true then
        return failure(context, "CRAN local install failed")
    end

    emit_event(context, "installed", { { path = source_path, localTarget = true, packageType = "r-package" } })
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end

    local available, message = read_available(context)
    if not available then
        return failure(context, message)
    end

    local normalized = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return failure(context, err)
        end
        normalized[#normalized + 1] = pkg
    end

    begin_step(context, "remove CRAN packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local repository = repository_from_context(context, requested)
    local package_names = {}
    for _, pkg in ipairs(normalized) do
        package_names[#package_names + 1] = r_quote(pkg.name)
    end
    local body = "utils::remove.packages(pkgs = c(" .. table.concat(package_names, ",") .. "), lib = lib);"
    local result = run_exec(context, rscript_command(paths, repository, body))
    if result == nil or result.success ~= true then
        return failure(context, "CRAN remove failed")
    end

    local deleted = {}
    for _, pkg in ipairs(normalized) do
        deleted[#deleted + 1] = {
            name = pkg.name,
            packageId = pkg.name,
            packageType = "r-package",
        }
    end
    emit_event(context, "deleted", deleted)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        tx_success(context)
        return true
    end

    local available, message = read_available(context)
    if not available then
        return failure(context, message)
    end

    local normalized = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return failure(context, err)
        end
        normalized[#normalized + 1] = pkg
    end

    begin_step(context, "update CRAN packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local repository = repository_from_context(context, requested)
    local package_names = {}
    for _, pkg in ipairs(normalized) do
        package_names[#package_names + 1] = r_quote(pkg.name)
    end
    local body = "utils::install.packages(pkgs = c(" .. table.concat(package_names, ",") .. "), lib = lib, repos = repo, quiet = TRUE, dependencies = " .. dependencies_expression(context, requested) .. ");"
    local result = run_exec(context, rscript_command(paths, repository, body))
    if result == nil or result.success ~= true then
        return failure(context, "CRAN update failed")
    end

    local updated = {}
    for _, pkg in ipairs(normalized) do
        updated[#updated + 1] = {
            name = pkg.name,
            packageId = pkg.name,
            packageType = "r-package",
        }
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.list(context)
    local available, message = read_available(context)
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "listed", items)
        return items
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local repository = repository_from_context(context, {})
    local items = query_installed(context, paths, repository)
    if items == nil then
        log_warn(context, "CRAN list failed")
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local available, message = read_available(context)
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "outdated", items)
        return items
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local repository = repository_from_context(context, {})
    local items = query_outdated(context, paths, repository)
    if items == nil then
        log_warn(context, "CRAN outdated failed")
        items = {}
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned_prompt = trim(prompt)
    if cleaned_prompt == "" and context ~= nil then
        cleaned_prompt = trim(context.prompt)
    end
    if cleaned_prompt == "" then
        local items = {}
        emit_event(context, "searched", items)
        return items
    end

    local available, message = read_available(context)
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "searched", items)
        return items
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local repository = repository_from_context(context, {})
    local items = query_search(context, paths, repository, cleaned_prompt)
    if items == nil then
        log_warn(context, "CRAN search failed")
        items = {}
    end
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

    local available, message = read_available(context)
    if not available then
        log_warn(context, message)
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local paths = state_paths(data_root_from_context(context, {}))
    local repository = repository_from_context(context, {})
    local item = query_info(context, paths, repository, cleaned_name)
    if item == nil then
        log_warn(context, "CRAN info failed")
        item = {}
    end
    if next(item) == nil then
        emit_event(context, "unavailable", {
            name = cleaned_name,
            reason = "not-found",
        })
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end

    local pkg, err = normalize_package(package)
    if pkg == nil then
        return nil, err
    end

    if not command_exists(context, REQUIRED_BINARY) then
        return {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "r-package",
        }
    end

    local paths = state_paths(data_root_from_context(context, { package }))
    local repository = repository_from_context(context, { package })
    local item = query_info(context, paths, repository, pkg.name)
    if item == nil or next(item) == nil then
        return {
            name = pkg.name,
            packageId = pkg.name,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "r-package",
        }
    end
    return item
end

return plugin
