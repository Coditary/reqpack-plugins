plugin = {}

local PLUGIN_ID = "io"
local PLUGIN_NAME = "Io / Eerie"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "eerie"
local DEFAULT_ENV_NAME = "default"
local JSON_NULL = {}

plugin.fileExtensions = { ".io", ".json" }

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

local function first_non_empty(...)
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    if value ~= nil then
      if type(value) == "string" then
        local cleaned = trim(value)
        if cleaned ~= "" then
          return cleaned
        end
      else
        return value
      end
    end
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

local function split_lines(value)
  local lines = {}
  local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
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

local function dirname(path)
  local cleaned = trim(path)
  local parent = cleaned:match("^(.*)[/\\][^/\\]+$")
  if parent == nil or parent == "" then
    return "."
  end
  return parent
end

local function basename(path)
  local cleaned = trim(path)
  local name = cleaned:match("([^/\\]+)$")
  return name or cleaned
end

local function env_raw(name)
  if os ~= nil and type(os.getenv) == "function" then
    local value = os.getenv(name)
    if value ~= nil and value ~= "" then
      return value
    end
  end

  local handle = io.open("/proc/self/environ", "rb")
  if handle ~= nil then
    local payload = handle:read("*a")
    handle:close()
    if payload ~= nil and payload ~= "" then
      local prefix = tostring(name or "") .. "="
      for entry in tostring(payload):gmatch("[^%z]+") do
        if entry:sub(1, #prefix) == prefix then
          return entry:sub(#prefix + 1)
        end
      end
    end
  end
  return nil
end

local function fixture_root()
  return trim(env_raw("REQPACK_TEST_FIXTURE_ROOT") or "")
end

local function expand_placeholders(value)
  local text = tostring(value or "")
  local root = fixture_root()
  if root ~= "" then
    text = text:gsub("%${fixtureRoot}", root)
  end
  return text
end

local function home_dir()
  return first_non_empty(expand_placeholders(env_raw("HOME") or ""), expand_placeholders(env_raw("USERPROFILE") or ""), "/home/test")
end

local function reqpack_path(name)
  local paths = type(reqpack) == "table" and read_field(reqpack, "paths") or nil
  if type(paths) ~= "table" then
    return nil
  end
  return non_empty(read_field(paths, name))
end

local function object_flags(value)
  if type(value) == "table" or type(value) == "userdata" then
    local direct_ok, direct_flags = pcall(function()
      local items = {}
      for _, item in ipairs(value) do
        local cleaned = trim(expand_placeholders(item))
        if cleaned ~= "" then
          items[#items + 1] = cleaned
        end
      end
      return items
    end)
    if direct_ok and #direct_flags > 0 and read_field(value, "flags") == nil then
      return direct_flags
    end
  end
  local raw = read_field(value, "flags")
  if type(raw) ~= "table" and type(raw) ~= "userdata" then
    return {}
  end
  local flags = {}
  local ok = pcall(function()
    for _, item in ipairs(raw) do
      local cleaned = trim(expand_placeholders(item))
      if cleaned ~= "" then
        flags[#flags + 1] = cleaned
      end
    end
  end)
  if not ok then
    return {}
  end
  return flags
end

local function collect_flags(context, package)
  local flags = {}
  local seen = {}
  local function append_from(object)
    for _, flag in ipairs(object_flags(object)) do
      if not seen[flag] then
        seen[flag] = true
        flags[#flags + 1] = flag
      end
    end
  end
  append_from(context)
  append_from(read_field(context, "request"))
  append_from(package)
  return flags
end

local function flag_value(flags, key)
  local prefix = lower(trim(key)) .. "="
  for _, flag in ipairs(flags or {}) do
    local cleaned = trim(flag)
    if lower(cleaned):sub(1, #prefix) == prefix then
      return trim(cleaned:sub(#prefix + 1))
    end
  end
  return nil
end

local function request_flag_value(context, package, key)
  return flag_value(collect_flags(context, package), key)
end

local function reqpack_root(kind, context, package)
  local flags = collect_flags(context, package)
  local explicit = non_empty(flag_value(flags, kind .. "-root"))
  if explicit ~= nil then
    return explicit
  end

  local root = fixture_root()
  if root ~= "" then
    if kind == "data" then
      return join_path(root, ".reqpack-data")
    end
    if kind == "cache" then
      return join_path(root, ".reqpack-cache")
    end
    return join_path(root, ".reqpack-config")
  end

  if kind == "data" then
    return first_non_empty(reqpack_path("dataRoot"), join_path(home_dir(), ".local", "share", "reqpack"))
  end
  if kind == "cache" then
    return first_non_empty(reqpack_path("cacheRoot"), join_path(home_dir(), ".cache", "reqpack"))
  end
  return first_non_empty(reqpack_path("configRoot"), join_path(home_dir(), ".config", "reqpack"))
end

local function runtime_paths(context, package)
  local data_root = join_path(reqpack_root("data", context, package), PLUGIN_ID, "eerie")
  local cache_root = join_path(reqpack_root("cache", context, package), PLUGIN_ID, "eerie")
  local config_root = join_path(reqpack_root("config", context, package), PLUGIN_ID, "eerie")
  return {
    data_root = data_root,
    cache_root = cache_root,
    config_root = config_root,
    env_root = join_path(data_root, "env"),
    tmp_dir = join_path(data_root, "tmp"),
    config_file = join_path(data_root, "config.json"),
    active_env_dir = join_path(data_root, "activeEnv"),
  }
end

local function normalize_exec_result(...)
  local result = {}
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    local value_type = type(value)
    if value_type == "table" then
      for key, item in pairs(value) do
        if result[key] == nil then
          result[key] = item
        end
      end
    elseif value_type == "userdata" then
      for _, key in ipairs({ "success", "ok", "stdout", "stderr", "exitCode", "exit_code", "code", "status", "stdoutText", "stderrText" }) do
        local ok, item = pcall(function()
          return value[key]
        end)
        if ok and item ~= nil and result[key] == nil then
          result[key] = item
        end
      end
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
  if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
    return normalize_exec_result(context.exec.run(command))
  end
  if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
    return normalize_exec_result(reqpack.exec.run(command))
  end
  return {
    success = false,
    stdout = "",
    stderr = "missing ReqPack exec runner",
    exitCode = 127,
  }
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

local function command_exists(context, binary)
  return exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1").success == true
end

local function ensure_directory(path)
  local cleaned = expand_placeholders(path)
  if cleaned == "" or cleaned == "." then
    return true
  end
  local probe = io.open(join_path(cleaned, "."), "rb")
  if probe ~= nil then
    probe:close()
    return true
  end
  if os ~= nil and type(os.execute) == "function" then
    local ok = os.execute("mkdir -p " .. shell_quote(cleaned))
    if ok == true or ok == 0 then
      return true
    end
  end
  return false
end

local function read_text_file(path, prefer_exec)
  local cleaned = expand_placeholders(path)
  if prefer_exec ~= false and reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
    local result = normalize_exec_result(reqpack.exec.run("cat " .. shell_quote(cleaned)))
    if result.success == true then
      return result.stdout
    end
  end
  local handle = io.open(cleaned, "rb")
  if handle == nil then
    return nil
  end
  local content = handle:read("*a")
  handle:close()
  return content
end

local function write_text_file(path, content)
  local cleaned = expand_placeholders(path)
  if not ensure_directory(dirname(cleaned)) then
    return false
  end
  local handle = io.open(cleaned, "wb")
  if handle == nil then
    return false
  end
  handle:write(content or "")
  handle:close()
  return true
end

local function file_exists(path)
  local cleaned = expand_placeholders(path)
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
  return false
end

local function is_array(value)
  if type(value) ~= "table" then
    return false
  end
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" then
      return false
    end
    count = count + 1
  end
  for index = 1, count do
    if value[index] == nil then
      return false
    end
  end
  return true
end

local function json_escape(value)
  local text = tostring(value or "")
  text = text:gsub("\\", "\\\\")
  text = text:gsub('"', '\\"')
  text = text:gsub("\b", "\\b")
  text = text:gsub("\f", "\\f")
  text = text:gsub("\n", "\\n")
  text = text:gsub("\r", "\\r")
  text = text:gsub("\t", "\\t")
  return text
end

local function json_encode(value)
  local value_type = type(value)
  if value == nil or value == JSON_NULL then
    return "null"
  end
  if value_type == "string" then
    return '"' .. json_escape(value) .. '"'
  end
  if value_type == "number" or value_type == "boolean" then
    return tostring(value)
  end
  if value_type ~= "table" then
    return '"' .. json_escape(tostring(value)) .. '"'
  end
  if is_array(value) then
    local items = {}
    for index = 1, #value do
      items[#items + 1] = json_encode(value[index])
    end
    return "[" .. table.concat(items, ",") .. "]"
  end
  local keys = {}
  for key in pairs(value) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(left, right)
    return tostring(left) < tostring(right)
  end)
  local parts = {}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = json_encode(tostring(key)) .. ":" .. json_encode(value[key])
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function json_decode(raw)
  local text = tostring(raw or "")
  local index = 1
  local length = #text

  local function skip_ws()
    while index <= length and text:sub(index, index):match("%s") do
      index = index + 1
    end
  end

  local parse_value

  local function parse_string()
    if text:sub(index, index) ~= '"' then
      error("expected string")
    end
    index = index + 1
    local chars = {}
    while index <= length do
      local ch = text:sub(index, index)
      if ch == '"' then
        index = index + 1
        return table.concat(chars)
      end
      if ch == "\\" then
        local next_char = text:sub(index + 1, index + 1)
        if next_char == '"' or next_char == "\\" or next_char == "/" then
          chars[#chars + 1] = next_char
          index = index + 2
        elseif next_char == "b" then
          chars[#chars + 1] = "\b"
          index = index + 2
        elseif next_char == "f" then
          chars[#chars + 1] = "\f"
          index = index + 2
        elseif next_char == "n" then
          chars[#chars + 1] = "\n"
          index = index + 2
        elseif next_char == "r" then
          chars[#chars + 1] = "\r"
          index = index + 2
        elseif next_char == "t" then
          chars[#chars + 1] = "\t"
          index = index + 2
        elseif next_char == "u" then
          local hex = text:sub(index + 2, index + 5)
          if hex:match("^[0-9a-fA-F]+$") then
            local code = tonumber(hex, 16)
            if code ~= nil and code < 128 then
              chars[#chars + 1] = string.char(code)
            else
              chars[#chars + 1] = "?"
            end
            index = index + 6
          else
            error("invalid unicode escape")
          end
        else
          error("invalid escape")
        end
      else
        chars[#chars + 1] = ch
        index = index + 1
      end
    end
    error("unterminated string")
  end

  local function parse_number()
    local start_index = index
    local token = text:sub(index, index)
    if token == "-" then
      index = index + 1
    end
    while index <= length and text:sub(index, index):match("%d") do
      index = index + 1
    end
    if text:sub(index, index) == "." then
      index = index + 1
      while index <= length and text:sub(index, index):match("%d") do
        index = index + 1
      end
    end
    local exponent = text:sub(index, index)
    if exponent == "e" or exponent == "E" then
      index = index + 1
      local sign = text:sub(index, index)
      if sign == "+" or sign == "-" then
        index = index + 1
      end
      while index <= length and text:sub(index, index):match("%d") do
        index = index + 1
      end
    end
    return tonumber(text:sub(start_index, index - 1))
  end

  local function parse_array()
    index = index + 1
    skip_ws()
    local result = {}
    if text:sub(index, index) == "]" then
      index = index + 1
      return result
    end
    while true do
      result[#result + 1] = parse_value()
      skip_ws()
      local ch = text:sub(index, index)
      if ch == "]" then
        index = index + 1
        return result
      end
      if ch ~= "," then
        error("expected array separator")
      end
      index = index + 1
      skip_ws()
    end
  end

  local function parse_object()
    index = index + 1
    skip_ws()
    local result = {}
    if text:sub(index, index) == "}" then
      index = index + 1
      return result
    end
    while true do
      skip_ws()
      local key = parse_string()
      skip_ws()
      if text:sub(index, index) ~= ":" then
        error("expected object separator")
      end
      index = index + 1
      skip_ws()
      result[key] = parse_value()
      skip_ws()
      local ch = text:sub(index, index)
      if ch == "}" then
        index = index + 1
        return result
      end
      if ch ~= "," then
        error("expected object separator")
      end
      index = index + 1
      skip_ws()
    end
  end

  function parse_value()
    skip_ws()
    local ch = text:sub(index, index)
    if ch == '"' then
      return parse_string()
    end
    if ch == "{" then
      return parse_object()
    end
    if ch == "[" then
      return parse_array()
    end
    if ch == "-" or ch:match("%d") then
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
      return JSON_NULL
    end
    error("unexpected token")
  end

  local ok, result = pcall(function()
    local value = parse_value()
    skip_ws()
    return value
  end)
  if not ok then
    return nil
  end
  return result
end

local function default_env_record(name)
  return {
    name = name,
    packages = {},
  }
end

local function ensure_config_table(config)
  local changed = false
  if type(config) ~= "table" then
    config = {}
    changed = true
  end
  if type(config.envs) ~= "table" then
    config.envs = {}
    changed = true
  end
  if non_empty(config.activeEnv) == nil then
    config.activeEnv = DEFAULT_ENV_NAME
    changed = true
  end
  return config, changed
end

local function ensure_env_record(config, name)
  if type(config.envs[name]) ~= "table" then
    config.envs[name] = default_env_record(name)
    return true
  end
  if non_empty(config.envs[name].name) == nil then
    config.envs[name].name = name
    return true
  end
  if type(config.envs[name].packages) ~= "table" then
    config.envs[name].packages = {}
    return true
  end
  return false
end

local function load_config(paths, prefer_exec)
  local raw = read_text_file(paths.config_file, prefer_exec)
  if raw == nil or trim(raw) == "" then
    return nil
  end
  local decoded = json_decode(raw)
  if type(decoded) ~= "table" then
    return nil
  end
  local config = ensure_config_table(decoded)
  return config
end

local function save_config(paths, config)
  return write_text_file(paths.config_file, json_encode(config))
end

local function ensure_runtime_state(context, package, env_name)
  local paths = runtime_paths(context, package)
  ensure_directory(paths.data_root)
  ensure_directory(paths.cache_root)
  ensure_directory(paths.config_root)
  ensure_directory(paths.env_root)
  ensure_directory(paths.tmp_dir)
  ensure_directory(join_path(paths.active_env_dir, "bin"))
  ensure_directory(join_path(paths.active_env_dir, "addons"))

  local config = load_config(paths, false)
  local changed = false
  config, changed = ensure_config_table(config)

  for _, stable_env in ipairs({ "_base", "_plugins", DEFAULT_ENV_NAME, env_name }) do
    if non_empty(stable_env) ~= nil then
      if ensure_env_record(config, stable_env) then
        changed = true
      end
      ensure_directory(join_path(paths.env_root, stable_env, "bin"))
      ensure_directory(join_path(paths.env_root, stable_env, "addons"))
    end
  end

  if non_empty(env_name) ~= nil and config.activeEnv ~= env_name then
    config.activeEnv = env_name
    changed = true
  end

  if changed or not file_exists(paths.config_file) then
    save_config(paths, config)
  end
  return paths, config
end

local function package_name(package)
  return trim(read_field(package, "name") or read_field(package, "packageId") or read_field(package, "id") or package or "")
end

local function package_list(value)
  local items = {}
  if type(value) ~= "table" and type(value) ~= "userdata" then
    return items
  end
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

local function request_packages(context, packages)
  local direct_packages = package_list(packages)
  if #direct_packages > 0 then
    return direct_packages
  end
  local direct = package_list(read_field(context, "packages"))
  if #direct > 0 then
    return direct
  end
  local request = read_field(context, "request")
  local requested = package_list(read_field(request, "packages"))
  if #requested > 0 then
    return requested
  end
  return {}
end

local function package_version(package)
  return trim(read_field(package, "version") or "")
end

local function package_action(context, package)
  return lower(first_non_empty(read_field(package, "action"), read_field(read_field(context, "request"), "action"), "install"))
end

local function package_env(context, package, config)
  return first_non_empty(request_flag_value(context, package, "env"), config ~= nil and config.activeEnv or nil, DEFAULT_ENV_NAME)
end

local function looks_like_owner_repo(value)
  return tostring(value or ""):match("^[%w%._%-]+/[%w%._%-]+$") ~= nil
end

local function extract_repo_slug(value)
  local text = trim(value)
  if looks_like_owner_repo(text) then
    return text
  end
  local slug = text:match("^github:([%w%._%-]+/[%w%._%-]+)$")
    or text:match("^gh:([%w%._%-]+/[%w%._%-]+)$")
    or text:match("^github%.com/([%w%._%-]+/[%w%._%-]+)$")
  if slug ~= nil then
    return slug
  end
  local owner, repo = text:match("^https?://github%.com/([^/]+)/([^/]+)%.git$")
  if owner ~= nil and repo ~= nil then
    return owner .. "/" .. repo
  end
  owner, repo = text:match("^https?://github%.com/([^/]+)/([^/]+)/?$")
  if owner ~= nil and repo ~= nil then
    return owner .. "/" .. repo
  end
  owner, repo = text:match("^git@github%.com:([^/]+)/([^/]+)%.git$")
  if owner ~= nil and repo ~= nil then
    return owner .. "/" .. repo
  end
  owner, repo = text:match("^ssh://git@github%.com/([^/]+)/([^/]+)%.git$")
  if owner ~= nil and repo ~= nil then
    return owner .. "/" .. repo
  end
  return nil
end

local function github_repo_url(value)
  local slug = extract_repo_slug(value)
  if slug ~= nil then
    return "https://github.com/" .. slug
  end
  return nil
end

local function looks_like_direct_target(value)
  local text = trim(value)
  if text == "" then
    return false
  end
  return text:match("^https?://") ~= nil
    or text:match("^git@") ~= nil
    or text:match("^ssh://") ~= nil
    or text:match("^git%+") ~= nil
    or text:match("^%./") ~= nil
    or text:match("^%.%./") ~= nil
    or text:match("^/") ~= nil
    or extract_repo_slug(text) ~= nil
end

local function normalize_source(value)
  local text = trim(value)
  local slug = extract_repo_slug(text)
  if slug ~= nil then
    return "https://github.com/" .. slug .. ".git"
  end
  if text:match("^git%+https?://") ~= nil then
    return text:gsub("^git%+", "")
  end
  return text
end

local function guess_name_from_source(source)
  local text = trim(source)
  if text == "" then
    return nil
  end
  local name = basename(text):gsub("%.git$", "")
  name = name:gsub("%.zip$", "")
  return non_empty(name)
end

local function package_source(context, package)
  local flags = collect_flags(context, package)
  local explicit = first_non_empty(
    read_field(package, "source"),
    read_field(package, "url"),
    read_field(package, "uri"),
    read_field(package, "sourcePath"),
    flag_value(flags, "source"),
    flag_value(flags, "uri")
  )
  if explicit ~= nil then
    return normalize_source(explicit)
  end

  local name = package_name(package)
  if name ~= "" then
    return normalize_source(name)
  end
  return nil
end

local function package_label(package, source)
  return first_non_empty(package_name(package), guess_name_from_source(source), source, "package")
end

local function package_id(name, version)
  local cleaned_name = trim(name)
  local cleaned_version = trim(version)
  if cleaned_name == "" then
    return nil
  end
  if cleaned_version == "" then
    return cleaned_name
  end
  return cleaned_name .. "@" .. cleaned_version
end

local function command_prefix(paths)
  return table.concat({
    "NO_COLOR=1",
    "LC_ALL=C",
    "LANG=C",
    "LANGUAGE=C",
    "EERIEDIR=" .. shell_quote(paths.data_root),
  }, " ")
end

local function build_eerie_command(paths, subcommand, args)
  local parts = { command_prefix(paths), REQUIRED_BINARY, subcommand }
  for _, arg in ipairs(args or {}) do
    parts[#parts + 1] = shell_quote(arg)
  end
  return table.concat(parts, " ")
end

local function parse_package_entry(entry)
  if type(entry) == "table" then
    return entry
  end
  if type(entry) ~= "string" then
    return nil
  end
  local cleaned = trim(entry)
  if cleaned:sub(1, 1) == "{" then
    local decoded = json_decode(cleaned)
    if type(decoded) == "table" then
      return decoded
    end
  end
  return nil
end

local function load_manifest(package_path)
  if non_empty(package_path) == nil then
    return nil
  end
  local raw = read_text_file(join_path(package_path, "package.json"), true)
  if raw == nil or trim(raw) == "" then
    return nil
  end
  local decoded = json_decode(raw)
  if type(decoded) == "table" then
    return decoded
  end
  return nil
end

local function build_installed_item(entry, env_name)
  local manifest = load_manifest(read_field(entry, "path"))
  local name = first_non_empty(read_field(entry, "name"), manifest ~= nil and read_field(manifest, "name") or nil, guess_name_from_source(read_field(entry, "uri")))
  local version = first_non_empty(manifest ~= nil and read_field(manifest, "version") or nil, read_field(entry, "version"))
  local description = first_non_empty(manifest ~= nil and read_field(manifest, "description") or nil, read_field(entry, "description"))
  local homepage = first_non_empty(
    manifest ~= nil and read_field(manifest, "website") or nil,
    manifest ~= nil and read_field(manifest, "homepage") or nil,
    manifest ~= nil and read_field(manifest, "repository") or nil
  )
  local item = {
    name = name,
    packageId = package_id(name, version),
    version = version,
    summary = description,
    description = description,
    homepage = homepage,
    source = first_non_empty(read_field(entry, "uri"), manifest ~= nil and read_field(manifest, "source") or nil),
    sourceUrl = first_non_empty(read_field(entry, "uri"), manifest ~= nil and read_field(manifest, "source") or nil),
    installPath = read_field(entry, "path"),
    env = env_name,
    installed = true,
    packageType = "io-addon",
    type = "package",
  }
  if manifest ~= nil then
    item.author = read_field(manifest, "author")
    item.readme = read_field(manifest, "readme")
    item.protos = read_field(manifest, "protos")
    item.dependencies = read_field(manifest, "dependencies")
  end
  return item
end

local function installed_packages(context, package, preferred_env)
  local paths = runtime_paths(context, package)
  local config = load_config(paths, true)
  if type(config) ~= "table" or type(config.envs) ~= "table" then
    return {}, {}, paths, nil, preferred_env or DEFAULT_ENV_NAME
  end
  local env_name = first_non_empty(preferred_env, config.activeEnv, DEFAULT_ENV_NAME)
  local env_config = read_field(config.envs, env_name)
  if type(env_config) ~= "table" then
    return {}, {}, paths, config, env_name
  end

  local results = {}
  local map = {}
  for _, raw_entry in ipairs(read_field(env_config, "packages") or {}) do
    local entry = parse_package_entry(raw_entry)
    if type(entry) == "table" then
      local item = build_installed_item(entry, env_name)
      if non_empty(item.name) ~= nil then
        results[#results + 1] = item
        map[lower(item.name)] = item
      end
    end
  end
  return results, map, paths, config, env_name
end

local function contains_text(haystack, needle)
  local left = lower(haystack)
  local right = lower(needle)
  return right == "" or left:find(right, 1, true) ~= nil
end

local function direct_target_item(target)
  local source = normalize_source(target)
  local name = guess_name_from_source(source)
  local repository = github_repo_url(source)
  local summary = repository ~= nil and "Direct GitHub Eerie install target" or "Direct Eerie install target"
  return {
    name = name,
    packageId = name,
    source = source,
    sourceUrl = source,
    homepage = repository,
    repository = repository,
    installed = false,
    summary = summary,
    description = summary,
    packageType = "io-addon",
    type = "package",
  }
end

local function ensure_available(context)
  if command_exists(context, REQUIRED_BINARY) then
    return true
  end
  tx_failed(context, REQUIRED_BINARY .. " command not available")
  emit_event(context, "unavailable", { reason = REQUIRED_BINARY .. "-not-installed" })
  return false
end

local function event_payload_from_request(context, package, source, env_name)
  local name = package_label(package, source)
  local version = package_version(package)
  return {
    name = name,
    packageId = package_id(name, version),
    version = non_empty(version),
    source = source,
    sourceUrl = source,
    env = env_name,
    summary = package_label(package, source),
    packageType = "io-addon",
    type = "package",
  }
end

local function command_failure_message(result, fallback)
  local stderr = trim(result ~= nil and result.stderr or "")
  local stdout = trim(result ~= nil and result.stdout or "")
  return first_non_empty(stderr, stdout, fallback, "command failed")
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
  return { "package-manager", "language", "io" }
end

function plugin.getMissingPackages(context, packages)
  local missing = {}
  for _, package in ipairs(request_packages(context, packages)) do
    local action = package_action(context, package)
    local env_name = package_env(context, package)
    local _, installed_map = installed_packages(context, package, env_name)
    local installed = installed_map[lower(package_name(package))]
    if action == "remove" then
      if installed ~= nil then
        missing[#missing + 1] = package
      end
    elseif action == "update" then
      if package_name(package) ~= "" or package_source(context, package) ~= nil then
        missing[#missing + 1] = package
      end
    else
      local requested_source = package_source(context, package)
      if installed == nil then
        missing[#missing + 1] = package
      elseif requested_source ~= nil and requested_source ~= trim(installed.source or "") then
        missing[#missing + 1] = package
      end
    end
  end
  return missing
end

function plugin.install(context, packages)
  if not ensure_available(context) then
    return false
  end
  packages = request_packages(context, packages)
  if #packages == 0 then
    tx_success(context)
    return true
  end

  for _, package in ipairs(packages) do
    local source = package_source(context, package)
    if non_empty(source) == nil then
      tx_failed(context, "io install requires source, url, uri, or installable package name")
      return false
    end

    local env_name = package_env(context, package)
    local paths = ensure_runtime_state(context, package, env_name)
    begin_step(context, "Install " .. package_label(package, source))
    local result = exec_run(context, build_eerie_command(paths, "install", { source }))
    if result.success ~= true then
      tx_failed(context, command_failure_message(result, "eerie install failed"))
      return false
    end
    emit_event(context, "installed", event_payload_from_request(context, package, source, env_name))
  end

  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  if not ensure_available(context) then
    return false
  end
  local local_path = first_non_empty(path, read_field(context, "localPath"), read_field(read_field(context, "request"), "localPath"), read_field(context, "path"), read_field(read_field(context, "request"), "path"))
  if local_path == nil then
    tx_failed(context, "io installLocal requires local path")
    return false
  end

  local env_name = package_env(context, nil)
  local paths = ensure_runtime_state(context, nil, env_name)
  begin_step(context, "Install local " .. local_path)
  local result = exec_run(context, build_eerie_command(paths, "install", { local_path }))
  if result.success ~= true then
    tx_failed(context, command_failure_message(result, "eerie install failed"))
    return false
  end

  emit_event(context, "installed", {
    name = guess_name_from_source(local_path),
    packageId = guess_name_from_source(local_path),
    source = local_path,
    sourceUrl = local_path,
    env = env_name,
    summary = guess_name_from_source(local_path),
    packageType = "io-addon",
    type = "package",
  })
  tx_success(context)
  return true
end

function plugin.remove(context, packages)
  if not ensure_available(context) then
    return false
  end
  packages = request_packages(context, packages)
  if #packages == 0 then
    tx_success(context)
    return true
  end

  for _, package in ipairs(packages) do
    local name = package_name(package)
    if name == "" then
      tx_failed(context, "io remove requires package name")
      return false
    end

    local env_name = package_env(context, package)
    local paths = ensure_runtime_state(context, package, env_name)
    begin_step(context, "Remove " .. name)
    local result = exec_run(context, build_eerie_command(paths, "remove", { name }))
    if result.success ~= true then
      tx_failed(context, command_failure_message(result, "eerie remove failed"))
      return false
    end
    emit_event(context, "deleted", {
      name = name,
      packageId = name,
      env = env_name,
      packageType = "io-addon",
      type = "package",
    })
  end

  tx_success(context)
  return true
end

function plugin.update(context, packages)
  if not ensure_available(context) then
    return false
  end

  packages = request_packages(context, packages)

  if #packages == 0 then
    local env_name = package_env(context, nil)
    local paths = ensure_runtime_state(context, nil, env_name)
    begin_step(context, "Update all io packages")
    local result = exec_run(context, build_eerie_command(paths, "pkg:updateAll", {}))
    if result.success ~= true then
      tx_failed(context, command_failure_message(result, "eerie updateAll failed"))
      return false
    end
    emit_event(context, "updated", { env = env_name, packageType = "io-addon", type = "package" })
    tx_success(context)
    return true
  end

  for _, package in ipairs(packages) do
    local name = package_name(package)
    if name == "" then
      tx_failed(context, "io update requires package name")
      return false
    end
    local env_name = package_env(context, package)
    local paths = ensure_runtime_state(context, package, env_name)
    begin_step(context, "Update " .. name)
    local result = exec_run(context, build_eerie_command(paths, "update", { name }))
    if result.success ~= true then
      tx_failed(context, command_failure_message(result, "eerie update failed"))
      return false
    end
    emit_event(context, "updated", {
      name = name,
      packageId = name,
      env = env_name,
      packageType = "io-addon",
      type = "package",
    })
  end

  tx_success(context)
  return true
end

function plugin.list(context)
  local env_name = package_env(context, nil)
  local items = installed_packages(context, nil, env_name)
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  local empty = {}
  emit_event(context, "outdated", empty)
  return empty
end

function plugin.search(context, prompt)
  local query = trim(first_non_empty(prompt, read_field(context, "prompt"), read_field(read_field(context, "request"), "prompt"), ""))
  if query == "" then
    local empty = {}
    emit_event(context, "searched", empty)
    return empty
  end

  if looks_like_direct_target(query) then
    local item = direct_target_item(query)
    local results = { item }
    emit_event(context, "searched", results)
    return results
  end

  local env_name = package_env(context, nil)
  local items = installed_packages(context, nil, env_name)
  local results = {}
  for _, item in ipairs(items) do
    if contains_text(item.name, query) or contains_text(item.description, query) or contains_text(item.source, query) then
      results[#results + 1] = item
    end
  end
  emit_event(context, "searched", results)
  return results
end

function plugin.info(context, name)
  local target = trim(first_non_empty(name, read_field(context, "name"), read_field(read_field(context, "request"), "name"), read_field(context, "prompt"), read_field(read_field(context, "request"), "prompt"), ""))
  if target == "" then
    local empty = {}
    emit_event(context, "informed", empty)
    return empty
  end

  local env_name = package_env(context, nil)
  local items, map = installed_packages(context, nil, env_name)
  local direct = map[lower(target:match("^([^@]+)@") or target)]
  if direct ~= nil then
    emit_event(context, "informed", direct)
    return direct
  end

  for _, item in ipairs(items) do
    if lower(trim(item.source or "")) == lower(target) then
      emit_event(context, "informed", item)
      return item
    end
  end

  if looks_like_direct_target(target) then
    local item = direct_target_item(target)
    emit_event(context, "informed", item)
    return item
  end

  local empty = {}
  emit_event(context, "informed", empty)
  return empty
end

function plugin.resolvePackage(context, package)
  if package == nil then
    return nil
  end
  local name = package_name(package)
  if name == "" then
    name = package_source(context, package) or ""
  end
  if name == "" then
    return nil
  end
  local info = plugin.info(context, name)
  if type(info) == "table" and next(info) ~= nil then
    return info
  end
  local results = plugin.search(context, name)
  for _, item in ipairs(results or {}) do
    if lower(trim(item.name or "")) == lower(package_name(package)) then
      return item
    end
  end
  return nil
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "exec", "network" },
    ecosystemScopes = { "io", "eerie", "iolanguage" },
    writeScopes = {
      { kind = "user-home-subpath", value = ".local/share/reqpack/io" },
      { kind = "user-home-subpath", value = ".cache/reqpack/io" },
      { kind = "user-home-subpath", value = ".config/reqpack/io" },
    },
    networkScopes = { "github.com", "raw.githubusercontent.com" },
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
