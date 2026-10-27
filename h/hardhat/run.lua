plugin = {}

local PLUGIN_ID = "hardhat"
local PLUGIN_NAME = "Hardhat"
local PLUGIN_VERSION = "0.1.0"
local PACKAGE_TYPE = "node-tool"
local PACKAGE_NAME = "hardhat"
local HOMEPAGE_URL = "https://hardhat.org"
local REGISTRY_URL = "https://registry.npmjs.org/hardhat"
local JSON_NULL = {}

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

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function join_path(...)
  local parts = {}
  for index = 1, select("#", ...) do
    local part = trim(select(index, ...) or "")
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

local function shallow_copy(value)
  local copy = {}
  for key, item in pairs(value or {}) do
    copy[key] = item
  end
  return copy
end

local function merge_tables(left, right)
  local merged = shallow_copy(type(left) == "table" and left or {})
  for key, value in pairs(type(right) == "table" and right or {}) do
    if value ~= nil and value ~= JSON_NULL then
      merged[key] = value
    end
  end
  if next(merged) == nil then
    return nil
  end
  return merged
end

local function starts_with(value, prefix)
  local text = tostring(value or "")
  local expected = tostring(prefix or "")
  return expected == "" or text:sub(1, #expected) == expected
end

local function ends_with(value, suffix)
  local text = tostring(value or "")
  local expected = tostring(suffix or "")
  return expected == "" or text:sub(-#expected) == expected
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
      stderr = "reqpack.exec.run unavailable",
      exitCode = 127,
    }
  end
  return normalize_run_result(first, second, third, fourth, fifth)
end

local function command_exists(context, binary)
  local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
  return result ~= nil and result.success == true
end

local function read_proc_environ_value(name)
  if os ~= nil and type(os.getenv) == "function" then
    local current = os.getenv(tostring(name or ""))
    if current ~= nil and current ~= "" then
      return trim(current)
    end
  end
  if reqpack ~= nil and reqpack.host ~= nil and type(reqpack.host.env) == "table" then
    local current = reqpack.host.env[name]
    if current ~= nil and current ~= "" then
      return trim(current)
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

local function runtime_expand(value)
  local text = trim(value)
  if text == "" then
    return ""
  end
  local fixture_root = non_empty(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT")) or ""
  if fixture_root ~= "" then
    text = text:gsub("%${fixtureRoot}", fixture_root)
  end
  return text
end

local function normalize_flags(flags)
  local result = {}
  if type(flags) == "table" or type(flags) == "userdata" then
    local ok = pcall(function()
      for _, flag in ipairs(flags) do
        local text = trim(runtime_expand(flag))
        if text ~= "" then
          result[#result + 1] = text
        end
      end
    end)
    if ok then
      return result
    end
  elseif type(flags) == "string" then
    local text = trim(runtime_expand(flags))
    if text ~= "" then
      result[#result + 1] = text
    end
  end
  return result
end

local function object_flags(value)
  local raw = read_field(value, "flags")
  if type(raw) ~= "table" and type(raw) ~= "userdata" then
    return {}
  end
  return normalize_flags(raw)
end

local function request_flags(context)
  local direct = object_flags(context)
  if #direct > 0 then
    return direct
  end
  local request = read_field(context, "request") or {}
  return normalize_flags(read_field(request, "flags"))
end

local function flag_value(flags, prefix)
  local wanted = prefix .. "="
  for _, flag in ipairs(flags or {}) do
    if flag:sub(1, #wanted) == wanted then
      return trim(flag:sub(#wanted + 1))
    end
  end
  return nil
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

local function reqpack_root(kind, context)
  local flags = request_flags(context)
  local override = nil
  if kind == "data" then
    override = flag_value(flags, "data-root")
  elseif kind == "cache" then
    override = flag_value(flags, "cache-root")
  else
    override = flag_value(flags, "config-root")
  end
  if type(override) == "string" and trim(override) ~= "" then
    return trim(override)
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

local function hardhat_roots(context)
  local data_root = join_path(reqpack_root("data", context), PLUGIN_ID)
  local cache_root = join_path(reqpack_root("cache", context), PLUGIN_ID)
  local config_root = join_path(reqpack_root("config", context), PLUGIN_ID)
  return {
    dataRoot = data_root,
    cacheRoot = cache_root,
    configRoot = config_root,
    installsDir = join_path(data_root, "installs"),
    binDir = join_path(data_root, "bin"),
    recordsDir = join_path(data_root, "records"),
    homeDir = join_path(data_root, "home"),
    registryDir = join_path(cache_root, "registry"),
    tarballsDir = join_path(cache_root, "tarballs"),
    npmCacheDir = join_path(cache_root, "npm-cache"),
    stagingDir = join_path(cache_root, "staging"),
    xdgCacheDir = join_path(cache_root, "xdg-cache"),
    xdgConfigDir = join_path(config_root, "xdg-config"),
    xdgDataDir = join_path(data_root, "xdg-data"),
  }
end

local function env_prefix(context)
  local roots = hardhat_roots(context)
  return table.concat({
    "NO_COLOR=1",
    "LC_ALL=C",
    "LANG=C",
    "LANGUAGE=C",
    "HOME=" .. shell_quote(roots.homeDir),
    "XDG_CACHE_HOME=" .. shell_quote(roots.xdgCacheDir),
    "XDG_CONFIG_HOME=" .. shell_quote(roots.xdgConfigDir),
    "XDG_DATA_HOME=" .. shell_quote(roots.xdgDataDir),
    "NPM_CONFIG_CACHE=" .. shell_quote(roots.npmCacheDir),
    "NPM_CONFIG_UPDATE_NOTIFIER=false",
    "NPM_CONFIG_FUND=false",
    "NPM_CONFIG_AUDIT=false",
    "NPM_CONFIG_PROGRESS=false",
    "NPM_CONFIG_LOGLEVEL=error",
  }, " ")
end

local function with_env(context, command)
  return env_prefix(context) .. " " .. command
end

local function ensure_directory(context, path)
  local result = exec_run(context, "mkdir -p " .. shell_quote(path))
  return result ~= nil and result.success == true
end

local function ensure_runtime_dirs(context)
  local roots = hardhat_roots(context)
  for _, path in ipairs({
    roots.installsDir,
    roots.binDir,
    roots.recordsDir,
    roots.homeDir,
    roots.registryDir,
    roots.tarballsDir,
    roots.npmCacheDir,
    roots.stagingDir,
    roots.xdgCacheDir,
    roots.xdgConfigDir,
    roots.xdgDataDir,
  }) do
    if not ensure_directory(context, path) then
      return false
    end
  end
  return true
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

local function write_text_file(context, path, content)
  local dir = tostring(path or ""):match("^(.*)/[^/]+$") or "."
  local command = "mkdir -p " .. shell_quote(dir) .. " && printf %s " .. shell_quote(content) .. " > " .. shell_quote(path)
  local result = exec_run(context, command)
  return result ~= nil and result.success == true
end

local function path_exists(context, path)
  local handle = io.open(path, "rb")
  if handle ~= nil then
    handle:close()
    return true
  end
  local result = exec_run(context, "test -e " .. shell_quote(path))
  return result ~= nil and result.success == true
end

local function list_dir(context, path)
  local result = exec_run(context, "ls -1A " .. shell_quote(path))
  if result == nil or result.success ~= true then
    return {}
  end
  local items = {}
  for _, line in ipairs(split_lines(result.stdout)) do
    local text = trim(line)
    if text ~= "" then
      items[#items + 1] = text
    end
  end
  table.sort(items)
  return items
end

local function safe_id(value)
  local text = lower(trim(value)):gsub("[^a-z0-9]+", "_")
  text = text:gsub("_+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if text == "" then
    return PLUGIN_ID
  end
  return text
end

local function codepoint_to_utf8(codepoint)
  if codepoint <= 0x7F then
    return string.char(codepoint)
  end
  if codepoint <= 0x7FF then
    return string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + (codepoint % 0x40))
  end
  if codepoint <= 0xFFFF then
    return string.char(
      0xE0 + math.floor(codepoint / 0x1000),
      0x80 + (math.floor(codepoint / 0x40) % 0x40),
      0x80 + (codepoint % 0x40)
    )
  end
  return string.char(
    0xF0 + math.floor(codepoint / 0x40000),
    0x80 + (math.floor(codepoint / 0x1000) % 0x40),
    0x80 + (math.floor(codepoint / 0x40) % 0x40),
    0x80 + (codepoint % 0x40)
  )
end

local function decode_json_internal(raw)
  local text = tostring(raw or "")
  local length = #text
  local index = 1

  local function decode_error(message)
    error(message .. " at byte " .. tostring(index), 0)
  end

  local function peek()
    return text:sub(index, index)
  end

  local function skip_whitespace()
    while index <= length do
      local byte = text:byte(index)
      if byte == 32 or byte == 9 or byte == 10 or byte == 13 then
        index = index + 1
      else
        break
      end
    end
  end

  local parse_value

  local function parse_string()
    index = index + 1
    local parts = {}
    local segment_start = index
    while index <= length do
      local current = text:sub(index, index)
      if current == '"' then
        parts[#parts + 1] = text:sub(segment_start, index - 1)
        index = index + 1
        return table.concat(parts)
      end
      if current == "\\" then
        parts[#parts + 1] = text:sub(segment_start, index - 1)
        index = index + 1
        if index > length then
          decode_error("unterminated escape sequence")
        end
        local escape = text:sub(index, index)
        if escape == '"' or escape == "\\" or escape == "/" then
          parts[#parts + 1] = escape
          index = index + 1
        elseif escape == "b" then
          parts[#parts + 1] = "\b"
          index = index + 1
        elseif escape == "f" then
          parts[#parts + 1] = "\f"
          index = index + 1
        elseif escape == "n" then
          parts[#parts + 1] = "\n"
          index = index + 1
        elseif escape == "r" then
          parts[#parts + 1] = "\r"
          index = index + 1
        elseif escape == "t" then
          parts[#parts + 1] = "\t"
          index = index + 1
        elseif escape == "u" then
          local hex = text:sub(index + 1, index + 4)
          if #hex ~= 4 or hex:match("^[0-9a-fA-F]+$") == nil then
            decode_error("invalid unicode escape")
          end
          parts[#parts + 1] = codepoint_to_utf8(tonumber(hex, 16))
          index = index + 5
        else
          decode_error("unsupported escape sequence")
        end
        segment_start = index
      else
        local byte = text:byte(index)
        if byte ~= nil and byte < 32 then
          decode_error("control character in string")
        end
        index = index + 1
      end
    end
    decode_error("unterminated string")
  end

  local function parse_number()
    local start_index = index
    local current = peek()
    if current == "-" then
      index = index + 1
      current = peek()
    end
    if current == "0" then
      index = index + 1
    elseif current:match("%d") ~= nil then
      repeat
        index = index + 1
        current = peek()
      until current == "" or current:match("%d") == nil
    else
      decode_error("invalid number")
    end
    current = peek()
    if current == "." then
      index = index + 1
      if peek():match("%d") == nil then
        decode_error("invalid number fraction")
      end
      repeat
        index = index + 1
      until peek():match("%d") == nil
    end
    current = peek()
    if current == "e" or current == "E" then
      index = index + 1
      current = peek()
      if current == "+" or current == "-" then
        index = index + 1
      end
      if peek():match("%d") == nil then
        decode_error("invalid number exponent")
      end
      repeat
        index = index + 1
      until peek():match("%d") == nil
    end
    return tonumber(text:sub(start_index, index - 1))
  end

  local function parse_array()
    index = index + 1
    skip_whitespace()
    local result = {}
    if peek() == "]" then
      index = index + 1
      return result
    end
    while true do
      result[#result + 1] = parse_value()
      skip_whitespace()
      local current = peek()
      if current == "," then
        index = index + 1
        skip_whitespace()
      elseif current == "]" then
        index = index + 1
        return result
      else
        decode_error("expected ',' or ']' in array")
      end
    end
  end

  local function parse_object()
    index = index + 1
    skip_whitespace()
    local result = {}
    if peek() == "}" then
      index = index + 1
      return result
    end
    while true do
      if peek() ~= '"' then
        decode_error("expected object key")
      end
      local key = parse_string()
      skip_whitespace()
      if peek() ~= ":" then
        decode_error("expected key separator")
      end
      index = index + 1
      skip_whitespace()
      local value = parse_value()
      if value == nil then
        result[key] = JSON_NULL
      else
        result[key] = value
      end
      skip_whitespace()
      local current = peek()
      if current == "," then
        index = index + 1
        skip_whitespace()
      elseif current == "}" then
        index = index + 1
        return result
      else
        decode_error("expected ',' or '}' in object")
      end
    end
  end

  function parse_value()
    skip_whitespace()
    local current = peek()
    if current == '"' then
      return parse_string()
    end
    if current == "{" then
      return parse_object()
    end
    if current == "[" then
      return parse_array()
    end
    if current == "-" or current:match("%d") ~= nil then
      return parse_number()
    end
    if text:sub(index, index + 3) == "true" then
      index = index + 4
      return true
    end
    if text:sub(index, index + 4) == "false" then
      index = index + 5
      return false
    end
    if text:sub(index, index + 3) == "null" then
      index = index + 4
      return nil
    end
    decode_error("unexpected token")
  end

  local value = parse_value()
  skip_whitespace()
  if index <= length then
    decode_error("trailing content")
  end
  return value
end

local function decode_json(raw)
  local ok, value = pcall(decode_json_internal, raw)
  if not ok then
    return nil, value
  end
  return value, nil
end

local function sort_items(items)
  table.sort(items, function(left, right)
    local left_key = lower(trim(left.packageId or left.name or ""))
    local right_key = lower(trim(right.packageId or right.name or ""))
    return left_key < right_key
  end)
end

local function record_path_for_version(context, version)
  return join_path(hardhat_roots(context).recordsDir, safe_id(PACKAGE_NAME .. "_" .. version) .. ".tsv")
end

local function install_path_for_version(context, version)
  return join_path(hardhat_roots(context).installsDir, version)
end

local function launcher_path_for_version(context, version)
  return join_path(hardhat_roots(context).binDir, PACKAGE_NAME .. "-" .. version)
end

local function tarball_path_for_version(context, version)
  return join_path(hardhat_roots(context).tarballsDir, PACKAGE_NAME .. "-" .. version .. ".tgz")
end

local function registry_cache_path(context)
  return join_path(hardhat_roots(context).registryDir, PACKAGE_NAME .. ".json")
end

local function encode_record(record)
  local keys = {
    "id", "name", "version", "installPath", "launcherPath", "recordPath", "tarballPath",
    "cacheRoot", "npmCacheDir", "homepage", "sourceUrl", "summary", "description", "sourceKind", "updatedAt"
  }
  local lines = {}
  for _, key in ipairs(keys) do
    if record[key] ~= nil then
      lines[#lines + 1] = key .. "\t" .. tostring(record[key])
    end
  end
  return table.concat(lines, "\n") .. "\n"
end

local function decode_record(content)
  local record = {}
  for _, line in ipairs(split_lines(content)) do
    local key, value = line:match("^([^\t]+)\t(.*)$")
    if key ~= nil then
      record[key] = value
    end
  end
  return record
end

local function write_record(record)
  return write_text_file(nil, record.recordPath, encode_record(record))
end

local function read_record(context, path)
  local content = read_text_file(context, path)
  if content == nil then
    return nil
  end
  return decode_record(content)
end

local function load_records(context)
  local records = {}
  for _, entry in ipairs(list_dir(context, hardhat_roots(context).recordsDir)) do
    if ends_with(entry, ".tsv") then
      local path = join_path(hardhat_roots(context).recordsDir, entry)
      local record = read_record(context, path)
      if record ~= nil and trim(record.version or "") ~= "" then
        records[#records + 1] = record
      end
    end
  end
  table.sort(records, function(left, right)
    return lower(trim(left.version or "")) < lower(trim(right.version or ""))
  end)
  return records
end

local function find_record_by_version(context, version)
  local wanted = trim(version)
  for _, record in ipairs(load_records(context)) do
    if trim(record.version) == wanted then
      return record
    end
  end
  return nil
end

local function remove_path(context, path)
  local result = exec_run(context, "rm -rf " .. shell_quote(path))
  return result ~= nil and result.success == true
end

local function parse_requested_package(package)
  local raw_name = trim(read_field(package, "name") or read_field(package, "packageId") or "")
  local explicit_version = trim(read_field(package, "version") or "")
  local name = raw_name
  local parsed_version = ""
  local split_name, split_version = raw_name:match("^([^@]+)@(.+)$")
  if split_name ~= nil and split_version ~= nil then
    name = trim(split_name)
    parsed_version = trim(split_version)
  end
  if lower(name) ~= PACKAGE_NAME then
    return nil, nil
  end
  return PACKAGE_NAME, non_empty(explicit_version) or non_empty(parsed_version)
end

local function package_summary(version)
  return "Hardhat CLI runtime " .. tostring(version or "")
end

local function package_description(version)
  return "Isolated Hardhat CLI runtime install version " .. tostring(version or "")
end

local function latest_version(metadata)
  local dist_tags = type(metadata) == "table" and read_field(metadata, "dist-tags") or nil
  return non_empty(read_field(dist_tags, "latest"))
end

local function metadata_version_payload(metadata, version)
  local versions = type(metadata) == "table" and read_field(metadata, "versions") or nil
  if type(versions) ~= "table" then
    return nil
  end
  local payload = read_field(versions, version)
  if type(payload) == "table" then
    return payload
  end
  return nil
end

local function metadata_package_item(metadata, version)
  local payload = metadata_version_payload(metadata, version)
  local latest = latest_version(metadata)
  if payload == nil then
    return nil
  end
  local repository = read_field(payload, "repository")
  local repository_url = repository
  if type(repository) == "table" then
    repository_url = read_field(repository, "url") or read_field(repository, "web")
  end
  return {
    name = PACKAGE_NAME,
    packageId = PACKAGE_NAME .. "@" .. trim(version),
    version = trim(read_field(payload, "version") or version),
    latestVersion = latest,
    packageType = PACKAGE_TYPE,
    homepage = non_empty(read_field(payload, "homepage")) or HOMEPAGE_URL,
    sourceUrl = non_empty(repository_url),
    summary = non_empty(read_field(payload, "description")) or package_summary(version),
    description = non_empty(read_field(payload, "description")) or package_description(version),
    license = non_empty(read_field(payload, "license")),
    extraFields = merge_tables(nil, {
      distTagLatest = latest,
      tarballUrl = read_field(read_field(payload, "dist") or {}, "tarball"),
      sourceKind = "registry",
    }),
  }
end

local function fetch_registry_metadata(context)
  if not ensure_runtime_dirs(context) then
    return nil, "hardhat runtime directory setup failed"
  end
  local target = registry_cache_path(context)
  local result = exec_run(context, "curl -fsSL " .. shell_quote(REGISTRY_URL) .. " -o " .. shell_quote(target))
  if result == nil or result.success ~= true then
    return nil, "hardhat registry metadata fetch failed"
  end
  local raw = read_text_file(context, target)
  if raw == nil or trim(raw) == "" then
    raw = result.stdout
  end
  if raw == nil or trim(raw) == "" then
    return nil, "hardhat registry metadata missing"
  end
  local decoded, decode_error = decode_json(raw)
  if decoded == nil then
    return nil, decode_error or "hardhat registry metadata parse failed"
  end
  return decoded, nil
end

local function record_to_item(record, latest)
  local item = {
    name = PACKAGE_NAME,
    packageId = record.id,
    version = trim(record.version),
    latestVersion = latest,
    installed = true,
    status = latest ~= nil and trim(latest) ~= trim(record.version) and "outdated" or "installed",
    type = "package",
    packageType = PACKAGE_TYPE,
    homepage = non_empty(record.homepage) or HOMEPAGE_URL,
    sourceUrl = non_empty(record.sourceUrl),
    summary = non_empty(record.summary) or package_summary(record.version),
    description = non_empty(record.description) or package_description(record.version),
    extraFields = merge_tables(nil, {
      launcherPath = record.launcherPath,
      installPath = record.installPath,
      recordPath = record.recordPath,
      tarballPath = record.tarballPath,
      cacheRoot = record.cacheRoot,
      npmCacheDir = record.npmCacheDir,
      sourceKind = record.sourceKind,
      distTagLatest = latest,
    }),
  }
  return item
end

local function read_installed_package_json(context, install_path)
  local raw = read_text_file(context, join_path(install_path, "node_modules", PACKAGE_NAME, "package.json"))
  if raw == nil then
    return nil, "installed hardhat package.json missing"
  end
  return decode_json(raw)
end

local function write_launcher(context, launcher_path, install_path)
  local script = "#!/bin/sh\nexec " .. shell_quote(join_path(install_path, "node_modules", ".bin", PACKAGE_NAME)) .. " \"$@\"\n"
  if not write_text_file(context, launcher_path, script) then
    return false
  end
  local result = exec_run(context, "chmod +x " .. shell_quote(launcher_path))
  return result ~= nil and result.success == true
end

local function now_timestamp()
  if non_empty(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT")) ~= nil then
    return "0"
  end
  if os ~= nil and type(os.time) == "function" then
    return tostring(os.time())
  end
  return "0"
end

local function install_source(context, source_path, source_kind, tarball_path, metadata_item)
  local requested_version = metadata_item.version
  local install_path = install_path_for_version(context, requested_version)
  local roots = hardhat_roots(context)

  remove_path(context, install_path)
  if not ensure_directory(context, install_path) then
    return nil, "hardhat install directory setup failed"
  end

  local command = with_env(
    context,
    "npm install --prefix " .. shell_quote(install_path) .. " --no-save --no-package-lock " .. shell_quote(source_path)
  )
  local result = exec_run(context, command)
  if result == nil or result.success ~= true then
    return nil, "hardhat npm install failed"
  end

  local package_json, decode_error = read_installed_package_json(context, install_path)
  if package_json == nil then
    return nil, decode_error or "hardhat installed package metadata missing"
  end
  local installed_version = non_empty(read_field(package_json, "version"))
  if installed_version == nil then
    return nil, "hardhat installed version missing"
  end

  local launcher_path = launcher_path_for_version(context, installed_version)

  if not write_launcher(context, launcher_path, install_path) then
    return nil, "hardhat launcher write failed"
  end

  local record = {
    id = PACKAGE_NAME .. "@" .. installed_version,
    name = PACKAGE_NAME,
    version = installed_version,
    installPath = install_path,
    launcherPath = launcher_path,
    recordPath = record_path_for_version(context, installed_version),
    tarballPath = tarball_path,
    cacheRoot = roots.cacheRoot,
    npmCacheDir = roots.npmCacheDir,
    homepage = metadata_item.homepage or HOMEPAGE_URL,
    sourceUrl = metadata_item.sourceUrl,
    summary = metadata_item.summary or package_summary(installed_version),
    description = metadata_item.description or package_description(installed_version),
    sourceKind = source_kind,
    updatedAt = now_timestamp(),
  }
  if not write_record(record) then
    return nil, "hardhat record write failed"
  end
  return record_to_item(record, metadata_item.latestVersion), nil
end

local function install_remote_version(context, requested_version)
  local metadata, error_message = fetch_registry_metadata(context)
  if metadata == nil then
    return nil, error_message
  end
  local version = non_empty(requested_version) or latest_version(metadata)
  if version == nil then
    return nil, "hardhat latest version unavailable"
  end
  local item = metadata_package_item(metadata, version)
  if item == nil then
    return nil, "hardhat version not found in registry metadata"
  end
  local tarball_url = non_empty(item.extraFields and item.extraFields.tarballUrl)
  if tarball_url == nil then
    return nil, "hardhat tarball url missing"
  end
  local tarball_path = tarball_path_for_version(context, version)
  local download_result = exec_run(context, "curl -fsSL " .. shell_quote(tarball_url) .. " -o " .. shell_quote(tarball_path))
  if download_result == nil or download_result.success ~= true then
    return nil, "hardhat tarball download failed"
  end
  return install_source(context, tarball_path, "registry", tarball_path, item)
end

local function local_dir_is_supported(path)
  return path_exists(nil, join_path(path, "package.json"))
end

local function local_item_metadata(path)
  local package_json_path = join_path(path, "package.json")
  local raw = read_text_file(nil, package_json_path)
  if raw == nil then
    return nil
  end
  local decoded = decode_json(raw)
  if type(decoded) ~= "table" then
    return nil
  end
  if lower(trim(read_field(decoded, "name") or "")) ~= PACKAGE_NAME then
    return nil
  end
  local version = non_empty(read_field(decoded, "version")) or "local"
  return {
    name = PACKAGE_NAME,
    packageId = PACKAGE_NAME .. "@" .. version,
    version = version,
    latestVersion = nil,
    packageType = PACKAGE_TYPE,
    homepage = non_empty(read_field(decoded, "homepage")) or HOMEPAGE_URL,
    sourceUrl = nil,
    summary = non_empty(read_field(decoded, "description")) or package_summary(version),
    description = non_empty(read_field(decoded, "description")) or package_description(version),
  }
end

local function install_local_source(context, path)
  local local_path = trim(path)
  if local_path == "" then
    return nil, "hardhat local install path missing"
  end
  if not path_exists(context, local_path) then
    return nil, "hardhat local install path missing"
  end
  if not ensure_runtime_dirs(context) then
    return nil, "hardhat runtime directory setup failed"
  end

  local source_kind = nil
  local metadata_item = nil
  if ends_with(lower(local_path), ".tgz") then
    source_kind = "local-tarball"
    metadata_item = {
      name = PACKAGE_NAME,
      packageId = PACKAGE_NAME .. "@local",
      version = "local",
      latestVersion = nil,
      packageType = PACKAGE_TYPE,
      homepage = HOMEPAGE_URL,
      sourceUrl = nil,
      summary = "Local Hardhat npm tarball",
      description = "Local Hardhat npm tarball install",
    }
  elseif local_dir_is_supported(local_path) then
    source_kind = "local-dir"
    metadata_item = local_item_metadata(local_path) or {
      name = PACKAGE_NAME,
      packageId = PACKAGE_NAME .. "@local",
      version = "local",
      latestVersion = nil,
      packageType = PACKAGE_TYPE,
      homepage = HOMEPAGE_URL,
      sourceUrl = nil,
      summary = "Local Hardhat package directory",
      description = "Local Hardhat package directory install",
    }
  else
    return nil, "unsupported local Hardhat source"
  end

  return install_source(context, local_path, source_kind, source_kind == "local-tarball" and local_path or nil, metadata_item)
end

local function search_versions(metadata, prompt)
  local lowered_prompt = lower(trim(prompt))
  local items = {}
  local versions = read_field(metadata, "versions")
  if type(versions) ~= "table" then
    return items
  end
  local version_keys = {}
  for key, _ in pairs(versions) do
    version_keys[#version_keys + 1] = tostring(key)
  end
  table.sort(version_keys)
  for index = #version_keys, 1, -1 do
    local version = version_keys[index]
    if lowered_prompt == "" or lower(version):find(lowered_prompt, 1, true) ~= nil then
      local item = metadata_package_item(metadata, version)
      if item ~= nil then
        items[#items + 1] = item
      end
    end
    if #items >= 20 then
      break
    end
  end
  return items
end

local function merge_installed_and_remote(installed_item, remote_item)
  if installed_item == nil then
    return remote_item
  end
  if remote_item == nil then
    return installed_item
  end
  installed_item.latestVersion = remote_item.latestVersion or installed_item.latestVersion
  installed_item.homepage = remote_item.homepage or installed_item.homepage
  installed_item.sourceUrl = remote_item.sourceUrl or installed_item.sourceUrl
  installed_item.summary = remote_item.summary or installed_item.summary
  installed_item.description = remote_item.description or installed_item.description
  installed_item.extraFields = merge_tables(installed_item.extraFields, remote_item.extraFields)
  installed_item.status = installed_item.latestVersion ~= nil and trim(installed_item.latestVersion) ~= trim(installed_item.version) and "outdated" or "installed"
  return installed_item
end

local function normalize_missing_args(arg1, arg2)
  if arg2 == nil and type(arg1) == "table" and arg1[1] ~= nil then
    return nil, arg1
  end
  return arg1, arg2 or {}
end

local function requested_action(context)
  return lower(trim(read_field(context, "action") or read_field(read_field(context, "request") or {}, "action") or "install"))
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
  return { "Development", "Solidity", "Ethereum", "Package Manager" }
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "exec", "network" },
    ecosystemScopes = { "hardhat", "solidity", "ethereum", "node", "npm" },
    writeScopes = {
      "user-home-subpath:.local/share/reqpack/hardhat",
      "user-home-subpath:.cache/reqpack/hardhat",
      "user-home-subpath:.config/reqpack/hardhat",
    },
    networkScopes = { "https://registry.npmjs.org" },
    privilegeLevel = "none",
    osvEcosystem = "npm",
    purlType = "npm",
  }
end

function plugin.init()
  return true
end

function plugin.getMissingPackages(arg1, arg2)
  local context, packages = normalize_missing_args(arg1, arg2)
  local action = requested_action(context)
  local missing = {}
  local latest = nil
  if action == "install" or action == "update" then
    latest = latest_version(select(1, fetch_registry_metadata(context)) or {})
  end

  for _, package in ipairs(packages or {}) do
    local name, version = parse_requested_package(package)
    if name == nil then
      missing[#missing + 1] = package
    elseif action == "remove" then
      if version ~= nil then
        if find_record_by_version(context, version) ~= nil then
          missing[#missing + 1] = package
        end
      else
        if #load_records(context) > 0 then
          missing[#missing + 1] = package
        end
      end
    elseif action == "update" then
      if version ~= nil then
        local record = find_record_by_version(context, version)
        if record ~= nil and latest ~= nil and trim(record.version) ~= trim(latest) then
          missing[#missing + 1] = package
        end
      else
        for _, record in ipairs(load_records(context)) do
          if latest ~= nil and trim(record.version) ~= trim(latest) then
            missing[#missing + 1] = package
            break
          end
        end
      end
    else
      local wanted = version or latest
      if wanted == nil or find_record_by_version(context, wanted) == nil then
        missing[#missing + 1] = package
      end
    end
  end

  return missing
end

function plugin.install(context, packages)
  packages = packages or {}
  local local_path = trim(read_field(context, "localPath") or read_field(context, "path") or read_field(read_field(context, "request") or {}, "localPath") or read_field(read_field(context, "request") or {}, "path") or "")
  if local_path ~= "" then
    return plugin.installLocal(context, local_path)
  end
  if not command_exists(context, "npm") or not command_exists(context, "curl") then
    tx_failed(context, "hardhat install requires npm and curl")
    return false
  end
  if #packages == 0 then
    packages = { { name = PACKAGE_NAME } }
  end

  local installed = {}
  for _, package in ipairs(packages) do
    local name, version = parse_requested_package(package)
    if name == nil then
      tx_failed(context, "hardhat install package name invalid")
      return false
    end
    begin_step(context, "install hardhat runtime")
    local item, error_message = install_remote_version(context, version)
    if item == nil then
      tx_failed(context, error_message or "hardhat install failed")
      return false
    end
    installed[#installed + 1] = item
  end

  emit_event(context, "installed", installed)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  path = trim(path or read_field(context, "localPath") or read_field(context, "path") or read_field(read_field(context, "request") or {}, "localPath") or read_field(read_field(context, "request") or {}, "path") or "")
  if not command_exists(context, "npm") then
    tx_failed(context, "hardhat local install requires npm")
    return false
  end
  begin_step(context, "install local hardhat runtime")
  local item, error_message = install_local_source(context, path)
  if item == nil then
    tx_failed(context, error_message or "hardhat local install failed")
    return false
  end
  emit_event(context, "installed", { item })
  tx_success(context)
  return true
end

function plugin.remove(context, packages)
  packages = packages or {}
  local removed = {}
  if #packages == 0 then
    for _, record in ipairs(load_records(context)) do
      begin_step(context, "remove hardhat runtime")
      remove_path(context, record.installPath)
      remove_path(context, record.launcherPath)
      remove_path(context, record.recordPath)
      removed[#removed + 1] = record_to_item(record, nil)
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
  end

  for _, package in ipairs(packages) do
    local name, version = parse_requested_package(package)
    if name ~= nil then
      if version ~= nil then
        local record = find_record_by_version(context, version)
        if record ~= nil then
          begin_step(context, "remove hardhat runtime")
          remove_path(context, record.installPath)
          remove_path(context, record.launcherPath)
          remove_path(context, record.recordPath)
          removed[#removed + 1] = record_to_item(record, nil)
        end
      else
        for _, record in ipairs(load_records(context)) do
          begin_step(context, "remove hardhat runtime")
          remove_path(context, record.installPath)
          remove_path(context, record.launcherPath)
          remove_path(context, record.recordPath)
          removed[#removed + 1] = record_to_item(record, nil)
        end
      end
    end
  end

  emit_event(context, "deleted", removed)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  packages = packages or {}
  if not command_exists(context, "npm") or not command_exists(context, "curl") then
    tx_failed(context, "hardhat update requires npm and curl")
    return false
  end
  local metadata, error_message = fetch_registry_metadata(context)
  if metadata == nil then
    tx_failed(context, error_message or "hardhat metadata fetch failed")
    return false
  end
  local latest = latest_version(metadata)
  if latest == nil then
    tx_failed(context, "hardhat latest version unavailable")
    return false
  end

  local targets = {}
  if #packages == 0 then
    for _, record in ipairs(load_records(context)) do
      if trim(record.version) ~= trim(latest) then
        targets[#targets + 1] = record
      end
    end
  else
    for _, package in ipairs(packages) do
      local _, version = parse_requested_package(package)
      if version ~= nil then
        local record = find_record_by_version(context, version)
        if record ~= nil and trim(record.version) ~= trim(latest) then
          targets[#targets + 1] = record
        end
      else
        for _, record in ipairs(load_records(context)) do
          if trim(record.version) ~= trim(latest) then
            targets[#targets + 1] = record
          end
        end
      end
    end
  end

  if #targets == 0 then
    tx_success(context)
    return true
  end

  begin_step(context, "update hardhat runtime")
  local latest_item = nil
  local existing_latest = find_record_by_version(context, latest)
  if existing_latest ~= nil then
    latest_item = record_to_item(existing_latest, latest)
  else
    latest_item, error_message = install_remote_version(context, latest)
    if latest_item == nil then
      tx_failed(context, error_message or "hardhat update failed")
      return false
    end
  end

  local seen = {}
  local updated = {}
  for _, record in ipairs(targets) do
    if trim(record.version) ~= trim(latest) and not seen[record.version] then
      seen[record.version] = true
      remove_path(context, record.installPath)
      remove_path(context, record.launcherPath)
      remove_path(context, record.recordPath)
      updated[#updated + 1] = latest_item
    end
  end

  emit_event(context, "updated", updated)
  tx_success(context)
  return true
end

function plugin.list(context)
  local latest = latest_version(select(1, fetch_registry_metadata(context)) or {})
  local items = {}
  for _, record in ipairs(load_records(context)) do
    items[#items + 1] = record_to_item(record, latest)
  end
  sort_items(items)
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  local metadata, error_message = fetch_registry_metadata(context)
  if metadata == nil then
    log_warn(context, error_message or "hardhat metadata fetch failed")
    emit_event(context, "outdated", {})
    return {}
  end
  local latest = latest_version(metadata)
  local items = {}
  for _, record in ipairs(load_records(context)) do
    if latest ~= nil and trim(record.version) ~= trim(latest) then
      items[#items + 1] = record_to_item(record, latest)
    end
  end
  sort_items(items)
  emit_event(context, "outdated", items)
  return items
end

function plugin.search(context, prompt)
  local search_prompt = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
  if search_prompt == "" then
    emit_event(context, "searched", {})
    return {}
  end
  local metadata, error_message = fetch_registry_metadata(context)
  if metadata == nil then
    log_warn(context, error_message or "hardhat metadata fetch failed")
    emit_event(context, "searched", {})
    return {}
  end

  local items = {}
  local lowered_prompt = lower(search_prompt)
  if lower(PACKAGE_NAME):find(lowered_prompt, 1, true) ~= nil then
    local latest = latest_version(metadata)
    local latest_item = latest ~= nil and metadata_package_item(metadata, latest) or nil
    if latest_item ~= nil then
      items[#items + 1] = latest_item
    end
  end
  for _, item in ipairs(search_versions(metadata, search_prompt)) do
    local duplicate = false
    for _, existing in ipairs(items) do
      if existing.packageId == item.packageId then
        duplicate = true
        break
      end
    end
    if not duplicate then
      items[#items + 1] = item
    end
  end
  sort_items(items)
  emit_event(context, "searched", items)
  return items
end

function plugin.info(context, name)
  local target = trim(name or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
  if target == "" then
    emit_event(context, "informed", {})
    return {}
  end

  local metadata = select(1, fetch_registry_metadata(context))
  local latest = latest_version(metadata or {})

  local requested_version = nil
  if lower(target) ~= PACKAGE_NAME then
    local _, version = parse_requested_package({ name = target })
    requested_version = version
  end

  if requested_version ~= nil then
    local installed = find_record_by_version(context, requested_version)
    local installed_item = installed ~= nil and record_to_item(installed, latest) or nil
    local remote_item = metadata ~= nil and metadata_package_item(metadata, requested_version) or nil
    local item = merge_installed_and_remote(installed_item, remote_item)
    if item == nil then
      emit_event(context, "informed", {})
      return {}
    end
    emit_event(context, "informed", item)
    return item
  end

  local installed_items = load_records(context)
  local newest_installed = installed_items[#installed_items]
  local installed_item = newest_installed ~= nil and record_to_item(newest_installed, latest) or nil
  local remote_item = latest ~= nil and metadata_package_item(metadata, latest) or nil
  local item = merge_installed_and_remote(installed_item, remote_item)
  if item == nil then
    emit_event(context, "informed", {})
    return {}
  end
  emit_event(context, "informed", item)
  return item
end

function plugin.resolvePackage(context, package)
  local _, version = parse_requested_package(package or {})
  local item = nil
  if version ~= nil then
    item = plugin.info(context, PACKAGE_NAME .. "@" .. version)
  else
    item = plugin.info(context, PACKAGE_NAME)
  end
  if type(item) ~= "table" or trim(read_field(item, "packageId") or "") == "" then
    return nil
  end
  return item
end

function plugin.shutdown()
  return true
end

return plugin
