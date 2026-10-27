plugin = {}

local PLUGIN_ID = "x10build"
local PLUGIN_NAME = "x10build"
local PLUGIN_VERSION = "0.1.0"
local REPO_URL = "https://github.com/x10-lang/x10"
local RELEASES_LATEST_API_URL = "https://api.github.com/repos/x10-lang/x10/releases/latest"
local RELEASES_TAG_API_PREFIX = "https://api.github.com/repos/x10-lang/x10/releases/tags/"
local HOMEPAGE_URL = "https://x10-lang.org"
local SOURCE_KIND_RELEASE = "release"
local SOURCE_KIND_LOCAL = "local"
local REQUIRED_BINARIES = { "curl", "tar", "ant" }

plugin.fileExtensions = { ".x10" }

local function trim(value)
  return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
  return trim(value):lower()
end

local function starts_with(value, prefix)
  local text = tostring(value or "")
  local wanted = tostring(prefix or "")
  return text:sub(1, #wanted) == wanted
end

local function split_lines(value)
  local text = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
  local lines = {}
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

local function basename(path)
  local cleaned = trim(path):gsub("[/\\]+$", "")
  return cleaned:match("[^/\\]+$") or cleaned
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

local function shallow_copy(value)
  local copy = {}
  for key, item in pairs(value or {}) do
    copy[key] = item
  end
  return copy
end

local function first_nonempty(...)
  for index = 1, select("#", ...) do
    local value = trim(select(index, ...))
    if value ~= "" then
      return value
    end
  end
  return nil
end

local function getenv(name)
  if os ~= nil and type(os.getenv) == "function" then
    local value = os.getenv(name)
    if value ~= nil and value ~= "" then
      return value
    end
  end

  if reqpack ~= nil and reqpack.host ~= nil and type(reqpack.host.env) == "table" then
    local value = reqpack.host.env[name]
    if value ~= nil and value ~= "" then
      return trim(value)
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

local function expand_placeholders(value)
  local text = tostring(value or "")
  local fixture_root = getenv("REQPACK_TEST_FIXTURE_ROOT")
  if fixture_root ~= nil and fixture_root ~= "" then
    text = text:gsub("%$%{fixtureRoot%}", fixture_root)
  end
  return text
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
      stderr = "missing ReqPack exec runner",
      exitCode = 127,
    }
  end
  return normalize_run_result(first, second, third, fourth, fifth)
end

local function is_command_success(result)
  if type(result) ~= "table" then
    return false
  end
  if result.success == true or result.ok == true then
    return true
  end
  local exit_code = result.exitCode or result.exit_code or result.code or result.status
  return exit_code == 0
end

local function command_exists(binary)
  return is_command_success(exec_run(nil, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1"))
end

local function path_exists(context, path)
  return is_command_success(exec_run(context, "test -e " .. shell_quote(path)))
end

local function file_exists(context, path)
  return is_command_success(exec_run(context, "test -f " .. shell_quote(path)))
end

local function directory_exists(context, path)
  return is_command_success(exec_run(context, "test -d " .. shell_quote(path)))
end

local function ensure_directory(context, path)
  local result = exec_run(context, "mkdir -p " .. shell_quote(path))
  if is_command_success(result) then
    return true
  end
  return nil, first_nonempty(result.stderr, result.stdout, "failed to create directory")
end

local function remove_path(context, path)
  local result = exec_run(context, "rm -rf " .. shell_quote(path))
  if is_command_success(result) then
    return true
  end
  return nil, first_nonempty(result.stderr, result.stdout, "failed to remove path")
end

local function copy_tree(context, from_path, to_path)
  local result = exec_run(context, "cp -R " .. shell_quote(from_path) .. " " .. shell_quote(to_path))
  if is_command_success(result) then
    return true
  end
  return nil, first_nonempty(result.stderr, result.stdout, "failed to copy tree")
end

local function object_flags(object)
  local value = read_field(object, "flags")
  if type(value) ~= "table" and type(value) ~= "userdata" then
    return {}
  end
  local flags = {}
  local ok = pcall(function()
    for _, item in ipairs(value) do
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

local function collect_flags(context, packages)
  local flags = {}
  local function collect_from(object)
    for _, flag in ipairs(object_flags(object)) do
      flags[#flags + 1] = flag
    end
  end
  collect_from(context)
  collect_from(read_field(context, "request"))
  for _, package in ipairs(packages or {}) do
    collect_from(package)
  end
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

local function default_cache_root()
  local home = getenv("HOME") or "~"
  return join_path(home, ".cache", "reqpack", PLUGIN_ID)
end

local function default_data_root()
  local home = getenv("HOME") or "~"
  return join_path(home, ".local", "share", "reqpack", PLUGIN_ID)
end

local function cache_root_for(context, packages)
  local override = flag_value(collect_flags(context, packages), "cache-root")
  if override ~= nil and override ~= "" then
    return expand_placeholders(override)
  end
  return default_cache_root()
end

local function data_root_for(context, packages)
  local override = flag_value(collect_flags(context, packages), "data-root")
  if override ~= nil and override ~= "" then
    return expand_placeholders(override)
  end
  return default_data_root()
end

local function releases_cache_dir(context, packages)
  return join_path(cache_root_for(context, packages), "releases")
end

local function archives_cache_dir(context, packages)
  return join_path(cache_root_for(context, packages), "archives")
end

local function sources_cache_dir(context, packages)
  return join_path(cache_root_for(context, packages), "sources")
end

local function installs_dir(context, packages)
  return join_path(data_root_for(context, packages), "installs")
end

local function metadata_dir(context, packages)
  return join_path(data_root_for(context, packages), "metadata")
end

local function installed_metadata_path(context, packages)
  return join_path(metadata_dir(context, packages), "installed.txt")
end

local function read_text_file(context, path)
  local expanded = expand_placeholders(path)
  local result = exec_run(context, "cat " .. shell_quote(expanded))
  if result ~= nil and result.success == true then
    return result.stdout
  end
  local handle = io.open(expanded, "rb")
  if handle == nil then
    return nil
  end
  local content = handle:read("*a")
  handle:close()
  return content
end

local function dirname(path)
  local cleaned = trim(path)
  local parent = cleaned:match("^(.*)/[^/]+$")
  if parent == nil or parent == "" then
    return "."
  end
  return parent
end

local function write_text_file(context, path, content)
  local expanded = expand_placeholders(path)
  local parent = dirname(expanded)
  local shell_result = exec_run(context, "mkdir -p " .. shell_quote(parent) .. " && printf %s " .. shell_quote(tostring(content or "")) .. " > " .. shell_quote(expanded))
  if shell_result ~= nil and shell_result.success == true then
    return true
  end
  local mkdir_result = exec_run(context, "mkdir -p " .. shell_quote(parent))
  if mkdir_result == nil or mkdir_result.success ~= true then
    return nil, "unable to create parent directory: " .. tostring(parent)
  end
  local handle = io.open(expanded, "wb")
  if handle ~= nil then
    local ok, err = handle:write(content or "")
    handle:close()
    if ok then
      return true
    end
    return nil, err or "write failed"
  end
  return nil, "unable to open file for write: " .. tostring(expanded)
end

local function parse_key_value_text(text)
  local data = {}
  for _, line in ipairs(split_lines(text)) do
    local key, value = line:match("^([^=]+)=(.*)$")
    if key ~= nil then
      data[trim(key)] = trim(value)
    end
  end
  return data
end

local function serialize_key_value_text(data)
  local order = {
    "name",
    "version",
    "installPath",
    "binPath",
    "sourceKind",
    "releaseUrl",
    "tarballUrl",
    "homepage",
    "license",
    "summary",
    "description",
  }
  local lines = {}
  for _, key in ipairs(order) do
    local value = trim(data[key])
    if value ~= "" then
      lines[#lines + 1] = key .. "=" .. value
    end
  end
  return table.concat(lines, "\n") .. "\n"
end

local function load_installed_metadata(context, packages)
  local path = installed_metadata_path(context, packages)
  local content = read_text_file(context, path)
  if content == nil or content == "" then
    return nil
  end
  local data = parse_key_value_text(content)
  if trim(data.name) == "" then
    return nil
  end
  return data
end

local function save_installed_metadata(context, packages, data)
  local ok, err = write_text_file(context, installed_metadata_path(context, packages), serialize_key_value_text(data))
  if ok then
    return true
  end
  return nil, err
end

local function clear_installed_metadata(context, packages)
  local path = installed_metadata_path(context, packages)
  if not path_exists(context, path) then
    return true
  end
  local result = exec_run(context, "rm -f " .. shell_quote(path))
  if result ~= nil and result.success == true then
    return true
  end
  local ok, err = os.remove(path)
  if ok then
    return true
  end
  return nil, err or "failed to remove metadata file"
end

local function ensure_layout(context, packages)
  for _, path in ipairs({
    releases_cache_dir(context, packages),
    archives_cache_dir(context, packages),
    sources_cache_dir(context, packages),
    installs_dir(context, packages),
    metadata_dir(context, packages),
  }) do
    local ok, err = ensure_directory(context, path)
    if not ok then
      return nil, err
    end
  end
  return true
end

local function canonical_name(name)
  local cleaned = lower(name)
  if cleaned == "" then
    return "x10"
  end
  if cleaned == "x10" or cleaned == "app:x10" or cleaned == "x10build" or cleaned == "app:x10build" then
    return "x10"
  end
  return cleaned
end

local function package_name(package)
  return canonical_name(trim(read_field(package, "name")))
end

local function package_version(package)
  return trim(read_field(package, "version"))
end

local function normalize_requested_package(package)
  local name = package_name(package)
  if name == "" then
    name = "x10"
  end
  return {
    name = name,
    version = package_version(package),
  }
end

local function package_matches_canonical(name)
  return canonical_name(name) == "x10"
end

local function tag_from_version(version)
  local cleaned = trim(version)
  if cleaned == "" or lower(cleaned) == "latest" then
    return nil
  end
  if starts_with(cleaned, "SF_RELEASE_") then
    return cleaned
  end
  return "SF_RELEASE_" .. cleaned:gsub("%.", "_")
end

local function version_from_tag(tag)
  local cleaned = trim(tag)
  if cleaned == "" then
    return nil
  end
  local body = cleaned:match("SF_RELEASE_(.+)$")
  if body ~= nil then
    return body:gsub("_", ".")
  end
  return cleaned
end

local function extract_json_string(text, key)
  local pattern = '"' .. key .. '"%s*:%s*"([^"]*)"'
  local value = tostring(text or ""):match(pattern)
  if value == nil then
    return nil
  end
  value = value:gsub("\\/", "/")
  value = value:gsub('\\"', '"')
  value = value:gsub("\\n", "\n")
  value = value:gsub("\\r", "\r")
  value = value:gsub("\\t", "\t")
  return value
end

local function extract_json_boolean(text, key)
  local value = tostring(text or ""):match('"' .. key .. '"%s*:%s*(true|false)')
  if value == nil then
    return nil
  end
  return value == "true"
end

local function extract_json_number(text, key)
  local value = tostring(text or ""):match('"' .. key .. '"%s*:%s*(-?%d+)')
  if value == nil then
    return nil
  end
  return tonumber(value)
end

local function extract_json_array_block(text, key)
  local source = tostring(text or "")
  local start_pos = source:find('"' .. key .. '"%s*:%s*%[', 1)
  if start_pos == nil then
    return nil
  end
  local open_pos = source:find("[", start_pos, true)
  if open_pos == nil then
    return nil
  end
  local depth = 0
  local in_string = false
  local escaped = false
  for index = open_pos, #source do
    local char = source:sub(index, index)
    if in_string then
      if escaped then
        escaped = false
      elseif char == "\\" then
        escaped = true
      elseif char == '"' then
        in_string = false
      end
    else
      if char == '"' then
        in_string = true
      elseif char == "[" then
        depth = depth + 1
      elseif char == "]" then
        depth = depth - 1
        if depth == 0 then
          return source:sub(open_pos, index)
        end
      end
    end
  end
  return nil
end

local function parse_json_object_array(array_text)
  local source = tostring(array_text or "")
  local objects = {}
  local depth = 0
  local in_string = false
  local escaped = false
  local object_start = nil
  for index = 1, #source do
    local char = source:sub(index, index)
    if in_string then
      if escaped then
        escaped = false
      elseif char == "\\" then
        escaped = true
      elseif char == '"' then
        in_string = false
      end
    else
      if char == '"' then
        in_string = true
      elseif char == "{" then
        depth = depth + 1
        if depth == 1 then
          object_start = index
        end
      elseif char == "}" then
        if depth == 1 and object_start ~= nil then
          objects[#objects + 1] = source:sub(object_start, index)
          object_start = nil
        end
        if depth > 0 then
          depth = depth - 1
        end
      end
    end
  end
  return objects
end

local function parse_release_assets(payload)
  local assets_block = extract_json_array_block(payload, "assets")
  if assets_block == nil then
    return {}
  end
  local assets = {}
  for _, object_text in ipairs(parse_json_object_array(assets_block)) do
    assets[#assets + 1] = {
      name = extract_json_string(object_text, "name"),
      label = extract_json_string(object_text, "label"),
      contentType = extract_json_string(object_text, "content_type"),
      state = extract_json_string(object_text, "state"),
      size = extract_json_number(object_text, "size"),
      downloadCount = extract_json_number(object_text, "download_count"),
      downloadUrl = extract_json_string(object_text, "browser_download_url"),
      apiUrl = extract_json_string(object_text, "url"),
    }
  end
  return assets
end

local function parse_release_payload(payload)
  local tag = extract_json_string(payload, "tag_name")
  local version = version_from_tag(tag)
  local name = extract_json_string(payload, "name")
  local html_url = extract_json_string(payload, "html_url")
  local tarball_url = extract_json_string(payload, "tarball_url")
  local zipball_url = extract_json_string(payload, "zipball_url")
  local body = extract_json_string(payload, "body")
  local published_at = extract_json_string(payload, "published_at")
  local draft = extract_json_boolean(payload, "draft")
  local prerelease = extract_json_boolean(payload, "prerelease")
  local assets = parse_release_assets(payload)
  if version == nil or tarball_url == nil then
    return nil
  end
  return {
    tag = tag,
    version = version,
    name = name,
    releaseUrl = html_url,
    tarballUrl = tarball_url,
    zipballUrl = zipball_url,
    body = body,
    publishedAt = published_at,
    draft = draft,
    prerelease = prerelease,
    assets = assets,
  }
end

local function release_api_url_for(version)
  local tag = tag_from_version(version)
  if tag == nil then
    return RELEASES_LATEST_API_URL
  end
  return RELEASES_TAG_API_PREFIX .. tag
end

local function release_cache_file_for(context, version, packages)
  local key = trim(version)
  if key == "" or lower(key) == "latest" then
    key = "latest"
  end
  return join_path(releases_cache_dir(context, packages), key .. ".json")
end

local function fetch_release(context, version, packages)
  local cache_file = release_cache_file_for(context, version, packages)
  local cached = read_text_file(context, cache_file)
  if cached ~= nil and cached ~= "" then
    local parsed_cached = parse_release_payload(cached)
    if parsed_cached ~= nil then
      return parsed_cached
    end
  end
  local api_url = release_api_url_for(version)
  local result = exec_run(context, "curl -fsSL " .. shell_quote(api_url) .. " -o " .. shell_quote(cache_file))
  if not is_command_success(result) then
    return nil, first_nonempty(result.stderr, result.stdout, "failed to fetch release metadata")
  end
  local payload = read_text_file(context, cache_file)
  if payload == nil or payload == "" then
    return nil, "empty release metadata"
  end
  local parsed = parse_release_payload(payload)
  if parsed == nil then
    return nil, "failed to parse release metadata"
  end
  return parsed
end

local function archive_path_for(context, version, packages)
  return join_path(archives_cache_dir(context, packages), "x10-" .. trim(version) .. ".tar.gz")
end

local function source_dir_for(context, version, packages)
  return join_path(sources_cache_dir(context, packages), "x10-" .. trim(version))
end

local function install_path_for(context, version, packages)
  return join_path(installs_dir(context, packages), trim(version))
end

local function ensure_release_archive(context, release, packages)
  local archive_path = archive_path_for(context, release.version, packages)
  if file_exists(context, archive_path) then
    return archive_path
  end
  local result = exec_run(context, "curl -fsSL " .. shell_quote(release.tarballUrl) .. " -o " .. shell_quote(archive_path))
  if not is_command_success(result) then
    return nil, first_nonempty(result.stderr, result.stdout, "failed to download release archive")
  end
  return archive_path
end

local function extract_release_source(context, release, packages)
  local source_dir = source_dir_for(context, release.version, packages)
  if directory_exists(context, join_path(source_dir, "x10.dist")) then
    return source_dir
  end
  local archive_path, err = ensure_release_archive(context, release, packages)
  if archive_path == nil then
    return nil, err
  end
  local ok, remove_err = remove_path(context, source_dir)
  if not ok then
    return nil, remove_err
  end
  ok, remove_err = ensure_directory(context, source_dir)
  if not ok then
    return nil, remove_err
  end
  local result = exec_run(context, "tar -xzf " .. shell_quote(archive_path) .. " -C " .. shell_quote(source_dir) .. " --strip-components=1")
  if not is_command_success(result) then
    return nil, first_nonempty(result.stderr, result.stdout, "failed to extract source archive")
  end
  return source_dir
end

local function infer_version_from_path(path)
  local name = basename(path)
  local version = name:match("(%d+[%._]%d+[%._]%d+)")
  if version ~= nil then
    return version:gsub("_", ".")
  end
  return nil
end

local function build_source_tree(context, source_root)
  local command = "sh -lc " .. shell_quote("cd " .. shell_quote(join_path(source_root, "x10.dist")) .. " && ant dist")
  local result = exec_run(context, command)
  if not is_command_success(result) then
    return nil, first_nonempty(result.stderr, result.stdout, "x10 build failed")
  end
  return join_path(source_root, "x10.dist")
end

local function install_built_dist(context, packages, version, built_dist_path, source_kind, release)
  local install_path = install_path_for(context, version, packages)
  local ok, err = remove_path(context, install_path)
  if not ok then
    return nil, err
  end
  ok, err = ensure_directory(context, installs_dir(context, packages))
  if not ok then
    return nil, err
  end
  ok, err = copy_tree(context, built_dist_path, install_path)
  if not ok then
    return nil, err
  end
  local metadata = {
    name = "x10",
    version = version,
    installPath = install_path,
    binPath = join_path(install_path, "bin"),
    sourceKind = source_kind,
    releaseUrl = release and release.releaseUrl or "",
    tarballUrl = release and release.tarballUrl or "",
    homepage = HOMEPAGE_URL,
    license = "EPL-1.0",
    summary = "X10 language compiler and runtime",
    description = "Official X10 toolchain built from upstream release or local source tree",
  }
  ok, err = save_installed_metadata(context, packages, metadata)
  if not ok then
    return nil, err
  end
  return metadata
end

local function package_record_from_metadata(metadata, release)
  if metadata == nil then
    return nil
  end
  local version = first_nonempty(metadata.version, release and release.version)
  local latest_version = release and release.version or nil
  local installed = trim(metadata.installPath) ~= ""
  return {
    name = "x10",
    packageId = version ~= nil and ("x10@" .. version) or "x10",
    version = version,
    latestVersion = latest_version,
    installed = installed,
    status = installed and ((latest_version ~= nil and latest_version ~= version) and "outdated" or "installed") or "available",
    summary = first_nonempty(metadata.summary, "X10 language compiler and runtime"),
    description = first_nonempty(metadata.description, "Official X10 toolchain built from upstream releases or local source trees"),
    homepage = first_nonempty(metadata.homepage, HOMEPAGE_URL),
    license = first_nonempty(metadata.license, "EPL-1.0"),
    categories = { "compiler", "language", "build-tool" },
    extraFields = {
      releaseName = first_nonempty(release and release.name),
      releaseTag = first_nonempty(release and release.tag),
      releaseUrl = first_nonempty(metadata.releaseUrl, release and release.releaseUrl),
      tarballUrl = first_nonempty(metadata.tarballUrl, release and release.tarballUrl),
      zipballUrl = first_nonempty(release and release.zipballUrl),
      releaseBody = first_nonempty(release and release.body),
      publishedAt = first_nonempty(release and release.publishedAt),
      draft = release and release.draft or false,
      prerelease = release and release.prerelease or false,
      assets = release and release.assets or {},
      assetCount = release and #release.assets or 0,
      sourceKind = metadata.sourceKind,
      installPath = metadata.installPath,
      binPath = metadata.binPath,
      repository = REPO_URL,
    },
  }
end

local function latest_release_record(context, packages)
  local release = fetch_release(context, nil, packages)
  if release == nil then
    return nil
  end
  return package_record_from_metadata({ name = "x10", version = release.version }, release)
end

local function ensure_required_binaries(context)
  for _, binary in ipairs(REQUIRED_BINARIES) do
    if not is_command_success(exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")) then
      local message = binary .. " not available"
      tx_failed(context, message)
      return false, message
    end
  end
  return true
end

local function ensure_unzip_if_needed(context, path)
  local cleaned = lower(path)
  if cleaned:sub(-4) ~= ".zip" then
    return true
  end
  if is_command_success(exec_run(context, "command -v " .. shell_quote("unzip") .. " >/dev/null 2>&1")) then
    return true
  end
  local message = "unzip not available"
  tx_failed(context, message)
  return false, message
end

local function install_release_package(context, request_package, event_name)
  local packages = { request_package }
  local ok, err = ensure_required_binaries(context)
  if not ok then
    return false, err
  end
  ok, err = ensure_layout(context, packages)
  if not ok then
    tx_failed(context, err)
    return false, err
  end

  local version = request_package.version
  begin_step(context, "resolve release")
  local release, release_err = fetch_release(context, version, packages)
  if release == nil then
    tx_failed(context, release_err)
    return false, release_err
  end
  begin_step(context, "prepare source")
  local source_dir, source_err = extract_release_source(context, release, packages)
  if source_dir == nil then
    tx_failed(context, source_err)
    return false, source_err
  end
  begin_step(context, "build x10")
  local built_dist_path, build_err = build_source_tree(context, source_dir)
  if built_dist_path == nil then
    tx_failed(context, build_err)
    return false, build_err
  end
  begin_step(context, "install build")
  local metadata, install_err = install_built_dist(context, packages, release.version, built_dist_path, SOURCE_KIND_RELEASE, release)
  if metadata == nil then
    tx_failed(context, install_err)
    return false, install_err
  end
  local item = package_record_from_metadata(metadata, release)
  emit_event(context, event_name, item)
  tx_success(context)
  return true
end

local function install_local_package(context, path, request_package, event_name)
  local local_path = expand_placeholders(path)
  if trim(local_path) == "" then
    local message = "missing local source path"
    tx_failed(context, message)
    emit_event(context, "unavailable", { path = path, reason = "missing-local-path" })
    return false, message
  end

  local packages = { request_package }
  local ok, err = ensure_required_binaries(context)
  if not ok then
    return false, err
  end
  ok, err = ensure_unzip_if_needed(context, local_path)
  if not ok then
    emit_event(context, "unavailable", { path = local_path, reason = "missing-unzip" })
    return false, err
  end
  ok, err = ensure_layout(context, packages)
  if not ok then
    tx_failed(context, err)
    return false, err
  end

  local source_root = nil
  local version = first_nonempty(request_package.version, infer_version_from_path(local_path), "local")
  local staged_source_dir = source_dir_for(context, version .. "-local", packages)

  if directory_exists(context, local_path) then
    source_root = local_path
  elseif lower(local_path):sub(-7) == ".tar.gz" or lower(local_path):sub(-4) == ".tgz" then
    local ok_remove, remove_err = remove_path(context, staged_source_dir)
    if not ok_remove then
      tx_failed(context, remove_err)
      return false, remove_err
    end
    ok_remove, remove_err = ensure_directory(context, staged_source_dir)
    if not ok_remove then
      tx_failed(context, remove_err)
      return false, remove_err
    end
    local result = exec_run(context, "tar -xzf " .. shell_quote(local_path) .. " -C " .. shell_quote(staged_source_dir) .. " --strip-components=1")
    if not is_command_success(result) then
      local message = first_nonempty(result.stderr, result.stdout, "failed to extract local archive")
      tx_failed(context, message)
      emit_event(context, "unavailable", { path = local_path, reason = "local-extract-failed" })
      return false, message
    end
    source_root = staged_source_dir
  elseif lower(local_path):sub(-4) == ".zip" then
    local ok_remove, remove_err = remove_path(context, staged_source_dir)
    if not ok_remove then
      tx_failed(context, remove_err)
      return false, remove_err
    end
    ok_remove, remove_err = ensure_directory(context, staged_source_dir)
    if not ok_remove then
      tx_failed(context, remove_err)
      return false, remove_err
    end
    local result = exec_run(context, "unzip -q " .. shell_quote(local_path) .. " -d " .. shell_quote(staged_source_dir))
    if not is_command_success(result) then
      local message = first_nonempty(result.stderr, result.stdout, "failed to extract local zip")
      tx_failed(context, message)
      emit_event(context, "unavailable", { path = local_path, reason = "local-extract-failed" })
      return false, message
    end
    source_root = staged_source_dir
  else
    local message = "unsupported local source path"
    tx_failed(context, message)
    emit_event(context, "unavailable", { path = local_path, reason = "local-install-unsupported" })
    return false, message
  end

  begin_step(context, "build x10")
  local built_dist_path, build_err = build_source_tree(context, source_root)
  if built_dist_path == nil then
    tx_failed(context, build_err)
    return false, build_err
  end
  begin_step(context, "install build")
  local metadata, install_err = install_built_dist(context, packages, version, built_dist_path, SOURCE_KIND_LOCAL, nil)
  if metadata == nil then
    tx_failed(context, install_err)
    return false, install_err
  end
  local item = package_record_from_metadata(metadata, nil)
  item.extraFields.localPath = local_path
  emit_event(context, event_name, item)
  tx_success(context)
  return true
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
  return { "compiler", "language", "build-tool" }
end

function plugin.getMissingPackages(context, packages)
  local request_action = lower(read_field(context, "action") or read_field(read_field(context, "request"), "action"))
  local installed = load_installed_metadata(context, packages)
  local missing = {}
  for _, package in ipairs(packages or {}) do
    local normalized = normalize_requested_package(package)
    if request_action == "remove" then
      if installed ~= nil and package_matches_canonical(normalized.name) then
        missing[#missing + 1] = package
      end
    elseif request_action == "update" then
      local release = fetch_release(context, nil, packages)
      if installed ~= nil and release ~= nil and trim(installed.version) ~= trim(release.version) then
        missing[#missing + 1] = package
      end
    else
      if installed == nil or trim(installed.version) ~= trim(normalized.version) then
        missing[#missing + 1] = package
      end
    end
  end
  return missing
end

function plugin.install(context, packages)
  local requested = packages or read_field(read_field(context, "request"), "packages") or {}
  if #requested == 0 then
    requested = { { name = "x10" } }
  end
  local package = normalize_requested_package(requested[1])
  if not package_matches_canonical(package.name) then
    local message = "unsupported package: " .. tostring(package.name)
    tx_failed(context, message)
    emit_event(context, "unavailable", { name = package.name, reason = "unsupported-package" })
    return false
  end
  return install_release_package(context, package, "installed")
end

function plugin.installLocal(context, path)
  local request = read_field(context, "request") or {}
  local packages = read_field(request, "packages") or {}
  local package = normalize_requested_package(packages[1] or { name = "x10", version = read_field(request, "version") })
  local local_path = first_nonempty(path, read_field(request, "localPath"), read_field(request, "path"))
  local ok = install_local_package(context, local_path, package, "installed")
  return ok == true
end

function plugin.remove(context, packages)
  local requested = packages or read_field(read_field(context, "request"), "packages") or {}
  local package = normalize_requested_package(requested[1] or { name = "x10" })
  local installed = load_installed_metadata(context, requested)
  if installed == nil then
    tx_success(context)
    emit_event(context, "deleted", {})
    return true
  end
  if package.version ~= "" and trim(package.version) ~= trim(installed.version) then
    local message = "requested version not installed"
    tx_failed(context, message)
    return false
  end
  local ok, err = remove_path(context, installed.installPath)
  if not ok then
    tx_failed(context, err)
    return false
  end
  ok, err = clear_installed_metadata(context, requested)
  if not ok then
    tx_failed(context, err)
    return false
  end
  emit_event(context, "deleted", package_record_from_metadata(installed, nil) or installed)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  local requested = packages or read_field(read_field(context, "request"), "packages") or {}
  if #requested > 0 then
    local package = normalize_requested_package(requested[1])
    if package.version == "" then
      local release = fetch_release(context, nil, requested)
      if release ~= nil then
        package.version = release.version
      end
    end
    return install_release_package(context, package, "updated")
  end

  local installed = load_installed_metadata(context, requested)
  if installed == nil then
    tx_success(context)
    emit_event(context, "updated", {})
    return true
  end
  return install_release_package(context, {
    name = "x10",
    version = "",
  }, "updated")
end

function plugin.list(context)
  local installed = load_installed_metadata(context, nil)
  local items = {}
  if installed ~= nil then
    local release, err = fetch_release(context, nil, nil)
    if release == nil and err ~= nil then
      log_warn(context, err)
    end
    items[#items + 1] = package_record_from_metadata(installed, release)
  end
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  local installed = load_installed_metadata(context, nil)
  if installed == nil then
    emit_event(context, "outdated", {})
    return {}
  end
  local release, err = fetch_release(context, nil, nil)
  if release == nil then
    log_warn(context, err or "failed to fetch latest x10 release")
    emit_event(context, "outdated", {})
    return {}
  end
  if trim(installed.version) == trim(release.version) then
    emit_event(context, "outdated", {})
    return {}
  end
  local item = package_record_from_metadata(installed, release)
  item.status = "outdated"
  emit_event(context, "outdated", { item })
  return { item }
end

function plugin.search(context, prompt)
  local text = lower(first_nonempty(prompt, read_field(context, "prompt"), read_field(read_field(context, "request"), "prompt"), ""))
  if text ~= "" and text:find("x10", 1, true) == nil and text:find("build", 1, true) == nil and text:find("compiler", 1, true) == nil then
    emit_event(context, "searched", {})
    return {}
  end
  local release = fetch_release(context, nil, nil)
  local item = nil
  if release ~= nil then
    item = package_record_from_metadata({ name = "x10", version = release.version }, release)
  else
    item = {
      name = "x10",
      packageId = "x10",
      summary = "X10 language compiler and runtime",
      description = "Official X10 toolchain built from upstream releases or local source trees",
      homepage = HOMEPAGE_URL,
      license = "EPL-1.0",
      installed = false,
      status = "available",
      categories = { "compiler", "language", "build-tool" },
      extraFields = { repository = REPO_URL },
    }
  end
  emit_event(context, "searched", { item })
  return { item }
end

function plugin.info(context, name)
  local requested_name = first_nonempty(name, read_field(context, "prompt"), read_field(read_field(context, "request"), "prompt"), read_field(read_field(context, "request"), "packageName"), "x10")
  if not package_matches_canonical(requested_name) then
    emit_event(context, "unavailable", { name = requested_name, reason = "unsupported-package" })
    return {}
  end
  local installed = load_installed_metadata(context, nil)
  local release = fetch_release(context, nil, nil)
  local item = nil
  if installed ~= nil then
    item = package_record_from_metadata(installed, release)
  elseif release ~= nil then
    item = package_record_from_metadata({ name = "x10", version = release.version }, release)
    item.installed = false
    item.status = "available"
  end
  if item == nil then
    emit_event(context, "unavailable", { name = requested_name, reason = "not-found" })
    return {}
  end
  emit_event(context, "informed", item)
  return item
end

function plugin.resolvePackage(context, package)
  local normalized = normalize_requested_package(package or {})
  if not package_matches_canonical(normalized.name) then
    return nil
  end
  local installed = load_installed_metadata(context, { normalized })
  local release = nil
  if normalized.version ~= "" and lower(normalized.version) ~= "latest" then
    release = fetch_release(context, normalized.version, { normalized })
  else
    release = fetch_release(context, nil, { normalized })
  end
  local item = package_record_from_metadata(installed or { name = "x10", version = normalized.version ~= "" and normalized.version or (release and release.version) or nil }, release)
  if item ~= nil and normalized.version ~= "" then
    item.version = normalized.version
    item.packageId = "x10@" .. normalized.version
  end
  return item
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "exec", "network" },
    ecosystemScopes = { "x10" },
    writeScopes = {
      "user-home-subpath:.cache/reqpack/x10build",
      "user-home-subpath:.local/share/reqpack/x10build",
    },
    networkScopes = { "api.github.com", "github.com" },
    privilegeLevel = "user",
    purlType = "generic",
  }
end

function plugin.init()
  for _, binary in ipairs(REQUIRED_BINARIES) do
    if not command_exists(binary) then
      return false
    end
  end
  return true
end

function plugin.shutdown()
  return true
end

return plugin
