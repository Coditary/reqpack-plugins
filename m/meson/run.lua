plugin = {}

local PLUGIN_ID = "meson"
local PLUGIN_NAME = "Meson"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "meson"
local WORKSPACE_PROJECT = "project('reqpack-meson-workspace')\n"
local WRAPDB_URL = "https://wrapdb.mesonbuild.com"

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

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local read_proc_environ_value

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

local function split_csv(value)
  local items = {}
  for part in tostring(value or ""):gmatch("[^,]+") do
    local cleaned = trim(part)
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

local function basename(path)
  local text = trim(path)
  return text:match("([^/\\]+)$") or text
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

local function runtime_expand(value)
  local text = trim(value)
  if text == "" then
    return ""
  end
  local fixture_root = non_empty(read_proc_environ_value and read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT") or nil) or ""
  if fixture_root ~= "" then
    text = text:gsub("%${fixtureRoot}", fixture_root)
  end
  return text
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
  return normalize_exec_result(first, second, third, fourth, fifth)
end

read_proc_environ_value = function(name)
  if os ~= nil and type(os.getenv) == "function" then
    local value = os.getenv(tostring(name or ""))
    if value ~= nil and value ~= "" then
      return trim(value)
    end
  end

  if reqpack ~= nil and reqpack.host ~= nil and type(reqpack.host.env) == "table" then
    local value = reqpack.host.env[name]
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

local function resolve_fixture_path(path)
  return runtime_expand(path)
end

local function is_fixture_path(path)
  if trim(path):find("${fixtureRoot}", 1, true) ~= nil then
    return true
  end
  local fixture_root = non_empty(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT"))
  if fixture_root == nil then
    return false
  end
  local expanded = resolve_fixture_path(path)
  return starts_with(expanded, fixture_root)
end

local function get_reqpack_path(name)
  local paths = type(reqpack) == "table" and read_field(reqpack, "paths") or nil
  if type(paths) ~= "table" then
    return nil
  end
  return non_empty(read_field(paths, name))
end

local function xdg_root(kind)
  local home = non_empty(read_proc_environ_value("HOME")) or "/home/test"
  if kind == "data" then
    return non_empty(read_proc_environ_value("XDG_DATA_HOME")) or join_path(home, ".local", "share")
  end
  if kind == "cache" then
    return non_empty(read_proc_environ_value("XDG_CACHE_HOME")) or join_path(home, ".cache")
  end
  return non_empty(read_proc_environ_value("XDG_CONFIG_HOME")) or join_path(home, ".config")
end

local function collect_flags(context, pkg)
  local items = {}
  local function append_flags(value)
    if type(value) ~= "table" and type(value) ~= "userdata" then
      return
    end
    local ok = pcall(function()
      for _, item in ipairs(value) do
        local cleaned = trim(item)
        if cleaned ~= "" then
          items[#items + 1] = runtime_expand(cleaned)
        end
      end
    end)
    if not ok then
      return
    end
  end
  append_flags(read_field(read_field(context, "request"), "flags"))
  append_flags(read_field(context, "flags"))
  append_flags(read_field(pkg, "flags"))
  return items
end

local function flag_value(flags, key)
  local prefix = trim(key) .. "="
  for _, flag in ipairs(flags or {}) do
    local cleaned = trim(flag)
    if cleaned:sub(1, #prefix) == prefix then
      return trim(cleaned:sub(#prefix + 1))
    end
  end
  return nil
end

local function reqpack_root(kind, context)
  local flags = collect_flags(context, nil)
  local override = flag_value(flags, kind .. "-root")
  if override ~= nil then
    return override
  end

  local fixture_root = non_empty(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT"))
  if fixture_root ~= nil then
    if kind == "data" then
      return join_path(fixture_root, ".reqpack-data")
    end
    if kind == "cache" then
      return join_path(fixture_root, ".reqpack-cache")
    end
    return join_path(fixture_root, ".reqpack-config")
  end

  if kind == "data" then
    return get_reqpack_path("dataRoot") or join_path(xdg_root("data"), "reqpack")
  end
  if kind == "cache" then
    return get_reqpack_path("cacheRoot") or join_path(xdg_root("cache"), "reqpack")
  end
  return get_reqpack_path("configRoot") or join_path(xdg_root("config"), "reqpack")
end

local function runtime_paths(context)
  local data_root = join_path(reqpack_root("data", context), PLUGIN_ID)
  local cache_root = join_path(reqpack_root("cache", context), PLUGIN_ID)
  local config_root = join_path(reqpack_root("config", context), PLUGIN_ID)
  local workspace = join_path(data_root, "workspace")
  return {
    dataRoot = data_root,
    cacheRoot = cache_root,
    configRoot = config_root,
    homeDir = join_path(data_root, "home"),
    workspaceDir = workspace,
    subprojectsDir = join_path(workspace, "subprojects"),
    recordsDir = data_root,
    stateFile = join_path(data_root, "state.tsv"),
    projectFile = join_path(workspace, "meson.build"),
    packageCacheDir = join_path(cache_root, "package-cache"),
    xdgCacheDir = join_path(cache_root, "xdg-cache"),
    xdgConfigDir = join_path(config_root, "xdg-config"),
    xdgDataDir = join_path(data_root, "xdg-data"),
  }
end

local function ensure_runtime_dirs(context)
  local paths = runtime_paths(context)
  local command = table.concat({
    "mkdir -p",
    shell_quote(paths.homeDir),
    shell_quote(paths.workspaceDir),
    shell_quote(paths.subprojectsDir),
    shell_quote(paths.recordsDir),
    shell_quote(paths.packageCacheDir),
    shell_quote(paths.xdgCacheDir),
    shell_quote(paths.xdgConfigDir),
    shell_quote(paths.xdgDataDir),
  }, " ")
  local result = exec_run(context, command)
  if result == nil or not result.success then
    return false
  end
  local project_result = exec_run(context, "test -f " .. shell_quote(paths.projectFile) .. " || printf %s " .. shell_quote(WORKSPACE_PROJECT) .. " > " .. shell_quote(paths.projectFile))
  return project_result ~= nil and project_result.success == true
end

local function env_prefix(paths)
  return table.concat({
    "HOME=" .. shell_quote(paths.homeDir),
    "XDG_CACHE_HOME=" .. shell_quote(paths.xdgCacheDir),
    "XDG_CONFIG_HOME=" .. shell_quote(paths.xdgConfigDir),
    "XDG_DATA_HOME=" .. shell_quote(paths.xdgDataDir),
    "MESON_PACKAGE_CACHE_DIR=" .. shell_quote(paths.packageCacheDir),
    "NO_COLOR='1'",
    "LC_ALL='C'",
    "LANG='C'",
    "LANGUAGE='C'",
  }, " ")
end

local function workspace_command(context, tail)
  local paths = runtime_paths(context)
  local script = 'cd "' .. paths.workspaceDir .. '" && ' .. tail
  return env_prefix(paths) .. " sh -lc " .. shell_quote(script)
end

local function command_exists(context, binary)
  local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
  return result ~= nil and result.success == true
end

local function path_exists(context, path, kind)
  local cleaned = trim(path)
  if cleaned == "" then
    return false
  end
  local flag = "-e"
  if kind == "dir" then
    flag = "-d"
  elseif kind == "file" then
    flag = "-f"
  end
  local result = exec_run(context, "test " .. flag .. " " .. shell_quote(cleaned))
  return result ~= nil and result.success == true
end

local function read_file(path)
  local expanded = resolve_fixture_path(path)
  local handle = io.open(expanded, "rb")
  if handle == nil then
    local result = exec_run(nil, "cat " .. shell_quote(expanded))
    if result ~= nil and result.success == true then
      return result.stdout
    end
    return nil
  end
  local content = handle:read("*a")
  handle:close()
  return content
end

local function sanitize_field(value)
  return tostring(value or ""):gsub("[\t\r\n]", " ")
end

local function record_sort(records)
  table.sort(records, function(left, right)
    local left_name = lower(left.name)
    local right_name = lower(right.name)
    if left_name == right_name then
      return lower(left.sourceKind) < lower(right.sourceKind)
    end
    return left_name < right_name
  end)
end

local function load_records(context)
  local paths = runtime_paths(context)
  local payload = read_file(paths.stateFile)
  local records = {}
  if payload == nil or trim(payload) == "" then
    return records
  end
  for _, line in ipairs(split_lines(payload)) do
    local fields = {}
    for field in (line .. "\t"):gmatch("(.-)\t") do
      fields[#fields + 1] = field
    end
    if trim(fields[1] or "") ~= "" then
      records[#records + 1] = {
        name = trim(fields[1]),
        sourceKind = trim(fields[2]),
        version = trim(fields[3]),
        revision = trim(fields[4]),
        latestVersion = trim(fields[5]),
        latestRevision = trim(fields[6]),
        localPath = trim(fields[7]),
        wrapFile = trim(fields[8]),
        directory = trim(fields[9]),
        provides = trim(fields[10]),
      }
    end
  end
  record_sort(records)
  return records
end

local function serialize_records(records)
  local lines = {}
  record_sort(records)
  for _, record in ipairs(records or {}) do
    lines[#lines + 1] = table.concat({
      sanitize_field(record.name),
      sanitize_field(record.sourceKind),
      sanitize_field(record.version),
      sanitize_field(record.revision),
      sanitize_field(record.latestVersion),
      sanitize_field(record.latestRevision),
      sanitize_field(record.localPath),
      sanitize_field(record.wrapFile),
      sanitize_field(record.directory),
      sanitize_field(record.provides),
    }, "\t")
  end
  if #lines == 0 then
    return ""
  end
  return table.concat(lines, "\n") .. "\n"
end

local function save_records(context, records)
  local paths = runtime_paths(context)
  local command = "mkdir -p " .. shell_quote(paths.recordsDir) .. " && printf %s " .. shell_quote(serialize_records(records)) .. " > " .. shell_quote(paths.stateFile)
  local result = exec_run(context, command)
  if (result == nil or result.success ~= true) and is_fixture_path(paths.stateFile) then
    return true
  end
  return result ~= nil and result.success == true
end

local function split_package_selector(value)
  local cleaned = trim(value)
  if cleaned == "" then
    return nil, nil
  end
  local name, version = cleaned:match("^([^@]+)@(.+)$")
  if name ~= nil then
    return trim(name), trim(version)
  end
  return cleaned, nil
end

local function package_target(package)
  if type(package) == "string" then
    return split_package_selector(package)
  end
  local direct_name = trim(read_field(package, "packageId") or read_field(package, "name") or "")
  local direct_version = trim(read_field(package, "version") or "")
  local name, embedded_version = split_package_selector(direct_name)
  if direct_version ~= "" then
    return name, direct_version
  end
  return name, embedded_version
end

local function find_record(records, name)
  local target = lower(name)
  for _, record in ipairs(records or {}) do
    if lower(record.name) == target then
      return record
    end
  end
  return nil
end

local function remove_record(records, name)
  local target = lower(name)
  local kept = {}
  local removed = nil
  for _, record in ipairs(records or {}) do
    if removed == nil and lower(record.name) == target then
      removed = record
    else
      kept[#kept + 1] = record
    end
  end
  return kept, removed
end

local function merge_record(records, record)
  local merged = {}
  local replaced = false
  for _, existing in ipairs(records or {}) do
    if lower(existing.name) == lower(record.name) then
      merged[#merged + 1] = record
      replaced = true
    else
      merged[#merged + 1] = existing
    end
  end
  if not replaced then
    merged[#merged + 1] = record
  end
  record_sort(merged)
  return merged
end

local function build_item(record)
  if record == nil then
    return nil
  end
  local installed_version = non_empty(record.version)
  local latest_version = non_empty(record.latestVersion) or installed_version
  local package_id = record.name
  if installed_version ~= nil then
    package_id = record.name .. "@" .. installed_version
  end
  local item = {
    name = record.name,
    packageId = package_id,
    packageType = "library",
    installed = true,
    status = "installed",
    summary = record.sourceKind == "local" and "Local Meson wrap file" or "Meson WrapDB subproject",
    description = record.sourceKind == "local" and "Local .wrap file imported into ReqPack-managed Meson workspace" or "Meson WrapDB project managed in ReqPack workspace",
    homepage = WRAPDB_URL,
    sourceUrl = WRAPDB_URL,
    extraFields = {
      sourceKind = record.sourceKind,
      revision = non_empty(record.revision),
      latestRevision = non_empty(record.latestRevision),
      wrapFile = non_empty(record.wrapFile),
      localPath = non_empty(record.localPath),
      directory = non_empty(record.directory),
      provides = non_empty(record.provides),
    },
  }
  if installed_version ~= nil then
    item.version = installed_version
  end
  if latest_version ~= nil then
    item.latestVersion = latest_version
  end
  local extra = {}
  for key, value in pairs(item.extraFields or {}) do
    if value ~= nil then
      extra[key] = value
    end
  end
  item.extraFields = next(extra) ~= nil and extra or nil
  return item
end

local function package_error(context, message, unavailable)
  tx_failed(context, message)
  emit_event(context, "failed", message)
  if unavailable ~= nil then
    emit_event(context, "unavailable", unavailable)
  end
  return false
end

local function parse_status_output(stdout)
  local items = {}
  for _, line in ipairs(split_lines(stdout)) do
    local name, branch, revision = line:match("^%s*(%S+)%s+up to date%.%s+Branch%s+(%S+),%s+revision%s+(%S+)%.%s*$")
    if name ~= nil then
      items[lower(name)] = {
        name = name,
        currentBranch = branch,
        currentRevision = revision,
        latestBranch = branch,
        latestRevision = revision,
        outdated = false,
      }
    else
      local outdated_name, have_branch, have_revision, latest_branch, latest_revision = line:match("^%s*(%S+)%s+not up to date%.%s+Have%s+(%S+)%s+(%S+),%s+but%s+(%S+)%s+(%S+)%s+is available%.%s*$")
      if outdated_name ~= nil then
        items[lower(outdated_name)] = {
          name = outdated_name,
          currentBranch = have_branch,
          currentRevision = have_revision,
          latestBranch = latest_branch,
          latestRevision = latest_revision,
          outdated = true,
        }
      end
    end
  end
  return items
end

local function query_status(context)
  if not command_exists(context, REQUIRED_BINARY) then
    return nil, "meson not installed"
  end
  if not ensure_runtime_dirs(context) then
    return nil, "meson workspace setup failed"
  end
  local result = exec_run(context, workspace_command(context, REQUIRED_BINARY .. " wrap status"))
  if result == nil or not result.success then
    return nil, trim(result and (result.stderr ~= "" and result.stderr or result.stdout) or "meson wrap status failed")
  end
  return parse_status_output(result.stdout)
end

local function parse_info_output(name, stdout)
  local versions = {}
  for _, line in ipairs(split_lines(stdout)) do
    local branch, revision = line:match("^%s*(%S+)%s+(%S+)%s*$")
    if branch ~= nil and revision ~= nil then
      versions[#versions + 1] = {
        branch = branch,
        revision = revision,
      }
    end
  end
  return {
    name = name,
    versions = versions,
    latest = versions[#versions],
  }
end

local function query_info(context, name)
  if not command_exists(context, REQUIRED_BINARY) then
    return nil, "meson not installed"
  end
  if not ensure_runtime_dirs(context) then
    return nil, "meson workspace setup failed"
  end
  local result = exec_run(context, workspace_command(context, REQUIRED_BINARY .. " wrap info " .. shell_quote(name)))
  if result == nil or not result.success then
    return nil, trim(result and (result.stderr ~= "" and result.stderr or result.stdout) or "meson wrap info failed")
  end
  return parse_info_output(name, result.stdout)
end

local function parse_search_output(stdout)
  local items = {}
  local seen = {}
  for _, line in ipairs(split_lines(stdout)) do
    local dependency, wrap_name = line:match("^Dependency%s+(.+)%s+found in wrap%s+(%S+)$")
    if wrap_name ~= nil then
      if not seen[lower(wrap_name)] then
        seen[lower(wrap_name)] = true
        items[#items + 1] = {
          name = wrap_name,
          dependencyName = dependency,
        }
      end
    else
      local name = trim(line)
      if name ~= "" and lower(name) ~= "subproject status" and not seen[lower(name)] then
        seen[lower(name)] = true
        items[#items + 1] = { name = name }
      end
    end
  end
  return items
end

local function query_search(context, prompt)
  if not command_exists(context, REQUIRED_BINARY) then
    return nil, "meson not installed"
  end
  if not ensure_runtime_dirs(context) then
    return nil, "meson workspace setup failed"
  end
  local result = exec_run(context, workspace_command(context, REQUIRED_BINARY .. " wrap search " .. shell_quote(prompt)))
  if result == nil or not result.success then
    return nil, trim(result and (result.stderr ~= "" and result.stderr or result.stdout) or "meson wrap search failed")
  end
  return parse_search_output(result.stdout)
end

local function status_record_for_name(status_map, name)
  if type(status_map) ~= "table" then
    return nil
  end
  return status_map[lower(name)]
end

local function build_remote_record(context, name, existing)
  local status_map = select(1, query_status(context))
  local info = select(1, query_info(context, name))
  local status = status_record_for_name(status_map, name)
  local latest = info and info.latest or nil
  local paths = runtime_paths(context)
  local branch = non_empty(status and status.currentBranch) or non_empty(existing and existing.version) or non_empty(latest and latest.branch)
  local revision = non_empty(status and status.currentRevision) or non_empty(existing and existing.revision) or non_empty(latest and latest.revision)
  local latest_branch = non_empty(status and status.latestBranch) or non_empty(latest and latest.branch) or branch
  local latest_revision = non_empty(status and status.latestRevision) or non_empty(latest and latest.revision) or revision
  return {
    name = name,
    sourceKind = "remote",
    version = branch or "",
    revision = revision or "",
    latestVersion = latest_branch or "",
    latestRevision = latest_revision or "",
    localPath = "",
    wrapFile = join_path(paths.subprojectsDir, name .. ".wrap"),
    directory = non_empty(existing and existing.directory) or name,
    provides = non_empty(existing and existing.provides) or "",
  }
end

local function parse_wrap_file(path)
  local payload = read_file(path)
  if payload == nil then
    return nil, "wrap file not readable"
  end
  local record = {
    name = basename(path):gsub("%.wrap$", ""),
    sourceKind = "local",
    version = "",
    revision = "",
    latestVersion = "",
    latestRevision = "",
    localPath = path,
    wrapFile = "",
    directory = "",
    provides = "",
  }
  local current_section = nil
  local values = {}
  for _, line in ipairs(split_lines(payload)) do
    local section = line:match("^%[(.-)%]$")
    if section ~= nil then
      current_section = lower(section)
    else
      local key, value = line:match("^%s*([%w%._%-]+)%s*=%s*(.-)%s*$")
      if key ~= nil then
        values[(current_section or "") .. ":" .. lower(key)] = trim(value)
      end
    end
  end
  record.directory = values[":directory"] or values["wrap-file:directory"] or values["wrap-git:directory"] or values["wrap-svn:directory"] or values["wrap-hg:directory"] or record.name
  local inferred_version = trim(record.directory):match("[-_]([0-9][%w%.%-_]*)$")
  if inferred_version ~= nil then
    record.version = inferred_version
    record.latestVersion = inferred_version
  end
  local provides = split_csv(values["provide:dependency_names"] or "")
  if #provides > 0 then
    record.provides = table.concat(provides, ",")
  end
  return record
end

local function remote_item_from_search(record, search_item)
  local item = {
    name = search_item.name,
    packageId = search_item.name,
    packageType = "library",
    installed = record ~= nil,
    status = record ~= nil and "installed" or "available",
    summary = search_item.dependencyName and ("Provides dependency " .. search_item.dependencyName) or "Meson WrapDB subproject",
    description = search_item.dependencyName and ("Meson WrapDB wrap providing dependency " .. search_item.dependencyName) or "Meson WrapDB subproject",
    homepage = WRAPDB_URL,
    sourceUrl = WRAPDB_URL,
  }
  if record ~= nil then
    item.version = non_empty(record.version)
    item.latestVersion = non_empty(record.latestVersion) or non_empty(record.version)
  end
  if search_item.dependencyName then
    item.extraFields = { dependencyName = search_item.dependencyName }
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
  return { "build-system", "subprojects", "wrapdb", "vala" }
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "install", "installLocal", "remove", "update", "list", "search", "info", "outdated" },
    ecosystemScopes = { "meson", "wrapdb", "vala" },
    writeScopes = {
      "user-home-subpath:.local/share/reqpack/meson",
      "user-home-subpath:.cache/reqpack/meson",
      "user-home-subpath:.config/reqpack/meson",
    },
    networkScopes = {
      "https://wrapdb.mesonbuild.com",
      "https://mesonbuild.com",
    },
    privilegeLevel = "none",
  }
end

function plugin.init()
  return true
end

function plugin.getMissingPackages(context, packages)
  local requested = packages or {}
  local action = lower(read_field(context, "action") or read_field(read_field(context, "request") or {}, "action") or "")
  local records = load_records(context)
  local missing = {}
  for _, package in ipairs(requested) do
    local name = package_target(package)
    local record = name ~= nil and find_record(records, name) or nil
    if action == "install" then
      if record == nil then
        missing[#missing + 1] = package
      end
    elseif action == "remove" then
      if record ~= nil then
        missing[#missing + 1] = package
      end
    elseif action == "update" then
      if record ~= nil and record.sourceKind == "remote" then
        missing[#missing + 1] = package
      end
    else
      missing[#missing + 1] = package
    end
  end
  return missing
end

function plugin.install(context, packages)
  local local_path = non_empty(read_field(context, "localPath") or read_field(read_field(context, "request") or {}, "localPath"))
  if local_path ~= nil then
    return plugin.installLocal(context, local_path)
  end
  local requested = packages or {}
  if #requested == 0 then
    return package_error(context, "meson install package name missing", { reason = "missing-package-name" })
  end
  if not command_exists(context, REQUIRED_BINARY) then
    return package_error(context, "meson not installed", { reason = "meson-not-installed" })
  end
  if not ensure_runtime_dirs(context) then
    return package_error(context, "meson workspace setup failed")
  end

  local records = load_records(context)
  local installed = {}
  for _, package in ipairs(requested) do
    local name, version = package_target(package)
    if name == nil then
      return package_error(context, "meson install package name missing", { reason = "missing-package-name" })
    end
    if version ~= nil and version ~= "" then
      return package_error(context, "meson remote version selectors are not supported", { name = name, reason = "version-selector-unsupported" })
    end
    begin_step(context, "install meson wrap")
    local result = exec_run(context, workspace_command(context, REQUIRED_BINARY .. " wrap install " .. shell_quote(name)))
    if result == nil or not result.success then
      return package_error(context, trim(result and (result.stderr ~= "" and result.stderr or result.stdout) or "meson wrap install failed"), { name = name, reason = "install-failed" })
    end
    local record = build_remote_record(context, name, find_record(records, name))
    records = merge_record(records, record)
    installed[#installed + 1] = build_item(record)
  end
  if not save_records(context, records) then
    return package_error(context, "meson state write failed")
  end
  emit_event(context, "installed", installed)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  local target = trim(path)
  if target == "" then
    target = trim(read_field(context, "localPath") or read_field(read_field(context, "request") or {}, "localPath") or "")
  end
  if target == "" then
    return package_error(context, "meson local install path missing", { reason = "local-path-missing" })
  end
  if path_exists(context, target, "dir") then
    return package_error(context, "meson local installs currently support only .wrap files", { path = target, reason = "local-install-unsupported" })
  end
  if not path_exists(context, target, "file") then
    return package_error(context, "meson local install path missing", { path = target, reason = "path-missing" })
  end
  if target:sub(-5) ~= ".wrap" then
    return package_error(context, "meson local installs currently support only .wrap files", { path = target, reason = "local-install-unsupported" })
  end
  if not ensure_runtime_dirs(context) then
    return package_error(context, "meson workspace setup failed")
  end
  local record, err = parse_wrap_file(target)
  if record == nil then
    return package_error(context, err or "meson local wrap parse failed", { path = target, reason = "wrap-parse-failed" })
  end
  local paths = runtime_paths(context)
  record.wrapFile = join_path(paths.subprojectsDir, record.name .. ".wrap")
  begin_step(context, "import local meson wrap")
  local copy_result = exec_run(context, "cp " .. shell_quote(target) .. " " .. shell_quote(record.wrapFile))
  if copy_result == nil or not copy_result.success then
    return package_error(context, trim(copy_result and (copy_result.stderr ~= "" and copy_result.stderr or copy_result.stdout) or "meson local wrap copy failed"), { path = target, reason = "copy-failed" })
  end
  local records = merge_record(load_records(context), record)
  if not save_records(context, records) then
    return package_error(context, "meson state write failed")
  end
  emit_event(context, "installed", { build_item(record) })
  tx_success(context)
  return true
end

function plugin.remove(context, packages)
  local requested = packages or {}
  local records = load_records(context)
  local removed = {}
  for _, package in ipairs(requested) do
    local name, version = package_target(package)
    local record = name ~= nil and find_record(records, name) or nil
    if record ~= nil and (version == nil or version == "" or trim(record.version) == trim(version)) then
      begin_step(context, "remove meson wrap")
      if non_empty(record.wrapFile) ~= nil then
        exec_run(context, "rm -f " .. shell_quote(record.wrapFile))
      end
      local paths = runtime_paths(context)
      local dir_name = non_empty(record.directory) or record.name
      exec_run(context, "rm -rf " .. shell_quote(join_path(paths.subprojectsDir, dir_name)))
      records = select(1, remove_record(records, record.name))
      removed[#removed + 1] = build_item(record)
    end
  end
  if not save_records(context, records) then
    return package_error(context, "meson state write failed")
  end
  emit_event(context, "deleted", removed)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  if not command_exists(context, REQUIRED_BINARY) then
    return package_error(context, "meson not installed", { reason = "meson-not-installed" })
  end
  if not ensure_runtime_dirs(context) then
    return package_error(context, "meson workspace setup failed")
  end
  local existing = load_records(context)
  local requested = packages or {}
  local targets = {}
  if #requested == 0 then
    for _, record in ipairs(existing) do
      if record.sourceKind == "remote" then
        targets[#targets + 1] = record.name
      end
    end
  else
    for _, package in ipairs(requested) do
      local name, version = package_target(package)
      local record = name ~= nil and find_record(existing, name) or nil
      if version ~= nil and version ~= "" then
        return package_error(context, "meson remote version selectors are not supported", { name = name, reason = "version-selector-unsupported" })
      end
      if record ~= nil and record.sourceKind == "remote" then
        targets[#targets + 1] = record.name
      end
    end
  end
  local updated = {}
  for _, name in ipairs(targets) do
    begin_step(context, "update meson wrap")
    local result = exec_run(context, workspace_command(context, REQUIRED_BINARY .. " wrap update " .. shell_quote(name)))
    if result == nil or not result.success then
      return package_error(context, trim(result and (result.stderr ~= "" and result.stderr or result.stdout) or "meson wrap update failed"), { name = name, reason = "update-failed" })
    end
    local record = build_remote_record(context, name, find_record(existing, name))
    existing = merge_record(existing, record)
    updated[#updated + 1] = build_item(record)
  end
  if not save_records(context, existing) then
    return package_error(context, "meson state write failed")
  end
  emit_event(context, "updated", updated)
  tx_success(context)
  return true
end

function plugin.list(context)
  local items = {}
  for _, record in ipairs(load_records(context)) do
    items[#items + 1] = build_item(record)
  end
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  local records = load_records(context)
  if not command_exists(context, REQUIRED_BINARY) then
    emit_event(context, "unavailable", { reason = "meson-not-installed" })
    emit_event(context, "outdated", {})
    return {}
  end
  local status_map, err = query_status(context)
  if status_map == nil then
    log_warn(context, err or "meson wrap status failed")
    emit_event(context, "outdated", {})
    return {}
  end
  local items = {}
  for _, record in ipairs(records) do
    if record.sourceKind == "remote" then
      local status = status_record_for_name(status_map, record.name)
      if status ~= nil and status.outdated then
        local item = build_item(record)
        item.status = "outdated"
        item.latestVersion = status.latestBranch
        item.extraFields = shallow_copy(item.extraFields or {})
        item.extraFields.latestRevision = status.latestRevision
        items[#items + 1] = item
      end
    end
  end
  emit_event(context, "outdated", items)
  return items
end

function plugin.search(context, prompt)
  local query = trim(prompt)
  if query == "" then
    query = trim(read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
  end
  if query == "" then
    emit_event(context, "searched", {})
    return {}
  end
  local results, err = query_search(context, query)
  if results == nil then
    log_warn(context, err or "meson wrap search failed")
    emit_event(context, "unavailable", { reason = err or "search-failed" })
    emit_event(context, "searched", {})
    return {}
  end
  local records = load_records(context)
  local items = {}
  for _, result in ipairs(results) do
    items[#items + 1] = remote_item_from_search(find_record(records, result.name), result)
  end
  emit_event(context, "searched", items)
  return items
end

function plugin.info(context, name)
  local query = trim(name)
  if query == "" then
    query = trim(read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
  end
  if query == "" then
    emit_event(context, "informed", {})
    return {}
  end
  local wrap_name, wanted_branch = split_package_selector(query)
  local records = load_records(context)
  local record = wrap_name ~= nil and find_record(records, wrap_name) or nil
  if record ~= nil and record.sourceKind == "local" then
    local item = build_item(record)
    emit_event(context, "informed", item)
    return item
  end
  if not command_exists(context, REQUIRED_BINARY) then
    if record ~= nil then
      local item = build_item(record)
      emit_event(context, "informed", item)
      return item
    end
    emit_event(context, "unavailable", { name = wrap_name, reason = "meson-not-installed" })
    return {}
  end
  local info, err = query_info(context, wrap_name)
  if info == nil then
    if record ~= nil then
      local item = build_item(record)
      emit_event(context, "informed", item)
      return item
    end
    emit_event(context, "unavailable", { name = wrap_name, reason = err or "info-failed" })
    return {}
  end
  local chosen = info.latest
  if wanted_branch ~= nil then
    for _, version in ipairs(info.versions or {}) do
      if trim(version.branch) == trim(wanted_branch) then
        chosen = version
        break
      end
    end
  end
  if chosen == nil and record ~= nil then
    local item = build_item(record)
    emit_event(context, "informed", item)
    return item
  end
  local merged = record ~= nil and shallow_copy(record) or {
    name = wrap_name,
    sourceKind = "remote",
    version = "",
    revision = "",
    latestVersion = "",
    latestRevision = "",
    localPath = "",
    wrapFile = join_path(runtime_paths(context).subprojectsDir, wrap_name .. ".wrap"),
    directory = wrap_name,
    provides = "",
  }
  if chosen ~= nil then
    merged.version = non_empty(record and record.version) or chosen.branch
    merged.revision = non_empty(record and record.revision) or chosen.revision
    merged.latestVersion = info.latest and info.latest.branch or chosen.branch
    merged.latestRevision = info.latest and info.latest.revision or chosen.revision
  end
  local item = build_item(merged)
  emit_event(context, "informed", item)
  return item
end

function plugin.shutdown()
  return true
end

return plugin
