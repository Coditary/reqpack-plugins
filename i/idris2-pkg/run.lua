plugin = {}

local PLUGIN_ID = "idris2-pkg"
local PLUGIN_NAME = "Idris2 Pack"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "pack"

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

local function parent_dir(path)
  return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
end

local function basename(path)
  local cleaned = trim(path):gsub("[/\\]+$", "")
  return cleaned:match("[^/\\]+$") or cleaned
end

local function first_nonempty(...)
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    if value ~= nil then
      local text = trim(value)
      if text ~= "" then
        return text
      end
    end
  end
  return nil
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

local function sequence_to_array(value)
  local items = {}
  if value == nil then
    return items
  end
  if type(value) == "table" then
    for _, item in ipairs(value) do
      items[#items + 1] = item
    end
    return items
  end

  local index = 1
  while true do
    local item = read_field(value, index)
    if item == nil then
      break
    end
    items[#items + 1] = item
    index = index + 1
  end
  return items
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

local function env_value(name)
  if os ~= nil and type(os.getenv) == "function" then
    return os.getenv(name)
  end
  return nil
end

local function home_dir()
  return first_nonempty(env_value("HOME"), env_value("USERPROFILE"), "/home/test")
end

local function cache_root()
  return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
end

local function managed_home()
  return join_path(cache_root(), "home")
end

local function xdg_config_home()
  return join_path(managed_home(), ".config")
end

local function xdg_cache_home()
  return join_path(managed_home(), ".cache")
end

local function xdg_state_home()
  return join_path(managed_home(), ".local", "state")
end

local function xdg_data_home()
  return join_path(managed_home(), ".local", "share")
end

local function pack_user_dir()
  return join_path(xdg_config_home(), "pack")
end

local function pack_cache_dir()
  return join_path(xdg_cache_home(), "pack")
end

local function pack_state_dir()
  return join_path(xdg_state_home(), "pack")
end

local function pack_bin_dir()
  return join_path(managed_home(), "bin")
end

local function manifest_path()
  return join_path(cache_root(), "installed.tsv")
end

local function ensure_directory(path)
  local cleaned = trim(path)
  if cleaned == "" then
    return
  end
  if os ~= nil and type(os.execute) == "function" then
    os.execute("mkdir -p " .. shell_quote(cleaned) .. " >/dev/null 2>&1")
  end
end

local function ensure_runtime_dirs()
  ensure_directory(cache_root())
  ensure_directory(managed_home())
  ensure_directory(xdg_config_home())
  ensure_directory(xdg_cache_home())
  ensure_directory(xdg_state_home())
  ensure_directory(xdg_data_home())
  ensure_directory(pack_user_dir())
  ensure_directory(pack_cache_dir())
  ensure_directory(pack_state_dir())
  ensure_directory(pack_bin_dir())
end

local function command_env_prefix()
  return table.concat({
    "HOME=" .. shell_quote(managed_home()),
    "XDG_CONFIG_HOME=" .. shell_quote(xdg_config_home()),
    "XDG_CACHE_HOME=" .. shell_quote(xdg_cache_home()),
    "XDG_STATE_HOME=" .. shell_quote(xdg_state_home()),
    "XDG_DATA_HOME=" .. shell_quote(xdg_data_home()),
    "PACK_USER_DIR=" .. shell_quote(pack_user_dir()),
    "PACK_CACHE_DIR=" .. shell_quote(pack_cache_dir()),
    "PACK_STATE_DIR=" .. shell_quote(pack_state_dir()),
    "PACK_BIN_DIR=" .. shell_quote(pack_bin_dir()),
    "NO_COLOR=" .. shell_quote("1"),
    "LC_ALL=" .. shell_quote("C"),
    "LANG=" .. shell_quote("C"),
    "LANGUAGE=" .. shell_quote("C"),
    "SHELL=" .. shell_quote("/bin/sh"),
  }, " ")
end

local function build_command(arguments)
  local parts = { command_env_prefix(), REQUIRED_BINARY }
  for _, item in ipairs(arguments or {}) do
    parts[#parts + 1] = item
  end
  return table.concat(parts, " ")
end

local function command_exists(binary)
  return is_command_success(exec_run(nil, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function ensure_binary(context)
  if command_exists(REQUIRED_BINARY) then
    return true
  end
  return false, REQUIRED_BINARY .. " binary not available"
end

local function package_error(context, message)
  tx_failed(context, message)
  return false
end

local function request_packages(context, packages)
  local direct = sequence_to_array(packages)
  if #direct > 0 then
    return direct
  end
  local request = read_field(context, "request")
  return sequence_to_array(read_field(request, "packages"))
end

local function request_prompt(context, prompt)
  return trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
end

local function request_path(context, path)
  return trim(path or read_field(read_field(context, "request"), "localPath") or read_field(read_field(context, "request"), "path") or "")
end

local function package_name(pkg)
  return trim(read_field(pkg, "name") or read_field(pkg, "package") or read_field(pkg, "id") or "")
end

local function package_version(pkg)
  return trim(read_field(pkg, "version") or "")
end

local function sort_items(items)
  table.sort(items, function(left, right)
    return lower(left.name or "") < lower(right.name or "")
  end)
end

local function split_tsv(line)
  local fields = {}
  local text = tostring(line or "") .. "\t"
  for field in text:gmatch("(.-)\t") do
    fields[#fields + 1] = field
  end
  return fields
end

local function read_file(path)
  local handle = io.open(path, "r")
  if handle == nil then
    return nil
  end
  local content = handle:read("*a")
  handle:close()
  return content
end

local function parse_manifest(context)
  local entries = {}
  local content = read_file(manifest_path())
  if content == nil then
    local result = exec_run(context, "cat " .. shell_quote(manifest_path()))
    if is_command_success(result) then
      content = result.stdout
    end
  end
  if content == nil then
    return entries
  end
  for _, line in ipairs(split_lines(content)) do
    if trim(line) ~= "" then
      local fields = split_tsv(line)
      entries[#entries + 1] = {
        name = trim(fields[1]),
        requestedVersion = trim(fields[2]),
        installedVersion = trim(fields[3]),
        packageId = trim(fields[4]),
        source = trim(fields[5]),
        summary = trim(fields[6]),
        localTarget = trim(fields[7]) == "true",
      }
    end
  end
  return entries
end

local function write_manifest(context, entries)
  local lines = {}
  sort_items(entries)
  for _, entry in ipairs(entries) do
    lines[#lines + 1] = table.concat({
      trim(entry.name),
      trim(entry.requestedVersion),
      trim(entry.installedVersion),
      trim(entry.packageId),
      trim(entry.source),
      trim(entry.summary),
      entry.localTarget and "true" or "false",
    }, "\t")
  end
  local content = table.concat(lines, "\n")
  if content ~= "" then
    content = content .. "\n"
  end
  local directory = parent_dir(manifest_path()) or cache_root()
  local command = "mkdir -p " .. shell_quote(directory) .. " && printf %s " .. shell_quote(content) .. " > " .. shell_quote(manifest_path())
  local result = exec_run(context, command)
  return is_command_success(result)
end

local function find_manifest_entry(entries, name)
  for _, entry in ipairs(entries or {}) do
    if lower(entry.name) == lower(name) then
      return entry
    end
  end
  return nil
end

local function upsert_manifest_entry(entries, candidate)
  for index, entry in ipairs(entries) do
    if lower(entry.name) == lower(candidate.name) then
      entries[index] = candidate
      return
    end
  end
  entries[#entries + 1] = candidate
end

local function remove_manifest_entries(entries, names)
  local keep = {}
  for _, entry in ipairs(entries or {}) do
    local remove = false
    for _, name in ipairs(names or {}) do
      if lower(entry.name) == lower(name) then
        remove = true
        break
      end
    end
    if not remove then
      keep[#keep + 1] = entry
    end
  end
  return keep
end

local function manifest_item(entry)
  if entry == nil then
    return {}
  end
  return {
    name = entry.name,
    packageId = first_nonempty(entry.packageId, entry.name),
    version = first_nonempty(entry.installedVersion, entry.requestedVersion),
    requestedVersion = first_nonempty(entry.requestedVersion, nil),
    installedVersion = first_nonempty(entry.installedVersion, nil),
    source = first_nonempty(entry.source, nil),
    summary = first_nonempty(entry.summary, nil),
    description = first_nonempty(entry.summary, nil),
    installed = true,
    status = "installed",
    packageType = entry.localTarget and "local-project" or "library",
  }
end

local function parse_search_output(output)
  local items = {}
  local current = nil
  for _, line in ipairs(split_lines(output)) do
    if trim(line) ~= "" then
      if line:match("^%S") then
        current = {
          name = trim(line),
          packageId = trim(line),
          installed = false,
          status = "available",
          packageType = "library",
        }
        items[#items + 1] = current
      elseif current ~= nil then
        local text = trim(line)
        if current.summary == nil then
          current.summary = text
          current.description = text
        else
          current.description = current.description .. "\n" .. text
        end
      end
    end
  end
  sort_items(items)
  return items
end

local function parse_detail_groups(output)
  local groups = {}
  local current = nil
  for _, line in ipairs(split_lines(output)) do
    if trim(line) ~= "" then
      if line:match("^%S") then
        current = {
          name = trim(line),
          lines = {},
        }
        groups[#groups + 1] = current
      elseif current ~= nil then
        current.lines[#current.lines + 1] = trim(line)
      end
    end
  end
  return groups
end

local function parse_info_output(name, output)
  local groups = parse_detail_groups(output)
  local selected = nil
  for _, group in ipairs(groups) do
    if lower(group.name) == lower(name) then
      selected = group
      break
    end
  end
  if selected == nil and #groups == 1 then
    selected = groups[1]
  end
  if selected == nil then
    return {}
  end

  local item = {
    name = selected.name,
    packageId = selected.name,
    installed = false,
    status = "available",
    packageType = "library",
    extraFields = {},
  }
  local dependency_lines = nil

  for _, line in ipairs(selected.lines) do
    local key, value = line:match("^([^:]+):%s*(.*)$")
    if key ~= nil then
      dependency_lines = nil
      key = lower(trim(key))
      value = trim(value)
      if key == "brief" then
        item.summary = value
        item.description = value
      elseif key == "type" then
        item.extraFields.type = value
      elseif key == "url" then
        item.homepage = value
        item.source = value
      elseif key == "commit" then
        item.extraFields.commit = value
      elseif key == "ipkg file" then
        item.extraFields.ipkgFile = value
      elseif key == "library" then
        if value:find("installed", 1, true) ~= nil then
          item.installed = true
          item.status = "installed"
        end
      elseif key == "executable" then
        item.extraFields.executable = value
      elseif key == "app" then
        item.extraFields.app = value
        if value:find("installed", 1, true) ~= nil then
          item.installed = true
          item.status = "installed"
        end
      elseif key == "dependencies" then
        dependency_lines = {}
        if value ~= "" then
          dependency_lines[#dependency_lines + 1] = value
        end
        item.dependencies = dependency_lines
      else
        item.extraFields[key] = value
      end
    elseif dependency_lines ~= nil then
      dependency_lines[#dependency_lines + 1] = trim(line)
    end
  end

  if next(item.extraFields) == nil then
    item.extraFields = nil
  end
  return item
end

local function merge_info(manifest_entry, remote_item)
  local item = type(remote_item) == "table" and shallow_copy(remote_item) or {}
  if manifest_entry ~= nil then
    local cached = manifest_item(manifest_entry)
    for key, value in pairs(cached) do
      if item[key] == nil or item[key] == "" then
        item[key] = value
      end
    end
    item.installed = true
    item.status = "installed"
  end
  return item
end

local function info_query_command(name)
  return build_command({ "--long-desc", "query", shell_quote(name) })
end

local function search_query_command(prompt)
  return build_command({ "--short-desc", "query", shell_quote(prompt) })
end

local function install_command(names)
  local arguments = { "install" }
  for _, name in ipairs(names or {}) do
    arguments[#arguments + 1] = shell_quote(name)
  end
  return build_command(arguments)
end

local function remove_command(names)
  local arguments = { "remove" }
  for _, name in ipairs(names or {}) do
    arguments[#arguments + 1] = shell_quote(name)
  end
  return build_command(arguments)
end

local function install_local_command(path)
  return build_command({ "install-deps", shell_quote(path) })
end

local function update_db_command()
  return build_command({ "update-db" })
end

local function update_command()
  return build_command({ "update" })
end

local function lookup_info(context, name, warn_on_failure)
  local result = exec_run(context, info_query_command(name))
  if not is_command_success(result) then
    if warn_on_failure then
      log_warn(context, first_nonempty(result.stderr, result.stdout, "pack query failed") or "pack query failed")
    end
    return nil
  end
  local item = parse_info_output(name, result.stdout)
  if next(item) == nil then
    return nil
  end
  return item
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
  return { "package-manager", "idris", "idris2-pack" }
end

function plugin.getMissingPackages(packages)
  if not command_exists(REQUIRED_BINARY) then
    return { REQUIRED_BINARY }
  end
  if type(packages) ~= "table" then
    return {}
  end

  local entries = parse_manifest(nil)
  local missing = {}
  for _, pkg in ipairs(packages) do
    local name = package_name(pkg)
    local action = lower(read_field(pkg, "action") or "")
    local installed = find_manifest_entry(entries, name) ~= nil
    if name ~= "" then
      if action == "remove" then
        if installed then
          missing[#missing + 1] = pkg
        end
      elseif action == "update" then
        missing[#missing + 1] = pkg
      elseif not installed then
        missing[#missing + 1] = pkg
      end
    end
  end
  return missing
end

function plugin.install(context, packages)
  local local_path = request_path(context, nil)
  if local_path ~= "" then
    return plugin.installLocal(context, local_path)
  end

  local requested = request_packages(context, packages)
  if #requested == 0 then
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
  end

  local available, message = ensure_binary(context)
  if not available then
    return package_error(context, message)
  end

  ensure_runtime_dirs()

  local names = {}
  for _, pkg in ipairs(requested) do
    local name = package_name(pkg)
    if name == "" then
      return package_error(context, "idris2-pkg package name missing")
    end
    names[#names + 1] = name
  end

  begin_step(context, "install idris2 packages")
  local result = exec_run(context, install_command(names))
  if not is_command_success(result) then
    return package_error(context, first_nonempty(result.stderr, result.stdout, "pack install failed") or "pack install failed")
  end

  local entries = parse_manifest(context)
  local installed = {}
  for index, pkg in ipairs(requested) do
    local name = names[index]
    local info = lookup_info(context, name, false)
    local entry = {
      name = name,
      requestedVersion = package_version(pkg),
      installedVersion = first_nonempty(info and info.version, package_version(pkg), ""),
      packageId = name,
      source = first_nonempty(info and info.source, info and info.homepage, ""),
      summary = first_nonempty(info and info.summary, ""),
      localTarget = false,
    }
    upsert_manifest_entry(entries, entry)
    installed[#installed + 1] = merge_info(entry, info)
  end

  if not write_manifest(context, entries) then
    return package_error(context, "idris2-pkg manifest write failed")
  end

  emit_event(context, "installed", installed)
  tx_success(context)
  emit_event(context, "success", "ok")
  return true
end

function plugin.installLocal(context, path)
  local local_path = request_path(context, path)
  if local_path == "" then
    return package_error(context, "missing local Idris2 project path")
  end
  if not local_path:lower():match("%.ipkg$") then
    return package_error(context, "idris2-pkg local install supports only .ipkg files")
  end

  local available, message = ensure_binary(context)
  if not available then
    return package_error(context, message)
  end

  ensure_runtime_dirs()

  begin_step(context, "install local idris2 project dependencies")
  local result = exec_run(context, install_local_command(local_path))
  if not is_command_success(result) then
    return package_error(context, first_nonempty(result.stderr, result.stdout, "pack install-deps failed") or "pack install-deps failed")
  end

  local requested = request_packages(context, nil)
  local explicit_name = package_name(requested[1])
  local entry = {
    name = first_nonempty(explicit_name, basename(local_path):gsub("%.ipkg$", ""), local_path),
    requestedVersion = package_version(requested[1]),
    installedVersion = package_version(requested[1]),
    packageId = local_path,
    source = local_path,
    summary = "Local Idris2 project dependencies installed via pack",
    localTarget = true,
  }
  local entries = parse_manifest(context)
  upsert_manifest_entry(entries, entry)
  if not write_manifest(context, entries) then
    return package_error(context, "idris2-pkg manifest write failed")
  end

  emit_event(context, "installed", {
    name = entry.name,
    path = local_path,
    localTarget = true,
  })
  tx_success(context)
  emit_event(context, "success", "ok")
  return true
end

function plugin.remove(context, packages)
  local requested = request_packages(context, packages)
  if #requested == 0 then
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
  end

  local available, message = ensure_binary(context)
  if not available then
    return package_error(context, message)
  end

  ensure_runtime_dirs()

  local names = {}
  for _, pkg in ipairs(requested) do
    local name = package_name(pkg)
    if name == "" then
      return package_error(context, "idris2-pkg package name missing")
    end
    names[#names + 1] = name
  end

  begin_step(context, "remove idris2 packages")
  local result = exec_run(context, remove_command(names))
  if not is_command_success(result) then
    return package_error(context, first_nonempty(result.stderr, result.stdout, "pack remove failed") or "pack remove failed")
  end

  local entries = remove_manifest_entries(parse_manifest(context), names)
  if not write_manifest(context, entries) then
    return package_error(context, "idris2-pkg manifest write failed")
  end

  emit_event(context, "deleted", requested)
  tx_success(context)
  emit_event(context, "success", "ok")
  return true
end

function plugin.update(context, packages)
  local requested = request_packages(context, packages)
  local available, message = ensure_binary(context)
  if not available then
    return package_error(context, message)
  end

  ensure_runtime_dirs()

  begin_step(context, "update idris2 pack state")
  local refresh = exec_run(context, update_db_command())
  if not is_command_success(refresh) then
    return package_error(context, first_nonempty(refresh.stderr, refresh.stdout, "pack update-db failed") or "pack update-db failed")
  end
  local result = exec_run(context, update_command())
  if not is_command_success(result) then
    return package_error(context, first_nonempty(result.stderr, result.stdout, "pack update failed") or "pack update failed")
  end

  emit_event(context, "updated", requested)
  tx_success(context)
  emit_event(context, "success", "ok")
  return true
end

function plugin.list(context)
  local items = {}
  for _, entry in ipairs(parse_manifest(context)) do
    items[#items + 1] = manifest_item(entry)
  end
  sort_items(items)
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  local empty = {}
  emit_event(context, "outdated", empty)
  return empty
end

function plugin.search(context, prompt)
  local cleaned = request_prompt(context, prompt)
  if cleaned == "" then
    local empty = {}
    emit_event(context, "searched", empty)
    return empty
  end

  local available, message = ensure_binary(context)
  if not available then
    log_warn(context, message)
    local empty = {}
    emit_event(context, "searched", empty)
    return empty
  end

  ensure_runtime_dirs()

  local result = exec_run(context, search_query_command(cleaned))
  if not is_command_success(result) then
    log_warn(context, first_nonempty(result.stderr, result.stdout, "pack query failed") or "pack query failed")
    local empty = {}
    emit_event(context, "searched", empty)
    return empty
  end

  local items = parse_search_output(result.stdout)
  emit_event(context, "searched", items)
  return items
end

function plugin.info(context, name)
  local cleaned = request_prompt(context, name)
  if cleaned == "" then
    local empty = {}
    emit_event(context, "informed", empty)
    return empty
  end

  local manifest_entry = find_manifest_entry(parse_manifest(context), cleaned)
  local available, message = ensure_binary(context)
  if not available then
    if manifest_entry ~= nil then
      local cached = manifest_item(manifest_entry)
      emit_event(context, "informed", cached)
      return cached
    end
    log_warn(context, message)
    local empty = {}
    emit_event(context, "informed", empty)
    return empty
  end

  ensure_runtime_dirs()

  local remote = lookup_info(context, cleaned, true)
  if remote == nil and manifest_entry == nil then
    local empty = {}
    emit_event(context, "informed", empty)
    return empty
  end

  local item = merge_info(manifest_entry, remote)
  emit_event(context, "informed", item)
  return item
end

function plugin.resolvePackage(context, package)
  local name = package_name(package)
  if name == "" then
    return nil, "idris2-pkg package name missing"
  end
  local item = plugin.info(context, name)
  if type(item) == "table" and next(item) ~= nil then
    return item
  end
  return {
    name = name,
    packageId = name,
    version = first_nonempty(package_version(package), nil),
    packageType = "library",
  }
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "exec", "network" },
    ecosystemScopes = { "idris", "idris2", "idris2-pack" },
    writeScopes = {
      { kind = "user-home-subpath", value = ".cache/reqpack/idris2-pkg" },
    },
    networkScopes = { "*" },
    privilegeLevel = "user",
    purlType = "generic",
  }
end

function plugin.init()
  return command_exists(REQUIRED_BINARY)
end

function plugin.shutdown()
  return true
end

return plugin
