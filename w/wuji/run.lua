plugin = {}

local PLUGIN_NAME = "wuji"
local PLUGIN_VERSION = "0.1.0"
local STATE_SCHEMA_VERSION = 1

local function trim(value)
  return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function starts_with(value, prefix)
  return tostring(value or ""):sub(1, #prefix) == prefix
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

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function run_shell(command)
  local handle = io.popen(command .. " 2>&1")
  if handle == nil then
    return false, "", 1
  end
  local output = handle:read("*a") or ""
  local ok, _, code = handle:close()
  if ok == true then
    return true, output, 0
  end
  return false, output, tonumber(code) or 1
end

local function exec_run(context, command)
  if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
    return context.exec.run(command)
  end
  if reqpack ~= nil and reqpack.exec ~= nil and type(reqpack.exec.run) == "function" then
    return reqpack.exec.run(command)
  end
  return nil
end

local function run_command(context, command)
  local result = exec_run(context, command)
  if result ~= nil then
    return result.success == true, trim(result.stdout or ""), tonumber(result.exitCode) or 1
  end
  return run_shell(command)
end

local function read_file(path)
  local file = io.open(path, "rb")
  if file == nil then
    return nil
  end
  local content = file:read("*a") or ""
  file:close()
  return content
end

local function write_file(path, content)
  local parent = path:match("^(.*)/[^/]+$")
  if parent ~= nil and parent ~= "" then
    run_shell("mkdir -p " .. shell_quote(parent))
  end
  local file, err = io.open(path, "wb")
  if file == nil then
    return false, err
  end
  file:write(content or "")
  file:close()
  return true
end

local function decode_json(text)
  local index = 1
  local length = #text
  local function skip_whitespace()
    while index <= length and text:sub(index, index):match("%s") do
      index = index + 1
    end
  end
  local parse_value
  local function parse_string()
    index = index + 1
    local start_index = index
    while index <= length do
      local char = text:sub(index, index)
      if char == '"' then
        local value = text:sub(start_index, index - 1)
        index = index + 1
        return value
      end
      if char == "\\" then
        index = index + 2
      else
        index = index + 1
      end
    end
    error("unterminated json string")
  end
  local function parse_array()
    index = index + 1
    skip_whitespace()
    local items = {}
    if text:sub(index, index) == "]" then
      index = index + 1
      return items
    end
    while true do
      items[#items + 1] = parse_value()
      skip_whitespace()
      local char = text:sub(index, index)
      if char == "]" then
        index = index + 1
        return items
      end
      if char ~= "," then
        error("expected ',' in array")
      end
      index = index + 1
      skip_whitespace()
    end
  end
  local function parse_object()
    index = index + 1
    skip_whitespace()
    local object = {}
    if text:sub(index, index) == "}" then
      index = index + 1
      return object
    end
    while true do
      skip_whitespace()
      if text:sub(index, index) ~= '"' then
        error("expected object key")
      end
      local key = parse_string()
      skip_whitespace()
      if text:sub(index, index) ~= ":" then
        error("expected ':'")
      end
      index = index + 1
      object[key] = parse_value()
      skip_whitespace()
      local char = text:sub(index, index)
      if char == "}" then
        index = index + 1
        return object
      end
      if char ~= "," then
        error("expected ',' in object")
      end
      index = index + 1
    end
  end
  function parse_value()
    skip_whitespace()
    local char = text:sub(index, index)
    if char == '"' then
      return parse_string()
    end
    if char == "{" then
      return parse_object()
    end
    if char == "[" then
      return parse_array()
    end
    if char == "t" and text:sub(index, index + 3) == "true" then
      index = index + 4
      return true
    end
    if char == "f" and text:sub(index, index + 4) == "false" then
      index = index + 5
      return false
    end
    if char == "n" and text:sub(index, index + 3) == "null" then
      index = index + 4
      return nil
    end
    local start_index = index
    while index <= length and text:sub(index, index):match("[%d%+%-%.eE]") do
      index = index + 1
    end
    local number_text = text:sub(start_index, index - 1)
    if number_text ~= "" then
      return tonumber(number_text)
    end
    error("invalid json token")
  end
  return parse_value()
end

local function read_json_file(path)
  local content = read_file(path)
  if content == nil then
    return nil, "file not found: " .. path
  end
  local ok, value = pcall(decode_json, content)
  if not ok then
    return nil, "failed to parse json: " .. tostring(value)
  end
  return value
end

local function fetch_json(url, context)
  local target = trim(url)
  if starts_with(target, "file://") then
    return read_json_file(target:sub(8))
  end
  if starts_with(target, "/") then
    return read_json_file(target)
  end
  local ok, output, code = run_command(context, "curl -fsSL " .. shell_quote(target))
  if not ok then
    return nil, "failed to fetch " .. target .. " (exit " .. tostring(code) .. ")"
  end
  local ok_decode, value = pcall(decode_json, output)
  if not ok_decode then
    return nil, "failed to parse json from " .. target
  end
  return value
end

local function cache_home()
  local cache_home_env = read_proc_environ_value("XDG_CACHE_HOME")
  if cache_home_env ~= nil and cache_home_env ~= "" then
    return cache_home_env
  end
  local home = read_proc_environ_value("HOME")
  if home == nil or home == "" then
    return nil
  end
  return join_path(home, ".cache")
end

local function data_home()
  local data_home_env = read_proc_environ_value("XDG_DATA_HOME")
  if data_home_env ~= nil and data_home_env ~= "" then
    return data_home_env
  end
  local home = read_proc_environ_value("HOME")
  if home == nil or home == "" then
    return nil
  end
  return join_path(home, ".local/share")
end

local function plugin_dir(context)
  if context ~= nil and context.plugin ~= nil and trim(context.plugin.dir) ~= "" then
    return trim(context.plugin.dir)
  end
  local data = data_home()
  if data == nil then
    return nil
  end
  return join_path(data, "reqpack/plugins", PLUGIN_NAME)
end

local function default_data_root()
  local cache = cache_home()
  if cache == nil then
    return nil
  end
  return join_path(cache, "wuji")
end

local function state_paths(cache_root)
  return {
    cache_root = cache_root,
    index_root = join_path(cache_root, "index"),
    installed_path = join_path(cache_root, "index", "installed.json"),
  }
end

local function load_installed_records(paths)
  local records = read_json_file(paths.installed_path)
  if records == nil or type(records) ~= "table" then
    return { schemaVersion = STATE_SCHEMA_VERSION, packages = {} }
  end
  if records.packages == nil then
    records.packages = {}
  end
  return records
end

local function save_installed_records(paths, records)
  run_shell("mkdir -p " .. shell_quote(paths.index_root))
  local lines = {
    "{",
    '  "schemaVersion": ' .. STATE_SCHEMA_VERSION .. ",",
    '  "packages": [',
  }
  for package_index, record in ipairs(records.packages or {}) do
    lines[#lines + 1] = "    {"
    lines[#lines + 1] = string.format('      "id": %q,', record.id)
    lines[#lines + 1] = string.format('      "version": %q,', record.version)
    lines[#lines + 1] = string.format('      "sourceType": %q', record.sourceType or "index")
    if package_index == #(records.packages or {}) then
      lines[#lines + 1] = "    }"
    else
      lines[#lines + 1] = "    },"
    end
  end
  lines[#lines + 1] = "  ]"
  lines[#lines + 1] = "}"
  write_file(paths.installed_path, table.concat(lines, "\n") .. "\n")
end

local function upsert_installed(records, record)
  local updated = { schemaVersion = STATE_SCHEMA_VERSION, packages = {} }
  local replaced = false
  for _, existing in ipairs(records.packages or {}) do
    if existing.id == record.id then
      updated.packages[#updated.packages + 1] = record
      replaced = true
    else
      updated.packages[#updated.packages + 1] = existing
    end
  end
  if not replaced then
    updated.packages[#updated.packages + 1] = record
  end
  return updated
end

local function is_record_installed(records, package_id, version)
  for _, record in ipairs(records.packages or {}) do
    if record.id == package_id and trim(record.version) == trim(version) then
      return true
    end
  end
  return false
end

local function load_repository_config(context)
  local dir = plugin_dir(context)
  if dir == nil then
    return nil, "plugin directory unavailable"
  end
  local config = read_json_file(join_path(dir, "default-package-repositories.json"))
  if config == nil then
    return nil, "default-package-repositories.json not found"
  end
  return config
end

local function refresh_catalog(context, paths)
  local config, config_error = load_repository_config(context)
  if config == nil then
    return nil, config_error
  end
  local catalog = {}
  for _, repository in ipairs(config.repositories or {}) do
    if repository.enabled ~= false then
      local url = trim(repository.url)
      if url ~= "" then
        local payload, fetch_error = fetch_json(url, context)
        if payload == nil then
          return nil, fetch_error
        end
        for _, entry in ipairs(payload.packages or {}) do
          catalog[#catalog + 1] = entry
        end
      end
    end
  end
  run_shell("mkdir -p " .. shell_quote(paths.index_root))
  return catalog
end

local function find_catalog_record(catalog, package_id, version)
  local wanted_version = trim(version)
  for _, entry in ipairs(catalog or {}) do
    if trim(entry.id) == trim(package_id) then
      if wanted_version == "" or trim(entry.version) == wanted_version then
        return entry
      end
    end
  end
  return nil
end

local function index_package_name(entry)
  local name = trim(entry.indexName)
  if name ~= "" then
    return name
  end
  return trim(entry.id)
end

local function host_architecture()
  local ok, output = run_shell("uname -m")
  if not ok then
    return "x86_64"
  end
  local arch = trim(output)
  if arch == "amd64" then
    return "x86_64"
  end
  if arch == "arm64" then
    return "aarch64"
  end
  return arch
end

local function host_system()
  local ok, output = run_shell("uname -s")
  if not ok then
    return "linux"
  end
  local system = trim(output):lower()
  if system == "darwin" then
    return "macos"
  end
  return "linux"
end

local function select_index_package(index, package_name)
  local arch = host_architecture()
  local system = host_system()
  for _, entry in ipairs(index.packages or {}) do
    if trim(entry.name) == trim(package_name)
      and trim(entry.architecture) == arch
      and type(entry.system) == "table"
      and trim(entry.system[1]) == system then
      return entry
    end
  end
  return nil
end

local function download_file(url, destination, context)
  run_shell("mkdir -p " .. shell_quote(destination:match("^(.*)/[^/]+$") or "."))
  local ok, output, code = run_command(context, "curl -fL " .. shell_quote(url) .. " -o " .. shell_quote(destination))
  if not ok then
    return false, "download failed (" .. tostring(code) .. "): " .. trim(output)
  end
  return true
end

local function install_rqp_archive(context, archive_path)
  if context ~= nil and context.rqp ~= nil and type(context.rqp.installLocal) == "function" then
    if not context.rqp.installLocal(archive_path) then
      return false, "rqp installLocal failed for " .. trim(archive_path)
    end
    return true
  end
  local command = "rqp --non-interactive install " .. shell_quote(archive_path)
  if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
    local result = context.exec.run(command)
    if not result.success then
      return false, trim(result.stderr ~= "" and result.stderr or result.stdout)
    end
    return true
  end
  local ok, output, code = run_shell(command)
  if not ok then
    return false, "rqp install failed (" .. tostring(code) .. "): " .. trim(output)
  end
  return true
end

local function install_from_index(context, paths, catalog_entry)
  local source = catalog_entry.source or {}
  if trim(source.type) ~= "" and trim(source.type) ~= "index" then
    return false, "catalog entry does not provide index source for " .. trim(catalog_entry.id)
  end
  local index, fetch_error = fetch_json(trim(source.url), context)
  if index == nil then
    return false, fetch_error
  end
  local package_name = index_package_name(catalog_entry)
  local package_entry = select_index_package(index, package_name)
  if package_entry == nil then
    return false, "no package for host platform in index for " .. trim(catalog_entry.id)
  end
  local temp_dir = join_path(paths.index_root, "downloads")
  local archive_name = package_entry.url:match("/([^/]+)$") or "package.rqp"
  local archive_path = join_path(temp_dir, archive_name)
  local downloaded, download_error = download_file(package_entry.url, archive_path, context)
  if not downloaded then
    return false, download_error
  end
  return install_rqp_archive(context, archive_path)
end

local function plugin_install_root()
  local data = data_home()
  if data == nil then
    return nil
  end
  return join_path(data, "wuji", "plugins")
end

local function install_plugin_files(context, catalog_entry)
  local source = catalog_entry.source or {}
  if trim(source.type) ~= "plugin" then
    return false, "catalog entry does not provide plugin source for " .. trim(catalog_entry.id)
  end
  local plugin_root = plugin_install_root()
  if plugin_root == nil then
    return false, "plugin install directory unavailable"
  end
  run_shell("mkdir -p " .. shell_quote(plugin_root))
  for _, file_entry in ipairs(source.files or {}) do
    local destination = join_path(plugin_root, trim(file_entry.path))
    local url = trim(file_entry.url)
    if url == "" or trim(file_entry.path) == "" then
      return false, "plugin file entry requires url and path"
    end
    local downloaded, download_error = download_file(url, destination, context)
    if not downloaded then
      return false, download_error
    end
  end
  return true
end


local function driver_install_root()
  local data = data_home()
  if data == nil then
    return nil
  end
  return join_path(data, "wuji", "drivers")
end

local function wuji_core_root()
  local data = data_home()
  if data == nil then
    return nil
  end
  return join_path(data, "wuji", "wuji-core")
end

local function ensure_wuji_core(context, paths)
  local core_root = wuji_core_root()
  if core_root == nil then
    return false, "wuji-core install directory unavailable"
  end
  if read_file(join_path(core_root, "go.mod")) ~= nil then
    return true
  end
  local ref = "main"
  local slug = "Coditary/wuji-core"
  local archive_root = "wuji-core-" .. ref
  local nested_root = join_path(core_root, archive_root)
  if read_file(join_path(nested_root, "go.mod")) ~= nil then
    local repair_dir = join_path(paths.index_root, "wuji-core-repair")
    run_shell("rm -rf " .. shell_quote(repair_dir))
    local ok, output, code = run_command(
      context,
      "mv " .. shell_quote(nested_root) .. " " .. shell_quote(repair_dir)
    )
    if not ok then
      return false, "wuji-core layout repair failed (" .. tostring(code) .. "): " .. trim(output)
    end
    run_shell("rm -rf " .. shell_quote(core_root))
    ok, output, code = run_command(
      context,
      "mv " .. shell_quote(repair_dir) .. " " .. shell_quote(core_root)
    )
    if not ok then
      return false, "wuji-core layout repair failed (" .. tostring(code) .. "): " .. trim(output)
    end
    return true
  end
  local temp_dir = join_path(paths.index_root, "wuji-core-extract")
  run_shell("rm -rf " .. shell_quote(temp_dir))
  run_shell("rm -rf " .. shell_quote(core_root))
  run_shell("mkdir -p " .. shell_quote(temp_dir))
  local tarball_url = "https://github.com/" .. slug .. "/archive/refs/heads/" .. ref .. ".tar.gz"
  local ok, output, code = run_command(
    context,
    "curl -fL " .. shell_quote(tarball_url) .. " | tar xz -C " .. shell_quote(temp_dir)
  )
  if not ok then
    return false, "wuji-core download failed (" .. tostring(code) .. "): " .. trim(output)
  end
  ok, output, code = run_command(
    context,
    "mv " .. shell_quote(join_path(temp_dir, archive_root)) .. " " .. shell_quote(core_root)
  )
  run_shell("rm -rf " .. shell_quote(temp_dir))
  if not ok then
    return false, "wuji-core extract failed (" .. tostring(code) .. "): " .. trim(output)
  end
  if read_file(join_path(core_root, "go.mod")) == nil then
    return false, "wuji-core download did not produce go.mod"
  end
  return true
end

local function github_repo_slug(repo_url)
  local slug = trim(repo_url):gsub("%.git$", "")
  slug = slug:gsub("^git@", "")
  slug = slug:gsub("^https://", "")
  slug = slug:gsub("^http://", "")
  slug = slug:gsub("^github%.com/", "")
  slug = slug:gsub("^www%.github%.com/", "")
  slug = slug:gsub("^/+", "")
  return slug
end

local function wuji_bin_root()
  local data = data_home()
  if data == nil then
    return nil
  end
  return join_path(data, "wuji", "bin")
end

local function driver_binary_name(package_id)
  return "wuji-driver-" .. trim(package_id)
end

local function path_exists(path)
  local ok = run_shell("test -e " .. shell_quote(path))
  return ok
end

local function yaml_quote(value)
  return '"' .. tostring(value):gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function package_spec(pkg)
  local system = trim(pkg.system)
  local name = trim(pkg.name)
  if system == "" or name == "" then
    return nil
  end
  local spec = system .. ":" .. name
  local version = trim(pkg.version)
  if version ~= "" then
    spec = spec .. "@" .. version
  end
  return spec
end

local function ensure_driver_manifest(context, driver_dir, package_id)
  if context ~= nil and context.manifest ~= nil and type(context.manifest.ensure) == "function" then
    if not context.manifest.ensure(driver_dir) then
      return false, "failed to ensure driver manifest dependencies for " .. package_id
    end
    return true
  end

  local manifest = nil
  if reqpack ~= nil and reqpack.manifest ~= nil and type(reqpack.manifest.load) == "function" then
    manifest = reqpack.manifest.load(driver_dir)
  end
  if manifest == nil or manifest.packages == nil then
    if read_file(join_path(driver_dir, "reqpack.lua")) == nil then
      return true
    end
    return false, "failed to load reqpack.lua for driver " .. package_id
  end

  for _, pkg in ipairs(manifest.packages) do
    local spec = package_spec(pkg)
    if spec ~= nil then
      local command = "rqp --non-interactive install " .. shell_quote(spec)
      local result = exec_run(context, command)
      if result == nil or result.success ~= true then
        local detail = "unknown error"
        if result ~= nil then
          detail = trim(result.stderr ~= "" and result.stderr or result.stdout)
        end
        return false, "failed to install driver dependency " .. spec .. ": " .. detail
      end
    end
  end
  return true
end

local function load_driver_manifest(driver_dir)
  if reqpack ~= nil and reqpack.manifest ~= nil and type(reqpack.manifest.load) == "function" then
    return reqpack.manifest.load(driver_dir)
  end
  return nil
end

local function manifest_capabilities(manifest)
  if manifest == nil or type(manifest.driver) ~= "table" then
    return {}
  end
  local capabilities = manifest.driver.capabilities
  if type(capabilities) ~= "table" then
    return {}
  end
  return capabilities
end

local function manifest_defaults(manifest)
  if manifest == nil or type(manifest.driver) ~= "table" then
    return {}
  end
  local defaults = manifest.driver.defaults
  if type(defaults) ~= "table" then
    return {}
  end
  return defaults
end

local function has_capability(capabilities, name)
  local wanted = trim(name)
  for _, capability in ipairs(capabilities or {}) do
    if trim(capability) == wanted then
      return true
    end
  end
  return false
end

local function driver_config_fields(package_id, driver_dir, bin_path)
  local fields = {
    driver_bin = bin_path,
    auto_start_driver = "true",
  }
  local manifest = load_driver_manifest(driver_dir)
  for key, value in pairs(manifest_defaults(manifest)) do
    if trim(key) ~= "" and value ~= nil then
      fields[trim(key)] = tostring(value)
    end
  end
  if package_id == "llama" then
    fields.server_bin = join_path(driver_dir, "vendor/llama/llama-server")
    fields.models_dir = join_path(driver_dir, "models")
    fields.use_ollama_api = "true"
  elseif package_id == "a1111" then
    fields.manage_server = "false"
  elseif package_id == "raggo" or package_id == "gorag" then
    fields.ollama_api = "http://127.0.0.1:11434"
  end
  return fields, manifest_capabilities(manifest)
end

local function write_reqpack_driver_config(entries, options)
  local home = read_proc_environ_value("HOME")
  if home == nil or home == "" then
    return false, "HOME unavailable for wuji config"
  end
  local config_dir = join_path(home, ".wuji")
  local config_path = join_path(config_dir, "drivers-reqpack.yaml")
  run_shell("mkdir -p " .. shell_quote(config_dir))
  local lines = {}
  if options ~= nil and trim(options.text_driver or "") ~= "" then
    lines[#lines + 1] = "capability_drivers:"
    lines[#lines + 1] = "  text: " .. yaml_quote(trim(options.text_driver))
  end
  lines[#lines + 1] = "drivers:"
  local ids = {}
  for package_id in pairs(entries) do
    ids[#ids + 1] = package_id
  end
  table.sort(ids)
  for _, package_id in ipairs(ids) do
    local fields = entries[package_id]
    lines[#lines + 1] = "  " .. package_id .. ":"
    local keys = {}
    for key in pairs(fields) do
      keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
      local value = fields[key]
      if value == "true" or value == "false" then
        lines[#lines + 1] = "    " .. key .. ": " .. value
      else
        lines[#lines + 1] = "    " .. key .. ": " .. yaml_quote(value)
      end
    end
  end
  local ok, err = write_file(config_path, table.concat(lines, "\n") .. "\n")
  if not ok then
    return false, err or "failed to write drivers-reqpack.yaml"
  end
  return true
end

local function rebuild_reqpack_driver_config(paths, package_id, driver_dir, bin_path)
  local driver_root = driver_install_root()
  local bin_root = wuji_bin_root()
  if driver_root == nil or bin_root == nil then
    return false, "wuji driver or bin directory unavailable"
  end
  local records = load_installed_records(paths)
  local entries = {}
  for _, record in ipairs(records.packages or {}) do
    if trim(record.sourceType) == "driver" then
      local installed_id = trim(record.id)
      local installed_dir = join_path(driver_root, installed_id)
      local installed_bin = join_path(bin_root, driver_binary_name(installed_id))
      if path_exists(installed_bin) then
        local fields, _ = driver_config_fields(installed_id, installed_dir, installed_bin)
        entries[installed_id] = fields
      end
    end
  end
  local capabilities = {}
  if trim(package_id) ~= "" and trim(bin_path) ~= "" then
    local fields
    fields, capabilities = driver_config_fields(trim(package_id), driver_dir, bin_path)
    entries[trim(package_id)] = fields
  end
  local options = {}
  if has_capability(capabilities, "text") then
    options.text_driver = trim(package_id)
  end
  return write_reqpack_driver_config(entries, options)
end

local function publish_driver_binary(driver_dir, package_id)
  local bin_name = driver_binary_name(package_id)
  local built = join_path(driver_dir, "bin", bin_name)
  if not path_exists(built) then
    return false, "built driver binary not found: " .. built
  end
  local bin_root = wuji_bin_root()
  local home = read_proc_environ_value("HOME")
  if bin_root == nil or home == nil or home == "" then
    return false, "wuji bin directory unavailable"
  end
  local local_bin = join_path(home, ".local", "bin")
  local canonical = join_path(bin_root, bin_name)
  run_shell("mkdir -p " .. shell_quote(bin_root) .. " " .. shell_quote(local_bin))
  local ok, output, code = run_shell(
    "cp -f "
      .. shell_quote(built)
      .. " "
      .. shell_quote(canonical)
      .. " && chmod +x "
      .. shell_quote(canonical)
      .. " && ln -sf "
      .. shell_quote(canonical)
      .. " "
      .. shell_quote(join_path(local_bin, bin_name))
  )
  if not ok then
    return false, "failed to publish driver binary (" .. tostring(code) .. "): " .. trim(output)
  end
  return true, canonical
end

local function bootstrap_driver_source(context, driver_dir, package_id)
  if package_id ~= "llama" then
    return true
  end
  local makefile = join_path(driver_dir, "Makefile")
  if read_file(makefile) == nil then
    return true
  end
  local ok, output, code = run_command(context, "make -C " .. shell_quote(driver_dir) .. " setup")
  if not ok then
    return false, "llama vendor setup failed (" .. tostring(code) .. "): " .. trim(output)
  end
  run_shell("mkdir -p " .. shell_quote(join_path(driver_dir, "models")))
  return true
end

local function install_driver_source(context, paths, catalog_entry)
  local source = catalog_entry.source or {}
  if trim(source.type) ~= "driver" then
    return false, "catalog entry does not provide driver source for " .. trim(catalog_entry.id)
  end
  local driver_root = driver_install_root()
  if driver_root == nil then
    return false, "driver install directory unavailable"
  end
  local package_id = trim(catalog_entry.id)
  local subpath = trim(source.path)
  if subpath == "" then
    subpath = package_id
  end
  local repo = trim(source.repo)
  if repo == "" then
    repo = "https://github.com/Coditary/wuji-driver.git"
  end
  local ref = trim(source.ref)
  if ref == "" then
    ref = "main"
  end
  local slug = github_repo_slug(repo)
  local repo_name = slug:match("([^/]+)$") or "wuji-driver"
  local archive_root = repo_name .. "-" .. ref
  local temp_dir = join_path(paths.index_root, "driver-extract", package_id)
  run_shell("rm -rf " .. shell_quote(temp_dir))
  run_shell("mkdir -p " .. shell_quote(temp_dir))
  local tarball_url = "https://github.com/" .. slug .. "/archive/refs/heads/" .. ref .. ".tar.gz"
  local ok, output, code = run_command(context, "curl -fL " .. shell_quote(tarball_url) .. " | tar xz -C " .. shell_quote(temp_dir))
  if not ok then
    return false, "driver download failed (" .. tostring(code) .. "): " .. trim(output)
  end
  local extracted = join_path(temp_dir, archive_root, subpath)
  run_shell("rm -rf " .. shell_quote(join_path(driver_root, package_id)))
  run_shell("mkdir -p " .. shell_quote(driver_root))
  ok, output, code = run_command(context, "mv " .. shell_quote(extracted) .. " " .. shell_quote(join_path(driver_root, package_id)))
  if not ok then
    return false, "driver extract failed (" .. tostring(code) .. "): " .. trim(output)
  end
  run_shell("rm -rf " .. shell_quote(temp_dir))
  local driver_dir = join_path(driver_root, package_id)
  ok, install_error = ensure_driver_manifest(context, driver_dir, package_id)
  if not ok then
    return false, install_error
  end
  ok, install_error = bootstrap_driver_source(context, driver_dir, package_id)
  if not ok then
    return false, install_error
  end
  ok, install_error = ensure_wuji_core(context, paths)
  if not ok then
    return false, install_error
  end
  local core_replace = "../../wuji-core"
  ok, output, code = run_command(
    context,
    "cd "
      .. shell_quote(driver_dir)
      .. " && go mod edit -dropreplace=github.com/coditary/wuji-core"
      .. " && go mod edit -replace=github.com/coditary/wuji-core=" .. core_replace
      .. " && go mod tidy"
  )
  if not ok then
    return false, "driver dependency setup failed (" .. tostring(code) .. "): " .. trim(output)
  end
  local makefile = join_path(driver_dir, "Makefile")
  if read_file(makefile) ~= nil then
    ok, output, code = run_command(context, "make -C " .. shell_quote(driver_dir) .. " build")
    if not ok then
      return false, "driver build failed (" .. tostring(code) .. "): " .. trim(output)
    end
  end
  local canonical_bin
  ok, canonical_bin = publish_driver_binary(driver_dir, package_id)
  if not ok then
    return false, canonical_bin
  end
  ok, install_error = rebuild_reqpack_driver_config(paths, package_id, driver_dir, canonical_bin)
  if not ok then
    return false, install_error
  end
  return true
end

local function tx_begin(context, label)
  if context ~= nil and context.tx ~= nil and type(context.tx.begin_step) == "function" then
    context.tx.begin_step(label)
  end
end

local function tx_success(context)
  if context ~= nil and context.tx ~= nil and type(context.tx.success) == "function" then
    context.tx.success()
  end
end

local function tx_failed(context, message)
  if context ~= nil and context.tx ~= nil and type(context.tx.failed) == "function" then
    context.tx.failed(message)
  end
end

local function emit_event(context, name, payload)
  if context ~= nil and context.events ~= nil and type(context.events[name]) == "function" then
    context.events[name](payload)
  end
end

local function filter_missing_packages(installed_records, packages)
  local missing = {}
  for _, pkg in ipairs(packages or {}) do
    local package_id = trim(pkg.name)
    local version = trim(pkg.version)
    if package_id ~= "" then
      if version == "" then
        local found = false
        for _, record in ipairs(installed_records.packages or {}) do
          if record.id == package_id then
            found = true
            break
          end
        end
        if not found then
          missing[#missing + 1] = pkg
        end
      elseif not is_record_installed(installed_records, package_id, version) then
        missing[#missing + 1] = pkg
      end
    end
  end
  return missing
end

function plugin.getName()
  return "wuji"
end

function plugin.getVersion()
  return PLUGIN_VERSION
end

function plugin.getRequirements()
  return {}
end

function plugin.getCategories()
  return { "package-manager", "ai", "cli", "drivers", "plugins" }
end

function plugin.getSecurityMetadata()
  return {
    privilegeLevel = "user",
    capabilities = { "exec", "network" },
    writeScopes = {
      { kind = "user-home-subpath", value = ".cache/wuji" },
      { kind = "user-home-subpath", value = ".local/share/wuji/plugins" },
      { kind = "user-home-subpath", value = ".local/share/wuji/drivers" },
    },
    networkScopes = {
      "github.com",
      "raw.githubusercontent.com",
      "api.github.com",
    },
  }
end

function plugin.getMissingPackages(packages)
  local cache_root = default_data_root()
  if cache_root == nil then
    return packages or {}
  end
  return filter_missing_packages(load_installed_records(state_paths(cache_root)), packages or {})
end

function plugin.install(context, packages)
  tx_begin(context, "install wuji packages")
  local cache_root = default_data_root()
  if cache_root == nil then
    tx_failed(context, "cache directory unavailable")
    return false
  end
  local paths = state_paths(cache_root)
  local catalog, catalog_error = refresh_catalog(context, paths)
  if catalog == nil then
    tx_failed(context, catalog_error)
    return false
  end
  local records = load_installed_records(paths)
  local requested = filter_missing_packages(records, packages or {})
  if #requested == 0 then
    tx_success(context)
    return true
  end
  for _, pkg in ipairs(requested) do
    local package_id = trim(pkg.name)
    local version = trim(pkg.version)
    local catalog_entry = find_catalog_record(catalog, package_id, version)
    if catalog_entry == nil then
      tx_failed(context, "package not found in catalog: " .. package_id)
      return false
    end
    local source_type = trim((catalog_entry.source or {}).type)
    local ok, install_error
    if source_type == "plugin" then
      ok, install_error = install_plugin_files(context, catalog_entry)
    elseif source_type == "driver" then
      ok, install_error = install_driver_source(context, paths, catalog_entry)
    elseif source_type == "" or source_type == "index" then
      ok, install_error = install_from_index(context, paths, catalog_entry)
    else
      tx_failed(context, "unsupported catalog source type for " .. package_id .. ": " .. source_type)
      return false
    end
    if not ok then
      tx_failed(context, install_error)
      return false
    end
    records = upsert_installed(records, {
      id = trim(catalog_entry.id),
      version = trim(catalog_entry.version),
      sourceType = source_type == "" and "index" or source_type,
    })
    emit_event(context, "installed", { name = package_id, version = trim(catalog_entry.version) })
  end
  save_installed_records(paths, records)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  tx_begin(context, "install local wuji package")
  if trim(path):match("%.rqp$") then
    local ok, install_error = install_rqp_archive(context, path)
    if not ok then
      tx_failed(context, install_error)
      return false
    end
    tx_success(context)
    return true
  end
  tx_failed(context, "local path must be a .rqp archive")
  return false
end

function plugin.remove(context, packages)
  tx_begin(context, "remove wuji package records")
  local cache_root = default_data_root()
  if cache_root == nil then
    tx_failed(context, "cache directory unavailable")
    return false
  end
  local paths = state_paths(cache_root)
  local records = load_installed_records(paths)
  for _, pkg in ipairs(packages or {}) do
    local package_id = trim(pkg.name)
    for index, record in ipairs(records.packages) do
      if record.id == package_id then
        table.remove(records.packages, index)
        emit_event(context, "deleted", { name = package_id, version = record.version })
        break
      end
    end
  end
  save_installed_records(paths, records)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  return plugin.install(context, packages)
end

function plugin.list(context)
  local cache_root = default_data_root()
  if cache_root == nil then
    return {}
  end
  local records = load_installed_records(state_paths(cache_root))
  local items = {}
  for _, record in ipairs(records.packages or {}) do
    items[#items + 1] = {
      name = record.id,
      version = record.version,
      description = "Installed wuji catalog package",
      extraFields = { sourceType = record.sourceType },
    }
  end
  return items
end

function plugin.search(context, prompt)
  local cache_root = default_data_root()
  if cache_root == nil then
    return {}
  end
  local paths = state_paths(cache_root)
  local catalog, catalog_error = refresh_catalog(context, paths)
  if catalog == nil then
    return {}
  end
  local query = trim(prompt):lower()
  local items = {}
  for _, entry in ipairs(catalog) do
    local id = trim(entry.id):lower()
    local description = trim(entry.description or ""):lower()
    if query == "" or id:find(query, 1, true) or description:find(query, 1, true) then
      items[#items + 1] = {
        name = entry.id,
        version = entry.version,
        description = entry.description or "",
        extraFields = { source = entry.source, tags = entry.tags },
      }
    end
  end
  return items
end

function plugin.info(context, name)
  local package_id = trim(name)
  local cache_root = default_data_root()
  if cache_root == nil then
    return {}
  end
  local paths = state_paths(cache_root)
  local records = load_installed_records(paths)
  for _, record in ipairs(records.packages or {}) do
    if record.id == package_id then
      return {
        name = record.id,
        version = record.version,
        description = "Installed wuji catalog package",
        extraFields = { sourceType = record.sourceType },
      }
    end
  end
  local catalog, _ = refresh_catalog(context, paths)
  if catalog ~= nil then
    local entry = find_catalog_record(catalog, package_id, "")
    if entry ~= nil then
      return {
        name = entry.id,
        version = entry.version,
        description = entry.description or "",
        extraFields = { source = entry.source, tags = entry.tags },
      }
    end
  end
  return {}
end

function plugin.outdated(context)
  return {}
end

return plugin
