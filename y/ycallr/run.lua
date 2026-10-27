plugin = {}

local PLUGIN_NAME = "ycallr"
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
  return join_path(cache, "ycallr")
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
  return "ycallr"
end

function plugin.getVersion()
  return PLUGIN_VERSION
end

function plugin.getRequirements()
  return {}
end

function plugin.getCategories()
  return { "package-manager", "api", "cli" }
end

function plugin.getSecurityMetadata()
  return {
    privilegeLevel = "user",
    capabilities = { "exec", "network" },
    writeScopes = { { kind = "user-home-subpath", value = ".cache/ycallr" } },
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
  tx_begin(context, "install ycallr packages")
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
    if source_type ~= "" and source_type ~= "index" then
      tx_failed(context, "unsupported catalog source type for " .. package_id .. ": " .. source_type)
      return false
    end
    local ok, install_error = install_from_index(context, paths, catalog_entry)
    if not ok then
      tx_failed(context, install_error)
      return false
    end
    records = upsert_installed(records, {
      id = trim(catalog_entry.id),
      version = trim(catalog_entry.version),
      sourceType = "index",
    })
    emit_event(context, "installed", { name = package_id, version = trim(catalog_entry.version) })
  end
  save_installed_records(paths, records)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  tx_begin(context, "install local ycallr package")
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
  tx_begin(context, "remove ycallr package records")
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
      description = "Installed ycallr catalog package",
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
        description = "Installed ycallr catalog package",
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
