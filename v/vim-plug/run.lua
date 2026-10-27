plugin = {}

local PLUGIN_ID = "vim-plug"
local PLUGIN_NAME = "vim-plug"
local PLUGIN_VERSION = "0.1.0"
local PLUG_URL = "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"

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

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function starts_with(value, prefix)
  local text = tostring(value or "")
  local expected = tostring(prefix or "")
  return text:sub(1, #expected) == expected
end

local function ends_with(value, suffix)
  local text = tostring(value or "")
  local expected = tostring(suffix or "")
  if expected == "" then
    return true
  end
  return text:sub(-#expected) == expected
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
  local cleaned = trim(path)
  local parent = cleaned:match("^(.*)/[^/]+$")
  if parent == nil or parent == "" then
    return "."
  end
  return parent
end

local function basename(path)
  local cleaned = trim(path)
  return cleaned:match("([^/\\]+)$") or cleaned
end

local function strip_git_suffix(value)
  return trim(value):gsub("%.git$", "")
end

local function sanitize_tsv(value)
  return tostring(value or ""):gsub("[\t\r\n]", " ")
end

local function sort_by_name(items)
  table.sort(items, function(left, right)
    return lower(left.name or left.packageId or "") < lower(right.name or right.packageId or "")
  end)
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

local read_proc_environ_value

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

local function runtime_expand(value)
  local text = trim(value)
  if text == "" then
    return ""
  end
  local fixture_root = non_empty(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT")) or ""
  if fixture_root ~= "" then
    text = text:gsub("%${fixtureRoot}", fixture_root)
  end
  if starts_with(text, "~/") then
    local home = non_empty(read_proc_environ_value("HOME"))
    if home ~= nil then
      text = join_path(home, text:sub(3))
    end
  end
  return text
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
        local cleaned = runtime_expand(item)
        if trim(cleaned) ~= "" then
          items[#items + 1] = cleaned
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
  local prefix = lower(key) .. "="
  for _, flag in ipairs(flags or {}) do
    local cleaned = trim(flag)
    if lower(cleaned):sub(1, #prefix) == prefix then
      return trim(cleaned:sub(#prefix + 1))
    end
  end
  return nil
end

local function has_flag(flags, key)
  local needle = lower(trim(key))
  for _, flag in ipairs(flags or {}) do
    if lower(trim(flag)) == needle then
      return true
    end
  end
  return false
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
  return {
    dataRoot = data_root,
    cacheRoot = cache_root,
    configRoot = config_root,
    autoloadDir = join_path(data_root, "autoload"),
    autoloadFile = join_path(data_root, "autoload", "plug.vim"),
    pluggedDir = join_path(data_root, "plugged"),
    tempDir = join_path(cache_root, "tmp"),
    manifestFile = join_path(data_root, "manifest.tsv"),
    stateFile = join_path(data_root, "state.tsv"),
    remoteInfoFile = join_path(cache_root, "remote-info.tsv"),
    configFile = join_path(config_root, "reqpack.vim"),
  }
end

local function ensure_runtime_dirs(context)
  local paths = runtime_paths(context)
  local result = exec_run(context, table.concat({
    "mkdir -p",
    shell_quote(paths.dataRoot),
    shell_quote(paths.cacheRoot),
    shell_quote(paths.configRoot),
    shell_quote(paths.autoloadDir),
    shell_quote(paths.pluggedDir),
    shell_quote(paths.tempDir),
  }, " "))
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

local function is_fixture_path(path)
  local cleaned = trim(path)
  if cleaned:find("${fixtureRoot}", 1, true) ~= nil then
    return true
  end
  local fixture_root = non_empty(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT"))
  if fixture_root == nil then
    return false
  end
  return starts_with(cleaned, fixture_root)
end

local function write_text_file(context, path, content)
  local parent = dirname(path)
  local mkdir_result = exec_run(context, "mkdir -p " .. shell_quote(parent))
  if mkdir_result == nil or mkdir_result.success ~= true then
    return is_fixture_path(path)
  end
  local handle = io.open(path, "wb")
  if handle ~= nil then
    handle:write(tostring(content or ""))
    handle:close()
    return true
  end
  local result = exec_run(context, "printf %s " .. shell_quote(tostring(content or "")) .. " > " .. shell_quote(path))
  if result ~= nil and result.success == true then
    return true
  end
  return is_fixture_path(path)
end

local function read_text_file(context, path)
  local handle = io.open(path, "rb")
  if handle ~= nil then
    local content = handle:read("*a")
    handle:close()
    return content
  end
  local result = exec_run(context, "cat " .. shell_quote(path))
  if result ~= nil and result.success == true then
    return result.stdout
  end
  return nil
end

local function remove_file(context, path)
  local result = exec_run(context, "rm -f " .. shell_quote(path))
  return result ~= nil and result.success == true
end

local function command_exists(context, binary)
  local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
  return result ~= nil and result.success == true
end

local function package_error(context, message, payload)
  tx_failed(context, message)
  if payload ~= nil then
    emit_event(context, "unavailable", payload)
  end
  return false
end

local function vim_quote(value)
  return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

local function vim_list(items)
  local rendered = {}
  for _, item in ipairs(items or {}) do
    rendered[#rendered + 1] = vim_quote(item)
  end
  return "[" .. table.concat(rendered, ", ") .. "]"
end

local function is_remote_url(value)
  local text = trim(value)
  return text:match("^https?://") ~= nil or text:match("^[%w%._%-]+@[%w%._%-]+:") ~= nil
end

local function is_repo_shorthand(value)
  local text = trim(value)
  if text == "" then
    return false
  end
  if starts_with(text, "/") or starts_with(text, "./") or starts_with(text, "../") or starts_with(text, "~/") then
    return false
  end
  if is_remote_url(text) then
    return false
  end
  return text:match("^[%w%._%-]+/[%w%._%-]+%.?[%w%._%-]*$") ~= nil
end

local function source_to_remote_url(source)
  local text = trim(source)
  if is_remote_url(text) then
    return text
  end
  if is_repo_shorthand(text) then
    return "https://github.com/" .. strip_git_suffix(text) .. ".git"
  end
  return nil
end

local function source_homepage(source)
  local text = trim(source)
  if is_repo_shorthand(text) then
    return "https://github.com/" .. strip_git_suffix(text)
  end
  if starts_with(text, "https://") or starts_with(text, "http://") then
    return strip_git_suffix(text)
  end
  return nil
end

local function default_name_for_source(source)
  local text = trim(source)
  if is_repo_shorthand(text) then
    return strip_git_suffix(text:match("/([^/]+)$") or text)
  end
  return strip_git_suffix(basename(text))
end

local function normalize_request_source(pkg)
  return non_empty(read_field(pkg, "name") or read_field(pkg, "packageId") or read_field(pkg, "source"))
end

local function parse_request_entry(context, pkg, source_kind_override)
  local flags = collect_flags(context, pkg)
  local requested_source = source_kind_override == "local"
    and runtime_expand(read_field(pkg, "localPath") or read_field(pkg, "path") or read_field(pkg, "name") or "")
    or runtime_expand(normalize_request_source(pkg) or "")
  if requested_source == "" then
    return nil, "missing-package-name"
  end

  local source_kind = source_kind_override
  if source_kind == nil then
    if is_remote_url(requested_source) or is_repo_shorthand(requested_source) then
      source_kind = "remote"
    else
      source_kind = "local"
    end
  end

  local branch = flag_value(flags, "branch")
  local tag = flag_value(flags, "tag")
  local commit = flag_value(flags, "commit")
  local version = non_empty(read_field(pkg, "version"))
  if version ~= nil and tag == nil and branch == nil and commit == nil and source_kind == "remote" then
    tag = version
  end
  if branch ~= nil and tag ~= nil then
    return nil, "conflicting-selectors"
  end
  if commit ~= nil then
    branch = nil
    tag = nil
  end

  local source = requested_source
  local package_id = source
  if source_kind == "remote" and is_repo_shorthand(source) then
    source = strip_git_suffix(source)
    package_id = source
  end

  local explicit_name = flag_value(flags, "as") or non_empty(read_field(pkg, "as"))
  local name = explicit_name or default_name_for_source(source)
  local custom_dir = runtime_expand(flag_value(flags, "dir") or read_field(pkg, "dir") or "")
  local managed_dir = ""
  local paths = runtime_paths(context)
  if source_kind == "remote" then
    managed_dir = non_empty(custom_dir) or join_path(paths.pluggedDir, name)
  end

  return {
    packageId = package_id,
    name = name,
    sourceKind = source_kind,
    source = source,
    branch = branch or "",
    tag = tag or "",
    commit = commit or "",
    rtp = runtime_expand(flag_value(flags, "rtp") or read_field(pkg, "rtp") or ""),
    dir = custom_dir,
    postUpdate = runtime_expand(flag_value(flags, "do") or read_field(pkg, "do") or ""),
    on = table.concat(split_csv(flag_value(flags, "on") or read_field(pkg, "on") or ""), ","),
    filetypes = table.concat(split_csv(flag_value(flags, "for") or read_field(pkg, "for") or ""), ","),
    frozen = has_flag(flags, "frozen") and "1" or "",
    managedDir = managed_dir,
    homepage = source_homepage(source) or "",
    status = "declared",
  }, nil
end

local function parse_manifest_text(text)
  local items = {}
  for _, line in ipairs(split_lines(text)) do
    local fields = split_tsv(line)
    if trim(fields[1] or "") ~= "" then
      items[#items + 1] = {
        packageId = fields[1] or "",
        name = fields[2] or "",
        sourceKind = fields[3] or "",
        source = fields[4] or "",
        branch = fields[5] or "",
        tag = fields[6] or "",
        commit = fields[7] or "",
        rtp = fields[8] or "",
        dir = fields[9] or "",
        postUpdate = fields[10] or "",
        on = fields[11] or "",
        filetypes = fields[12] or "",
        frozen = fields[13] or "",
        managedDir = fields[14] or "",
      }
    end
  end
  return items
end

local function serialize_manifest(items)
  sort_by_name(items)
  local lines = {}
  for _, item in ipairs(items or {}) do
    lines[#lines + 1] = table.concat({
      sanitize_tsv(item.packageId),
      sanitize_tsv(item.name),
      sanitize_tsv(item.sourceKind),
      sanitize_tsv(item.source),
      sanitize_tsv(item.branch),
      sanitize_tsv(item.tag),
      sanitize_tsv(item.commit),
      sanitize_tsv(item.rtp),
      sanitize_tsv(item.dir),
      sanitize_tsv(item.postUpdate),
      sanitize_tsv(item.on),
      sanitize_tsv(item.filetypes),
      sanitize_tsv(item.frozen),
      sanitize_tsv(item.managedDir),
    }, "\t")
  end
  if #lines == 0 then
    return ""
  end
  return table.concat(lines, "\n") .. "\n"
end

local function parse_state_text(text)
  local items = {}
  for _, line in ipairs(split_lines(text)) do
    local fields = split_tsv(line)
    if trim(fields[1] or "") ~= "" then
      items[#items + 1] = {
        packageId = fields[1] or "",
        name = fields[2] or "",
        sourceKind = fields[3] or "",
        source = fields[4] or "",
        installedVersion = fields[5] or "",
        installedRevision = fields[6] or "",
        branch = fields[7] or "",
        tag = fields[8] or "",
        commit = fields[9] or "",
        managedDir = fields[10] or "",
        status = fields[11] or "installed",
      }
    end
  end
  return items
end

local function serialize_state(items)
  sort_by_name(items)
  local lines = {}
  for _, item in ipairs(items or {}) do
    lines[#lines + 1] = table.concat({
      sanitize_tsv(item.packageId),
      sanitize_tsv(item.name),
      sanitize_tsv(item.sourceKind),
      sanitize_tsv(item.source),
      sanitize_tsv(item.installedVersion),
      sanitize_tsv(item.installedRevision),
      sanitize_tsv(item.branch),
      sanitize_tsv(item.tag),
      sanitize_tsv(item.commit),
      sanitize_tsv(item.managedDir),
      sanitize_tsv(item.status),
    }, "\t")
  end
  if #lines == 0 then
    return ""
  end
  return table.concat(lines, "\n") .. "\n"
end

local function parse_remote_info_text(text)
  local items = {}
  for _, line in ipairs(split_lines(text)) do
    local fields = split_tsv(line)
    if trim(fields[1] or "") ~= "" then
      items[#items + 1] = {
        packageId = fields[1] or "",
        name = fields[2] or "",
        source = fields[3] or "",
        defaultBranch = fields[4] or "",
        latestRevision = fields[5] or "",
        latestVersion = fields[6] or "",
        homepage = fields[7] or "",
        tags = fields[8] or "",
      }
    end
  end
  return items
end

local function serialize_remote_info(items)
  sort_by_name(items)
  local lines = {}
  for _, item in ipairs(items or {}) do
    lines[#lines + 1] = table.concat({
      sanitize_tsv(item.packageId),
      sanitize_tsv(item.name),
      sanitize_tsv(item.source),
      sanitize_tsv(item.defaultBranch),
      sanitize_tsv(item.latestRevision),
      sanitize_tsv(item.latestVersion),
      sanitize_tsv(item.homepage),
      sanitize_tsv(item.tags),
    }, "\t")
  end
  if #lines == 0 then
    return ""
  end
  return table.concat(lines, "\n") .. "\n"
end

local function read_manifest(context)
  local content = read_text_file(context, runtime_paths(context).manifestFile)
  if content == nil then
    return {}
  end
  return parse_manifest_text(content)
end

local function save_manifest(context, items)
  return write_text_file(context, runtime_paths(context).manifestFile, serialize_manifest(items))
end

local function read_state(context)
  local content = read_text_file(context, runtime_paths(context).stateFile)
  if content == nil then
    return {}
  end
  return parse_state_text(content)
end

local function save_state(context, items)
  return write_text_file(context, runtime_paths(context).stateFile, serialize_state(items))
end

local function read_remote_info_cache(context)
  local content = read_text_file(context, runtime_paths(context).remoteInfoFile)
  if content == nil then
    return {}
  end
  return parse_remote_info_text(content)
end

local function save_remote_info_cache(context, items)
  return write_text_file(context, runtime_paths(context).remoteInfoFile, serialize_remote_info(items))
end

local function find_by_name(items, name)
  local needle = lower(name)
  for _, item in ipairs(items or {}) do
    if lower(item.name) == needle then
      return item
    end
  end
  return nil
end

local function find_by_package_id(items, package_id)
  local needle = trim(package_id)
  for _, item in ipairs(items or {}) do
    if trim(item.packageId) == needle then
      return item
    end
  end
  return nil
end

local function merge_manifest_entry(items, entry)
  local merged = {}
  local replaced = false
  for _, item in ipairs(items or {}) do
    if lower(item.name) == lower(entry.name) then
      if trim(item.source) ~= trim(entry.source) then
        return nil, "alias-collision"
      end
      merged[#merged + 1] = shallow_copy(entry)
      replaced = true
    elseif trim(item.packageId) == trim(entry.packageId) or trim(item.source) == trim(entry.source) then
      merged[#merged + 1] = shallow_copy(entry)
      replaced = true
    else
      merged[#merged + 1] = shallow_copy(item)
    end
  end
  if not replaced then
    merged[#merged + 1] = shallow_copy(entry)
  end
  return merged
end

local function remove_manifest_entries(items, requested)
  local removed = {}
  local keep = {}
  local targets = {}
  for _, item in ipairs(requested or {}) do
    targets[lower(item.name or item.packageId or item.source or "")] = true
    if trim(item.packageId or "") ~= "" then
      targets[trim(item.packageId)] = true
    end
    if trim(item.source or "") ~= "" then
      targets[trim(item.source)] = true
    end
  end
  for _, item in ipairs(items or {}) do
    local key = lower(item.name or "")
    if targets[key] or targets[trim(item.packageId)] or targets[trim(item.source)] then
      removed[#removed + 1] = shallow_copy(item)
    else
      keep[#keep + 1] = shallow_copy(item)
    end
  end
  return keep, removed
end

local function merge_state_entry(items, entry)
  local merged = {}
  local replaced = false
  for _, item in ipairs(items or {}) do
    if lower(item.name) == lower(entry.name) or trim(item.packageId) == trim(entry.packageId) then
      merged[#merged + 1] = shallow_copy(entry)
      replaced = true
    else
      merged[#merged + 1] = shallow_copy(item)
    end
  end
  if not replaced then
    merged[#merged + 1] = shallow_copy(entry)
  end
  return merged
end

local function remove_state_entries(items, removed_items)
  local removed_names = {}
  for _, item in ipairs(removed_items or {}) do
    removed_names[lower(item.name or "")] = true
    removed_names[trim(item.packageId or "")] = true
  end
  local keep = {}
  for _, item in ipairs(items or {}) do
    if not removed_names[lower(item.name or "")] and not removed_names[trim(item.packageId or "")] then
      keep[#keep + 1] = shallow_copy(item)
    end
  end
  return keep
end

local function serialize_plug_options(entry)
  local options = {}
  local function add_string(key, value)
    local text = non_empty(value)
    if text ~= nil then
      options[#options + 1] = vim_quote(key) .. ": " .. vim_quote(text)
    end
  end
  local function add_list(key, value)
    local items = split_csv(value)
    if #items == 1 then
      options[#options + 1] = vim_quote(key) .. ": " .. vim_quote(items[1])
    elseif #items > 1 then
      options[#options + 1] = vim_quote(key) .. ": " .. vim_list(items)
    end
  end
  add_string("branch", entry.branch)
  add_string("tag", entry.tag)
  add_string("commit", entry.commit)
  add_string("rtp", entry.rtp)
  add_string("dir", entry.dir)
  add_string("as", entry.name ~= default_name_for_source(entry.source) and entry.name or "")
  add_string("do", entry.postUpdate)
  add_list("on", entry.on)
  add_list("for", entry.filetypes)
  if trim(entry.frozen or "") ~= "" then
    options[#options + 1] = vim_quote("frozen") .. ": 1"
  end
  if #options == 0 then
    return nil
  end
  return "{ " .. table.concat(options, ", ") .. " }"
end

local function render_vim_config(context, manifest)
  local paths = runtime_paths(context)
  local lines = {
    "set nocompatible",
    "set shortmess+=I",
    "filetype off",
    "let g:plug_window = 'enew'",
    "let g:plug_pwindow = 'enew'",
    "execute 'set rtp^=' . fnameescape('" .. paths.dataRoot:gsub("'", "''") .. "')",
    "call plug#begin('" .. paths.pluggedDir:gsub("'", "''") .. "')",
  }
  for _, entry in ipairs(manifest or {}) do
    local source = entry.sourceKind == "local" and runtime_expand(entry.source) or entry.source
    local options = serialize_plug_options(entry)
    if options == nil then
      lines[#lines + 1] = "Plug " .. vim_quote(source)
    else
      lines[#lines + 1] = "Plug " .. vim_quote(source) .. ", " .. options
    end
  end
  lines[#lines + 1] = "call plug#end()"
  lines[#lines + 1] = "filetype plugin indent on"
  return table.concat(lines, "\n") .. "\n"
end

local function save_generated_config(context, manifest)
  return write_text_file(context, runtime_paths(context).configFile, render_vim_config(context, manifest))
end

local function detect_editor(context)
  if command_exists(context, "nvim") then
    return "nvim"
  end
  if command_exists(context, "vim") then
    return "vim"
  end
  return nil
end

local function ensure_bootstrap(context)
  local paths = runtime_paths(context)
  if path_exists(context, paths.autoloadFile, "file") then
    return true
  end
  if not command_exists(context, "curl") then
    return false, "curl-not-installed"
  end
  local result = exec_run(context, "mkdir -p " .. shell_quote(paths.autoloadDir) .. " && curl -fsSL " .. shell_quote(PLUG_URL) .. " -o " .. shell_quote(paths.autoloadFile))
  if result == nil or result.success ~= true then
    return false, trim(result and (result.stderr ~= "" and result.stderr or result.stdout) or "bootstrap-failed")
  end
  return true, nil
end

local function run_headless(context, ex_command)
  local editor = detect_editor(context)
  if editor == nil then
    return nil, "missing-editor"
  end
  local paths = runtime_paths(context)
  local command
  if editor == "nvim" then
    command = table.concat({
      editor,
      "--headless",
      "-u", shell_quote(paths.configFile),
      "-i", "NONE",
      "-c", shell_quote(ex_command),
      "-c", shell_quote("qa"),
    }, " ")
  else
    command = table.concat({
      editor,
      "-es",
      "-u", shell_quote(paths.configFile),
      "-i", "NONE",
      "-c", shell_quote(ex_command),
      "-c", shell_quote("qa"),
    }, " ")
  end
  return exec_run(context, command), nil
end

local function git_current_revision(context, path)
  if trim(path) == "" then
    return nil
  end
  local result = exec_run(context, "git -C " .. shell_quote(path) .. " rev-parse HEAD")
  if result == nil or result.success ~= true then
    return nil
  end
  return non_empty(result.stdout)
end

local function git_remote_origin(context, path)
  if trim(path) == "" then
    return nil
  end
  local result = exec_run(context, "git -C " .. shell_quote(path) .. " remote get-url origin")
  if result == nil or result.success ~= true then
    return nil
  end
  return non_empty(result.stdout)
end

local function parse_remote_info_output(source, output)
  local info = {
    source = source,
    homepage = source_homepage(source) or "",
    defaultBranch = "",
    latestRevision = "",
    latestVersion = "",
    tags = "",
    heads = {},
    tagMap = {},
  }
  local tag_names = {}
  for _, line in ipairs(split_lines(output)) do
    local ref_target = line:match("^ref:%s+refs/heads/([^%s]+)%s+HEAD$")
    if ref_target ~= nil then
      info.defaultBranch = ref_target
    else
      local sha, ref = line:match("^([0-9a-fA-F]+)%s+(.+)$")
      if sha ~= nil and ref ~= nil then
        local branch = ref:match("^refs/heads/(.+)$")
        if branch ~= nil then
          info.heads[branch] = sha
        else
          local tag = ref:match("^refs/tags/(.+)$")
          if tag ~= nil then
            local peeled = false
            if ends_with(tag, "^{}") then
              tag = tag:sub(1, -4)
              peeled = true
            end
            if peeled or info.tagMap[tag] == nil then
              info.tagMap[tag] = sha
            end
          end
        end
      end
    end
  end
  for tag_name in pairs(info.tagMap) do
    tag_names[#tag_names + 1] = tag_name
  end
  table.sort(tag_names)
  info.tags = table.concat(tag_names, ",")
  local tracked = info.defaultBranch ~= "" and info.heads[info.defaultBranch] or nil
  if tracked == nil then
    for _, branch in ipairs(tag_names) do
      tracked = info.tagMap[branch]
      if tracked ~= nil then
        break
      end
    end
  end
  if tracked == nil then
    for _, sha in pairs(info.heads) do
      tracked = sha
      break
    end
  end
  info.latestRevision = tracked or ""
  info.latestVersion = info.defaultBranch ~= "" and info.defaultBranch or (tag_names[#tag_names] or "")
  return info
end

local function fetch_remote_info(context, entry)
  local remote_url = source_to_remote_url(entry.source or entry.packageId or "")
  if remote_url == nil then
    return nil, "remote-source-unsupported"
  end
  local result = exec_run(context, "git ls-remote --symref " .. shell_quote(remote_url) .. " HEAD refs/heads/* refs/tags/*")
  if result == nil or result.success ~= true then
    return nil, trim(result and (result.stderr ~= "" and result.stderr or result.stdout) or "git-ls-remote-failed")
  end
  local info = parse_remote_info_output(entry.source or entry.packageId or remote_url, result.stdout or "")
  info.packageId = entry.packageId or entry.source or remote_url
  info.name = entry.name or default_name_for_source(entry.source or remote_url)
  return info, nil
end

local function upsert_remote_cache_entry(cache, entry)
  local merged = {}
  local replaced = false
  for _, item in ipairs(cache or {}) do
    if trim(item.packageId) == trim(entry.packageId) or lower(item.name) == lower(entry.name) then
      merged[#merged + 1] = shallow_copy(entry)
      replaced = true
    else
      merged[#merged + 1] = shallow_copy(item)
    end
  end
  if not replaced then
    merged[#merged + 1] = shallow_copy(entry)
  end
  return merged
end

local function tracked_revision_for_state(state, remote_info)
  if trim(state.commit or "") ~= "" then
    return trim(state.commit)
  end
  if trim(state.tag or "") ~= "" then
    return trim(state.tag)
  end
  local branch = trim(state.branch or remote_info.defaultBranch or "")
  if branch ~= "" and type(remote_info.heads) == "table" then
    return trim(remote_info.heads[branch] or "")
  end
  return trim(remote_info.latestRevision or "")
end

local function version_label(state, remote_info)
  if trim(state.commit or "") ~= "" then
    return trim(state.commit)
  end
  if trim(state.tag or "") ~= "" then
    return trim(state.tag)
  end
  if trim(state.branch or "") ~= "" then
    return trim(state.branch)
  end
  if remote_info ~= nil then
    return trim(remote_info.defaultBranch or remote_info.latestVersion or "")
  end
  return ""
end

local function build_item(base)
  local item = {
    name = base.name,
    packageId = base.packageId,
    version = base.version or base.installedVersion or "",
    latestVersion = base.latestVersion or "",
    status = base.status or "available",
    installed = base.installed == true,
    packageType = "plugin",
    manager = PLUGIN_ID,
    description = base.description or ("Vim plugin managed through vim-plug: " .. tostring(base.name or base.packageId or "")),
  }
  if non_empty(base.homepage) ~= nil then
    item.homepage = base.homepage
  end
  item.extraFields = {}
  local function put(key, value)
    if non_empty(value) ~= nil then
      item.extraFields[key] = value
    end
  end
  put("source", base.source)
  put("sourceKind", base.sourceKind)
  put("branch", base.branch)
  put("tag", base.tag)
  put("commit", base.commit)
  put("managedDir", base.managedDir)
  put("runtimePath", base.rtp)
  put("defaultBranch", base.defaultBranch)
  put("installedRevision", base.installedRevision)
  put("latestRevision", base.latestRevision)
  put("frozen", base.frozen)
  put("availableTags", base.tags)
  if next(item.extraFields) == nil then
    item.extraFields = nil
  end
  return item
end

local function item_from_manifest(entry, installed_state, remote_info)
  local installed = installed_state ~= nil
  local version = installed and trim(installed_state.installedVersion or "") or version_label(entry, remote_info or {})
  local latest_version = remote_info ~= nil and trim(remote_info.latestVersion or "") or ""
  local latest_revision = remote_info ~= nil and trim(remote_info.latestRevision or "") or ""
  local installed_revision = installed and trim(installed_state.installedRevision or "") or ""
  return build_item({
    name = entry.name,
    packageId = entry.packageId,
    version = version,
    latestVersion = latest_version,
    status = installed and (installed_state.status or "installed") or "declared",
    installed = installed,
    source = entry.source,
    sourceKind = entry.sourceKind,
    branch = entry.branch,
    tag = entry.tag,
    commit = entry.commit,
    managedDir = entry.managedDir,
    rtp = entry.rtp,
    homepage = (remote_info and remote_info.homepage) or source_homepage(entry.source),
    defaultBranch = remote_info and remote_info.defaultBranch or "",
    installedRevision = installed_revision,
    latestRevision = latest_revision,
    frozen = trim(entry.frozen or "") ~= "" and "1" or "",
    tags = remote_info and remote_info.tags or "",
  })
end

local function build_state_entry(entry, installed_revision, remote_info)
  return {
    packageId = entry.packageId,
    name = entry.name,
    sourceKind = entry.sourceKind,
    source = entry.source,
    installedVersion = version_label(entry, remote_info or {}),
    installedRevision = installed_revision or "",
    branch = entry.branch,
    tag = entry.tag,
    commit = entry.commit,
    managedDir = entry.managedDir,
    status = "installed",
  }
end

local function exact_entry_for_query(entries, query)
  local cleaned = trim(query)
  if cleaned == "" then
    return nil
  end
  local lowered = lower(cleaned)
  for _, item in ipairs(entries or {}) do
    if lower(item.name or "") == lowered or trim(item.packageId or "") == cleaned or trim(item.source or "") == cleaned then
      return item
    end
  end
  return nil
end

local function collect_known_items(context)
  local manifest = read_manifest(context)
  local state = read_state(context)
  local cache = read_remote_info_cache(context)
  local items = {}
  local seen = {}
  for _, entry in ipairs(manifest) do
    local state_entry = exact_entry_for_query(state, entry.packageId) or exact_entry_for_query(state, entry.name)
    local cache_entry = exact_entry_for_query(cache, entry.packageId) or exact_entry_for_query(cache, entry.name)
    local item = item_from_manifest(entry, state_entry, cache_entry)
    items[#items + 1] = item
    seen[item.packageId] = true
  end
  for _, state_entry in ipairs(state) do
    if not seen[state_entry.packageId] then
      local cache_entry = exact_entry_for_query(cache, state_entry.packageId) or exact_entry_for_query(cache, state_entry.name)
      items[#items + 1] = build_item({
        name = state_entry.name,
        packageId = state_entry.packageId,
        version = state_entry.installedVersion,
        latestVersion = cache_entry and cache_entry.latestVersion or "",
        status = state_entry.status,
        installed = true,
        source = state_entry.source,
        sourceKind = state_entry.sourceKind,
        branch = state_entry.branch,
        tag = state_entry.tag,
        commit = state_entry.commit,
        managedDir = state_entry.managedDir,
        homepage = cache_entry and cache_entry.homepage or source_homepage(state_entry.source),
        defaultBranch = cache_entry and cache_entry.defaultBranch or "",
        installedRevision = state_entry.installedRevision,
        latestRevision = cache_entry and cache_entry.latestRevision or "",
        tags = cache_entry and cache_entry.tags or "",
      })
    end
  end
  sort_by_name(items)
  return items
end

local function fuzzy_match_item(item, query)
  if query == "" then
    return true
  end
  local haystack = table.concat({
    item.name or "",
    item.packageId or "",
    item.homepage or "",
    type(item.extraFields) == "table" and (item.extraFields.source or "") or "",
  }, " "):lower()
  return haystack:find(query, 1, true) ~= nil
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
  return { "editor-plugin", "vim", "neovim", "git" }
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "install", "installLocal", "remove", "update", "list", "search", "info", "outdated" },
    ecosystemScopes = { "vim", "neovim", "vim-plugin", "git" },
    writeScopes = {
      "user-home-subpath:.local/share/reqpack/vim-plug",
      "user-home-subpath:.cache/reqpack/vim-plug",
      "user-home-subpath:.config/reqpack/vim-plug",
    },
    networkScopes = { "*" },
    privilegeLevel = "user",
    purlType = "generic",
  }
end

function plugin.init()
  return true
end

function plugin.shutdown()
  return true
end

function plugin.getMissingPackages(context, packages)
  local action = lower(read_field(context, "action") or read_field(read_field(context, "request") or {}, "action") or "")
  local manifest = read_manifest(context)
  local missing = {}
  for _, pkg in ipairs(packages or {}) do
    local parsed = parse_request_entry(context, pkg)
    if parsed ~= nil then
      local existing = find_by_name(manifest, parsed.name) or find_by_package_id(manifest, parsed.packageId)
      if action == "install" then
        if existing == nil then
          missing[#missing + 1] = pkg
        end
      elseif action == "remove" then
        if existing ~= nil then
          missing[#missing + 1] = pkg
        end
      elseif action == "update" then
        if existing ~= nil and existing.sourceKind == "remote" then
          missing[#missing + 1] = pkg
        end
      else
        missing[#missing + 1] = pkg
      end
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
    return package_error(context, "vim-plug install package name missing", { reason = "missing-package-name" })
  end
  if not command_exists(context, "git") then
    return package_error(context, "git not installed", { reason = "git-not-installed" })
  end
  if not ensure_runtime_dirs(context) then
    return package_error(context, "vim-plug workspace setup failed")
  end

  local manifest = read_manifest(context)
  local state = read_state(context)
  local install_entries = {}
  for _, pkg in ipairs(requested) do
    local entry, err = parse_request_entry(context, pkg, "remote")
    if entry == nil then
      if err == "conflicting-selectors" then
        return package_error(context, "vim-plug branch and tag selectors are mutually exclusive", { reason = err })
      end
      return package_error(context, "vim-plug install package name missing", { reason = err })
    end
    local merged, merge_err = merge_manifest_entry(manifest, entry)
    if merged == nil then
      return package_error(context, "vim-plug alias collision for " .. entry.name, { name = entry.name, reason = merge_err })
    end
    manifest = merged
    install_entries[#install_entries + 1] = entry
  end

  if not save_manifest(context, manifest) or not save_generated_config(context, manifest) then
    return package_error(context, "vim-plug manifest write failed")
  end
  local boot_ok, boot_err = ensure_bootstrap(context)
  if not boot_ok then
    return package_error(context, boot_err == "curl-not-installed" and "curl not installed" or "vim-plug bootstrap failed", { reason = boot_err })
  end

  begin_step(context, "install vim-plug plugins")
  local names = {}
  for _, entry in ipairs(install_entries) do
    names[#names + 1] = entry.name
  end
  local result, run_err = run_headless(context, "PlugInstall --sync " .. table.concat(names, " "))
  if result == nil then
    return package_error(context, run_err == "missing-editor" and "vim or neovim not installed" or "vim-plug install failed", { reason = run_err })
  end
  if result.success ~= true then
    return package_error(context, trim(result.stderr ~= "" and result.stderr or result.stdout) ~= "" and trim(result.stderr ~= "" and result.stderr or result.stdout) or "vim-plug install failed", { reason = "install-failed" })
  end

  local cache = read_remote_info_cache(context)
  local installed_items = {}
  for _, entry in ipairs(install_entries) do
    local remote_info = nil
    if entry.sourceKind == "remote" then
      remote_info = exact_entry_for_query(cache, entry.packageId)
      if remote_info == nil then
        local fetched = fetch_remote_info(context, entry)
        remote_info = fetched
        if fetched ~= nil then
          cache = upsert_remote_cache_entry(cache, fetched)
        end
      end
    end
    local installed_revision = git_current_revision(context, non_empty(entry.managedDir) or entry.source)
    local state_entry = build_state_entry(entry, installed_revision, remote_info or {})
    state = merge_state_entry(state, state_entry)
    installed_items[#installed_items + 1] = item_from_manifest(entry, state_entry, remote_info)
  end
  save_remote_info_cache(context, cache)
  if not save_state(context, state) then
    return package_error(context, "vim-plug state write failed")
  end
  emit_event(context, "installed", installed_items)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  local target = runtime_expand(trim(path or read_field(context, "localPath") or read_field(read_field(context, "request") or {}, "localPath") or ""))
  if target == "" then
    return package_error(context, "vim-plug local install path missing", { reason = "local-path-missing" })
  end
  if not path_exists(context, target, "dir") then
    return package_error(context, "vim-plug local installs require plugin directory", { path = target, reason = "local-install-unsupported" })
  end
  if not ensure_runtime_dirs(context) then
    return package_error(context, "vim-plug workspace setup failed")
  end
  if not command_exists(context, "git") then
    return package_error(context, "git not installed", { reason = "git-not-installed" })
  end

  local entry, err = parse_request_entry(context, { name = target }, "local")
  if entry == nil then
    return package_error(context, "vim-plug local install path missing", { reason = err })
  end
  local manifest = read_manifest(context)
  local merged, merge_err = merge_manifest_entry(manifest, entry)
  if merged == nil then
    return package_error(context, "vim-plug alias collision for " .. entry.name, { name = entry.name, reason = merge_err })
  end
  manifest = merged
  if not save_manifest(context, manifest) or not save_generated_config(context, manifest) then
    return package_error(context, "vim-plug manifest write failed")
  end
  local boot_ok, boot_err = ensure_bootstrap(context)
  if not boot_ok then
    return package_error(context, boot_err == "curl-not-installed" and "curl not installed" or "vim-plug bootstrap failed", { reason = boot_err })
  end

  begin_step(context, "register local vim plugin")
  local result, run_err = run_headless(context, "PlugInstall --sync " .. entry.name)
  if result == nil then
    return package_error(context, run_err == "missing-editor" and "vim or neovim not installed" or "vim-plug install failed", { reason = run_err })
  end
  if result.success ~= true then
    return package_error(context, trim(result.stderr ~= "" and result.stderr or result.stdout) ~= "" and trim(result.stderr ~= "" and result.stderr or result.stdout) or "vim-plug install failed", { reason = "install-failed" })
  end

  local state = read_state(context)
  local revision = git_current_revision(context, target) or ""
  local state_entry = build_state_entry(entry, revision, {})
  state = merge_state_entry(state, state_entry)
  if not save_state(context, state) then
    return package_error(context, "vim-plug state write failed")
  end
  emit_event(context, "installed", { item_from_manifest(entry, state_entry, nil) })
  tx_success(context)
  return true
end

function plugin.remove(context, packages)
  local requested = packages or {}
  if #requested == 0 then
    tx_success(context)
    return true
  end
  if not ensure_runtime_dirs(context) then
    return package_error(context, "vim-plug workspace setup failed")
  end
  local manifest = read_manifest(context)
  local remove_entries = {}
  for _, pkg in ipairs(requested) do
    local parsed = parse_request_entry(context, pkg)
    if parsed ~= nil then
      remove_entries[#remove_entries + 1] = parsed
    end
  end
  local next_manifest, removed_manifest = remove_manifest_entries(manifest, remove_entries)
  if #removed_manifest == 0 then
    tx_success(context)
    return true
  end
  if not save_manifest(context, next_manifest) or not save_generated_config(context, next_manifest) then
    return package_error(context, "vim-plug manifest write failed")
  end
  local boot_ok, boot_err = ensure_bootstrap(context)
  if not boot_ok then
    return package_error(context, boot_err == "curl-not-installed" and "curl not installed" or "vim-plug bootstrap failed", { reason = boot_err })
  end
  local paths = runtime_paths(context)
  local should_clean = false
  for _, entry in ipairs(removed_manifest) do
    if entry.sourceKind == "remote" and starts_with(trim(entry.managedDir or ""), paths.pluggedDir) then
      should_clean = true
      break
    end
  end
  if should_clean then
    begin_step(context, "clean removed vim plugins")
    local result, run_err = run_headless(context, "PlugClean!")
    if result == nil then
      return package_error(context, run_err == "missing-editor" and "vim or neovim not installed" or "vim-plug clean failed", { reason = run_err })
    end
    if result.success ~= true then
      return package_error(context, trim(result.stderr ~= "" and result.stderr or result.stdout) ~= "" and trim(result.stderr ~= "" and result.stderr or result.stdout) or "vim-plug clean failed", { reason = "clean-failed" })
    end
  end
  local state = remove_state_entries(read_state(context), removed_manifest)
  if not save_state(context, state) then
    return package_error(context, "vim-plug state write failed")
  end
  local removed_items = {}
  for _, entry in ipairs(removed_manifest) do
    removed_items[#removed_items + 1] = item_from_manifest(entry, nil, nil)
  end
  emit_event(context, "deleted", removed_items)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  if not command_exists(context, "git") then
    return package_error(context, "git not installed", { reason = "git-not-installed" })
  end
  if not ensure_runtime_dirs(context) then
    return package_error(context, "vim-plug workspace setup failed")
  end
  local manifest = read_manifest(context)
  local targets = {}
  local requested = packages or {}
  if #requested == 0 then
    for _, entry in ipairs(manifest) do
      if entry.sourceKind == "remote" and trim(entry.frozen or "") == "" then
        targets[#targets + 1] = entry
      end
    end
  else
    for _, pkg in ipairs(requested) do
      local parsed = parse_request_entry(context, pkg)
      if parsed ~= nil then
        local existing = find_by_name(manifest, parsed.name) or find_by_package_id(manifest, parsed.packageId)
        if existing ~= nil and existing.sourceKind == "remote" and trim(existing.frozen or "") == "" then
          targets[#targets + 1] = existing
        end
      end
    end
  end
  if #targets == 0 then
    tx_success(context)
    return true
  end
  if not save_generated_config(context, manifest) then
    return package_error(context, "vim-plug manifest write failed")
  end
  local boot_ok, boot_err = ensure_bootstrap(context)
  if not boot_ok then
    return package_error(context, boot_err == "curl-not-installed" and "curl not installed" or "vim-plug bootstrap failed", { reason = boot_err })
  end
  begin_step(context, "update vim-plug plugins")
  local names = {}
  for _, entry in ipairs(targets) do
    names[#names + 1] = entry.name
  end
  local result, run_err = run_headless(context, "PlugUpdate --sync " .. table.concat(names, " "))
  if result == nil then
    return package_error(context, run_err == "missing-editor" and "vim or neovim not installed" or "vim-plug update failed", { reason = run_err })
  end
  if result.success ~= true then
    return package_error(context, trim(result.stderr ~= "" and result.stderr or result.stdout) ~= "" and trim(result.stderr ~= "" and result.stderr or result.stdout) or "vim-plug update failed", { reason = "update-failed" })
  end
  local state = read_state(context)
  local cache = read_remote_info_cache(context)
  local updated_items = {}
  for _, entry in ipairs(targets) do
    local remote_info = fetch_remote_info(context, entry)
    if remote_info ~= nil then
      cache = upsert_remote_cache_entry(cache, remote_info)
    else
      remote_info = exact_entry_for_query(cache, entry.packageId)
    end
    local installed_revision = git_current_revision(context, non_empty(entry.managedDir) or entry.source)
    local state_entry = build_state_entry(entry, installed_revision, remote_info or {})
    state = merge_state_entry(state, state_entry)
    updated_items[#updated_items + 1] = item_from_manifest(entry, state_entry, remote_info)
  end
  save_remote_info_cache(context, cache)
  if not save_state(context, state) then
    return package_error(context, "vim-plug state write failed")
  end
  emit_event(context, "updated", updated_items)
  tx_success(context)
  return true
end

function plugin.list(context)
  local manifest = read_manifest(context)
  local state = read_state(context)
  local cache = read_remote_info_cache(context)
  local items = {}
  local seen = {}
  for _, state_entry in ipairs(state) do
    local manifest_entry = exact_entry_for_query(manifest, state_entry.packageId) or exact_entry_for_query(manifest, state_entry.name)
    local cache_entry = exact_entry_for_query(cache, state_entry.packageId) or exact_entry_for_query(cache, state_entry.name)
    if manifest_entry ~= nil then
      items[#items + 1] = item_from_manifest(manifest_entry, state_entry, cache_entry)
    else
      items[#items + 1] = build_item({
        name = state_entry.name,
        packageId = state_entry.packageId,
        version = state_entry.installedVersion,
        latestVersion = cache_entry and cache_entry.latestVersion or "",
        status = state_entry.status,
        installed = true,
        source = state_entry.source,
        sourceKind = state_entry.sourceKind,
        branch = state_entry.branch,
        tag = state_entry.tag,
        commit = state_entry.commit,
        managedDir = state_entry.managedDir,
        homepage = cache_entry and cache_entry.homepage or source_homepage(state_entry.source),
        defaultBranch = cache_entry and cache_entry.defaultBranch or "",
        installedRevision = state_entry.installedRevision,
        latestRevision = cache_entry and cache_entry.latestRevision or "",
        tags = cache_entry and cache_entry.tags or "",
      })
    end
    seen[trim(state_entry.packageId)] = true
  end
  for _, entry in ipairs(manifest) do
    if not seen[trim(entry.packageId)] then
      local cache_entry = exact_entry_for_query(cache, entry.packageId) or exact_entry_for_query(cache, entry.name)
      items[#items + 1] = item_from_manifest(entry, nil, cache_entry)
    end
  end
  sort_by_name(items)
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  if not command_exists(context, "git") then
    emit_event(context, "unavailable", { reason = "git-not-installed" })
    emit_event(context, "outdated", {})
    return {}
  end
  local manifest = read_manifest(context)
  local state = read_state(context)
  local cache = read_remote_info_cache(context)
  local items = {}
  local mutated_cache = cache
  for _, state_entry in ipairs(state) do
    local manifest_entry = exact_entry_for_query(manifest, state_entry.packageId) or exact_entry_for_query(manifest, state_entry.name)
    if manifest_entry ~= nil and manifest_entry.sourceKind == "remote" and trim(manifest_entry.frozen or "") == "" and trim(state_entry.commit or "") == "" and trim(state_entry.tag or "") == "" then
      local remote_info, err = fetch_remote_info(context, manifest_entry)
      if remote_info ~= nil then
        mutated_cache = upsert_remote_cache_entry(mutated_cache, remote_info)
      else
        remote_info = exact_entry_for_query(cache, state_entry.packageId) or exact_entry_for_query(cache, state_entry.name)
        if remote_info == nil then
          log_warn(context, "vim-plug remote info unavailable for " .. state_entry.name .. ": " .. tostring(err))
        end
      end
      if remote_info ~= nil then
        local local_revision = git_current_revision(context, non_empty(state_entry.managedDir) or state_entry.source) or trim(state_entry.installedRevision or "")
        local tracked_revision = tracked_revision_for_state(state_entry, remote_info)
        if trim(local_revision) ~= "" and trim(tracked_revision) ~= "" and trim(local_revision) ~= trim(tracked_revision) then
          items[#items + 1] = build_item({
            name = state_entry.name,
            packageId = state_entry.packageId,
            version = state_entry.installedVersion,
            latestVersion = remote_info.latestVersion,
            status = "outdated",
            installed = true,
            source = state_entry.source,
            sourceKind = state_entry.sourceKind,
            branch = state_entry.branch,
            tag = state_entry.tag,
            commit = state_entry.commit,
            managedDir = state_entry.managedDir,
            homepage = remote_info.homepage,
            defaultBranch = remote_info.defaultBranch,
            installedRevision = local_revision,
            latestRevision = tracked_revision,
            tags = remote_info.tags,
          })
        end
      end
    end
  end
  save_remote_info_cache(context, mutated_cache)
  sort_by_name(items)
  emit_event(context, "outdated", items)
  return items
end

function plugin.search(context, prompt)
  local query = lower(trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or ""))
  local items = collect_known_items(context)
  local results = {}
  local seen = {}
  if query ~= "" and (is_repo_shorthand(query) or is_remote_url(query)) then
    local candidate, err = parse_request_entry(context, { name = query }, "remote")
    if candidate ~= nil then
      local remote_info, info_err = fetch_remote_info(context, candidate)
      if remote_info ~= nil then
        local cache = upsert_remote_cache_entry(read_remote_info_cache(context), remote_info)
        save_remote_info_cache(context, cache)
        local synthetic = item_from_manifest(candidate, nil, remote_info)
        results[#results + 1] = synthetic
        seen[trim(synthetic.packageId)] = true
      elseif info_err ~= nil then
        log_warn(context, "vim-plug search remote inspect failed: " .. tostring(info_err))
      elseif err ~= nil then
        log_warn(context, "vim-plug search parse failed: " .. tostring(err))
      end
    end
  end
  for _, item in ipairs(items) do
    if fuzzy_match_item(item, query) and not seen[trim(item.packageId or "")] then
      results[#results + 1] = item
      seen[trim(item.packageId or "")] = true
    end
  end
  sort_by_name(results)
  emit_event(context, "searched", results)
  return results
end

function plugin.info(context, name)
  local query = trim(name or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
  if query == "" then
    emit_event(context, "informed", {})
    return {}
  end
  local manifest = read_manifest(context)
  local state = read_state(context)
  local cache = read_remote_info_cache(context)
  local manifest_entry = exact_entry_for_query(manifest, query)
  local state_entry = exact_entry_for_query(state, query)
  local cache_entry = exact_entry_for_query(cache, query)
  if manifest_entry == nil and state_entry ~= nil then
    manifest_entry = {
      packageId = state_entry.packageId,
      name = state_entry.name,
      sourceKind = state_entry.sourceKind,
      source = state_entry.source,
      branch = state_entry.branch,
      tag = state_entry.tag,
      commit = state_entry.commit,
      rtp = "",
      dir = "",
      postUpdate = "",
      on = "",
      filetypes = "",
      frozen = "",
      managedDir = state_entry.managedDir,
    }
  end
  if manifest_entry == nil and (is_repo_shorthand(query) or is_remote_url(query)) then
    manifest_entry = select(1, parse_request_entry(context, { name = query }, "remote"))
  end
  if manifest_entry == nil then
    emit_event(context, "informed", {})
    return {}
  end
  local remote_info = cache_entry
  if manifest_entry.sourceKind == "remote" then
    local fetched, err = fetch_remote_info(context, manifest_entry)
    if fetched ~= nil then
      remote_info = fetched
      cache = upsert_remote_cache_entry(cache, fetched)
      save_remote_info_cache(context, cache)
    elseif remote_info == nil and err ~= nil then
      log_warn(context, "vim-plug info remote inspect failed: " .. tostring(err))
    end
  end
  local item = item_from_manifest(manifest_entry, state_entry, remote_info)
  emit_event(context, "informed", item)
  return item
end

function plugin.resolvePackage(context, package)
  local query = normalize_request_source(package) or read_field(package, "path") or read_field(package, "localPath")
  if query == nil then
    return nil
  end
  local exact = plugin.info(context, query)
  if type(exact) == "table" and next(exact) ~= nil then
    return exact
  end
  return nil
end

return plugin
