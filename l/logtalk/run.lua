plugin = {}

local PLUGIN_ID = "logtalk"
local PLUGIN_NAME = "Logtalk"
local PLUGIN_VERSION = "0.1.0"
local DEFAULT_RUNNER = "swilgt"
local DEFAULT_REGISTRY = "talkshow"
local DEFAULT_REGISTRY_URL = "https://github.com/LogtalkDotOrg/talkshow.git"
local FIELD_SEPARATOR = "|^|"
local RECORD_PREFIX = "REQPACK" .. FIELD_SEPARATOR

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
        lines[#lines + 1] = line
    end
    return lines
end

local function split_fields(line)
    local fields = {}
    local pattern = "(.-)" .. FIELD_SEPARATOR
    for field in (tostring(line or "") .. FIELD_SEPARATOR):gmatch(pattern) do
        fields[#fields + 1] = field
    end
    return fields
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

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
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

local function is_command_success(result)
    return type(result) == "table" and result.success == true
end

local function command_exists(context, binary)
    local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
    return is_command_success(result)
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
    local cleaned = trim(value)
    if cleaned == "" or seen[cleaned] then
        return
    end
    seen[cleaned] = true
    list[#list + 1] = cleaned
end

local function collect_flags(context, package)
    local flags = {}
    local seen = {}
    local function collect_from(object)
        for _, flag in ipairs(object_flags(object)) do
            append_unique(flags, flag, seen)
        end
    end
    collect_from(context)
    collect_from(read_field(context, "request"))
    collect_from(package)
    return flags
end

local function has_flag(flags, name)
    local wanted = lower(name)
    for _, flag in ipairs(flags or {}) do
        if lower(flag) == wanted then
            return true
        end
    end
    return false
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

local function home_dir()
    if os ~= nil and type(os.getenv) == "function" then
        local value = trim(os.getenv("HOME") or os.getenv("USERPROFILE") or "")
        if value ~= "" then
            return value
        end
    end
    return "/home/test"
end

local function data_root(context, package)
    local flags = collect_flags(context, package)
    local root = flag_value(flags, "data-root")
    if root ~= nil and root ~= "" then
        return root
    end
    return join_path(home_dir(), ".reqpack-data", PLUGIN_ID)
end

local function paths_for(context, package)
    local root = data_root(context, package)
    return {
        dataRoot = root,
        logtalkPacks = join_path(root, "logtalk_packs"),
    }
end

local function runner_for(context, package)
    local flags = collect_flags(context, package)
    return flag_value(flags, "runner") or flag_value(flags, "backend") or DEFAULT_RUNNER
end

local function prolog_atom(value)
    return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

local function normalize_none(value)
    local cleaned = trim(value)
    if cleaned == "" or cleaned == "none" then
        return nil
    end
    return cleaned
end

local function parse_bool(value)
    return lower(value) == "true"
end

local function parse_version(value)
    local cleaned = trim(value)
    if cleaned == "" or cleaned == "none" then
        return nil
    end
    return cleaned
end

local function version_to_prolog(value)
    local cleaned = trim(value)
    if cleaned == "" then
        return nil
    end
    local parts = {}
    for token in cleaned:gmatch("[^%.:]+") do
        local number = tonumber(token)
        if number == nil then
            return nil
        end
        parts[#parts + 1] = tostring(math.floor(number))
    end
    if #parts == 0 then
        return nil
    end
    while #parts < 3 do
        parts[#parts + 1] = "0"
    end
    return table.concat({ parts[1], parts[2], parts[3] }, ":")
end

local function package_request_name(package)
    return trim(read_field(package, "name") or read_field(package, "id") or read_field(package, "package") or "")
end

local function parse_package_ref(context, package, fallback_name)
    local flags = collect_flags(context, package)
    local raw = trim(fallback_name or package_request_name(package) or read_field(context, "prompt") or "")
    if raw == "" then
        return nil
    end
    local registry, name = raw:match("^([^:]+)::(.+)$")
    if registry ~= nil and name ~= nil then
        return {
            raw = raw,
            registry = trim(registry),
            name = trim(name),
        }
    end
    local registry_flag = flag_value(flags, "registry")
    return {
        raw = raw,
        registry = trim(registry_flag or ""),
        name = raw,
    }
end

local function package_id(spec)
    if spec == nil then
        return nil
    end
    if spec.registry ~= nil and spec.registry ~= "" then
        return spec.registry .. "::" .. spec.name
    end
    return spec.name
end

local function sort_by_name(items)
    table.sort(items, function(left, right)
        local left_key = table.concat({ lower(left.registry or ""), lower(left.name or ""), trim(left.version or "") }, "\0")
        local right_key = table.concat({ lower(right.registry or ""), lower(right.name or ""), trim(right.version or "") }, "\0")
        return left_key < right_key
    end)
    return items
end

local function failure_message(result, fallback)
    if type(result) ~= "table" then
        return fallback
    end
    local stderr = trim(result.stderr or "")
    if stderr ~= "" then
        return stderr
    end
    local stdout = trim(result.stdout or "")
    if stdout ~= "" then
        return stdout
    end
    return fallback
end

local function build_runner_command(context, package, goal)
    local runner = runner_for(context, package)
    local paths = paths_for(context, package)
    return "LOGTALKPACKS=" .. shell_quote(paths.logtalkPacks) .. " " .. shell_quote(runner) .. " -q -g " .. shell_quote(goal) .. " -t halt"
end

local function run_goal(context, package, goal)
    local runner = runner_for(context, package)
    if not command_exists(context, runner) then
        return nil, runner .. " binary not available"
    end
    local result = exec_run(context, build_runner_command(context, package, goal))
    if not is_command_success(result) then
        return nil, failure_message(result, "Logtalk command failed")
    end
    return result.stdout or ""
end

local function base_goal(extra)
    return "set_logtalk_flag(report,off),logtalk_load(packs(loader))," .. extra
end

local function ensure_default_registry(context, package)
    local stdout, err = run_goal(context, package, base_goal("(registries::defined(talkshow,_,_,_)->true;registries::add(" .. prolog_atom(DEFAULT_REGISTRY_URL) .. "))"))
    if stdout == nil then
        return nil, err
    end
    local flags = collect_flags(context, package)
    if has_flag(flags, "refresh") then
        local refreshed, refresh_err = run_goal(context, package, base_goal("registries::update(talkshow)"))
        if refreshed == nil then
            return nil, refresh_err
        end
    end
    return true
end

local function query_records(context, package, query, bootstrap)
    if bootstrap then
        local ok, err = ensure_default_registry(context, package)
        if not ok then
            return nil, err
        end
    else
        local runner = runner_for(context, package)
        if not command_exists(context, runner) then
            return nil, runner .. " binary not available"
        end
    end
    local stdout, err = run_goal(context, package, base_goal(query))
    if stdout == nil then
        return nil, err
    end
    local records = {}
    for _, line in ipairs(split_lines(stdout)) do
        if line:sub(1, #RECORD_PREFIX) == RECORD_PREFIX then
            records[#records + 1] = split_fields(line)
        end
    end
    return records
end

local function latest_version_for(context, package, spec)
    local registry = spec.registry
    if registry == nil or registry == "" then
        registry = DEFAULT_REGISTRY
    end
    local query = "once((packs::pack_object(" .. prolog_atom(registry) .. "," .. prolog_atom(spec.name) .. ",O),O::version(V,_,_,_,_,_),V=A:B:C,format('" .. RECORD_PREFIX .. "~d.~d.~d~n',[A,B,C])))"
    local records, err = query_records(context, package, query, true)
    if records == nil then
        return nil, err
    end
    if #records == 0 then
        return nil, "unknown Logtalk pack: " .. package_id({ registry = registry, name = spec.name })
    end
    return parse_version(records[1][2])
end

local function options_to_prolog(context, package, allow_install)
    local flags = collect_flags(context, package)
    local options = {}
    if has_flag(flags, "clean") then
        options[#options + 1] = "clean(true)"
    end
    if has_flag(flags, "verbose") then
        options[#options + 1] = "verbose(true)"
    end
    if has_flag(flags, "force") then
        options[#options + 1] = "force(true)"
    end
    if has_flag(flags, "checksig") then
        options[#options + 1] = "checksig(true)"
    end
    if has_flag(flags, "no-checksum") then
        options[#options + 1] = "checksum(false)"
    end
    if has_flag(flags, "incompatible") then
        options[#options + 1] = "compatible(false)"
    end
    if allow_install and has_flag(flags, "install-missing") then
        options[#options + 1] = "install(true)"
    end
    local status = flag_value(flags, "status")
    if status ~= nil and status ~= "" then
        if lower(status) == "all" then
            options[#options + 1] = "status(all)"
        else
            local status_parts = {}
            for token in status:gmatch("[^,%s]+") do
                status_parts[#status_parts + 1] = lower(token)
            end
            if #status_parts > 0 then
                options[#options + 1] = "status([" .. table.concat(status_parts, ",") .. "])"
            end
        end
    end
    local downloader = flag_value(flags, "downloader")
    if downloader ~= nil and downloader ~= "" then
        options[#options + 1] = "downloader(" .. lower(downloader) .. ")"
    end
    for _, key in ipairs({ "curl", "wget", "git", "gpg", "tar" }) do
        local value = flag_value(flags, key)
        if value ~= nil and value ~= "" then
            options[#options + 1] = key .. "(" .. prolog_atom(value) .. ")"
        end
    end
    return "[" .. table.concat(options, ",") .. "]"
end

local function list_packages_internal(context)
    local query = "forall(packs::pack_metadata(R,P,V,metadata(_,D,L,H,S,_,_,_,Dir,Pinned,true,Loaded)),(V=A:B:C,format('" .. RECORD_PREFIX .. "~w|^|~w|^|~d.~d.~d|^|~w|^|~w|^|~w|^|~w|^|~w|^|~w~n',[R,P,A,B,C,D,L,H,S,Dir,Pinned,Loaded])))"
    local records, err = query_records(context, nil, query, false)
    if records == nil then
        return nil, err
    end
    local items = {}
    for _, fields in ipairs(records) do
        items[#items + 1] = {
            registry = normalize_none(fields[2]),
            name = normalize_none(fields[3]),
            version = parse_version(fields[4]),
            description = normalize_none(fields[5]),
            license = normalize_none(fields[6]),
            homepage = normalize_none(fields[7]),
            sourceUrl = normalize_none(fields[8]),
            directory = normalize_none(fields[9]),
            pinned = parse_bool(fields[10]),
            loaded = parse_bool(fields[11]),
            packageId = package_id({ registry = fields[2], name = fields[3] }),
        }
    end
    return sort_by_name(items)
end

local function search_packages_internal(context, prompt)
    local term = trim(prompt)
    if term == "" then
        return {}
    end
    local query = "forall((registries::provides(R,P),packs::pack_object(R,P,O),((sub_atom(P,_,_,_," .. prolog_atom(term) .. "));(O::description(D0),sub_atom(D0,_,_,_," .. prolog_atom(term) .. "))),once(O::version(V,Status,_,_,_,_)),(O::description(D)->true;D=none),(O::license(L)->true;L=none),(O::home(H)->true;H=none)),(V=A:B:C,format('" .. RECORD_PREFIX .. "~w|^|~w|^|~d.~d.~d|^|~w|^|~w|^|~w|^|~w~n',[R,P,A,B,C,Status,D,L,H])))"
    local records, err = query_records(context, nil, query, true)
    if records == nil then
        return nil, err
    end
    local items = {}
    for _, fields in ipairs(records) do
        items[#items + 1] = {
            registry = normalize_none(fields[2]),
            name = normalize_none(fields[3]),
            version = parse_version(fields[4]),
            status = normalize_none(fields[5]),
            description = normalize_none(fields[6]),
            license = normalize_none(fields[7]),
            homepage = normalize_none(fields[8]),
            packageId = package_id({ registry = fields[2], name = fields[3] }),
        }
    end
    return sort_by_name(items)
end

local function info_internal(context, prompt)
    local spec = parse_package_ref(context, nil, prompt)
    if spec == nil then
        return nil, "missing package name"
    end
    local ref
    if spec.registry ~= nil and spec.registry ~= "" then
        ref = "packs::pack_object(" .. prolog_atom(spec.registry) .. "," .. prolog_atom(spec.name) .. ",O),R=" .. prolog_atom(spec.registry) .. ",P=" .. prolog_atom(spec.name)
    else
        ref = "packs::pack_object(R," .. prolog_atom(spec.name) .. ",O),P=" .. prolog_atom(spec.name)
    end
    local query = "once((" .. ref .. ",(O::description(D)->true;D=none),(O::license(L)->true;L=none),(O::home(H)->true;H=none),(packs::installed(R,P,IV,_)->(IV=IA:IB:IC,format(atom(IS),'~d.~d.~d',[IA,IB,IC]));IS=none),once(O::version(LV,Status,U,_,_,_)),LV=LA:LB:LC,format(atom(LS),'~d.~d.~d',[LA,LB,LC]),format('" .. RECORD_PREFIX .. "~w|^|~w|^|~w|^|~w|^|~w|^|~w|^|~w|^|~w~n',[R,P,IS,LS,Status,D,L,H,U])))"
    local records, err = query_records(context, nil, query, true)
    if records == nil then
        return nil, err
    end
    if #records == 0 then
        return nil, "unknown Logtalk pack: " .. spec.name
    end
    local fields = records[1]
    return {
        registry = normalize_none(fields[2]),
        name = normalize_none(fields[3]),
        installedVersion = parse_version(fields[4]),
        latestVersion = parse_version(fields[5]),
        version = parse_version(fields[4]) or parse_version(fields[5]),
        status = normalize_none(fields[6]),
        description = normalize_none(fields[7]),
        license = normalize_none(fields[8]),
        homepage = normalize_none(fields[9]),
        sourceUrl = normalize_none(fields[10]),
        packageId = package_id({ registry = fields[2], name = fields[3] }),
    }
end

local function outdated_internal(context)
    local options = options_to_prolog(context, nil, false)
    local query = "forall((packs::outdated(R,P,Old,New," .. options .. "),packs::pack_object(R,P,O),(O::description(D)->true;D=none)),(Old=OA:OB:OC,New=NA:NB:NC,format('" .. RECORD_PREFIX .. "~w|^|~w|^|~d.~d.~d|^|~d.~d.~d|^|~w~n',[R,P,OA,OB,OC,NA,NB,NC,D])))"
    local records, err = query_records(context, nil, query, true)
    if records == nil then
        return nil, err
    end
    local items = {}
    for _, fields in ipairs(records) do
        items[#items + 1] = {
            registry = normalize_none(fields[2]),
            name = normalize_none(fields[3]),
            version = parse_version(fields[4]),
            latestVersion = parse_version(fields[5]),
            description = normalize_none(fields[6]),
            packageId = package_id({ registry = fields[2], name = fields[3] }),
        }
    end
    return sort_by_name(items)
end

local function mutation_packages(context, packages)
    local items = {}
    for _, pkg in ipairs(packages or {}) do
        if parse_package_ref(context, pkg) ~= nil then
            items[#items + 1] = pkg
        end
    end
    if #items == 0 and parse_package_ref(context, nil, read_field(context, "prompt") or "") ~= nil then
        items[#items + 1] = { name = read_field(context, "prompt") }
    end
    return items
end

local function install_event_item(spec, version)
    return {
        name = spec.name,
        registry = spec.registry,
        packageId = package_id(spec),
        version = version,
        packageType = "pack",
        type = "package",
    }
end

local function run_mutation(context, package, goal)
    local ok, err = ensure_default_registry(context, package)
    if not ok then
        return nil, err
    end
    local stdout, mutation_err = run_goal(context, package, base_goal(goal))
    if stdout == nil then
        return nil, mutation_err
    end
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
    return { "language", "package-manager", "logic-programming", "prolog" }
end

function plugin.init()
    return command_exists(nil, DEFAULT_RUNNER)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec" },
        ecosystemScopes = { "logtalk", "prolog" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".reqpack-data/logtalk" },
        },
        networkScopes = { "github.com", "logtalk.org" },
        privilegeLevel = "none",
        purlType = "generic",
    }
end

function plugin.resolvePackage(context, package)
    local spec = parse_package_ref(context, package)
    if spec == nil then
        return nil
    end
    if spec.registry == nil or spec.registry == "" then
        spec.registry = DEFAULT_REGISTRY
    end
    spec.packageId = package_id(spec)
    return spec
end

function plugin.getMissingPackages(context, packages)
    local requested = mutation_packages(context, packages)
    local installed, err = list_packages_internal(context)
    if installed == nil then
        return requested
    end
    local present = {}
    for _, item in ipairs(installed) do
        present[lower(item.packageId or item.name)] = true
        present[lower(item.name or "")] = true
    end
    local missing = {}
    for _, pkg in ipairs(requested) do
        local spec = parse_package_ref(context, pkg)
        local action = lower(read_field(pkg, "action") or read_field(context, "action") or "")
        local key = lower(package_id(spec) or spec.name)
        local is_present = present[key] == true or present[lower(spec.name)] == true
        if action == "remove" then
            if is_present then
                missing[#missing + 1] = pkg
            end
        elseif action == "update" then
            missing[#missing + 1] = pkg
        else
            if not is_present then
                missing[#missing + 1] = pkg
            end
        end
    end
    return missing
end

function plugin.install(context, packages)
    local requested = mutation_packages(context, packages)
    if #requested == 0 then
        return true
    end
    local installed = {}
    for _, pkg in ipairs(requested) do
        local spec = parse_package_ref(context, pkg)
        if spec.registry == nil or spec.registry == "" then
            spec.registry = DEFAULT_REGISTRY
        end
        local version = trim(read_field(pkg, "version") or "")
        if version == "" then
            local resolved, err = latest_version_for(context, pkg, spec)
            if resolved == nil then
                tx_failed(context, err)
                return false
            end
            version = resolved
        end
        local prolog_version = version_to_prolog(version)
        if prolog_version == nil then
            tx_failed(context, "invalid Logtalk pack version: " .. tostring(version))
            return false
        end
        begin_step(context, "Installing " .. package_id(spec))
        local options = options_to_prolog(context, pkg, false)
        local ok, err = run_mutation(context, pkg, "packs::install(" .. prolog_atom(spec.registry) .. "," .. prolog_atom(spec.name) .. "," .. prolog_version .. "," .. options .. ")")
        if not ok then
            tx_failed(context, err)
            return false
        end
        installed[#installed + 1] = install_event_item(spec, version)
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local local_path = trim(path or read_field(context, "localPath") or "")
    if local_path == "" then
        tx_failed(context, "missing local path")
        return false
    end
    local message = "installLocal is not supported for Logtalk packs"
    emit_event(context, "unavailable", { path = local_path, reason = "local-install-unsupported" })
    tx_failed(context, message)
    return false
end

function plugin.remove(context, packages)
    local requested = mutation_packages(context, packages)
    if #requested == 0 then
        return true
    end
    local removed = {}
    for _, pkg in ipairs(requested) do
        local spec = parse_package_ref(context, pkg)
        begin_step(context, "Removing " .. spec.name)
        local options = options_to_prolog(context, pkg, false)
        local ok, err = run_mutation(context, pkg, "packs::uninstall(" .. prolog_atom(spec.name) .. "," .. options .. ")")
        if not ok then
            tx_failed(context, err)
            return false
        end
        removed[#removed + 1] = install_event_item(spec, read_field(pkg, "version"))
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = mutation_packages(context, packages)
    if #requested == 0 then
        return true
    end
    local updated = {}
    for _, pkg in ipairs(requested) do
        local spec = parse_package_ref(context, pkg)
        local version = trim(read_field(pkg, "version") or "")
        local options = options_to_prolog(context, pkg, true)
        begin_step(context, "Updating " .. spec.name)
        local goal
        if version ~= "" then
            local prolog_version = version_to_prolog(version)
            if prolog_version == nil then
                tx_failed(context, "invalid Logtalk pack version: " .. tostring(version))
                return false
            end
            goal = "packs::update(" .. prolog_atom(spec.name) .. "," .. prolog_version .. "," .. options .. ")"
        else
            goal = "packs::update(" .. prolog_atom(spec.name) .. "," .. options .. ")"
        end
        local ok, err = run_mutation(context, pkg, goal)
        if not ok then
            tx_failed(context, err)
            return false
        end
        updated[#updated + 1] = install_event_item(spec, version ~= "" and version or nil)
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items, err = list_packages_internal(context)
    if items == nil then
        log_warn(context, err)
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items, err = outdated_internal(context)
    if items == nil then
        log_warn(context, err)
        items = {}
    end
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local term = trim(prompt or read_field(context, "prompt") or "")
    local items, err = search_packages_internal(context, term)
    if items == nil then
        log_warn(context, err)
        items = {}
    end
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local item, err = info_internal(context, name or read_field(context, "prompt"))
    if item == nil then
        log_warn(context, err)
        return nil
    end
    emit_event(context, "informed", item)
    return item
end

function plugin.shutdown()
    return true
end

return plugin
