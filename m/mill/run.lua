plugin = {}

local PLUGIN_ID = "mill"
local PLUGIN_NAME = "Mill"
local PLUGIN_VERSION = "0.1.0"
local PACKAGE_TYPE = "mill-launcher"
local HOMEPAGE_URL = "https://mill-build.org/"
local METADATA_URL = "https://repo1.maven.org/maven2/com/lihaoyi/mill-dist/maven-metadata.xml"
local DOWNLOAD_URL_TEMPLATE = "https://repo1.maven.org/maven2/com/lihaoyi/mill-dist/%s/mill-dist-%s-mill.sh"

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

local function starts_with(value, prefix)
  local text = tostring(value or "")
  local expected = tostring(prefix or "")
  return expected == "" or text:sub(1, #expected) == expected
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

function read_proc_environ_value(name)
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

local function request_flags(context)
  local direct = object_flags(context)
  if #direct > 0 then
    return direct
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

local function mill_roots(context)
  local data_root = join_path(reqpack_root("data", context), PLUGIN_ID)
  local cache_root = join_path(reqpack_root("cache", context), PLUGIN_ID)
  local config_root = join_path(reqpack_root("config", context), PLUGIN_ID)
  return {
    dataRoot = data_root,
    cacheRoot = cache_root,
    configRoot = config_root,
    binDir = join_path(data_root, "bin"),
    recordsDir = join_path(data_root, "records"),
    downloadsDir = join_path(cache_root, "downloads"),
    userCacheDir = join_path(cache_root, "user-cache"),
    coursierCacheDir = join_path(cache_root, "coursier"),
    coursierJvmCacheDir = join_path(cache_root, "coursier-jvm"),
    homeDir = join_path(data_root, "home"),
    xdgCacheDir = join_path(cache_root, "xdg-cache"),
    xdgConfigDir = join_path(config_root, "xdg-config"),
    xdgDataDir = join_path(data_root, "xdg-data"),
  }
end

local function env_prefix(context)
  local roots = mill_roots(context)
  return table.concat({
    "NO_COLOR=1",
    "LC_ALL=C",
    "LANG=C",
    "LANGUAGE=C",
    "HOME=" .. shell_quote(roots.homeDir),
    "XDG_CACHE_HOME=" .. shell_quote(roots.xdgCacheDir),
    "XDG_CONFIG_HOME=" .. shell_quote(roots.xdgConfigDir),
    "XDG_DATA_HOME=" .. shell_quote(roots.xdgDataDir),
    "MILL_USER_CACHE_DIR=" .. shell_quote(roots.userCacheDir),
    "MILL_DOWNLOAD_PATH=" .. shell_quote(roots.downloadsDir),
    "COURSIER_CACHE=" .. shell_quote(roots.coursierCacheDir),
    "COURSIER_JVM_CACHE=" .. shell_quote(roots.coursierJvmCacheDir),
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
  local roots = mill_roots(context)
  for _, path in ipairs({
    roots.binDir,
    roots.recordsDir,
    roots.downloadsDir,
    roots.userCacheDir,
    roots.coursierCacheDir,
    roots.coursierJvmCacheDir,
    roots.homeDir,
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

local function read_file(path)
  local handle = io.open(path, "r")
  if handle ~= nil then
    local content = handle:read("*a")
    handle:close()
    return content
  end
  local result = exec_run(nil, "cat " .. shell_quote(path))
  if result ~= nil and result.success == true then
    return result.stdout
  end
  return nil
end

local function write_file(context, path, content)
  local dir = tostring(path or ""):match("^(.*)/[^/]+$")
  if dir ~= nil and dir ~= "" then
    ensure_directory(context, dir)
  end
  local result = exec_run(context, "mkdir -p " .. shell_quote(dir or ".") .. " && printf %s " .. shell_quote(content) .. " > " .. shell_quote(path))
  return result ~= nil and result.success == true
end

local function path_exists(context, path)
  local handle = io.open(path, "r")
  if handle ~= nil then
    handle:close()
    return true
  end
  local result = exec_run(context, "test -e " .. shell_quote(path))
  return result ~= nil and result.success == true
end

local function list_dir_tsv(context, dir)
  local result = exec_run(context, "ls -1A " .. shell_quote(dir))
  if result == nil or result.success ~= true then
    return {}
  end
  local paths = {}
  for _, line in ipairs(split_lines(result.stdout)) do
    if line:match("%.tsv$") ~= nil then
      paths[#paths + 1] = join_path(dir, trim(line))
    end
  end
  return paths
end

local function safe_id(value)
  local text = lower(trim(value)):gsub("[^a-z0-9]+", "_")
  text = text:gsub("_+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if text == "" then
    return "mill"
  end
  return text
end

local function record_path_for_id(context, id)
  return join_path(mill_roots(context).recordsDir, safe_id(id) .. ".tsv")
end

local function encode_record(record)
  local keys = { "id", "name", "version", "launcherPath", "downloadPath", "homepage", "updatedAt" }
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

local function read_record(path)
  local content = read_file(path)
  if content == nil then
    return nil
  end
  return decode_record(content)
end

local function write_record(context, record)
  return write_file(context, record_path_for_id(context, record.id), encode_record(record))
end

local function load_records(context)
  local records = {}
  for _, path in ipairs(list_dir_tsv(context, mill_roots(context).recordsDir)) do
    local record = read_record(path)
    if record ~= nil and trim(record.id) ~= "" then
      records[#records + 1] = record
    end
  end
  return records
end

local function remove_file(context, path)
  local result = exec_run(context, "rm -f " .. shell_quote(path))
  if result ~= nil and result.success == true then
    return true
  end
  if os ~= nil and type(os.remove) == "function" then
    os.remove(path)
    return true
  end
  return false
end

local function package_name(package)
  local explicit = trim(read_field(package, "name") or "")
  local name, version = explicit:match("^([^@]+)@(.+)$")
  if name ~= nil then
    return trim(name), non_empty(read_field(package, "version")) or trim(version)
  end
  return explicit, non_empty(read_field(package, "version"))
end

local function package_target(package)
  local name, version = package_name(package)
  if trim(name) == "" then
    return nil, nil, nil
  end
  if lower(name) ~= PLUGIN_ID then
    return nil, nil, nil
  end
  if version ~= nil then
    return PLUGIN_ID .. "@" .. version, PLUGIN_ID, version
  end
  return PLUGIN_ID, PLUGIN_ID, nil
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

local function remote_metadata_path(context)
  return join_path(mill_roots(context).cacheRoot, "maven-metadata.xml")
end

local function parse_versions_from_xml(xml)
  local versions = {}
  for version in tostring(xml or ""):gmatch("<version>([^<]+)</version>") do
    local text = trim(version)
    if text ~= "" then
      versions[#versions + 1] = text
    end
  end
  local release = tostring(xml or ""):match("<release>([^<]+)</release>")
  local latest = tostring(xml or ""):match("<latest>([^<]+)</latest>")
  return {
    versions = versions,
    release = non_empty(release),
    latest = non_empty(latest),
  }
end

local function fetch_remote_metadata(context)
  if not ensure_runtime_dirs(context) then
    return nil, "mill runtime directory setup failed"
  end
  local target = remote_metadata_path(context)
  local result = exec_run(context, "curl -fsSL " .. shell_quote(METADATA_URL) .. " -o " .. shell_quote(target))
  if result == nil or result.success ~= true then
    return nil, "mill metadata fetch failed"
  end
  local xml = read_file(target)
  if xml == nil or trim(xml) == "" then
    xml = result.stdout
  end
  if xml == nil then
    return nil, "mill metadata read failed"
  end
  local parsed = parse_versions_from_xml(xml)
  if parsed.release == nil and parsed.latest == nil and #parsed.versions == 0 then
    return nil, "mill metadata parse failed"
  end
  return parsed, nil
end

local function latest_version(metadata)
  return non_empty(metadata and metadata.release) or non_empty(metadata and metadata.latest) or (metadata and metadata.versions and metadata.versions[#metadata.versions]) or nil
end

local function launcher_paths(context, version)
  local roots = mill_roots(context)
  local base = "mill-" .. trim(version)
  return {
    download = join_path(roots.downloadsDir, base .. ".sh"),
    launcher = join_path(roots.binDir, base),
  }
end

local function launcher_item(record)
  return {
    name = record.name or PLUGIN_ID,
    packageId = record.id,
    version = record.version,
    installed = true,
    status = "installed",
    packageType = PACKAGE_TYPE,
    homepage = record.homepage or HOMEPAGE_URL,
    summary = "Mill build tool launcher",
    description = "Official Mill launcher bootstrap script version " .. tostring(record.version or ""),
    extraFields = {
      launcherPath = record.launcherPath,
      downloadPath = record.downloadPath,
    },
  }
end

local function synthetic_item(version)
  return {
    name = PLUGIN_ID,
    packageId = PLUGIN_ID .. "@" .. version,
    version = version,
    packageType = PACKAGE_TYPE,
    homepage = HOMEPAGE_URL,
    summary = "Mill build tool launcher",
    description = "Official Mill launcher bootstrap script version " .. tostring(version),
  }
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

local function detect_launcher_version(context, path)
  local result = exec_run(context, with_env(context, shell_quote(path) .. " --version"))
  if result == nil or result.success ~= true then
    return nil, "mill version probe failed"
  end
  local version = tostring(result.stdout or ""):match("([0-9][0-9A-Za-z%._%-]+)")
  return non_empty(version), nil
end

local function install_version(context, version, source_path)
  version = trim(version)
  if version == "" then
    return nil, "mill version missing"
  end
  if not ensure_runtime_dirs(context) then
    return nil, "mill runtime directory setup failed"
  end

  local paths = launcher_paths(context, version)
  if source_path ~= nil then
    local copy_result = exec_run(context, "cp " .. shell_quote(source_path) .. " " .. shell_quote(paths.launcher))
    if copy_result == nil or copy_result.success ~= true then
      return nil, "mill local launcher copy failed"
    end
  else
    local url = string.format(DOWNLOAD_URL_TEMPLATE, version, version)
    local download_result = exec_run(context, "curl -fsSL " .. shell_quote(url) .. " -o " .. shell_quote(paths.download))
    if download_result == nil or download_result.success ~= true then
      return nil, "mill launcher download failed"
    end
    local copy_result = exec_run(context, "cp " .. shell_quote(paths.download) .. " " .. shell_quote(paths.launcher))
    if copy_result == nil or copy_result.success ~= true then
      return nil, "mill launcher copy failed"
    end
  end

  local chmod_result = exec_run(context, "chmod +x " .. shell_quote(paths.launcher))
  if chmod_result == nil or chmod_result.success ~= true then
    return nil, "mill launcher chmod failed"
  end

  local detected, detect_error = detect_launcher_version(context, paths.launcher)
  if detected == nil then
    return nil, detect_error
  end

  local record = {
    id = PLUGIN_ID .. "@" .. detected,
    name = PLUGIN_ID,
    version = detected,
    launcherPath = paths.launcher,
    downloadPath = source_path == nil and paths.download or source_path,
    homepage = HOMEPAGE_URL,
    updatedAt = now_timestamp(),
  }
  if not write_record(context, record) then
    return nil, "mill record write failed"
  end
  return launcher_item(record), nil
end

local function package_error(context, message, unavailable_payload)
  tx_failed(context, message)
  if unavailable_payload ~= nil then
    emit_event(context, "unavailable", unavailable_payload)
  end
  return false
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
  return { "Development", "Build Tool", "Scala" }
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "install", "installLocal", "remove", "update", "list", "search", "info", "outdated" },
    ecosystemScopes = { "scala", "mill" },
    writeScopes = {
      "user-home-subpath:.local/share/reqpack/mill",
      "user-home-subpath:.cache/reqpack/mill",
      "user-home-subpath:.config/reqpack/mill",
    },
    networkScopes = {
      "https://repo1.maven.org",
      "https://repo.maven.apache.org",
      "https://mill-build.org",
    },
    privilegeLevel = "none",
  }
end

function plugin.init()
  return true
end

function plugin.getMissingPackages(context, packages)
  local requested = packages or {}
  local action = lower(read_field(context, "action") or read_field(read_field(context, "request") or {}, "action") or "")
  local metadata = nil
  local latest = nil
  if action == "install" or action == "update" then
    metadata = select(1, fetch_remote_metadata(context))
    latest = latest_version(metadata or {})
  end

  local missing = {}
  for _, package in ipairs(requested) do
    local _, name, version = package_target(package)
    if name == nil then
      missing[#missing + 1] = package
    else
      local wanted = version or latest
      local record = wanted ~= nil and find_record_by_version(context, wanted) or nil
      if action == "install" then
        if record == nil then
          missing[#missing + 1] = package
        end
      elseif action == "remove" then
        if version ~= nil and record == nil then
          -- already absent
        else
          missing[#missing + 1] = package
        end
      elseif action == "update" then
        if version ~= nil and record ~= nil and latest ~= nil and trim(record.version) ~= trim(latest) then
          missing[#missing + 1] = package
        end
      else
        missing[#missing + 1] = package
      end
    end
  end
  return missing
end

function plugin.install(context, packages)
  local requested = packages or {}
  local local_path = non_empty(read_field(context, "localPath") or read_field(read_field(context, "request") or {}, "localPath"))
  if local_path ~= nil then
    return plugin.installLocal(context, local_path)
  end
  local metadata, error_message = fetch_remote_metadata(context)
  if metadata == nil then
    return package_error(context, error_message or "mill metadata fetch failed")
  end
  local latest = latest_version(metadata)
  if latest == nil then
    return package_error(context, "mill latest version unavailable")
  end

  local installed = {}
  if #requested == 0 then
    requested = { { name = PLUGIN_ID, version = latest } }
  end

  for _, package in ipairs(requested) do
    local _, name, version = package_target(package)
    if name == nil then
      return package_error(context, "mill install package name missing")
    end
    local target_version = version or latest
    begin_step(context, "install mill launcher")
    local item, install_error = install_version(context, target_version, nil)
    if item == nil then
      return package_error(context, install_error or "mill install failed")
    end
    installed[#installed + 1] = item
  end

  emit_event(context, "installed", installed)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  local target = trim(path)
  if target == "" then
    target = trim(read_field(context, "localPath") or read_field(read_field(context, "request") or {}, "localPath") or "")
  end
  if target == "" then
    return package_error(context, "mill local install path missing", { reason = "local-path-missing" })
  end
  if not path_exists(context, target) then
    return package_error(context, "mill local install path missing", { path = target, reason = "path-missing" })
  end
  if not ensure_runtime_dirs(context) then
    return package_error(context, "mill runtime directory setup failed")
  end
  begin_step(context, "import local mill launcher")
  local detected, detect_error = detect_launcher_version(context, target)
  if detected == nil then
    return package_error(context, detect_error or "mill version probe failed", { path = target, reason = "version-probe-failed" })
  end
  local item, install_error = install_version(context, detected, target)
  if item == nil then
    return package_error(context, install_error or "mill local install failed")
  end
  emit_event(context, "installed", { item })
  tx_success(context)
  return true
end

function plugin.remove(context, packages)
  local requested = packages or {}
  local removed = {}
  for _, package in ipairs(requested) do
    local _, name, version = package_target(package)
    if name ~= nil and version ~= nil then
      local record = find_record_by_version(context, version)
      if record ~= nil then
        begin_step(context, "remove mill launcher")
        remove_file(context, record.launcherPath)
        remove_file(context, record_path_for_id(context, record.id))
        removed[#removed + 1] = launcher_item(record)
      end
    end
  end
  emit_event(context, "deleted", removed)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  local metadata, error_message = fetch_remote_metadata(context)
  if metadata == nil then
    return package_error(context, error_message or "mill metadata fetch failed")
  end
  local latest = latest_version(metadata)
  if latest == nil then
    return package_error(context, "mill latest version unavailable")
  end

  local targets = {}
  if packages == nil or #packages == 0 then
    for _, record in ipairs(load_records(context)) do
      if trim(record.version) ~= trim(latest) then
        targets[#targets + 1] = { name = PLUGIN_ID, version = latest }
      end
    end
  else
    for _, package in ipairs(packages) do
      local _, name, version = package_target(package)
      if name ~= nil then
        local record = version ~= nil and find_record_by_version(context, version) or nil
        if record ~= nil and trim(record.version) ~= trim(latest) then
          targets[#targets + 1] = { name = PLUGIN_ID, version = latest }
        end
      end
    end
  end

  local updated = {}
  local seen = {}
  for _, package in ipairs(targets) do
    local key = PLUGIN_ID .. "@" .. tostring(package.version)
    if not seen[key] then
      seen[key] = true
      begin_step(context, "update mill launcher")
      local item, install_error = install_version(context, package.version, nil)
      if item == nil then
        return package_error(context, install_error or "mill update failed")
      end
      updated[#updated + 1] = item
    end
  end
  emit_event(context, "updated", updated)
  tx_success(context)
  return true
end

function plugin.list(context)
  local items = {}
  for _, record in ipairs(load_records(context)) do
    items[#items + 1] = launcher_item(record)
  end
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  local metadata, error_message = fetch_remote_metadata(context)
  if metadata == nil then
    log_warn(context, error_message or "mill metadata fetch failed")
    emit_event(context, "outdated", {})
    return {}
  end
  local latest = latest_version(metadata)
  if latest == nil then
    emit_event(context, "outdated", {})
    return {}
  end
  local items = {}
  for _, record in ipairs(load_records(context)) do
    if trim(record.version) ~= trim(latest) then
      local item = launcher_item(record)
      item.status = "outdated"
      item.latestVersion = latest
      items[#items + 1] = item
    end
  end
  emit_event(context, "outdated", items)
  return items
end

function plugin.search(context, prompt)
  local search_prompt = trim(prompt)
  if search_prompt == "" then
    search_prompt = trim(read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
  end
  if search_prompt == "" then
    emit_event(context, "searched", {})
    return {}
  end
  local metadata, error_message = fetch_remote_metadata(context)
  if metadata == nil then
    log_warn(context, error_message or "mill metadata fetch failed")
    emit_event(context, "searched", {})
    return {}
  end
  local items = {}
  for _, version in ipairs(metadata.versions or {}) do
    local package_id = PLUGIN_ID .. "@" .. version
    local haystack = lower(package_id)
    if haystack:find(lower(search_prompt), 1, true) ~= nil or lower(version):find(lower(search_prompt), 1, true) ~= nil then
      items[#items + 1] = synthetic_item(version)
    end
  end
  emit_event(context, "searched", items)
  return items
end

function plugin.info(context, name)
  local target = trim(name)
  if target == "" then
    target = trim(read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
  end
  local metadata, _ = fetch_remote_metadata(context)
  local latest = latest_version(metadata or {})

  if target == "" or lower(target) == PLUGIN_ID then
    if latest == nil then
      emit_event(context, "informed", {})
      return {}
    end
    local record = find_record_by_version(context, latest)
    local item = record ~= nil and launcher_item(record) or synthetic_item(latest)
    emit_event(context, "informed", item)
    return item
  end

  local tool, version = target:match("^([^@]+)@(.+)$")
  if lower(trim(tool or "")) ~= PLUGIN_ID or trim(version or "") == "" then
    emit_event(context, "informed", {})
    return {}
  end

  local record = find_record_by_version(context, version)
  if record ~= nil then
    local item = launcher_item(record)
    emit_event(context, "informed", item)
    return item
  end

  for _, remote_version in ipairs((metadata and metadata.versions) or {}) do
    if trim(remote_version) == trim(version) then
      local item = synthetic_item(remote_version)
      emit_event(context, "informed", item)
      return item
    end
  end

  emit_event(context, "informed", {})
  return {}
end

function plugin.shutdown()
  return true
end

return plugin
