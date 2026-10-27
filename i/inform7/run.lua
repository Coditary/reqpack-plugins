plugin = {}

local PLUGIN_ID = "inform7"
local PLUGIN_NAME = "Inform 7"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "inbuild"
local COMMAND_ENV_PREFIX = "LC_ALL=C LANG=C LANGUAGE=C"

plugin.fileExtensions = { ".i7x", ".i7xd" }

local function trim(value)
  return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
  return trim(value):lower()
end

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
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

local function ends_with(value, suffix)
  local text = tostring(value or "")
  return suffix ~= "" and text:sub(-#suffix) == suffix
end

local function is_path_like(value)
  local text = trim(value)
  return text:find("/", 1, true) ~= nil or text:find("\\", 1, true) ~= nil or text:sub(1, 1) == "."
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

local function package_error(context, message)
  tx_failed(context, message)
  return false
end

local function read_flags(value)
  local flags = {}
  for _, item in ipairs(sequence_values(read_field(value, "flags"))) do
    local cleaned = trim(item)
    if cleaned ~= "" then
      flags[#flags + 1] = cleaned
    end
  end
  return flags
end

local function pattern_escape(value)
  return (tostring(value or ""):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

local function collect_flags(context, package)
  local flags = {}

  local function collect_from(object)
    for _, flag in ipairs(read_flags(object)) do
      flags[#flags + 1] = flag
    end
  end

  collect_from(context)
  collect_from(read_field(context, "request"))
  collect_from(package)
  return flags
end

local function flag_value(flags, key)
  local prefix = lower(key) .. "="
  for _, flag in ipairs(flags or {}) do
    local cleaned = trim(flag)
    if lower(cleaned):sub(1, #prefix) == prefix then
      return trim(cleaned:sub(#prefix + 1))
    end
  end
  return ""
end

local function flag_values(flags, key)
  local prefix = lower(key) .. "="
  local values = {}
  for _, flag in ipairs(flags or {}) do
    local cleaned = trim(flag)
    if lower(cleaned):sub(1, #prefix) == prefix then
      local value = trim(cleaned:sub(#prefix + 1))
      if value ~= "" then
        values[#values + 1] = value
      end
    end
  end
  return values
end

local function default_data_root()
  if os ~= nil and type(os.getenv) == "function" then
    local home = trim(os.getenv("HOME") or "")
    if home ~= "" then
      return join_path(home, ".cache", "reqpack", PLUGIN_ID)
    end
  end
  return ".cache/reqpack/" .. PLUGIN_ID
end

local function build_paths(context, package)
  local flags = collect_flags(context, package)
  local root = flag_value(flags, "data-root")
  if root == "" then
    root = default_data_root()
  end
  local internal = flag_value(flags, "internal")
  local nests = flag_values(flags, "nest")
  return {
    root = root,
    external = join_path(root, "external"),
    externalExtensions = join_path(root, "external", "Extensions"),
    temp = join_path(root, "tmp"),
    internal = internal,
    nests = nests,
  }
end

local function normalize_path(value)
  local text = trim(value):gsub("\\", "/")
  text = text:gsub("/+", "/")
  if #text > 1 then
    text = text:gsub("/$", "")
  end
  return text
end

local function path_is_within(root, target)
  local base = normalize_path(root)
  local path = normalize_path(target)
  if base == "" or path == "" then
    return false
  end
  return path == base or path:sub(1, #base + 1) == base .. "/"
end

local function build_command(paths, arguments)
  local parts = {}
  if COMMAND_ENV_PREFIX ~= "" then
    parts[#parts + 1] = COMMAND_ENV_PREFIX
  end
  parts[#parts + 1] = shell_quote(REQUIRED_BINARY)
  if trim(paths.internal) ~= "" then
    parts[#parts + 1] = shell_quote("-internal")
    parts[#parts + 1] = shell_quote(paths.internal)
  end
  parts[#parts + 1] = shell_quote("-external")
  parts[#parts + 1] = shell_quote(paths.external)
  for _, nest in ipairs(paths.nests or {}) do
    parts[#parts + 1] = shell_quote("-nest")
    parts[#parts + 1] = shell_quote(nest)
  end
  for _, item in ipairs(arguments or {}) do
    parts[#parts + 1] = item
  end
  return table.concat(parts, " ")
end

local function inspect_target_command(paths, target)
  return build_command(paths, {
    shell_quote("-inspect"),
    shell_quote("-json"),
    shell_quote("-"),
    shell_quote(target),
  })
end

local function inspect_contents_command(paths, dir)
  return build_command(paths, {
    shell_quote("-inspect"),
    shell_quote("-recursive"),
    shell_quote("-contents-of"),
    shell_quote(dir),
    shell_quote("-json"),
    shell_quote("-"),
  })
end

local function sync_to_command(paths, target)
  return build_command(paths, {
    shell_quote("-sync-to"),
    shell_quote(paths.external),
    shell_quote(target),
  })
end

local function command_exists_command()
  return "command -v " .. shell_quote(REQUIRED_BINARY) .. " >/dev/null 2>&1"
end

local function ensure_runtime_dirs_command(paths)
  return "mkdir -p " .. table.concat({
    shell_quote(paths.root),
    shell_quote(paths.external),
    shell_quote(paths.externalExtensions),
    shell_quote(paths.temp),
  }, " ")
end

local function file_exists_command(path)
  return "test -e " .. shell_quote(path)
end

local function dir_exists_command(path)
  return "test -d " .. shell_quote(path)
end

local function remove_path_command(path, is_directory)
  if is_directory then
    return "rm -rf " .. shell_quote(path)
  end
  return "rm -f " .. shell_quote(path)
end

local function ensure_binary(context)
  local result = exec_run(context, command_exists_command())
  if is_command_success(result) then
    return true
  end
  return false, "inform7 requires 'inbuild' on PATH"
end

local function ensure_runtime_dirs(context, paths)
  local result = exec_run(context, ensure_runtime_dirs_command(paths))
  return is_command_success(result)
end

local function path_exists(context, path)
  return is_command_success(exec_run(context, file_exists_command(path)))
end

local function dir_exists(context, path)
  return is_command_success(exec_run(context, dir_exists_command(path)))
end

local function request_packages(context, packages)
  if type(packages) == "table" or type(packages) == "userdata" then
    local direct_values = sequence_values(packages)
    if #direct_values > 0 then
      return direct_values
    end
  end
  local direct_packages = read_field(context, "packages")
  if type(direct_packages) == "table" or type(direct_packages) == "userdata" then
    local values = sequence_values(direct_packages)
    if #values > 0 then
      return values
    end
  end
  local request = read_field(context, "request")
  local nested = sequence_values(read_field(request, "packages"))
  if #nested > 0 then
    return nested
  end

  local direct_path = trim(read_field(context, "path") or read_field(request, "path") or "")
  if direct_path ~= "" then
    return {
      {
        name = direct_path,
        path = direct_path,
      }
    }
  end

  return {}
end

local function request_prompt(context, prompt)
  local text = trim(prompt)
  if text ~= "" then
    return text
  end
  local request = read_field(context, "request")
  return trim(read_field(context, "prompt") or read_field(request, "prompt") or "")
end

local function request_path(context, path)
  local text = trim(path)
  if text ~= "" then
    return text
  end
  local request = read_field(context, "request")
  return trim(read_field(context, "localPath") or read_field(context, "path") or read_field(request, "localPath") or read_field(request, "path") or "")
end

local function split_title_author(name, author)
  local explicit_author = trim(author)
  local title = trim(name)
  if explicit_author ~= "" then
    return title, explicit_author
  end
  local inferred_title, inferred_author = title:match("^(.-)%s+[Bb][Yy]%s+(.+)$")
  if inferred_title ~= nil and trim(inferred_title) ~= "" and trim(inferred_author) ~= "" then
    return trim(inferred_title), trim(inferred_author)
  end
  return title, ""
end

local function package_title(package)
  local name = trim(read_field(package, "name") or "")
  local author = trim(read_field(package, "author") or "")
  local title = split_title_author(name, author)
  return trim(title)
end

local function package_author(package)
  local name = trim(read_field(package, "name") or "")
  local author = trim(read_field(package, "author") or "")
  local _, resolved_author = split_title_author(name, author)
  return trim(resolved_author)
end

local function package_version(package)
  return trim(read_field(package, "version") or "")
end

local function local_target_path(package)
  local direct = trim(read_field(package, "path") or "")
  if direct ~= "" then
    return direct
  end
  local name = trim(read_field(package, "name") or "")
  if is_path_like(name) then
    return name
  end
  return ""
end

local function is_supported_local_target(path)
  local lowered = lower(path)
  return ends_with(lowered, ".i7x") or ends_with(lowered, ".i7xd")
end

local function json_unescape(value)
  local text = tostring(value or "")
  text = text:gsub('\\"', '"')
  text = text:gsub("\\/", "/")
  text = text:gsub("\\n", "\n")
  text = text:gsub("\\r", "\r")
  text = text:gsub("\\t", "\t")
  text = text:gsub("\\\\", "\\")
  return text
end

local function find_json_array(text, key)
  local start_at = text:find('"' .. pattern_escape(key) .. '"%s*:%s*%[', 1)
  if start_at == nil then
    return nil
  end
  local open_at = text:find("[", start_at, true)
  if open_at == nil then
    return nil
  end
  local depth = 0
  local in_string = false
  local escaped = false
  for index = open_at, #text do
    local ch = text:sub(index, index)
    if in_string then
      if escaped then
        escaped = false
      elseif ch == "\\" then
        escaped = true
      elseif ch == '"' then
        in_string = false
      end
    else
      if ch == '"' then
        in_string = true
      elseif ch == "[" then
        depth = depth + 1
      elseif ch == "]" then
        depth = depth - 1
        if depth == 0 then
          return text:sub(open_at, index)
        end
      end
    end
  end
  return nil
end

local function find_json_object(text, key)
  local start_at = text:find('"' .. pattern_escape(key) .. '"%s*:%s*%{', 1)
  if start_at == nil then
    return nil
  end
  local open_at = text:find("{", start_at, true)
  if open_at == nil then
    return nil
  end
  local depth = 0
  local in_string = false
  local escaped = false
  for index = open_at, #text do
    local ch = text:sub(index, index)
    if in_string then
      if escaped then
        escaped = false
      elseif ch == "\\" then
        escaped = true
      elseif ch == '"' then
        in_string = false
      end
    else
      if ch == '"' then
        in_string = true
      elseif ch == "{" then
        depth = depth + 1
      elseif ch == "}" then
        depth = depth - 1
        if depth == 0 then
          return text:sub(open_at, index)
        end
      end
    end
  end
  return nil
end

local function split_top_level_objects(array_text)
  local objects = {}
  if trim(array_text) == "" then
    return objects
  end
  local depth = 0
  local start_at = nil
  local in_string = false
  local escaped = false
  for index = 1, #array_text do
    local ch = array_text:sub(index, index)
    if in_string then
      if escaped then
        escaped = false
      elseif ch == "\\" then
        escaped = true
      elseif ch == '"' then
        in_string = false
      end
    else
      if ch == '"' then
        in_string = true
      elseif ch == "{" then
        if depth == 0 then
          start_at = index
        end
        depth = depth + 1
      elseif ch == "}" then
        depth = depth - 1
        if depth == 0 and start_at ~= nil then
          objects[#objects + 1] = array_text:sub(start_at, index)
          start_at = nil
        end
      end
    end
  end
  return objects
end

local function json_string_field(text, key)
  local value = text:match('"' .. pattern_escape(key) .. '"%s*:%s*"(.-)"')
  if value == nil then
    return ""
  end
  return json_unescape(value)
end

local function parse_inspection_json(text)
  local inspection_array = find_json_array(tostring(text or ""), "inspection")
  local items = {}
  if inspection_array == nil then
    return items
  end
  for _, object_text in ipairs(split_top_level_objects(inspection_array)) do
    local resource_text = find_json_object(object_text, "resource")
    if resource_text ~= nil then
      local item = {
        type = json_string_field(resource_text, "type"),
        title = json_string_field(resource_text, "title"),
        author = json_string_field(resource_text, "author"),
        version = json_string_field(resource_text, "version"),
        locationFile = json_string_field(object_text, "location-file"),
        locationDirectory = json_string_field(object_text, "location-directory"),
      }
      if trim(item.title) ~= "" then
        items[#items + 1] = item
      end
    end
  end
  return items
end

local function package_id_from_item(item)
  local author = trim(item.author)
  if author ~= "" then
    return trim(item.title) .. " by " .. author
  end
  return trim(item.title)
end

local function package_info_from_item(paths, item)
  local source = trim(item.locationFile)
  if source == "" then
    source = trim(item.locationDirectory)
  end
  local installed = source ~= "" and path_is_within(paths.external, source)
  local package_id = package_id_from_item(item)
  local author = trim(item.author)
  local version = trim(item.version)
  local summary = author ~= "" and ("Inform extension by " .. author) or "Inform extension"
  return {
    name = trim(item.title),
    packageId = package_id,
    version = version ~= "" and version or nil,
    author = author ~= "" and author or nil,
    installed = installed,
    status = installed and "installed" or "available",
    packageType = "extension",
    type = "extension",
    summary = summary,
    description = summary,
    source = source ~= "" and source or nil,
    extraFields = {
      genre = trim(item.type),
      locationFile = trim(item.locationFile),
      locationDirectory = trim(item.locationDirectory),
    },
  }
end

local function version_tokens(value)
  local tokens = {}
  for token in tostring(value or ""):gmatch("[^%._%-]+") do
    tokens[#tokens + 1] = token
  end
  return tokens
end

local function compare_versions(left, right)
  local a = version_tokens(left)
  local b = version_tokens(right)
  local limit = #a
  if #b > limit then
    limit = #b
  end
  for index = 1, limit do
    local av = a[index]
    local bv = b[index]
    if av == nil and bv ~= nil then
      return -1
    elseif av ~= nil and bv == nil then
      return 1
    elseif av ~= nil and bv ~= nil and av ~= bv then
      local an = tonumber(av)
      local bn = tonumber(bv)
      if an ~= nil and bn ~= nil then
        if an < bn then
          return -1
        end
        if an > bn then
          return 1
        end
      else
        if av < bv then
          return -1
        end
        if av > bv then
          return 1
        end
      end
    end
  end
  return 0
end

local function sort_package_infos(items)
  table.sort(items, function(left, right)
    local left_name = lower(left.name)
    local right_name = lower(right.name)
    if left_name ~= right_name then
      return left_name < right_name
    end
    local left_author = lower(left.author or "")
    local right_author = lower(right.author or "")
    if left_author ~= right_author then
      return left_author < right_author
    end
    return compare_versions(left.version or "", right.version or "") > 0
  end)
end

local function inspect_target(context, paths, target)
  local result = exec_run(context, inspect_target_command(paths, target))
  if not is_command_success(result) then
    return nil, first_nonempty(result.stderr, result.stdout, "inbuild inspect failed")
  end
  local items = parse_inspection_json(result.stdout)
  for _, item in ipairs(items) do
    if lower(item.type) == "extension" then
      return item
    end
  end
  return nil, "target is not an Inform extension"
end

local function inspect_extensions_dir(context, paths, dir)
  if not dir_exists(context, dir) then
    return {}
  end
  local result = exec_run(context, inspect_contents_command(paths, dir))
  if not is_command_success(result) then
    log_warn(context, first_nonempty(result.stderr, result.stdout, "inbuild inspect failed") or "inbuild inspect failed")
    return {}
  end
  local items = {}
  for _, item in ipairs(parse_inspection_json(result.stdout)) do
    if lower(item.type) == "extension" then
      items[#items + 1] = item
    end
  end
  return items
end

local function collect_visible_extensions(context, paths)
  local dirs = { paths.externalExtensions }
  for _, nest in ipairs(paths.nests or {}) do
    dirs[#dirs + 1] = join_path(nest, "Extensions")
  end
  if trim(paths.internal) ~= "" then
    dirs[#dirs + 1] = join_path(paths.internal, "Extensions")
  end

  local seen = {}
  local items = {}
  for _, dir in ipairs(dirs) do
    for _, item in ipairs(inspect_extensions_dir(context, paths, dir)) do
      local key = lower(package_id_from_item(item)) .. "@" .. lower(item.version)
      if not seen[key] then
        seen[key] = true
        items[#items + 1] = package_info_from_item(paths, item)
      end
    end
  end
  sort_package_infos(items)
  return items
end

local function match_package(item, title, author, version)
  local item_title = lower(item.name)
  local item_author = lower(item.author or "")
  local wanted_title = lower(title)
  local wanted_author = lower(author)
  local wanted_version = trim(version)

  if wanted_title ~= "" and item_title ~= wanted_title and lower(item.packageId) ~= wanted_title then
    return false
  end
  if wanted_author ~= "" and item_author ~= wanted_author then
    return false
  end
  if wanted_version ~= "" and trim(item.version or "") ~= wanted_version then
    return false
  end
  return true
end

local function resolve_one_extension(context, paths, title, author, version)
  local visible = collect_visible_extensions(context, paths)
  for _, item in ipairs(visible) do
    if item.installed and match_package(item, title, author, version) then
      return item
    end
  end
  for _, item in ipairs(visible) do
    if match_package(item, title, author, version) then
      return item
    end
  end
  return nil
end

local function filter_search_results(items, prompt)
  local query = lower(prompt)
  if query == "" then
    return items
  end
  local filtered = {}
  for _, item in ipairs(items) do
    local haystacks = {
      lower(item.name),
      lower(item.packageId),
      lower(item.author or ""),
    }
    for _, haystack in ipairs(haystacks) do
      if haystack:find(query, 1, true) ~= nil then
        filtered[#filtered + 1] = item
        break
      end
    end
  end
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
  return { "package-manager", "inform", "inform7", "inbuild" }
end

function plugin.getMissingPackages()
  local available = ensure_binary(nil)
  if available then
    return {}
  end
  return { REQUIRED_BINARY }
end

function plugin.install(context, packages)
  local local_path = request_path(context, nil)
  if local_path ~= "" then
    return plugin.installLocal(context, local_path)
  end

  local requested = request_packages(context, packages)
  if #requested == 0 then
    tx_success(context)
    return true
  end

  local available, message = ensure_binary(context)
  if not available then
    return package_error(context, message)
  end

  local paths = build_paths(context, nil)
  if not ensure_runtime_dirs(context, paths) then
    return package_error(context, "inform7 failed to create runtime directories")
  end

  begin_step(context, "install Inform 7 extensions")
  local installed = {}
  for _, package in ipairs(requested) do
    local target = local_target_path(package)
    if target == "" or not is_supported_local_target(target) then
      return package_error(context, "inform7 install requires local .i7x or .i7xd path")
    end
    if not path_exists(context, target) then
      return package_error(context, "inform7 install path not found")
    end

    local inspected, inspect_err = inspect_target(context, paths, target)
    if inspected == nil then
      return package_error(context, "inform7 install validation failed: " .. tostring(inspect_err))
    end

    local sync_result = exec_run(context, sync_to_command(paths, target))
    if not is_command_success(sync_result) then
      return package_error(context, first_nonempty(sync_result.stderr, sync_result.stdout, "inbuild sync failed") or "inbuild sync failed")
    end

    local resolved = resolve_one_extension(context, paths, inspected.title, inspected.author, inspected.version)
    if resolved == nil then
      resolved = package_info_from_item(paths, {
        type = "extension",
        title = inspected.title,
        author = inspected.author,
        version = inspected.version,
      })
      resolved.installed = true
      resolved.status = "installed"
    end
    installed[#installed + 1] = resolved
  end

  emit_event(context, "installed", installed)
  tx_success(context)
  emit_event(context, "success", "ok")
  return true
end

function plugin.installLocal(context, path)
  local target = request_path(context, path)
  if target == "" or not is_supported_local_target(target) then
    return package_error(context, "inform7 installLocal requires local .i7x or .i7xd path")
  end
  return plugin.install(context, {
    {
      name = target,
      path = target,
    }
  })
end

function plugin.remove(context, packages)
  local requested = request_packages(context, packages)
  if #requested == 0 then
    tx_success(context)
    emit_event(context, "success", "ok")
    return true
  end

  local available, message = ensure_binary(context)
  if not available then
    return package_error(context, message)
  end

  local paths = build_paths(context, nil)
  begin_step(context, "remove Inform 7 extensions")
  local visible = collect_visible_extensions(context, paths)
  local removed = {}
  for _, package in ipairs(requested) do
    local title, author = split_title_author(read_field(package, "name") or "", read_field(package, "author") or "")
    local version = package_version(package)
    local item = resolve_one_extension(context, paths, title, author, version)
    if item == nil then
      local wanted_name = lower(trim(read_field(package, "name") or ""))
      for _, candidate in ipairs(visible) do
        if candidate.installed == true and (
          lower(candidate.name) == wanted_name or
          lower(candidate.packageId) == wanted_name
        ) then
          item = candidate
          break
        end
      end
    end
    if item == nil or item.installed ~= true then
      return package_error(context, "inform7 remove failed: extension not installed in ReqPack external nest")
    end
    local target = trim(item.source or "")
    if target == "" or not path_is_within(paths.external, target) then
      return package_error(context, "inform7 remove refused to delete outside ReqPack external nest")
    end
    local remove_result = exec_run(context, remove_path_command(target, ends_with(lower(target), ".i7xd")))
    if not is_command_success(remove_result) then
      return package_error(context, first_nonempty(remove_result.stderr, remove_result.stdout, "remove failed") or "remove failed")
    end
    removed[#removed + 1] = item
  end

  emit_event(context, "deleted", removed)
  tx_success(context)
  emit_event(context, "success", "ok")
  return true
end

function plugin.update(context, packages)
  local requested = request_packages(context, packages)
  emit_event(context, "updated", requested)
  tx_success(context)
  emit_event(context, "success", "ok")
  return true
end

function plugin.list(context)
  local available, message = ensure_binary(context)
  if not available then
    log_warn(context, message)
    local empty = {}
    emit_event(context, "listed", empty)
    return empty
  end

  local paths = build_paths(context, nil)
  local items = {}
  for _, item in ipairs(inspect_extensions_dir(context, paths, paths.externalExtensions)) do
    items[#items + 1] = package_info_from_item(paths, item)
  end
  sort_package_infos(items)
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  local empty = {}
  emit_event(context, "outdated", empty)
  return empty
end

function plugin.search(context, prompt)
  local query = request_prompt(context, prompt)
  if query == "" then
    local empty = {}
    emit_event(context, "searched", empty)
    return empty
  end

  local available, message = ensure_binary(context)
  if not available then
    log_warn(context, message)
    local empty = {}
    emit_event(context, "searched", empty)
    return empty
  end

  local paths = build_paths(context, nil)
  local items = filter_search_results(collect_visible_extensions(context, paths), query)
  emit_event(context, "searched", items)
  return items
end

function plugin.info(context, name)
  local prompt = request_prompt(context, name)
  if prompt == "" then
    local empty = {}
    emit_event(context, "informed", empty)
    return empty
  end

  local available, message = ensure_binary(context)
  if not available then
    log_warn(context, message)
    local empty = {}
    emit_event(context, "informed", empty)
    return empty
  end

  local title, author = split_title_author(prompt, "")
  local paths = build_paths(context, nil)
  local item = resolve_one_extension(context, paths, title, author, "")
  if item == nil then
    local empty = {}
    emit_event(context, "informed", empty)
    return empty
  end
  emit_event(context, "informed", item)
  return item
end

function plugin.resolvePackage(context, package)
  local title = package_title(package)
  if title == "" then
    return package
  end
  local author = package_author(package)
  local version = package_version(package)
  local paths = build_paths(context, package)
  local item = resolve_one_extension(context, paths, title, author, version)
  if item == nil then
    local resolved = shallow_copy(type(package) == "table" and package or {})
    resolved.name = title
    if author ~= "" then
      resolved.author = author
      resolved.packageId = title .. " by " .. author
    else
      resolved.packageId = title
    end
    if version ~= "" then
      resolved.version = version
    end
    resolved.packageType = "extension"
    return resolved
  end
  local resolved = shallow_copy(type(package) == "table" and package or {})
  for key, value in pairs(item) do
    resolved[key] = value
  end
  return resolved
end

function plugin.getSecurityMetadata()
  return {
    role = "package-manager",
    capabilities = { "exec" },
    ecosystemScopes = { "inform", "inform7" },
    writeScopes = {
      { kind = "user-home-subpath", value = ".cache/reqpack/inform7" },
    },
    networkScopes = {},
    privilegeLevel = "none",
    purlType = "generic",
  }
end

function plugin.init()
  return ensure_binary(nil)
end

function plugin.shutdown()
  return true
end

return plugin
