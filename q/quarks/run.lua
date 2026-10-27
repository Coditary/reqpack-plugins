plugin = {}

local PLUGIN_ID = "quarks"
local PLUGIN_NAME = "quarks"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "sclang"

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

local function sc_escape(value)
  local text = tostring(value or "")
  text = text:gsub("\\", "\\\\")
  text = text:gsub('"', '\\"')
  return text
end

local function sc_string(value)
  return '"' .. sc_escape(value) .. '"'
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

local function is_url(value)
  local text = trim(value)
  return starts_with(text, "http://")
    or starts_with(text, "https://")
    or starts_with(text, "ssh://")
    or starts_with(text, "git@")
end

local function is_path_like(value)
  local text = trim(value)
  return starts_with(text, "/")
    or starts_with(text, "./")
    or starts_with(text, "../")
    or starts_with(text, "~/")
    or text:match("^[A-Za-z]:[/\\]") ~= nil
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

local path_exists

local function ensure_directory(context, path)
  local dir = trim(expand_runtime_placeholders(path))
  if dir == "" or dir == "." then
    return true
  end
  local result = exec_run(context, "mkdir -p " .. shell_quote(dir))
  if result ~= nil and result.success ~= true then
    return false
  end
  if os ~= nil and type(os.execute) == "function" then
    local ok, _, code = os.execute("mkdir -p " .. shell_quote(dir))
    if ok == true or ok == 0 or code == 0 then
      return true
    end
  end
  local probe = io.open(join_path(dir, "."), "rb")
  if probe ~= nil then
    probe:close()
    return true
  end
  return result ~= nil and result.success == true
end

local function read_text_file(context, path)
  local cleaned = expand_runtime_placeholders(path)
  local handle = io.open(cleaned, "rb")
  if handle ~= nil then
    local content = handle:read("*a")
    handle:close()
    return content
  end
  local result = exec_run(context, "cat " .. shell_quote(cleaned))
  if result ~= nil and result.success == true then
    return result.stdout or ""
  end
  return nil
end

local function write_text_file(context, path, content)
  local cleaned = expand_runtime_placeholders(path)
  if not ensure_directory(context, dirname(cleaned)) then
    return nil, "failed to prepare directory for " .. cleaned
  end
  if context ~= nil then
    local result = exec_run(context, "printf %s " .. shell_quote(content or "") .. " > " .. shell_quote(cleaned))
    if result ~= nil and result.success == true then
      return true, nil
    end
  end
  local handle, open_error = io.open(cleaned, "wb")
  if handle == nil then
    local result = exec_run(context, "printf %s " .. shell_quote(content or "") .. " > " .. shell_quote(cleaned))
    if result ~= nil and result.success == true then
      return true, nil
    end
    return nil, open_error or first_non_empty(result and result.stderr, result and result.stdout, "failed to write " .. cleaned)
  end
  local ok, write_error = handle:write(content or "")
  handle:close()
  if not ok then
    return nil, write_error
  end
  return true, nil
end

path_exists = function(context, path)
  local cleaned = expand_runtime_placeholders(path)
  local handle = io.open(cleaned, "rb")
  if handle ~= nil then
    handle:close()
    return true
  end
  local dir = io.open(join_path(cleaned, "."), "rb")
  if dir ~= nil then
    dir:close()
    return true
  end
  local file_result = exec_run(context, "test -f " .. shell_quote(cleaned))
  if file_result ~= nil and file_result.success == true then
    return true
  end
  local dir_result = exec_run(context, "test -d " .. shell_quote(cleaned))
  return dir_result ~= nil and dir_result.success == true
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
    local ok, value = pcall(function()
      return os.date("!%Y-%m-%dT%H:%M:%SZ")
    end)
    if ok and value ~= nil then
      return value
    end
  end
  local result = exec_run(context, "date -u +%Y-%m-%dT%H:%M:%SZ")
  return first_non_empty(result and result.stdout, "1970-01-01T00:00:00Z")
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
  local explicit = expand_runtime_placeholders(flag_value(collect_flags(context, packages ~= nil and packages[1] or nil), "data-root") or "")
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
  local home = join_path(root, "home")
  return {
    root = root,
    home = home,
    xdgConfig = join_path(home, ".config"),
    xdgData = join_path(home, ".local", "share"),
    xdgCache = join_path(home, ".cache"),
    config = join_path(root, "config"),
    runtime = join_path(root, "runtime"),
    cache = join_path(root, "cache"),
    state = join_path(root, "state"),
    installedFile = join_path(root, "state", "installed.tsv"),
    directoryFile = join_path(root, "cache", "directory.tsv"),
    scripts = join_path(root, "runtime", "scripts"),
  }
end

local function ensure_paths(context, paths)
  return ensure_directory(context, paths.root)
    and ensure_directory(context, paths.home)
    and ensure_directory(context, paths.xdgConfig)
    and ensure_directory(context, paths.xdgData)
    and ensure_directory(context, paths.xdgCache)
    and ensure_directory(context, paths.config)
    and ensure_directory(context, paths.runtime)
    and ensure_directory(context, paths.cache)
    and ensure_directory(context, paths.state)
    and ensure_directory(context, paths.scripts)
end

local function env_prefix(paths)
  return table.concat({
    "NO_COLOR=1",
    "LC_ALL=C",
    "LANG=C",
    "LANGUAGE=C",
    "HOME=" .. shell_quote(paths.home),
    "XDG_CONFIG_HOME=" .. shell_quote(paths.xdgConfig),
    "XDG_DATA_HOME=" .. shell_quote(paths.xdgData),
    "XDG_CACHE_HOME=" .. shell_quote(paths.xdgCache),
  }, " ")
end

local function script_path(paths, name)
  return join_path(paths.scripts, name .. ".scd")
end

local function run_sclang_script(context, paths, name, content)
  if not ensure_paths(context, paths) then
    return nil, "failed to prepare quarks runtime directories"
  end
  local target = script_path(paths, name)
  local ok, error_message
  ok, error_message = write_text_file(context, target, content)
  if not ok then
    return nil, error_message
  end
  local result = exec_run(context, env_prefix(paths) .. " " .. REQUIRED_BINARY .. " -D " .. shell_quote(target))
  if result == nil or result.success ~= true then
    return nil, first_non_empty(result and result.stderr, result and result.stdout, "sclang command failed")
  end
  return result.stdout or "", nil
end

local function sc_header()
  return [=[(
var reqpackSanitize = { |value|
  if(value.isNil, { "" }, { value.asString });
};
var reqpackEmit = { |row|
  ("REQPACK\t" ++ row.collect(reqpackSanitize).join(Char.tab.asString)).postln;
};
]=]
end

local function sc_footer()
  return [=[
0.exit;
)]=]
end

local function build_directory_script()
  return table.concat({
    sc_header(),
    [=[Quarks.fetchDirectory(true);
Quarks.directory.keys.asArray.sort.do { |name|
  reqpackEmit.value(["DIR", name, Quarks.directory[name].asString]);
};]=],
    sc_footer(),
  }, "\n")
end

local function build_list_script()
  return table.concat({
    sc_header(),
    [=[Quarks.installed.asArray.sort({ |a, b| a.name.asString.toLower < b.name.asString.toLower }).do { |quark|
  var name = quark.name ? "";
  var version = quark.version ? "";
  var summary = quark.summary ? "";
  var url = quark.url ? "";
  var refspec = quark.refspec ? "";
  var localPath = quark.localPath ? "";
  var isGit = if(Git.isGit(localPath), { "true" }, { "false" });
  reqpackEmit.value(["ITEM", name, version, summary, url, refspec, localPath, isGit]);
};]=],
    sc_footer(),
  }, "\n")
end

local function build_install_script(target, refspec)
  local install_line
  if non_empty(refspec) ~= nil then
    install_line = "Quarks.install(" .. sc_string(target) .. ", " .. sc_string(refspec) .. ");"
  else
    install_line = "Quarks.install(" .. sc_string(target) .. ");"
  end
  return table.concat({
    sc_header(),
    install_line,
    sc_footer(),
  }, "\n")
end

local function build_remove_script(target)
  return table.concat({
    sc_header(),
    "Quarks.uninstall(" .. sc_string(target) .. ");",
    sc_footer(),
  }, "\n")
end

local function build_update_script(target)
  local body
  if non_empty(target) ~= nil then
    body = "Quarks.update(" .. sc_string(target) .. ");"
  else
    body = [=[Quarks.installed.do { |quark|
  if(Git.isGit(quark.localPath), {
    quark.update;
  });
};]=]
  end
  return table.concat({
    sc_header(),
    body,
    sc_footer(),
  }, "\n")
end

local function parse_directory_entry(value)
  local text = trim(value)
  if text == "" then
    return "", ""
  end
  local index = text:match("^.*()@")
  if index == nil then
    return text, ""
  end
  local url = trim(text:sub(1, index - 1))
  local refspec = trim(text:sub(index + 1))
  if url == "" then
    return text, ""
  end
  return url, refspec
end

local function build_item_from_record(record)
  if record == nil then
    return nil
  end
  local item = {
    name = record.name,
    packageId = record.name,
    version = non_empty(record.version) or "",
    installed = record.installed == true,
    status = record.status or (record.installed == true and "installed" or "available"),
    packageType = "supercollider-quark",
    type = "package",
    summary = non_empty(record.summary),
    description = non_empty(record.summary),
    homepage = non_empty(record.url),
  }
  if non_empty(record.latestVersion) ~= nil and trim(record.latestVersion) ~= trim(record.version or "") then
    item.latestVersion = record.latestVersion
  end
  local extra = {
    url = non_empty(record.url),
    refspec = non_empty(record.refspec),
    localPath = non_empty(record.localPath),
    sourceKind = non_empty(record.sourceKind),
    isGit = non_empty(record.isGit),
    installedAt = non_empty(record.installedAt),
  }
  if next(extra) ~= nil then
    item.extraFields = extra
  end
  return item
end

local function sort_items(items)
  table.sort(items, function(left, right)
    return lower(read_field(left, "name") or read_field(left, "packageId") or "") < lower(read_field(right, "name") or read_field(right, "packageId") or "")
  end)
end

local function infer_source_kind(paths, url, local_path)
  if non_empty(url) == nil then
    return "local-path"
  end
  if starts_with(trim(local_path), join_path(paths.xdgData, "SuperCollider", "downloaded-quarks")) then
    return "directory"
  end
  return "git-url"
end

local function parse_live_items(stdout, paths)
  local items = {}
  for _, line in ipairs(split_lines(stdout)) do
    if starts_with(line, "REQPACK\t") then
      local fields = split_tsv(line)
      if fields[2] == "ITEM" then
        local record = {
          name = trim(fields[3]),
          version = trim(fields[4]),
          summary = trim(fields[5]),
          url = trim(fields[6]),
          refspec = trim(fields[7]),
          localPath = trim(fields[8]),
          isGit = trim(fields[9]),
          installed = true,
        }
        record.sourceKind = infer_source_kind(paths, record.url, record.localPath)
        record.status = "installed"
        items[#items + 1] = record
      end
    end
  end
  table.sort(items, function(left, right)
    return lower(left.name) < lower(right.name)
  end)
  return items
end

local function parse_directory_rows(stdout)
  local items = {}
  for _, line in ipairs(split_lines(stdout)) do
    if starts_with(line, "REQPACK\t") then
      local fields = split_tsv(line)
      if fields[2] == "DIR" then
        local url, refspec = parse_directory_entry(fields[4])
        items[#items + 1] = {
          name = trim(fields[3]),
          url = url,
          refspec = refspec,
        }
      end
    end
  end
  table.sort(items, function(left, right)
    return lower(left.name) < lower(right.name)
  end)
  return items
end

local function read_installed_records(context, path)
  local records = {}
  local content = read_text_file(context, path)
  if content == nil or content == "" then
    return records
  end
  for _, line in ipairs(split_lines(content)) do
    local fields = split_tsv(line)
    local name = non_empty(fields[1])
    if name ~= nil then
      records[lower(name)] = {
        name = name,
        version = trim(fields[2]),
        summary = trim(fields[3]),
        url = trim(fields[4]),
        refspec = trim(fields[5]),
        localPath = trim(fields[6]),
        sourceKind = trim(fields[7]),
        isGit = trim(fields[8]),
        installedAt = trim(fields[9]),
        installed = true,
        status = "installed",
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
  table.sort(items, function(left, right)
    return lower(left.name) < lower(right.name)
  end)
  return items
end

local function write_installed_records(context, path, records)
  local lines = {}
  for _, record in ipairs(installed_records_list(records)) do
    lines[#lines + 1] = table.concat({
      trim(record.name),
      trim(record.version),
      trim(record.summary),
      trim(record.url),
      trim(record.refspec),
      trim(record.localPath),
      trim(record.sourceKind),
      trim(record.isGit),
      trim(record.installedAt),
    }, "\t")
  end
  local payload = #lines > 0 and (table.concat(lines, "\n") .. "\n") or ""
  return write_text_file(context, path, payload)
end

local function read_directory_records(context, path)
  local records = {}
  local content = read_text_file(context, path)
  if content == nil or content == "" then
    return records
  end
  for _, line in ipairs(split_lines(content)) do
    local fields = split_tsv(line)
    local name = non_empty(fields[1])
    if name ~= nil then
      records[lower(name)] = {
        name = name,
        url = trim(fields[2]),
        refspec = trim(fields[3]),
      }
    end
  end
  return records
end

local write_directory_records

local function safe_write_directory_records(context, path, records)
  local ok, error_message = write_directory_records(context, path, records)
  if ok then
    return true, nil
  end
  return nil, error_message
end

local function directory_records_list(records)
  local items = {}
  for _, record in pairs(records or {}) do
    items[#items + 1] = shallow_copy(record)
  end
  table.sort(items, function(left, right)
    return lower(left.name) < lower(right.name)
  end)
  return items
end

write_directory_records = function(context, path, records)
  local lines = {}
  for _, record in ipairs(directory_records_list(records)) do
    lines[#lines + 1] = table.concat({ trim(record.name), trim(record.url), trim(record.refspec) }, "\t")
  end
  local payload = #lines > 0 and (table.concat(lines, "\n") .. "\n") or ""
  return write_text_file(context, path, payload)
end

local function refresh_installed_snapshot(context, paths)
  local previous = read_installed_records(context, paths.installedFile)
  local stdout, error_message = run_sclang_script(context, paths, "quarks-list", build_list_script())
  if stdout == nil then
    return nil, error_message
  end
  local now = timestamp_now(context)
  local current = {}
  for _, record in ipairs(parse_live_items(stdout, paths)) do
    local prior = previous[lower(record.name)]
    record.installedAt = prior ~= nil and prior.installedAt or now
    current[lower(record.name)] = record
  end
  local ok, write_error = write_installed_records(context, paths.installedFile, current)
  if not ok then
    return nil, write_error
  end
  return current, nil
end

local function refresh_directory_cache(context, paths)
  local stdout, error_message = run_sclang_script(context, paths, "quarks-directory", build_directory_script())
  if stdout == nil then
    return nil, error_message
  end
  local current = {}
  for _, record in ipairs(parse_directory_rows(stdout)) do
    current[lower(record.name)] = record
  end
  local ok, write_error = safe_write_directory_records(context, paths.directoryFile, current)
  if not ok then
    log_warn(context, write_error)
    return current, nil
  end
  return current, nil
end

local function installed_records_map(context, paths, refresh)
  if refresh == true then
    return refresh_installed_snapshot(context, paths)
  end
  local cached = read_installed_records(context, paths.installedFile)
  if next(cached) ~= nil then
    return cached, nil
  end
  return refresh_installed_snapshot(context, paths)
end

local function directory_records_map(context, paths, refresh)
  if refresh == true then
    return refresh_directory_cache(context, paths)
  end
  local cached = read_directory_records(context, paths.directoryFile)
  if next(cached) ~= nil then
    return cached, nil
  end
  return refresh_directory_cache(context, paths)
end

local function search_items(installed_map, directory_map, query)
  local items = {}
  local seen = {}
  local needle = lower(query)
  for _, record in pairs(directory_map or {}) do
    local haystack = table.concat({ lower(record.name), lower(record.url), lower(record.refspec) }, "\n")
    if haystack:find(needle, 1, true) ~= nil then
      local installed = installed_map[lower(record.name)]
      local merged = shallow_copy(record)
      merged.version = installed ~= nil and installed.version or ""
      merged.summary = installed ~= nil and installed.summary or ""
      merged.localPath = installed ~= nil and installed.localPath or ""
      merged.sourceKind = installed ~= nil and installed.sourceKind or (non_empty(record.url) ~= nil and "directory" or "available")
      merged.isGit = installed ~= nil and installed.isGit or "false"
      merged.installedAt = installed ~= nil and installed.installedAt or ""
      merged.installed = installed ~= nil
      merged.status = installed ~= nil and "installed" or "available"
      items[#items + 1] = build_item_from_record(merged)
      seen[lower(record.name)] = true
    end
  end
  for _, installed in pairs(installed_map or {}) do
    if not seen[lower(installed.name)] then
      local haystack = table.concat({ lower(installed.name), lower(installed.localPath), lower(installed.summary) }, "\n")
      if haystack:find(needle, 1, true) ~= nil then
        items[#items + 1] = build_item_from_record(installed)
      end
    end
  end
  sort_items(items)
  return items
end

local function info_item(installed_map, directory_map, target)
  local exact = lower(target)
  local installed = installed_map[exact]
  if installed == nil and is_path_like(target) then
    for _, record in pairs(installed_map or {}) do
      if trim(record.localPath) == trim(target) then
        installed = record
        break
      end
    end
  end
  local directory = directory_map[exact]
  if installed == nil and directory == nil then
    return {}
  end
  local merged = shallow_copy(directory or {})
  if installed ~= nil then
    for key, value in pairs(installed) do
      merged[key] = value
    end
  else
    merged.installed = false
    merged.status = "available"
    merged.sourceKind = non_empty(merged.url) ~= nil and "directory" or nil
  end
  return build_item_from_record(merged) or {}
end

local function resolve_target_value(pkg)
  return package_name(pkg) or ""
end

local function resolve_install_target(pkg)
  return resolve_target_value(pkg), package_version(pkg)
end

local function tracked_record_for_package(records, pkg)
  local target = resolve_target_value(pkg)
  if target == "" then
    return nil
  end
  if is_path_like(target) then
    for _, record in pairs(records or {}) do
      if trim(record.localPath) == trim(target) then
        return record
      end
    end
    return nil
  end
  return records[lower(target)]
end

local function refresh_after_mutation(context, paths)
  local installed, install_error = refresh_installed_snapshot(context, paths)
  if installed == nil then
    return nil, install_error
  end
  local directory = read_directory_records(context, paths.directoryFile)
  if next(directory) == nil then
    directory = nil
  end
  return installed, directory
end

local function latest_commit_sha(context, path)
  local result = exec_run(context, "git -C " .. shell_quote(path) .. " rev-parse @{upstream}")
  if result == nil or result.success ~= true then
    return nil
  end
  return non_empty(result.stdout)
end

local function head_commit_sha(context, path)
  local result = exec_run(context, "git -C " .. shell_quote(path) .. " rev-parse HEAD")
  if result == nil or result.success ~= true then
    return nil
  end
  return non_empty(result.stdout)
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
  return { "audio", "supercollider", "package-manager", "quarks" }
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
    ecosystemScopes = { "supercollider", "quarks" },
    writeScopes = {
      { kind = "plugin-subpath", path = ".reqpack-data" },
    },
    networkScopes = { "github.com" },
    privilegeLevel = "user",
    purlType = "generic",
  }
end

function plugin.getMissingPackages(packages)
  local requested = packages or {}
  if #requested == 0 then
    return {}
  end
  local paths = state_paths(nil, requested)
  local installed, _ = installed_records_map(nil, paths, false)
  local missing = {}
  for _, pkg in ipairs(requested) do
    local action = lower(read_field(pkg, "action") or "install")
    local record = tracked_record_for_package(installed, pkg)
    if action == "remove" or action == "update" then
      if record ~= nil then
        missing[#missing + 1] = pkg
      end
    elseif record == nil then
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
  begin_step(context, "install quarks packages")
  for _, pkg in ipairs(requested) do
    local target, refspec = resolve_install_target(pkg)
    if target == "" then
      return fail_action(context, "quarks package name missing")
    end
    local _, error_message = run_sclang_script(context, paths, "quarks-install", build_install_script(target, refspec))
    if error_message ~= nil then
      return fail_action(context, error_message)
    end
  end

  local installed, refresh_error = refresh_after_mutation(context, paths)
  if installed == nil then
    return fail_action(context, refresh_error)
  end

  local items = {}
  for _, pkg in ipairs(requested) do
    local record = tracked_record_for_package(installed, pkg)
    if record ~= nil then
      items[#items + 1] = build_item_from_record(record)
    end
  end
  emit_event(context, "installed", items)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  local local_path = request_local_path(context, path)
  if local_path == nil then
    return fail_action(context, "local quark path missing")
  end
  if not command_exists(context, REQUIRED_BINARY) then
    return fail_action(context, REQUIRED_BINARY .. " binary not available")
  end

  local paths = state_paths(context, {})
  begin_step(context, "install local quark")
  local _, error_message = run_sclang_script(context, paths, "quarks-install-local", build_install_script(local_path, nil))
  if error_message ~= nil then
    return fail_action(context, error_message)
  end

  local installed, refresh_error = refresh_after_mutation(context, paths)
  if installed == nil then
    return fail_action(context, refresh_error)
  end

  local items = {}
  for _, record in pairs(installed) do
    if trim(record.localPath) == trim(local_path) then
      items[#items + 1] = build_item_from_record(record)
    end
  end
  sort_items(items)
  emit_event(context, "installed", items)
  tx_success(context)
  return true
end

function plugin.remove(context, packages)
  local requested = request_packages(context, packages)
  if #requested == 0 then
    tx_success(context)
    return true
  end
  if not command_exists(context, REQUIRED_BINARY) then
    return fail_action(context, REQUIRED_BINARY .. " binary not available")
  end

  local paths = state_paths(context, requested)
  local before, before_error = installed_records_map(context, paths, false)
  if before == nil then
    return fail_action(context, before_error)
  end
  begin_step(context, "remove quarks packages")

  local removed = {}
  for _, pkg in ipairs(requested) do
    local record = tracked_record_for_package(before, pkg)
    if record == nil then
      return fail_action(context, "tracked quark not found: " .. (resolve_target_value(pkg) or ""))
    end
    local target = is_path_like(resolve_target_value(pkg)) and record.localPath or record.name
    local _, error_message = run_sclang_script(context, paths, "quarks-remove", build_remove_script(target))
    if error_message ~= nil then
      return fail_action(context, error_message)
    end
    removed[#removed + 1] = build_item_from_record(record)
  end

  local _, refresh_error = refresh_after_mutation(context, paths)
  if refresh_error ~= nil then
    return fail_action(context, refresh_error)
  end
  emit_event(context, "deleted", removed)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  local requested = request_packages(context, packages)
  if not command_exists(context, REQUIRED_BINARY) then
    return fail_action(context, REQUIRED_BINARY .. " binary not available")
  end
  local paths = state_paths(context, requested)
  local before, before_error = installed_records_map(context, paths, false)
  if before == nil then
    return fail_action(context, before_error)
  end

  begin_step(context, "update quarks packages")
  if #requested == 0 then
    local _, error_message = run_sclang_script(context, paths, "quarks-update-all", build_update_script(nil))
    if error_message ~= nil then
      return fail_action(context, error_message)
    end
  else
    for _, pkg in ipairs(requested) do
      local record = tracked_record_for_package(before, pkg)
      if record == nil then
        return fail_action(context, "tracked quark not found: " .. (resolve_target_value(pkg) or ""))
      end
      local target = is_path_like(resolve_target_value(pkg)) and record.localPath or record.name
      local _, error_message = run_sclang_script(context, paths, "quarks-update", build_update_script(target))
      if error_message ~= nil then
        return fail_action(context, error_message)
      end
    end
  end

  local after, refresh_error = refresh_after_mutation(context, paths)
  if after == nil then
    return fail_action(context, refresh_error)
  end
  local updated = {}
  if #requested == 0 then
    for _, record in pairs(after) do
      updated[#updated + 1] = build_item_from_record(record)
    end
    sort_items(updated)
  else
    for _, pkg in ipairs(requested) do
      local record = tracked_record_for_package(after, pkg)
      if record ~= nil then
        updated[#updated + 1] = build_item_from_record(record)
      end
    end
  end
  emit_event(context, "updated", updated)
  tx_success(context)
  return true
end

function plugin.list(context)
  local paths = state_paths(context, {})
  if not command_exists(context, REQUIRED_BINARY) and not path_exists(context, paths.installedFile) then
    log_warn(context, REQUIRED_BINARY .. " binary not available")
    emit_event(context, "listed", {})
    return {}
  end
  local installed, error_message = installed_records_map(context, paths, true)
  if installed == nil then
    log_warn(context, error_message)
    installed = read_installed_records(context, paths.installedFile)
  end
  local items = {}
  for _, record in ipairs(installed_records_list(installed)) do
    items[#items + 1] = build_item_from_record(record)
  end
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  local paths = state_paths(context, {})
  local installed = read_installed_records(context, paths.installedFile)
  if next(installed) == nil then
    installed, _ = installed_records_map(context, paths, false)
  end
  local items = {}
  for _, record in ipairs(installed_records_list(installed)) do
    if lower(record.isGit) == "true" and non_empty(record.localPath) ~= nil then
      exec_run(context, "git -C " .. shell_quote(record.localPath) .. " fetch --tags --quiet")
      local head = head_commit_sha(context, record.localPath)
      local upstream = latest_commit_sha(context, record.localPath)
      if head ~= nil and upstream ~= nil and trim(head) ~= trim(upstream) then
        local item_record = shallow_copy(record)
        item_record.status = "outdated"
        item_record.latestVersion = upstream
        items[#items + 1] = build_item_from_record(item_record)
      end
    end
  end
  emit_event(context, "outdated", items)
  return items
end

function plugin.search(context, prompt)
  local query = request_prompt(context, prompt)
  if query == "" then
    emit_event(context, "searched", {})
    return {}
  end

  local paths = state_paths(context, {})
  local installed = read_installed_records(context, paths.installedFile)
  local directory, error_message = directory_records_map(context, paths, true)
  if directory == nil then
    log_warn(context, error_message)
    directory = read_directory_records(context, paths.directoryFile)
  end
  local items = search_items(installed, directory, query)
  emit_event(context, "searched", items)
  return items
end

function plugin.info(context, name)
  local target = request_prompt(context, name)
  if target == "" then
    emit_event(context, "informed", {})
    return {}
  end

  local paths = state_paths(context, {})
  local installed = read_installed_records(context, paths.installedFile)
  if next(installed) == nil and command_exists(context, REQUIRED_BINARY) then
    installed = installed_records_map(context, paths, true) or {}
  end
  local directory = read_directory_records(context, paths.directoryFile)
  if next(directory) == nil and command_exists(context, REQUIRED_BINARY) then
    local refreshed = directory_records_map(context, paths, true)
    if type(refreshed) == "table" then
      directory = refreshed
    end
  end
  local item = info_item(installed, directory, target)
  emit_event(context, "informed", item)
  return item
end

function plugin.resolvePackage(context, package)
  return plugin.info(context, package_name(package))
end

return plugin
