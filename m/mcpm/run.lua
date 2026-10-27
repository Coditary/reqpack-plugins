plugin = {}

local PLUGIN_ID = "mcpm"
local PLUGIN_NAME = "MCPM"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "mcpm"
local PACKAGE_TYPE = "mcp-server"
local JSON_NULL = {}

local function trim(value)
  return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
  return tostring(value or ""):lower()
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

local function json_value(value)
  if value == JSON_NULL then
    return nil
  end
  return value
end

local function first_nonempty(...)
  for index = 1, select("#", ...) do
    local value = json_value(select(index, ...))
    if value ~= nil then
      if type(value) == "string" then
        local text = trim(value)
        if text ~= "" then
          return text
        end
      else
        return value
      end
    end
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

local function exec_run(context, command)
  if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
    return context.exec.run(command)
  end
  if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
    return reqpack.exec.run(command)
  end
  return {
    success = false,
    stdout = "",
    stderr = "missing ReqPack exec runner",
    exitCode = 127,
  }
end

local function command_exists(context, binary)
  local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
  return result ~= nil and result.success == true
end

local function command_error(context, message, payload)
  tx_failed(context, message)
  if payload ~= nil then
    emit_event(context, "unavailable", payload)
  end
  return false
end

local function ensure_available(context, fatal)
  if command_exists(context, REQUIRED_BINARY) then
    return true
  end
  local message = "mcpm command not available"
  if fatal then
    tx_failed(context, message)
    emit_event(context, "unavailable", { reason = "mcpm-not-installed" })
  else
    log_warn(context, message)
  end
  return false
end

local function starts_with(value, prefix)
  local text = tostring(value or "")
  local expected = tostring(prefix or "")
  return expected == "" or text:sub(1, #expected) == expected
end

local function join_path(...)
  local parts = {}
  for index = 1, select("#", ...) do
    local raw = tostring(select(index, ...) or "")
    if raw ~= "" then
      raw = raw:gsub("/+$", "")
      if #parts > 0 then
        raw = raw:gsub("^/+", "")
      end
      parts[#parts + 1] = raw
    end
  end
  if #parts == 0 then
    return "."
  end
  return table.concat(parts, "/")
end

local function read_proc_environ_value(name)
  if os ~= nil and type(os.getenv) == "function" then
    local current = os.getenv(tostring(name or ""))
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
  local fixture_root = non_empty(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT"))
  if fixture_root ~= nil then
    text = text:gsub("%${fixtureRoot}", fixture_root)
  end
  return text
end

local function object_flags(value)
  local raw = read_field(value, "flags")
  if type(raw) ~= "table" and type(raw) ~= "userdata" then
    return {}
  end
  local flags = {}
  local ok = pcall(function()
    for _, item in ipairs(raw) do
      local text = runtime_expand(item)
      if text ~= "" then
        flags[#flags + 1] = text
      end
    end
  end)
  if not ok then
    return {}
  end
  return flags
end

local function normalize_flags(flags)
  local result = {}
  if type(flags) == "table" then
    for _, flag in ipairs(flags) do
      local text = runtime_expand(flag)
      if text ~= "" then
        result[#result + 1] = text
      end
    end
  elseif type(flags) == "string" then
    local text = runtime_expand(flags)
    if text ~= "" then
      result[#result + 1] = text
    end
  end
  return result
end

local function request_flags(context)
  local flags = object_flags(context)
  if #flags > 0 then
    return flags
  end
  local request = read_field(context, "request") or {}
  return normalize_flags(read_field(request, "flags"))
end

local function flag_value(flags, prefix)
  local wanted = prefix .. "="
  for _, flag in ipairs(flags or {}) do
    if flag == prefix then
      return true
    end
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
  if kind == "data" then
    return non_empty(read_proc_environ_value("XDG_DATA_HOME")) or join_path(non_empty(read_proc_environ_value("HOME")) or "/home/test", ".local", "share")
  end
  if kind == "cache" then
    return non_empty(read_proc_environ_value("XDG_CACHE_HOME")) or join_path(non_empty(read_proc_environ_value("HOME")) or "/home/test", ".cache")
  end
  return non_empty(read_proc_environ_value("XDG_CONFIG_HOME")) or join_path(non_empty(read_proc_environ_value("HOME")) or "/home/test", ".config")
end

local function reqpack_root(kind, context)
  local override = nil
  if kind == "data" then
    override = flag_value(request_flags(context), "data-root")
  elseif kind == "cache" then
    override = flag_value(request_flags(context), "cache-root")
  else
    override = flag_value(request_flags(context), "config-root")
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

local function mcpm_roots(context)
  local data_root = join_path(reqpack_root("data", context), PLUGIN_ID)
  local cache_root = join_path(reqpack_root("cache", context), PLUGIN_ID)
  local config_root = join_path(reqpack_root("config", context), PLUGIN_ID)
  return {
    dataRoot = data_root,
    cacheRoot = cache_root,
    configRoot = config_root,
    mcpmDataDir = join_path(data_root, "data"),
    mcpmCacheDir = join_path(cache_root, "cache"),
    mcpmConfigDir = join_path(config_root, "config"),
  }
end

local function env_prefix(context)
  local roots = mcpm_roots(context)
  return table.concat({
    "NO_COLOR=1",
    "LC_ALL=C",
    "LANG=C",
    "LANGUAGE=C",
    "MCPM_NON_INTERACTIVE=true",
    "MCPM_FORCE=true",
    "MCPM_JSON_OUTPUT=true",
    "MCPM_CONFIG_DIR=" .. shell_quote(roots.mcpmConfigDir),
    "XDG_CACHE_HOME=" .. shell_quote(roots.mcpmCacheDir),
    "XDG_DATA_HOME=" .. shell_quote(roots.mcpmDataDir),
  }, " ")
end

local function with_env(context, command)
  return env_prefix(context) .. " " .. command
end

local function append_arg(parts, value)
  local text = trim(value)
  if text ~= "" then
    parts[#parts + 1] = shell_quote(text)
  end
end

local function join_command(parts)
  return table.concat(parts, " ")
end

local function package_name(package)
  local name = non_empty(read_field(package, "name"))
  if name ~= nil then
    return name
  end
  return non_empty(read_field(package, "packageId"))
end

local function package_action(package)
  return lower(first_nonempty(read_field(package, "action"), "install"))
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
  local parse_value

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
    if peek() == "-" then
      index = index + 1
    end
    local current = peek()
    if current == "0" then
      index = index + 1
    elseif current:match("%d") then
      repeat
        index = index + 1
        current = peek()
      until current == "" or current:match("%d") == nil
    else
      decode_error("invalid number")
    end
    if peek() == "." then
      index = index + 1
      if peek():match("%d") == nil then
        decode_error("invalid fraction")
      end
      repeat
        index = index + 1
        current = peek()
      until current == "" or current:match("%d") == nil
    end
    current = peek()
    if current == "e" or current == "E" then
      index = index + 1
      current = peek()
      if current == "+" or current == "-" then
        index = index + 1
      end
      if peek():match("%d") == nil then
        decode_error("invalid exponent")
      end
      repeat
        index = index + 1
        current = peek()
      until current == "" or current:match("%d") == nil
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
        decode_error("expected string key")
      end
      local key = parse_string()
      skip_whitespace()
      if peek() ~= ":" then
        decode_error("expected ':' after key")
      end
      index = index + 1
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
    elseif current == "{" then
      return parse_object()
    elseif current == "[" then
      return parse_array()
    elseif current == "-" or current:match("%d") then
      return parse_number()
    elseif text:sub(index, index + 3) == "true" then
      index = index + 4
      return true
    elseif text:sub(index, index + 4) == "false" then
      index = index + 5
      return false
    elseif text:sub(index, index + 3) == "null" then
      index = index + 4
      return nil
    end
    decode_error("unexpected token")
  end

  local value = parse_value()
  skip_whitespace()
  if index <= length then
    decode_error("unexpected trailing content")
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

local function is_array(value)
  if type(value) ~= "table" then
    return false
  end
  local count = 0
  for key, _ in pairs(value) do
    if type(key) ~= "number" then
      return false
    end
    count = count + 1
  end
  return count == #value
end

local function is_record_like(value)
  if type(value) ~= "table" then
    return false
  end
  local keys = {
    "name",
    "server_name",
    "serverName",
    "id",
    "description",
    "summary",
    "command",
    "url",
    "type",
    "version",
    "installed",
    "source",
  }
  for _, key in ipairs(keys) do
    if read_field(value, key) ~= nil then
      return true
    end
  end
  return false
end

local function collect_records(value, out, key_hint)
  if value == nil or value == JSON_NULL then
    return
  end
  local value_type = type(value)
  if value_type == "string" then
    out[#out + 1] = { name = value, __key = key_hint }
    return
  end
  if value_type ~= "table" then
    return
  end
  if is_array(value) then
    for _, item in ipairs(value) do
      collect_records(item, out, key_hint)
    end
    return
  end
  if is_record_like(value) then
    value.__key = key_hint
    out[#out + 1] = value
    return
  end

  local preferred = { "servers", "installed", "items", "results", "data", "updates", "outdated", "available" }
  local matched = false
  for _, key in ipairs(preferred) do
    local child = read_field(value, key)
    if child ~= nil then
      matched = true
      collect_records(child, out, key_hint)
    end
  end
  if matched then
    return
  end

  for key, child in pairs(value) do
    if type(child) == "table" then
      collect_records(child, out, tostring(key))
    elseif type(key) == "string" and (type(child) == "string" or type(child) == "boolean") then
      out[#out + 1] = { name = key, status = tostring(child) }
    end
  end
end

local function raw_records(raw)
  local parsed, err = decode_json(raw)
  if parsed == nil then
    return nil, err
  end
  local records = {}
  collect_records(parsed, records, nil)
  return records, nil
end

local function copy_extra(record)
  local extra = {}
  local keys = {
    "source",
    "profiles",
    "clients",
    "command",
    "args",
    "env",
    "url",
    "headers",
    "alias",
    "aliases",
    "transport",
    "registry",
    "package",
    "repository",
    "homepage",
  }
  for _, key in ipairs(keys) do
    local value = json_value(read_field(record, key))
    if value ~= nil then
      extra[key] = value
    end
  end
  local key_hint = json_value(read_field(record, "__key"))
  if key_hint ~= nil then
    extra.key = key_hint
  end
  return extra
end

local function normalize_record(record, defaults)
  defaults = defaults or {}
  if type(record) == "string" then
    record = { name = record }
  end
  if type(record) ~= "table" then
    return nil
  end

  local name = first_nonempty(
    read_field(record, "name"),
    read_field(record, "server_name"),
    read_field(record, "serverName"),
    read_field(record, "id"),
    read_field(record, "package"),
    read_field(record, "title"),
    read_field(record, "__key")
  )
  if name == nil then
    return nil
  end

  local installed = read_field(record, "installed")
  if installed == JSON_NULL or installed == nil then
    installed = defaults.installed
  end

  local version = first_nonempty(
    read_field(record, "version"),
    read_field(record, "current_version"),
    read_field(record, "currentVersion"),
    read_field(record, "installed_version"),
    read_field(record, "installedVersion"),
    read_field(record, "current")
  )
  local latest = first_nonempty(
    read_field(record, "latest_version"),
    read_field(record, "latestVersion"),
    read_field(record, "latest"),
    read_field(record, "target_version"),
    read_field(record, "targetVersion")
  )
  local description = first_nonempty(read_field(record, "summary"), read_field(record, "description"), defaults.description)
  local status = first_nonempty(read_field(record, "status"), defaults.status)
  if status == nil then
    status = installed == true and "installed" or "available"
  end

  return {
    name = name,
    packageId = first_nonempty(read_field(record, "packageId"), read_field(record, "package_id"), name),
    version = version,
    latestVersion = latest,
    packageType = PACKAGE_TYPE,
    type = "package",
    installed = installed,
    status = status,
    summary = description,
    description = description,
    extraFields = copy_extra(record),
  }
end

local function normalize_records(records, defaults)
  local items = {}
  for _, record in ipairs(records or {}) do
    local item = normalize_record(record, defaults)
    if item ~= nil then
      items[#items + 1] = item
    end
  end
  table.sort(items, function(left, right)
    return lower(left.name or "") < lower(right.name or "")
  end)
  return items
end

local function query_items(context, command, defaults)
  local result = exec_run(context, with_env(context, command))
  if result == nil or not result.success then
    return nil, "mcpm query failed"
  end
  local records, err = raw_records(result.stdout or "")
  if records == nil then
    return nil, "mcpm JSON parse failed: " .. tostring(err)
  end
  return normalize_records(records, defaults), nil
end

local function query_list_items(context)
  return query_items(context, "mcpm ls --verbose", {
    installed = true,
    status = "installed",
    description = "Installed MCP server",
  })
end

local function query_outdated_items(context)
  return query_items(context, "mcpm update --check", {
    installed = true,
    status = "outdated",
    description = "Outdated MCP server",
  })
end

local function query_search_items(context, prompt)
  local command = "mcpm search"
  if non_empty(prompt) ~= nil then
    command = command .. " " .. shell_quote(prompt)
  end
  return query_items(context, command, {
    installed = false,
    status = "available",
    description = "Available MCP server",
  })
end

local function query_info_item(context, name)
  local items, err = query_items(context, "mcpm info " .. shell_quote(name), {
    installed = false,
    status = "available",
    description = "MCP server",
  })
  if items == nil then
    return nil, err
  end
  return items[1], nil
end

local function installed_index(items)
  local installed = {}
  for _, item in ipairs(items or {}) do
    installed[lower(item.name or "")] = item
  end
  return installed
end

local function add_install_flags(parts, package)
  local alias = nil
  for _, flag in ipairs(object_flags(package)) do
    if flag == "force" then
      parts[#parts + 1] = "--force"
    else
      local key, value = flag:match("^([^=]+)=(.+)$")
      if key == "alias" then
        alias = value
      end
    end
  end
  if alias ~= nil and trim(alias) ~= "" then
    parts[#parts + 1] = "--alias"
    append_arg(parts, alias)
  end
end

local function add_update_flags(parts, package)
  for _, flag in ipairs(object_flags(package)) do
    if flag == "rebase" then
      parts[#parts + 1] = "--rebase"
    elseif flag == "init" then
      parts[#parts + 1] = "--init"
    elseif flag == "force" then
      parts[#parts + 1] = "--force"
    end
  end
end

local function make_requested_item(package, installed, status)
  local name = package_name(package)
  return {
    name = name,
    packageId = name,
    version = non_empty(read_field(package, "version")),
    packageType = PACKAGE_TYPE,
    type = "package",
    installed = installed,
    status = status,
  }
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
  return { "Development", "Package Manager", "MCP" }
end

function plugin.getMissingPackages(packages)
  if packages == nil or #packages == 0 then
    return {}
  end
  if not ensure_available(nil, false) then
    return packages
  end
  local list_items = select(1, query_list_items(nil))
  if list_items == nil then
    return packages
  end
  local installed = installed_index(list_items)
  local outdated = nil
  for _, package in ipairs(packages) do
    if package_action(package) == "update" then
      outdated = installed_index(select(1, query_outdated_items(nil)) or {})
      break
    end
  end

  local missing = {}
  for _, package in ipairs(packages) do
    local name = package_name(package)
    if name ~= nil then
      local action = package_action(package)
      local has_installed = installed[lower(name)] ~= nil
      if action == "remove" then
        if has_installed then
          missing[#missing + 1] = package
        end
      elseif action == "update" then
        if outdated ~= nil and outdated[lower(name)] ~= nil then
          missing[#missing + 1] = package
        end
      elseif not has_installed then
        missing[#missing + 1] = package
      end
    end
  end
  return missing
end

function plugin.install(context, packages)
  if not ensure_available(context, true) then
    return false
  end
  if packages == nil or #packages == 0 then
    return true
  end

  local installed = {}
  for _, package in ipairs(packages) do
    local name = package_name(package)
    if name == nil then
      return command_error(context, "mcpm install package name missing")
    end
    begin_step(context, "install MCP server")
    local parts = { "mcpm", "install" }
    add_install_flags(parts, package)
    append_arg(parts, name)
    local result = exec_run(context, with_env(context, join_command(parts)))
    if result == nil or not result.success then
      return command_error(context, "mcpm install failed")
    end
    installed[#installed + 1] = make_requested_item(package, true, "installed")
  end

  emit_event(context, "installed", installed)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  if not ensure_available(context, true) then
    return false
  end
  local flags = request_flags(context)
  local name = flag_value(flags, "name")
  if type(name) ~= "string" or trim(name) == "" then
    return command_error(context, "mcpm local install requires name=<server>", {
      path = trim(path),
      reason = "local-install-name-required",
    })
  end

  local server_type = first_nonempty(flag_value(flags, "type"), "stdio")
  local parts = { "mcpm", "new" }
  append_arg(parts, name)
  parts[#parts + 1] = "--type"
  append_arg(parts, server_type)

  if server_type == "remote" then
    local url = first_nonempty(flag_value(flags, "url"), path)
    if url == nil then
      return command_error(context, "mcpm remote install requires url=<url>")
    end
    parts[#parts + 1] = "--url"
    append_arg(parts, url)
    local headers = flag_value(flags, "headers")
    if type(headers) == "string" and trim(headers) ~= "" then
      parts[#parts + 1] = "--headers"
      append_arg(parts, headers)
    end
  else
    local command = first_nonempty(flag_value(flags, "command"), path)
    if command == nil then
      return command_error(context, "mcpm stdio install requires command=<command>")
    end
    parts[#parts + 1] = "--command"
    append_arg(parts, command)
    local args = flag_value(flags, "args")
    if type(args) == "string" and trim(args) ~= "" then
      parts[#parts + 1] = "--args"
      append_arg(parts, args)
    end
    local env = flag_value(flags, "env")
    if type(env) == "string" and trim(env) ~= "" then
      parts[#parts + 1] = "--env"
      append_arg(parts, env)
    end
  end
  if flag_value(flags, "force") == true then
    parts[#parts + 1] = "--force"
  end

  begin_step(context, "create MCP server")
  local result = exec_run(context, with_env(context, join_command(parts)))
  if result == nil or not result.success then
    return command_error(context, "mcpm local install failed")
  end

  emit_event(context, "installed", {
    {
      name = trim(name),
      packageId = trim(name),
      packageType = PACKAGE_TYPE,
      type = "package",
      installed = true,
      status = "installed",
    },
  })
  tx_success(context)
  return true
end

function plugin.remove(context, packages)
  if not ensure_available(context, true) then
    return false
  end
  if packages == nil or #packages == 0 then
    return true
  end

  local removed = {}
  for _, package in ipairs(packages) do
    local name = package_name(package)
    if name == nil then
      return command_error(context, "mcpm remove package name missing")
    end
    begin_step(context, "remove MCP server")
    local result = exec_run(context, with_env(context, "mcpm uninstall " .. shell_quote(name) .. " --force"))
    if result == nil or not result.success then
      return command_error(context, "mcpm uninstall failed")
    end
    removed[#removed + 1] = make_requested_item(package, false, "removed")
  end

  emit_event(context, "deleted", removed)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  if not ensure_available(context, true) then
    return false
  end

  local updated = {}
  if packages == nil or #packages == 0 then
    begin_step(context, "update MCP servers")
    local result = exec_run(context, with_env(context, "mcpm update"))
    if result == nil or not result.success then
      return command_error(context, "mcpm update failed")
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    return true
  end

  for _, package in ipairs(packages) do
    local name = package_name(package)
    if name == nil then
      return command_error(context, "mcpm update package name missing")
    end
    begin_step(context, "update MCP server")
    local parts = { "mcpm", "update" }
    add_update_flags(parts, package)
    append_arg(parts, name)
    local result = exec_run(context, with_env(context, join_command(parts)))
    if result == nil or not result.success then
      return command_error(context, "mcpm update failed")
    end
    updated[#updated + 1] = make_requested_item(package, true, "updated")
  end

  emit_event(context, "updated", updated)
  tx_success(context)
  return true
end

function plugin.list(context)
  if not ensure_available(context, false) then
    emit_event(context, "listed", {})
    return {}
  end
  local items, err = query_list_items(context)
  if items == nil then
    log_warn(context, err)
    items = {}
  end
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  if not ensure_available(context, false) then
    emit_event(context, "outdated", {})
    return {}
  end
  local items, err = query_outdated_items(context)
  if items == nil then
    log_warn(context, err)
    items = {}
  end
  emit_event(context, "outdated", items)
  return items
end

function plugin.search(context, prompt)
  if not ensure_available(context, false) then
    emit_event(context, "searched", {})
    return {}
  end
  local query = trim(prompt)
  if query == "" then
    query = trim(read_field(context, "prompt") or "")
  end
  local items, err = query_search_items(context, query)
  if items == nil then
    log_warn(context, err)
    items = {}
  end
  emit_event(context, "searched", items)
  return items
end

function plugin.info(context, name)
  local target = trim(name)
  if target == "" then
    target = trim(read_field(context, "prompt") or "")
  end
  if target == "" then
    emit_event(context, "informed", {})
    return {}
  end
  if not ensure_available(context, false) then
    emit_event(context, "informed", {})
    return {}
  end

  local item, err = query_info_item(context, target)
  if item == nil then
    log_warn(context, err)
    emit_event(context, "informed", {})
    return {}
  end
  emit_event(context, "informed", item)
  return item
end

function plugin.resolvePackage(context, package)
  if package == nil then
    return nil
  end
  local name = package_name(package)
  if name == nil then
    return nil
  end
  local info = plugin.info(context, name)
  if type(info) == "table" and next(info) ~= nil then
    return info
  end
  return make_requested_item(package, nil, "unknown")
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "exec", "network" },
    ecosystemScopes = { "mcpm", "mcp" },
    writeScopes = {
      { kind = "user-home-subpath", value = ".config/reqpack/mcpm" },
      { kind = "user-home-subpath", value = ".cache/reqpack/mcpm" },
      { kind = "user-home-subpath", value = ".local/share/reqpack/mcpm" },
    },
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

return plugin
