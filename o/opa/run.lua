plugin = {}

local PLUGIN_ID = "opa"
local PLUGIN_NAME = "Opa"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "opa"
local COMMAND_ENV_PREFIX = "LC_ALL=C LANG=C LANGUAGE=C"
local DEFAULT_HOME_DATA_ROOT = '"$HOME/.local/share/reqpack/opa"'
local INVENTORY_FILE_NAME = "inventory.tsv"

local function trim(value)
  return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
  return trim(value):lower()
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

local function basename(path)
  local cleaned = trim(path):gsub("[/\\]+$", "")
  if cleaned == "" then
    return ""
  end
  return cleaned:match("[^/\\]+$") or cleaned
end

local function dirname(path)
  local cleaned = trim(path):gsub("[/\\]+$", "")
  if cleaned == "" then
    return "."
  end
  local parent = cleaned:match("^(.*)[/\\][^/\\]+$")
  if parent == nil or parent == "" then
    return "."
  end
  return parent
end

local function strip_extension(name)
  local cleaned = trim(name)
  return (cleaned:gsub("(%.[^./\\]+)$", ""))
end

local function ends_with(value, suffix)
  local text = tostring(value or "")
  return suffix ~= "" and text:sub(-#suffix) == suffix
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

local function expand_runtime_placeholders(value)
  local text = tostring(value or "")
  local root = ""
  if os ~= nil and type(os.getenv) == "function" then
    root = trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
  end
  if root ~= "" then
    text = text:gsub("%${fixtureRoot}", root)
  end
  return text
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

local function command_exists(context, binary)
  local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
  return result ~= nil and result.success == true
end

local function file_exists(context, path)
  local result = exec_run(context, "test -e " .. shell_quote(path))
  return result ~= nil and result.success == true
end

local function read_file(context, path)
  local result = exec_run(context, "cat " .. shell_quote(path))
  if result ~= nil and result.success == true then
    return result.stdout
  end
  return nil
end

local function ensure_dir(context, path)
  local result = exec_run(context, "mkdir -p " .. shell_quote(path))
  return result ~= nil and result.success == true
end

local function write_file(context, path, content)
  local dir = dirname(path)
  if dir ~= "." and not ensure_dir(context, dir) then
    return false
  end
  local result = exec_run(context, "printf %s " .. shell_quote(content) .. " > " .. shell_quote(path))
  return result ~= nil and result.success == true
end

local function request_object(context)
  return read_field(context, "request")
end

local function request_flags(context)
  local combined = {}
  local function collect(source)
    local flags = read_field(source, "flags")
    for _, flag in ipairs(sequence_values(flags)) do
      local cleaned = trim(flag)
      if cleaned ~= "" then
        combined[#combined + 1] = cleaned
      end
    end
  end
  collect(context)
  collect(request_object(context))
  return combined
end

local function request_prompt(context, fallback)
  return non_empty(fallback) or non_empty(read_field(request_object(context), "prompt")) or non_empty(read_field(context, "prompt")) or ""
end

local function request_local_path(context, fallback)
  return non_empty(fallback)
    or non_empty(read_field(request_object(context), "localPath"))
    or non_empty(read_field(request_object(context), "path"))
    or non_empty(read_field(context, "localPath"))
    or non_empty(read_field(context, "path"))
end

local function request_packages(context, fallback)
  local items = sequence_values(read_field(request_object(context), "packages"))
  if #items > 0 then
    return items
  end
  items = sequence_values(read_field(context, "packages"))
  if #items > 0 then
    return items
  end
  return fallback or {}
end

local function path_flag_value(flags, key)
  local prefix = lower(key) .. "="
  for _, flag in ipairs(flags or {}) do
    local cleaned = trim(flag)
    if lower(cleaned):sub(1, #prefix) == prefix then
      return trim(cleaned:sub(#prefix + 1))
    end
  end
  return nil
end

local function has_flag(flags, wanted)
  local needle = lower(wanted)
  for _, flag in ipairs(flags or {}) do
    if lower(flag) == needle then
      return true
    end
  end
  return false
end

local function inventory_root(flags)
  local configured = path_flag_value(flags, "data-root")
  if configured ~= nil and configured ~= "" then
    return join_path(configured, PLUGIN_ID)
  end
  return DEFAULT_HOME_DATA_ROOT
end

local function inventory_path(flags)
  return join_path(inventory_root(flags), INVENTORY_FILE_NAME)
end

local function package_target(raw_pkg)
  if type(raw_pkg) == "string" then
    return non_empty(raw_pkg)
  end
  return non_empty(read_field(raw_pkg, "path"))
    or non_empty(read_field(raw_pkg, "sourcePath"))
    or non_empty(read_field(raw_pkg, "target"))
    or non_empty(read_field(raw_pkg, "localPath"))
    or non_empty(read_field(raw_pkg, "name"))
    or non_empty(read_field(raw_pkg, "packageId"))
end

local function infer_input_kind(path)
  if ends_with(path, ".opa") then
    return "source"
  end
  if ends_with(path, ".opack") then
    return "opack"
  end
  if ends_with(path, ".conf") then
    return "conf"
  end
  if ends_with(path, ".opx") then
    return "opx"
  end
  return "directory"
end

local function list_candidates_in_dir(context, dir)
  local result = exec_run(context, "ls -1 " .. shell_quote(dir))
  if result == nil or result.success ~= true then
    return {}
  end
  return split_lines(result.stdout)
end

local function resolve_directory_target(context, dir)
  local names = list_candidates_in_dir(context, dir)
  local opacks = {}
  local confs = {}
  local opas = {}
  local basename_only = basename(dir)

  for _, entry in ipairs(names) do
    local cleaned = trim(entry)
    if ends_with(cleaned, ".opack") then
      opacks[#opacks + 1] = cleaned
    elseif ends_with(cleaned, ".conf") then
      confs[#confs + 1] = cleaned
    elseif ends_with(cleaned, ".opa") then
      opas[#opas + 1] = cleaned
    end
  end

  local function resolve_one(items)
    if #items == 1 then
      return join_path(dir, items[1])
    end
    for _, item in ipairs(items) do
      if strip_extension(item) == basename_only then
        return join_path(dir, item)
      end
    end
    return nil
  end

  local selected = resolve_one(opacks) or resolve_one(confs) or resolve_one(opas)
  if selected ~= nil then
    return selected
  end

  local candidates = {}
  for _, item in ipairs(opacks) do
    candidates[#candidates + 1] = join_path(dir, item)
  end
  for _, item in ipairs(confs) do
    candidates[#candidates + 1] = join_path(dir, item)
  end
  for _, item in ipairs(opas) do
    candidates[#candidates + 1] = join_path(dir, item)
  end
  if #candidates == 0 then
    return nil, "no supported Opa target in directory " .. dir
  end
  return nil, "ambiguous Opa directory target: " .. table.concat(candidates, ", ")
end

local function resolve_target(context, raw_target)
  local cleaned = trim(expand_runtime_placeholders(raw_target))
  if cleaned == "" then
    return nil, "missing Opa target"
  end
  if ends_with(cleaned, ".opa") or ends_with(cleaned, ".opack") or ends_with(cleaned, ".conf") or ends_with(cleaned, ".opx") then
    return cleaned
  end
  local resolved, err = resolve_directory_target(context, cleaned)
  if resolved ~= nil then
    return resolved
  end
  if file_exists(context, cleaned) then
    return cleaned
  end
  return nil, err
end

local function build_mode(flags, target)
  if has_flag(flags, "compile") then
    return "compile"
  end
  if has_flag(flags, "link") then
    return "link"
  end
  if has_flag(flags, "autocompile") then
    return "autocompile"
  end
  if ends_with(target, ".opx") then
    return "link"
  end
  return "build"
end

local function build_command(flags, target)
  local mode = build_mode(flags, target)
  local args = { COMMAND_ENV_PREFIX, REQUIRED_BINARY }
  if mode == "compile" then
    args[#args + 1] = "-c"
  elseif mode == "link" then
    args[#args + 1] = "-l"
  elseif mode == "autocompile" then
    args[#args + 1] = "--autocompile"
  end
  if has_flag(flags, "api") then
    args[#args + 1] = "--api"
  end
  for _, flag in ipairs(flags or {}) do
    local warn_value = flag:match("^warn%-error=(.+)$")
    if warn_value ~= nil and trim(warn_value) ~= "" then
      args[#args + 1] = "--warn-error"
      args[#args + 1] = shell_quote(trim(warn_value))
    end
  end
  args[#args + 1] = shell_quote(target)
  return table.concat(args, " "), mode
end

local function candidate_outputs(target, flags)
  local outputs = {}
  local dir = dirname(target)
  local base = strip_extension(basename(target))
  local full_base = join_path(dir, base)

  outputs[#outputs + 1] = full_base .. ".opx"
  outputs[#outputs + 1] = join_path(dir, "_build")
  outputs[#outputs + 1] = full_base .. ".exe"
  outputs[#outputs + 1] = full_base
  if has_flag(flags, "api") then
    outputs[#outputs + 1] = full_base .. ".api"
    outputs[#outputs + 1] = full_base .. ".api-txt"
  end
  return outputs
end

local function existing_outputs(context, target, flags)
  local items = {}
  local seen = {}
  for _, output in ipairs(candidate_outputs(target, flags)) do
    if not seen[output] and file_exists(context, output) then
      seen[output] = true
      items[#items + 1] = output
    end
  end
  return items
end

local function read_inventory(context, flags)
  local path = inventory_path(flags)
  local content = read_file(context, path)
  if content == nil then
    return {}
  end
  local items = {}
  for _, line in ipairs(split_lines(content)) do
    local cleaned = trim(line)
    if cleaned ~= "" then
      local fields = {}
      for field in (cleaned .. "\t"):gmatch("(.-)\t") do
        fields[#fields + 1] = field
      end
      if #fields >= 5 then
        items[#items + 1] = {
          packageId = fields[1],
          name = fields[2],
          sourcePath = fields[3],
          inputKind = fields[4],
          buildMode = fields[5],
          outputs = fields[6] or "",
        }
      end
    end
  end
  return items
end

local function write_inventory(context, flags, items)
  local lines = {}
  for _, item in ipairs(items or {}) do
    lines[#lines + 1] = table.concat({
      trim(item.packageId or ""),
      trim(item.name or ""),
      trim(item.sourcePath or ""),
      trim(item.inputKind or ""),
      trim(item.buildMode or ""),
      trim(item.outputs or ""),
    }, "\t")
  end
  return write_file(context, inventory_path(flags), table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
end

local function build_package_id(path)
  local cleaned = trim(path)
  return PLUGIN_ID .. "/" .. cleaned
end

local function compiler_version(context)
  local result = exec_run(context, COMMAND_ENV_PREFIX .. " " .. REQUIRED_BINARY .. " --version")
  if result ~= nil and result.success == true then
    local first_line = split_lines(result.stdout)[1]
    return non_empty(first_line)
  end
  return nil
end

local function normalize_item(source_path, mode, outputs, version)
  local path = trim(source_path)
  local name = strip_extension(basename(path))
  local install_path = outputs[1]
  local item = {
    name = name,
    packageId = build_package_id(path),
    packageType = "opa",
    installed = #outputs > 0,
    status = #outputs > 0 and "installed" or "available",
    summary = "Local Opa target " .. name,
    description = "Local Opa target built through opa",
    installPath = install_path,
    extraFields = {
      sourcePath = path,
      inputKind = infer_input_kind(path),
      buildMode = mode,
      outputs = outputs,
      compilerVersion = version,
    },
  }
  return item
end

local function sort_items(items)
  table.sort(items, function(left, right)
    return trim(left.packageId or left.name or "") < trim(right.packageId or right.name or "")
  end)
  return items
end

local function refresh_inventory_entry(entries, item)
  local replaced = false
  for index, entry in ipairs(entries) do
    if trim(entry.packageId) == trim(item.packageId) then
      entries[index] = item
      replaced = true
      break
    end
  end
  if not replaced then
    entries[#entries + 1] = item
  end
end

local function remove_inventory_entry(entries, package_id)
  local kept = {}
  for _, entry in ipairs(entries or {}) do
    if trim(entry.packageId) ~= trim(package_id) then
      kept[#kept + 1] = entry
    end
  end
  return kept
end

local function inventory_item_from_normalized(item)
  return {
    packageId = item.packageId,
    name = item.name,
    sourcePath = item.extraFields.sourcePath,
    inputKind = item.extraFields.inputKind,
    buildMode = item.extraFields.buildMode,
    outputs = table.concat(item.extraFields.outputs or {}, "|"),
  }
end

local function remove_output(context, path)
  return exec_run(context, "rm -rf " .. shell_quote(path))
end

local function known_outputs_from_entry(entry)
  local outputs = {}
  for value in tostring(entry.outputs or ""):gmatch("[^|]+") do
    outputs[#outputs + 1] = value
  end
  return outputs
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
  return { "language", "package-manager", "opa" }
end

function plugin.init()
  return command_exists(nil, REQUIRED_BINARY)
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "build", "local-install", "query" },
    ecosystemScopes = { "opa" },
    writeScopes = {
      { path = "local-target-outputs", kind = "filesystem" },
      { path = "plugin-cache", kind = "filesystem" },
    },
    networkScopes = {},
    privilegeLevel = "none",
    purlType = "generic",
  }
end

function plugin.getMissingPackages(packages)
  if command_exists(nil, REQUIRED_BINARY) then
    return {}
  end
  return packages or { { name = REQUIRED_BINARY } }
end

function plugin.install(context, packages)
  local requested = request_packages(context, packages)
  if #requested == 0 then
    return true
  end
  if not command_exists(context, REQUIRED_BINARY) then
    tx_failed(context, "opa binary not available")
    return false
  end
  local flags = request_flags(context)
  local compiler = compiler_version(context)
  local inventory = read_inventory(context, flags)
  local installed_items = {}

  for _, raw_pkg in ipairs(requested) do
    local raw_target = package_target(raw_pkg)
    local target, err = resolve_target(context, raw_target)
    if target == nil then
      tx_failed(context, err)
      return false
    end
    local command, mode = build_command(flags, target)
    begin_step(context, "build Opa target " .. basename(target))
    local result = exec_run(context, command)
    if result == nil or result.success ~= true then
      tx_failed(context, trim(result and result.stderr) ~= "" and trim(result.stderr) or "opa build failed")
      return false
    end
    local outputs = existing_outputs(context, target, flags)
    local item = normalize_item(target, mode, outputs, compiler)
    installed_items[#installed_items + 1] = item
    refresh_inventory_entry(inventory, inventory_item_from_normalized(item))
  end

  write_inventory(context, flags, inventory)
  emit_event(context, "installed", installed_items)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  local local_path = request_local_path(context, path)
  if local_path == nil then
    tx_failed(context, "missing local Opa path")
    return false
  end
  return plugin.install(context, { { path = local_path } })
end

function plugin.remove(context, packages)
  local requested = request_packages(context, packages)
  if #requested == 0 then
    return true
  end
  local flags = request_flags(context)
  local inventory = read_inventory(context, flags)
  local deleted = {}

  for _, raw_pkg in ipairs(requested) do
    local raw_target = package_target(raw_pkg)
    local target, err = resolve_target(context, raw_target)
    if target == nil then
      tx_failed(context, err)
      return false
    end
    local package_id = build_package_id(target)
    local outputs = existing_outputs(context, target, flags)
    if #outputs == 0 then
      for _, entry in ipairs(inventory) do
        if trim(entry.packageId) == package_id then
          outputs = known_outputs_from_entry(entry)
          break
        end
      end
    end
    begin_step(context, "remove Opa outputs for " .. basename(target))
    for _, output in ipairs(outputs) do
      local result = remove_output(context, output)
      if result == nil or result.success ~= true then
        tx_failed(context, "failed to remove Opa output")
        return false
      end
    end
    inventory = remove_inventory_entry(inventory, package_id)
    deleted[#deleted + 1] = normalize_item(target, build_mode(flags, target), {}, nil)
  end

  write_inventory(context, flags, inventory)
  emit_event(context, "deleted", deleted)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  local requested = request_packages(context, packages)
  local flags = request_flags(context)
  if #requested == 0 then
    local inventory = read_inventory(context, flags)
    for _, entry in ipairs(inventory) do
      requested[#requested + 1] = { path = entry.sourcePath }
    end
    if #requested == 0 then
      emit_event(context, "updated", {})
      tx_success(context)
      return true
    end
  end
  local ok = plugin.install(context, requested)
  if not ok then
    return false
  end
  local updated = {}
  for _, raw_pkg in ipairs(requested) do
    local target = package_target(raw_pkg)
    if target ~= nil then
      local resolved = resolve_target(context, target)
      if resolved ~= nil then
        updated[#updated + 1] = normalize_item(resolved, build_mode(flags, resolved), existing_outputs(context, resolved, flags), compiler_version(context))
      end
    end
  end
  emit_event(context, "updated", updated)
  tx_success(context)
  return true
end

function plugin.list(context)
  local flags = request_flags(context)
  local compiler = command_exists(context, REQUIRED_BINARY) and compiler_version(context) or nil
  local inventory = read_inventory(context, flags)
  local items = {}

  for _, entry in ipairs(inventory) do
    local outputs = existing_outputs(context, entry.sourcePath, flags)
    if #outputs == 0 then
      outputs = known_outputs_from_entry(entry)
    end
    items[#items + 1] = normalize_item(entry.sourcePath, entry.buildMode, outputs, compiler)
  end

  sort_items(items)
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  local items = {}
  emit_event(context, "outdated", items)
  return items
end

function plugin.search(context, prompt)
  local cleaned = request_prompt(context, prompt)
  if cleaned == "" then
    emit_event(context, "searched", {})
    return {}
  end
  local lowered = lower(cleaned)
  local items = {}
  for _, item in ipairs(plugin.list(context)) do
    local blob = lower((item.name or "") .. " " .. ((item.extraFields and item.extraFields.sourcePath) or ""))
    if blob:find(lowered, 1, true) ~= nil then
      items[#items + 1] = item
    end
  end
  sort_items(items)
  emit_event(context, "searched", items)
  return items
end

function plugin.info(context, name)
  local cleaned = request_prompt(context, name)
  if cleaned == "" then
    emit_event(context, "informed", {})
    return {}
  end
  local flags = request_flags(context)
  local resolved = resolve_target(context, cleaned)
  if resolved ~= nil then
    local item = normalize_item(resolved, build_mode(flags, resolved), existing_outputs(context, resolved, flags), compiler_version(context))
    emit_event(context, "informed", item)
    return item
  end
  for _, item in ipairs(plugin.list(context)) do
    if item.name == cleaned or item.packageId == cleaned or ((item.extraFields and item.extraFields.sourcePath) == cleaned) then
      emit_event(context, "informed", item)
      return item
    end
  end
  emit_event(context, "informed", {})
  return {}
end

function plugin.resolvePackage(context, package)
  local target = package_target(package)
  if target == nil then
    return nil
  end
  local resolved = resolve_target(context, target)
  if resolved == nil then
    return nil
  end
  return {
    name = strip_extension(basename(resolved)),
    path = resolved,
    packageId = build_package_id(resolved),
    packageType = "opa",
    type = "package",
  }
end

function plugin.shutdown()
  return true
end

return plugin
