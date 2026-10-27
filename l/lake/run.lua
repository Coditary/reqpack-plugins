plugin = {}

local PLUGIN_ID = "lake"
local PLUGIN_NAME = "Lake"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "lake"
local JSON_NULL = {}
local REMOTE_CACHE_TTL = 300
local RESERVOIR_BASE_URL = "https://reservoir.lean-lang.org"
local WORKSPACE_PACKAGE_NAME = "reqpack-lake-workspace"
local WORKSPACE_LIBRARY_NAME = "ReqpackLakeWorkspace"
local read_proc_environ_value

plugin.fileExtensions = { ".toml", ".lean" }

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

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
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

local function first_nonempty(...)
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    if value ~= nil and value ~= JSON_NULL then
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

local function split_lines(value)
  local lines = {}
  local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
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

local function sorted_items(items, sorter)
  local copy = {}
  for _, item in ipairs(items or {}) do
    copy[#copy + 1] = item
  end
  table.sort(copy, sorter)
  return copy
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
  return normalize_exec_result(reqpack.exec.run(command))
end

local function join_path(...)
  local parts = {}
  for index = 1, select("#", ...) do
    local raw = runtime_expand(tostring(select(index, ...) or ""))
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

read_proc_environ_value = function(name)
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
    if entry:sub(1, #prefix) == prefix then
      return trim(entry:sub(#prefix + 1))
    end
  end
  return nil
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
      local cleaned = runtime_expand(item)
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
  local function collect_from(object)
    for _, flag in ipairs(object_flags(object)) do
      local cleaned = trim(flag)
      if cleaned ~= "" and not seen[cleaned] then
        seen[cleaned] = true
        flags[#flags + 1] = cleaned
      end
    end
  end

  collect_from(context)
  collect_from(context ~= nil and context.request or nil)
  collect_from(package)
  return flags
end

local function flag_value(flags, key)
  local prefix = lower(trim(key)) .. "="
  for _, flag in ipairs(flags or {}) do
    local cleaned = trim(flag)
    local lowered = lower(cleaned)
    if lowered:sub(1, #prefix) == prefix then
      return trim(cleaned:sub(#prefix + 1))
    end
  end
  return nil
end

local function reqpack_root(kind, context)
  local flags = collect_flags(context, nil)
  local override = nil
  if kind == "data" then
    override = flag_value(flags, "data-root")
  elseif kind == "cache" then
    override = flag_value(flags, "cache-root")
  else
    override = flag_value(flags, "config-root")
  end
  if non_empty(override) ~= nil then
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

local function lake_roots(context)
  local data_root = join_path(reqpack_root("data", context), PLUGIN_ID)
  local cache_root = join_path(reqpack_root("cache", context), PLUGIN_ID)
  return {
    dataRoot = data_root,
    cacheRoot = cache_root,
    workspaceRoot = join_path(data_root, "workspace"),
    elanHome = join_path(data_root, "elan"),
    lakeHome = join_path(cache_root, "lake-home"),
    queryRoot = join_path(cache_root, "query"),
    lakefile = join_path(data_root, "workspace", "lakefile.toml"),
    rootModule = join_path(data_root, "workspace", WORKSPACE_LIBRARY_NAME .. ".lean"),
    manifest = join_path(data_root, "workspace", "lake-manifest.json"),
  }
end

local function env_prefix(context)
  local roots = lake_roots(context)
  return table.concat({
    "NO_COLOR=1",
    "LC_ALL=C",
    "LANG=C",
    "LANGUAGE=C",
    "ELAN_HOME=" .. shell_quote(roots.elanHome),
    "LAKE_HOME=" .. shell_quote(roots.lakeHome),
  }, " ")
end

local function with_env(context, command)
  return env_prefix(context) .. " " .. command
end

local function command_exists(context, binary)
  local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
  return result ~= nil and result.success == true
end

local function path_exists(path)
  local target = runtime_expand(path)
  if target == "" then
    return false
  end

  local handle = io.open(target, "rb")
  if handle ~= nil then
    handle:close()
    return true
  end

  local probe = io.open(join_path(target, "."), "rb")
  if probe ~= nil then
    probe:close()
    return true
  end
  return false
end

local function read_file(context, path)
  local target = runtime_expand(path)
  local handle = io.open(target, "rb")
  if handle == nil then
    if context ~= nil then
      local result = exec_run(context, "cat " .. shell_quote(target))
      if result ~= nil and result.success == true then
        return result.stdout
      end
    end
    return nil
  end
  local content = handle:read("*a")
  handle:close()
  return content
end

local function write_file(context, path, content)
  local target = runtime_expand(path)
  local handle = io.open(target, "wb")
  if handle ~= nil then
    handle:write(content or "")
    handle:close()
    return true
  end

  local parent = target:match("^(.*)/[^/]+$")
  if parent ~= nil and parent ~= "" then
    local mkdir = exec_run(context, "mkdir -p " .. shell_quote(parent))
    if mkdir == nil or mkdir.success ~= true then
      return false
    end
  end

  local tmp = target .. ".tmp"
  local write = exec_run(context, "printf %s " .. shell_quote(content or "") .. " > " .. shell_quote(tmp) .. " && mv " .. shell_quote(tmp) .. " " .. shell_quote(target))
  return write ~= nil and write.success == true
end

local function ensure_directories(context, paths)
  local unique = {}
  local seen = {}
  for _, path in ipairs(paths or {}) do
    local cleaned = trim(path)
    cleaned = runtime_expand(cleaned)
    if cleaned ~= "" and not seen[cleaned] then
      seen[cleaned] = true
      unique[#unique + 1] = shell_quote(cleaned)
    end
  end
  if #unique == 0 then
    return true
  end
  local result = exec_run(context, "mkdir -p " .. table.concat(unique, " "))
  return result ~= nil and result.success == true
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
    end
    current = peek()
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
    current = peek()
    if current == "." then
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
    if current == "-" or current:match("%d") then
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
    return nil, tostring(value)
  end
  return value, nil
end

local function normalize_package_ref(raw)
  local text = trim(raw)
  text = text:gsub("^@", "")
  local scope, name = text:match("^([^/]+)/([^/]+)$")
  if scope ~= nil and name ~= nil then
    return {
      scope = trim(scope),
      name = trim(name),
      packageId = "@" .. trim(scope) .. "/" .. trim(name),
    }
  end
  if text == "" then
    return {
      scope = nil,
      name = nil,
      packageId = nil,
    }
  end
  return {
    scope = nil,
    name = text,
    packageId = text,
  }
end

local function normalized_request_package(package)
  local ref = normalize_package_ref(first_nonempty(read_field(package, "name"), read_field(package, "packageId")))
  ref.version = non_empty(read_field(package, "version"))
  return ref
end

local function dependency_sorter(left, right)
  return lower(left.packageId or "") < lower(right.packageId or "")
end

local function dependency_matches_request(dep, request)
  if dep == nil or request == nil then
    return false
  end
  if non_empty(request.scope) ~= nil then
    return lower(dep.packageId or "") == lower(request.packageId or "")
  end
  return lower(dep.name or "") == lower(request.name or "")
end

local function parse_toml_string(value)
  local inner = trim(value)
  if inner:sub(1, 1) == '"' and inner:sub(-1) == '"' then
    inner = inner:sub(2, -2)
  end
  inner = inner:gsub('\\"', '"')
  inner = inner:gsub("\\n", "\n")
  inner = inner:gsub("\\t", "\t")
  inner = inner:gsub("\\r", "\r")
  inner = inner:gsub("\\\\", "\\")
  return inner
end

local function toml_quote(value)
  local text = tostring(value or "")
  text = text:gsub("\\", "\\\\")
  text = text:gsub('"', '\\"')
  text = text:gsub("\n", "\\n")
  return '"' .. text .. '"'
end

local function parse_direct_dependencies(content)
  local dependencies = {}
  local current = nil
  for _, line in ipairs(split_lines(content or "")) do
    local cleaned = trim(line)
    if cleaned == "[[require]]" then
      if current ~= nil and current.name ~= nil then
        current.packageId = current.scope ~= nil and ("@" .. current.scope .. "/" .. current.name) or current.name
        dependencies[#dependencies + 1] = current
      end
      current = {}
    elseif current ~= nil and cleaned ~= "" and cleaned:sub(1, 1) ~= "#" then
      if cleaned:sub(1, 2) == "[[" then
        if current.name ~= nil then
          current.packageId = current.scope ~= nil and ("@" .. current.scope .. "/" .. current.name) or current.name
          dependencies[#dependencies + 1] = current
        end
        current = nil
      else
        local key, value = cleaned:match("^([%w_]+)%s*=%s*(.+)$")
        if key ~= nil and value ~= nil then
          local parsed = parse_toml_string(value)
          if key == "name" then
            current.name = non_empty(parsed)
          elseif key == "scope" then
            current.scope = non_empty(parsed)
          elseif key == "version" then
            current.version = non_empty(parsed)
          elseif key == "git" then
            current.git = non_empty(parsed)
          elseif key == "path" then
            current.path = non_empty(parsed)
          elseif key == "rev" then
            current.rev = non_empty(parsed)
          end
        end
      end
    end
  end

  if current ~= nil and current.name ~= nil then
    current.packageId = current.scope ~= nil and ("@" .. current.scope .. "/" .. current.name) or current.name
    dependencies[#dependencies + 1] = current
  end

  table.sort(dependencies, dependency_sorter)
  return dependencies
end

local function serialize_workspace_file(dependencies)
  local lines = {
    "name = " .. toml_quote(WORKSPACE_PACKAGE_NAME),
    "version = \"0.1.0\"",
    "packagesDir = \".lake/packages\"",
    "",
    "[[lean_lib]]",
    "name = " .. toml_quote(WORKSPACE_LIBRARY_NAME),
  }

  for _, dep in ipairs(sorted_items(dependencies, dependency_sorter)) do
    lines[#lines + 1] = ""
    lines[#lines + 1] = "[[require]]"
    lines[#lines + 1] = "name = " .. toml_quote(dep.name)
    if non_empty(dep.scope) ~= nil then
      lines[#lines + 1] = "scope = " .. toml_quote(dep.scope)
    end
    if non_empty(dep.version) ~= nil then
      lines[#lines + 1] = "version = " .. toml_quote(dep.version)
    end
    if non_empty(dep.git) ~= nil then
      lines[#lines + 1] = "git = " .. toml_quote(dep.git)
    end
    if non_empty(dep.path) ~= nil then
      lines[#lines + 1] = "path = " .. toml_quote(dep.path)
    end
    if non_empty(dep.rev) ~= nil then
      lines[#lines + 1] = "rev = " .. toml_quote(dep.rev)
    end
  end

  return table.concat(lines, "\n") .. "\n"
end

local function ensure_workspace(context)
  local roots = lake_roots(context)
  if not ensure_directories(context, {
    roots.dataRoot,
    roots.cacheRoot,
    roots.workspaceRoot,
    roots.elanHome,
    roots.lakeHome,
    roots.queryRoot,
  }) then
    return nil, "failed to create Lake plugin directories"
  end

  if not path_exists(roots.lakefile) then
    if not write_file(context, roots.lakefile, serialize_workspace_file({})) then
      return nil, "failed to write Lake workspace lakefile.toml"
    end
  end

  if not path_exists(roots.rootModule) then
    if not write_file(context, roots.rootModule, "-- ReqPack-managed shared Lake workspace.\n") then
      return nil, "failed to write shared Lake workspace root module"
    end
  end

  return roots, nil
end

local function read_workspace_dependencies(context)
  local roots = lake_roots(context)
  local content = read_file(context, roots.lakefile)
  if content == nil then
    return {}
  end
  return parse_direct_dependencies(content)
end

local function write_workspace_dependencies(context, dependencies)
  local roots, workspace_error = ensure_workspace(context)
  if roots == nil then
    return nil, workspace_error
  end
  local ok = write_file(context, roots.lakefile, serialize_workspace_file(dependencies))
  if not ok then
    return nil, "failed to persist Lake workspace dependencies"
  end
  return roots, nil
end

local function manifest_package_lookup(context)
  local roots = lake_roots(context)
  local payload = read_file(context, roots.manifest)
  if payload == nil then
    return {}, nil
  end

  local decoded, decode_error = decode_json(payload)
  if decoded == nil then
    return {}, decode_error
  end

  local packages = read_field(decoded, "packages")
  if type(packages) ~= "table" then
    return {}, nil
  end

  local lookup = {}
  for _, entry in ipairs(packages) do
    if type(entry) == "table" then
      local scope = non_empty(read_field(entry, "scope"))
      local name = non_empty(read_field(entry, "name"))
      if name ~= nil then
        local package_id = scope ~= nil and ("@" .. scope .. "/" .. name) or name
        lookup[lower(package_id)] = entry
        lookup[lower(name)] = lookup[lower(name)] or entry
      end
    end
  end
  return lookup, nil
end

local function lake_command(context, args)
  local roots = lake_roots(context)
  local command = "cd " .. shell_quote(roots.workspaceRoot) .. " && " .. with_env(context, REQUIRED_BINARY)
  for _, arg in ipairs(args or {}) do
    command = command .. " " .. shell_quote(arg)
  end
  return command
end

local function run_lake(context, args)
  return exec_run(context, lake_command(context, args))
end

local function fetch_url(context, url)
  local result = exec_run(context, "curl -fsSL " .. shell_quote(url))
  if result == nil or result.success ~= true then
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "request failed")
  end
  return result.stdout, nil
end

local function cache_key(value)
  local normalized = lower(trim(value))
  if normalized == "" then
    normalized = "unknown"
  end
  return normalized:gsub("[^%w%.%-_]+", "_")
end

local function epoch_now()
  if os ~= nil and type(os.time) == "function" then
    return os.time()
  end
  return 0
end

local function read_timestamp(path)
  local raw = trim(read_file(nil, path) or "")
  local value = tonumber(raw)
  if value == nil then
    return 0
  end
  return value
end

local function persist_cache(context, body_path, ts_path, body)
  write_file(context, body_path, body)
  write_file(context, ts_path, tostring(epoch_now()))
end

local function cached_fetch(context, body_path, ts_path, url, ttl)
  local cached = read_file(context, body_path)
  if cached ~= nil and (epoch_now() - read_timestamp(ts_path)) < ttl then
    return cached, nil
  end
  local body, fetch_error = fetch_url(context, url)
  if body ~= nil then
    persist_cache(context, body_path, ts_path, body)
    return body, nil
  end
  if cached ~= nil then
    return cached, nil
  end
  return nil, fetch_error
end

local function html_unescape(value)
  local text = tostring(value or "")
  text = text:gsub("&quot;", '"')
  text = text:gsub("&#39;", "'")
  text = text:gsub("&apos;", "'")
  text = text:gsub("&lt;", "<")
  text = text:gsub("&gt;", ">")
  text = text:gsub("&amp;", "&")
  return text
end

local function strip_tags(value)
  local text = tostring(value or "")
  text = text:gsub("<script.-</script>", " ")
  text = text:gsub("<style.-</style>", " ")
  text = text:gsub("<[^>]+>", " ")
  text = html_unescape(text)
  text = text:gsub("%s+", " ")
  return trim(text)
end

local function parse_reservoir_search_ids(html)
  local items = {}
  local seen = {}
  local index = 1
  while true do
    local start_pos, end_pos, href = html:find('href="(/@[^"?#]+)"', index)
    if start_pos == nil then
      break
    end
    local scope, name = href:match("^/@([^/]+)/([^/]+)$")
    if scope ~= nil and name ~= nil then
      local package_id = "@" .. scope .. "/" .. name
      if not seen[lower(package_id)] then
        seen[lower(package_id)] = true
        items[#items + 1] = {
          scope = scope,
          name = name,
          packageId = package_id,
        }
      end
    end
    index = end_pos + 1
  end
  return items
end

local function first_html_meta(html, meta_name)
  local patterns = {
    '<meta[^>]-name="' .. meta_name .. '"[^>]-content="([^"]+)"',
    '<meta[^>]-property="' .. meta_name .. '"[^>]-content="([^"]+)"',
    '<meta[^>]-content="([^"]+)"[^>]-name="' .. meta_name .. '"',
    '<meta[^>]-content="([^"]+)"[^>]-property="' .. meta_name .. '"',
  }
  for _, pattern in ipairs(patterns) do
    local value = html:match(pattern)
    if non_empty(value) ~= nil then
      return html_unescape(value)
    end
  end
  return nil
end

local function parse_reservoir_package_page(html, package_id)
  local normalized = normalize_package_ref(package_id)
  local title = strip_tags(first_nonempty(html:match("<title>(.-)</title>"), ""))
  local description = first_nonempty(
    first_html_meta(html, "description"),
    first_html_meta(html, "og:description")
  )
  local repository = first_nonempty(
    html:match('href="(https://github.com/[^"#]+)"'),
    html:match('href="(http://github.com/[^"#]+)"')
  )
  local updated_at = first_nonempty(html:match("Last updated on ([^<\n]+)"))
  local license = first_nonempty(
    html:match("METADATA.-%-%s*([A-Za-z0-9%._%-]+)%s*%-%s*[^\n<]-Last updated"),
    html:match("%-%s*([A-Za-z0-9%._%-]+)%s*%-%s*[%d]+%s+days?%s+ago")
  )
  local toolchain = first_nonempty(html:match("leanprover/lean4:([A-Za-z0-9%._%-]+)"))
  local summary = description
  if summary == nil and normalized.name ~= nil then
    summary = normalized.name
  end

  return {
    name = normalized.name,
    packageId = normalized.packageId,
    packageType = "lake-package",
    type = "package",
    installed = false,
    status = "available",
    summary = summary,
    description = description,
    homepage = repository,
    repository = repository,
    license = license,
    version = toolchain,
    latestVersion = toolchain,
    extraFields = {
      scope = normalized.scope,
      title = title,
      leanToolchain = toolchain,
      reservoirUrl = RESERVOIR_BASE_URL .. "/" .. normalized.packageId,
      updatedAt = updated_at,
    },
  }
end

local function fetch_reservoir_search(context, prompt)
  local roots, workspace_error = ensure_workspace(context)
  if roots == nil then
    return nil, workspace_error
  end
  local key = cache_key("search-" .. prompt)
  local body_path = join_path(roots.queryRoot, key .. ".html")
  local ts_path = join_path(roots.queryRoot, key .. ".ts")
  return cached_fetch(context, body_path, ts_path, RESERVOIR_BASE_URL .. "/packages?query=" .. runtime_expand(tostring(prompt)), REMOTE_CACHE_TTL)
end

local function fetch_reservoir_package_page(context, package_id)
  local roots, workspace_error = ensure_workspace(context)
  if roots == nil then
    return nil, workspace_error
  end
  local normalized = normalize_package_ref(package_id)
  if normalized.packageId == nil then
    return nil, "invalid package id"
  end
  local key = cache_key("pkg-" .. normalized.packageId)
  local body_path = join_path(roots.queryRoot, key .. ".html")
  local ts_path = join_path(roots.queryRoot, key .. ".ts")
  return cached_fetch(context, body_path, ts_path, RESERVOIR_BASE_URL .. "/" .. normalized.packageId, REMOTE_CACHE_TTL)
end

local function local_item_from_dependency(context, dep, manifest)
  local roots = lake_roots(context)
  local manifest_entry = nil
  if type(manifest) == "table" then
    manifest_entry = manifest[lower(dep.packageId or dep.name or "")]
  end
  local resolved_version = first_nonempty(
    manifest_entry and read_field(manifest_entry, "version"),
    manifest_entry and read_field(manifest_entry, "rev"),
    manifest_entry and read_field(manifest_entry, "inputRev"),
    dep.version
  )
  return {
    name = dep.name,
    packageId = dep.packageId,
    version = resolved_version,
    latestVersion = resolved_version,
    installed = true,
    status = "installed",
    packageType = "lake-package",
    type = "package",
    summary = dep.packageId,
    description = dep.packageId,
    extraFields = {
      scope = dep.scope,
      declaredVersion = dep.version,
      manifestType = manifest_entry and read_field(manifest_entry, "type") or nil,
      manifestUrl = manifest_entry and read_field(manifest_entry, "url") or nil,
      manifestRev = manifest_entry and read_field(manifest_entry, "rev") or nil,
      manifestInputRev = manifest_entry and read_field(manifest_entry, "inputRev") or nil,
      workspaceRoot = roots.workspaceRoot,
      lakefile = roots.lakefile,
      manifest = roots.manifest,
      elanHome = roots.elanHome,
      lakeHome = roots.lakeHome,
    },
  }
end

local function merge_items(local_item, remote_item)
  if local_item == nil then
    return remote_item
  end
  if remote_item == nil then
    return local_item
  end
  local merged = shallow_copy(remote_item)
  merged.installed = true
  merged.status = local_item.status == "outdated" and "outdated" or "installed"
  merged.version = first_nonempty(local_item.version, remote_item.version, remote_item.latestVersion)
  merged.latestVersion = first_nonempty(remote_item.latestVersion, local_item.latestVersion, local_item.version)
  merged.extraFields = shallow_copy(remote_item.extraFields or {})
  for key, value in pairs(local_item.extraFields or {}) do
    merged.extraFields[key] = value
  end
  merged.packageId = first_nonempty(local_item.packageId, remote_item.packageId)
  merged.name = first_nonempty(local_item.name, remote_item.name)
  merged.homepage = first_nonempty(remote_item.homepage, local_item.homepage)
  merged.repository = first_nonempty(remote_item.repository, local_item.repository)
  return merged
end

local function resolve_remote_package_id(context, raw_name)
  local normalized = normalize_package_ref(raw_name)
  if normalized.scope ~= nil then
    return normalized.packageId
  end

  local html = select(1, fetch_reservoir_search(context, normalized.name or ""))
  if type(html) ~= "string" then
    return nil
  end

  local matches = parse_reservoir_search_ids(html)
  local wanted = lower(normalized.name or "")
  for _, item in ipairs(matches) do
    if lower(item.name or "") == wanted then
      return item.packageId
    end
  end
  if #matches > 0 then
    return matches[1].packageId
  end
  return nil
end

local function remote_info_item(context, raw_name)
  local package_id = resolve_remote_package_id(context, raw_name)
  if package_id == nil then
    return nil
  end
  local html = select(1, fetch_reservoir_package_page(context, package_id))
  if type(html) ~= "string" then
    return nil
  end
  return parse_reservoir_package_page(html, package_id)
end

local function installed_lookup(context)
  local dependencies = read_workspace_dependencies(context)
  local manifest = select(1, manifest_package_lookup(context)) or {}
  local lookup = {}
  for _, dep in ipairs(dependencies) do
    local item = local_item_from_dependency(context, dep, manifest)
    lookup[lower(dep.packageId or dep.name or "")] = item
    lookup[lower(dep.name or "")] = lookup[lower(dep.name or "")] or item
  end
  return lookup
end

local function ensure_available(context, fatal)
  if command_exists(context, REQUIRED_BINARY) then
    return true
  end
  local message = "lake command not available"
  if fatal then
    tx_failed(context, message)
    emit_event(context, "unavailable", { reason = "lake-not-installed" })
  else
    log_warn(context, message)
  end
  return false
end

local function update_dependencies(existing, packages)
  local updated = {}
  local seen = {}

  for _, dep in ipairs(existing or {}) do
    updated[#updated + 1] = shallow_copy(dep)
    seen[lower(dep.packageId or dep.name or "")] = #updated
    seen[lower(dep.name or "")] = seen[lower(dep.name or "")] or #updated
  end

  for _, package in ipairs(packages or {}) do
    local normalized = normalized_request_package(package)
    if normalized.name ~= nil then
      local key = lower(normalized.packageId or normalized.name)
      local existing_index = seen[key]
      local dep = {
        scope = normalized.scope,
        name = normalized.name,
        packageId = normalized.packageId,
        version = normalized.version,
      }
      if existing_index ~= nil then
        updated[existing_index] = dep
      else
        updated[#updated + 1] = dep
        seen[key] = #updated
      end
    end
  end

  table.sort(updated, dependency_sorter)
  return updated
end

local function remove_dependencies(existing, packages)
  local filtered = {}
  for _, dep in ipairs(existing or {}) do
    local keep = true
    for _, package in ipairs(packages or {}) do
      if dependency_matches_request(dep, normalized_request_package(package)) then
        keep = false
        break
      end
    end
    if keep then
      filtered[#filtered + 1] = dep
    end
  end
  table.sort(filtered, dependency_sorter)
  return filtered
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
  return { "Lean", "Package Manager", "Build Tool" }
end

function plugin.getMissingPackages(packages)
  if packages == nil or #packages == 0 then
    return {}
  end

  local dependencies = read_workspace_dependencies(nil)
  local missing = {}
  for _, package in ipairs(packages) do
    local request = normalized_request_package(package)
    local action = lower(read_field(package, "action") or "install")
    local matched = false
    for _, dep in ipairs(dependencies) do
      if dependency_matches_request(dep, request) then
        matched = true
        break
      end
    end
    if action == "remove" or action == "update" then
      if matched then
        missing[#missing + 1] = package
      end
    elseif not matched then
      missing[#missing + 1] = package
    end
  end
  return missing
end

function plugin.install(context, packages)
  if packages == nil or #packages == 0 then
    return true
  end
  if not ensure_available(context, true) then
    return false
  end

  begin_step(context, "install lake dependencies")
  local roots, workspace_error = ensure_workspace(context)
  if roots == nil then
    tx_failed(context, workspace_error)
    return false
  end

  local updated = update_dependencies(read_workspace_dependencies(context), packages)
  local _, write_error = write_workspace_dependencies(context, updated)
  if write_error ~= nil then
    tx_failed(context, write_error)
    return false
  end

  local result = run_lake(context, { "update" })
  if result == nil or result.success ~= true then
    tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "lake update failed"))
    return false
  end

  emit_event(context, "installed", packages)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  begin_step(context, "install local lake dependency")
  emit_event(context, "unavailable", {
    path = trim(path),
    reason = "local-install-unsupported",
  })
  tx_failed(context, "lake local installs are not supported")
  return false
end

function plugin.remove(context, packages)
  if packages == nil or #packages == 0 then
    return true
  end
  if not ensure_available(context, true) then
    return false
  end

  begin_step(context, "remove lake dependencies")
  local updated = remove_dependencies(read_workspace_dependencies(context), packages)
  local _, write_error = write_workspace_dependencies(context, updated)
  if write_error ~= nil then
    tx_failed(context, write_error)
    return false
  end

  local result = run_lake(context, { "update" })
  if result == nil or result.success ~= true then
    tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "lake update failed"))
    return false
  end

  emit_event(context, "deleted", packages)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  if not ensure_available(context, true) then
    return false
  end

  begin_step(context, "update lake dependencies")
  local roots, workspace_error = ensure_workspace(context)
  if roots == nil then
    tx_failed(context, workspace_error)
    return false
  end

  local result = run_lake(context, { "update" })
  if result == nil or result.success ~= true then
    tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "lake update failed"))
    return false
  end

  emit_event(context, "updated", packages or {})
  tx_success(context)
  return true
end

function plugin.list(context)
  local dependencies = read_workspace_dependencies(context)
  local manifest, manifest_error = manifest_package_lookup(context)
  if manifest_error ~= nil then
    log_warn(context, manifest_error)
  end
  local items = {}
  for _, dep in ipairs(dependencies) do
    items[#items + 1] = local_item_from_dependency(context, dep, manifest)
  end
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  local items = {}
  emit_event(context, "outdated", items)
  return items
end

function plugin.search(context, prompt)
  local query = trim(prompt)
  if query == "" then
    emit_event(context, "searched", {})
    return {}
  end

  local html, fetch_error = fetch_reservoir_search(context, query)
  if html == nil then
    log_warn(context, fetch_error)
    emit_event(context, "searched", {})
    return {}
  end

  local installed = installed_lookup(context)
  local ids = parse_reservoir_search_ids(html)
  local items = {}
  local limit = math.min(#ids, 10)
  for index = 1, limit do
    local remote = nil
    local page_html = select(1, fetch_reservoir_package_page(context, ids[index].packageId))
    if type(page_html) == "string" then
      remote = parse_reservoir_package_page(page_html, ids[index].packageId)
    else
      remote = {
        name = ids[index].name,
        packageId = ids[index].packageId,
        packageType = "lake-package",
        type = "package",
        installed = false,
        status = "available",
        summary = ids[index].packageId,
        description = ids[index].packageId,
        extraFields = { scope = ids[index].scope },
      }
    end
    local local_item = installed[lower(ids[index].packageId)] or installed[lower(ids[index].name)]
    items[#items + 1] = merge_items(local_item, remote)
  end

  emit_event(context, "searched", items)
  return items
end

function plugin.info(context, name)
  local query = trim(name or read_field(read_field(context, "request") or {}, "prompt") or "")
  if query == "" then
    emit_event(context, "informed", {})
    return {}
  end

  local installed = installed_lookup(context)
  local normalized = normalize_package_ref(query)
  local local_item = installed[lower(normalized.packageId or "")] or installed[lower(normalized.name or "")]
  local remote_item = remote_info_item(context, query)
  local item = merge_items(local_item, remote_item)
  if item == nil then
    item = local_item or {}
  end
  emit_event(context, "informed", item)
  return item
end

function plugin.resolvePackage(context, package)
  if package == nil then
    return nil
  end
  local request = normalized_request_package(package)
  if request.name == nil then
    return nil
  end
  local item = plugin.info(context, request.packageId or request.name)
  if type(item) ~= "table" or next(item) == nil then
    return nil
  end
  return item
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "exec", "network", "filesystem.read", "filesystem.write" },
    ecosystemScopes = { "lean", "lake", "reservoir" },
    writeScopes = {
      { kind = "user-home-subpath", value = ".local/share/reqpack/lake" },
      { kind = "user-home-subpath", value = ".cache/reqpack/lake" },
    },
    networkScopes = {
      { host = "reservoir.lean-lang.org", scheme = "https", pathPrefix = "/" },
    },
    privilegeLevel = "none",
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
