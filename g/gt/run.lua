plugin = {}

local PLUGIN_ID = "gt"
local PLUGIN_NAME = "GenomeTools"
local PLUGIN_VERSION = "0.1.0"
local DEFAULT_DATA_ROOT = "$HOME/.reqpack-data/gt"
local RELEASES_URL = "https://api.github.com/repos/genometools/genometools/releases?per_page=100"
local REPOSITORY_URL = "https://github.com/genometools/genometools"
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

local function split_lines(value)
  local lines = {}
  for line in tostring(value or ""):gmatch("[^\r\n]+") do
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

local function is_success(result)
  return type(result) == "table" and result.success == true
end

local function command_exists(context, binary)
  local result = exec_run(context, "command -v " .. shell_quote(binary) .. " >/dev/null 2>&1")
  return is_success(result)
end

local function collect_flags(context, pkg)
  local items = {}
  local seen = {}

  local function append_from(object)
    for _, flag in ipairs(sequence_values(read_field(object, "flags"))) do
      local cleaned = trim(flag)
      if cleaned ~= "" and not seen[cleaned] then
        seen[cleaned] = true
        items[#items + 1] = cleaned
      end
    end
  end

  append_from(context)
  append_from(read_field(context, "request"))
  append_from(pkg)
  return items
end

local function flag_value(flags, key)
  local prefix = lower(key) .. "="
  for _, flag in ipairs(flags or {}) do
    local cleaned = trim(flag)
    if lower(cleaned):sub(1, #prefix) == prefix then
      return non_empty(cleaned:sub(#prefix + 1))
    end
  end
  return nil
end

local function build_flags(flags)
  local build = {}
  local jobs = nil
  local allowed = {
    ["cairo=no"] = true,
    ["useshared=yes"] = true,
    ["assert=no"] = true,
    ["opt=no"] = true,
    ["errorcheck=no"] = true,
    ["verbose=yes"] = true,
    ["64bit=no"] = true,
    ["32bit=yes"] = true,
    ["amalgamation=yes"] = true,
  }

  for _, flag in ipairs(flags or {}) do
    local cleaned = trim(flag)
    local lowered = lower(cleaned)
    if lowered:match("^jobs=%d+$") then
      jobs = cleaned:match("=(%d+)$")
    elseif allowed[lowered] then
      build[#build + 1] = cleaned
    end
  end

  return build, jobs
end

local function join_words(parts)
  local items = {}
  for _, part in ipairs(parts or {}) do
    local cleaned = trim(part)
    if cleaned ~= "" then
      items[#items + 1] = cleaned
    end
  end
  return table.concat(items, " ")
end

local function action_name(context, pkg)
  return lower(read_field(pkg, "action") or read_field(context, "action") or read_field(read_field(context, "request"), "action") or "")
end

local function package_name(pkg)
  local name = lower(read_field(pkg, "name") or "")
  if name == "" or name == "gt" or name == "genometools" then
    return "gt"
  end
  return name
end

local function requested_version(pkg, default_latest)
  local version = non_empty(read_field(pkg, "version"))
  if version ~= nil then
    return version:gsub("^v", "")
  end
  if default_latest then
    return "latest"
  end
  return nil
end

local function request_packages(context, packages)
  local explicit = sequence_values(packages)
  if #explicit > 0 then
    return explicit
  end
  local direct = sequence_values(read_field(context, "packages"))
  if #direct > 0 then
    return direct
  end
  local request = read_field(context, "request")
  local from_request = sequence_values(read_field(request, "packages"))
  if #from_request > 0 then
    return from_request
  end
  return {}
end

local function query_prompt(context, name)
  return trim(name or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or "")
end

local function data_root(context, pkg)
  return flag_value(collect_flags(context, pkg), "data-root") or DEFAULT_DATA_ROOT
end

local function root_paths(root)
  return {
    root = root,
    downloads = root .. "/downloads",
    src = root .. "/src",
    installs = root .. "/installs",
  }
end

local function install_root(root, version)
  return root .. "/installs/" .. version
end

local function binary_path(root, version)
  return install_root(root, version) .. "/bin/gt"
end

local function tarball_path(root, version)
  return root .. "/downloads/genometools-" .. version .. ".tar.gz"
end

local function source_path(root, version)
  return root .. "/src/genometools-" .. version
end

local function ensure_directories(context, root)
  local paths = root_paths(root)
  local command = "mkdir -p " .. shell_quote(paths.root) .. " " .. shell_quote(paths.downloads) .. " " .. shell_quote(paths.src) .. " " .. shell_quote(paths.installs)
  local result = exec_run(context, command)
  if not is_success(result) then
    return nil, trim(result.stderr or result.stdout or "failed to create gt data directories")
  end
  return paths, nil
end

local function list_installed_versions(context, root)
  local command = "if [ -d " .. shell_quote(root .. "/installs") .. " ]; then ls -1 " .. shell_quote(root .. "/installs") .. "; fi"
  local result = exec_run(context, command)
  if not is_success(result) then
    return {}, trim(result.stderr or result.stdout or "failed to list installs")
  end
  local items = {}
  for _, line in ipairs(split_lines(result.stdout)) do
    local version = non_empty(line)
    if version ~= nil then
      local check = exec_run(context, "test -x " .. shell_quote(binary_path(root, version)))
      if is_success(check) then
        items[#items + 1] = version
      end
    end
  end
  table.sort(items)
  return items, nil
end

local function is_installed(context, root, version)
  local result = exec_run(context, "test -x " .. shell_quote(binary_path(root, version)))
  return is_success(result)
end

local function ensure_tools(context, require_downloader)
  if not command_exists(context, "tar") then
    return nil, "gt wrapper requires tar"
  end
  if not command_exists(context, "make") then
    return nil, "gt wrapper requires make"
  end
  if require_downloader then
    if command_exists(context, "curl") then
      return "curl", nil
    end
    if command_exists(context, "wget") then
      return "wget", nil
    end
    return nil, "gt wrapper requires curl or wget"
  end
  return true, nil
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

local function json_value(value)
  if value == JSON_NULL then
    return nil
  end
  return value
end

local function normalize_version(value)
  local cleaned = trim(value):gsub("^v", "")
  if cleaned == "" then
    return nil
  end
  return cleaned
end

local function release_from_raw(raw)
  if type(raw) ~= "table" then
    return nil
  end
  local tag_name = normalize_version(json_value(raw.tag_name))
  if tag_name == nil then
    return nil
  end
  return {
    version = tag_name,
    tag = non_empty(json_value(raw.tag_name)) or ("v" .. tag_name),
    title = non_empty(json_value(raw.name)) or ("GenomeTools " .. tag_name),
    tarballUrl = non_empty(json_value(raw.tarball_url)),
    htmlUrl = non_empty(json_value(raw.html_url)) or REPOSITORY_URL .. "/releases/tag/v" .. tag_name,
    description = non_empty(json_value(raw.body)),
  }
end

local function fetch_releases(context)
  local downloader, err = ensure_tools(context, true)
  if downloader == nil then
    return nil, err
  end
  local command
  if downloader == "curl" then
    command = "curl -fsSL " .. shell_quote(RELEASES_URL)
  else
    command = "wget -qO- " .. shell_quote(RELEASES_URL)
  end
  local result = exec_run(context, command)
  if not is_success(result) then
    return nil, trim(result.stderr or result.stdout or "failed to fetch gt releases")
  end
  local decoded, decode_err = decode_json(result.stdout)
  if decoded == nil then
    return nil, decode_err or "failed to decode gt releases"
  end
  local releases = {}
  for _, raw in ipairs(decoded or {}) do
    local item = release_from_raw(raw)
    if item ~= nil then
      releases[#releases + 1] = item
    end
  end
  return releases, nil
end

local function latest_release(context)
  local releases, err = fetch_releases(context)
  if releases == nil then
    return nil, err
  end
  return releases[1], nil
end

local function find_release_by_version(releases, version)
  local wanted = normalize_version(version)
  for _, release in ipairs(releases or {}) do
    if release.version == wanted then
      return release
    end
  end
  return nil
end

local function parse_query_version(query)
  local cleaned = trim(query)
  if cleaned == "" then
    return nil
  end
  local suffix = cleaned:match("@(.+)$")
  if suffix ~= nil then
    return normalize_version(suffix)
  end
  if lower(cleaned) == "gt" or lower(cleaned) == "genometools" then
    return nil
  end
  return normalize_version(cleaned)
end

local function build_item(version, latest_version, installed, status, root, extra)
  local install_path_value = root ~= nil and install_root(root, version) or nil
  local item = {
    name = "gt",
    packageId = PLUGIN_ID .. "/" .. version,
    packageType = "release",
    type = "package",
    version = version,
    latestVersion = latest_version or version,
    installed = installed == true,
    status = status,
    summary = "GenomeTools release " .. version,
    repository = REPOSITORY_URL,
    extraFields = {
      installPath = install_path_value,
      binaryPath = install_path_value ~= nil and (install_path_value .. "/bin/gt") or nil,
      managedRoot = root,
    },
  }
  for key, value in pairs(extra or {}) do
    item.extraFields[key] = value
  end
  if next(item.extraFields) == nil then
    item.extraFields = nil
  end
  return item
end

local function installed_item(root, version, latest_version, extra)
  local status = "installed"
  if latest_version ~= nil and latest_version ~= version then
    status = "outdated"
  end
  return build_item(version, latest_version, true, status, root, extra)
end

local function release_item(root, release, installed_versions)
  local installed = installed_versions ~= nil and installed_versions[release.version] == true or false
  local status = installed and "installed" or "available"
  return build_item(release.version, release.version, installed, status, root, {
    tarballUrl = release.tarballUrl,
    releaseUrl = release.htmlUrl,
    description = release.description,
  })
end

local function installed_versions_map(versions)
  local map = {}
  for _, version in ipairs(versions or {}) do
    map[version] = true
  end
  return map
end

local function download_release(context, downloader, release, target)
  local exists = exec_run(context, "test -f " .. shell_quote(target))
  if is_success(exists) then
    return true, nil
  end
  local command
  if downloader == "curl" then
    command = "curl -fL " .. shell_quote(release.tarballUrl) .. " -o " .. shell_quote(target)
  else
    command = "wget -O " .. shell_quote(target) .. " " .. shell_quote(release.tarballUrl)
  end
  local result = exec_run(context, command)
  if not is_success(result) then
    return false, trim(result.stderr or result.stdout or "failed to download gt tarball")
  end
  return true, nil
end

local function extract_release(context, tarball, destination)
  local command = "rm -rf " .. shell_quote(destination) .. " && mkdir -p " .. shell_quote(destination) .. " && tar -xzf " .. shell_quote(tarball) .. " -C " .. shell_quote(destination) .. " --strip-components=1"
  local result = exec_run(context, command)
  if not is_success(result) then
    return false, trim(result.stderr or result.stdout or "failed to extract gt source")
  end
  return true, nil
end

local function build_source(context, source_dir, install_dir, build_flags, jobs)
  local make_args = {}
  if jobs ~= nil then
    make_args[#make_args + 1] = "-j" .. jobs
  end
  for _, flag in ipairs(build_flags or {}) do
    make_args[#make_args + 1] = flag
  end
  local compile = "cd " .. shell_quote(source_dir) .. " && make"
  if #make_args > 0 then
    compile = compile .. " " .. join_words(make_args)
  end
  local compile_result = exec_run(context, compile)
  if not is_success(compile_result) then
    return false, trim(compile_result.stderr or compile_result.stdout or "gt make failed")
  end

  local install_args = { "prefix=" .. shell_quote(install_dir) }
  for _, flag in ipairs(build_flags or {}) do
    install_args[#install_args + 1] = flag
  end
  install_args[#install_args + 1] = "install"
  local install = "cd " .. shell_quote(source_dir) .. " && make " .. join_words(install_args)
  local install_result = exec_run(context, install)
  if not is_success(install_result) then
    return false, trim(install_result.stderr or install_result.stdout or "gt make install failed")
  end
  return true, nil
end

local function install_release_version(context, pkg, root, release)
  local downloader, err = ensure_tools(context, true)
  if downloader == nil then
    return nil, err
  end
  if release.tarballUrl == nil then
    return nil, "gt release tarball URL missing for " .. release.version
  end
  local _, dir_err = ensure_directories(context, root)
  if dir_err ~= nil then
    return nil, dir_err
  end
  if is_installed(context, root, release.version) then
    return installed_item(root, release.version, release.version, {
      tarballUrl = release.tarballUrl,
      releaseUrl = release.htmlUrl,
      sourcePath = source_path(root, release.version),
    }), nil
  end
  local flags = collect_flags(context, pkg)
  local build_flags, jobs = build_flags(flags)
  local tarball = tarball_path(root, release.version)
  local src = source_path(root, release.version)
  local install_dir = install_root(root, release.version)
  local ok, download_err = download_release(context, downloader, release, tarball)
  if not ok then
    return nil, download_err
  end
  local extracted, extract_err = extract_release(context, tarball, src)
  if not extracted then
    return nil, extract_err
  end
  local built, build_err = build_source(context, src, install_dir, build_flags, jobs)
  if not built then
    return nil, build_err
  end
  return installed_item(root, release.version, release.version, {
    tarballUrl = release.tarballUrl,
    releaseUrl = release.htmlUrl,
    sourcePath = src,
  }), nil
end

local function local_version_from_path(context, path)
  local result = exec_run(context, "if [ -f " .. shell_quote(path .. "/VERSION") .. " ]; then cat " .. shell_quote(path .. "/VERSION") .. "; fi")
  if not is_success(result) then
    return "0.0.0-local"
  end
  return normalize_version(result.stdout) or "0.0.0-local"
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
  return { "Package Manager", "GenomeTools", "Wrapper" }
end

function plugin.init(context)
  local _, err = ensure_tools(context, false)
  return err == nil
end

function plugin.getMissingPackages(packages)
  local context = {}
  local missing = {}
  for _, pkg in ipairs(packages or {}) do
    local root = data_root(context, pkg)
    local action = action_name(context, pkg)
    local version = requested_version(pkg, action == "install")
    if version == "latest" or version == nil then
      local release = latest_release(context)
      version = release and release.version or version
    end
    if version == nil then
      missing[#missing + 1] = pkg
    else
      local installed = is_installed(context, root, version)
      if action == "remove" then
        if installed then
          missing[#missing + 1] = pkg
        end
      elseif action == "update" then
        local latest = latest_release(context)
        if latest == nil or not is_installed(context, root, latest.version) then
          missing[#missing + 1] = pkg
        end
      elseif not installed then
        missing[#missing + 1] = pkg
      end
    end
  end
  return missing
end

function plugin.install(context, packages)
  packages = request_packages(context, packages)
  if #packages == 0 then
    tx_success(context)
    return true
  end
  begin_step(context, "install gt release")
  local releases, release_err = fetch_releases(context)
  if releases == nil then
    tx_failed(context, release_err)
    return false
  end
  local installed = {}
  for _, pkg in ipairs(packages) do
    if package_name(pkg) ~= "gt" then
      tx_failed(context, "gt package name must be gt or genometools")
      return false
    end
    local version = requested_version(pkg, true)
    local release = version == "latest" and releases[1] or find_release_by_version(releases, version)
    if release == nil then
      tx_failed(context, "gt release not found")
      return false
    end
    local item, err = install_release_version(context, pkg, data_root(context, pkg), release)
    if item == nil then
      tx_failed(context, err)
      return false
    end
    installed[#installed + 1] = item
  end
  emit_event(context, "installed", installed)
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  local local_path = trim(path or read_field(context, "localPath") or read_field(read_field(context, "request"), "localPath") or "")
  begin_step(context, "install local gt source")
  local _, err = ensure_tools(context, false)
  if err ~= nil then
    tx_failed(context, err)
    return false
  end
  if local_path == "" then
    tx_failed(context, "gt installLocal requires local source path")
    return false
  end
  local exists = exec_run(context, "test -d " .. shell_quote(local_path))
  if not is_success(exists) then
    tx_failed(context, "gt local source path not found")
    return false
  end
  local version = local_version_from_path(context, local_path)
  local root = data_root(context, nil)
  local _, dir_err = ensure_directories(context, root)
  if dir_err ~= nil then
    tx_failed(context, dir_err)
    return false
  end
  local flags = collect_flags(context, nil)
  local build_list, jobs = build_flags(flags)
  local install_dir = install_root(root, version)
  local ok, build_err = build_source(context, local_path, install_dir, build_list, jobs)
  if not ok then
    tx_failed(context, build_err)
    return false
  end
  local item = installed_item(root, version, version, {
    sourcePath = local_path,
    localTarget = true,
  })
  emit_event(context, "installed", item)
  tx_success(context)
  return true
end

function plugin.remove(context, packages)
  packages = request_packages(context, packages)
  if #packages == 0 then
    tx_success(context)
    return true
  end
  begin_step(context, "remove gt release")
  local removed = {}
  for _, pkg in ipairs(packages) do
    local root = data_root(context, pkg)
    local version = requested_version(pkg, false)
    if version == nil then
      local versions, err = list_installed_versions(context, root)
      if err ~= nil then
        tx_failed(context, err)
        return false
      end
      if #versions == 1 then
        version = versions[1]
      else
        tx_failed(context, "gt remove requires explicit version when multiple installs exist")
        return false
      end
    end
    if not is_installed(context, root, version) then
      tx_failed(context, "gt release not installed")
      return false
    end
    local command = "rm -rf " .. shell_quote(install_root(root, version))
    local result = exec_run(context, command)
    if not is_success(result) then
      tx_failed(context, trim(result.stderr or result.stdout or "failed to remove gt install"))
      return false
    end
    removed[#removed + 1] = build_item(version, version, false, "removed", root, {})
  end
  emit_event(context, "deleted", removed)
  tx_success(context)
  return true
end

function plugin.update(context, packages)
  packages = request_packages(context, packages)
  begin_step(context, "update gt release")
  local releases, release_err = fetch_releases(context)
  if releases == nil then
    tx_failed(context, release_err)
    return false
  end
  local release = releases[1]
  if release == nil then
    tx_failed(context, "gt latest release not found")
    return false
  end
  if #packages == 0 then
    local root = data_root(context, nil)
    local versions, err = list_installed_versions(context, root)
    if err ~= nil then
      tx_failed(context, err)
      return false
    end
    if #versions == 0 then
      tx_success(context)
      return true
    end
    if is_installed(context, root, release.version) then
      tx_success(context)
      return true
    end
    local item, install_err = install_release_version(context, {}, root, release)
    if item == nil then
      tx_failed(context, install_err)
      return false
    end
    emit_event(context, "updated", { item })
    tx_success(context)
    return true
  end
  local updated = {}
  for _, pkg in ipairs(packages) do
    local root = data_root(context, pkg)
    if not is_installed(context, root, release.version) then
      local item, install_err = install_release_version(context, pkg, root, release)
      if item == nil then
        tx_failed(context, install_err)
        return false
      end
      updated[#updated + 1] = item
    end
  end
  emit_event(context, "updated", updated)
  tx_success(context)
  return true
end

function plugin.list(context)
  local root = data_root(context, nil)
  local versions, err = list_installed_versions(context, root)
  if err ~= nil then
    tx_failed(context, err)
    return {}
  end
  local latest = nil
  local release, release_err = latest_release(context)
  if release == nil then
    log_warn(context, release_err or "gt latest release lookup failed")
  else
    latest = release.version
  end
  local items = {}
  for _, version in ipairs(versions) do
    items[#items + 1] = installed_item(root, version, latest, {})
  end
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  local root = data_root(context, nil)
  local versions, err = list_installed_versions(context, root)
  if err ~= nil then
    tx_failed(context, err)
    return {}
  end
  local release, release_err = latest_release(context)
  if release == nil then
    log_warn(context, release_err or "gt latest release lookup failed")
    emit_event(context, "outdated", {})
    return {}
  end
  local items = {}
  for _, version in ipairs(versions) do
    if version ~= release.version then
      items[#items + 1] = installed_item(root, version, release.version, {})
    end
  end
  emit_event(context, "outdated", items)
  return items
end

function plugin.search(context, prompt)
  local query = lower(trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request"), "prompt") or ""))
  local releases, err = fetch_releases(context)
  if releases == nil then
    log_warn(context, err or "gt search failed")
    emit_event(context, "searched", {})
    return {}
  end
  local root = data_root(context, nil)
  local versions = installed_versions_map(select(1, list_installed_versions(context, root)))
  local items = {}
  for _, release in ipairs(releases) do
    local haystack = lower((release.version or "") .. " " .. (release.title or ""))
    if query == "" or haystack:find(query, 1, true) ~= nil then
      items[#items + 1] = release_item(root, release, versions)
    end
  end
  emit_event(context, "searched", items)
  return items
end

function plugin.info(context, name)
  local query = query_prompt(context, name)
  local root = data_root(context, nil)
  local versions, err = list_installed_versions(context, root)
  if err ~= nil then
    tx_failed(context, err)
    return {}
  end
  local installed = installed_versions_map(versions)
  local version = parse_query_version(query)
  if version ~= nil and installed[version] then
    local item = installed_item(root, version, version, {})
    emit_event(context, "informed", item)
    return item
  end
  local releases, release_err = fetch_releases(context)
  if releases == nil then
    log_warn(context, release_err or "gt info failed")
    emit_event(context, "informed", {})
    return {}
  end
  local release = version ~= nil and find_release_by_version(releases, version) or releases[1]
  if release == nil then
    emit_event(context, "informed", {})
    return {}
  end
  local item = release_item(root, release, installed)
  emit_event(context, "informed", item)
  return item
end

function plugin.resolvePackage(context, pkg)
  local version = requested_version(pkg, true)
  if version ~= nil and version ~= "latest" then
    return build_item(version, version, false, "available", data_root(context, pkg), {})
  end
  local release = latest_release(context)
  if release ~= nil then
    return release_item(data_root(context, pkg), release, {})
  end
  return {
    name = "gt",
    packageId = "gt/latest",
    packageType = "release",
    type = "package",
    version = "latest",
    latestVersion = "latest",
  }
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "exec", "download", "build" },
    ecosystemScopes = { "genometools", "gtscript", "bioinformatics" },
    writeScopes = {
      { kind = "user-home-subpath", value = ".reqpack-data/gt" },
    },
    networkScopes = { "api.github.com", "github.com", "codeload.github.com" },
    privilegeLevel = "user",
  }
end

function plugin.shutdown()
  return true
end

return plugin
