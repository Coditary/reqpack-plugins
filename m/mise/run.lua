plugin = {}

local PLUGIN_ID = "mise"
local PLUGIN_NAME = "Mise"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "mise"
local PACKAGE_TYPE = "mise-tool"
local JSON_NULL = {}
local normalize_flags

plugin.fileExtensions = { ".toml", ".tool-versions" }

local function trim(value)
  return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
  return tostring(value or ""):lower()
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
  local lines = {}
  for line in tostring(value or ""):gmatch("[^\r\n]+") do
    local text = trim(line)
    if text ~= "" then
      lines[#lines + 1] = text
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
  return reqpack.exec.run(command)
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

local function ensure_available(context, fatal)
  if command_exists(context, REQUIRED_BINARY) then
    return true
  end

  local message = "mise command not available"
  if fatal then
    tx_failed(context, message)
    emit_event(context, "unavailable", { reason = "mise-not-installed" })
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
  if text == "" then
    return ""
  end
  local fixture_root = non_empty(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT")) or ""
  if fixture_root ~= "" then
    text = text:gsub("%${fixtureRoot}", fixture_root)
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

local function object_flags(value)
  local raw = read_field(value, "flags")
  if type(raw) ~= "table" and type(raw) ~= "userdata" then
    return {}
  end
  local flags = {}
  local ok = pcall(function()
    for _, item in ipairs(raw) do
      flags[#flags + 1] = runtime_expand(trim(item))
    end
  end)
  if not ok then
    return {}
  end
  return flags
end

local function context_flag_value(context, prefix)
  for _, flag in ipairs(object_flags(context)) do
    local text = trim(flag)
    if text:sub(1, #prefix) == prefix then
      return trim(text:sub(#prefix + 1))
    end
  end
  return ""
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

local function request_flags(context)
  local flags = object_flags(context)
  if #flags > 0 then
    return flags
  end
  local request = read_field(context, "request") or {}
  local value = read_field(request, "flags")
  if value ~= nil then
    return normalize_flags(value)
  end
  return {}
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

local function reqpack_root(kind, context)
  local override = nil
  if kind == "data" then
    override = context_flag_value(context, "data-root=")
  elseif kind == "cache" then
    override = context_flag_value(context, "cache-root=")
  else
    override = context_flag_value(context, "config-root=")
  end
  if trim(override or "") == "" then
    local flags = request_flags(context)
    if kind == "data" then
      override = flag_value(flags, "data-root")
    elseif kind == "cache" then
      override = flag_value(flags, "cache-root")
    else
      override = flag_value(flags, "config-root")
    end
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

local function mise_roots(context)
  local data_root = join_path(reqpack_root("data", context), PLUGIN_ID)
  local cache_root = join_path(reqpack_root("cache", context), PLUGIN_ID)
  local config_root = join_path(reqpack_root("config", context), PLUGIN_ID)
  return {
    dataRoot = data_root,
    cacheRoot = cache_root,
    configRoot = config_root,
    miseDataDir = join_path(data_root, "data"),
    miseStateDir = join_path(data_root, "state"),
    miseCacheDir = join_path(cache_root, "cache"),
    miseConfigDir = join_path(config_root, "config"),
    miseGlobalConfigFile = join_path(config_root, "config", "config.toml"),
  }
end

local function env_prefix(context)
  local roots = mise_roots(context)
  return table.concat({
    "NO_COLOR=1",
    "LC_ALL=C",
    "LANG=C",
    "LANGUAGE=C",
    "MISE_DATA_DIR=" .. shell_quote(roots.miseDataDir),
    "MISE_CACHE_DIR=" .. shell_quote(roots.miseCacheDir),
    "MISE_CONFIG_DIR=" .. shell_quote(roots.miseConfigDir),
    "MISE_STATE_DIR=" .. shell_quote(roots.miseStateDir),
    "MISE_GLOBAL_CONFIG_FILE=" .. shell_quote(roots.miseGlobalConfigFile),
  }, " ")
end

local function with_env(context, command)
  return env_prefix(context) .. " " .. command
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

normalize_flags = function(flags)
  local result = {}
  if type(flags) == "table" then
    for _, flag in ipairs(flags) do
      local text = trim(flag)
      if text ~= "" then
        result[#result + 1] = text
      end
    end
  elseif type(flags) == "string" then
    local text = trim(flags)
    if text ~= "" then
      result[#result + 1] = text
    end
  end
  return result
end

local function add_package_flags(parts, package)
  for _, flag in ipairs(object_flags(package)) do
    local key, value = flag:match("^([^=]+)=(.+)$")
    if flag == "force" then
      parts[#parts + 1] = "--force"
    elseif key == "jobs" then
      parts[#parts + 1] = "--jobs"
      parts[#parts + 1] = shell_quote(value)
    elseif flag == "raw" then
      parts[#parts + 1] = "--raw"
    elseif flag == "system" then
      parts[#parts + 1] = "--system"
    elseif key == "minimum-release-age" then
      parts[#parts + 1] = "--minimum-release-age"
      parts[#parts + 1] = shell_quote(value)
    end
  end
end

local function split_package_name(raw)
  local value = trim(raw)
  local tool, version = value:match("^([^@]+)@(.+)$")
  if tool ~= nil then
    return trim(tool), trim(version)
  end
  return value, nil
end

local function package_name(package)
  local explicit = trim(read_field(package, "name") or "")
  local parsed_name, parsed_version = split_package_name(explicit)
  local version = non_empty(read_field(package, "version")) or parsed_version
  return parsed_name, version
end

local function package_target(package)
  local name, version = package_name(package)
  if name == "" then
    return nil, nil, nil
  end
  if version ~= nil then
    return name .. "@" .. version, name, version
  end
  return name, name, nil
end

local function join_command(parts)
  return table.concat(parts, " ")
end

local function append_arg(parts, value)
  parts[#parts + 1] = shell_quote(value)
end

local function registry_index_by_name(items)
  local index = {}
  for _, item in ipairs(items or {}) do
    if type(item) == "table" then
      local short = non_empty(json_value(read_field(item, "short")))
      if short ~= nil then
        index[lower(short)] = item
      end
    end
  end
  return index
end

local function join_list(values)
  local parts = {}
  for _, value in ipairs(values or {}) do
    if non_empty(value) ~= nil then
      parts[#parts + 1] = trim(value)
    end
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts, ",")
end

local function parse_registry_items(stdout)
  local decoded, error_message = decode_json(stdout)
  if decoded == nil then
    return nil, error_message
  end
  if type(decoded) ~= "table" then
    return {}, nil
  end

  local items = {}
  for _, record in ipairs(decoded) do
    if type(record) == "table" then
      local backends = json_value(read_field(record, "backends"))
      local aliases = json_value(read_field(record, "aliases"))
      items[#items + 1] = {
        name = non_empty(json_value(read_field(record, "short"))),
        packageId = non_empty(json_value(read_field(record, "short"))),
        packageType = PACKAGE_TYPE,
        type = "package",
        installed = false,
        status = "available",
        summary = non_empty(json_value(read_field(record, "description"))) or (type(backends) == "table" and backends[1] or nil),
        description = non_empty(json_value(read_field(record, "description"))),
        extraFields = {
          backends = type(backends) == "table" and join_list(backends) or nil,
          aliases = type(aliases) == "table" and join_list(aliases) or nil,
        },
      }
    end
  end
  return items, nil
end

local function sort_items(items)
  table.sort(items, function(left, right)
    return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "")
  end)
end

local function parse_installed_items(stdout)
  local decoded, error_message = decode_json(stdout)
  if decoded == nil then
    return nil, error_message
  end
  if type(decoded) ~= "table" then
    return {}, nil
  end

  local items = {}
  for tool_name, versions in pairs(decoded) do
    if type(versions) == "table" then
      for _, entry in ipairs(versions) do
        if type(entry) == "table" then
          local version = non_empty(json_value(read_field(entry, "version")))
          if version ~= nil then
            local source = json_value(read_field(entry, "source"))
            local extra = {
              installPath = non_empty(json_value(read_field(entry, "install_path"))),
              requestedVersion = non_empty(json_value(read_field(entry, "requested_version"))),
              active = tostring(json_value(read_field(entry, "active")) == true),
            }
            if type(source) == "table" then
              extra.sourceType = non_empty(json_value(read_field(source, "type")))
              extra.sourcePath = non_empty(json_value(read_field(source, "path")))
            end
            items[#items + 1] = {
              name = tostring(tool_name),
              packageId = tostring(tool_name) .. "@" .. version,
              version = version,
              packageType = PACKAGE_TYPE,
              type = "package",
              installed = true,
              status = "installed",
              summary = "Installed mise tool version",
              description = "Installed mise tool version",
              extraFields = extra,
            }
          end
        end
      end
    end
  end
  sort_items(items)
  return items, nil
end

local function parse_outdated_items(stdout)
  local decoded, error_message = decode_json(stdout)
  if decoded == nil then
    return nil, error_message
  end
  if type(decoded) ~= "table" then
    return {}, nil
  end

  local items = {}
  for tool_name, entry in pairs(decoded) do
    if type(entry) == "table" then
      local current = non_empty(json_value(read_field(entry, "current")))
      local latest = non_empty(json_value(read_field(entry, "latest")))
      if latest ~= nil then
        local source = json_value(read_field(entry, "source"))
        local extra = {
          requestedVersion = non_empty(json_value(read_field(entry, "requested"))),
        }
        if type(source) == "table" then
          extra.sourceType = non_empty(json_value(read_field(source, "type")))
          extra.sourcePath = non_empty(json_value(read_field(source, "path")))
        end
        items[#items + 1] = {
          name = tostring(tool_name),
          packageId = current ~= nil and (tostring(tool_name) .. "@" .. current) or tostring(tool_name),
          version = current,
          latestVersion = latest,
          packageType = PACKAGE_TYPE,
          type = "package",
          installed = true,
          status = "outdated",
          summary = "Outdated mise tool version",
          description = "Outdated mise tool version",
          extraFields = extra,
        }
      end
    end
  end
  sort_items(items)
  return items, nil
end

local function parse_ls_remote_versions(stdout)
  local decoded, error_message = decode_json(stdout)
  if decoded == nil then
    return nil, error_message
  end
  if type(decoded) ~= "table" then
    return {}, nil
  end

  local versions = {}
  for _, entry in ipairs(decoded) do
    if type(entry) == "table" then
      local version = non_empty(json_value(read_field(entry, "version")))
      if version ~= nil then
        versions[#versions + 1] = {
          version = version,
          createdAt = non_empty(json_value(read_field(entry, "created_at"))),
          prerelease = json_value(read_field(entry, "prerelease")) == true,
        }
      end
    elseif non_empty(entry) ~= nil then
      versions[#versions + 1] = { version = trim(entry), prerelease = false }
    end
  end
  return versions, nil
end

local function installed_index(items)
  local index = {}
  for _, item in ipairs(items or {}) do
    local name = lower(item.name or "")
    if index[name] == nil then
      index[name] = {}
    end
    index[name][lower(item.version or "")] = item
  end
  return index
end

local function package_action(pkg)
  return lower(read_field(pkg, "action") or "install")
end

local function query_registry_items(context)
  local result = exec_run(context, with_env(context, "mise registry --json"))
  if result == nil or not result.success then
    return nil, (result and (result.stderr ~= "" and result.stderr or result.stdout)) or "mise registry failed"
  end
  return parse_registry_items(result.stdout)
end

local function query_list_items(context)
  local result = exec_run(context, with_env(context, "mise ls --installed --json"))
  if result == nil or not result.success then
    return nil, (result and (result.stderr ~= "" and result.stderr or result.stdout)) or "mise ls failed"
  end
  return parse_installed_items(result.stdout)
end

local function query_outdated_items(context)
  local result = exec_run(context, with_env(context, "mise outdated --json --inactive"))
  if result == nil or not result.success then
    return nil, (result and (result.stderr ~= "" and result.stderr or result.stdout)) or "mise outdated failed"
  end
  return parse_outdated_items(result.stdout)
end

local function query_remote_versions(context, tool, version)
  local target = trim(tool)
  if version ~= nil and version ~= "" then
    target = target .. "@" .. trim(version)
  end
  local result = exec_run(context, with_env(context, "mise ls-remote " .. shell_quote(target) .. " --json"))
  if result == nil or not result.success then
    return nil, (result and (result.stderr ~= "" and result.stderr or result.stdout)) or "mise ls-remote failed"
  end
  return parse_ls_remote_versions(result.stdout)
end

local function enrich_with_registry(item, registry_record)
  if item == nil or registry_record == nil then
    return item
  end
  item.summary = non_empty(json_value(read_field(registry_record, "description"))) or item.summary
  item.description = non_empty(json_value(read_field(registry_record, "description"))) or item.description
  local extra = shallow_copy(item.extraFields)
  local backends = json_value(read_field(registry_record, "backends"))
  local aliases = json_value(read_field(registry_record, "aliases"))
  if type(backends) == "table" then
    extra.backends = join_list(backends)
  end
  if type(aliases) == "table" then
    extra.aliases = join_list(aliases)
  end
  item.extraFields = extra
  return item
end

local function find_installed_item(items, tool, version)
  for _, item in ipairs(items or {}) do
    if lower(item.name or "") == lower(tool) then
      if version == nil or lower(item.version or "") == lower(version) then
        return item
      end
    end
  end
  return nil
end

local function search_match(item, prompt)
  local needle = lower(trim(prompt))
  if needle == "" then
    return false
  end
  local extra = item.extraFields or {}
  local haystacks = {
    item.name,
    item.packageId,
    item.summary,
    item.description,
    extra.backends,
    extra.aliases,
  }
  for _, value in ipairs(haystacks) do
    if lower(value or ""):find(needle, 1, true) ~= nil then
      return true
    end
  end
  return false
end

local function make_requested_item(package)
  local target, tool, version = package_target(package)
  if target == nil then
    return nil
  end
  return {
    name = tool,
    packageId = version ~= nil and (tool .. "@" .. version) or tool,
    version = version,
    packageType = PACKAGE_TYPE,
    type = "package",
  }
end

local function latest_remote_version(versions)
  if type(versions) == "table" and #versions > 0 then
    return versions[1]
  end
  return nil
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
  return { "Development", "Package Manager", "Version Manager" }
end

function plugin.getMissingPackages(packages)
  if packages == nil or #packages == 0 then
    return {}
  end
  if not ensure_available(nil, false) then
    return packages
  end

  local items = select(1, query_list_items(nil))
  if items == nil then
    return packages
  end

  local installed = installed_index(items)
  local outdated_lookup = nil
  local wants_update = false
  for _, package in ipairs(packages) do
    if package_action(package) == "update" then
      wants_update = true
      break
    end
  end

  if wants_update then
    outdated_lookup = {}
    for _, item in ipairs(plugin.outdated(nil) or {}) do
      local tool = lower(item.name or "")
      local version = lower(item.version or "")
      if outdated_lookup[tool] == nil then
        outdated_lookup[tool] = {}
      end
      outdated_lookup[tool][version] = item
    end
  end

  local missing = {}
  for _, package in ipairs(packages) do
    local action = package_action(package)
    local _, tool, version = package_target(package)
    if tool ~= nil then
      local installed_versions = installed[lower(tool)] or {}
      local installed_exact = version ~= nil and installed_versions[lower(version)] ~= nil or false
      local has_any = next(installed_versions) ~= nil

      if action == "remove" then
        if version ~= nil then
          if installed_exact then
            missing[#missing + 1] = package
          end
        elseif has_any then
          missing[#missing + 1] = package
        end
      elseif action == "update" then
        local outdated_versions = outdated_lookup ~= nil and outdated_lookup[lower(tool)] or nil
        if version ~= nil then
          if outdated_versions ~= nil and outdated_versions[lower(version)] ~= nil then
            missing[#missing + 1] = package
          end
        elseif outdated_versions ~= nil and next(outdated_versions) ~= nil then
          missing[#missing + 1] = package
        end
      elseif not installed_exact and not (version == nil and has_any) then
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
    local target = package_target(package)
    if target == nil then
      return package_error(context, "mise install package name missing")
    end

    begin_step(context, "install mise tool")
    local parts = { "mise", "install" }
    add_package_flags(parts, package)
    append_arg(parts, target)

    local result = exec_run(context, with_env(context, join_command(parts)))
    if result == nil or not result.success then
      return package_error(context, "mise install failed")
    end

    installed[#installed + 1] = make_requested_item(package)
  end

  emit_event(context, "installed", installed)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  local local_path = trim(path)
  return package_error(context, "mise local installs are not supported", {
    path = local_path,
    reason = "local-install-unsupported",
  })
end

function plugin.remove(context, packages)
  if not ensure_available(context, true) then
    return false
  end
  if packages == nil or #packages == 0 then
    return true
  end

  local installed_items, error_message = query_list_items(context)
  if installed_items == nil then
    return package_error(context, error_message or "mise list failed before remove")
  end

  local removed = {}
  for _, package in ipairs(packages) do
    local _, tool, version = package_target(package)
    if tool == nil then
      return package_error(context, "mise remove package name missing")
    end

    local targets = {}
    if version ~= nil then
      targets[#targets + 1] = tool .. "@" .. version
    else
      for _, item in ipairs(installed_items) do
        if lower(item.name or "") == lower(tool) and non_empty(item.version) ~= nil then
          targets[#targets + 1] = tool .. "@" .. item.version
        end
      end
    end

    for _, target in ipairs(targets) do
      begin_step(context, "remove mise tool")
      local result = exec_run(context, with_env(context, "mise uninstall " .. shell_quote(target)))
      if result == nil or not result.success then
        return package_error(context, "mise uninstall failed")
      end
      removed[#removed + 1] = {
        name = tool,
        packageId = target,
        version = target:match("@(.+)$"),
        packageType = PACKAGE_TYPE,
        type = "package",
      }
    end
  end

  emit_event(context, "deleted", removed)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  if not ensure_available(context, true) then
    return false
  end

  local outdated_items, error_message = query_outdated_items(context)
  if outdated_items == nil then
    return package_error(context, error_message or "mise outdated failed")
  end

  local targets = {}
  if packages == nil or #packages == 0 then
    for _, item in ipairs(outdated_items) do
      if non_empty(item.latestVersion) ~= nil then
        targets[#targets + 1] = {
          name = item.name,
          packageId = item.name .. "@" .. item.latestVersion,
          version = item.latestVersion,
          packageType = PACKAGE_TYPE,
          type = "package",
        }
      end
    end
  else
    for _, package in ipairs(packages) do
      local _, tool, version = package_target(package)
      if tool == nil then
        return package_error(context, "mise update package name missing")
      end
      for _, item in ipairs(outdated_items) do
        if lower(item.name or "") == lower(tool) then
          if version == nil or lower(item.version or "") == lower(version) then
            targets[#targets + 1] = {
              name = tool,
              packageId = tool .. "@" .. item.latestVersion,
              version = item.latestVersion,
              packageType = PACKAGE_TYPE,
              type = "package",
            }
          end
        end
      end
    end
  end

  if #targets == 0 then
    emit_event(context, "updated", {})
    tx_success(context)
    return true
  end

  for _, item in ipairs(targets) do
    begin_step(context, "update mise tool")
    local result = exec_run(context, with_env(context, "mise install " .. shell_quote(item.packageId)))
    if result == nil or not result.success then
      return package_error(context, "mise update failed")
    end
  end

  emit_event(context, "updated", targets)
  tx_success(context)
  return true
end

function plugin.list(context)
  if not ensure_available(context, false) then
    emit_event(context, "listed", {})
    return {}
  end

  local items, error_message = query_list_items(context)
  if items == nil then
    log_warn(context, error_message)
    items = {}
  end

  local registry_items = select(1, query_registry_items(context)) or {}
  local registry = registry_index_by_name(registry_items)
  for _, item in ipairs(items) do
    enrich_with_registry(item, registry[lower(item.name)])
  end

  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  if not ensure_available(context, false) then
    emit_event(context, "outdated", {})
    return {}
  end

  local items, error_message = query_outdated_items(context)
  if items == nil then
    log_warn(context, error_message)
    items = {}
  end

  local registry_items = select(1, query_registry_items(context)) or {}
  local registry = registry_index_by_name(registry_items)
  for _, item in ipairs(items) do
    enrich_with_registry(item, registry[lower(item.name)])
  end

  emit_event(context, "outdated", items)
  return items
end

function plugin.search(context, prompt)
  if not ensure_available(context, false) then
    emit_event(context, "searched", {})
    return {}
  end
  if trim(prompt) == "" then
    emit_event(context, "searched", {})
    return {}
  end

  local items, error_message = query_registry_items(context)
  if items == nil then
    log_warn(context, error_message)
    items = {}
  end

  local filtered = {}
  for _, item in ipairs(items) do
    if search_match(item, prompt) then
      filtered[#filtered + 1] = item
    end
  end
  sort_items(filtered)

  emit_event(context, "searched", filtered)
  return filtered
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

  local tool, requested_version = split_package_name(target)
  local installed_items = plugin.list(context)
  local installed_item = find_installed_item(installed_items, tool, requested_version)

  local registry_items = select(1, query_registry_items(context)) or {}
  local registry = registry_index_by_name(registry_items)
  local registry_record = registry[lower(tool)]

  if installed_item ~= nil then
    enrich_with_registry(installed_item, registry_record)
    emit_event(context, "informed", installed_item)
    return installed_item
  end

  local remote_versions = select(1, query_remote_versions(context, tool, requested_version)) or {}
  local latest = latest_remote_version(remote_versions)
  if latest ~= nil then
    local item = {
      name = tool,
      packageId = tool,
      version = requested_version,
      latestVersion = latest.version,
      packageType = PACKAGE_TYPE,
      type = "package",
      installed = false,
      status = "available",
      summary = "Available mise tool",
      description = "Available mise tool",
      extraFields = {
        requestedVersion = requested_version,
        latestCreatedAt = latest.createdAt,
        prerelease = tostring(latest.prerelease == true),
      },
    }
    enrich_with_registry(item, registry_record)
    emit_event(context, "informed", item)
    return item
  end

  if registry_record ~= nil then
    local item = {
      name = tool,
      packageId = tool,
      packageType = PACKAGE_TYPE,
      type = "package",
      installed = false,
      status = "available",
      summary = non_empty(json_value(read_field(registry_record, "description"))) or "Available mise tool",
      description = non_empty(json_value(read_field(registry_record, "description"))) or "Available mise tool",
      extraFields = {},
    }
    enrich_with_registry(item, registry_record)
    emit_event(context, "informed", item)
    return item
  end

  emit_event(context, "informed", {})
  return {}
end

function plugin.resolvePackage(context, package)
  if package == nil then
    return nil
  end

  local target, tool, version = package_target(package)
  if target == nil then
    return nil
  end

  local info = plugin.info(context, target)
  if type(info) == "table" and next(info) ~= nil then
    return info
  end

  return {
    name = tool,
    packageId = version ~= nil and (tool .. "@" .. version) or tool,
    version = version,
    packageType = PACKAGE_TYPE,
    type = "package",
  }
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "exec", "network" },
    ecosystemScopes = { "mise" },
    writeScopes = {
      { kind = "user-home-subpath", value = ".local/share/reqpack/mise" },
      { kind = "user-home-subpath", value = ".cache/reqpack/mise" },
      { kind = "user-home-subpath", value = ".config/reqpack/mise" },
    },
    privilegeLevel = "user",
    purlType = "generic",
  }
end

function plugin.init()
  return command_exists(nil, REQUIRED_BINARY)
end

function plugin.shutdown()
  return true
end

return plugin
