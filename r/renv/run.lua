plugin = {}

local PLUGIN_ID = "renv"
local PLUGIN_NAME = "renv"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "Rscript"
local DEFAULT_REPOSITORY = "https://cloud.r-project.org"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return trim(value):lower()
end

local function split_lines(value)
    local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
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
    if #parts == 0 then
        return "."
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
    local result = {}
    local seen = {}
    local function add_from(object)
        for _, flag in ipairs(object_flags(object)) do
            if not seen[flag] then
                seen[flag] = true
                result[#result + 1] = flag
            end
        end
    end
    add_from(context)
    add_from(read_field(context, "request"))
    for _, pkg in ipairs(packages or {}) do
        add_from(pkg)
    end
    return result
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

local function flag_truthy(value, default)
    local cleaned = lower(value)
    if cleaned == "" then
        return default
    end
    if cleaned == "1" or cleaned == "true" or cleaned == "yes" or cleaned == "on" then
        return true
    end
    if cleaned == "0" or cleaned == "false" or cleaned == "no" or cleaned == "off" then
        return false
    end
    return default
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

local function is_success(result)
    return type(result) == "table" and (result.success == true or result.exitCode == 0)
end

local function command_exists(context, binary)
    return is_success(exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function get_plugin_dir()
    local dir = trim(_G.REQPACK_PLUGIN_DIR)
    if dir ~= "" then
        return dir
    end
    return join_path("r", "renv")
end

local function default_data_root()
    local fixture_root = os ~= nil and type(os.getenv) == "function" and trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT")) or ""
    if fixture_root ~= "" then
        return join_path(fixture_root, ".reqpack-data")
    end
    return join_path(get_plugin_dir(), ".reqpack-data")
end

local function shared_state_paths(root)
    local base = trim(root)
    if base == "" then
        base = default_data_root()
    end
    local shared = join_path(base, "shared")
    return {
        dataRoot = base,
        shared = shared,
        renvRoot = join_path(shared, "renv-root"),
        cache = join_path(shared, "cache"),
        source = join_path(shared, "source"),
        binary = join_path(shared, "binary"),
        cellar = join_path(shared, "cellar"),
        helperLibrary = join_path(shared, "helper-library"),
        tmp = join_path(shared, "tmp"),
    }
end

local function project_paths(project)
    local normalized = trim(project)
    return {
        project = normalized,
        renvDir = join_path(normalized, "renv"),
        lockfile = join_path(normalized, "renv.lock"),
        profile = join_path(normalized, ".Rprofile"),
        library = join_path(normalized, "renv", "library", "reqpack-library"),
    }
end

local function context_options(context, packages)
    local flags = collect_flags(context, packages)
    local data_root = trim(flag_value(flags, "data-root") or default_data_root())
    local project = trim(flag_value(flags, "project") or "")
    local repo = trim(flag_value(flags, "repo") or flag_value(flags, "repos") or DEFAULT_REPOSITORY)
    local snapshot = flag_truthy(flag_value(flags, "snapshot"), false)
    local lock = flag_truthy(flag_value(flags, "lock"), false)
    local bare = flag_truthy(flag_value(flags, "bare"), true)
    local rebuild = flag_truthy(flag_value(flags, "rebuild"), false)
    return {
        flags = flags,
        dataRoot = data_root,
        project = project,
        repository = repo,
        snapshot = snapshot,
        lock = lock,
        bare = bare,
        rebuild = rebuild,
        shared = shared_state_paths(data_root),
        projectPaths = project ~= "" and project_paths(project) or nil,
    }
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
        return nil, "missing renv package name"
    end
    local version = package_version(pkg)
    if version ~= "" and not name:find("@", 1, true) then
        name = name .. "@" .. version
    end
    return {
        name = name,
        packageId = package_name(pkg),
        version = version,
        raw = pkg,
    }, nil
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

local function failure(context, message)
    tx_failed(context, message)
    return false
end

local function require_project_path(context, options)
    if options.project ~= "" then
        return true
    end
    return failure(context, "renv action requires project=/abs/path flag")
end

local function dependencies_expression(flags)
    local value = lower(flag_value(flags, "dependencies") or "")
    if value == "true" or value == "yes" or value == "1" then
        return "TRUE"
    end
    if value == "false" or value == "no" or value == "0" then
        return "FALSE"
    end
    if value == "strong" or value == "most" or value == "all" then
        return r_quote(value)
    end
    return "NULL"
end

local function env_prefix(shared, project_paths)
    return table.concat({
        "R_LIBS_USER=" .. shell_quote(project_paths and project_paths.library or shared.helperLibrary),
        "RENV_PATHS_ROOT=" .. shell_quote(shared.renvRoot),
        "RENV_PATHS_CACHE=" .. shell_quote(shared.cache),
        "RENV_PATHS_SOURCE=" .. shell_quote(shared.source),
        "RENV_PATHS_BINARY=" .. shell_quote(shared.binary),
        "RENV_PATHS_CELLAR=" .. shell_quote(shared.cellar),
        "TMPDIR=" .. shell_quote(shared.tmp),
        "R_ENVIRON_USER=/dev/null",
        "R_PROFILE_USER=/dev/null",
        "RENV_CONFIG_AUTOLOADER_ENABLED=FALSE",
        "RENV_AUTOLOAD_ENABLED=FALSE",
        "LC_ALL=C",
        "LANG=C",
        "LANGUAGE=C",
    }, " ")
end

local function r_common_setup(shared, project_paths, repository)
    return table.concat({
        "helper <- " .. r_quote(shared.helperLibrary) .. ";",
        "tmp <- " .. r_quote(shared.tmp) .. ";",
        "repo <- " .. r_quote(repository) .. ";",
        "dir.create(helper, recursive = TRUE, showWarnings = FALSE);",
        "dir.create(tmp, recursive = TRUE, showWarnings = FALSE);",
        "dir.create(" .. r_quote(shared.renvRoot) .. ", recursive = TRUE, showWarnings = FALSE);",
        "dir.create(" .. r_quote(shared.cache) .. ", recursive = TRUE, showWarnings = FALSE);",
        "dir.create(" .. r_quote(shared.source) .. ", recursive = TRUE, showWarnings = FALSE);",
        "dir.create(" .. r_quote(shared.binary) .. ", recursive = TRUE, showWarnings = FALSE);",
        "dir.create(" .. r_quote(shared.cellar) .. ", recursive = TRUE, showWarnings = FALSE);",
        "options(repos = c(CRAN = repo), renv.consent = TRUE, renv.config.autoloader.enabled = FALSE, renv.config.auto.snapshot = FALSE);",
        ".libPaths(c(helper, .libPaths()));",
        "field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(\"\"); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(\"\"); gsub(\"[\\t\\r\\n]+\", \" \", value); };",
        "row_out <- function(values) { cat(paste(vapply(values, field, \"\"), collapse = \"\\t\"), \"\\n\", sep = \"\"); };",
        "if (!requireNamespace(\"renv\", quietly = TRUE, lib.loc = helper)) utils::install.packages(\"renv\", lib = helper, repos = repo, quiet = TRUE);",
        "library(renv, lib.loc = helper);",
        "renv::consent(provided = TRUE);",
        project_paths and ("project <- " .. r_quote(project_paths.project) .. "; dir.create(project, recursive = TRUE, showWarnings = FALSE);") or "project <- NULL;",
        project_paths and ("project_lib <- " .. r_quote(project_paths.library) .. "; dir.create(project_lib, recursive = TRUE, showWarnings = FALSE);") or "project_lib <- helper;",
        project_paths and ("lockfile <- " .. r_quote(project_paths.lockfile) .. ";") or "lockfile <- NULL;",
    }, " ")
end

local function rscript_command(shared, project_paths, repository, body)
    local code = r_common_setup(shared, project_paths, repository) .. " " .. body
    return env_prefix(shared, project_paths) .. " " .. REQUIRED_BINARY .. " --vanilla -e " .. shell_quote(code)
end

local function project_bootstrap_body(options)
    local project_paths = options.projectPaths
    return table.concat({
        "if (!file.exists(file.path(project, \"renv\", \"activate.R\")) && !file.exists(file.path(project, \"renv.lock\"))) {",
        "renv::init(project = project, bare = " .. (options.bare and "TRUE" or "FALSE") .. ", force = TRUE, restart = FALSE, load = FALSE, repos = c(CRAN = repo));",
        "}",
    }, " ")
end

local function ensure_runtime(context, options)
    if not command_exists(context, REQUIRED_BINARY) then
        return false, REQUIRED_BINARY .. " binary not available"
    end
    return true, nil
end

local function ensure_project(context, options)
    if not require_project_path(context, options) then
        return false
    end
    local available, message = ensure_runtime(context, options)
    if not available then
        return failure(context, message)
    end
    local result = exec_run(context, rscript_command(options.shared, options.projectPaths, options.repository, project_bootstrap_body(options)))
    if not is_success(result) then
        return failure(context, "renv project bootstrap failed")
    end
    return true
end

local function snapshot_body(options)
    return "renv::snapshot(project = project, library = project_lib, lockfile = lockfile, prompt = FALSE, update = TRUE, force = TRUE, repos = c(CRAN = repo));"
end

local function maybe_snapshot(context, options)
    if not options.snapshot or options.lock then
        return true
    end
    local result = exec_run(context, rscript_command(options.shared, options.projectPaths, options.repository, snapshot_body(options)))
    if not is_success(result) then
        return failure(context, "renv snapshot failed")
    end
    return true
end

local function installed_query_body(project_aware)
    local prefix = project_aware and "" or ""
    return table.concat({
        prefix,
        "fields <- c(\"Priority\",\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Built\",\"Depends\",\"Imports\",\"Suggests\");",
        "db <- utils::installed.packages(lib.loc = project_lib, noCache = TRUE, fields = fields);",
        "if (nrow(db) > 0L) { for (i in seq_len(nrow(db))) row_out(list(db[i, \"Package\"], db[i, \"Version\"], db[i, \"LibPath\"], db[i, \"Priority\"], db[i, \"Description\"], db[i, \"License\"], db[i, \"URL\"], db[i, \"NeedsCompilation\"], db[i, \"Built\"], db[i, \"Depends\"], db[i, \"Imports\"], db[i, \"Suggests\"])); }",
    }, " ")
end

local function search_query_body(prompt, with_installed)
    local installed_part = with_installed
        and "installed <- utils::installed.packages(lib.loc = project_lib, noCache = TRUE); installed_names <- if (nrow(installed) > 0L) rownames(installed) else character();"
        or "installed_names <- character();"
    return table.concat({
        "target <- tolower(" .. r_quote(prompt) .. ");",
        installed_part,
        "fields <- c(\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Repository\",\"Depends\",\"Imports\",\"Suggests\");",
        "avail <- utils::available.packages(repos = repo, fields = fields, cache_user_dir = TRUE);",
        "if (nrow(avail) > 0L) { desc <- ifelse(is.na(avail[, \"Description\"]), \"\", avail[, \"Description\"]); mask <- grepl(target, tolower(avail[, \"Package\"]), fixed = TRUE) | grepl(target, tolower(desc), fixed = TRUE); rows <- which(mask); if (length(rows) > 0L) { rows <- rows[order(avail[rows, \"Package\"])]; if (length(rows) > 50L) rows <- rows[seq_len(50L)]; for (i in rows) row_out(list(avail[i, \"Package\"], avail[i, \"Version\"], if (avail[i, \"Package\"] %in% installed_names) \"true\" else \"false\", avail[i, \"Description\"], avail[i, \"License\"], avail[i, \"URL\"], avail[i, \"Repository\"], avail[i, \"NeedsCompilation\"], avail[i, \"Depends\"], avail[i, \"Imports\"], avail[i, \"Suggests\"])); } } }",
    }, " ")
end

local function outdated_query_body()
    return table.concat({
        "fields <- c(\"Priority\",\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Built\",\"Depends\",\"Imports\",\"Suggests\");",
        "inst <- utils::installed.packages(lib.loc = project_lib, noCache = TRUE, fields = fields);",
        "if (nrow(inst) > 0L) { avail <- utils::available.packages(repos = repo, fields = c(\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Repository\",\"Depends\",\"Imports\",\"Suggests\"), cache_user_dir = TRUE); old <- utils::old.packages(lib.loc = project_lib, repos = repo, instPkgs = inst, available = avail); if (!is.null(old) && nrow(old) > 0L) { for (i in seq_len(nrow(old))) { name <- old[i, \"Package\"]; row_out(list(name, old[i, \"Installed\"], old[i, \"ReposVer\"], old[i, \"Repository\"], old[i, \"LibPath\"], inst[name, \"Description\"], inst[name, \"License\"], inst[name, \"URL\"], inst[name, \"NeedsCompilation\"], inst[name, \"Depends\"], inst[name, \"Imports\"], inst[name, \"Suggests\"], inst[name, \"Built\"])); } } }",
    }, " ")
end

local function info_query_body(name, with_project)
    local local_part = with_project and table.concat({
        "fields <- c(\"Priority\",\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Built\",\"Depends\",\"Imports\",\"Suggests\");",
        "inst <- utils::installed.packages(lib.loc = project_lib, noCache = TRUE, fields = fields);",
        "if (nrow(inst) > 0L && target %in% rownames(inst)) row_out(list(\"local\", target, inst[target, \"Version\"], inst[target, \"LibPath\"], inst[target, \"Priority\"], inst[target, \"Description\"], inst[target, \"License\"], inst[target, \"URL\"], inst[target, \"NeedsCompilation\"], inst[target, \"Built\"], inst[target, \"Depends\"], inst[target, \"Imports\"], inst[target, \"Suggests\"]));",
        "if (!is.null(lockfile) && file.exists(lockfile)) { lock <- renv::lockfile_read(lockfile); rec <- lock$Packages[[target]]; if (!is.null(rec)) row_out(list(\"lock\", target, if (!is.null(rec$Version)) rec$Version else \"\", lockfile, if (!is.null(rec$Source)) rec$Source else \"\", if (!is.null(rec$Repository)) rec$Repository else \"\", \"\", \"\", \"\", \"\", \"\", \"\", \"\")); }",
    }, " ") or ""
    return table.concat({
        "target <- " .. r_quote(name) .. ";",
        local_part,
        "avail <- utils::available.packages(repos = repo, fields = c(\"Priority\",\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Repository\",\"Depends\",\"Imports\",\"Suggests\"), cache_user_dir = TRUE);",
        "if (nrow(avail) > 0L && target %in% rownames(avail)) row_out(list(\"remote\", target, avail[target, \"Version\"], avail[target, \"Repository\"], avail[target, \"Priority\"], avail[target, \"Description\"], avail[target, \"License\"], avail[target, \"URL\"], avail[target, \"NeedsCompilation\"], \"\", avail[target, \"Depends\"], avail[target, \"Imports\"], avail[target, \"Suggests\"]));",
    }, " ")
end

local function map_installed_record(record, repository, project, lockfile_path)
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
            project = project,
            lockfilePath = lockfile_path,
        }),
    }
end

local function map_remote_record(record, repository, installed_version, project, lockfile_path, lockfile_version, source)
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
            project = project,
            lockfilePath = lockfile_path,
            lockfileVersion = lockfile_version,
            source = source,
        }),
    }
end

local function parse_installed_items(raw, repository, project, lockfile_path)
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
            }, repository, project, lockfile_path)
        end
    end
    return items
end

local function parse_outdated_items(raw, project, lockfile_path)
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
                    project = project,
                    lockfilePath = lockfile_path,
                }),
            }
        end
    end
    return items
end

local function parse_search_items(raw, repository, project)
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
                    project = project,
                }),
            }
        end
    end
    return items
end

local function query_installed(context, options)
    local result = exec_run(context, rscript_command(options.shared, options.projectPaths, options.repository, installed_query_body(true)))
    if not is_success(result) then
        return nil
    end
    return parse_installed_items(result.stdout, options.repository, options.project, options.projectPaths and options.projectPaths.lockfile or nil)
end

local function query_outdated(context, options)
    local result = exec_run(context, rscript_command(options.shared, options.projectPaths, options.repository, outdated_query_body()))
    if not is_success(result) then
        return nil
    end
    return parse_outdated_items(result.stdout, options.project, options.projectPaths and options.projectPaths.lockfile or nil)
end

local function query_search(context, options, prompt)
    local result = exec_run(context, rscript_command(options.shared, options.projectPaths, options.repository, search_query_body(prompt, options.project ~= "")))
    if not is_success(result) then
        return nil
    end
    return parse_search_items(result.stdout, options.repository, options.project ~= "" and options.project or nil)
end

local function combine_info_records(local_record, remote_record, lock_record, repository, project, lockfile_path)
    if local_record == nil and remote_record == nil and lock_record == nil then
        return {}
    end
    if remote_record == nil and local_record ~= nil then
        local item = map_installed_record(local_record, repository, project, lockfile_path)
        if lock_record ~= nil then
            item.extraFields = make_extra_fields({
                libPath = local_record.libPath,
                priority = local_record.priority,
                needsCompilation = local_record.needsCompilation,
                built = local_record.built,
                project = project,
                lockfilePath = lockfile_path,
                lockfileVersion = lock_record.version,
                source = lock_record.source,
            })
        end
        return item
    end
    local item = map_remote_record(remote_record or { name = lock_record.name, version = lock_record.version, repository = lock_record.repository, description = "", license = "", url = "", needsCompilation = "", priority = "", depends = "", imports = "", suggests = "" }, repository, local_record and local_record.version or nil, project, lockfile_path, lock_record and lock_record.version or nil, lock_record and lock_record.source or nil)
    if local_record ~= nil then
        item.status = item.latestVersion ~= local_record.version and "outdated" or "installed"
        item.summary = trim(remote_record and remote_record.description or "") ~= "" and remote_record.description or local_record.description
        item.description = item.summary
        item.license = trim(remote_record and remote_record.license or "") ~= "" and remote_record.license or (trim(local_record.license) ~= "" and local_record.license or nil)
        item.homepage = trim(remote_record and remote_record.url or "") ~= "" and remote_record.url or (trim(local_record.url) ~= "" and local_record.url or nil)
        item.dependencies = parse_dependencies(remote_record and remote_record.depends or "", remote_record and remote_record.imports or "", remote_record and remote_record.suggests or "", local_record.depends, local_record.imports, local_record.suggests)
        item.extraFields = make_extra_fields({
            libPath = local_record.libPath,
            priority = local_record.priority,
            needsCompilation = trim(remote_record and remote_record.needsCompilation or "") ~= "" and remote_record.needsCompilation or local_record.needsCompilation,
            built = local_record.built,
            project = project,
            lockfilePath = lockfile_path,
            lockfileVersion = lock_record and lock_record.version or nil,
            source = lock_record and lock_record.source or nil,
        })
    end
    return item
end

local function query_info(context, options, name)
    local result = exec_run(context, rscript_command(options.shared, options.projectPaths, options.repository, info_query_body(name, options.project ~= "")))
    if not is_success(result) then
        return nil
    end
    local local_record = nil
    local remote_record = nil
    local lock_record = nil
    for _, line in ipairs(split_lines(result.stdout)) do
        local fields = split_tabs(line)
        if #fields >= 13 and fields[1] == "local" then
            local_record = {
                name = fields[2], version = fields[3], libPath = fields[4], priority = fields[5], description = fields[6], license = fields[7], url = fields[8], needsCompilation = fields[9], built = fields[10], depends = fields[11], imports = fields[12], suggests = fields[13],
            }
        elseif #fields >= 13 and fields[1] == "remote" then
            remote_record = {
                name = fields[2], version = fields[3], repository = fields[4], priority = fields[5], description = fields[6], license = fields[7], url = fields[8], needsCompilation = fields[9], built = fields[10], depends = fields[11], imports = fields[12], suggests = fields[13],
            }
        elseif #fields >= 6 and fields[1] == "lock" then
            lock_record = {
                name = fields[2], version = fields[3], lockfile = fields[4], source = fields[5], repository = fields[6],
            }
        end
    end
    return combine_info_records(local_record, remote_record, lock_record, options.repository, options.project ~= "" and options.project or nil, options.projectPaths and options.projectPaths.lockfile or nil)
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
        ecosystemScopes = { "r", "renv", "cran", "bioconductor", "github" },
        writeScopes = {
            { kind = "plugin-subpath", path = ".reqpack-data" },
            { kind = "project-relative", value = "renv" },
            { kind = "project-relative", value = "renv.lock" },
            { kind = "project-relative", value = ".Rprofile" },
            { kind = "temp" },
        },
        networkScopes = {
            { host = "*", scheme = "https", pathPrefix = "/" },
        },
        privilegeLevel = "user",
        osvEcosystem = "CRAN",
        purlType = "cran",
    }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end
    if not command_exists(nil, REQUIRED_BINARY) then
        return packages
    end
    local options = context_options(nil, packages)
    if options.project == "" then
        local filtered = {}
        for _, pkg in ipairs(packages) do
            local action = package_action(pkg)
            if action == "install" or action == "" then
                filtered[#filtered + 1] = pkg
            end
        end
        return filtered
    end
    local bootstrap = ensure_project(nil, options)
    if bootstrap ~= true then
        return packages
    end
    local installed_items = query_installed(nil, options)
    if installed_items == nil then
        return packages
    end
    local installed_set = {}
    for _, item in ipairs(installed_items) do
        installed_set[lower(item.name)] = true
    end
    local outdated_set = {}
    local outdated_items = query_outdated(nil, options) or {}
    for _, item in ipairs(outdated_items) do
        outdated_set[lower(item.name)] = true
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
    local options = context_options(context, requested)
    if not ensure_project(context, options) then
        return false
    end
    local normalized = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return failure(context, err)
        end
        normalized[#normalized + 1] = pkg
    end
    begin_step(context, "install renv packages")
    local package_names = {}
    for _, pkg in ipairs(normalized) do
        package_names[#package_names + 1] = r_quote(pkg.name)
    end
    local body = "renv::install(packages = c(" .. table.concat(package_names, ",") .. "), prompt = FALSE, project = project, library = project_lib, repos = c(CRAN = repo), dependencies = " .. dependencies_expression(options.flags) .. ", rebuild = " .. (options.rebuild and "TRUE" or "FALSE") .. ", lock = " .. (options.lock and "TRUE" or "FALSE") .. ");"
    local result = exec_run(context, rscript_command(options.shared, options.projectPaths, options.repository, body))
    if not is_success(result) then
        return failure(context, "renv install failed")
    end
    if not maybe_snapshot(context, options) then
        return false
    end
    local installed = {}
    for _, pkg in ipairs(normalized) do
        installed[#installed + 1] = {
            name = pkg.packageId,
            packageId = pkg.packageId,
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
    local requested_path = trim(path or read_field(context, "localPath") or read_field(context, "path"))
    if requested_path == "" then
        return failure(context, "missing local renv package path")
    end
    local options = context_options(context, {})
    if not ensure_project(context, options) then
        return false
    end
    begin_step(context, "install local renv package")
    local body = "renv::install(packages = " .. r_quote(requested_path) .. ", prompt = FALSE, project = project, library = project_lib, repos = NULL, rebuild = " .. (options.rebuild and "TRUE" or "FALSE") .. ", lock = " .. (options.lock and "TRUE" or "FALSE") .. ");"
    local result = exec_run(context, rscript_command(options.shared, options.projectPaths, options.repository, body))
    if not is_success(result) then
        return failure(context, "renv local install failed")
    end
    if not maybe_snapshot(context, options) then
        return false
    end
    emit_event(context, "installed", { { path = requested_path, localTarget = true, packageType = "r-package" } })
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
    local options = context_options(context, requested)
    if not ensure_project(context, options) then
        return false
    end
    local normalized = {}
    for _, raw_pkg in ipairs(requested) do
        local pkg, err = normalize_package(raw_pkg)
        if pkg == nil then
            return failure(context, err)
        end
        normalized[#normalized + 1] = pkg
    end
    begin_step(context, "remove renv packages")
    local package_names = {}
    for _, pkg in ipairs(normalized) do
        package_names[#package_names + 1] = r_quote(pkg.packageId)
    end
    local body = "renv::remove(packages = c(" .. table.concat(package_names, ",") .. "), project = project, library = project_lib);"
    local result = exec_run(context, rscript_command(options.shared, options.projectPaths, options.repository, body))
    if not is_success(result) then
        return failure(context, "renv remove failed")
    end
    if not maybe_snapshot(context, options) then
        return false
    end
    local deleted = {}
    for _, pkg in ipairs(normalized) do
        deleted[#deleted + 1] = {
            name = pkg.packageId,
            packageId = pkg.packageId,
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
    local options = context_options(context, requested)
    if not ensure_project(context, options) then
        return false
    end
    begin_step(context, "update renv packages")
    local body = nil
    if #requested == 0 then
        body = "renv::update(prompt = FALSE, project = project, library = project_lib, rebuild = " .. (options.rebuild and "TRUE" or "FALSE") .. ", lock = " .. (options.lock and "TRUE" or "FALSE") .. ");"
    else
        local normalized = {}
        for _, raw_pkg in ipairs(requested) do
            local pkg, err = normalize_package(raw_pkg)
            if pkg == nil then
                return failure(context, err)
            end
            normalized[#normalized + 1] = pkg
        end
        local package_names = {}
        for _, pkg in ipairs(normalized) do
            package_names[#package_names + 1] = r_quote(pkg.packageId)
        end
        body = "renv::update(packages = c(" .. table.concat(package_names, ",") .. "), prompt = FALSE, project = project, library = project_lib, rebuild = " .. (options.rebuild and "TRUE" or "FALSE") .. ", lock = " .. (options.lock and "TRUE" or "FALSE") .. ");"
    end
    local result = exec_run(context, rscript_command(options.shared, options.projectPaths, options.repository, body))
    if not is_success(result) then
        return failure(context, "renv update failed")
    end
    if not maybe_snapshot(context, options) then
        return false
    end
    local updated = {}
    if #requested > 0 then
        for _, raw_pkg in ipairs(requested) do
            local name = package_name(raw_pkg)
            updated[#updated + 1] = { name = name, packageId = name, packageType = "r-package" }
        end
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.list(context)
    local options = context_options(context, {})
    if not ensure_project(context, options) then
        return {}
    end
    local items = query_installed(context, options)
    if items == nil then
        log_warn(context, "renv list failed")
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local options = context_options(context, {})
    if not ensure_project(context, options) then
        return {}
    end
    local items = query_outdated(context, options)
    if items == nil then
        log_warn(context, "renv outdated failed")
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
    local options = context_options(context, {})
    local available, message = ensure_runtime(context, options)
    if not available then
        log_warn(context, message)
        local items = {}
        emit_event(context, "searched", items)
        return items
    end
    if options.project ~= "" then
        ensure_project(context, options)
    end
    local items = query_search(context, options, cleaned_prompt)
    if items == nil then
        log_warn(context, "renv search failed")
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
    local options = context_options(context, {})
    local available, message = ensure_runtime(context, options)
    if not available then
        log_warn(context, message)
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end
    if options.project ~= "" then
        ensure_project(context, options)
    end
    local item = query_info(context, options, cleaned_name)
    if item == nil then
        log_warn(context, "renv info failed")
        item = {}
    end
    if next(item) == nil then
        emit_event(context, "unavailable", { name = cleaned_name, reason = "not-found" })
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
    local options = context_options(context, { package })
    if not command_exists(context, REQUIRED_BINARY) then
        return {
            name = pkg.packageId,
            packageId = pkg.packageId,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "r-package",
        }
    end
    if options.project ~= "" then
        ensure_project(context, options)
    end
    local item = query_info(context, options, pkg.packageId)
    if item == nil or next(item) == nil then
        return {
            name = pkg.packageId,
            packageId = pkg.packageId,
            version = pkg.version ~= "" and pkg.version or nil,
            packageType = "r-package",
        }
    end
    return item
end

return plugin
