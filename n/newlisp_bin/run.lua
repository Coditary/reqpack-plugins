plugin = {}

local PLUGIN_ID = "newlisp_bin"
local PLUGIN_NAME = "newlisp_bin"
local PLUGIN_VERSION = "0.1.0"
local PACKAGE_NAME = "newlisp"
local OFFICIAL_DOWNLOADS_URL = "https://www.newlisp.org/index.cgi?page=Downloads"
local SOURCEFORGE_FILES_URL = "https://sourceforge.net/projects/newlisp/files/"
local OFFICIAL_BASE_URL = "https://www.newlisp.org/"
local SOURCEFORGE_DOWNLOAD_BASE = "https://sourceforge.net/projects/newlisp/files/"
local HISTORICAL_MACOS_1071_URL = "https://newlisp.nfshost.com/downloads1071/development/macOS-UTF8/"
local SOURCEFORGE_NEWS_URL = "https://sourceforge.net/p/newlisp/news/"
local DEFAULT_SOURCE_VERSION = "10.7.5"
local MANAGED_VARIANTS = {
  "source",
  "macos-utf8",
  "win32",
  "win32-utf8",
  "win64",
  "win64-utf8",
}
local VARIANT_HOST_PLATFORM = {
  source = "linux-unix",
  ["macos-utf8"] = "macos",
  win32 = "windows",
  ["win32-utf8"] = "windows",
  win64 = "windows",
  ["win64-utf8"] = "windows",
}

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
    local raw = trim(select(index, ...))
    if raw ~= "" then
      raw = raw:gsub("\\", "/")
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

local function dirname(path)
  local parent = trim(path):match("^(.*)/[^/]+$")
  if parent == nil or parent == "" then
    return "."
  end
  return parent
end

local function basename(path)
  return trim(path):match("([^/]+)$") or trim(path)
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
  return first_non_empty(expand_placeholders(env_raw("HOME") or ""), "/home/test")
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

local function request_object(context)
  local request = read_field(context, "request")
  if type(request) == "table" then
    return request
  end
  if type(context) == "table" then
    return context
  end
  return {}
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
  append_from(request_object(context))
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

local function has_flag(flags, key)
  local want = lower(trim(key))
  for _, flag in ipairs(flags or {}) do
    if lower(trim(flag)) == want then
      return true
    end
  end
  return false
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
  local data_root = join_path(reqpack_root("data", context, package), PLUGIN_ID)
  local cache_root = join_path(reqpack_root("cache", context, package), PLUGIN_ID)
  return {
    dataRoot = data_root,
    cacheRoot = cache_root,
    installsRoot = join_path(data_root, "installs"),
    registryPath = join_path(data_root, "installed.tsv"),
    queryRoot = join_path(cache_root, "query"),
    downloadsRoot = join_path(cache_root, "downloads"),
    tmpRoot = join_path(cache_root, "tmp"),
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

local function ensure_query_binary(context)
  if command_exists(context, "curl") then
    return true, nil
  end
  return false, "curl binary not available"
end

local function ensure_extract_binary(context)
  if command_exists(context, "tar") then
    return true, nil
  end
  return false, "tar binary not available"
end

local function ensure_build_binaries(context)
  local required = { "sh", "make" }
  for _, binary in ipairs(required) do
    if not command_exists(context, binary) then
      return false, binary .. " binary not available"
    end
  end
  return true, nil
end

local function read_text_file(context, path)
  local result = exec_run(context, "cat " .. shell_quote(path))
  if result == nil or result.success ~= true then
    return nil
  end
  return tostring(result.stdout or "")
end

local function command_success(context, command)
  local result = exec_run(context, command)
  return result ~= nil and result.success == true
end

local function mkdir_p(context, ...)
  local parts = {}
  for _, path in ipairs({ ... }) do
    if non_empty(path) ~= nil then
      parts[#parts + 1] = shell_quote(path)
    end
  end
  if #parts == 0 then
    return true
  end
  local result = exec_run(context, "mkdir -p " .. table.concat(parts, " "))
  return result ~= nil and result.success == true
end

local function write_text_file(context, path, content)
  if not mkdir_p(context, dirname(path)) then
    return false
  end
  local command = "printf %s " .. shell_quote(content or "") .. " > " .. shell_quote(path)
  local result = exec_run(context, command)
  return result ~= nil and result.success == true
end

local function rm_rf(context, path)
  local result = exec_run(context, "rm -rf " .. shell_quote(path))
  return result ~= nil and result.success == true
end

local function cp_file(context, source, target)
  local result = exec_run(context, "cp " .. shell_quote(source) .. " " .. shell_quote(target))
  return result ~= nil and result.success == true
end

local function chmod_plus_x(context, path)
  local result = exec_run(context, "chmod +x " .. shell_quote(path))
  return result ~= nil and result.success == true
end

local function detect_os(context)
  local result = exec_run(context, "uname -s")
  local value = lower(trim(result and result.stdout or ""))
  if value == "darwin" then
    return "macos"
  end
  if value:find("mingw", 1, true) ~= nil or value:find("msys", 1, true) ~= nil or value:find("cygwin", 1, true) ~= nil then
    return "windows"
  end
  if value ~= "" then
    return "linux"
  end
  return "linux"
end

local function detect_arch_bits(context)
  local result = exec_run(context, "uname -m")
  local value = lower(trim(result and result.stdout or ""))
  if value:find("64", 1, true) ~= nil then
    return 64
  end
  return 32
end

local function default_variant_for_host(context)
  local os_name = detect_os(context)
  if os_name == "macos" then
    return "macos-utf8"
  end
  if os_name == "windows" then
    if detect_arch_bits(context) >= 64 then
      return "win64-utf8"
    end
    return "win32-utf8"
  end
  return "source"
end

local function is_supported_variant(value)
  local wanted = lower(trim(value))
  for _, variant in ipairs(MANAGED_VARIANTS) do
    if variant == wanted then
      return true
    end
  end
  return false
end

local function version_sort_key(version)
  local parts = {}
  for token in tostring(version or ""):gmatch("%d+") do
    parts[#parts + 1] = string.format("%06d", tonumber(token))
  end
  return table.concat(parts, ".")
end

local function compare_versions(a, b)
  local a_parts = {}
  local b_parts = {}
  for token in tostring(a or ""):gmatch("%d+") do
    a_parts[#a_parts + 1] = tonumber(token)
  end
  for token in tostring(b or ""):gmatch("%d+") do
    b_parts[#b_parts + 1] = tonumber(token)
  end
  local max = #a_parts
  if #b_parts > max then
    max = #b_parts
  end
  for index = 1, max do
    local left = a_parts[index] or 0
    local right = b_parts[index] or 0
    if left < right then
      return -1
    end
    if left > right then
      return 1
    end
  end
  return 0
end

local function package_id_for_variant(variant)
  return PACKAGE_NAME .. "/" .. variant
end

local function binary_name_for_variant(variant)
  if lower(variant) == "source" or lower(variant) == "macos-utf8" then
    return "newlisp"
  end
  return "newlisp.exe"
end

local function source_filename_for_version(version)
  return "newlisp-" .. version .. ".tgz"
end

local function source_release_date_for_version(version, sourceforge_dates, news_dates)
  local file_name = source_filename_for_version(version)
  return first_non_empty(
    type(sourceforge_dates) == "table" and sourceforge_dates[file_name] or nil,
    type(news_dates) == "table" and news_dates[version] or nil
  )
end

local function sourceforge_source_url(version)
  return SOURCEFORGE_DOWNLOAD_BASE .. source_filename_for_version(version) .. "/download"
end

local function official_source_url(version)
  return OFFICIAL_BASE_URL .. "downloads/" .. source_filename_for_version(version)
end

local function official_variant_url(variant)
  if variant == "macos-utf8" then
    return OFFICIAL_BASE_URL .. "downloads/macOS-UTF8/newlisp"
  end
  if variant == "win32" then
    return OFFICIAL_BASE_URL .. "downloads/Win32/newlisp.exe"
  end
  if variant == "win32-utf8" then
    return OFFICIAL_BASE_URL .. "downloads/Win32-UTF8/newlisp.exe"
  end
  if variant == "win64" then
    return OFFICIAL_BASE_URL .. "downloads/Win64/newlisp.exe"
  end
  if variant == "win64-utf8" then
    return OFFICIAL_BASE_URL .. "downloads/Win64-UTF8/newlisp.exe"
  end
  return official_source_url(DEFAULT_SOURCE_VERSION)
end

local function variant_archive_kind(variant)
  if variant == "source" then
    return "tar.gz"
  end
  if variant == "macos-utf8" then
    return "binary"
  end
  return "exe"
end

local function major_minor_version(version)
  local major = nil
  local minor = nil
  local index = 0
  for token in tostring(version or ""):gmatch("%d+") do
    index = index + 1
    if index == 1 then
      major = tonumber(token)
    elseif index == 2 then
      minor = tonumber(token)
      break
    end
  end
  if major == nil or minor == nil then
    return nil
  end
  return tostring(major) .. "." .. tostring(minor)
end

local function release_notes_url_for_version(version)
  local major_minor = major_minor_version(version)
  if major_minor == nil then
    return nil
  end
  if compare_versions(version, "9.0.0") >= 0 then
    return OFFICIAL_BASE_URL .. "downloads/newLISP-" .. major_minor .. "-Release.html"
  end
  return OFFICIAL_BASE_URL .. "downloads/newLISP_" .. tostring(major_minor):gsub("%.", "") .. "_Release_Notes.html"
end

local function encode_windows_release_version(version)
  local parts = {}
  for token in tostring(version or ""):gmatch("%d+") do
    parts[#parts + 1] = tostring(tonumber(token))
  end
  if #parts == 0 then
    return ""
  end
  local major = tonumber(parts[1]) or 0
  local minor = tonumber(parts[2] or "0") or 0
  local patch = tonumber(parts[3] or "0") or 0
  return string.format("%02d%d%02d", major, minor, patch)
end

local function decode_windows_release_version(encoded_version)
  local digits = tostring(encoded_version or "")
  if #digits < 4 then
    return nil
  end
  local major = tonumber(digits:sub(1, 2))
  local minor = tonumber(digits:sub(3, 3))
  local patch = tonumber(digits:sub(4))
  if major == nil or minor == nil or patch == nil then
    return nil
  end
  return tostring(major) .. "." .. tostring(minor) .. "." .. tostring(patch)
end

local function enrich_extra_fields(extra, variant, source_url, file_name, release_date, history_source)
  local merged = shallow_copy(extra or {})
  merged.variant = variant
  merged.channel = "stable"
  merged.historySource = history_source or "official"
  merged.hostPlatform = VARIANT_HOST_PLATFORM[variant]
  merged.archiveKind = variant_archive_kind(variant)
  merged.sourceUrl = source_url
  if non_empty(file_name) ~= nil then
    merged.fileName = file_name
  end
  if non_empty(release_date) ~= nil then
    merged.releaseDate = release_date
  end
  local release_notes_url = release_notes_url_for_version(extra and extra.version or nil)
  if release_notes_url == nil then
    release_notes_url = release_notes_url_for_version(file_name and decode_windows_release_version(file_name:match("^newlisp%-(%d+)%-.+%.exe$")) or nil)
  end
  if release_notes_url == nil then
    release_notes_url = release_notes_url_for_version((extra and extra.releaseVersion) or nil)
  end
  if release_notes_url ~= nil then
    merged.releaseNotesUrl = release_notes_url
  end
  return merged
end

local function registry_line_for_item(item)
  local extra = type(item.extraFields) == "table" and item.extraFields or {}
  local fields = {
    trim(item.packageId),
    trim(item.name),
    trim(item.version),
    trim(extra.variant),
    trim(extra.installPath),
    trim(extra.binaryPath),
    trim(extra.sourceUrl),
    trim(item.description),
  }
  return table.concat(fields, "\t")
end

local function item_from_registry_line(line)
  local parts = {}
  for field in (tostring(line or "") .. "\t"):gmatch("(.-)\t") do
    parts[#parts + 1] = field
  end
  local package_id = non_empty(parts[1])
  if package_id == nil then
    return nil
  end
  local variant = non_empty(parts[4]) or "source"
  return {
    name = non_empty(parts[2]) or PACKAGE_NAME,
    packageId = package_id,
    version = non_empty(parts[3]),
    packageType = "release",
    type = "package",
    description = non_empty(parts[8]) or "Managed newLISP release",
    homepage = OFFICIAL_BASE_URL,
    extraFields = {
      variant = variant,
      channel = "stable",
      historySource = "installed",
      hostPlatform = VARIANT_HOST_PLATFORM[variant],
      archiveKind = variant_archive_kind(variant),
      installPath = non_empty(parts[5]),
      binaryPath = non_empty(parts[6]),
      sourceUrl = non_empty(parts[7]),
      fileName = non_empty(parts[7]) and basename(parts[7]) or nil,
    },
  }
end

local function load_registry(context, package)
  local paths = runtime_paths(context, package)
  local content = read_text_file(context, paths.registryPath)
  if content == nil then
    return {}
  end
  local items = {}
  for _, line in ipairs(split_lines(content)) do
    local item = item_from_registry_line(line)
    if item ~= nil then
      items[#items + 1] = item
    end
  end
  return items
end

local function save_registry(context, package, items)
  local paths = runtime_paths(context, package)
  if not mkdir_p(context, dirname(paths.registryPath)) then
    return false
  end
  local lines = {}
  for _, item in ipairs(items or {}) do
    lines[#lines + 1] = registry_line_for_item(item)
  end
  local content = table.concat(lines, "\n")
  if #lines > 0 then
    content = content .. "\n"
  end
  return write_text_file(context, paths.registryPath, content)
end

local function find_installed_by_variant(context, package, variant)
  for _, item in ipairs(load_registry(context, package)) do
    local extra = type(item.extraFields) == "table" and item.extraFields or {}
    if lower(extra.variant) == lower(variant) then
      return item
    end
  end
  return nil
end

local function catalog_cache_path(context, package, name)
  return join_path(runtime_paths(context, package).queryRoot, name)
end

local function download_cache_path(context, package, file_name)
  return join_path(runtime_paths(context, package).downloadsRoot, file_name)
end

local function remote_fetch_to_cache(context, package, url, cache_path)
  if not mkdir_p(context, dirname(cache_path)) then
    return nil
  end
  local result = exec_run(context, "curl -fsSL " .. shell_quote(url) .. " -o " .. shell_quote(cache_path))
  if result == nil or result.success ~= true then
    return nil
  end
  local cached = read_text_file(context, cache_path)
  if cached ~= nil then
    return cached
  end
  return tostring(result.stdout or "")
end

local function cached_or_fetch(context, package, url, cache_name)
  local path = catalog_cache_path(context, package, cache_name)
  local cached = read_text_file(context, path)
  if cached ~= nil and cached ~= "" then
    return cached
  end
  return remote_fetch_to_cache(context, package, url, path)
end

local function latest_version_from_downloads_html(html)
  local version = tostring(html or ""):match("Stable Release version%s+([0-9][0-9%.]+)")
  if version ~= nil then
    return version
  end
  version = tostring(html or ""):match("Source distribution v%.([0-9][0-9%.]+)")
  if version ~= nil then
    return version
  end
  version = tostring(html or ""):match("newlisp%-([0-9][0-9%.]+)%.tgz")
  return version
end

local function historical_source_versions_from_html(html)
  local found = {}
  local seen = {}
  for version in tostring(html or ""):gmatch("newlisp%-([0-9][0-9%.]+)%.tgz") do
    if not seen[version] then
      seen[version] = true
      found[#found + 1] = version
    end
  end
  table.sort(found, function(left, right)
    return compare_versions(left, right) > 0
  end)
  return found
end

local function release_date_map_from_sourceforge_html(html)
  local dates = {}
  for _, line in ipairs(split_lines(html)) do
    local file_name = line:match("(newlisp[^%s|]+)")
    local release_date = line:match("([0-9][0-9][0-9][0-9]%-%d%d%-%d%d)")
    if file_name ~= nil and release_date ~= nil then
      dates[file_name] = release_date
    end
  end
  return dates
end

local function release_date_map_from_news_html(html)
  local dates = {}
  local current_version = nil
  for _, line in ipairs(split_lines(html)) do
    local version = line:match("newLISP v%.([0-9][0-9%.]+)")
    if version ~= nil then
      current_version = version
    end
    local posted = line:match("Posted by ([0-9][0-9][0-9][0-9]%-%d%d%-%d%d)")
    if current_version ~= nil and posted ~= nil and dates[current_version] == nil then
      dates[current_version] = posted
      current_version = nil
    end
  end
  return dates
end

local function parse_historical_macos_binaries(html)
  local items = {}
  if tostring(html or ""):find("newlisp.dylib", 1, true) ~= nil and tostring(html or ""):find("newlisp", 1, true) ~= nil then
    items[#items + 1] = {
      version = "10.7.1",
      variant = "macos-utf8",
      fileName = "newlisp",
      sourceUrl = HISTORICAL_MACOS_1071_URL .. "newlisp",
      historySource = "nfshost",
      releaseDate = tostring(html or ""):match("newlisp[^\n]-([0-9][0-9][0-9][0-9]%-%d%d%-%d%d)"),
    }
  end
  return items
end

local function parse_sourceforge_windows_binaries(html, release_dates)
  local items = {}
  local seen = {}
  for _, line in ipairs(split_lines(html)) do
    local file_name = line:match("(newlisp%-%d+%-win64%-gs%-%d+%.exe)")
    local variant = "win64"
    if file_name == nil then
      file_name = line:match("(newlisp%-%d+%-win%-gs%-%d+%.exe)")
      variant = "win32"
    end
    if file_name ~= nil then
      local encoded_version = file_name:match("^newlisp%-(%d+)%-.+%.exe$")
      local version = decode_windows_release_version(encoded_version)
      local key = variant .. ":" .. tostring(version or "")
      if version ~= nil and not seen[key] then
        seen[key] = true
        items[#items + 1] = {
          version = version,
          variant = variant,
          fileName = file_name,
          sourceUrl = SOURCEFORGE_DOWNLOAD_BASE .. file_name .. "/download",
          historySource = "sourceforge",
          releaseDate = release_dates and release_dates[file_name] or nil,
        }
      end
    end
  end
  table.sort(items, function(left, right)
    local cmp = compare_versions(left.version, right.version)
    if cmp ~= 0 then
      return cmp > 0
    end
    return left.variant < right.variant
  end)
  return items
end

local function build_release_item(variant, version, source_url, options)
  options = options or {}
  local latest = options.latestVersion or version
  local file_name = options.fileName
  if file_name == nil then
    if variant == "source" then
      file_name = source_filename_for_version(version)
    else
      file_name = basename(source_url)
    end
  end
  return {
    name = PACKAGE_NAME,
    packageId = package_id_for_variant(variant),
    version = version,
    latestVersion = latest,
    packageType = "release",
    type = "package",
    description = options.description or (variant == "source" and "Official newLISP source release" or ("Official newLISP " .. variant .. " release")),
    homepage = OFFICIAL_BASE_URL,
    extraFields = enrich_extra_fields(shallow_copy(options.extraFields or { releaseVersion = version }), variant, source_url, file_name, options.releaseDate, options.historySource),
  }
end

local function remote_catalog(context, package)
  local downloads_html = cached_or_fetch(context, package, OFFICIAL_DOWNLOADS_URL, "downloads.html")
  if downloads_html == nil then
    return nil, nil, nil
  end
  local latest = latest_version_from_downloads_html(downloads_html) or DEFAULT_SOURCE_VERSION
  local sourceforge_html = cached_or_fetch(context, package, SOURCEFORGE_FILES_URL, "sourceforge-files.html") or ""
  local sourceforge_dates = release_date_map_from_sourceforge_html(sourceforge_html)
  local news_html = cached_or_fetch(context, package, SOURCEFORGE_NEWS_URL, "sourceforge-news.html") or ""
  local news_dates = release_date_map_from_news_html(news_html)
  local historical_source_dates = {}
  local historical = historical_source_versions_from_html(sourceforge_html)
  for _, version in ipairs(historical) do
    historical_source_dates[version] = source_release_date_for_version(version, sourceforge_dates, news_dates)
  end
  local historical_windows = parse_sourceforge_windows_binaries(sourceforge_html, sourceforge_dates)
  local historical_macos_html = cached_or_fetch(context, package, HISTORICAL_MACOS_1071_URL, "macos-1071.html") or ""
  local historical_macos = parse_historical_macos_binaries(historical_macos_html)
  local items = {}
  for _, variant in ipairs(MANAGED_VARIANTS) do
    local url = variant == "source" and official_source_url(latest) or official_variant_url(variant)
    items[#items + 1] = build_release_item(variant, latest, url, {
      latestVersion = latest,
      historySource = "official",
      releaseDate = news_dates[latest],
    })
  end
  for _, entry in ipairs(historical_windows) do
    if entry.releaseDate == nil then
      entry.releaseDate = news_dates[entry.version]
    end
  end
  for _, entry in ipairs(historical_macos) do
    if entry.releaseDate == nil then
      entry.releaseDate = news_dates[entry.version]
    end
  end
  return items, latest, historical, historical_windows, historical_macos, historical_source_dates
end

local function build_source_item(version, release_date)
  return build_release_item("source", version, sourceforge_source_url(version), {
    historySource = "sourceforge",
    fileName = source_filename_for_version(version),
    releaseDate = release_date,
  })
end

local function build_historical_windows_item(entry, latest)
  return build_release_item(entry.variant, entry.version, entry.sourceUrl, {
    latestVersion = latest,
    historySource = entry.historySource,
    fileName = entry.fileName,
    releaseDate = entry.releaseDate,
    description = "Historical newLISP " .. entry.variant .. " Windows release",
  })
end

local function build_historical_macos_item(entry, latest)
  return build_release_item(entry.variant, entry.version, entry.sourceUrl, {
    latestVersion = latest,
    historySource = entry.historySource,
    fileName = entry.fileName,
    releaseDate = entry.releaseDate,
    description = "Historical newLISP macOS UTF8 release",
  })
end

local function package_name_value(package)
  if type(package) == "string" then
    return package
  end
  return first_non_empty(read_field(package, "packageId"), read_field(package, "name"))
end

local function normalize_requested_variant(context, package)
  local flags = collect_flags(context, package)
  local variant = lower(first_non_empty(
    flag_value(flags, "variant"),
    read_field(type(package) == "table" and read_field(package, "extraFields") or nil, "variant")
  ) or "")
  if variant ~= "" and is_supported_variant(variant) then
    return variant
  end

  local raw_name = lower(package_name_value(package) or "")
  if raw_name:match("^newlisp/") then
    local suffix = raw_name:match("^newlisp/(.+)$")
    if is_supported_variant(suffix) then
      return suffix
    end
  end
  return default_variant_for_host(context)
end

local function normalize_requested_version(package)
  return first_non_empty(read_field(package, "version"), read_field(package, "latestVersion"))
end

local function resolved_package(context, package)
  local variant = normalize_requested_variant(context, package)
  local requested_version = normalize_requested_version(package)
  local catalog, latest, historical, historical_windows, historical_macos, historical_source_dates = remote_catalog(context, package)
  if catalog == nil then
    return nil, "remote catalog unavailable"
  end
  local version = requested_version or latest
  if variant ~= "source" then
    version = latest
  end

  if variant == "source" and requested_version ~= nil then
    local found = false
    if compare_versions(requested_version, latest) == 0 then
      found = true
    else
      for _, item in ipairs(historical or {}) do
        if compare_versions(item, requested_version) == 0 then
          found = true
          break
        end
      end
    end
    if not found then
      return nil, "newlisp source version not found: " .. requested_version
    end
  end

  if variant ~= "source" and requested_version ~= nil and compare_versions(requested_version, latest) ~= 0 then
    for _, entry in ipairs(historical_windows or {}) do
      if entry.variant == variant and compare_versions(entry.version, requested_version) == 0 then
        return build_historical_windows_item(entry, latest), nil
      end
    end
    for _, entry in ipairs(historical_macos or {}) do
      if entry.variant == variant and compare_versions(entry.version, requested_version) == 0 then
        return build_historical_macos_item(entry, latest), nil
      end
    end
    return nil, "newlisp binary version not found: " .. requested_version
  end

  if variant == "source" and compare_versions(version, latest) ~= 0 then
    return build_source_item(version, historical_source_dates and historical_source_dates[version] or nil), nil
  end

  for _, item in ipairs(catalog) do
    local extra = type(item.extraFields) == "table" and item.extraFields or {}
    if lower(extra.variant) == variant then
      local resolved = shallow_copy(item)
      resolved.extraFields = shallow_copy(extra)
      resolved.version = version
      resolved.latestVersion = latest
      if variant == "source" then
        resolved.extraFields.sourceUrl = official_source_url(version)
        if compare_versions(version, latest) ~= 0 then
          resolved.extraFields.sourceUrl = sourceforge_source_url(version)
        end
      end
      resolved.extraFields = enrich_extra_fields(resolved.extraFields, variant, resolved.extraFields.sourceUrl, resolved.extraFields.fileName, resolved.extraFields.releaseDate, resolved.extraFields.historySource)
      return resolved, nil
    end
  end
  return nil, "variant not found: " .. variant
end

local function request_packages(context, packages)
  if type(packages) == "table" and #packages > 0 then
    return packages
  end
  local request = request_object(context)
  local items = read_field(request, "packages")
  if type(items) == "table" and #items > 0 then
    return items
  end
  if type(request) == "table" then
    return { request }
  end
  return {}
end

local function current_install_paths(context, package, variant, version)
  local paths = runtime_paths(context, package)
  local install_path = join_path(paths.installsRoot, variant, version)
  local binary_path = join_path(install_path, "bin", binary_name_for_variant(variant))
  return install_path, binary_path
end

local function install_source_release(context, package, item)
  local paths = runtime_paths(context, package)
  local variant = item.extraFields.variant
  local version = item.version
  local archive_name = source_filename_for_version(version)
  local archive_path = download_cache_path(context, package, archive_name)
  local install_path, binary_path = current_install_paths(context, package, variant, version)
  local extract_root = join_path(paths.tmpRoot, "source-" .. version)
  local source_dir = join_path(extract_root, "newlisp-" .. version)

  local ok, err = ensure_extract_binary(context)
  if not ok then
    return nil, err
  end
  ok, err = ensure_build_binaries(context)
  if not ok then
    return nil, err
  end
  if not mkdir_p(context, paths.downloadsRoot, paths.tmpRoot, dirname(install_path)) then
    return nil, "failed to prepare directories"
  end
  local download = exec_run(context, "curl -fsSL " .. shell_quote(item.extraFields.sourceUrl) .. " -o " .. shell_quote(archive_path))
  if download == nil or download.success ~= true then
    return nil, "newlisp download failed"
  end
  if not rm_rf(context, extract_root) then
    return nil, "failed to clear temp build directory"
  end
  if not mkdir_p(context, extract_root) then
    return nil, "failed to prepare temp build directory"
  end
  local extract = exec_run(context, "tar -xzf " .. shell_quote(archive_path) .. " -C " .. shell_quote(extract_root))
  if extract == nil or extract.success ~= true then
    return nil, "newlisp extract failed"
  end
  if not rm_rf(context, install_path) then
    return nil, "failed to clear install path"
  end
  if not mkdir_p(context, install_path) then
    return nil, "failed to prepare install path"
  end
  local build = exec_run(context, "cd " .. shell_quote(source_dir) .. " && ./configure-alt --prefix=" .. shell_quote(install_path) .. " && make && make install")
  if build == nil or build.success ~= true then
    return nil, "newlisp build failed"
  end
  return {
    name = PACKAGE_NAME,
    packageId = item.packageId,
    version = version,
    latestVersion = item.latestVersion,
    packageType = "release",
    type = "package",
    description = item.description,
    homepage = OFFICIAL_BASE_URL,
    extraFields = {
      variant = variant,
      installPath = install_path,
      binaryPath = binary_path,
      sourceUrl = item.extraFields.sourceUrl,
      channel = item.extraFields.channel,
      historySource = item.extraFields.historySource,
      hostPlatform = item.extraFields.hostPlatform,
      archiveKind = item.extraFields.archiveKind,
      fileName = item.extraFields.fileName,
    },
  }, nil
end

local function install_binary_release(context, package, item)
  local variant = item.extraFields.variant
  local version = item.version
  local file_name = binary_name_for_variant(variant) .. "-" .. version
  local download_path = download_cache_path(context, package, file_name)
  local install_path, binary_path = current_install_paths(context, package, variant, version)

  if not mkdir_p(context, dirname(download_path), dirname(binary_path)) then
    return nil, "failed to prepare directories"
  end
  local download = exec_run(context, "curl -fsSL " .. shell_quote(item.extraFields.sourceUrl) .. " -o " .. shell_quote(download_path))
  if download == nil or download.success ~= true then
    return nil, "newlisp download failed"
  end
  if not rm_rf(context, install_path) then
    return nil, "failed to clear install path"
  end
  if not mkdir_p(context, dirname(binary_path)) then
    return nil, "failed to prepare install path"
  end
  if not cp_file(context, download_path, binary_path) then
    return nil, "failed to copy executable"
  end
  if lower(binary_path):sub(-4) ~= ".exe" then
    if not chmod_plus_x(context, binary_path) then
      return nil, "failed to chmod executable"
    end
  end
  return {
    name = PACKAGE_NAME,
    packageId = item.packageId,
    version = version,
    latestVersion = item.latestVersion,
    packageType = "release",
    type = "package",
    description = item.description,
    homepage = OFFICIAL_BASE_URL,
    extraFields = {
      variant = variant,
      installPath = install_path,
      binaryPath = binary_path,
      sourceUrl = item.extraFields.sourceUrl,
      channel = item.extraFields.channel,
      historySource = item.extraFields.historySource,
      hostPlatform = item.extraFields.hostPlatform,
      archiveKind = item.extraFields.archiveKind,
      fileName = item.extraFields.fileName,
    },
  }, nil
end

local function upsert_registry_item(context, package, installed_item)
  local all = load_registry(context, package)
  local next_items = {}
  local installed_variant = lower(installed_item.extraFields.variant)
  for _, item in ipairs(all) do
    local extra = type(item.extraFields) == "table" and item.extraFields or {}
    if lower(extra.variant) ~= installed_variant then
      next_items[#next_items + 1] = item
    end
  end
  next_items[#next_items + 1] = installed_item
  table.sort(next_items, function(left, right)
    return trim(left.packageId) < trim(right.packageId)
  end)
  return save_registry(context, package, next_items)
end

local function install_resolved_item(context, package, item)
  if item.extraFields.variant == "source" then
    return install_source_release(context, package, item)
  end
  return install_binary_release(context, package, item)
end

local function install_local_binary(context, package, local_path, variant, version)
  local install_path, binary_path = current_install_paths(context, package, variant, version)
  if not rm_rf(context, install_path) then
    return nil, "failed to clear install path"
  end
  if not mkdir_p(context, dirname(binary_path)) then
    return nil, "failed to prepare install path"
  end
  if not cp_file(context, local_path, binary_path) then
    return nil, "failed to copy local executable"
  end
  if lower(binary_path):sub(-4) ~= ".exe" then
    if not chmod_plus_x(context, binary_path) then
      return nil, "failed to chmod executable"
    end
  end
  return {
    name = PACKAGE_NAME,
    packageId = package_id_for_variant(variant),
    version = version,
    latestVersion = version,
    packageType = "release",
    type = "package",
    description = "Managed local newLISP executable",
    homepage = OFFICIAL_BASE_URL,
    extraFields = {
      variant = variant,
      installPath = install_path,
      binaryPath = binary_path,
      sourceUrl = local_path,
      channel = "local",
      historySource = "local",
      hostPlatform = VARIANT_HOST_PLATFORM[variant],
      archiveKind = variant_archive_kind(variant),
      fileName = basename(local_path),
    },
  }, nil
end

local function install_local_source_archive(context, package, local_path, version)
  local paths = runtime_paths(context, package)
  local variant = "source"
  local install_path, binary_path = current_install_paths(context, package, variant, version)
  local extract_root = join_path(paths.tmpRoot, "local-source-" .. version)

  local ok, err = ensure_extract_binary(context)
  if not ok then
    return nil, err
  end
  ok, err = ensure_build_binaries(context)
  if not ok then
    return nil, err
  end
  if not rm_rf(context, extract_root) then
    return nil, "failed to clear temp build directory"
  end
  if not mkdir_p(context, extract_root, dirname(install_path)) then
    return nil, "failed to prepare directories"
  end
  local extract = exec_run(context, "tar -xzf " .. shell_quote(local_path) .. " -C " .. shell_quote(extract_root))
  if extract == nil or extract.success ~= true then
    return nil, "local source extract failed"
  end
  local probe = exec_run(context, "sh -lc " .. shell_quote("for d in " .. shell_quote(extract_root) .. "/*; do if [ -d \"$d\" ]; then printf '%s\\n' \"$d\"; break; fi; done"))
  local source_dir = trim(probe and probe.stdout or "")
  if source_dir == "" then
    source_dir = extract_root
  end
  if not rm_rf(context, install_path) then
    return nil, "failed to clear install path"
  end
  if not mkdir_p(context, install_path) then
    return nil, "failed to prepare install path"
  end
  local build = exec_run(context, "cd " .. shell_quote(source_dir) .. " && ./configure-alt --prefix=" .. shell_quote(install_path) .. " && make && make install")
  if build == nil or build.success ~= true then
    return nil, "local source build failed"
  end
  return {
    name = PACKAGE_NAME,
    packageId = package_id_for_variant(variant),
    version = version,
    latestVersion = version,
    packageType = "release",
    type = "package",
    description = "Managed local newLISP source build",
    homepage = OFFICIAL_BASE_URL,
    extraFields = {
      variant = variant,
      installPath = install_path,
      binaryPath = binary_path,
      sourceUrl = local_path,
      channel = "local",
      historySource = "local",
      hostPlatform = VARIANT_HOST_PLATFORM[variant],
      archiveKind = variant_archive_kind(variant),
      fileName = basename(local_path),
    },
  }, nil
end

local function install_local_source_dir(context, package, local_path, version)
  local variant = "source"
  local install_path, binary_path = current_install_paths(context, package, variant, version)

  local ok, err = ensure_build_binaries(context)
  if not ok then
    return nil, err
  end
  if not rm_rf(context, install_path) then
    return nil, "failed to clear install path"
  end
  if not mkdir_p(context, install_path) then
    return nil, "failed to prepare install path"
  end
  local build = exec_run(context, "cd " .. shell_quote(local_path) .. " && ./configure-alt --prefix=" .. shell_quote(install_path) .. " && make && make install")
  if build == nil or build.success ~= true then
    return nil, "local source build failed"
  end
  return {
    name = PACKAGE_NAME,
    packageId = package_id_for_variant(variant),
    version = version,
    latestVersion = version,
    packageType = "release",
    type = "package",
    description = "Managed local newLISP source build",
    homepage = OFFICIAL_BASE_URL,
    extraFields = {
      variant = variant,
      installPath = install_path,
      binaryPath = binary_path,
      sourceUrl = local_path,
      channel = "local",
      historySource = "local",
      hostPlatform = VARIANT_HOST_PLATFORM[variant],
      archiveKind = variant_archive_kind(variant),
      fileName = basename(local_path),
    },
  }, nil
end

local function local_path_kind(path)
  local cleaned = lower(trim(path))
  local name = lower(basename(cleaned))
  if cleaned:sub(-4) == ".exe" then
    return "binary"
  end
  if name == "newlisp" or name == "newlisp.exe" then
    return "binary"
  end
  if cleaned:sub(-4) == ".tgz" or cleaned:sub(-7) == ".tar.gz" then
    return "archive"
  end
  return "directory"
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
  return { "language", "package-manager", "newlisp" }
end

function plugin.init()
  return true
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "exec", "network" },
    ecosystemScopes = { "newlisp" },
    writeScopes = {
      { kind = "user-home-subpath", value = ".local/share/reqpack/newlisp_bin" },
      { kind = "user-home-subpath", value = ".cache/reqpack/newlisp_bin" },
    },
    networkScopes = {
      "https://www.newlisp.org/",
      "https://sourceforge.net/projects/newlisp/files/",
    },
    privilegeLevel = "none",
    purlType = "generic",
    versionComparatorProfile = "semver-ish",
    versionTokenPattern = "\\d+",
  }
end

function plugin.getMissingPackages(packages)
  local requested = request_packages(nil, packages)
  local installed = load_registry(nil, requested[1])
  local missing = {}
  for _, pkg in ipairs(requested) do
    local variant = normalize_requested_variant(nil, pkg)
    local present = false
    for _, item in ipairs(installed) do
      local extra = type(item.extraFields) == "table" and item.extraFields or {}
      if lower(extra.variant) == variant then
        present = true
        break
      end
    end
    local action = lower(read_field(pkg, "action") or "install")
    if action == "install" then
      if not present then
        missing[#missing + 1] = pkg
      end
    elseif action == "remove" then
      if present then
        missing[#missing + 1] = pkg
      end
    elseif action == "update" then
      missing[#missing + 1] = pkg
    end
  end
  return missing
end

function plugin.install(context, packages)
  local requested = request_packages(context, packages)
  if #requested == 0 then
    return true
  end

  local ok, err = ensure_query_binary(context)
  if not ok then
    tx_failed(context, err)
    return false
  end

  local installed_items = {}
  for _, pkg in ipairs(requested) do
    local target_name = package_name_value(pkg) or PACKAGE_NAME
    begin_step(context, "Installing " .. target_name)
    local resolved, resolve_err = resolved_package(context, pkg)
    if resolved == nil then
      tx_failed(context, resolve_err)
      return false
    end
    local installed_item, install_err = install_resolved_item(context, pkg, resolved)
    if installed_item == nil then
      tx_failed(context, install_err)
      return false
    end
    if not upsert_registry_item(context, pkg, installed_item) then
      tx_failed(context, "failed to update installed registry")
      return false
    end
    installed_items[#installed_items + 1] = installed_item
  end
  emit_event(context, "installed", installed_items)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  local request = request_object(context)
  local local_path = first_non_empty(path, read_field(request, "localPath"), read_field(context, "localPath"))
  if local_path == nil then
    tx_failed(context, "missing local path")
    return false
  end

  local kind = local_path_kind(local_path)
  local version = first_non_empty(read_field(request, "version"), read_field(context, "version"), DEFAULT_SOURCE_VERSION)
  local item, err
  begin_step(context, "Installing local newlisp")
  if kind == "binary" then
    local variant = lower(flag_value(collect_flags(context, request), "variant") or "")
    if not is_supported_variant(variant) or variant == "source" then
      if lower(local_path):sub(-4) == ".exe" then
        variant = "win64-utf8"
      else
        variant = default_variant_for_host(context)
        if variant == "source" then
          variant = "macos-utf8"
        end
      end
    end
    item, err = install_local_binary(context, request, local_path, variant, version)
  elseif kind == "archive" then
    item, err = install_local_source_archive(context, request, local_path, version)
  else
    item, err = install_local_source_dir(context, request, local_path, version)
  end

  if item == nil then
    tx_failed(context, err)
    return false
  end
  if not upsert_registry_item(context, request, item) then
    tx_failed(context, "failed to update installed registry")
    return false
  end
  emit_event(context, "installed", { item })
  tx_success(context)
  return true
end

function plugin.remove(context, packages)
  local requested = request_packages(context, packages)
  if #requested == 0 then
    return true
  end
  local current = load_registry(context, requested[1])
  local removed = {}
  local remaining = shallow_copy(current)

  for _, pkg in ipairs(requested) do
    local variant = normalize_requested_variant(context, pkg)
    begin_step(context, "Removing " .. package_id_for_variant(variant))
    local next_items = {}
    local removed_item = nil
    for _, item in ipairs(remaining) do
      local extra = type(item.extraFields) == "table" and item.extraFields or {}
      if removed_item == nil and lower(extra.variant) == variant then
        removed_item = item
      else
        next_items[#next_items + 1] = item
      end
    end
    if removed_item ~= nil then
      local install_path = read_field(removed_item.extraFields, "installPath")
      if non_empty(install_path) ~= nil then
        if not rm_rf(context, install_path) then
          tx_failed(context, "failed to remove install path")
          return false
        end
      end
      removed[#removed + 1] = removed_item
      remaining = next_items
    end
  end
  if not save_registry(context, requested[1], remaining) then
    tx_failed(context, "failed to update installed registry")
    return false
  end
  emit_event(context, "deleted", removed)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  local targets = request_packages(context, packages)
  if #targets == 0 then
    local installed = load_registry(context, nil)
    for _, item in ipairs(installed) do
      targets[#targets + 1] = {
        name = item.packageId,
        action = "update",
        flags = { "variant=" .. tostring(read_field(item.extraFields, "variant") or "source") },
      }
    end
  end
  local updated = {}
  for _, pkg in ipairs(targets) do
    local variant = normalize_requested_variant(context, pkg)
    begin_step(context, "Updating " .. package_id_for_variant(variant))
    local resolved, err = resolved_package(context, pkg)
    if resolved == nil then
      tx_failed(context, err)
      return false
    end
    local installed_item, install_err = install_resolved_item(context, pkg, resolved)
    if installed_item == nil then
      tx_failed(context, install_err)
      return false
    end
    if not upsert_registry_item(context, pkg, installed_item) then
      tx_failed(context, "failed to update installed registry")
      return false
    end
    updated[#updated + 1] = installed_item
  end
  emit_event(context, "updated", updated)
  tx_success(context)
  return true
end

function plugin.list(context)
  local items = load_registry(context, nil)
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  local installed = load_registry(context, nil)
  if #installed == 0 then
    emit_event(context, "outdated", {})
    return {}
  end

  local catalog, latest = remote_catalog(context, installed[1])
  if catalog == nil then
    log_warn(context, "newlisp remote catalog unavailable during outdated check")
    emit_event(context, "outdated", {})
    return {}
  end
  local result = {}
  for _, item in ipairs(installed) do
    if compare_versions(item.version, latest) < 0 then
      local copy = shallow_copy(item)
      copy.latestVersion = latest
      result[#result + 1] = copy
    end
  end
  emit_event(context, "outdated", result)
  return result
end

function plugin.search(context, prompt)
  local ok, err = ensure_query_binary(context)
  if not ok then
    tx_failed(context, err)
    return {}
  end

  local query = lower(first_non_empty(prompt, read_field(request_object(context), "prompt")) or "")
  local catalog, latest, historical, historical_windows, historical_macos, historical_source_dates = remote_catalog(context, nil)
  if catalog == nil then
    emit_event(context, "searched", {})
    return {}
  end
  local results = {}
  for _, item in ipairs(catalog) do
    local haystack = lower(item.packageId .. " " .. item.name .. " " .. (item.extraFields.variant or ""))
    if query == "" or haystack:find(query, 1, true) ~= nil then
      results[#results + 1] = item
    end
  end
  for _, version in ipairs(historical or {}) do
    if compare_versions(version, latest) ~= 0 then
      local source_item = build_source_item(version, historical_source_dates and historical_source_dates[version] or nil)
      local haystack = lower(source_item.packageId .. " " .. source_item.version .. " source")
      if query == "" or haystack:find(query, 1, true) ~= nil or lower(version):find(query, 1, true) ~= nil then
        results[#results + 1] = source_item
      end
    end
  end
  for _, entry in ipairs(historical_windows or {}) do
    local item = build_historical_windows_item(entry, latest)
    local haystack = lower(item.packageId .. " " .. item.version .. " " .. (item.extraFields.variant or "") .. " " .. (item.extraFields.fileName or ""))
    if query == "" or haystack:find(query, 1, true) ~= nil then
      results[#results + 1] = item
    end
  end
  for _, entry in ipairs(historical_macos or {}) do
    local item = build_historical_macos_item(entry, latest)
    local haystack = lower(item.packageId .. " " .. item.version .. " " .. (item.extraFields.variant or "") .. " " .. (item.extraFields.fileName or "") .. " " .. (item.extraFields.releaseDate or ""))
    if query == "" or haystack:find(query, 1, true) ~= nil then
      results[#results + 1] = item
    end
  end
  emit_event(context, "searched", results)
  return results
end

function plugin.info(context, name)
  local request = request_object(context)
  local prompt = first_non_empty(name, read_field(request, "prompt"), read_field(request, "name"), PACKAGE_NAME)
  local target = lower(prompt)

  for _, item in ipairs(load_registry(context, nil)) do
    if lower(item.packageId) == target or lower(item.name) == target or lower(read_field(item.extraFields, "variant") or "") == target or lower(item.packageId .. ":" .. tostring(item.version or "")) == target then
      emit_event(context, "informed", item)
      return item
    end
  end

  local catalog, latest, historical, historical_windows, historical_macos, historical_source_dates = remote_catalog(context, nil)
  if catalog == nil then
    emit_event(context, "informed", {})
    return {}
  end
  for _, item in ipairs(catalog) do
    if target == lower(item.packageId) or target == lower(item.name) or target == lower(read_field(item.extraFields, "variant") or "") then
      emit_event(context, "informed", item)
      return item
    end
  end
  for _, entry in ipairs(historical_windows or {}) do
    local item = build_historical_windows_item(entry, latest)
    local file_name = lower(item.extraFields.fileName or "")
    local raw_file_name = lower(entry.fileName or "")
    if target == lower(item.packageId .. ":" .. item.version)
      or target == lower(item.packageId)
      or target == lower(entry.variant .. ":" .. entry.version)
      or target == lower(entry.version)
      or target == file_name
      or target == raw_file_name
      or target == lower("newlisp-" .. encode_windows_release_version(entry.version)) then
      emit_event(context, "informed", item)
      return item
    end
  end
  for _, entry in ipairs(historical_macos or {}) do
    local item = build_historical_macos_item(entry, latest)
    local file_name = lower(item.extraFields.fileName or "")
    if target == lower(item.packageId .. ":" .. item.version)
      or target == lower(item.packageId)
      or target == lower(entry.variant .. ":" .. entry.version)
      or target == lower(entry.version)
      or target == file_name
      or target == lower((item.extraFields.releaseDate or "") .. " " .. entry.variant) then
      emit_event(context, "informed", item)
      return item
    end
  end
  for _, version in ipairs(historical or {}) do
    if target == lower(version) or target == lower("newlisp/source:" .. version) or target == lower("newlisp-" .. version) then
      local item = build_source_item(version, historical_source_dates and historical_source_dates[version] or nil)
      item.latestVersion = latest
      emit_event(context, "informed", item)
      return item
    end
  end
  emit_event(context, "informed", {})
  return {}
end

function plugin.resolvePackage(context, package)
  local resolved, _ = resolved_package(context, package)
  if resolved ~= nil then
    local merged = shallow_copy(type(package) == "table" and package or {})
    for key, value in pairs(resolved) do
      merged[key] = value
    end
    return merged
  end
  return package
end

function plugin.shutdown()
  return true
end

return plugin
