plugin = {}

local PLUGIN_NAME = "OCX"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "ocx"
local JSON_NULL = {}

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
    merged[key] = value
  end
  return merged
end

local function runtime_expand(value)
  local text = tostring(value or "")
  local fixture_root = ""
  if os ~= nil and type(os.getenv) == "function" then
    fixture_root = trim(os.getenv("REQPACK_TEST_FIXTURE_ROOT") or os.getenv("fixtureRoot") or "")
  end
  if fixture_root ~= "" then
    text = text:gsub("%${fixtureRoot}", fixture_root)
  end
  return text
end

local function split_lines(value)
  local lines = {}
  for line in tostring(value or ""):gmatch("[^\r\n]+") do
    lines[#lines + 1] = line
  end
  return lines
end

local function starts_with(value, prefix)
  local text = tostring(value or "")
  return text:sub(1, #prefix) == prefix
end

local function shell_arg(parts, value)
  local cleaned = trim(runtime_expand(value))
  if cleaned ~= "" then
    parts[#parts + 1] = shell_quote(cleaned)
  end
end

local function join_path(...)
  local parts = {}
  for index = 1, select("#", ...) do
    local value = trim(runtime_expand(select(index, ...) or ""))
    if value ~= "" then
      if #parts == 0 then
        parts[#parts + 1] = value:gsub("/+$", "")
      else
        parts[#parts + 1] = value:gsub("^/", ""):gsub("/+$", "")
      end
    end
  end
  if #parts == 0 then
    return "."
  end
  return table.concat(parts, "/")
end

local function dirname(path)
  local cleaned = trim(runtime_expand(path))
  local parent = cleaned:match("^(.*)/[^/]+$")
  if parent ~= nil and parent ~= "" then
    return parent
  end
  if starts_with(cleaned, "/") then
    return "/"
  end
  return "."
end

local function basename(path)
  local cleaned = trim(runtime_expand(path))
  return cleaned:match("([^/]+)$") or cleaned
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

local function read_text_file(path)
  local expanded = runtime_expand(path)
  local handle = io.open(expanded, "rb")
  if handle == nil then
    return nil
  end
  local content = handle:read("*a")
  handle:close()
  return content
end

local function read_text_file_with_fallback(context, path)
  local content = read_text_file(path)
  if content ~= nil then
    return content
  end
  local result = exec_run(context, "cat " .. shell_quote(runtime_expand(path)))
  if result ~= nil and result.success == true then
    return result.stdout
  end
  return nil
end

local function path_exists(context, path)
  local result = exec_run(context, "test -e " .. shell_quote(path))
  return result ~= nil and result.success == true
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

local function request_object(context)
  return read_field(context, "request")
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

local function request_flags(context, package)
  local flags = {}
  local function collect(source)
    for _, item in ipairs(sequence_values(read_field(source, "flags"))) do
      local cleaned = trim(item)
      if cleaned ~= "" then
        flags[#flags + 1] = cleaned
      end
    end
  end
  collect(context)
  collect(request_object(context))
  collect(package)
  return flags
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

local function flag_value(flags, key)
  local prefix = lower(key) .. "="
  for _, flag in ipairs(flags or {}) do
    local cleaned = trim(flag)
    if lower(cleaned):sub(1, #prefix) == prefix then
      return trim(runtime_expand(cleaned:sub(#prefix + 1)))
    end
  end
  return nil
end

local function context_cwd(context, package)
  return first_nonempty(
    flag_value(request_flags(context, package), "cwd"),
    runtime_expand(read_field(request_object(context), "cwd")),
    runtime_expand(read_field(context, "cwd")),
    "."
  )
end

local function package_name(pkg)
  if type(pkg) == "string" then
    return non_empty(runtime_expand(pkg))
  end
  return first_nonempty(runtime_expand(read_field(pkg, "name")), runtime_expand(read_field(pkg, "packageId")))
end

local function parse_qualified_ref(value)
  local cleaned = trim(value)
  if cleaned == "" then
    return nil, nil
  end
  if cleaned:find("::", 1, true) ~= nil then
    local rest = cleaned:match("::(.+)$")
    if rest == nil then
      return nil, nil
    end
    local qualified = rest:match("^([^@]+)")
    if qualified == nil then
      return nil, nil
    end
    local slash = qualified:find("/", 1, true)
    if slash == nil then
      return nil, nil
    end
    return qualified:sub(1, slash - 1), qualified:sub(slash + 1)
  end
  local slash = cleaned:find("/", 1, true)
  if slash == nil then
    return nil, nil
  end
  return cleaned:sub(1, slash - 1), cleaned:sub(slash + 1)
end

local function strip_jsonc_comments(raw)
  local text = tostring(raw or "")
  local out = {}
  local index = 1
  local length = #text
  local in_string = false
  local escaped = false
  while index <= length do
    local char = text:sub(index, index)
    local next_char = text:sub(index + 1, index + 1)
    if in_string then
      out[#out + 1] = char
      if escaped then
        escaped = false
      elseif char == "\\" then
        escaped = true
      elseif char == '"' then
        in_string = false
      end
      index = index + 1
    elseif char == '"' then
      in_string = true
      out[#out + 1] = char
      index = index + 1
    elseif char == "/" and next_char == "/" then
      index = index + 2
      while index <= length do
        local line_char = text:sub(index, index)
        if line_char == "\n" or line_char == "\r" then
          out[#out + 1] = line_char
          index = index + 1
          break
        end
        index = index + 1
      end
    elseif char == "/" and next_char == "*" then
      index = index + 2
      while index <= length do
        local current = text:sub(index, index)
        local following = text:sub(index + 1, index + 1)
        if current == "*" and following == "/" then
          index = index + 2
          break
        end
        index = index + 1
      end
    else
      out[#out + 1] = char
      index = index + 1
    end
  end
  return table.concat(out)
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
    elseif current:match("%d") then
      repeat
        index = index + 1
        current = peek()
      until current == "" or not current:match("%d")
    else
      decode_error("invalid number")
    end
    current = peek()
    if current == "." then
      index = index + 1
      if not peek():match("%d") then
        decode_error("invalid number fraction")
      end
      repeat
        index = index + 1
        current = peek()
      until current == "" or not current:match("%d")
    end
    current = peek()
    if current == "e" or current == "E" then
      index = index + 1
      current = peek()
      if current == "+" or current == "-" then
        index = index + 1
      end
      if not peek():match("%d") then
        decode_error("invalid number exponent")
      end
      repeat
        index = index + 1
        current = peek()
      until current == "" or not current:match("%d")
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
        decode_error("expected ',' or ']' ")
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
        decode_error("expected ':'")
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
        decode_error("expected ',' or '}'")
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

  local parsed = parse_value()
  skip_whitespace()
  if index <= length then
    decode_error("trailing data")
  end
  return parsed
end

local function decode_json(raw)
  local ok, value = pcall(decode_json_internal, raw)
  if not ok then
    return nil, value
  end
  return value, nil
end

local function read_jsonc_file(context, path)
  local content = read_text_file_with_fallback(context, path)
  if content == nil then
    return nil, "missing file"
  end
  return decode_json(strip_jsonc_comments(content))
end

local function project_paths(context, package)
  local cwd = context_cwd(context, package)
  return {
    cwd = cwd,
    configPath = join_path(cwd, ".opencode", "ocx.jsonc"),
    receiptPath = join_path(cwd, ".ocx", "receipt.jsonc"),
  }
end

local function read_receipt(context, package)
  local paths = project_paths(context, package)
  local receipt, err = read_jsonc_file(context, paths.receiptPath)
  if receipt == nil then
    return nil, err, paths
  end
  return receipt, nil, paths
end

local function parse_canonical_id(canonical_id)
  local registry_url, rest = tostring(canonical_id or ""):match("^(.-)::(.+)$")
  if registry_url == nil or rest == nil then
    return nil
  end
  local qualified, revision = rest:match("^(.+)@(.+)$")
  if qualified == nil or revision == nil then
    return nil
  end
  local registry_name, component_name = qualified:match("^([^/]+)/(.+)$")
  if registry_name == nil or component_name == nil then
    return nil
  end
  return {
    registryUrl = registry_url,
    registryName = registry_name,
    name = component_name,
    revision = revision,
  }
end

local function receipt_entries(receipt)
  local items = {}
  local installed = type(receipt) == "table" and read_field(receipt, "installed") or nil
  if type(installed) ~= "table" then
    return items
  end
  for canonical_id, entry in pairs(installed) do
    if type(entry) == "table" then
      local parsed = parse_canonical_id(canonical_id)
      local registry_name = first_nonempty(parsed and parsed.registryName, read_field(entry, "registryName"))
      local component_name = first_nonempty(parsed and parsed.name, read_field(entry, "name"))
      local revision = first_nonempty(read_field(entry, "revision"), parsed and parsed.revision)
      items[#items + 1] = {
        canonicalId = canonical_id,
        registryUrl = first_nonempty(read_field(entry, "registryUrl"), parsed and parsed.registryUrl),
        registryName = registry_name,
        name = component_name,
        qualifiedName = first_nonempty(registry_name and component_name and (registry_name .. "/" .. component_name)),
        revision = revision,
        hash = read_field(entry, "hash"),
        installedAt = read_field(entry, "installedAt"),
        updatedAt = read_field(entry, "updatedAt"),
        files = read_field(entry, "files"),
        opencode = read_field(entry, "opencode"),
      }
    end
  end
  table.sort(items, function(left, right)
    return lower(left.canonicalId or "") < lower(right.canonicalId or "")
  end)
  return items
end

local function map_receipt_entry_to_item(entry)
  return {
    name = entry.qualifiedName,
    packageId = entry.canonicalId,
    version = entry.revision,
    latestVersion = entry.revision,
    installed = true,
    status = "installed",
    packageType = "ocx-component",
    type = "package",
    summary = "Installed OCX component " .. tostring(entry.qualifiedName or entry.name or ""),
    description = "Installed OCX component managed through local receipt",
    source = entry.registryUrl,
    repository = entry.registryName,
    updatedAt = first_nonempty(entry.updatedAt, entry.installedAt),
    extraFields = {
      canonicalId = entry.canonicalId,
      registryUrl = entry.registryUrl,
      registryName = entry.registryName,
      componentName = entry.name,
      fileCount = tostring(type(entry.files) == "table" and #entry.files or 0),
    },
  }
end

local function map_search_component(component)
  local name = first_nonempty(read_field(component, "name"))
  return {
    name = name,
    packageId = name,
    version = first_nonempty(read_field(component, "version")),
    summary = first_nonempty(read_field(component, "description")),
    description = first_nonempty(read_field(component, "description")),
    source = first_nonempty(read_field(component, "registry")),
    repository = first_nonempty(read_field(component, "registry")),
    packageType = first_nonempty(read_field(component, "type"), "ocx-component"),
    type = "package",
    installed = false,
    status = "available",
    extraFields = {
      registryName = first_nonempty(read_field(component, "registry")),
      componentType = first_nonempty(read_field(component, "type")),
    },
  }
end

local function decode_command_json(result)
  if result == nil or result.success ~= true then
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "command failed")
  end
  return decode_json(result.stdout or "")
end

local function build_ocx_command(context, package, subcommand, args)
  local parts = { REQUIRED_BINARY, subcommand }
  local flags = request_flags(context, package)
  local cwd = context_cwd(context, package)
  if cwd ~= "." then
    parts[#parts + 1] = "--cwd"
    shell_arg(parts, cwd)
  end
  if has_flag(flags, "json") or true then
    parts[#parts + 1] = "--json"
  end
  for _, arg in ipairs(args or {}) do
    parts[#parts + 1] = arg
  end
  return table.concat(parts, " ")
end

local function append_passthrough_flags(parts, flags, allowed)
  for _, key in ipairs(allowed) do
    if has_flag(flags, key) then
      parts[#parts + 1] = "--" .. key
    end
  end
end

local function append_keyed_flag(parts, flags, key)
  local value = flag_value(flags, key)
  if value ~= nil then
    parts[#parts + 1] = "--" .. key
    shell_arg(parts, value)
  end
end

local function command_for_add(context, package, ref)
  local flags = request_flags(context, package)
  local args = {}
  shell_arg(args, ref)
  append_passthrough_flags(args, flags, { "dry-run", "skip-compat-check", "trust", "global" })
  append_keyed_flag(args, flags, "profile")
  append_keyed_flag(args, flags, "from")
  return build_ocx_command(context, package, "add", args)
end

local function command_for_remove(context, package, ref)
  local flags = request_flags(context, package)
  local args = {}
  shell_arg(args, ref)
  append_passthrough_flags(args, flags, { "dry-run", "force" })
  return build_ocx_command(context, package, "remove", args)
end

local function command_for_update(context, package, ref, all_mode)
  local flags = request_flags(context, package)
  local args = {}
  if all_mode then
    args[#args + 1] = "--all"
    append_keyed_flag(args, flags, "registry")
  else
    shell_arg(args, ref)
  end
  append_passthrough_flags(args, flags, { "dry-run", "global" })
  return build_ocx_command(context, package, "update", args)
end

local function command_for_search(context, package, prompt, installed_only, limit)
  local args = {}
  if installed_only then
    args[#args + 1] = "--installed"
  elseif non_empty(prompt) ~= nil then
    shell_arg(args, prompt)
  end
  if limit ~= nil then
    args[#args + 1] = "--limit"
    shell_arg(args, tostring(limit))
  end
  local flags = request_flags(context, package)
  append_keyed_flag(args, flags, "profile")
  return build_ocx_command(context, package, "search", args)
end

local function find_receipt_entry(receipt, ref)
  local query = trim(ref)
  if query == "" then
    return nil
  end
  for _, entry in ipairs(receipt_entries(receipt)) do
    if entry.canonicalId == query or entry.qualifiedName == query then
      return entry
    end
  end
  local registry_name, component_name = parse_qualified_ref(query)
  if registry_name ~= nil then
    for _, entry in ipairs(receipt_entries(receipt)) do
      if entry.registryName == registry_name and entry.name == component_name then
        return entry
      end
    end
  end
  return nil
end

local function collect_installed_items(context, package)
  local receipt, receipt_err = read_receipt(context, package)
  if receipt ~= nil then
    local items = {}
    for _, entry in ipairs(receipt_entries(receipt)) do
      items[#items + 1] = map_receipt_entry_to_item(entry)
    end
    return items, nil
  end

  local paths = project_paths(context, package)
  if not path_exists(context, paths.configPath) then
    return {}, nil
  end

  local result = exec_run(context, command_for_search(context, package, nil, true, nil))
  local payload, decode_err = decode_command_json(result)
  if payload == nil then
    return {}, decode_err or receipt_err
  end
  local components = read_field(read_field(payload, "data"), "components")
  local items = {}
  for _, component in ipairs(sequence_values(components)) do
    items[#items + 1] = map_search_component(component)
    items[#items].installed = true
    items[#items].status = "installed"
  end
  return items, nil
end

local function exact_or_first(items, query)
  local cleaned = lower(query)
  for _, item in ipairs(items or {}) do
    if lower(item.name or "") == cleaned or lower(item.packageId or "") == cleaned then
      return item
    end
  end
  return items[1]
end

local function has_would_update(payload)
  for _, item in ipairs(sequence_values(read_field(payload, "updated"))) do
    if lower(read_field(item, "status") or "") == "would-update" then
      return item
    end
  end
  return nil
end

plugin.fileExtensions = {}

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
  return { "opencode", "package-manager", "component-manager" }
end

function plugin.getMissingPackages(packages)
  local requested = packages or {}
  if command_exists(nil, REQUIRED_BINARY) then
    return {}
  end
  local missing = {}
  for _, package in ipairs(requested) do
    local action = lower(read_field(package, "action") or "install")
    if action ~= "remove" and action ~= "update" then
      missing[#missing + 1] = package
    end
  end
  return missing
end

function plugin.install(context, packages)
  local requested = request_packages(context, packages)
  if #requested == 0 then
    return true
  end
  if not command_exists(context, REQUIRED_BINARY) then
    tx_failed(context, "ocx binary not available")
    return false
  end

  local installed = {}
  for _, package in ipairs(requested) do
    local ref = package_name(package)
    if ref == nil then
      tx_failed(context, "ocx package ref missing")
      return false
    end
    begin_step(context, "install OCX component " .. ref)
    local result = exec_run(context, command_for_add(context, package, ref))
    if result == nil or result.success ~= true then
      tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "ocx add failed"))
      return false
    end
    local receipt = select(1, read_receipt(context, package))
    local entry = receipt ~= nil and find_receipt_entry(receipt, ref) or nil
    installed[#installed + 1] = entry ~= nil and map_receipt_entry_to_item(entry) or {
      name = ref,
      packageId = ref,
      packageType = "ocx-component",
      type = "package",
      installed = true,
      status = "installed",
    }
  end
  emit_event(context, "installed", installed)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  begin_step(context, "install local OCX artifact")
  tx_failed(context, "ocx installLocal is not supported")
  return false
end

function plugin.remove(context, packages)
  local requested = request_packages(context, packages)
  if #requested == 0 then
    return true
  end
  if not command_exists(context, REQUIRED_BINARY) then
    tx_failed(context, "ocx binary not available")
    return false
  end
  local deleted = {}
  for _, package in ipairs(requested) do
    local ref = package_name(package)
    if ref == nil then
      tx_failed(context, "ocx package ref missing")
      return false
    end
    begin_step(context, "remove OCX component " .. ref)
    local result = exec_run(context, command_for_remove(context, package, ref))
    if result == nil or result.success ~= true then
      tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "ocx remove failed"))
      return false
    end
    deleted[#deleted + 1] = {
      name = ref,
      packageId = ref,
      packageType = "ocx-component",
      type = "package",
    }
  end
  emit_event(context, "deleted", deleted)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  local requested = request_packages(context, packages)
  if not command_exists(context, REQUIRED_BINARY) then
    tx_failed(context, "ocx binary not available")
    return false
  end
  local updated = {}
  if #requested == 0 then
    begin_step(context, "update OCX components")
    local result = exec_run(context, command_for_update(context, nil, nil, true))
    if result == nil or result.success ~= true then
      tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "ocx update failed"))
      return false
    end
    local items = plugin.list(context)
    emit_event(context, "updated", items)
    tx_success(context)
    return true
  end
  for _, package in ipairs(requested) do
    local ref = package_name(package)
    if ref == nil then
      tx_failed(context, "ocx package ref missing")
      return false
    end
    begin_step(context, "update OCX component " .. ref)
    local result = exec_run(context, command_for_update(context, package, ref, false))
    if result == nil or result.success ~= true then
      tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "ocx update failed"))
      return false
    end
    local receipt = select(1, read_receipt(context, package))
    local entry = receipt ~= nil and find_receipt_entry(receipt, ref) or nil
    updated[#updated + 1] = entry ~= nil and map_receipt_entry_to_item(entry) or {
      name = ref,
      packageId = ref,
      packageType = "ocx-component",
      type = "package",
    }
  end
  emit_event(context, "updated", updated)
  tx_success(context)
  return true
end

function plugin.list(context)
  local items, err = collect_installed_items(context, nil)
  if err ~= nil and #items == 0 then
    log_warn(context, "ocx list fallback failed: " .. tostring(err))
  end
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  local receipt = select(1, read_receipt(context, nil))
  if receipt == nil then
    emit_event(context, "outdated", {})
    return {}
  end
  if not command_exists(context, REQUIRED_BINARY) then
    emit_event(context, "outdated", {})
    return {}
  end
  local items = {}
  for _, entry in ipairs(receipt_entries(receipt)) do
    local result = exec_run(context, command_for_update(context, { flags = { "dry-run" } }, entry.qualifiedName, false))
    local payload = result ~= nil and result.success == true and select(1, decode_json(result.stdout or "")) or nil
    local update_entry = payload ~= nil and has_would_update(payload) or nil
    if update_entry ~= nil then
      local item = map_receipt_entry_to_item(entry)
      item.status = "outdated"
      item.latestVersion = first_nonempty(read_field(update_entry, "newVersion"), item.version)
      items[#items + 1] = item
    end
  end
  emit_event(context, "outdated", items)
  return items
end

function plugin.search(context, prompt)
  local cleaned = trim(prompt)
  if cleaned == "" then
    emit_event(context, "searched", {})
    return {}
  end
  if not command_exists(context, REQUIRED_BINARY) then
    log_warn(context, "ocx binary not available")
    emit_event(context, "searched", {})
    return {}
  end
  local result = exec_run(context, command_for_search(context, nil, cleaned, false, 20))
  local payload, err = decode_command_json(result)
  if payload == nil then
    log_warn(context, "ocx search failed: " .. tostring(err))
    emit_event(context, "searched", {})
    return {}
  end
  local components = read_field(read_field(payload, "data"), "components")
  local items = {}
  for _, component in ipairs(sequence_values(components)) do
    items[#items + 1] = map_search_component(component)
  end
  emit_event(context, "searched", items)
  return items
end

function plugin.info(context, name)
  local query = trim(name)
  if query == "" then
    emit_event(context, "informed", {})
    return {}
  end

  local receipt = select(1, read_receipt(context, nil))
  if receipt ~= nil then
    local entry = find_receipt_entry(receipt, query)
    if entry ~= nil then
      local item = map_receipt_entry_to_item(entry)
      emit_event(context, "informed", item)
      return item
    end
  end

  local items = plugin.search(context, query)
  local item = exact_or_first(items, query)
  if item == nil then
    emit_event(context, "informed", {})
    return {}
  end
  emit_event(context, "informed", item)
  return item
end

function plugin.resolvePackage(context, package)
  local ref = package_name(package)
  if ref == nil then
    return nil
  end
  local receipt = select(1, read_receipt(context, package))
  if receipt ~= nil then
    local entry = find_receipt_entry(receipt, ref)
    if entry ~= nil then
      return map_receipt_entry_to_item(entry)
    end
  end
  local registry_name, component_name = parse_qualified_ref(ref)
  return {
    name = ref,
    packageId = ref,
    packageType = "ocx-component",
    type = "package",
    extraFields = merge_tables({}, {
      registryName = registry_name,
      componentName = component_name,
    }),
  }
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
    ecosystemScopes = { "ocx", "opencode" },
    writeScopes = {
      { kind = "project-subpath", value = ".opencode" },
      { kind = "project-subpath", value = ".ocx" },
      { kind = "user-home-subpath", value = ".config/opencode" },
    },
    networkScopes = {},
    privilegeLevel = "user",
    purlType = "generic",
  }
end

return plugin
