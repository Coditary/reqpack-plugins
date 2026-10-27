plugin = {}

local PLUGIN_ID = "longtalk"
local PLUGIN_NAME = "Longtalk"
local PLUGIN_VERSION = "0.1.0"
local DEFAULT_PACKS_ROOT = "$HOME/logtalk_packs"
local RUNNER_ENV_NAMES = { "LONGTALK_RUNNER", "LOGTALK_RUNNER" }
local KNOWN_RUNNERS = {
    { binary = "swilgt", quietFlag = "-q", goalFlag = "-g" },
    { binary = "tplgt", quietFlag = "-q", goalFlag = "-g" },
    { binary = "yaplgt", quietFlag = "-q", goalFlag = "-g" },
    { binary = "bplgt", quietFlag = "", goalFlag = "-g" },
    { binary = "sicstuslgt", quietFlag = "", goalFlag = "-g" },
    { binary = "gplgt", quietFlag = "--quiet", goalFlag = "--query-goal" },
    { binary = "cxlgt", quietFlag = "--quiet", goalFlag = "--goal" },
    { binary = "eclipselgt", quietFlag = "", goalFlag = "-e" },
}

plugin.fileExtensions = { ".lgt", ".logtalk", ".pl", ".pro" }

local runner_cache = nil

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return tostring(value or ""):lower()
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

local function double_quote(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\")
    text = text:gsub('"', '\\"')
    return '"' .. text .. '"'
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
    local lines = {}
    for line in tostring(value or ""):gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end
    return lines
end

local function split_tsv(line)
    local fields = {}
    for field in (tostring(line or "") .. "\t"):gmatch("(.-)\t") do
        fields[#fields + 1] = field
    end
    return fields
end

local function starts_with(value, prefix)
    local text = tostring(value or "")
    local expected = tostring(prefix or "")
    return text:sub(1, #expected) == expected
end

local function strip_atom_quotes(value)
    local text = trim(value)
    if #text >= 2 and text:sub(1, 1) == "'" and text:sub(-1) == "'" then
        return text:sub(2, -2):gsub("\\'", "'")
    end
    return text
end

local function parse_bool(value)
    return lower(strip_atom_quotes(value)) == "true"
end

local function append_all(target, items)
    for _, item in ipairs(items or {}) do
        target[#target + 1] = item
    end
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

local function exec_run(context, command)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return context.exec.run(command)
    end
    return reqpack.exec.run(command)
end

local function read_env(name)
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

local function packs_root()
    return non_empty(read_env("LOGTALKPACKS")) or DEFAULT_PACKS_ROOT
end

local function sort_items(items)
    table.sort(items, function(left, right)
        local left_key = trim(left.packageId or left.name or "")
        local right_key = trim(right.packageId or right.name or "")
        return left_key < right_key
    end)
    return items
end

local function prolog_atom(value)
    local text = trim(value)
    if text == "" then
        return "''"
    end
    if text:match("^[a-z][a-zA-Z0-9_]*$") then
        return text
    end
    return "'" .. text:gsub("'", "\\'") .. "'"
end

local function prolog_term(value)
    local text = trim(value)
    if text == "" then
        return nil
    end
    return text
end

local function escape_goal(value)
    local text = tostring(value or "")
    text = text:gsub('"', '\\"')
    return text
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return result ~= nil and result.success == true
end

local function resolve_runner_from_binary(context, binary)
    local cleaned = trim(binary)
    if cleaned == "" then
        return nil
    end

    for _, runner in ipairs(KNOWN_RUNNERS) do
        if runner.binary == cleaned and command_exists(context, cleaned) then
            return shallow_copy(runner)
        end
    end

    if command_exists(context, cleaned) then
        return {
            binary = cleaned,
            quietFlag = "",
            goalFlag = "-g",
        }
    end

    return nil
end

local function select_runner(context)
    if runner_cache ~= nil then
        return runner_cache or nil
    end

    for _, env_name in ipairs(RUNNER_ENV_NAMES) do
        local override = non_empty(read_env(env_name))
        if override ~= nil then
            runner_cache = resolve_runner_from_binary(context, override) or false
            return runner_cache or nil
        end
    end

    for _, runner in ipairs(KNOWN_RUNNERS) do
        if command_exists(context, runner.binary) then
            runner_cache = shallow_copy(runner)
            return runner_cache
        end
    end

    runner_cache = false
    return nil
end

local function build_runner_command(context, query)
    local runner = select_runner(context)
    if runner == nil then
        return nil
    end

    local goal = "set_logtalk_flag(report,warnings),logtalk_load(packs(loader)),(" .. query .. "),halt"
    local parts = {
        "env",
        "LOGTALKPACKS=" .. double_quote(packs_root()),
        runner.binary,
    }
    if runner.quietFlag ~= nil and runner.quietFlag ~= "" then
        parts[#parts + 1] = runner.quietFlag
    end
    parts[#parts + 1] = runner.goalFlag
    parts[#parts + 1] = double_quote(escape_goal(goal))
    return table.concat(parts, " ")
end

local function run_query(context, query)
    local command = build_runner_command(context, query)
    if command == nil then
        return nil, "longtalk runner not installed"
    end

    local result = exec_run(context, command)
    if result == nil then
        return nil, "longtalk query failed"
    end
    if not result.success then
        return nil, non_empty(result.stderr) or non_empty(result.stdout) or "longtalk query failed"
    end
    return result.stdout or "", nil
end

local function make_package_id(registry, pack, version)
    local reg = trim(registry)
    local pkg = trim(pack)
    local ver = trim(version or "")
    if reg == "" or pkg == "" then
        return nil
    end
    if ver ~= "" then
        return PLUGIN_ID .. "/" .. reg .. "/" .. pkg .. "/" .. ver
    end
    return PLUGIN_ID .. "/" .. reg .. "/" .. pkg
end

local function parse_selector(name, extra_fields)
    local raw = trim(name)
    local registry = non_empty(read_field(extra_fields, "registry"))
    local pack = raw
    local separator = raw:find("::", 1, true)
    if separator ~= nil then
        registry = trim(raw:sub(1, separator - 1))
        pack = trim(raw:sub(separator + 2))
    end

    registry = non_empty(registry)
    pack = non_empty(pack)
    if pack == nil then
        return nil
    end

    return {
        registry = registry,
        pack = pack,
    }
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

local function build_options_term(pkg)
    local terms = {}
    for _, flag in ipairs(object_flags(pkg)) do
        local cleaned = trim(flag)
        if cleaned == "force" or cleaned == "clean" or cleaned == "verbose" or cleaned == "update" or cleaned == "checksig" then
            terms[#terms + 1] = cleaned .. "(true)"
        elseif cleaned == "no-checksum" then
            terms[#terms + 1] = "checksum(false)"
        elseif cleaned == "incompatible" then
            terms[#terms + 1] = "compatible(false)"
        elseif starts_with(cleaned, "status=") then
            terms[#terms + 1] = "status(" .. trim(cleaned:sub(8)) .. ")"
        elseif starts_with(cleaned, "downloader=") then
            terms[#terms + 1] = "downloader(" .. prolog_atom(cleaned:sub(12)) .. ")"
        elseif starts_with(cleaned, "curl=") then
            terms[#terms + 1] = "curl(" .. prolog_atom(cleaned:sub(6)) .. ")"
        elseif starts_with(cleaned, "wget=") then
            terms[#terms + 1] = "wget(" .. prolog_atom(cleaned:sub(6)) .. ")"
        elseif starts_with(cleaned, "gpg=") then
            terms[#terms + 1] = "gpg(" .. prolog_atom(cleaned:sub(5)) .. ")"
        elseif starts_with(cleaned, "git=") then
            terms[#terms + 1] = "git(" .. prolog_atom(cleaned:sub(5)) .. ")"
        elseif starts_with(cleaned, "tar=") then
            terms[#terms + 1] = "tar(" .. prolog_atom(cleaned:sub(5)) .. ")"
        end
    end
    return "[" .. table.concat(terms, ",") .. "]"
end

local function parse_metadata_rows(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local fields = split_tsv(line)
        if fields[1] == "REQPACK" and fields[2] == "METADATA" then
            local registry = strip_atom_quotes(fields[3])
            local pack = strip_atom_quotes(fields[4])
            local version = strip_atom_quotes(fields[5])
            local summary = strip_atom_quotes(fields[7])
            local license = strip_atom_quotes(fields[8])
            local home = strip_atom_quotes(fields[9])
            local source_url = strip_atom_quotes(fields[10])
            local dependencies = strip_atom_quotes(fields[12])
            local portability = strip_atom_quotes(fields[13])
            local directory = strip_atom_quotes(fields[14])
            local pinned = parse_bool(fields[15])
            local installed = parse_bool(fields[16])
            local loaded = parse_bool(fields[17])
            items[#items + 1] = {
                name = pack,
                packageId = make_package_id(registry, pack, version),
                version = version,
                installed = installed,
                status = installed and "installed" or "available",
                summary = summary ~= "none" and summary or nil,
                description = summary ~= "none" and summary or nil,
                license = license ~= "none" and license or nil,
                homepage = home ~= "none" and home or nil,
                sourceUrl = source_url ~= "none" and source_url or nil,
                packageType = "pack",
                type = "package",
                extraFields = {
                    registry = registry,
                    installDirectory = directory ~= "none" and directory or nil,
                    pinned = pinned,
                    loaded = loaded,
                    dependencies = dependencies ~= "none" and dependencies or nil,
                    portability = portability ~= "none" and portability or nil,
                },
            }
        end
    end
    return items
end

local function parse_outdated_rows(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local fields = split_tsv(line)
        if fields[1] == "REQPACK" and fields[2] == "OUTDATED" then
            local registry = strip_atom_quotes(fields[3])
            local pack = strip_atom_quotes(fields[4])
            local version = strip_atom_quotes(fields[5])
            local latest = strip_atom_quotes(fields[6])
            items[#items + 1] = {
                name = pack,
                packageId = make_package_id(registry, pack, version),
                version = version,
                latestVersion = latest,
                installed = true,
                status = "outdated",
                packageType = "pack",
                type = "package",
                extraFields = {
                    registry = registry,
                },
            }
        end
    end
    return items
end

local function parse_search_rows(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local fields = split_tsv(line)
        if fields[1] == "REQPACK" and fields[2] == "SEARCH" then
            local registry = strip_atom_quotes(fields[3])
            local pack = strip_atom_quotes(fields[4])
            local latest = strip_atom_quotes(fields[5])
            local installed = parse_bool(fields[6])
            local description = strip_atom_quotes(fields[7])
            local home = strip_atom_quotes(fields[8])
            items[#items + 1] = {
                name = pack,
                packageId = make_package_id(registry, pack),
                version = latest ~= "none" and latest or nil,
                latestVersion = latest ~= "none" and latest or nil,
                installed = installed,
                status = installed and "installed" or "available",
                summary = description ~= "none" and description or nil,
                description = description ~= "none" and description or nil,
                sourceUrl = home ~= "none" and home or nil,
                packageType = "pack",
                type = "package",
                extraFields = {
                    registry = registry,
                },
            }
        end
    end
    return items
end

local function parse_info_rows(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local fields = split_tsv(line)
        if fields[1] == "REQPACK" and fields[2] == "INFO" then
            local registry = strip_atom_quotes(fields[3])
            local pack = strip_atom_quotes(fields[4])
            local version = strip_atom_quotes(fields[5])
            local latest = strip_atom_quotes(fields[6])
            local installed = parse_bool(fields[7])
            local pinned = parse_bool(fields[8])
            local description = strip_atom_quotes(fields[9])
            local license = strip_atom_quotes(fields[10])
            local home = strip_atom_quotes(fields[11])
            local source_url = strip_atom_quotes(fields[12])
            local directory = strip_atom_quotes(fields[13])
            local loaded = parse_bool(fields[14])
            local status = installed and "installed" or "available"
            if installed and latest ~= "none" and latest ~= "" and version ~= latest then
                status = "outdated"
            end
            items[#items + 1] = {
                name = pack,
                packageId = make_package_id(registry, pack, installed and version or nil),
                version = version ~= "none" and version or nil,
                latestVersion = latest ~= "none" and latest or nil,
                installed = installed,
                status = status,
                summary = description ~= "none" and description or nil,
                description = description ~= "none" and description or nil,
                license = license ~= "none" and license or nil,
                sourceUrl = source_url ~= "none" and source_url or (home ~= "none" and home or nil),
                packageType = "pack",
                type = "package",
                extraFields = {
                    registry = registry,
                    pinned = pinned,
                    installDirectory = directory ~= "none" and directory or nil,
                    loaded = loaded,
                },
            }
        end
    end
    return items
end

local function parse_resolved_row(stdout)
    for _, line in ipairs(split_lines(stdout)) do
        local fields = split_tsv(line)
        if fields[1] == "REQPACK" and fields[2] == "RESOLVED" then
            return {
                registry = strip_atom_quotes(fields[3]),
                pack = strip_atom_quotes(fields[4]),
                version = strip_atom_quotes(fields[5]),
            }
        end
    end
    return nil
end

local function metadata_query()
    return table.concat({
        "forall(",
        "packs::pack_metadata(Registry,Pack,Version,metadata(Name,Description,License,Home,SourceURL,Checksum,Dependencies,Portability,Directory,Pinned,Installed,Loaded)),",
        "(",
        "write('REQPACK\\tMETADATA\\t'),write(Registry),write('\\t'),write(Pack),write('\\t'),write(Version),",
        "write('\\t'),write(Name),write('\\t'),write(Description),write('\\t'),write(License),write('\\t'),write(Home),",
        "write('\\t'),write(SourceURL),write('\\t'),write(Checksum),write('\\t'),write(Dependencies),write('\\t'),write(Portability),",
        "write('\\t'),write(Directory),write('\\t'),write(Pinned),write('\\t'),write(Installed),write('\\t'),write(Loaded),nl",
        ")",
        ")"
    }, "")
end

local function outdated_query()
    return table.concat({
        "forall(",
        "packs::outdated(Registry,Pack,Version,LatestVersion),",
        "(",
        "write('REQPACK\\tOUTDATED\\t'),write(Registry),write('\\t'),write(Pack),write('\\t'),write(Version),write('\\t'),write(LatestVersion),nl",
        ")",
        ")"
    }, "")
end

local function search_query()
    return table.concat({
        "forall(",
        "(packs::available(Registry,Pack),packs::pack_object(Registry,Pack,Object),",
        "(catch(Object::description(Description),_,Description=none)->true;Description=none),",
        "(catch(Object::home(Home),_,Home=none)->true;Home=none),",
        "(packs::versions(Registry,Pack,Versions),Versions=[LatestVersion|_]->true;LatestVersion=none),",
        "(packs::installed(Registry,Pack,_)->Installed=true;Installed=false)),",
        "(",
        "write('REQPACK\\tSEARCH\\t'),write(Registry),write('\\t'),write(Pack),write('\\t'),write(LatestVersion),write('\\t'),",
        "write(Installed),write('\\t'),write(Description),write('\\t'),write(Home),nl",
        ")",
        ")"
    }, "")
end

local function info_query(registry, pack)
    local reg = prolog_atom(registry)
    local pkg = prolog_atom(pack)
    return table.concat({
        "(packs::pack_object(", reg, ",", pkg, ",Object),",
        "(catch(Object::description(Description),_,Description=none)->true;Description=none),",
        "(catch(Object::license(License),_,License=none)->true;License=none),",
        "(catch(Object::home(Home),_,Home=none)->true;Home=none),",
        "(packs::versions(", reg, ",", pkg, ",Versions),Versions=[LatestVersion|_]->true;LatestVersion=none),",
        "(packs::pack_metadata(", reg, ",", pkg, ",InstalledVersion,metadata(_,_,_,_,SourceURL,_,_,_,Directory,Pinned,Installed,Loaded))->true;",
        "InstalledVersion=LatestVersion,SourceURL=Home,Directory=none,Pinned=false,Installed=false,Loaded=false),",
        "write('REQPACK\\tINFO\\t'),write(", reg, "),write('\\t'),write(", pkg, "),write('\\t'),write(InstalledVersion),",
        "write('\\t'),write(LatestVersion),write('\\t'),write(Installed),write('\\t'),write(Pinned),write('\\t'),",
        "write(Description),write('\\t'),write(License),write('\\t'),write(Home),write('\\t'),write(SourceURL),write('\\t'),",
        "write(Directory),write('\\t'),write(Loaded),nl)"
    }, "")
end

local function resolve_query(selector, version_text)
    local pack_atom = prolog_atom(selector.pack)
    if selector.registry ~= nil then
        local reg_atom = prolog_atom(selector.registry)
        if version_text ~= nil then
            return table.concat({
                "write('REQPACK\\tRESOLVED\\t'),write(", reg_atom, "),write('\\t'),write(", pack_atom, "),write('\\t'),write(", version_text, "),nl"
            }, "")
        end
        return table.concat({
            "packs::versions(", reg_atom, ",", pack_atom, ",Versions),Versions=[ResolvedVersion|_],",
            "write('REQPACK\\tRESOLVED\\t'),write(", reg_atom, "),write('\\t'),write(", pack_atom, "),write('\\t'),write(ResolvedVersion),nl"
        }, "")
    end

    if version_text ~= nil then
        return table.concat({
            "findall(Registry,packs::available(Registry,", pack_atom, "),Registries),sort(Registries,Sorted),Sorted=[ResolvedRegistry],",
            "write('REQPACK\\tRESOLVED\\t'),write(ResolvedRegistry),write('\\t'),write(", pack_atom, "),write('\\t'),write(", version_text, "),nl"
        }, "")
    end

    return table.concat({
        "findall(Registry,packs::available(Registry,", pack_atom, "),Registries),sort(Registries,Sorted),Sorted=[ResolvedRegistry],",
        "packs::versions(ResolvedRegistry,", pack_atom, ",Versions),Versions=[ResolvedVersion|_],",
        "write('REQPACK\\tRESOLVED\\t'),write(ResolvedRegistry),write('\\t'),write(", pack_atom, "),write('\\t'),write(ResolvedVersion),nl"
    }, "")
end

local function resolve_package_request(context, pkg)
    local selector = parse_selector(read_field(pkg, "name"), read_field(pkg, "extraFields"))
    if selector == nil then
        return nil, "longtalk package name missing"
    end

    local version_text = prolog_term(read_field(pkg, "version"))
    local stdout, error_message = run_query(context, resolve_query(selector, version_text))
    if stdout == nil then
        return nil, error_message
    end
    local resolved = parse_resolved_row(stdout)
    if resolved == nil then
        return nil, "longtalk package resolution failed for " .. selector.pack
    end
    return resolved, nil
end

local function fetch_metadata(context)
    local stdout, error_message = run_query(context, metadata_query())
    if stdout == nil then
        return nil, error_message
    end
    return parse_metadata_rows(stdout), nil
end

local function installed_exact(items, resolved)
    for _, item in ipairs(items or {}) do
        if read_field(item.extraFields, "registry") == resolved.registry and item.name == resolved.pack and item.version == resolved.version then
            return true
        end
    end
    return false
end

local function any_installed(items, selector, version)
    for _, item in ipairs(items or {}) do
        local item_registry = read_field(item.extraFields, "registry")
        if item.name == selector.pack and (selector.registry == nil or selector.registry == item_registry) then
            if version == nil or version == "" or item.version == version then
                return true
            end
        end
    end
    return false
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
    return { "Package Manager", "Logtalk", "Wrapper" }
end

function plugin.getMissingPackages(packages)
    local requested = packages or {}
    if #requested == 0 then
        return {}
    end

    if select_runner(nil) == nil then
        return requested
    end

    local installed, error_message = fetch_metadata(nil)
    if installed == nil then
        return requested
    end

    local filtered = {}
    for _, pkg in ipairs(requested) do
        local action = lower(read_field(pkg, "action") or "")
        local selector = parse_selector(read_field(pkg, "name"), read_field(pkg, "extraFields"))
        if selector == nil then
            filtered[#filtered + 1] = pkg
        elseif action == "remove" then
            local version = non_empty(read_field(pkg, "version"))
            if any_installed(installed, selector, version) then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "update" then
            filtered[#filtered + 1] = pkg
        else
            local resolved, _ = resolve_package_request(nil, pkg)
            if resolved == nil or not installed_exact(installed, resolved) then
                filtered[#filtered + 1] = pkg
            end
        end
    end

    return filtered
end

function plugin.install(context, packages)
    if packages == nil or #packages == 0 then
        local local_path = non_empty(read_field(context, "localPath"))
        if local_path ~= nil then
            return plugin.installLocal(context, local_path)
        end
    end

    local requested = packages or {}
    if #requested == 0 then
        local local_path = non_empty(read_field(context, "localPath"))
        if local_path ~= nil then
            return plugin.installLocal(context, local_path)
        end
    end

    if #requested == 0 then
        return true
    end

    begin_step(context, "install longtalk packs")
    if select_runner(context) == nil then
        tx_failed(context, "longtalk runner not installed")
        return false
    end

    local installed = {}
    for _, pkg in ipairs(requested) do
        local resolved, resolve_error = resolve_package_request(context, pkg)
        if resolved == nil then
            tx_failed(context, resolve_error or "longtalk package resolution failed")
            return false
        end

        local query = "packs::install(" .. prolog_atom(resolved.registry) .. "," .. prolog_atom(resolved.pack) .. "," .. prolog_term(resolved.version) .. "," .. build_options_term(pkg) .. ")"
        local _, error_message = run_query(context, query)
        if error_message ~= nil then
            tx_failed(context, error_message)
            return false
        end

        installed[#installed + 1] = {
            name = resolved.pack,
            packageId = make_package_id(resolved.registry, resolved.pack, resolved.version),
            version = resolved.version,
            installed = true,
            status = "installed",
            packageType = "pack",
            type = "package",
            extraFields = {
                registry = resolved.registry,
            },
        }
    end

    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    begin_step(context, "install local longtalk pack")
    tx_failed(context, "longtalk installLocal is not supported; use install with pack name or registry::pack")
    return false
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    begin_step(context, "remove longtalk packs")
    if select_runner(context) == nil then
        tx_failed(context, "longtalk runner not installed")
        return false
    end

    for _, pkg in ipairs(requested) do
        local selector = parse_selector(read_field(pkg, "name"), read_field(pkg, "extraFields"))
        if selector == nil then
            tx_failed(context, "longtalk package name missing")
            return false
        end

        local query = "packs::uninstall(" .. prolog_atom(selector.pack) .. "," .. build_options_term(pkg) .. ")"
        local _, error_message = run_query(context, query)
        if error_message ~= nil then
            tx_failed(context, error_message)
            return false
        end
    end

    emit_event(context, "deleted", requested)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    begin_step(context, "update longtalk packs")
    if select_runner(context) == nil then
        tx_failed(context, "longtalk runner not installed")
        return false
    end

    if #requested == 0 then
        local _, error_message = run_query(context, "packs::update")
        if error_message ~= nil then
            tx_failed(context, error_message)
            return false
        end
        emit_event(context, "updated", {})
        tx_success(context)
        return true
    end

    for _, pkg in ipairs(requested) do
        local selector = parse_selector(read_field(pkg, "name"), read_field(pkg, "extraFields"))
        if selector == nil then
            tx_failed(context, "longtalk package name missing")
            return false
        end

        local version_text = prolog_term(read_field(pkg, "version"))
        local query
        if version_text ~= nil then
            query = "packs::update(" .. prolog_atom(selector.pack) .. "," .. version_text .. "," .. build_options_term(pkg) .. ")"
        else
            query = "packs::update(" .. prolog_atom(selector.pack) .. "," .. build_options_term(pkg) .. ")"
        end

        local _, error_message = run_query(context, query)
        if error_message ~= nil then
            tx_failed(context, error_message)
            return false
        end
    end

    emit_event(context, "updated", requested)
    tx_success(context)
    return true
end

function plugin.list(context)
    if select_runner(context) == nil then
        emit_event(context, "listed", {})
        return {}
    end

    local items, error_message = fetch_metadata(context)
    if items == nil then
        log_warn(context, error_message)
        emit_event(context, "listed", {})
        return {}
    end

    sort_items(items)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    if select_runner(context) == nil then
        emit_event(context, "outdated", {})
        return {}
    end

    local stdout, error_message = run_query(context, outdated_query())
    if stdout == nil then
        log_warn(context, error_message)
        emit_event(context, "outdated", {})
        return {}
    end

    local items = parse_outdated_rows(stdout)
    sort_items(items)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local cleaned_prompt = lower(trim(prompt))
    if cleaned_prompt == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    if select_runner(context) == nil then
        emit_event(context, "searched", {})
        return {}
    end

    local stdout, error_message = run_query(context, search_query())
    if stdout == nil then
        log_warn(context, error_message)
        emit_event(context, "searched", {})
        return {}
    end

    local filtered = {}
    for _, item in ipairs(parse_search_rows(stdout)) do
        local haystack = table.concat({
            lower(item.name or ""),
            lower(read_field(item.extraFields, "registry") or ""),
            lower(item.description or ""),
        }, "\n")
        if haystack:find(cleaned_prompt, 1, true) ~= nil then
            filtered[#filtered + 1] = item
        end
    end

    sort_items(filtered)
    emit_event(context, "searched", filtered)
    return filtered
end

function plugin.info(context, name)
    local selector = parse_selector(name, nil)
    if selector == nil then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    if select_runner(context) == nil then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local resolved = selector
    if resolved.registry == nil then
        local resolved_row, resolve_error = resolve_package_request(context, { name = selector.pack })
        if resolved_row == nil then
            log_warn(context, resolve_error or ("longtalk info ambiguous for " .. selector.pack))
            local empty = {}
            emit_event(context, "informed", empty)
            return empty
        end
        resolved.registry = resolved_row.registry
        resolved.pack = resolved_row.pack
    end

    local stdout, error_message = run_query(context, info_query(resolved.registry, resolved.pack))
    if stdout == nil then
        log_warn(context, error_message)
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local items = parse_info_rows(stdout)
    if #items == 0 then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local item = items[1]
    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if type(package) ~= "table" then
        return nil
    end

    local resolved, _ = resolve_package_request(context, package)
    if resolved == nil then
        return nil
    end

    local copy = shallow_copy(package)
    copy.name = resolved.registry .. "::" .. resolved.pack
    copy.version = resolved.version
    copy.packageId = make_package_id(resolved.registry, resolved.pack, resolved.version)
    copy.packageType = "pack"
    copy.type = "package"
    copy.extraFields = shallow_copy(read_field(package, "extraFields") or {})
    copy.extraFields.registry = resolved.registry
    return copy
end

function plugin.init()
    return select_runner(nil) ~= nil
end

function plugin.shutdown()
    return true
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "logtalk", "prolog" },
        writeScopes = {
            { kind = "user-home-subpath", value = "logtalk_packs" },
        },
        networkScopes = { "github.com", "gitlab.com", "bitbucket.org", "logtalk.org" },
        privilegeLevel = "user",
        purlType = "generic",
    }
end

return plugin
