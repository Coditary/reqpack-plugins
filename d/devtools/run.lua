plugin = {}
plugin.fileExtensions = { ".tar.gz", ".tgz", ".zip" }

local PLUGIN_ID = "devtools"
local PLUGIN_NAME = "devtools"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "Rscript"
local DEFAULT_REPOSITORY = "https://cloud.r-project.org"

local SUPPORTED_SOURCES = {
    cran = true,
    version = true,
    bioc = true,
    github = true,
    gitlab = true,
    bitbucket = true,
    git = true,
    svn = true,
    url = true,
    dev = true,
}

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

local function first_flag_value(...)
    for index = 1, select("#", ...) do
        local flags = select(index, ...)
        if flags ~= nil then
            local key = select(index + select("#", ...), ...)
            break
        end
    end
end

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = trim(select(index, ...))
        if value ~= "" then
            return value
        end
    end
    return ""
end

local function merged_flag_value(package_flags, context_flags, key)
    return trim(flag_value(package_flags, key) or flag_value(context_flags, key) or "")
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
    return join_path("d", "devtools")
end

local function default_data_root()
    local fixture_root = os ~= nil and type(os.getenv) == "function" and trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT")) or ""
    if fixture_root ~= "" then
        return join_path(fixture_root, ".reqpack-data")
    end
    return join_path(get_plugin_dir(), ".reqpack-data")
end

local function state_paths(root)
    local base = trim(root)
    if base == "" then
        base = default_data_root()
    end
    return {
        root = base,
        library = join_path(base, "library"),
        helperLibrary = join_path(base, "helper-library"),
        cache = join_path(base, "cache"),
        config = join_path(base, "config"),
        tmp = join_path(base, "tmp"),
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

local function r_setup(paths, repository, include_bioc_manager)
    local parts = {
        "lib <- " .. r_quote(paths.library) .. ";",
        "helper <- " .. r_quote(paths.helperLibrary) .. ";",
        "repo <- " .. r_quote(repository) .. ";",
        "dir.create(lib, recursive = TRUE, showWarnings = FALSE);",
        "dir.create(helper, recursive = TRUE, showWarnings = FALSE);",
        "dir.create(Sys.getenv(\"XDG_CACHE_HOME\"), recursive = TRUE, showWarnings = FALSE);",
        "dir.create(Sys.getenv(\"XDG_CONFIG_HOME\"), recursive = TRUE, showWarnings = FALSE);",
        "dir.create(Sys.getenv(\"TMPDIR\"), recursive = TRUE, showWarnings = FALSE);",
        "options(repos = c(CRAN = repo));",
        ".libPaths(c(helper, .libPaths()));",
        "if (!requireNamespace(\"devtools\", quietly = TRUE, lib.loc = helper)) utils::install.packages(\"devtools\", lib = helper, repos = repo, quiet = TRUE);",
        ".libPaths(c(lib, helper, .libPaths()));",
        "field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(\"\"); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(\"\"); gsub(\"[\\t\\r\\n]+\", \" \", value); };",
        "row_out <- function(values) { cat(paste(vapply(values, field, \"\"), collapse = \"\\t\"), \"\\n\", sep = \"\"); };",
    }
    if include_bioc_manager == true then
        table.insert(parts, 11, "if (!requireNamespace(\"BiocManager\", quietly = TRUE, lib.loc = helper)) utils::install.packages(\"BiocManager\", lib = helper, repos = repo, quiet = TRUE);")
    end
    return table.concat(parts, " ")
end

local function rscript_command(paths, repository, body, include_bioc_manager)
    local code = r_setup(paths, repository, include_bioc_manager) .. " " .. body
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

local function merge_extra_fields(...)
    local merged = {}
    for index = 1, select("#", ...) do
        for key, value in pairs(select(index, ...) or {}) do
            if value ~= nil and trim(value) ~= "" then
                merged[key] = value
            end
        end
    end
    if next(merged) == nil then
        return nil
    end
    return merged
end

local function remote_extra_fields(record)
    local source = trim(record.remoteType)
    local normalized_source = source
    local lowered = lower(source)
    if lowered == "bioc_xgit" or lowered == "bioc_git2r" then
        normalized_source = "bioc"
    elseif normalized_source == "" then
        normalized_source = "cran"
    end
    return make_extra_fields({
        source = normalized_source,
        remoteType = record.remoteType,
        remoteHost = record.remoteHost,
        remoteRepo = record.remoteRepo,
        remoteUsername = record.remoteUsername,
        remoteRef = record.remoteRef,
        remoteSha = record.remoteSha,
        remoteSubdir = record.remoteSubdir,
        remoteUrl = record.remoteUrl,
        remotePkgRef = record.remotePkgRef,
        remoteRepos = record.remoteRepos,
        remotePkgType = record.remotePkgType,
        remoteMirror = record.remoteMirror,
        remoteRelease = record.remoteRelease,
        remoteBranch = record.remoteBranch,
    })
end

local function is_cran_like_remote_type(remote_type)
    local cleaned = lower(remote_type)
    return cleaned == "" or cleaned == "cran" or cleaned == "standard" or cleaned == "any" or cleaned == "version"
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
        repository = trim(record.remoteRepos) ~= "" and record.remoteRepos or (trim(record.remoteUrl) ~= "" and record.remoteUrl or repository),
        packageType = "r-package",
        dependencies = parse_dependencies(record.depends, record.imports, record.suggests),
        extraFields = merge_extra_fields(
            make_extra_fields({
                libPath = record.libPath,
                priority = record.priority,
                needsCompilation = record.needsCompilation,
                built = record.built,
            }),
            remote_extra_fields(record)
        ),
    }
end

local function map_remote_record(record, repository, installed_version, installed_extra)
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
        extraFields = merge_extra_fields(
            make_extra_fields({
                needsCompilation = record.needsCompilation,
                priority = record.priority,
                source = record.source,
            }),
            installed_extra
        ),
    }
end

local function parse_installed_item_fields(fields, repository)
    if #fields < 26 then
        return nil
    end
    return map_installed_record({
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
        remoteType = fields[13],
        remoteHost = fields[14],
        remoteRepo = fields[15],
        remoteUsername = fields[16],
        remoteRef = fields[17],
        remoteSha = fields[18],
        remoteSubdir = fields[19],
        remoteUrl = fields[20],
        remotePkgRef = fields[21],
        remoteRepos = fields[22],
        remotePkgType = fields[23],
        remoteMirror = fields[24],
        remoteRelease = fields[25],
        remoteBranch = fields[26],
    }, repository)
end

local function parse_installed_items(raw, repository)
    local items = {}
    for _, line in ipairs(split_lines(raw)) do
        local item = parse_installed_item_fields(split_tabs(line), repository)
        if item ~= nil then
            items[#items + 1] = item
        end
    end
    return items
end

local function parse_outdated_items(raw)
    local items = {}
    for _, line in ipairs(split_lines(raw)) do
        local fields = split_tabs(line)
        if #fields >= 15 then
            local source = trim(fields[14])
            if lower(source) == "bioc_xgit" or lower(source) == "bioc_git2r" then
                source = "bioc"
            elseif source == "" then
                source = "cran"
            end
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
                    source = source,
                    remoteType = fields[14],
                    remotePkgRef = fields[15],
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
        if #fields >= 15 then
            local installed_extra = make_extra_fields({
                source = fields[1] == "local" and "installed" or fields[12],
                remoteType = fields[12],
                remoteRepo = fields[13],
                remoteUrl = fields[14],
                remotePkgRef = fields[15],
            })
            items[#items + 1] = {
                name = fields[2],
                packageId = fields[2],
                version = fields[3],
                latestVersion = fields[3],
                installed = fields[4] == "true",
                status = fields[4] == "true" and "installed" or "available",
                summary = fields[5],
                description = fields[5],
                license = trim(fields[6]) ~= "" and fields[6] or nil,
                homepage = trim(fields[7]) ~= "" and fields[7] or nil,
                repository = trim(fields[8]) ~= "" and fields[8] or repository,
                packageType = "r-package",
                dependencies = parse_dependencies(fields[10], fields[11]),
                extraFields = merge_extra_fields(make_extra_fields({ needsCompilation = fields[9] }), installed_extra),
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
        return map_remote_record(remote_record, repository, nil, nil)
    end
    local item = map_remote_record(remote_record, repository, local_record.version, remote_extra_fields(local_record))
    item.status = item.latestVersion ~= local_record.version and "outdated" or "installed"
    item.summary = trim(remote_record.description) ~= "" and remote_record.description or local_record.description
    item.description = item.summary
    item.license = trim(remote_record.license) ~= "" and remote_record.license or (trim(local_record.license) ~= "" and local_record.license or nil)
    item.homepage = trim(remote_record.url) ~= "" and remote_record.url or (trim(local_record.url) ~= "" and local_record.url or nil)
    item.dependencies = parse_dependencies(remote_record.depends, remote_record.imports, remote_record.suggests, local_record.depends, local_record.imports, local_record.suggests)
    item.extraFields = merge_extra_fields(
        make_extra_fields({
            libPath = local_record.libPath,
            priority = local_record.priority,
            needsCompilation = trim(remote_record.needsCompilation) ~= "" and remote_record.needsCompilation or local_record.needsCompilation,
            built = local_record.built,
        }),
        remote_extra_fields(local_record)
    )
    return item
end

local function installed_fields_expression()
    return r_quote('c("Priority","Description","License","URL","NeedsCompilation","Built","Depends","Imports","Suggests","RemoteType","RemoteHost","RemoteRepo","RemoteUsername","RemoteRef","RemoteSha","RemoteSubdir","RemoteUrl","RemotePkgRef","RemoteRepos","RemotePkgType","RemoteMirror","RemoteRelease","RemoteBranch")')
end

local function installed_query_command(paths, repository)
    local body = table.concat({
        "fields <- eval(parse(text = " .. installed_fields_expression() .. "));",
        "db <- utils::installed.packages(lib.loc = lib, noCache = TRUE, fields = fields);",
        "if (nrow(db) > 0L) { for (i in seq_len(nrow(db))) row_out(list(db[i, \"Package\"], db[i, \"Version\"], db[i, \"LibPath\"], db[i, \"Priority\"], db[i, \"Description\"], db[i, \"License\"], db[i, \"URL\"], db[i, \"NeedsCompilation\"], db[i, \"Built\"], db[i, \"Depends\"], db[i, \"Imports\"], db[i, \"Suggests\"], db[i, \"RemoteType\"], db[i, \"RemoteHost\"], db[i, \"RemoteRepo\"], db[i, \"RemoteUsername\"], db[i, \"RemoteRef\"], db[i, \"RemoteSha\"], db[i, \"RemoteSubdir\"], db[i, \"RemoteUrl\"], db[i, \"RemotePkgRef\"], db[i, \"RemoteRepos\"], db[i, \"RemotePkgType\"], db[i, \"RemoteMirror\"], db[i, \"RemoteRelease\"], db[i, \"RemoteBranch\"])); }",
    }, " ")
    return rscript_command(paths, repository, body, false)
end

local function outdated_query_command(paths, repository)
    local body = table.concat({
        "fields <- eval(parse(text = " .. installed_fields_expression() .. "));",
        "inst <- utils::installed.packages(lib.loc = lib, noCache = TRUE, fields = fields);",
        "avail <- utils::available.packages(repos = repo, fields = c(\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Repository\",\"Depends\",\"Imports\",\"Suggests\"), cache_user_dir = TRUE);",
        "if (nrow(inst) > 0L && nrow(avail) > 0L) { for (i in seq_len(nrow(inst))) { name <- inst[i, \"Package\"]; remote_type <- if (is.na(inst[i, \"RemoteType\"])) \"\" else as.character(inst[i, \"RemoteType\"]); if ((remote_type %in% c(\"\",\"cran\",\"standard\",\"any\",\"version\")) && name %in% rownames(avail) && utils::compareVersion(as.character(inst[i, \"Version\"]), as.character(avail[name, \"Version\"])) < 0L) row_out(list(name, inst[i, \"Version\"], avail[name, \"Version\"], avail[name, \"Repository\"], inst[i, \"LibPath\"], inst[i, \"Description\"], inst[i, \"License\"], inst[i, \"URL\"], inst[i, \"NeedsCompilation\"], inst[i, \"Depends\"], inst[i, \"Imports\"], inst[i, \"Suggests\"], inst[i, \"Built\"], remote_type, inst[i, \"RemotePkgRef\"])); } }",
        "bioc_valid <- tryCatch(suppressWarnings(BiocManager::valid(lib.loc = lib)), error = function(e) NULL);",
        "bioc_outdated <- if (is.list(bioc_valid) && !is.null(bioc_valid$out_of_date) && nrow(bioc_valid$out_of_date) > 0L) bioc_valid$out_of_date else NULL;",
        "if (nrow(inst) > 0L && !is.null(bioc_outdated)) { for (i in seq_len(nrow(inst))) { name <- inst[i, \"Package\"]; remote_type <- if (is.na(inst[i, \"RemoteType\"])) \"\" else as.character(inst[i, \"RemoteType\"]); if ((remote_type %in% c(\"bioc_xgit\",\"bioc_git2r\")) && name %in% rownames(bioc_outdated)) row_out(list(name, inst[i, \"Version\"], bioc_outdated[name, \"Version\"], inst[i, \"RemoteRepos\"], inst[i, \"LibPath\"], inst[i, \"Description\"], inst[i, \"License\"], inst[i, \"URL\"], inst[i, \"NeedsCompilation\"], inst[i, \"Depends\"], inst[i, \"Imports\"], inst[i, \"Suggests\"], inst[i, \"Built\"], remote_type, inst[i, \"RemotePkgRef\"])); } }",
    }, " ")
    return rscript_command(paths, repository, body, true)
end

local function search_query_command(paths, repository, prompt)
    local body = table.concat({
        "target <- tolower(" .. r_quote(prompt) .. ");",
        "fields <- eval(parse(text = " .. installed_fields_expression() .. "));",
        "inst <- utils::installed.packages(lib.loc = lib, noCache = TRUE, fields = fields);",
        "avail <- utils::available.packages(repos = repo, fields = c(\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Repository\",\"Depends\",\"Imports\",\"Suggests\"), cache_user_dir = TRUE);",
        "bioc_repos <- tryCatch(BiocManager::repositories(), error = function(e) NULL);",
        "bioc_avail <- if (!is.null(bioc_repos)) tryCatch(utils::available.packages(repos = bioc_repos, fields = c(\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Repository\",\"Depends\",\"Imports\",\"Suggests\"), cache_user_dir = TRUE), error = function(e) NULL) else NULL;",
        "remote_hits <- character();",
        "if (nrow(avail) > 0L) { desc <- ifelse(is.na(avail[, \"Description\"]), \"\", avail[, \"Description\"]); mask <- grepl(target, tolower(avail[, \"Package\"]), fixed = TRUE) | grepl(target, tolower(desc), fixed = TRUE); rows <- which(mask); if (length(rows) > 0L) { rows <- rows[order(avail[rows, \"Package\"])]; if (length(rows) > 50L) rows <- rows[seq_len(50L)]; remote_hits <- avail[rows, \"Package\"]; installed_names <- if (nrow(inst) > 0L) rownames(inst) else character(); for (i in rows) row_out(list(\"remote\", avail[i, \"Package\"], avail[i, \"Version\"], if (avail[i, \"Package\"] %in% installed_names) \"true\" else \"false\", avail[i, \"Description\"], avail[i, \"License\"], avail[i, \"URL\"], avail[i, \"Repository\"], avail[i, \"NeedsCompilation\"], avail[i, \"Depends\"], avail[i, \"Imports\"], \"cran\", \"\", \"\", \"\")); } } }",
        "if (!is.null(bioc_avail) && nrow(bioc_avail) > 0L) { desc <- ifelse(is.na(bioc_avail[, \"Description\"]), \"\", bioc_avail[, \"Description\"]); mask <- grepl(target, tolower(bioc_avail[, \"Package\"]), fixed = TRUE) | grepl(target, tolower(desc), fixed = TRUE); rows <- which(mask); if (length(rows) > 0L) { rows <- rows[order(bioc_avail[rows, \"Package\"])]; if (length(rows) > 50L) rows <- rows[seq_len(50L)]; installed_names <- if (nrow(inst) > 0L) rownames(inst) else character(); for (i in rows) { pkg <- bioc_avail[i, \"Package\"]; if (!(pkg %in% remote_hits)) { remote_hits <- c(remote_hits, pkg); row_out(list(\"remote\", pkg, bioc_avail[i, \"Version\"], if (pkg %in% installed_names) \"true\" else \"false\", bioc_avail[i, \"Description\"], bioc_avail[i, \"License\"], bioc_avail[i, \"URL\"], bioc_avail[i, \"Repository\"], bioc_avail[i, \"NeedsCompilation\"], bioc_avail[i, \"Depends\"], bioc_avail[i, \"Imports\"], \"bioc\", \"\", \"\", \"\")); } } } }",
        "if (nrow(inst) > 0L) { desc <- ifelse(is.na(inst[, \"Description\"]), \"\", inst[, \"Description\"]); mask <- grepl(target, tolower(rownames(inst)), fixed = TRUE) | grepl(target, tolower(desc), fixed = TRUE); rows <- which(mask); if (length(rows) > 0L) { rows <- rows[order(rownames(inst)[rows])]; for (i in rows) { pkg <- rownames(inst)[i]; if (!(pkg %in% remote_hits)) row_out(list(\"local\", pkg, inst[i, \"Version\"], \"true\", inst[i, \"Description\"], inst[i, \"License\"], inst[i, \"URL\"], inst[i, \"RemoteRepos\"], inst[i, \"NeedsCompilation\"], inst[i, \"Depends\"], inst[i, \"Imports\"], inst[i, \"RemoteType\"], inst[i, \"RemoteRepo\"], inst[i, \"RemoteUrl\"], inst[i, \"RemotePkgRef\"])); } } } }",
    }, " ")
    return rscript_command(paths, repository, body, true)
end

local function info_query_command(paths, repository, name)
    local body = table.concat({
        "target <- " .. r_quote(name) .. ";",
        "fields <- eval(parse(text = " .. installed_fields_expression() .. "));",
        "inst <- utils::installed.packages(lib.loc = lib, noCache = TRUE, fields = fields);",
        "if (nrow(inst) > 0L && target %in% rownames(inst)) row_out(list(\"local\", target, inst[target, \"Version\"], inst[target, \"LibPath\"], inst[target, \"Priority\"], inst[target, \"Description\"], inst[target, \"License\"], inst[target, \"URL\"], inst[target, \"NeedsCompilation\"], inst[target, \"Built\"], inst[target, \"Depends\"], inst[target, \"Imports\"], inst[target, \"Suggests\"], inst[target, \"RemoteType\"], inst[target, \"RemoteHost\"], inst[target, \"RemoteRepo\"], inst[target, \"RemoteUsername\"], inst[target, \"RemoteRef\"], inst[target, \"RemoteSha\"], inst[target, \"RemoteSubdir\"], inst[target, \"RemoteUrl\"], inst[target, \"RemotePkgRef\"], inst[target, \"RemoteRepos\"], inst[target, \"RemotePkgType\"], inst[target, \"RemoteMirror\"], inst[target, \"RemoteRelease\"], inst[target, \"RemoteBranch\"]));",
        "avail <- utils::available.packages(repos = repo, fields = c(\"Priority\",\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Repository\",\"Depends\",\"Imports\",\"Suggests\"), cache_user_dir = TRUE);",
        "if (nrow(avail) > 0L && target %in% rownames(avail)) row_out(list(\"remote\", target, avail[target, \"Version\"], avail[target, \"Repository\"], avail[target, \"Priority\"], avail[target, \"Description\"], avail[target, \"License\"], avail[target, \"URL\"], avail[target, \"NeedsCompilation\"], \"\", avail[target, \"Depends\"], avail[target, \"Imports\"], avail[target, \"Suggests\"]));",
        "if (!(nrow(avail) > 0L && target %in% rownames(avail))) { bioc_repos <- tryCatch(BiocManager::repositories(), error = function(e) NULL); bioc_avail <- if (!is.null(bioc_repos)) tryCatch(utils::available.packages(repos = bioc_repos, fields = c(\"Priority\",\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Repository\",\"Depends\",\"Imports\",\"Suggests\"), cache_user_dir = TRUE), error = function(e) NULL) else NULL; if (!is.null(bioc_avail) && nrow(bioc_avail) > 0L && target %in% rownames(bioc_avail)) row_out(list(\"remote\", target, bioc_avail[target, \"Version\"], bioc_avail[target, \"Repository\"], bioc_avail[target, \"Priority\"], bioc_avail[target, \"Description\"], bioc_avail[target, \"License\"], bioc_avail[target, \"URL\"], bioc_avail[target, \"NeedsCompilation\"], \"\", bioc_avail[target, \"Depends\"], bioc_avail[target, \"Imports\"], bioc_avail[target, \"Suggests\"], \"bioc\")); }",
    }, " ")
    return rscript_command(paths, repository, body, true)
end

local function query_installed(context, paths, repository)
    local result = exec_run(context, installed_query_command(paths, repository))
    if not is_success(result) then
        return nil
    end
    return parse_installed_items(result.stdout, repository)
end

local function query_outdated(context, paths, repository)
    local result = exec_run(context, outdated_query_command(paths, repository))
    if not is_success(result) then
        return nil
    end
    return parse_outdated_items(result.stdout)
end

local function query_search(context, paths, repository, prompt)
    local result = exec_run(context, search_query_command(paths, repository, prompt))
    if not is_success(result) then
        return nil
    end
    return parse_search_items(result.stdout, repository)
end

local function query_info(context, paths, repository, name)
    local result = exec_run(context, info_query_command(paths, repository, name))
    if not is_success(result) then
        return nil
    end
    local local_record = nil
    local remote_record = nil
    for _, line in ipairs(split_lines(result.stdout)) do
        local fields = split_tabs(line)
        if #fields >= 27 and fields[1] == "local" then
            local_record = {
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
                remoteType = fields[14],
                remoteHost = fields[15],
                remoteRepo = fields[16],
                remoteUsername = fields[17],
                remoteRef = fields[18],
                remoteSha = fields[19],
                remoteSubdir = fields[20],
                remoteUrl = fields[21],
                remotePkgRef = fields[22],
                remoteRepos = fields[23],
                remotePkgType = fields[24],
                remoteMirror = fields[25],
                remoteRelease = fields[26],
                remoteBranch = fields[27],
            }
        elseif #fields >= 13 and fields[1] == "remote" then
            remote_record = {
                name = fields[2],
                version = fields[3],
                repository = fields[4],
                priority = fields[5],
                description = fields[6],
                license = fields[7],
                url = fields[8],
                needsCompilation = fields[9],
                built = fields[10],
                depends = fields[11],
                imports = fields[12],
                suggests = fields[13],
                source = fields[14] ~= nil and fields[14] ~= "" and fields[14] or "cran",
            }
        end
    end
    return combine_info_records(local_record, remote_record, repository)
end

local function failure(context, message)
    tx_failed(context, message)
    return false
end

local function read_available(context)
    if command_exists(context, REQUIRED_BINARY) then
        return true, nil
    end
    return false, REQUIRED_BINARY .. " binary not available"
end

local function global_repository(context, packages)
    local flags = collect_flags(context, packages)
    return trim(flag_value(flags, "repo") or flag_value(flags, "repos") or DEFAULT_REPOSITORY)
end

local function data_root_from_context(context, packages)
    local flags = collect_flags(context, packages)
    local data_root = trim(flag_value(flags, "data-root") or default_data_root())
    return data_root ~= "" and data_root or default_data_root()
end

local function dependencies_expression(package_flags, context_flags)
    local value = lower(merged_flag_value(package_flags, context_flags, "dependencies"))
    if value == "true" or value == "yes" or value == "1" then
        return "TRUE"
    end
    if value == "false" or value == "no" or value == "0" then
        return "FALSE"
    end
    if value == "soft" or value == "hard" then
        return r_quote(value)
    end
    return "NA"
end

local function upgrade_expression(package_flags, context_flags)
    local value = lower(merged_flag_value(package_flags, context_flags, "upgrade"))
    if value == "always" or value == "never" or value == "default" or value == "ask" then
        return r_quote(value)
    end
    return r_quote("default")
end

local function bool_expression(package_flags, context_flags, key, default)
    if flag_truthy(merged_flag_value(package_flags, context_flags, key), default) then
        return "TRUE"
    end
    return "FALSE"
end

local function source_default_build(source)
    if source == "version" then
        return false
    end
    return true
end

local function package_target_name(pkg)
    if pkg.source == "github" or pkg.source == "gitlab" or pkg.source == "bitbucket" then
        if pkg.name:find("/", 1, true) then
            return pkg.name
        end
        if pkg.username ~= "" then
            return pkg.username .. "/" .. pkg.name
        end
        return pkg.name
    end
    if pkg.source == "git" or pkg.source == "svn" or pkg.source == "url" then
        return first_nonempty(pkg.url, pkg.name)
    end
    return pkg.name
end

local function normalize_package(context_flags, raw_pkg)
    local name = package_name(raw_pkg)
    if name == "" then
        return nil, "missing devtools package name"
    end
    local package_flags = object_flags(raw_pkg)
    local source = lower(merged_flag_value(package_flags, context_flags, "source"))
    local version = package_version(raw_pkg)
    if source == "" then
        source = version ~= "" and "version" or "cran"
    end
    if not SUPPORTED_SOURCES[source] then
        return nil, "unsupported devtools source: " .. source
    end
    return {
        name = name,
        version = version,
        source = source,
        flags = package_flags,
        ref = merged_flag_value(package_flags, context_flags, "ref"),
        subdir = merged_flag_value(package_flags, context_flags, "subdir"),
        host = merged_flag_value(package_flags, context_flags, "host"),
        username = merged_flag_value(package_flags, context_flags, "username"),
        url = merged_flag_value(package_flags, context_flags, "url"),
        mirror = merged_flag_value(package_flags, context_flags, "mirror"),
        repository = first_nonempty(merged_flag_value(package_flags, context_flags, "repo"), merged_flag_value(package_flags, context_flags, "repos"), DEFAULT_REPOSITORY),
        dependenciesExpr = dependencies_expression(package_flags, context_flags),
        upgradeExpr = upgrade_expression(package_flags, context_flags),
        forceExpr = bool_expression(package_flags, context_flags, "force", false),
        buildExpr = bool_expression(package_flags, context_flags, "build", source_default_build(source)),
        buildManualExpr = bool_expression(package_flags, context_flags, "build-manual", false),
        buildVignettesExpr = bool_expression(package_flags, context_flags, "build-vignettes", false),
        typeExpr = trim(merged_flag_value(package_flags, context_flags, "type")) ~= "" and r_quote(merged_flag_value(package_flags, context_flags, "type")) or nil,
        raw = raw_pkg,
    }, nil
end

local function append_arg(args, key, expr)
    if expr ~= nil and trim(expr) ~= "" then
        args[#args + 1] = key .. " = " .. expr
    end
end

local function install_call_for_package(pkg)
    local args = {}
    if pkg.source == "cran" then
        args[#args + 1] = "pkgs = c(" .. r_quote(pkg.name) .. ")"
        args[#args + 1] = "repos = repo"
        args[#args + 1] = "dependencies = " .. pkg.dependenciesExpr
        args[#args + 1] = "quiet = TRUE"
        return "devtools::install_cran(" .. table.concat(args, ", ") .. ");"
    end
    if pkg.source == "version" then
        args[#args + 1] = "package = " .. r_quote(pkg.name)
        append_arg(args, "version", r_quote(pkg.version))
        args[#args + 1] = "repos = repo"
        args[#args + 1] = "dependencies = " .. pkg.dependenciesExpr
        args[#args + 1] = "upgrade = " .. pkg.upgradeExpr
        args[#args + 1] = "force = " .. pkg.forceExpr
        args[#args + 1] = "quiet = TRUE"
        args[#args + 1] = "build = " .. pkg.buildExpr
        args[#args + 1] = "build_manual = " .. pkg.buildManualExpr
        args[#args + 1] = "build_vignettes = " .. pkg.buildVignettesExpr
        append_arg(args, "type", pkg.typeExpr)
        return "devtools::install_version(" .. table.concat(args, ", ") .. ");"
    end
    if pkg.source == "bioc" then
        args[#args + 1] = "repo = " .. r_quote(pkg.name)
        append_arg(args, "mirror", trim(pkg.mirror) ~= "" and r_quote(pkg.mirror) or nil)
        args[#args + 1] = "dependencies = " .. pkg.dependenciesExpr
        args[#args + 1] = "upgrade = " .. pkg.upgradeExpr
        args[#args + 1] = "force = " .. pkg.forceExpr
        args[#args + 1] = "quiet = TRUE"
        args[#args + 1] = "build = " .. pkg.buildExpr
        args[#args + 1] = "build_manual = " .. pkg.buildManualExpr
        args[#args + 1] = "build_vignettes = " .. pkg.buildVignettesExpr
        args[#args + 1] = "repos = repo"
        append_arg(args, "type", pkg.typeExpr)
        return "devtools::install_bioc(" .. table.concat(args, ", ") .. ");"
    end
    if pkg.source == "github" then
        args[#args + 1] = "repo = " .. r_quote(package_target_name(pkg))
        append_arg(args, "ref", trim(pkg.ref) ~= "" and r_quote(pkg.ref) or nil)
        append_arg(args, "subdir", trim(pkg.subdir) ~= "" and r_quote(pkg.subdir) or nil)
        append_arg(args, "host", trim(pkg.host) ~= "" and r_quote(pkg.host) or nil)
        args[#args + 1] = "dependencies = " .. pkg.dependenciesExpr
        args[#args + 1] = "upgrade = " .. pkg.upgradeExpr
        args[#args + 1] = "force = " .. pkg.forceExpr
        args[#args + 1] = "quiet = TRUE"
        args[#args + 1] = "build = " .. pkg.buildExpr
        args[#args + 1] = "build_manual = " .. pkg.buildManualExpr
        args[#args + 1] = "build_vignettes = " .. pkg.buildVignettesExpr
        args[#args + 1] = "repos = repo"
        append_arg(args, "type", pkg.typeExpr)
        return "devtools::install_github(" .. table.concat(args, ", ") .. ");"
    end
    if pkg.source == "gitlab" then
        args[#args + 1] = "repo = " .. r_quote(package_target_name(pkg))
        append_arg(args, "subdir", trim(pkg.subdir) ~= "" and r_quote(pkg.subdir) or nil)
        append_arg(args, "host", trim(pkg.host) ~= "" and r_quote(pkg.host) or nil)
        args[#args + 1] = "dependencies = " .. pkg.dependenciesExpr
        args[#args + 1] = "upgrade = " .. pkg.upgradeExpr
        args[#args + 1] = "force = " .. pkg.forceExpr
        args[#args + 1] = "quiet = TRUE"
        args[#args + 1] = "build = " .. pkg.buildExpr
        args[#args + 1] = "build_manual = " .. pkg.buildManualExpr
        args[#args + 1] = "build_vignettes = " .. pkg.buildVignettesExpr
        args[#args + 1] = "repos = repo"
        append_arg(args, "type", pkg.typeExpr)
        return "devtools::install_gitlab(" .. table.concat(args, ", ") .. ");"
    end
    if pkg.source == "bitbucket" then
        args[#args + 1] = "repo = " .. r_quote(package_target_name(pkg))
        append_arg(args, "ref", trim(pkg.ref) ~= "" and r_quote(pkg.ref) or nil)
        append_arg(args, "subdir", trim(pkg.subdir) ~= "" and r_quote(pkg.subdir) or nil)
        append_arg(args, "host", trim(pkg.host) ~= "" and r_quote(pkg.host) or nil)
        args[#args + 1] = "dependencies = " .. pkg.dependenciesExpr
        args[#args + 1] = "upgrade = " .. pkg.upgradeExpr
        args[#args + 1] = "force = " .. pkg.forceExpr
        args[#args + 1] = "quiet = TRUE"
        args[#args + 1] = "build = " .. pkg.buildExpr
        args[#args + 1] = "build_manual = " .. pkg.buildManualExpr
        args[#args + 1] = "build_vignettes = " .. pkg.buildVignettesExpr
        args[#args + 1] = "repos = repo"
        append_arg(args, "type", pkg.typeExpr)
        return "devtools::install_bitbucket(" .. table.concat(args, ", ") .. ");"
    end
    if pkg.source == "git" then
        args[#args + 1] = "url = " .. r_quote(package_target_name(pkg))
        append_arg(args, "ref", trim(pkg.ref) ~= "" and r_quote(pkg.ref) or nil)
        append_arg(args, "subdir", trim(pkg.subdir) ~= "" and r_quote(pkg.subdir) or nil)
        args[#args + 1] = "dependencies = " .. pkg.dependenciesExpr
        args[#args + 1] = "upgrade = " .. pkg.upgradeExpr
        args[#args + 1] = "force = " .. pkg.forceExpr
        args[#args + 1] = "quiet = TRUE"
        args[#args + 1] = "build = " .. pkg.buildExpr
        args[#args + 1] = "build_manual = " .. pkg.buildManualExpr
        args[#args + 1] = "build_vignettes = " .. pkg.buildVignettesExpr
        args[#args + 1] = "repos = repo"
        append_arg(args, "type", pkg.typeExpr)
        return "devtools::install_git(" .. table.concat(args, ", ") .. ");"
    end
    if pkg.source == "svn" then
        args[#args + 1] = "url = " .. r_quote(package_target_name(pkg))
        append_arg(args, "subdir", trim(pkg.subdir) ~= "" and r_quote(pkg.subdir) or nil)
        append_arg(args, "revision", trim(pkg.ref) ~= "" and r_quote(pkg.ref) or nil)
        args[#args + 1] = "dependencies = " .. pkg.dependenciesExpr
        args[#args + 1] = "upgrade = " .. pkg.upgradeExpr
        args[#args + 1] = "force = " .. pkg.forceExpr
        args[#args + 1] = "quiet = TRUE"
        args[#args + 1] = "build = " .. pkg.buildExpr
        args[#args + 1] = "build_manual = " .. pkg.buildManualExpr
        args[#args + 1] = "build_vignettes = " .. pkg.buildVignettesExpr
        args[#args + 1] = "repos = repo"
        append_arg(args, "type", pkg.typeExpr)
        return "devtools::install_svn(" .. table.concat(args, ", ") .. ");"
    end
    if pkg.source == "url" then
        args[#args + 1] = "url = " .. r_quote(package_target_name(pkg))
        append_arg(args, "subdir", trim(pkg.subdir) ~= "" and r_quote(pkg.subdir) or nil)
        args[#args + 1] = "dependencies = " .. pkg.dependenciesExpr
        args[#args + 1] = "upgrade = " .. pkg.upgradeExpr
        args[#args + 1] = "force = " .. pkg.forceExpr
        args[#args + 1] = "quiet = TRUE"
        args[#args + 1] = "build = " .. pkg.buildExpr
        args[#args + 1] = "build_manual = " .. pkg.buildManualExpr
        args[#args + 1] = "build_vignettes = " .. pkg.buildVignettesExpr
        args[#args + 1] = "repos = repo"
        append_arg(args, "type", pkg.typeExpr)
        return "devtools::install_url(" .. table.concat(args, ", ") .. ");"
    end
    if pkg.source == "dev" then
        args[#args + 1] = "package = " .. r_quote(pkg.name)
        args[#args + 1] = "cran_url = repo"
        args[#args + 1] = "quiet = TRUE"
        return "devtools::install_dev(" .. table.concat(args, ", ") .. ");"
    end
    return nil, "unsupported devtools source: " .. pkg.source
end

local function install_local_call(path, repository, context_flags)
    local package_flags = {}
    local args = {
        "path = " .. r_quote(path),
        "dependencies = " .. dependencies_expression(package_flags, context_flags),
        "upgrade = " .. upgrade_expression(package_flags, context_flags),
        "force = " .. bool_expression(package_flags, context_flags, "force", false),
        "quiet = TRUE",
        "build = " .. bool_expression(package_flags, context_flags, "build", true),
        "build_manual = " .. bool_expression(package_flags, context_flags, "build-manual", false),
        "build_vignettes = " .. bool_expression(package_flags, context_flags, "build-vignettes", false),
        "repos = repo",
    }
    local type_value = trim(flag_value(context_flags, "type") or "")
    if type_value ~= "" then
        args[#args + 1] = "type = " .. r_quote(type_value)
    end
    return "devtools::install_local(" .. table.concat(args, ", ") .. ");"
end

local function infer_source_from_item(item)
    local extra = item and item.extraFields or {}
    return lower(extra and extra.remoteType or "")
end

local function matches_request_to_item(pkg, item)
    if item == nil then
        return false
    end
    local requested_name = lower(pkg.name)
    if requested_name == lower(item.name) then
        return true
    end
    local extra = item.extraFields or {}
    if requested_name ~= "" then
        if requested_name == lower(extra.remotePkgRef or "") then
            return true
        end
        if requested_name == lower(extra.remoteUrl or "") then
            return true
        end
        if requested_name == lower(extra.remoteRepo or "") then
            return true
        end
    end
    if pkg.source == "github" or pkg.source == "gitlab" or pkg.source == "bitbucket" then
        local slug = lower(package_target_name(pkg))
        local item_slug = lower(trim((extra.remoteUsername or "") ~= "" and (extra.remoteUsername .. "/" .. (extra.remoteRepo or "")) or ""))
        if slug ~= "" and slug == item_slug then
            return true
        end
    elseif pkg.source == "git" or pkg.source == "svn" or pkg.source == "url" then
        local target = lower(package_target_name(pkg))
        if target ~= "" and target == lower(extra.remoteUrl or "") then
            return true
        end
    end
    return false
end

local function fallback_item_from_package(pkg)
    return {
        name = pkg.name,
        packageId = pkg.name,
        version = pkg.version ~= "" and pkg.version or nil,
        packageType = "r-package",
        extraFields = make_extra_fields({ source = pkg.source }),
    }
end

local function find_installed_item(context, paths, repository, pkg)
    local items = query_installed(context, paths, repository)
    if items == nil then
        return nil
    end
    for _, item in ipairs(items) do
        if matches_request_to_item(pkg, item) then
            return item
        end
    end
    return nil
end

local function resolve_item_or_fallback(context, paths, repository, pkg)
    return find_installed_item(context, paths, repository, pkg) or fallback_item_from_package(pkg)
end

local function normalized_packages(context, packages)
    local context_flags = collect_flags(context, packages)
    local normalized = {}
    for _, raw_pkg in ipairs(packages or {}) do
        local pkg, err = normalize_package(context_flags, raw_pkg)
        if pkg == nil then
            return nil, err
        end
        normalized[#normalized + 1] = pkg
    end
    return normalized, nil, context_flags
end

local function remove_target_name(context, paths, repository, pkg)
    local item = find_installed_item(context, paths, repository, pkg)
    if item ~= nil then
        return item.name, item
    end
    return pkg.name, nil
end

local function update_call_for_item(pkg, installed_item)
    local extra = installed_item and installed_item.extraFields or {}
    local remote_type = lower(extra.remoteType or "")
    if remote_type == "" or remote_type == "cran" or remote_type == "standard" or remote_type == "any" or remote_type == "version" then
        local args = {
            "packages = c(" .. r_quote(installed_item.name) .. ")",
            "dependencies = " .. pkg.dependenciesExpr,
            "upgrade = " .. pkg.upgradeExpr,
            "force = " .. pkg.forceExpr,
            "quiet = TRUE",
            "build = " .. pkg.buildExpr,
            "build_manual = " .. pkg.buildManualExpr,
            "build_vignettes = " .. pkg.buildVignettesExpr,
            "repos = repo",
        }
        append_arg(args, "type", pkg.typeExpr)
        return "devtools::update_packages(" .. table.concat(args, ", ") .. ");"
    end
    if remote_type == "local" then
        return nil, "cannot update local devtools install without original source path"
    end
    if remote_type == "github" then
        local repo_name = trim((extra.remoteUsername or "") ~= "" and (extra.remoteUsername .. "/" .. (extra.remoteRepo or "")) or (extra.remotePkgRef or extra.remoteRepo or installed_item.name))
        local clone = {
            name = repo_name,
            source = "github",
            ref = extra.remoteRef or "",
            subdir = extra.remoteSubdir or "",
            host = extra.remoteHost or "",
            dependenciesExpr = pkg.dependenciesExpr,
            upgradeExpr = pkg.upgradeExpr,
            forceExpr = pkg.forceExpr,
            buildExpr = pkg.buildExpr,
            buildManualExpr = pkg.buildManualExpr,
            buildVignettesExpr = pkg.buildVignettesExpr,
            typeExpr = pkg.typeExpr,
            username = "",
        }
        return install_call_for_package(clone)
    end
    if remote_type == "gitlab" then
        local repo_name = trim((extra.remoteUsername or "") ~= "" and (extra.remoteUsername .. "/" .. (extra.remoteRepo or "")) or (extra.remotePkgRef or extra.remoteRepo or installed_item.name))
        local clone = {
            name = repo_name,
            source = "gitlab",
            subdir = extra.remoteSubdir or "",
            host = extra.remoteHost or "",
            dependenciesExpr = pkg.dependenciesExpr,
            upgradeExpr = pkg.upgradeExpr,
            forceExpr = pkg.forceExpr,
            buildExpr = pkg.buildExpr,
            buildManualExpr = pkg.buildManualExpr,
            buildVignettesExpr = pkg.buildVignettesExpr,
            typeExpr = pkg.typeExpr,
            username = "",
        }
        return install_call_for_package(clone)
    end
    if remote_type == "bitbucket" then
        local repo_name = trim((extra.remoteUsername or "") ~= "" and (extra.remoteUsername .. "/" .. (extra.remoteRepo or "")) or (extra.remotePkgRef or extra.remoteRepo or installed_item.name))
        local clone = {
            name = repo_name,
            source = "bitbucket",
            ref = extra.remoteRef or "",
            subdir = extra.remoteSubdir or "",
            host = extra.remoteHost or "",
            dependenciesExpr = pkg.dependenciesExpr,
            upgradeExpr = pkg.upgradeExpr,
            forceExpr = pkg.forceExpr,
            buildExpr = pkg.buildExpr,
            buildManualExpr = pkg.buildManualExpr,
            buildVignettesExpr = pkg.buildVignettesExpr,
            typeExpr = pkg.typeExpr,
            username = "",
        }
        return install_call_for_package(clone)
    end
    if remote_type == "git" or remote_type == "xgit" or remote_type == "git2r" then
        local clone = {
            name = extra.remoteUrl or installed_item.name,
            url = extra.remoteUrl or "",
            source = "git",
            ref = extra.remoteRef ~= "" and extra.remoteRef or (extra.remoteBranch or ""),
            subdir = extra.remoteSubdir or "",
            dependenciesExpr = pkg.dependenciesExpr,
            upgradeExpr = pkg.upgradeExpr,
            forceExpr = pkg.forceExpr,
            buildExpr = pkg.buildExpr,
            buildManualExpr = pkg.buildManualExpr,
            buildVignettesExpr = pkg.buildVignettesExpr,
            typeExpr = pkg.typeExpr,
        }
        return install_call_for_package(clone)
    end
    if remote_type == "svn" then
        local clone = {
            name = extra.remoteUrl or installed_item.name,
            url = extra.remoteUrl or "",
            source = "svn",
            ref = extra.remoteSha or "",
            subdir = extra.remoteSubdir or "",
            dependenciesExpr = pkg.dependenciesExpr,
            upgradeExpr = pkg.upgradeExpr,
            forceExpr = pkg.forceExpr,
            buildExpr = pkg.buildExpr,
            buildManualExpr = pkg.buildManualExpr,
            buildVignettesExpr = pkg.buildVignettesExpr,
            typeExpr = pkg.typeExpr,
        }
        return install_call_for_package(clone)
    end
    if remote_type == "url" then
        local clone = {
            name = extra.remoteUrl or installed_item.name,
            url = extra.remoteUrl or "",
            source = "url",
            subdir = extra.remoteSubdir or "",
            dependenciesExpr = pkg.dependenciesExpr,
            upgradeExpr = pkg.upgradeExpr,
            forceExpr = pkg.forceExpr,
            buildExpr = pkg.buildExpr,
            buildManualExpr = pkg.buildManualExpr,
            buildVignettesExpr = pkg.buildVignettesExpr,
            typeExpr = pkg.typeExpr,
        }
        return install_call_for_package(clone)
    end
    if remote_type == "dev" then
        local clone = {
            name = installed_item.name,
            source = "dev",
            dependenciesExpr = pkg.dependenciesExpr,
            upgradeExpr = pkg.upgradeExpr,
            forceExpr = pkg.forceExpr,
            buildExpr = pkg.buildExpr,
            buildManualExpr = pkg.buildManualExpr,
            buildVignettesExpr = pkg.buildVignettesExpr,
            typeExpr = pkg.typeExpr,
        }
        return install_call_for_package(clone)
    end
    if remote_type == "bioc_git2r" or remote_type == "bioc_xgit" then
        local clone = {
            name = extra.remoteRepo or installed_item.name,
            source = "bioc",
            mirror = extra.remoteMirror or "",
            dependenciesExpr = pkg.dependenciesExpr,
            upgradeExpr = pkg.upgradeExpr,
            forceExpr = pkg.forceExpr,
            buildExpr = pkg.buildExpr,
            buildManualExpr = pkg.buildManualExpr,
            buildVignettesExpr = pkg.buildVignettesExpr,
            typeExpr = pkg.typeExpr,
        }
        return install_call_for_package(clone)
    end
    return nil, "unsupported installed remote type: " .. remote_type
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
        ecosystemScopes = { "r", "devtools", "cran", "bioc", "github", "gitlab", "bitbucket", "git", "svn" },
        writeScopes = {},
        networkScopes = { "*" },
        privilegeLevel = "none",
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
    local repository = global_repository(nil, packages)
    local installed_items = query_installed(nil, paths, repository)
    if installed_items == nil then
        return packages
    end
    local outdated_items = query_outdated(nil, paths, repository) or {}
    local filtered = {}
    for _, raw_pkg in ipairs(packages) do
        local context_flags = collect_flags(nil, packages)
        local pkg = normalize_package(context_flags, raw_pkg)
        local action = package_action(raw_pkg)
        local installed_item = nil
        for _, item in ipairs(installed_items) do
            if matches_request_to_item(pkg, item) then
                installed_item = item
                break
            end
        end
        if action == "remove" then
            if installed_item ~= nil then
                filtered[#filtered + 1] = raw_pkg
            end
        elseif action == "update" then
            local include = false
            if installed_item ~= nil then
                local remote_type = lower((installed_item.extraFields or {}).remoteType or "")
                if not is_cran_like_remote_type(remote_type) then
                    include = remote_type ~= "local"
                else
                    for _, outdated in ipairs(outdated_items) do
                        if outdated.name == installed_item.name then
                            include = true
                            break
                        end
                    end
                end
            end
            if include then
                filtered[#filtered + 1] = raw_pkg
            end
        elseif installed_item == nil then
            filtered[#filtered + 1] = raw_pkg
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
    local normalized, err, context_flags = normalized_packages(context, requested)
    if normalized == nil then
        return failure(context, err)
    end
    begin_step(context, "install devtools packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local installed = {}
    for _, pkg in ipairs(normalized) do
        local call, call_err = install_call_for_package(pkg)
        if call == nil then
            return failure(context, call_err)
        end
        local result = exec_run(context, rscript_command(paths, pkg.repository, call, pkg.source == "bioc"))
        if not is_success(result) then
            return failure(context, "devtools install failed")
        end
        installed[#installed + 1] = resolve_item_or_fallback(context, paths, pkg.repository, pkg)
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    emit_event(context, "success", "")
    return true
end

function plugin.installLocal(context, path)
    local source_path = trim(path or read_field(context, "localPath") or read_field(context, "path"))
    if source_path == "" then
        return failure(context, "missing local devtools package path")
    end
    local available, message = read_available(context)
    if not available then
        return failure(context, message)
    end
    local requested = {}
    local context_flags = collect_flags(context, requested)
    begin_step(context, "install local devtools package")
    local paths = state_paths(data_root_from_context(context, requested))
    local repository = global_repository(context, requested)
    local result = exec_run(context, rscript_command(paths, repository, install_local_call(source_path, repository, context_flags), false))
    if not is_success(result) then
        return failure(context, "devtools local install failed")
    end
    local item = nil
    local info = query_installed(context, paths, repository)
    if info ~= nil and #info > 0 then
        item = info[#info]
    end
    local installed = { item or { path = source_path, localTarget = true, packageType = "r-package" } }
    emit_event(context, "installed", installed)
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
    local normalized, err = normalized_packages(context, requested)
    if normalized == nil then
        return failure(context, err)
    end
    begin_step(context, "remove devtools packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local repository = global_repository(context, requested)
    local deleted = {}
    for _, pkg in ipairs(normalized) do
        local target_name, item = remove_target_name(context, paths, repository, pkg)
        local body = "utils::remove.packages(pkgs = c(" .. r_quote(target_name) .. "), lib = lib);"
        local result = exec_run(context, rscript_command(paths, repository, body, false))
        if not is_success(result) then
            return failure(context, "devtools remove failed")
        end
        deleted[#deleted + 1] = item or {
            name = target_name,
            packageId = target_name,
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
    local normalized, err = normalized_packages(context, requested)
    if normalized == nil then
        return failure(context, err)
    end
    begin_step(context, "update devtools packages")
    local paths = state_paths(data_root_from_context(context, requested))
    local repository = global_repository(context, requested)
    local updated = {}
    for _, pkg in ipairs(normalized) do
        local installed_item = find_installed_item(context, paths, repository, pkg)
        if installed_item == nil then
            return failure(context, "devtools update target not installed: " .. pkg.name)
        end
        local call, call_err = update_call_for_item(pkg, installed_item)
        if call == nil then
            return failure(context, call_err)
        end
        local include_bioc_manager = lower((installed_item.extraFields or {}).remoteType or "") == "bioc_xgit" or lower((installed_item.extraFields or {}).remoteType or "") == "bioc_git2r"
        local result = exec_run(context, rscript_command(paths, repository, call, include_bioc_manager))
        if not is_success(result) then
            return failure(context, "devtools update failed")
        end
        updated[#updated + 1] = resolve_item_or_fallback(context, paths, repository, pkg)
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
    local repository = global_repository(context, {})
    local items = query_installed(context, paths, repository)
    if items == nil then
        log_warn(context, "devtools list failed")
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
    local repository = global_repository(context, {})
    local items = query_outdated(context, paths, repository)
    if items == nil then
        log_warn(context, "devtools outdated failed")
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
    local repository = global_repository(context, {})
    local items = query_search(context, paths, repository, cleaned_prompt)
    if items == nil then
        log_warn(context, "devtools search failed")
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
    local repository = global_repository(context, {})
    local item = query_info(context, paths, repository, cleaned_name)
    if item == nil then
        log_warn(context, "devtools info failed")
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
    local normalized, err = normalize_package(collect_flags(context, { package }), package)
    if normalized == nil then
        return nil, err
    end
    if not command_exists(context, REQUIRED_BINARY) then
        return fallback_item_from_package(normalized)
    end
    local paths = state_paths(data_root_from_context(context, { package }))
    local item = find_installed_item(context, paths, normalized.repository, normalized)
    if item ~= nil then
        return item
    end
    local info = query_info(context, paths, normalized.repository, normalized.name)
    if info == nil or next(info) == nil then
        return fallback_item_from_package(normalized)
    end
    return info
end

return plugin
