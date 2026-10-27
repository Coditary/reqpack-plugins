plugin = {}

local PLUGIN_ID = "podman"
local PLUGIN_NAME = "Podman"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "podman"
local SEARCH_TTL = 120
local REMOTE_INFO_TTL = 120
local JSON_NULL = {}

plugin.fileExtensions = {
  ".tar",
  ".tgz",
  ".tar.gz",
  ".tar.xz",
  ".tar.zst",
  ".tar.bz2",
}

local function trim(value)
  return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
  return string.lower(tostring(value or ""))
end

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function first_nonempty(...)
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    if value ~= nil and value ~= JSON_NULL then
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

local function read_first_field(value, ...)
  for index = 1, select("#", ...) do
    local result = read_field(value, select(index, ...))
    if result ~= nil then
      return result
    end
  end
  return nil
end

local function json_value(value)
  if value == JSON_NULL then
    return nil
  end
  return value
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

local function encode_json_string(value)
  local text = tostring(value or "")
  local replacements = {
    ["\\"] = "\\\\",
    ['"'] = '\\"',
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
  }
  return '"' .. text:gsub('[%z\1-\31\\"]', function(char)
    return replacements[char] or string.format("\\u%04x", string.byte(char))
  end) .. '"'
end

local function sorted_string_keys(value)
  local keys = {}
  for key in pairs(value or {}) do
    keys[#keys + 1] = tostring(key)
  end
  table.sort(keys)
  return keys
end

local function encode_json(value)
  local value_type = type(value)
  if value == nil or value == JSON_NULL then
    return "null"
  end
  if value_type == "string" then
    return encode_json_string(value)
  end
  if value_type == "number" or value_type == "boolean" then
    return tostring(value)
  end
  if value_type ~= "table" then
    return encode_json_string(tostring(value))
  end

  if is_array_table(value) then
    local items = {}
    for index = 1, #value do
      items[#items + 1] = encode_json(value[index])
    end
    return "[" .. table.concat(items, ",") .. "]"
  end

  local pairs_json = {}
  for _, key in ipairs(sorted_string_keys(value)) do
    pairs_json[#pairs_json + 1] = encode_json_string(key) .. ":" .. encode_json(value[key])
  end
  return "{" .. table.concat(pairs_json, ",") .. "}"
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

local function split_lines(value)
  local lines = {}
  for line in tostring(value or ""):gmatch("[^\r\n]+") do
    lines[#lines + 1] = line
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

local function starts_with(value, prefix)
  local text = tostring(value or "")
  local expected = tostring(prefix or "")
  return expected == "" or text:sub(1, #expected) == expected
end

local function ends_with(value, suffix)
  local text = tostring(value or "")
  local expected = tostring(suffix or "")
  if expected == "" then
    return true
  end
  return text:sub(-#expected) == expected
end

local function join_path(...)
  local parts = {}
  for index = 1, select("#", ...) do
    local value = trim(select(index, ...) or "")
    if value ~= "" then
      if #parts == 0 then
        parts[#parts + 1] = value:gsub("/+$", "")
      else
        parts[#parts + 1] = value:gsub("^/+", ""):gsub("/+$", "")
      end
    end
  end
  if #parts == 0 then
    return "."
  end
  return table.concat(parts, "/")
end

local function parent_dir(path)
  return tostring(path or ""):match("^(.*)/[^/]+$")
end

local function read_file(path)
  local handle = io.open(path, "rb")
  if handle == nil then
    return nil
  end
  local content = handle:read("*a")
  handle:close()
  return content
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
  if os == nil or type(os.execute) ~= "function" then
    return false
  end
  local ok, kind, code = os.execute("mkdir -p " .. shell_quote(dir))
  return command_ok(ok, kind, code)
end

local function write_file(path, content)
  local dir = parent_dir(path)
  if dir ~= nil and dir ~= "" and not ensure_directory(dir) then
    return false
  end

  local handle = io.open(path, "wb")
  if handle == nil then
    return false
  end
  handle:write(content)
  handle:close()
  return true
end

local function epoch_now()
  if os ~= nil and type(os.time) == "function" then
    return os.time()
  end
  return 0
end

local function home_dir()
  if os ~= nil and type(os.getenv) == "function" then
    return first_nonempty(os.getenv("HOME"), ".")
  end
  return "."
end

local function cache_root()
  if os ~= nil and type(os.getenv) == "function" then
    local xdg = trim(os.getenv("XDG_CACHE_HOME") or "")
    if xdg ~= "" then
      return join_path(xdg, "reqpack", PLUGIN_ID)
    end
  end
  return join_path(home_dir(), ".cache", "reqpack", PLUGIN_ID)
end

local function cache_key(value)
  local normalized = lower(trim(value))
  if normalized == "" then
    normalized = "unknown"
  end
  return (normalized:gsub("[^%w%._%-]+", "_"))
end

local function read_timestamp(path)
  local content = trim(read_file(path) or "")
  local value = tonumber(content)
  if value == nil then
    return 0
  end
  return value
end

local function is_cache_fresh(ts_path, ttl)
  local timestamp = read_timestamp(ts_path)
  if timestamp <= 0 then
    return false
  end
  return (epoch_now() - timestamp) < ttl
end

local function cache_json_paths(kind, key)
  local base = join_path(cache_root(), "query", kind, cache_key(key))
  return base .. ".json", base .. ".ts"
end

local function read_cached_json(kind, key, ttl)
  local body_path, ts_path = cache_json_paths(kind, key)
  local cached = read_file(body_path)
  if cached == nil or not is_cache_fresh(ts_path, ttl) then
    return nil
  end
  return decode_json(cached)
end

local function write_cached_json(kind, key, value)
  local body_path, ts_path = cache_json_paths(kind, key)
  if not write_file(body_path, encode_json(value)) then
    return false
  end
  write_file(ts_path, tostring(epoch_now()))
  return true
end

local function cached_fetch_json(kind, key, ttl, fetcher)
  local cached = read_cached_json(kind, key, ttl)
  if cached ~= nil then
    return cached, nil
  end

  local fresh, err = fetcher()
  if fresh ~= nil then
    write_cached_json(kind, key, fresh)
    return fresh, nil
  end

  local body_path = cache_json_paths(kind, key)
  local stale_raw = read_file(body_path)
  if stale_raw ~= nil then
    local stale = decode_json(stale_raw)
    if stale ~= nil then
      return stale, nil
    end
  end

  return nil, err
end

local function trim_prefix(value, prefix)
  local text = tostring(value or "")
  local expected = tostring(prefix or "")
  if starts_with(text, expected) then
    return text:sub(#expected + 1)
  end
  return text
end

local function merge_extra_fields(left, right)
  local merged = shallow_copy(type(left) == "table" and left or {})
  for key, value in pairs(type(right) == "table" and right or {}) do
    if value ~= nil then
      merged[key] = value
    end
  end
  if next(merged) == nil then
    return nil
  end
  return merged
end

local function normalize_registry_repo(repository)
  local text = trim(repository)
  if text == "" then
    return nil
  end

  if text:match("^[^/]+%.[^/]+/.+$") ~= nil or text:match("^[^/]+:[^/]+/.+$") ~= nil or starts_with(text, "localhost/") then
    return text
  end

  local segments = {}
  for segment in text:gmatch("[^/]+") do
    segments[#segments + 1] = segment
  end

  if #segments == 0 then
    return text
  end

  local first = segments[1]
  local has_registry = first:find("%.", 1, true) ~= nil or first:find(":", 1, true) ~= nil or first == "localhost"
  if not has_registry then
    if #segments == 1 then
      return "docker.io/library/" .. segments[1]
    end
    return "docker.io/" .. text
  end

  return text
end

local function parse_reference(raw, default_tag)
  local text = trim(raw)
  if text == "" then
    return nil
  end

  local transport = nil
  local body = text
  local transport_match, rest = text:match("^([%a][%w%+%.%-]*)://(.+)$")
  if transport_match ~= nil then
    transport = transport_match
    body = rest
  end

  local digest = body:match("@([^@]+)$")
  local repository = body
  local tag = nil

  if digest ~= nil then
    repository = body:sub(1, #body - #digest - 1)
  else
    local last_slash = repository:match("^.*()/") or 0
    local last_colon = repository:match("^.*():") or 0
    if last_colon > last_slash then
      tag = repository:sub(last_colon + 1)
      repository = repository:sub(1, last_colon - 1)
    end
  end

  repository = normalize_registry_repo(repository)
  if repository == nil then
    return nil
  end

  if digest == nil and trim(tag) == "" then
    tag = default_tag or "latest"
  end

  local full_ref = digest ~= nil and (repository .. "@" .. digest) or (repository .. ":" .. tag)
  local pull_ref = transport ~= nil and (transport .. "://" .. full_ref) or full_ref
  local display_name = repository:match("([^/]+)$") or repository

  return {
    raw = text,
    transport = transport,
    repository = repository,
    tag = trim(tag or "") ~= "" and trim(tag) or nil,
    digest = trim(digest or "") ~= "" and trim(digest) or nil,
    fullRef = full_ref,
    pullRef = pull_ref,
    displayName = display_name,
  }
end

local function package_request_ref(pkg)
  local name = trim(read_field(pkg, "name") or read_field(pkg, "packageId") or "")
  local version = trim(read_field(pkg, "version") or "")
  if name == "" then
    return nil
  end
  if version ~= "" and name:find("@", 1, true) == nil and name:find(":", 1, true) == nil then
    name = name .. ":" .. version
  end
  return parse_reference(name, "latest")
end

local function version_from_ref(parsed, fallback)
  if parsed == nil then
    return fallback
  end
  return first_nonempty(parsed.tag, parsed.digest, fallback)
end

local function parse_bool_text(value)
  local text = lower(trim(value))
  return text == "[ok]" or text == "true" or text == "yes"
end

local function list_like(value)
  if type(value) ~= "table" then
    return {}
  end
  local result = {}
  for _, item in ipairs(value) do
    local text = trim(item)
    if text ~= "" then
      result[#result + 1] = text
    end
  end
  return result
end

local function first_named_image(names)
  for _, name in ipairs(list_like(names)) do
    if name ~= "<none>" then
      return name
    end
  end
  return nil
end

local function map_local_image(record)
  local names = list_like(read_first_field(record, "names", "Names"))
  local primary = first_named_image(names)
  local digest = first_nonempty(read_first_field(record, "digest", "Digest"))
  local image_id = first_nonempty(read_first_field(record, "id", "Id", "ID"))
  local created = first_nonempty(read_first_field(record, "created", "Created"))
  local size = read_first_field(record, "size", "Size")
  local parsed = parse_reference(primary or "", "latest")
  local package_id = first_nonempty(primary, digest ~= nil and ("sha256:" .. trim(trim_prefix(digest, "sha256:"))) or nil, image_id)
  local display_name = first_nonempty(parsed and parsed.displayName, package_id)

  return {
    name = display_name,
    packageId = package_id,
    version = first_nonempty(version_from_ref(parsed, nil), digest, image_id),
    latestVersion = first_nonempty(version_from_ref(parsed, nil), digest, image_id),
    type = "package",
    packageType = "container-image",
    installed = true,
    status = "installed",
    summary = package_id,
    description = package_id,
    updatedAt = created,
    extraFields = merge_extra_fields(nil, {
      imageId = image_id,
      digest = digest,
      repoTag = primary,
      registry = parsed and parsed.repository:match("^([^/]+)") or nil,
      repository = parsed and parsed.repository or nil,
      sizeBytes = size ~= nil and tostring(size) or nil,
      names = names,
    }),
  }
end

local function parse_label_table(record)
  local labels = read_first_field(record, "Labels")
  if type(labels) ~= "table" then
    local config = read_field(record, "Config")
    labels = type(config) == "table" and read_field(config, "Labels") or nil
  end
  if type(labels) ~= "table" then
    return {}
  end
  return labels
end

local function label_value(labels, ...)
  for index = 1, select("#", ...) do
    local key = select(index, ...)
    local value = first_nonempty(read_field(labels, key))
    if value ~= nil then
      return value
    end
  end
  return nil
end

local function map_inspect_info(record, requested_name)
  local repo_tags = list_like(read_first_field(record, "RepoTags", "repoTags"))
  local repo_digests = list_like(read_first_field(record, "RepoDigests", "repoDigests"))
  local digest = first_nonempty(read_first_field(record, "Digest", "digest"))
  local image_id = first_nonempty(read_first_field(record, "Id", "ID", "id"))
  local primary = first_nonempty(repo_tags[1], repo_digests[1], requested_name, image_id)
  local parsed = parse_reference(primary or requested_name or "", "latest")
  local labels = parse_label_table(record)
  local description = first_nonempty(
    label_value(labels, "org.opencontainers.image.description", "description"),
    primary
  )
  local homepage = first_nonempty(
    label_value(labels, "org.opencontainers.image.url", "url"),
    label_value(labels, "org.opencontainers.image.source", "source")
  )

  return {
    name = first_nonempty(parsed and parsed.displayName, primary, requested_name, image_id),
    packageId = first_nonempty(primary, image_id),
    version = first_nonempty(version_from_ref(parsed, nil), digest, image_id),
    latestVersion = first_nonempty(version_from_ref(parsed, nil), digest, image_id),
    type = "package",
    packageType = "container-image",
    installed = true,
    status = "installed",
    summary = description,
    description = description,
    homepage = homepage,
    sourceUrl = label_value(labels, "org.opencontainers.image.source", "source"),
    license = label_value(labels, "org.opencontainers.image.licenses", "license"),
    updatedAt = first_nonempty(read_first_field(record, "Created", "created")),
    extraFields = merge_extra_fields(nil, {
      imageId = image_id,
      digest = digest,
      repoTag = repo_tags[1],
      repoDigest = repo_digests[1],
      registry = parsed and parsed.repository:match("^([^/]+)") or nil,
      repository = parsed and parsed.repository or nil,
      transport = parsed and parsed.transport or nil,
      architecture = first_nonempty(read_first_field(record, "Architecture", "architecture")),
      os = first_nonempty(read_first_field(record, "Os", "os")),
      manifestType = first_nonempty(read_first_field(record, "ManifestType", "manifestType")),
      sizeBytes = read_first_field(record, "Size", "size") ~= nil and tostring(read_first_field(record, "Size", "size")) or nil,
    }),
  }
end

local function ensure_binary(context, fatal)
  if command_exists(context, REQUIRED_BINARY) then
    return true
  end

  local message = "podman command not available"
  if fatal then
    tx_failed(context, message)
  else
    log_warn(context, message)
  end
  return false
end

local function pull_flag_values(package, default_policy)
  local flags = {}
  local policy = default_policy

  if type(package) == "table" and type(package.flags) == "table" then
    for _, raw in ipairs(package.flags) do
      local text = trim(raw)
      if text == "" then
      elseif text == "force" then
        flags[#flags + 1] = "--force"
      else
        local key, value = text:match("^([^=]+)=(.+)$")
        key = lower(trim(key or ""))
        value = trim(value or "")
        if key == "platform" and value ~= "" then
          flags[#flags + 1] = "--platform " .. shell_quote(value)
        elseif key == "arch" and value ~= "" then
          flags[#flags + 1] = "--arch " .. shell_quote(value)
        elseif key == "os" and value ~= "" then
          flags[#flags + 1] = "--os " .. shell_quote(value)
        elseif key == "variant" and value ~= "" then
          flags[#flags + 1] = "--variant " .. shell_quote(value)
        elseif key == "tls-verify" and value ~= "" then
          flags[#flags + 1] = "--tls-verify=" .. value
        elseif key == "policy" and value ~= "" then
          policy = value
        end
      end
    end
  end

  return policy, flags
end

local function remove_flag_values(package)
  local flags = { "--ignore" }
  if type(package) == "table" and type(package.flags) == "table" then
    for _, raw in ipairs(package.flags) do
      local text = lower(trim(raw))
      if text == "force" then
        flags[#flags + 1] = "--force"
      elseif text == "no-prune" then
        flags[#flags + 1] = "--no-prune"
      end
    end
  end
  return flags
end

local function query_images(context)
  local result = exec_run(context, "podman images --format json")
  if result == nil or not result.success then
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "podman images failed")
  end

  local payload, decode_error = decode_json(result.stdout)
  if payload == nil or type(payload) ~= "table" then
    return nil, first_nonempty(decode_error, "failed to decode podman images output")
  end

  local items = {}
  for _, record in ipairs(payload) do
    local item = map_local_image(record)
    if item ~= nil then
      items[#items + 1] = item
    end
  end

  table.sort(items, function(left, right)
    return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "")
  end)
  return items, nil
end

local function inspect_image(context, name)
  local result = exec_run(context, "podman image inspect " .. shell_quote(name))
  if result == nil or not result.success then
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "podman image inspect failed")
  end

  local payload, decode_error = decode_json(result.stdout)
  if payload == nil or type(payload) ~= "table" then
    return nil, first_nonempty(decode_error, "failed to decode podman inspect output")
  end

  local record = payload[1]
  if type(record) ~= "table" then
    return nil, "podman image inspect returned no image"
  end
  return map_inspect_info(record, name), nil
end

local SEARCH_TEMPLATE = "{{.Index}}\t{{.Name}}\t{{.Description}}\t{{.Stars}}\t{{.Official}}\t{{.Automated}}"
local TAG_TEMPLATE = "{{.Name}}\t{{.Tag}}"

local function search_item_package_id(registry, name)
  local repo = trim(name)
  if repo ~= "" and registry ~= "" and not starts_with(lower(repo), lower(registry .. "/")) then
    repo = registry .. "/" .. repo
  end
  repo = normalize_registry_repo(repo)
  if repo == nil then
    return nil
  end
  return repo .. ":latest", repo
end

local function parse_search_output(stdout)
  local items = {}
  for _, line in ipairs(split_lines(stdout)) do
    local fields = split_tsv(line)
    local registry = trim(fields[1])
    local name = trim(fields[2])
    local description = trim(fields[3])
    if registry ~= "" and name ~= "" then
      local package_id, repository = search_item_package_id(registry, name)
      items[#items + 1] = {
        name = repository ~= nil and (repository:match("([^/]+)$") or repository) or name,
        packageId = package_id,
        version = "latest",
        latestVersion = "latest",
        type = "package",
        packageType = "container-image",
        installed = false,
        status = "available",
        summary = description ~= "" and description or package_id,
        description = description ~= "" and description or nil,
        extraFields = merge_extra_fields(nil, {
          registry = registry,
          repository = repository,
          searchStars = trim(fields[4]),
          searchOfficial = tostring(parse_bool_text(fields[5])),
          searchAutomated = tostring(parse_bool_text(fields[6])),
        }),
      }
    end
  end

  return items
end

local function fetch_search_items(context, prompt)
  local query = trim(prompt)
  if query == "" then
    return {}
  end

  return cached_fetch_json("search", query, SEARCH_TTL, function()
    local command = "podman search --limit 25 --format " .. shell_quote(SEARCH_TEMPLATE) .. " " .. shell_quote(query)
    local result = exec_run(context, command)
    if result == nil or not result.success then
      return nil, first_nonempty(result and result.stderr, result and result.stdout, "podman search failed")
    end
    return parse_search_output(result.stdout), nil
  end)
end

local function fetch_repository_tags(context, repository)
  local repo = trim(repository)
  if repo == "" then
    return {}, nil
  end

  return cached_fetch_json("remote-info", repo .. ":tags", REMOTE_INFO_TTL, function()
    local command = "podman search --list-tags --limit 25 --format " .. shell_quote(TAG_TEMPLATE) .. " " .. shell_quote(repo)
    local result = exec_run(context, command)
    if result == nil or not result.success then
      return nil, first_nonempty(result and result.stderr, result and result.stdout, "podman tag search failed")
    end

    local tags = {}
    for _, line in ipairs(split_lines(result.stdout)) do
      local fields = split_tsv(line)
      local tag = trim(fields[2])
      if tag ~= "" then
        tags[#tags + 1] = tag
      end
    end
    return tags, nil
  end)
end

local function pick_search_item(items, repository)
  local wanted = lower(trim(repository))
  for _, item in ipairs(items or {}) do
    local actual = lower(read_field(item.extraFields or {}, "repository") or "")
    if actual == wanted then
      return item
    end
  end
  return items ~= nil and items[1] or nil
end

local function build_remote_info(context, name)
  local parsed = parse_reference(name, "latest")
  if parsed == nil then
    return nil, "invalid image reference"
  end

  return cached_fetch_json("remote-info", parsed.fullRef, REMOTE_INFO_TTL, function()
    local search_items, search_error = fetch_search_items(context, parsed.repository)
    if search_items == nil then
      return nil, search_error
    end

    local best = pick_search_item(search_items, parsed.repository)
    local tags = nil
    if parsed.digest == nil then
      tags = fetch_repository_tags(context, parsed.repository)
    end
    if tags == nil then
      tags = {}
    end

    local version = first_nonempty(parsed.digest, parsed.tag, "latest")
    local latest_version = version
    if parsed.digest == nil then
      latest_version = parsed.tag or (tags[1] or "latest")
    end

    if best == nil then
      return {
        name = parsed.displayName,
        packageId = parsed.fullRef,
        version = version,
        latestVersion = latest_version,
        type = "package",
        packageType = "container-image",
        installed = false,
        status = "available",
        summary = parsed.fullRef,
        description = parsed.fullRef,
        extraFields = merge_extra_fields(nil, {
          registry = parsed.repository:match("^([^/]+)"),
          repository = parsed.repository,
        }),
      }, nil
    end

    local item = shallow_copy(best)
    item.packageId = parsed.fullRef
    item.version = version
    item.latestVersion = latest_version
    item.name = parsed.displayName
    item.extraFields = merge_extra_fields(item.extraFields, {
      registry = parsed.repository:match("^([^/]+)"),
      repository = parsed.repository,
    })
    return item, nil
  end)
end

local function is_supported_local_path(context, path)
  local lowered = lower(trim(path))
  for _, extension in ipairs(plugin.fileExtensions or {}) do
    if ends_with(lowered, extension) then
      return true
    end
  end

  local result = exec_run(context, "test -d " .. shell_quote(path))
  return result ~= nil and result.success == true
end

local function parse_loaded_image(stdout)
  for _, line in ipairs(split_lines(stdout)) do
    local image = trim(line:match("^Loaded image:%s*(.+)$") or "")
    if image ~= "" then
      return image
    end
  end
  return nil
end

local function local_path_from_context(context)
  local request = read_field(context, "request") or {}
  return trim(read_field(context, "localPath") or read_field(request, "localPath") or "")
end

local function item_identifiers(item)
  local identifiers = {}
  local function add(value)
    local text = trim(value)
    if text ~= "" then
      identifiers[text] = true
    end
  end

  add(read_field(item, "packageId"))
  if type(item.extraFields) == "table" then
    add(read_field(item.extraFields, "repoTag"))
    add(read_field(item.extraFields, "repoDigest"))
    add(read_field(item.extraFields, "imageId"))
    local names = read_field(item.extraFields, "names")
    if type(names) == "table" then
      for _, name in ipairs(names) do
        add(name)
      end
    end
  end
  return identifiers
end

local function request_identifier_set(package)
  local identifiers = {}
  local parsed = package_request_ref(package)
  local function add(value)
    local text = trim(value)
    if text ~= "" then
      identifiers[text] = true
    end
  end

  add(read_field(package, "name"))
  add(read_field(package, "packageId"))
  if parsed ~= nil then
    add(parsed.raw)
    add(parsed.fullRef)
    add(parsed.repository)
  end
  return identifiers
end

local function item_matches_request(item, package)
  local known = item_identifiers(item)
  for identifier in pairs(request_identifier_set(package)) do
    if known[identifier] then
      return true
    end
  end
  return false
end

local function outdated_items(context)
  local items, list_error = query_images(context)
  if items == nil then
    return nil, list_error
  end

  local outdated = {}
  for _, item in ipairs(items) do
    local repo_tag = type(item.extraFields) == "table" and read_field(item.extraFields, "repoTag") or nil
    local parsed = parse_reference(repo_tag or item.packageId or "", "latest")
    local before_digest = type(item.extraFields) == "table" and first_nonempty(read_field(item.extraFields, "digest")) or nil

    if parsed ~= nil and parsed.digest == nil and before_digest ~= nil then
      local result = exec_run(context, "podman pull --quiet --policy newer " .. shell_quote(parsed.fullRef))
      if result ~= nil and result.success then
        local info = inspect_image(context, parsed.fullRef)
        if info ~= nil and type(info.extraFields) == "table" then
          local after_digest = first_nonempty(read_field(info.extraFields, "digest"))
          if after_digest ~= nil and after_digest ~= before_digest then
            info.status = "outdated"
            info.latestVersion = after_digest
            info.extraFields = merge_extra_fields(info.extraFields, {
              previousDigest = before_digest,
            })
            outdated[#outdated + 1] = info
          end
        end
      else
        log_warn(context, first_nonempty(result and result.stderr, result and result.stdout, "podman newer-policy pull failed"))
      end
    end
  end

  table.sort(outdated, function(left, right)
    return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "")
  end)
  return outdated, nil
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
  return { "Containers", "OCI", "Package Manager" }
end

function plugin.getMissingPackages(packages)
  local requested = packages or {}
  if #requested == 0 then
    return {}
  end
  if not command_exists(nil, REQUIRED_BINARY) then
    return requested
  end

  local installed, list_error = query_images(nil)
  if installed == nil then
    return requested
  end

  local outdated = nil
  local wants_update = false
  for _, package in ipairs(requested) do
    if lower(read_field(package, "action") or "") == "update" then
      wants_update = true
      break
    end
  end
  if wants_update then
    outdated = select(1, outdated_items(nil)) or {}
  end

  local missing = {}
  for _, package in ipairs(requested) do
    local action = lower(read_field(package, "action") or "install")
    local matched = nil
    for _, item in ipairs(installed) do
      if item_matches_request(item, package) then
        matched = item
        break
      end
    end

    if action == "remove" then
      if matched ~= nil then
        missing[#missing + 1] = package
      end
    elseif action == "update" then
      local found_outdated = false
      for _, item in ipairs(outdated or {}) do
        if item_matches_request(item, package) then
          found_outdated = true
          break
        end
      end
      if found_outdated then
        missing[#missing + 1] = package
      end
    elseif matched == nil then
      missing[#missing + 1] = package
    end
  end

  return missing
end

function plugin.install(context, packages)
  local local_path = local_path_from_context(context)
  if local_path ~= "" then
    return plugin.installLocal(context, local_path)
  end

  local requested = packages or {}
  if #requested == 0 then
    return true
  end
  if not ensure_binary(context, true) then
    return false
  end

  begin_step(context, "install podman images")
  for _, package in ipairs(requested) do
    local parsed = package_request_ref(package)
    if parsed == nil then
      tx_failed(context, "podman image reference missing")
      return false
    end

    local policy, flags = pull_flag_values(package, "missing")
    local command = "podman pull --quiet --policy " .. policy
    if #flags > 0 then
      command = command .. " " .. table.concat(flags, " ")
    end
    command = command .. " " .. shell_quote(parsed.pullRef)

    local result = exec_run(context, command)
    if result == nil or not result.success then
      tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "podman pull failed"))
      return false
    end
  end

  emit_event(context, "installed", requested)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  local target = trim(path)
  if target == "" then
    tx_failed(context, "podman local install path missing")
    return false
  end
  if not ensure_binary(context, true) then
    return false
  end
  if not is_supported_local_path(context, target) then
    tx_failed(context, "unsupported local Podman image artifact")
    return false
  end

  begin_step(context, "install local podman image")
  local command = "podman load --quiet --input " .. shell_quote(target)
  local result = exec_run(context, command)
  if result == nil or not result.success then
    tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "podman load failed"))
    return false
  end

  emit_event(context, "installed", {
    path = target,
    localTarget = true,
    packageId = parse_loaded_image(result.stdout),
  })
  tx_success(context)
  return true
end

function plugin.remove(context, packages)
  local requested = packages or {}
  if #requested == 0 then
    return true
  end
  if not ensure_binary(context, true) then
    return false
  end

  begin_step(context, "remove podman images")
  for _, package in ipairs(requested) do
    local parsed = package_request_ref(package)
    if parsed == nil then
      tx_failed(context, "podman image reference missing")
      return false
    end
    local flags = remove_flag_values(package)
    local command = "podman rmi " .. table.concat(flags, " ") .. " " .. shell_quote(parsed.fullRef)
    local result = exec_run(context, command)
    if result == nil or not result.success then
      tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "podman remove failed"))
      return false
    end
  end

  emit_event(context, "deleted", requested)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  local requested = packages or {}
  if #requested == 0 then
    return true
  end
  if not ensure_binary(context, true) then
    return false
  end

  begin_step(context, "update podman images")
  for _, package in ipairs(requested) do
    local parsed = package_request_ref(package)
    if parsed == nil then
      tx_failed(context, "podman image reference missing")
      return false
    end

    local policy, flags = pull_flag_values(package, "newer")
    local command = "podman pull --quiet --policy " .. policy
    if #flags > 0 then
      command = command .. " " .. table.concat(flags, " ")
    end
    command = command .. " " .. shell_quote(parsed.pullRef)

    local result = exec_run(context, command)
    if result == nil or not result.success then
      tx_failed(context, first_nonempty(result and result.stderr, result and result.stdout, "podman update failed"))
      return false
    end
  end

  emit_event(context, "updated", requested)
  tx_success(context)
  return true
end

function plugin.list(context)
  if not ensure_binary(context, false) then
    emit_event(context, "listed", {})
    return {}
  end

  local items, error_message = query_images(context)
  if items == nil then
    log_warn(context, error_message)
    items = {}
  end
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  if not ensure_binary(context, false) then
    emit_event(context, "outdated", {})
    return {}
  end

  local items, error_message = outdated_items(context)
  if items == nil then
    log_warn(context, error_message)
    items = {}
  end
  emit_event(context, "outdated", items)
  return items
end

function plugin.search(context, prompt)
  local query = trim(prompt)
  if query == "" then
    emit_event(context, "searched", {})
    return {}
  end
  if not ensure_binary(context, false) then
    emit_event(context, "searched", {})
    return {}
  end

  local items, error_message = fetch_search_items(context, query)
  if items == nil then
    log_warn(context, error_message)
    items = {}
  end
  emit_event(context, "searched", items)
  return items
end

function plugin.info(context, name)
  local requested = trim(name)
  if requested == "" then
    emit_event(context, "informed", {})
    return {}
  end
  if not ensure_binary(context, false) then
    emit_event(context, "informed", {})
    return {}
  end

  local local_item = inspect_image(context, requested)
  if local_item == nil then
    local normalized = parse_reference(requested, "latest")
    if normalized ~= nil and normalized.fullRef ~= requested then
      local_item = inspect_image(context, normalized.fullRef)
    end
  end
  if local_item ~= nil then
    emit_event(context, "informed", local_item)
    return local_item
  end

  local remote_item, error_message = build_remote_info(context, requested)
  if remote_item == nil then
    log_warn(context, error_message)
    remote_item = {}
  end
  emit_event(context, "informed", remote_item)
  return remote_item
end

function plugin.resolvePackage(context, package)
  if package == nil then
    return nil
  end

  local parsed = package_request_ref(package)
  if parsed == nil then
    return nil
  end

  local item = plugin.info(context, parsed.fullRef)
  if type(item) ~= "table" or next(item) == nil then
    return {
      name = parsed.displayName,
      packageId = parsed.fullRef,
      version = version_from_ref(parsed, nil),
      packageType = "container-image",
      extraFields = {
        registry = parsed.repository:match("^([^/]+)"),
        repository = parsed.repository,
      },
    }
  end
  return item
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "exec", "network" },
    ecosystemScopes = { "containers", "oci", "docker", "podman" },
    writeScopes = {
      { kind = "temp" },
      { kind = "user-home-subpath", value = ".local/share/containers" },
      { kind = "user-home-subpath", value = ".cache/containers" },
      { kind = "user-home-subpath", value = ".cache/reqpack/podman" },
    },
    networkScopes = {
      { host = "*", scheme = "https", pathPrefix = "/" },
    },
    privilegeLevel = "user",
    purlType = "oci",
  }
end

function plugin.init()
  return true
end

function plugin.shutdown()
  return true
end

return plugin
