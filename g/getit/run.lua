plugin = {}

local PLUGIN_ID = "getit"
local PLUGIN_NAME = "GetIt"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "GetItCmd.exe"
local PACKAGE_TYPE = "delphi-package"

plugin.fileExtensions = { ".json", ".zip" }

local function trim(value)
  return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
  return string.lower(tostring(value or ""))
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

local function getenv(name)
  if os ~= nil and type(os.getenv) == "function" then
    return os.getenv(name)
  end
  return nil
end

local function expand_placeholders(value)
  local text = tostring(value or "")
  local fixture_root = trim(getenv("REQPACK_TEST_FIXTURE_ROOT") or "")
  if fixture_root ~= "" then
    text = text:gsub("%$%{fixtureRoot%}", fixture_root)
  end
  return text
end

local function is_safe_token(value)
  return tostring(value or ""):match("^[A-Za-z0-9_./:@%%+=,%-%[%]~\\]+$") ~= nil
end

local function shell_quote(value)
  local text = expand_placeholders(value)
  if is_safe_token(text) then
    return text
  end
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function force_shell_quote(value)
  local text = expand_placeholders(value)
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function split_lines(value)
  local lines = {}
  local text = tostring(value or ""):gsub("\r\n", "\n")
  if text == "" then
    return lines
  end
  for line in (text .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
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

local function package_error(context, message, unavailable_payload)
  tx_failed(context, message)
  emit_event(context, "failed", message)
  if unavailable_payload ~= nil then
    emit_event(context, "unavailable", unavailable_payload)
  end
  return false
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

local function join_path(...)
  local parts = {}
  for index = 1, select("#", ...) do
    local part = trim(expand_placeholders(select(index, ...)))
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

local function is_test_fixture_path(path)
  local text = tostring(path or "")
  if text:find("${fixtureRoot}", 1, true) ~= nil then
    return true
  end
  return trim(getenv("REQPACK_TEST_FIXTURE_ROOT") or "") ~= ""
end

local function command_ok(ok, _, code)
  if ok == true then
    return true
  end
  if type(ok) == "number" then
    return ok == 0
  end
  return code == 0
end

local function ensure_directory(path)
  local dir = trim(path)
  if dir == "" or dir == "." then
    return true
  end
  if is_test_fixture_path(dir) then
    return true
  end
  if os == nil or type(os.execute) ~= "function" then
    return false
  end
  local ok, kind, code = os.execute("mkdir -p " .. shell_quote(dir))
  return command_ok(ok, kind, code)
end

local function read_file(path)
  local target = expand_placeholders(path)
  local handle = io.open(target, "r")
  if handle ~= nil then
    local content = handle:read("*a")
    handle:close()
    return content
  end
  local result = exec_run(nil, "cat " .. force_shell_quote(path))
  if result ~= nil and result.success == true then
    return result.stdout
  end
  return nil
end

local function write_file(path, content)
  local target = expand_placeholders(path)
  local dir = parent_dir(target)
  if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
    if not is_test_fixture_path(target) then
      return false
    end
  end
  local handle = io.open(target, "w")
  if handle == nil then
    if is_test_fixture_path(target) then
      return true
    end
    return false
  end
  handle:write(content)
  handle:close()
  return true
end

local function json_error(message, index)
  error("invalid json at offset " .. tostring(index) .. ": " .. message)
end

local function json_decode(input)
  local source = tostring(input or "")
  local index = 1

  local function peek(offset)
    return source:sub(index + (offset or 0), index + (offset or 0))
  end

  local function advance(count)
    index = index + (count or 1)
  end

  local function skip_whitespace()
    while true do
      local char = peek()
      if char == " " or char == "\n" or char == "\r" or char == "\t" then
        advance(1)
      else
        return
      end
    end
  end

  local parse_value

  local function parse_string()
    if peek() ~= '"' then
      json_error("expected string", index)
    end
    advance(1)
    local parts = {}
    while true do
      local char = peek()
      if char == "" then
        json_error("unterminated string", index)
      elseif char == '"' then
        advance(1)
        return table.concat(parts)
      elseif char == "\\" then
        local escape = peek(1)
        if escape == '"' or escape == "\\" or escape == "/" then
          parts[#parts + 1] = escape
          advance(2)
        elseif escape == "b" then
          parts[#parts + 1] = "\b"
          advance(2)
        elseif escape == "f" then
          parts[#parts + 1] = "\f"
          advance(2)
        elseif escape == "n" then
          parts[#parts + 1] = "\n"
          advance(2)
        elseif escape == "r" then
          parts[#parts + 1] = "\r"
          advance(2)
        elseif escape == "t" then
          parts[#parts + 1] = "\t"
          advance(2)
        elseif escape == "u" then
          local hex = source:sub(index + 2, index + 5)
          if not hex:match("^%x%x%x%x$") then
            json_error("invalid unicode escape", index)
          end
          local codepoint = tonumber(hex, 16)
          if utf8 ~= nil and type(utf8.char) == "function" then
            parts[#parts + 1] = utf8.char(codepoint)
          elseif codepoint < 128 then
            parts[#parts + 1] = string.char(codepoint)
          else
            json_error("unicode escape unsupported without utf8 library", index)
          end
          advance(6)
        else
          json_error("invalid escape sequence", index)
        end
      else
        parts[#parts + 1] = char
        advance(1)
      end
    end
  end

  local function parse_number()
    local start = index
    if peek() == "-" then
      advance(1)
    end
    local char = peek()
    if char == "0" then
      advance(1)
    elseif char:match("%d") then
      repeat
        advance(1)
        char = peek()
      until not char:match("%d")
    else
      json_error("invalid number", index)
    end
    if peek() == "." then
      advance(1)
      if not peek():match("%d") then
        json_error("invalid fraction", index)
      end
      repeat
        advance(1)
        char = peek()
      until not char:match("%d")
    end
    char = peek()
    if char == "e" or char == "E" then
      advance(1)
      char = peek()
      if char == "+" or char == "-" then
        advance(1)
      end
      if not peek():match("%d") then
        json_error("invalid exponent", index)
      end
      repeat
        advance(1)
        char = peek()
      until not char:match("%d")
    end
    return tonumber(source:sub(start, index - 1))
  end

  local function parse_array()
    advance(1)
    skip_whitespace()
    local result = {}
    if peek() == "]" then
      advance(1)
      return result
    end
    while true do
      result[#result + 1] = parse_value()
      skip_whitespace()
      local char = peek()
      if char == "," then
        advance(1)
        skip_whitespace()
      elseif char == "]" then
        advance(1)
        return result
      else
        json_error("expected ',' or ']'", index)
      end
    end
  end

  local function parse_object()
    advance(1)
    skip_whitespace()
    local result = {}
    if peek() == "}" then
      advance(1)
      return result
    end
    while true do
      local key = parse_string()
      skip_whitespace()
      if peek() ~= ":" then
        json_error("expected ':'", index)
      end
      advance(1)
      skip_whitespace()
      result[key] = parse_value()
      skip_whitespace()
      local char = peek()
      if char == "," then
        advance(1)
        skip_whitespace()
      elseif char == "}" then
        advance(1)
        return result
      else
        json_error("expected ',' or '}'", index)
      end
    end
  end

  function parse_value()
    skip_whitespace()
    local char = peek()
    if char == '"' then
      return parse_string()
    elseif char == "{" then
      return parse_object()
    elseif char == "[" then
      return parse_array()
    elseif char == "-" or char:match("%d") then
      return parse_number()
    elseif source:sub(index, index + 3) == "true" then
      advance(4)
      return true
    elseif source:sub(index, index + 4) == "false" then
      advance(5)
      return false
    elseif source:sub(index, index + 3) == "null" then
      advance(4)
      return nil
    end
    json_error("unexpected token", index)
  end

  local result = parse_value()
  skip_whitespace()
  if index <= #source then
    json_error("unexpected trailing characters", index)
  end
  return result
end

local function is_array_table(value)
  if type(value) ~= "table" then
    return false
  end
  local max_index = 0
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or math.floor(key) ~= key then
      return false
    end
    if key > max_index then
      max_index = key
    end
    count = count + 1
  end
  return max_index == count
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

local function sorted_keys(table_value)
  local keys = {}
  for key in pairs(table_value or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(left, right)
    return tostring(left) < tostring(right)
  end)
  return keys
end

local function json_encode(value)
  if value == nil then
    return "null"
  end
  local value_type = type(value)
  if value_type == "string" then
    return '"' .. json_escape(value) .. '"'
  end
  if value_type == "number" or value_type == "boolean" then
    return tostring(value)
  end
  if value_type ~= "table" then
    return '"' .. json_escape(tostring(value)) .. '"'
  end
  if is_array_table(value) then
    local items = {}
    for index = 1, #value do
      items[#items + 1] = json_encode(value[index])
    end
    return "[" .. table.concat(items, ",") .. "]"
  end
  local pairs_json = {}
  for _, key in ipairs(sorted_keys(value)) do
    pairs_json[#pairs_json + 1] = json_encode(tostring(key)) .. ":" .. json_encode(value[key])
  end
  return "{" .. table.concat(pairs_json, ",") .. "}"
end

local function read_flags(value)
  if type(value) ~= "table" and type(value) ~= "userdata" then
    return {}
  end
  local flags = {}
  local ok = pcall(function()
    for _, item in ipairs(value) do
      local cleaned = trim(item)
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

local function append_unique(list, value, seen)
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
    for _, flag in ipairs(read_flags(read_field(object, "flags"))) do
      append_unique(flags, flag, seen)
    end
  end

  collect_from(context)
  collect_from(read_field(context, "request"))
  collect_from(package)
  return flags
end

local function flag_value(flags, name)
  local prefix = lower(trim(name)) .. "="
  for _, flag in ipairs(flags or {}) do
    local cleaned = trim(flag)
    if lower(cleaned):sub(1, #prefix) == prefix then
      return trim(expand_placeholders(cleaned:sub(#prefix + 1)))
    end
  end
  return nil
end

local function has_flag(flags, name)
  local wanted = lower(trim(name))
  for _, flag in ipairs(flags or {}) do
    if lower(trim(flag)) == wanted then
      return true
    end
  end
  return false
end

local function request_packages(context, packages)
  if (type(packages) == "table" or type(packages) == "userdata") and #packages > 0 then
    return packages
  end
  local request = read_field(context, "request")
  local request_packages_value = read_field(request, "packages")
  if type(request_packages_value) == "table" or type(request_packages_value) == "userdata" then
    return request_packages_value
  end
  return packages or {}
end

local function package_name(package)
  return trim(read_field(package, "name") or read_field(package, "packageId") or read_field(package, "id"))
end

local function package_action(package, fallback)
  return lower(trim(read_field(package, "action") or fallback or "install"))
end

local function request_local_path(context, explicit_path)
  local request = read_field(context, "request")
  return trim(expand_placeholders(
    explicit_path
    or read_field(context, "localPath")
    or read_field(request, "localPath")
    or read_field(context, "path")
    or read_field(request, "path")
    or ""
  ))
end

local function home_dir()
  return first_nonempty(getenv("HOME"), getenv("USERPROFILE"), "/home/test")
end

local function documents_root()
  return first_nonempty(getenv("USERPROFILE") and join_path(getenv("USERPROFILE"), "Documents") or nil, join_path(home_dir(), "Documents"))
end

local function cache_root(context, package)
  local flags = collect_flags(context, package)
  local explicit = flag_value(flags, "cache-root")
  if explicit ~= nil then
    return explicit
  end
  local env_root = first_nonempty(getenv("GETIT_CATALOG_REPOSITORY"), getenv("BDSCATALOGREPOSITORY"))
  if env_root ~= nil then
    return env_root
  end
  local version = first_nonempty(getenv("BDS_VERSION"), getenv("BDSVER"), "12.0")
  return join_path(documents_root(), "Embarcadero", "Studio", version, "CatalogRepository")
end

local function state_paths(context, package)
  local root = cache_root(context, package)
  local plugin_root = join_path(root, "reqpack-getit")
  return {
    root = root,
    plugin_root = plugin_root,
    installed_cache = join_path(plugin_root, "installed-cache.json"),
  }
end

local function search_cache_path(paths, prompt)
  local key = lower(trim(prompt or ""))
  key = key:gsub("[^%w%._%-]+", "_")
  if key == "" then
    key = "empty"
  end
  return join_path(paths.plugin_root, "search-cache-" .. key .. ".json")
end

local function write_cached_items(path, items)
  return write_file(path, json_encode(items) .. "\n")
end

local function read_cached_items(path)
  local content = read_file(path)
  if content == nil or trim(content) == "" then
    return nil
  end
  local ok, decoded = pcall(json_decode, content)
  if not ok or type(decoded) ~= "table" then
    return nil
  end
  return decoded
end

local function binary_candidate(context, package)
  local flags = collect_flags(context, package)
  return first_nonempty(
    flag_value(flags, "binary"),
    getenv("GETITCMD_PATH"),
    getenv("BDS") and join_path(getenv("BDS"), "bin", REQUIRED_BINARY) or nil,
    REQUIRED_BINARY
  )
end

local function command_exists(context, binary)
  local value = trim(binary)
  if value == "" then
    return false
  end
  local command = nil
  if value:find("/", 1, true) ~= nil or value:find("\\", 1, true) ~= nil or value:find(":", 1, true) ~= nil then
    command = "test -x " .. force_shell_quote(value)
  else
    command = "command -v " .. force_shell_quote(value) .. " >/dev/null 2>&1"
  end
  local result = exec_run(context, command)
  return result ~= nil and result.success == true
end

local function ensure_available(context, package, fatal)
  local binary = binary_candidate(context, package)
  if command_exists(context, binary) then
    return binary
  end
  local message = REQUIRED_BINARY .. " binary not available"
  if fatal then
    tx_failed(context, message)
    emit_event(context, "failed", message)
  else
    log_warn(context, message)
    emit_event(context, "unavailable", { reason = "getitcmd-not-installed" })
  end
  return nil
end

local function build_common_args(context, package)
  local flags = collect_flags(context, package)
  local args = {}
  local verbose = flag_value(flags, "verbose")
  if verbose ~= nil then
    args[#args + 1] = shell_quote("-v=" .. verbose)
  end
  if has_flag(flags, "donotsetenvfile") then
    args[#args + 1] = "-dnsef"
  end
  return args
end

local function build_getit_command(context, package, extra_args)
  local binary = binary_candidate(context, package)
  local parts = { force_shell_quote(binary) }
  for _, arg in ipairs(build_common_args(context, package)) do
    parts[#parts + 1] = arg
  end
  for _, arg in ipairs(extra_args or {}) do
    parts[#parts + 1] = arg
  end
  return table.concat(parts, " ")
end

local function split_columns(line)
  local columns = {}
  local text = tostring(line or "")
  if text:find("\t", 1, true) ~= nil then
    for field in text:gmatch("[^\t]+") do
      columns[#columns + 1] = trim(field)
    end
    return columns
  end
  local padded = text:gsub("%s%s+", "\t")
  for field in padded:gmatch("[^\t]+") do
    columns[#columns + 1] = trim(field)
  end
  return columns
end

local function item_id_version(item_id)
  local text = trim(item_id)
  if text == "" then
    return ""
  end
  local segments = {}
  for segment in text:gmatch("[^%-]+") do
    segments[#segments + 1] = segment
  end
  local version_parts = {}
  for index = #segments, 1, -1 do
    local segment = trim(segments[index])
    if segment:match("^%d[%w%.]*$") ~= nil then
      table.insert(version_parts, 1, segment)
    elseif #version_parts > 0 then
      break
    end
  end
  if #version_parts == 0 then
    return ""
  end
  return table.concat(version_parts, "-")
end

local function item_id_name(item_id)
  local text = trim(item_id)
  local version = item_id_version(text)
  if version == "" then
    return text
  end
  local suffix = "-" .. version
  if text:sub(-#suffix) == suffix then
    return text:sub(1, #text - #suffix)
  end
  return text
end

local function looks_like_data_line(line)
  local cleaned = trim(line)
  if cleaned == "" then
    return false
  end
  if cleaned:match("^[-=]+$") ~= nil then
    return false
  end
  local first = cleaned:match("^(%S+)")
  if first == nil then
    return false
  end
  local lowered = lower(cleaned)
  if lowered:find("available commands", 1, true) ~= nil then
    return false
  end
  if first == "ID" or first == "Id" or first == "Name" or first == "Vendor" or first == "Date" then
    return false
  end
  if first:sub(1, 1) == "-" then
    return false
  end
  return first:match("^[%w_][%w%._%-]+$") ~= nil
end

local function parse_item_line(line, installed)
  if not looks_like_data_line(line) then
    return nil
  end
  local columns = split_columns(line)
  local item_id = trim(columns[1])
  if item_id == "" then
    return nil
  end
  local name = first_nonempty(columns[2], item_id_name(item_id), item_id)
  local vendor = columns[3]
  local updated = columns[4]
  local version = item_id_version(item_id)
  local summary = nil
  if #columns > 4 then
    summary = trim(table.concat(columns, " ", 5))
  elseif #columns == 2 and name ~= item_id then
    summary = trim(columns[2])
  end
  return {
    type = "package",
    name = name,
    packageId = item_id,
    version = version ~= "" and version or nil,
    latestVersion = version ~= "" and version or nil,
    packageType = PACKAGE_TYPE,
    installed = installed,
    status = installed and "installed" or "available",
    summary = summary,
    description = summary,
    vendor = vendor,
    updatedAt = updated,
    extraFields = {
      rawLine = line,
      parsedColumns = columns,
    },
  }
end

local function parse_list_output(raw, installed)
  local items = {}
  local seen = {}
  for _, line in ipairs(split_lines(raw)) do
    local item = parse_item_line(line, installed)
    if item ~= nil and not seen[lower(item.packageId)] then
      seen[lower(item.packageId)] = true
      items[#items + 1] = item
    end
  end
  return items
end

local function installed_lookup(items)
  local lookup = {}
  for _, item in ipairs(items or {}) do
    lookup[lower(item.packageId or item.name or "")] = item
    lookup[lower(item.name or "")] = lookup[lower(item.name or "")] or item
  end
  return lookup
end

local function query_items(context, prompt, filter_value, write_cache)
  local binary = ensure_available(context, nil, false)
  if binary == nil then
    return {}, "binary-not-available"
  end
  local cleaned_prompt = trim(prompt or "")
  local command = build_getit_command(context, nil, {
    shell_quote("-l=" .. cleaned_prompt),
    shell_quote("-f=" .. filter_value),
    shell_quote("-s=name"),
  })
  local result = exec_run(context, command)
  if result == nil or result.success ~= true then
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "GetIt list failed")
  end
  local items = parse_list_output(result.stdout, filter_value == "installed")
  local paths = state_paths(context, nil)
  if write_cache then
    local cache_path = filter_value == "installed" and paths.installed_cache or search_cache_path(paths, cleaned_prompt)
    write_cached_items(cache_path, items)
  end
  return items, nil
end

local function cached_or_query_installed(context)
  local paths = state_paths(context, nil)
  local cached = read_cached_items(paths.installed_cache)
  if cached ~= nil then
    return cached, nil
  end
  return query_items(context, "", "installed", true)
end

local function best_match(items, query)
  local wanted = lower(trim(query))
  if wanted == "" then
    return nil
  end
  local partial_match = nil
  for _, item in ipairs(items or {}) do
    if lower(item.packageId or "") == wanted then
      return item
    end
    if lower(item.name or "") == wanted then
      return item
    end
    if partial_match == nil then
      local package_id = lower(item.packageId or "")
      local name = lower(item.name or "")
      if package_id:find(wanted, 1, true) ~= nil or name:find(wanted, 1, true) ~= nil then
        partial_match = item
      end
    end
  end
  return partial_match
end

local function make_requested_item(package, status)
  local item_id = package_name(package)
  return {
    type = "package",
    name = item_id_name(item_id),
    packageId = item_id,
    version = item_id_version(item_id) ~= "" and item_id_version(item_id) or nil,
    latestVersion = item_id_version(item_id) ~= "" and item_id_version(item_id) or nil,
    packageType = PACKAGE_TYPE,
    installed = status ~= "available",
    status = status or "installed",
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
  return { "Delphi", "RAD Studio", "Package Manager" }
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
    capabilities = { "exec" },
    ecosystemScopes = { "delphi", "rad-studio", "getit" },
    writeScopes = {
      { kind = "user-home-subpath", path = "Documents/Embarcadero/Studio" },
    },
    networkScopes = { "*" },
    privilegeLevel = "user",
    purlType = "generic",
    versionComparatorProfile = "lexicographic",
  }
end

function plugin.getMissingPackages(packages)
  local requested = request_packages(nil, packages)
  if #requested == 0 then
    return {}
  end
  local installed_items, err = cached_or_query_installed(nil)
  if installed_items == nil then
    return requested
  end
  local installed = installed_lookup(installed_items)
  local missing = {}
  for _, package in ipairs(requested) do
    local item_id = package_name(package)
    local action = package_action(package)
    local present = installed[lower(item_id)] ~= nil
    if item_id ~= "" then
      if action == "remove" then
        if present then
          missing[#missing + 1] = package
        end
      elseif action == "update" then
        if not present then
          missing[#missing + 1] = package
        end
      elseif not present then
        missing[#missing + 1] = package
      end
    end
  end
  return missing
end

function plugin.install(context, packages)
  local local_path = request_local_path(context)
  if local_path ~= "" then
    return plugin.installLocal(context, local_path)
  end
  local requested = request_packages(context, packages)
  local flags = collect_flags(context, nil)
  local binary = ensure_available(context, nil, true)
  if binary == nil then
    return false
  end
  if #requested == 0 then
    if has_flag(flags, "deferred") then
      begin_step(context, "install deferred GetIt packages")
      local result = exec_run(context, build_getit_command(context, nil, { "-id" }))
      if result == nil or result.success ~= true then
        return package_error(context, first_nonempty(result and result.stderr, result and result.stdout, "GetIt deferred install failed"))
      end
      emit_event(context, "installed", {})
      tx_success(context)
      return true
    end
    tx_success(context)
    return true
  end
  local installed = {}
  begin_step(context, "install GetIt packages")
  for _, package in ipairs(requested) do
    local item_id = package_name(package)
    if item_id == "" then
      return package_error(context, "GetIt install failed: missing package id")
    end
    local result = exec_run(context, build_getit_command(context, package, {
      "-ae",
      shell_quote("-i=" .. item_id),
    }))
    if result == nil or result.success ~= true then
      return package_error(context, first_nonempty(result and result.stderr, result and result.stdout, "GetIt install failed for " .. item_id))
    end
    installed[#installed + 1] = make_requested_item(package, "installed")
  end
  emit_event(context, "installed", installed)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  local local_path = request_local_path(context, path)
  return package_error(context, "GetIt local installs are not supported; use IDE Load Local Package flow", {
    path = local_path,
    reason = "local-install-unsupported",
  })
end

function plugin.remove(context, packages)
  local requested = request_packages(context, packages)
  local binary = ensure_available(context, nil, true)
  if binary == nil then
    return false
  end
  if #requested == 0 then
    tx_success(context)
    return true
  end
  local deleted = {}
  begin_step(context, "remove GetIt packages")
  for _, package in ipairs(requested) do
    local item_id = package_name(package)
    if item_id == "" then
      return package_error(context, "GetIt remove failed: missing package id")
    end
    local result = exec_run(context, build_getit_command(context, package, {
      shell_quote("-u=" .. item_id),
    }))
    if result == nil or result.success ~= true then
      return package_error(context, first_nonempty(result and result.stderr, result and result.stdout, "GetIt remove failed for " .. item_id))
    end
    deleted[#deleted + 1] = make_requested_item(package, "available")
  end
  emit_event(context, "deleted", deleted)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  local requested = request_packages(context, packages)
  local binary = ensure_available(context, nil, true)
  if binary == nil then
    return false
  end
  begin_step(context, "update GetIt packages")
  if #requested == 0 then
    emit_event(context, "updated", {})
    tx_success(context)
    return true
  end
  local updated = {}
  for _, package in ipairs(requested) do
    local item_id = package_name(package)
    if item_id == "" then
      return package_error(context, "GetIt update failed: missing package id")
    end
    local result = exec_run(context, build_getit_command(context, package, {
      "-ae",
      shell_quote("-i=" .. item_id),
    }))
    if result == nil or result.success ~= true then
      return package_error(context, first_nonempty(result and result.stderr, result and result.stdout, "GetIt update failed for " .. item_id))
    end
    updated[#updated + 1] = make_requested_item(package, "installed")
  end
  emit_event(context, "updated", updated)
  tx_success(context)
  return true
end

function plugin.list(context)
  local items, err = query_items(context, "", "installed", true)
  if items == nil then
    log_warn(context, err)
    items = {}
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
    query = trim(read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
  end
  if query == "" then
    local empty = {}
    emit_event(context, "searched", empty)
    return empty
  end
  local items, err = query_items(context, query, "all", true)
  if items == nil then
    log_warn(context, err)
    items = {}
  end
  emit_event(context, "searched", items)
  return items
end

function plugin.info(context, name)
  local query = trim(name)
  if query == "" then
    query = trim(read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
  end
  if query == "" then
    emit_event(context, "informed", {})
    return {}
  end

  local installed_items = select(1, cached_or_query_installed(context)) or {}
  local item = best_match(installed_items, query)
  if item == nil then
    local paths = state_paths(context, nil)
    local cached_search = read_cached_items(search_cache_path(paths, query))
    item = best_match(cached_search or {}, query)
    if item == nil then
      local searched, err = query_items(context, query, "all", true)
      if searched == nil then
        log_warn(context, err)
      else
        item = best_match(searched, query)
      end
    end
  end

  if item == nil then
    emit_event(context, "unavailable", { name = query, reason = "not-found" })
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
  local query = package_name(package)
  if query == "" then
    return package
  end
  local item = plugin.info(context, query)
  if type(item) == "table" and next(item) ~= nil then
    local merged = shallow_copy(type(package) == "table" and package or {})
    for key, value in pairs(item) do
      merged[key] = value
    end
    return merged
  end
  return package
end

return plugin
