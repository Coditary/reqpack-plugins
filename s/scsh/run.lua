plugin = {}

local PLUGIN_ID = "scsh"
local PLUGIN_NAME = "scsh"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "scsh-install-pkg"

local function trim(value)
  return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
  return trim(value):lower()
end

local function non_empty(value)
  local text = trim(value)
  if text == "" then
    return nil
  end
  return text
end

local function first_non_empty(...)
  for index = 1, select("#", ...) do
    local value = non_empty(select(index, ...))
    if value ~= nil then
      return value
    end
  end
  return nil
end

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
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

local function split_tsv(line)
  local fields = {}
  for field in (tostring(line or "") .. "\t"):gmatch("(.-)\t") do
    fields[#fields + 1] = field
  end
  return fields
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

local function dirname(path)
  local text = trim(path)
  local parent = text:match("^(.*)[/\\][^/\\]+$")
  if parent == nil or parent == "" then
    return "."
  end
  return parent
end

local function basename(path)
  local cleaned = trim(path):gsub("[/\\]+$", "")
  return cleaned:match("[^/\\]+$") or cleaned
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
  local flags = {}
  for _, item in ipairs(sequence_values(read_field(value, "flags"))) do
    local cleaned = trim(item)
    if cleaned ~= "" then
      flags[#flags + 1] = cleaned
    end
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

local function collect_flags(context, package)
  local flags = {}
  local seen = {}
  local function collect_from(object)
    for _, flag in ipairs(object_flags(object)) do
      append_unique(flags, seen, flag)
    end
  end
  collect_from(context)
  collect_from(read_field(context, "request"))
  collect_from(package)
  return flags
end

local function flag_value(flags, name)
  local prefix = lower(name) .. "="
  for _, flag in ipairs(flags or {}) do
    local cleaned = trim(flag)
    if lower(cleaned):sub(1, #prefix) == prefix then
      return trim(cleaned:sub(#prefix + 1))
    end
  end
  return nil
end

local function starts_with(value, prefix)
  local text = tostring(value or "")
  return text:sub(1, #prefix) == prefix
end

local function sanitize_name(value)
  local text = lower(value):gsub("[^%w%._%-]+", "-")
  text = text:gsub("%-+", "-")
  text = text:gsub("^%-+", ""):gsub("%-+$", "")
  if text == "" then
    return "package"
  end
  return text
end

local function read_proc_environ_value(name)
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

local function fixture_root()
  return non_empty(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT"))
end

local function expand_runtime_placeholders(value)
  local text = tostring(value or "")
  local root = fixture_root()
  if root ~= nil then
    text = text:gsub("%${fixtureRoot}", root)
  end
  return text
end

local function reqpack_path(name)
  local paths = type(reqpack) == "table" and read_field(reqpack, "paths") or nil
  if type(paths) ~= "table" then
    return nil
  end
  return non_empty(read_field(paths, name))
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

local function ensure_directory(context, path)
  local dir = trim(expand_runtime_placeholders(path))
  if dir == "" or dir == "." then
    return true
  end
  local result = exec_run(context, "mkdir -p " .. shell_quote(dir))
  if result ~= nil and result.success == true then
    return true
  end
  if os ~= nil and type(os.execute) == "function" then
    local ok, _, code = os.execute("mkdir -p " .. shell_quote(dir))
    if ok == true or ok == 0 or code == 0 then
      return true
    end
  end
  return false
end

local function read_text_file(context, path)
  local cleaned = expand_runtime_placeholders(path)
  local handle = io.open(cleaned, "rb")
  if handle == nil then
    local result = exec_run(context, "cat " .. shell_quote(cleaned))
    if result ~= nil and result.success == true then
      return result.stdout or ""
    end
    return nil
  end
  local content = handle:read("*a")
  handle:close()
  return content
end

local function write_text_file(context, path, content)
  local cleaned = expand_runtime_placeholders(path)
  if not ensure_directory(context, dirname(cleaned)) then
    return nil, "failed to create directory for " .. cleaned
  end
  local handle, open_error = io.open(cleaned, "wb")
  if handle == nil then
    local result = exec_run(context, "printf %s " .. shell_quote(content or "") .. " > " .. shell_quote(cleaned))
    if result ~= nil and result.success == true then
      return true, nil
    end
    return nil, open_error
  end
  local ok, write_error = handle:write(content or "")
  handle:close()
  if not ok then
    return nil, write_error
  end
  return true, nil
end

local function path_exists(path)
  local cleaned = expand_runtime_placeholders(path)
  local handle = io.open(cleaned, "rb")
  if handle ~= nil then
    handle:close()
    return true
  end
  local result = exec_run(nil, "test -f " .. shell_quote(cleaned))
  if result ~= nil and result.success == true then
    return true
  end
  return false
end

local function command_exists(context, binary)
  local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
  return result ~= nil and result.success == true
end

local function fail_action(context, message)
  tx_failed(context, message)
  return false
end

local function timestamp_now(context)
  if os ~= nil and type(os.date) == "function" then
    local ok, result = pcall(function()
      return os.date("!%Y-%m-%dT%H:%M:%SZ")
    end)
    if ok and result ~= nil then
      return result
    end
  end
  local probe = exec_run(context, "date -u +%Y-%m-%dT%H:%M:%SZ")
  return first_non_empty(probe and probe.stdout, "1970-01-01T00:00:00Z")
end

local function compare_version_tokens(left, right)
  local left_number = tonumber(left)
  local right_number = tonumber(right)
  if left_number ~= nil and right_number ~= nil then
    if left_number < right_number then
      return -1
    end
    if left_number > right_number then
      return 1
    end
    return 0
  end
  if left < right then
    return -1
  end
  if left > right then
    return 1
  end
  return 0
end

local function version_tokens(value)
  local tokens = {}
  local normalized = trim(value):gsub("[-_]+", ".")
  for token in normalized:gmatch("[^%.]+") do
    tokens[#tokens + 1] = token
  end
  if #tokens == 0 and normalized ~= "" then
    tokens[1] = normalized
  end
  return tokens
end

local function compare_versions(left, right)
  local left_tokens = version_tokens(left)
  local right_tokens = version_tokens(right)
  local max_count = math.max(#left_tokens, #right_tokens)
  for index = 1, max_count do
    local left_token = left_tokens[index] or "0"
    local right_token = right_tokens[index] or "0"
    local cmp = compare_version_tokens(left_token, right_token)
    if cmp ~= 0 then
      return cmp
    end
  end
  return 0
end

local function sort_by_name(items)
  table.sort(items, function(left, right)
    local left_name = lower(read_field(left, "name") or read_field(left, "packageId") or "")
    local right_name = lower(read_field(right, "name") or read_field(right, "packageId") or "")
    if left_name == right_name then
      return lower(read_field(left, "version") or "") < lower(read_field(right, "version") or "")
    end
    return left_name < right_name
  end)
end

local function request_packages(context, fallback)
  local request = read_field(context, "request")
  local value = read_field(request, "packages") or read_field(context, "packages") or fallback or {}
  return sequence_values(value)
end

local function request_prompt(context, fallback)
  local request = read_field(context, "request")
  return first_non_empty(fallback, read_field(request, "prompt"), read_field(context, "prompt")) or ""
end

local function request_local_path(context, fallback)
  local request = read_field(context, "request")
  return first_non_empty(fallback, read_field(request, "localPath"), read_field(request, "path"), read_field(context, "localPath"), read_field(context, "path"))
end

local function package_name(pkg)
  return first_non_empty(read_field(pkg, "name"), read_field(pkg, "packageId"))
end

local function package_version(pkg)
  return first_non_empty(read_field(pkg, "version")) or ""
end

local function package_root(context, packages)
  local flags = collect_flags(context, packages ~= nil and packages[1] or nil)
  local explicit = expand_runtime_placeholders(flag_value(flags, "data-root") or "")
  if explicit ~= "" then
    return join_path(explicit, PLUGIN_ID)
  end
  local fixture = fixture_root()
  if fixture ~= nil then
    return join_path(fixture, ".reqpack-data", PLUGIN_ID)
  end
  local data_root = reqpack_path("dataRoot")
  if data_root ~= nil then
    return join_path(data_root, PLUGIN_ID)
  end
  return join_path(".", ".reqpack-data", PLUGIN_ID)
end

local function state_paths(context, packages)
  local root = package_root(context, packages)
  return {
    root = root,
    home = join_path(root, "home"),
    managed = join_path(root, "home", "packages"),
    state = join_path(root, "state"),
    installed = join_path(root, "state", "installed.tsv"),
    cache = join_path(root, "cache"),
    catalog = join_path(root, "cache", "catalog.tsv"),
    tmp = join_path(root, "tmp"),
  }
end

local function ensure_paths(context, paths)
  return ensure_directory(context, paths.root)
    and ensure_directory(context, paths.home)
    and ensure_directory(context, paths.managed)
    and ensure_directory(context, paths.state)
    and ensure_directory(context, paths.cache)
    and ensure_directory(context, paths.tmp)
end

local function installed_record_key(name)
  return lower(name)
end

local function read_installed_records(path)
  local records = {}
  local content = read_text_file(nil, path)
  if content == nil or content == "" then
    return records
  end
  for _, line in ipairs(split_lines(content)) do
    local fields = split_tsv(line)
    local name = non_empty(fields[1])
    if name ~= nil then
      records[installed_record_key(name)] = {
        name = name,
        version = trim(fields[2]),
        destDir = trim(fields[3]),
        sourceKind = trim(fields[4]),
        sourceValue = trim(fields[5]),
        installedAt = trim(fields[6]),
        catalogSource = trim(fields[7]),
      }
    end
  end
  return records
end

local function installed_records_list(records)
  local items = {}
  for _, record in pairs(records or {}) do
    items[#items + 1] = shallow_copy(record)
  end
  sort_by_name(items)
  return items
end

local function write_installed_records(context, path, records)
  local lines = {}
  for _, record in ipairs(installed_records_list(records)) do
    lines[#lines + 1] = table.concat({
      trim(record.name),
      trim(record.version),
      trim(record.destDir),
      trim(record.sourceKind),
      trim(record.sourceValue),
      trim(record.installedAt),
      trim(record.catalogSource),
    }, "\t")
  end
  local payload = ""
  if #lines > 0 then
    payload = table.concat(lines, "\n") .. "\n"
  end
  return write_text_file(context, path, payload)
end

local function read_catalog_items(path)
  local items = {}
  local map = {}
  local content = read_text_file(context, path)
  if content == nil or content == "" then
    return items, map
  end
  for _, line in ipairs(split_lines(content)) do
    local fields = split_tsv(line)
    local name = non_empty(fields[1])
    if name ~= nil then
      local item = {
        name = name,
        packageId = name,
        version = trim(fields[2]),
        summary = trim(fields[3]),
        source = trim(fields[4]),
        homepage = trim(fields[5]),
        license = trim(fields[6]),
      }
      items[#items + 1] = item
      map[installed_record_key(name)] = item
    end
  end
  sort_by_name(items)
  return items, map
end

local function catalog_path_from_flags(context, package, paths)
  local flags = collect_flags(context, package)
  local explicit = flag_value(flags, "catalog")
  if explicit ~= nil then
    return expand_runtime_placeholders(explicit), flag_value(flags, "catalog-name") or explicit
  end
  return paths.catalog, nil
end

local function load_catalog(context, paths, package)
  local explicit_path, explicit_name = catalog_path_from_flags(context, package, paths)
  local chosen_path = explicit_path

  if explicit_path ~= paths.catalog and path_exists(explicit_path) then
    local content = read_text_file(context, explicit_path)
    if content ~= nil then
      write_text_file(context, paths.catalog, content)
    end
  elseif explicit_path ~= paths.catalog and not path_exists(explicit_path) and path_exists(paths.catalog) then
    chosen_path = paths.catalog
  end

  if not path_exists(chosen_path) then
    return {}, {}, explicit_name
  end
  local items, map = read_catalog_items(chosen_path)
  return items, map, explicit_name
end

local function build_item(record, catalog_item)
  local name = first_non_empty(record and record.name, catalog_item and catalog_item.name) or ""
  local version = first_non_empty(record and record.version, catalog_item and catalog_item.version) or ""
  local latest = first_non_empty(catalog_item and catalog_item.version, version) or ""
  local summary = first_non_empty(catalog_item and catalog_item.summary, "scsh package " .. name)
  local item = {
    name = name,
    packageId = name,
    version = version,
    latestVersion = latest ~= version and latest or nil,
    installed = record ~= nil,
    status = record ~= nil and "installed" or "available",
    packageType = "scheme-package",
    type = "package",
    summary = summary,
    description = summary,
  }
  local extra = {}
  if catalog_item ~= nil then
    extra.source = non_empty(catalog_item.source)
    extra.homepage = non_empty(catalog_item.homepage)
    extra.license = non_empty(catalog_item.license)
  end
  if record ~= nil then
    extra.destDir = non_empty(record.destDir)
    extra.sourceKind = non_empty(record.sourceKind)
    extra.sourceValue = non_empty(record.sourceValue)
    extra.installedAt = non_empty(record.installedAt)
    extra.catalogSource = non_empty(record.catalogSource)
  end
  if next(extra) ~= nil then
    item.extraFields = extra
  end
  return item
end

local function exact_prefix_match(query, item)
  return starts_with(lower(read_field(item, "name") or ""), lower(query))
end

local function resolve_dest_dir(context, paths, package, fallback_name)
  local flags = collect_flags(context, package)
  local explicit = flag_value(flags, "dest-dir")
  if explicit ~= nil then
    return expand_runtime_placeholders(explicit)
  end
  return join_path(paths.managed, sanitize_name(fallback_name))
end

local function resolve_phases(context, package)
  return flag_value(collect_flags(context, package), "phases")
end

local function resolve_catalog_source(context, package)
  local flags = collect_flags(context, package)
  return flag_value(flags, "catalog-name") or flag_value(flags, "catalog") or ""
end

local function build_install_command(source, dest_dir, phases)
  local parts = { REQUIRED_BINARY }
  if phases ~= nil and phases ~= "" then
    parts[#parts + 1] = "--phases"
    parts[#parts + 1] = shell_quote(phases)
  end
  parts[#parts + 1] = "--dest-dir"
  parts[#parts + 1] = shell_quote(dest_dir)
  parts[#parts + 1] = shell_quote(source)
  return table.concat(parts, " ")
end

local function tracked_record_for_package(records, package)
  local name = package_name(package)
  if name == nil then
    return nil
  end
  return records[installed_record_key(name)]
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
  return { "scheme", "package-manager", "scsh" }
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
    capabilities = { "exec" },
    ecosystemScopes = { "scheme", "scsh" },
    writeScopes = {},
    networkScopes = {},
    privilegeLevel = "user",
    purlType = "generic",
    versionComparatorProfile = "lexicographic",
  }
end

function plugin.getMissingPackages(packages)
  local requested = packages or {}
  if #requested == 0 then
    return {}
  end
  local paths = state_paths(nil, requested)
  local installed = read_installed_records(paths.installed)
  local missing = {}
  for _, pkg in ipairs(requested) do
    local action = lower(read_field(pkg, "action") or "install")
    local record = tracked_record_for_package(installed, pkg)
    local version = package_version(pkg)
    if action == "remove" or action == "update" then
      if record ~= nil then
        missing[#missing + 1] = pkg
      end
    elseif record == nil then
      missing[#missing + 1] = pkg
    elseif version ~= "" and trim(record.version) ~= version then
      missing[#missing + 1] = pkg
    end
  end
  return missing
end

function plugin.install(context, packages)
  local requested = request_packages(context, packages)
  if #requested == 0 then
    tx_success(context)
    return true
  end
  if not command_exists(context, REQUIRED_BINARY) then
    return fail_action(context, REQUIRED_BINARY .. " binary not available")
  end
  local paths = state_paths(context, requested)
  ensure_paths(context, paths)

  local records = read_installed_records(paths.installed)
  local installed_items = {}
  begin_step(context, "install scsh packages")

  for _, pkg in ipairs(requested) do
    local name = package_name(pkg)
    if name == nil then
      return fail_action(context, "scsh package name missing")
    end
    local dest_dir = resolve_dest_dir(context, paths, pkg, name)
    ensure_directory(context, dest_dir)
    local phases = resolve_phases(context, pkg)
    local result = exec_run(context, build_install_command(name, dest_dir, phases))
    if result == nil or result.success ~= true then
      return fail_action(context, first_non_empty(result and result.stderr, result and result.stdout, "scsh install failed for " .. name))
    end

    local record = {
      name = name,
      version = package_version(pkg),
      destDir = dest_dir,
      sourceKind = "remote",
      sourceValue = name,
      installedAt = timestamp_now(context),
      catalogSource = resolve_catalog_source(context, pkg),
    }
    records[installed_record_key(name)] = record
    installed_items[#installed_items + 1] = build_item(record, nil)
  end

  local ok, error_message = write_installed_records(context, paths.installed, records)
  if not ok then
    return fail_action(context, error_message)
  end

  emit_event(context, "installed", installed_items)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  local local_path = request_local_path(context, path)
  if local_path == nil then
    return fail_action(context, "local scsh package path missing")
  end
  if not command_exists(context, REQUIRED_BINARY) then
    return fail_action(context, REQUIRED_BINARY .. " binary not available")
  end

  local expanded_path = expand_runtime_placeholders(local_path)
  local local_name = sanitize_name(basename(expanded_path))
  local paths = state_paths(context, {})
  ensure_paths(context, paths)
  local records = read_installed_records(paths.installed)
  local dest_dir = resolve_dest_dir(context, paths, nil, local_name)
  ensure_directory(context, dest_dir)

  begin_step(context, "install local scsh package")
  local phases = resolve_phases(context, nil)
  local result = exec_run(context, build_install_command(expanded_path, dest_dir, phases))
  if result == nil or result.success ~= true then
    return fail_action(context, first_non_empty(result and result.stderr, result and result.stdout, "scsh local install failed"))
  end

  local record = {
    name = basename(expanded_path),
    version = "",
    destDir = dest_dir,
    sourceKind = "local",
    sourceValue = expanded_path,
    installedAt = timestamp_now(context),
    catalogSource = resolve_catalog_source(context, nil),
  }
  records[installed_record_key(record.name)] = record
  local ok, error_message = write_installed_records(context, paths.installed, records)
  if not ok then
    return fail_action(context, error_message)
  end

  emit_event(context, "installed", { build_item(record, nil) })
  tx_success(context)
  return true
end

function plugin.remove(context, packages)
  local requested = request_packages(context, packages)
  if #requested == 0 then
    tx_success(context)
    return true
  end

  local paths = state_paths(context, requested)
  local records = read_installed_records(paths.installed)
  local removed_items = {}
  begin_step(context, "remove scsh packages")

  for _, pkg in ipairs(requested) do
    local record = tracked_record_for_package(records, pkg)
    local name = package_name(pkg) or ""
    if record == nil then
      return fail_action(context, "tracked scsh package not found: " .. name)
    end
    if not starts_with(record.destDir, paths.root) then
      return fail_action(context, "refusing to remove unmanaged path: " .. record.destDir)
    end
    local result = exec_run(context, "rm -rf " .. shell_quote(record.destDir))
    if result == nil or result.success ~= true then
      return fail_action(context, first_non_empty(result and result.stderr, result and result.stdout, "failed to remove " .. record.destDir))
    end
    removed_items[#removed_items + 1] = build_item(record, nil)
    records[installed_record_key(record.name)] = nil
  end

  local ok, error_message = write_installed_records(context, paths.installed, records)
  if not ok then
    return fail_action(context, error_message)
  end

  emit_event(context, "deleted", removed_items)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  local requested = request_packages(context, packages)
  local paths = state_paths(context, requested)
  local records = read_installed_records(paths.installed)
  local targets = {}

  if requested == nil or #requested == 0 then
    targets = installed_records_list(records)
  else
    for _, pkg in ipairs(requested) do
      local record = tracked_record_for_package(records, pkg)
      if record == nil then
        return fail_action(context, "tracked scsh package not found: " .. (package_name(pkg) or ""))
      end
      if package_version(pkg) ~= "" then
        record.version = package_version(pkg)
      end
      targets[#targets + 1] = record
    end
  end

  if #targets == 0 then
    tx_success(context)
    return true
  end
  if not command_exists(context, REQUIRED_BINARY) then
    return fail_action(context, REQUIRED_BINARY .. " binary not available")
  end

  begin_step(context, "update scsh packages")
  local updated_items = {}
  for _, record in ipairs(targets) do
    local result = exec_run(context, build_install_command(record.sourceValue, record.destDir, nil))
    if result == nil or result.success ~= true then
      return fail_action(context, first_non_empty(result and result.stderr, result and result.stdout, "scsh update failed for " .. record.name))
    end
    record.installedAt = timestamp_now(context)
    records[installed_record_key(record.name)] = record
    updated_items[#updated_items + 1] = build_item(record, nil)
  end

  local ok, error_message = write_installed_records(context, paths.installed, records)
  if not ok then
    return fail_action(context, error_message)
  end

  emit_event(context, "updated", updated_items)
  tx_success(context)
  return true
end

function plugin.list(context)
  local paths = state_paths(context, {})
  local records = read_installed_records(paths.installed)
  local items = {}
  for _, record in ipairs(installed_records_list(records)) do
    items[#items + 1] = build_item(record, nil)
  end
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  local paths = state_paths(context, {})
  local records = read_installed_records(paths.installed)
  local _, catalog_map = load_catalog(context, paths, nil)
  local items = {}
  for _, record in ipairs(installed_records_list(records)) do
    local catalog_item = catalog_map[installed_record_key(record.name)]
    if catalog_item ~= nil and non_empty(record.version) ~= nil and non_empty(catalog_item.version) ~= nil then
      if compare_versions(record.version, catalog_item.version) < 0 then
        local item = build_item(record, catalog_item)
        item.status = "outdated"
        item.latestVersion = catalog_item.version
        items[#items + 1] = item
      end
    end
  end
  emit_event(context, "outdated", items)
  return items
end

function plugin.search(context, prompt)
  local query = lower(request_prompt(context, prompt))
  if query == "" then
    local empty = {}
    emit_event(context, "searched", empty)
    return empty
  end

  local paths = state_paths(context, {})
  local records = read_installed_records(paths.installed)
  local catalog_items = load_catalog(context, paths, nil)
  local items = {}
  for _, item in ipairs(catalog_items) do
    local haystack = table.concat({
      lower(item.name or ""),
      lower(item.summary or ""),
      lower(item.source or ""),
      lower(item.homepage or ""),
      lower(item.license or ""),
    }, "\n")
    if haystack:find(query, 1, true) ~= nil then
      items[#items + 1] = build_item(records[installed_record_key(item.name)], item)
    end
  end
  if #items == 0 and not path_exists(paths.catalog) then
    log_warn(context, "scsh catalog not available")
  end
  table.sort(items, function(left, right)
    local left_prefix = exact_prefix_match(query, left)
    local right_prefix = exact_prefix_match(query, right)
    if left_prefix ~= right_prefix then
      return left_prefix
    end
    return lower(left.name or "") < lower(right.name or "")
  end)
  emit_event(context, "searched", items)
  return items
end

function plugin.info(context, name)
  local target = request_prompt(context, name)
  if target == "" then
    local empty = {}
    emit_event(context, "informed", empty)
    return empty
  end
  local exact_name = trim(target:match("^([^=]+)=") or target)
  local paths = state_paths(context, {})
  local records = read_installed_records(paths.installed)
  local _, catalog_map = load_catalog(context, paths, nil)
  local record = records[installed_record_key(exact_name)]
  local catalog_item = catalog_map[installed_record_key(exact_name)]
  if record == nil and catalog_item == nil then
    local empty = {}
    emit_event(context, "informed", empty)
    return empty
  end
  local item = build_item(record, catalog_item)
  emit_event(context, "informed", item)
  return item
end

return plugin
