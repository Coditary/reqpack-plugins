plugin = {}

local PLUGIN_ID = "miktex"
local PLUGIN_NAME = "MiKTeX"
local PLUGIN_VERSION = "0.1.0"
local TEMPLATE_SEPARATOR = "|@|"
local CATALOG_TEMPLATE = table.concat({
  "{id}",
  "{displayName}",
  "{title}",
  "{version}",
  "{isInstalled}",
  "{isObsolete}",
  "{isRemovable}",
  "{licenseType}",
  "{ctanPath}",
  "{requiredPackages}",
  "{targetSystem}",
}, TEMPLATE_SEPARATOR)
local DETECT_MIKTEX_COMMAND = "command -v miktex 2>/dev/null"

local function trim(value)
  return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
  return string.lower(tostring(value or ""))
end

local function non_empty(value)
  local text = trim(value)
  if text == "" then
    return nil
  end
  return text
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

local function starts_with(value, prefix)
  local text = tostring(value or "")
  local wanted = tostring(prefix or "")
  return wanted == "" or text:sub(1, #wanted) == wanted
end

local function is_safe_token(value)
  return tostring(value or ""):match("^[A-Za-z0-9_./:@%%+=,-]+$") ~= nil
end

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function shell_arg(value)
  local text = tostring(value or "")
  if is_safe_token(text) then
    return text
  end
  return shell_quote(text)
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
  local text = trim(path)
  if text == "" then
    return "."
  end
  local parent = text:match("^(.*)/[^/]+$")
  if parent == nil or parent == "" then
    return "."
  end
  return parent
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

local function split_simple_list(value)
  local text = trim(value)
  if text == "" then
    return {}
  end
  local separator = nil
  if text:find(";", 1, true) ~= nil then
    separator = ";"
  elseif text:find(",", 1, true) ~= nil then
    separator = ","
  end
  if separator == nil then
    return { text }
  end
  local items = {}
  for part in text:gmatch("([^" .. separator .. "]+)") do
    local normalized = trim(part)
    if normalized ~= "" then
      items[#items + 1] = normalized
    end
  end
  return items
end

local function normalize_exec_result(first, second, third, fourth, fifth)
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

  local function merge_table(value)
    for key, item in pairs(value or {}) do
      result[key] = item
    end
  end

  local function apply_scalar(value)
    local value_type = type(value)
    if value_type == "table" then
      merge_table(value)
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
  local first, second, third, fourth, fifth
  if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
    first, second, third, fourth, fifth = context.exec.run(command)
  elseif reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
    first, second, third, fourth, fifth = reqpack.exec.run(command)
  else
    first = {
      success = false,
      stdout = "",
      stderr = "reqpack.exec.run unavailable",
      exitCode = 127,
    }
  end
  return normalize_exec_result(first, second, third, fourth, fifth)
end

local function read_proc_environ_value(name)
  if os ~= nil and type(os.getenv) == "function" then
    local direct = os.getenv(tostring(name or ""))
    if direct ~= nil and direct ~= "" then
      return trim(direct)
    end
  end
  if reqpack ~= nil and reqpack.host ~= nil and type(reqpack.host.env) == "table" then
    local host_value = reqpack.host.env[name]
    if host_value ~= nil and host_value ~= "" then
      return trim(host_value)
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
    if starts_with(entry, prefix) then
      return trim(entry:sub(#prefix + 1))
    end
  end
  return nil
end

local function object_flags(value)
  local raw = read_field(value, "flags")
  if type(raw) ~= "table" and type(raw) ~= "userdata" then
    return {}
  end
  local result = {}
  local ok = pcall(function()
    for _, item in ipairs(raw) do
      local text = trim(item)
      if text ~= "" then
        result[#result + 1] = text
      end
    end
  end)
  if not ok then
    return {}
  end
  return result
end

local function request_flags(context, package)
  local result = {}
  for _, item in ipairs(object_flags(context)) do
    result[#result + 1] = item
  end
  local request = read_field(context, "request")
  for _, item in ipairs(object_flags(request)) do
    result[#result + 1] = item
  end
  for _, item in ipairs(object_flags(package)) do
    result[#result + 1] = item
  end
  return result
end

local function flag_present(flags, name)
  local wanted = lower(name)
  for _, item in ipairs(flags or {}) do
    if lower(trim(item)) == wanted then
      return true
    end
  end
  return false
end

local function flag_value(flags, prefix)
  for _, item in ipairs(flags or {}) do
    local text = trim(item)
    if starts_with(lower(text), lower(prefix)) then
      return trim(text:sub(#prefix + 1))
    end
  end
  return nil
end

local function catalog_cache_root(flags)
  local configured = non_empty(flag_value(flags or {}, "cache-root="))
  if configured ~= nil then
    return join_path(configured, PLUGIN_ID)
  end
  local fixture_root = non_empty(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT"))
  if fixture_root ~= nil then
    return join_path(fixture_root, "cache", "reqpack", PLUGIN_ID)
  end
  local xdg_cache_home = non_empty(read_proc_environ_value("XDG_CACHE_HOME"))
  if xdg_cache_home ~= nil then
    return join_path(xdg_cache_home, "reqpack", PLUGIN_ID)
  end
  local home = non_empty(read_proc_environ_value("HOME"))
  if home ~= nil then
    return join_path(home, ".cache", "reqpack", PLUGIN_ID)
  end
  return nil
end

local function catalog_cache_path()
  local root = catalog_cache_root()
  if root == nil then
    return nil
  end
  return join_path(root, "catalog.tsv")
end

local function catalog_cache_path_for_flags(flags)
  local root = catalog_cache_root(flags)
  if root == nil then
    return nil
  end
  return join_path(root, "catalog.tsv")
end

local function read_text_file(context, path)
  local result = exec_run(context, "cat " .. shell_quote(path))
  if not result.success then
    return nil
  end
  return result.stdout
end

local function ensure_dir(context, path)
  local result = exec_run(context, "mkdir -p " .. shell_arg(path))
  if not result.success then
    return false, trim(result.stderr ~= "" and result.stderr or result.stdout)
  end
  return true
end

local function write_text_file(context, path, content)
  local ok, err = ensure_dir(context, parent_dir(path))
  if not ok then
    return false, err
  end
  local command = "printf %s " .. shell_quote(content or "") .. " > " .. shell_quote(path)
  local result = exec_run(context, command)
  if not result.success then
    return false, trim(result.stderr ~= "" and result.stderr or result.stdout)
  end
  return true
end

local function detect_miktex_binary(context)
  local result = exec_run(context, DETECT_MIKTEX_COMMAND)
  if not result.success then
    return nil
  end
  local line = trim((result.stdout or ""):match("([^\r\n]+)"))
  if line == "" then
    return nil
  end
  return line
end

local function build_miktex_command(miktex_binary, flags, subcommand, args, repository)
  local parts = { shell_arg(miktex_binary) }
  if flag_present(flags, "admin") then
    parts[#parts + 1] = "--admin"
  end
  parts[#parts + 1] = "packages"
  parts[#parts + 1] = subcommand
  if repository ~= nil and repository ~= "" then
    parts[#parts + 1] = shell_arg(repository)
  end
  for _, item in ipairs(args or {}) do
    parts[#parts + 1] = shell_arg(item)
  end
  return table.concat(parts, " ")
end

local function build_update_db_command(miktex_binary, flags)
  return build_miktex_command(miktex_binary, flags, "update-package-database", {}, flag_value(flags, "repository="))
end

local function build_check_update_command(miktex_binary, flags)
  return build_miktex_command(miktex_binary, flags, "check-update", {}, flag_value(flags, "repository="))
end

local function parse_catalog_record(line)
  local fields = {}
  local pattern = "([^|]+|@|?)"
  local remaining = tostring(line or "")
  local start_index = 1
  while true do
    local plain_start, plain_end = remaining:find(TEMPLATE_SEPARATOR, start_index, true)
    if plain_start == nil then
      fields[#fields + 1] = remaining:sub(start_index)
      break
    end
    fields[#fields + 1] = remaining:sub(start_index, plain_start - 1)
    start_index = plain_end + 1
  end
  if #fields < 11 then
    return nil
  end

  local id = trim(fields[1])
  if id == "" then
    return nil
  end

  local installed = lower(fields[5]) == "true"
  local obsolete = lower(fields[6]) == "true"
  local removable = lower(fields[7]) == "true"
  local version = trim(fields[4])
  local ctan_path = trim(fields[9])
  local homepage = nil
  if ctan_path ~= "" then
    if starts_with(ctan_path, "/") then
      homepage = "https://ctan.org" .. ctan_path
    else
      homepage = "https://ctan.org/" .. ctan_path
    end
  end

  local item = {
    name = id,
    packageId = id,
    version = version ~= "" and version or nil,
    latestVersion = version ~= "" and version or nil,
    installed = installed,
    status = obsolete and "obsolete" or (installed and "installed" or "available"),
    summary = non_empty(fields[3]) or non_empty(fields[2]) or id,
    description = non_empty(fields[3]) or non_empty(fields[2]) or id,
    homepage = homepage,
    license = non_empty(fields[8]),
    dependencies = split_simple_list(fields[10]),
    extraFields = {
      displayName = non_empty(fields[2]),
      title = non_empty(fields[3]),
      isInstalled = tostring(installed),
      isObsolete = tostring(obsolete),
      isRemovable = tostring(removable),
      ctanPath = ctan_path ~= "" and ctan_path or nil,
      targetSystem = non_empty(fields[11]),
    },
  }

  return item
end

local function parse_catalog_payload(payload)
  local items = {}
  for _, line in ipairs(split_lines(payload)) do
    local item = parse_catalog_record(line)
    if item ~= nil then
      items[#items + 1] = item
    end
  end
  return items
end

local function read_catalog_cache(context, flags)
  local path = catalog_cache_path_for_flags(flags)
  if path == nil then
    return nil
  end
  local payload = read_text_file(context, path)
  if payload == nil then
    return nil
  end
  return parse_catalog_payload(payload)
end

local function refresh_catalog_cache(context, flags, miktex_binary)
  local cache_path = catalog_cache_path_for_flags(flags)
  if cache_path == nil then
    return nil, "catalog cache path unavailable"
  end
  local command = build_miktex_command(miktex_binary, flags, "list", { "--template", CATALOG_TEMPLATE })
  local result = exec_run(context, command)
  if not result.success then
    return nil, trim(result.stderr ~= "" and result.stderr or result.stdout)
  end
  local ok, err = write_text_file(context, cache_path, result.stdout or "")
  if not ok then
    return nil, err
  end
  return parse_catalog_payload(result.stdout or "")
end

local function load_catalog(context, flags, miktex_binary)
  local cached = read_catalog_cache(context, flags)
  if cached ~= nil then
    return cached
  end
  return refresh_catalog_cache(context, flags, miktex_binary)
end

local function direct_info(context, flags, miktex_binary, package_name)
  local command = build_miktex_command(miktex_binary, flags, "info", { "--template", CATALOG_TEMPLATE, package_name })
  local result = exec_run(context, command)
  if not result.success then
    return nil, trim(result.stderr ~= "" and result.stderr or result.stdout)
  end
  local items = parse_catalog_payload(result.stdout or "")
  if #items == 0 then
    return nil, "package not found"
  end
  return items[1]
end

local function exact_match(items, query)
  local wanted = lower(trim(query))
  if wanted == "" then
    return nil
  end

  for _, item in ipairs(items or {}) do
    if lower(trim(item.packageId)) == wanted then
      return shallow_copy(item)
    end
  end
  for _, item in ipairs(items or {}) do
    local display_name = read_field(item.extraFields or {}, "displayName")
    if lower(trim(display_name)) == wanted then
      return shallow_copy(item)
    end
  end
  for _, item in ipairs(items or {}) do
    local title = read_field(item.extraFields or {}, "title")
    if lower(trim(title)) == wanted then
      return shallow_copy(item)
    end
  end
  return nil
end

local function resolve_requested_package(context, package, options)
  local opts = options or {}
  local flags = opts.flags or {}
  local miktex_binary = opts.miktex_binary
  if miktex_binary == nil then
    return nil, "miktex not installed"
  end

  local query = non_empty(read_field(package, "packageId")) or non_empty(read_field(package, "name"))
  if query == nil then
    return nil, "missing package name"
  end

  local item = select(1, direct_info(context, flags, miktex_binary, query))
  if item ~= nil then
    return item
  end

  local catalog = load_catalog(context, flags, miktex_binary)
  if type(catalog) == "table" then
    local matched = exact_match(catalog, query)
    if matched ~= nil then
      return matched
    end
  end

  return nil, "package not found: " .. query
end

local function package_names(items)
  local names = {}
  for _, item in ipairs(items or {}) do
    names[#names + 1] = item.packageId or item.name
  end
  return names
end

local function run_checked(context, label, command)
  begin_step(context, label)
  local result = exec_run(context, command)
  if not result.success then
    local message = trim(result.stderr ~= "" and result.stderr or result.stdout)
    tx_failed(context, message ~= "" and message or (label .. " failed"))
    return false, message
  end
  return true, result.stdout
end

local function search_catalog(items, prompt)
  local needle = lower(trim(prompt))
  if needle == "" then
    return {}
  end

  local ranked = {}
  for _, item in ipairs(items or {}) do
    local display_name = lower(read_field(item.extraFields or {}, "displayName") or "")
    local title = lower(read_field(item.extraFields or {}, "title") or "")
    local package_id = lower(item.packageId or item.name or "")
    local score = nil

    if package_id == needle then
      score = 1
    elseif display_name == needle or title == needle then
      score = 2
    elseif starts_with(package_id, needle) then
      score = 3
    elseif starts_with(display_name, needle) or starts_with(title, needle) then
      score = 4
    elseif package_id:find(needle, 1, true) ~= nil or display_name:find(needle, 1, true) ~= nil or title:find(needle, 1, true) ~= nil then
      score = 5
    end

    if score ~= nil then
      ranked[#ranked + 1] = { score = score, item = shallow_copy(item) }
    end
  end

  table.sort(ranked, function(left, right)
    if left.score ~= right.score then
      return left.score < right.score
    end
    return lower(left.item.packageId or left.item.name or "") < lower(right.item.packageId or right.item.name or "")
  end)

  local results = {}
  for _, entry in ipairs(ranked) do
    results[#results + 1] = entry.item
  end
  return results
end

local function missing_due_to_action(pkg, resolved)
  local action = lower(read_field(pkg, "action") or "install")
  if action == "remove" then
    return resolved.installed == true
  end
  if action == "update" then
    return resolved.installed == true
  end
  return resolved.installed ~= true
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
  return { "Package Manager", "TeX", "MiKTeX", "Wrapper" }
end

function plugin.getMissingPackages(packages)
  local items = packages or {}
  local miktex_binary = detect_miktex_binary(nil)
  if miktex_binary == nil then
    local missing = {}
    for _, pkg in ipairs(items) do
      local action = lower(read_field(pkg, "action") or "install")
      if action ~= "remove" and action ~= "update" then
        missing[#missing + 1] = pkg
      end
    end
    return missing
  end

  local missing = {}
  for _, pkg in ipairs(items) do
    local flags = request_flags(nil, pkg)
    local resolved = select(1, resolve_requested_package(nil, pkg, {
      flags = flags,
      miktex_binary = miktex_binary,
    }))
    if resolved == nil or missing_due_to_action(pkg, resolved) then
      missing[#missing + 1] = pkg
    end
  end
  return missing
end

function plugin.install(context, packages)
  local requested = packages or {}
  if #requested == 0 then
    return true
  end

  local miktex_binary = detect_miktex_binary(context)
  if miktex_binary == nil then
    tx_failed(context, "miktex not installed")
    emit_event(context, "unavailable", { reason = "miktex-not-installed" })
    return false
  end

  local flags = request_flags(context, requested[1])
  local ok = select(1, run_checked(context, "refresh miktex package database", build_update_db_command(miktex_binary, flags)))
  if not ok then
    return false
  end

  local resolved = {}
  for _, pkg in ipairs(requested) do
    local item, err = resolve_requested_package(context, pkg, {
      flags = flags,
      miktex_binary = miktex_binary,
    })
    if item == nil then
      emit_event(context, "unavailable", {
        name = read_field(pkg, "name") or read_field(pkg, "packageId"),
        reason = err,
      })
      tx_failed(context, err)
      return false
    end
    resolved[#resolved + 1] = item
  end

  ok = select(1, run_checked(context, "install miktex packages", build_miktex_command(miktex_binary, flags, "install", package_names(resolved), flag_value(flags, "repository="))))
  if not ok then
    return false
  end

  local refreshed, refresh_error = refresh_catalog_cache(context, flags, miktex_binary)
  if refreshed == nil then
    log_warn(context, "miktex catalog cache refresh failed: " .. tostring(refresh_error))
  end

  emit_event(context, "installed", resolved)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  begin_step(context, "install local miktex package")
  tx_failed(context, "miktex local installs are not supported")
  emit_event(context, "unavailable", {
    path = path,
    reason = "local-install-unsupported",
  })
  return false
end

function plugin.remove(context, packages)
  local requested = packages or {}
  if #requested == 0 then
    return true
  end

  local miktex_binary = detect_miktex_binary(context)
  if miktex_binary == nil then
    tx_failed(context, "miktex not installed")
    emit_event(context, "unavailable", { reason = "miktex-not-installed" })
    return false
  end

  local flags = request_flags(context, requested[1])
  local resolved = {}
  for _, pkg in ipairs(requested) do
    local item, err = resolve_requested_package(context, pkg, {
      flags = flags,
      miktex_binary = miktex_binary,
    })
    if item == nil then
      emit_event(context, "unavailable", {
        name = read_field(pkg, "name") or read_field(pkg, "packageId"),
        reason = err,
      })
      tx_failed(context, err)
      return false
    end
    resolved[#resolved + 1] = item
  end

  local ok = select(1, run_checked(context, "remove miktex packages", build_miktex_command(miktex_binary, flags, "remove", package_names(resolved))))
  if not ok then
    return false
  end

  local refreshed, refresh_error = refresh_catalog_cache(context, flags, miktex_binary)
  if refreshed == nil then
    log_warn(context, "miktex catalog cache refresh failed: " .. tostring(refresh_error))
  end

  emit_event(context, "deleted", resolved)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  local requested = packages or {}
  if #requested == 0 then
    return true
  end

  local miktex_binary = detect_miktex_binary(context)
  if miktex_binary == nil then
    tx_failed(context, "miktex not installed")
    emit_event(context, "unavailable", { reason = "miktex-not-installed" })
    return false
  end

  local flags = request_flags(context, requested[1])
  local ok = select(1, run_checked(context, "refresh miktex package database", build_update_db_command(miktex_binary, flags)))
  if not ok then
    return false
  end

  local resolved = {}
  for _, pkg in ipairs(requested) do
    local item, err = resolve_requested_package(context, pkg, {
      flags = flags,
      miktex_binary = miktex_binary,
    })
    if item == nil then
      emit_event(context, "unavailable", {
        name = read_field(pkg, "name") or read_field(pkg, "packageId"),
        reason = err,
      })
      tx_failed(context, err)
      return false
    end
    resolved[#resolved + 1] = item
  end

  ok = select(1, run_checked(context, "update miktex packages", build_miktex_command(miktex_binary, flags, "update", package_names(resolved), flag_value(flags, "repository="))))
  if not ok then
    return false
  end

  local refreshed, refresh_error = refresh_catalog_cache(context, flags, miktex_binary)
  if refreshed == nil then
    log_warn(context, "miktex catalog cache refresh failed: " .. tostring(refresh_error))
  end

  emit_event(context, "updated", resolved)
  tx_success(context)
  return true
end

function plugin.list(context)
  local miktex_binary = detect_miktex_binary(context)
  if miktex_binary == nil then
    emit_event(context, "unavailable", { reason = "miktex-not-installed" })
    return {}
  end

  local flags = request_flags(context)
  local items, err = load_catalog(context, flags, miktex_binary)
  if items == nil then
    emit_event(context, "unavailable", { reason = err })
    return {}
  end

  local installed = {}
  for _, item in ipairs(items) do
    if item.installed then
      installed[#installed + 1] = shallow_copy(item)
    end
  end
  emit_event(context, "listed", installed)
  return installed
end

function plugin.outdated(context)
  local miktex_binary = detect_miktex_binary(context)
  if miktex_binary == nil then
    emit_event(context, "unavailable", { reason = "miktex-not-installed" })
    return {}
  end

  local flags = request_flags(context)
  local result = exec_run(context, build_check_update_command(miktex_binary, flags))
  if result.exitCode == 0 then
    local empty = {}
    emit_event(context, "outdated", empty)
    return empty
  end
  if result.exitCode == 100 then
    log_warn(context, "miktex reports package updates exist, but stable CLI does not enumerate package names")
    local empty = {}
    emit_event(context, "outdated", empty)
    return empty
  end

  emit_event(context, "unavailable", {
    reason = trim(result.stderr ~= "" and result.stderr or result.stdout),
  })
  return {}
end

function plugin.search(context, prompt)
  if trim(prompt) == "" then
    local empty = {}
    emit_event(context, "searched", empty)
    return empty
  end

  local miktex_binary = detect_miktex_binary(context)
  if miktex_binary == nil then
    emit_event(context, "unavailable", { reason = "miktex-not-installed" })
    return {}
  end

  local flags = request_flags(context)
  local items, err = load_catalog(context, flags, miktex_binary)
  if items == nil then
    emit_event(context, "unavailable", { reason = err })
    return {}
  end

  local results = search_catalog(items, prompt)
  emit_event(context, "searched", results)
  return results
end

function plugin.info(context, name)
  local query = trim(name)
  if query == "" then
    emit_event(context, "unavailable", { reason = "missing-package-name" })
    return {}
  end

  local miktex_binary = detect_miktex_binary(context)
  if miktex_binary == nil then
    emit_event(context, "unavailable", { reason = "miktex-not-installed" })
    return {}
  end

  local flags = request_flags(context)
  local item, err = direct_info(context, flags, miktex_binary, query)
  if item == nil then
    local items = load_catalog(context, flags, miktex_binary)
    if type(items) == "table" then
      item = exact_match(items, query)
    end
  end

  if item == nil then
    emit_event(context, "unavailable", {
      name = query,
      reason = err or "package not found",
    })
    return {}
  end

  emit_event(context, "informed", item)
  return item
end

function plugin.resolvePackage(context, package)
  local miktex_binary = detect_miktex_binary(context)
  if miktex_binary == nil then
    return nil
  end
  local flags = request_flags(context, package)
  return resolve_requested_package(context, package, {
    flags = flags,
    miktex_binary = miktex_binary,
  })
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "exec", "network" },
    ecosystemScopes = { "tex", "miktex" },
    writeScopes = {
      { kind = "temp" },
      { kind = "user-home-subpath", value = ".miktex" },
      { kind = "user-home-subpath", value = ".cache/reqpack/miktex" },
      { kind = "user-home-subpath", value = ".cache/miktex" },
      { kind = "user-home-subpath", value = ".local/share/miktex" },
    },
    networkScopes = {},
    privilegeLevel = "user",
  }
end

function plugin.init()
  return true
end

function plugin.shutdown()
  return true
end

return plugin
