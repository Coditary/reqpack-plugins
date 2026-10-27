plugin = {}

local PLUGIN_NAME = "Nix Package Manager"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "nix"
local NIXPKGS_REF = "nixpkgs"
local NIX_INSTALLER_URL = "https://nixos.org/nix/install"
local NIX_EXPERIMENTAL_FEATURES = "nix-command flakes"
local active_nix_binary = nil

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function first_non_empty(...)
    for index = 1, select("#", ...) do
        local value = trim(select(index, ...))
        if value ~= "" then
            return value
        end
    end
    return nil
end

local function basename(path)
    local value = trim(path)
    if value == "" then
        return ""
    end
    return value:match("([^/]+)$") or value
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
                json_error("invalid number fraction", index)
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
                json_error("invalid number exponent", index)
            end
            repeat
                advance(1)
                char = peek()
            until not char:match("%d")
        end

        return tonumber(source:sub(start, index - 1))
    end

    local function parse_array()
        if peek() ~= "[" then
            json_error("expected array", index)
        end

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
        if peek() ~= "{" then
            json_error("expected object", index)
        end

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

    local decoded = parse_value()
    skip_whitespace()
    if index <= #source then
        json_error("trailing characters", index)
    end
    return decoded
end

local function try_json_decode(input)
    return pcall(json_decode, input)
end

local function copy_string_map(values)
    local result = {}
    for key, value in pairs(values or {}) do
        if value ~= nil and type(value) ~= "table" then
            result[key] = tostring(value)
        end
    end
    return result
end

local function is_array(value)
    if type(value) ~= "table" then
        return false
    end

    local max_index = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or math.floor(key) ~= key then
            return false
        end
        if key > max_index then
            max_index = key
        end
    end

    for index = 1, max_index do
        if value[index] == nil then
            return false
        end
    end

    return true
end

local function append_unique(parts, value)
    local normalized = trim(value)
    if normalized == "" then
        return
    end

    for _, existing in ipairs(parts) do
        if existing == normalized then
            return
        end
    end

    parts[#parts + 1] = normalized
end

local function flatten_metadata_values(value, parts)
    local kind = type(value)
    if value == nil then
        return parts
    end

    if kind == "string" or kind == "number" or kind == "boolean" then
        append_unique(parts, tostring(value))
        return parts
    end

    if kind ~= "table" then
        return parts
    end

    if is_array(value) then
        for _, item in ipairs(value) do
            flatten_metadata_values(item, parts)
        end
        return parts
    end

    local preferred = first_non_empty(value.shortName, value.spdxId, value.fullName, value.longName)
    if preferred == nil then
        local name = trim(value.name)
        local email = trim(value.email)
        if name ~= "" and email ~= "" then
            preferred = name .. " <" .. email .. ">"
        else
            preferred = first_non_empty(value.name, value.email, value.github, value.url, value.description, value.position)
        end
    end

    if preferred ~= nil then
        append_unique(parts, preferred)
    end

    return parts
end

local function collapse_metadata_values(value, separator)
    local parts = flatten_metadata_values(value, {})
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, separator or ", ")
end

local function merge_string_maps(...)
    local result = {}
    for index = 1, select("#", ...) do
        local values = select(index, ...)
        for key, value in pairs(values or {}) do
            if value ~= nil then
                result[key] = tostring(value)
            end
        end
    end

    if next(result) == nil then
        return nil
    end

    return result
end

local function sorted_keys(object)
    local keys = {}
    for key in pairs(object or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
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

local function executable_exists(context, path)
    local value = trim(path)
    local quoted = shell_quote(value)
    if value:find("$", 1, true) ~= nil then
        quoted = '"' .. value:gsub('"', '\\"') .. '"'
    end
    local result = exec_run(context, "test -x " .. quoted)
    return result ~= nil and result.success == true
end

local function find_existing_nix_binary(context)
    if active_nix_binary ~= nil and active_nix_binary ~= "$HOME/.nix-profile/bin/nix" then
        return active_nix_binary
    end

    if command_exists(context, REQUIRED_BINARY) then
        active_nix_binary = REQUIRED_BINARY
        return active_nix_binary
    end

    local candidates = {
        "$HOME/.nix-profile/bin/nix",
        "/nix/var/nix/profiles/default/bin/nix",
        "/run/current-system/sw/bin/nix",
    }

    for _, candidate in ipairs(candidates) do
        if executable_exists(context, candidate) then
            active_nix_binary = candidate
            return active_nix_binary
        end
    end

    return nil
end

local function quote_command_path(path)
    local value = trim(path)
    if value == REQUIRED_BINARY then
        return REQUIRED_BINARY
    end
    if value:find("$", 1, true) ~= nil then
        return '"' .. value:gsub('"', '\\"') .. '"'
    end
    return shell_quote(value)
end

local function nix_invocation(binary)
    return quote_command_path(binary or REQUIRED_BINARY)
        .. " --extra-experimental-features "
        .. shell_quote(NIX_EXPERIMENTAL_FEATURES)
end

local function bootstrap_nix(context)
    if not command_exists(context, "curl") then
        return nil, "nix bootstrap requires curl"
    end

    begin_step(context, "bootstrap nix")
    local command = "curl -L " .. shell_quote(NIX_INSTALLER_URL) .. " | sh -s -- --no-daemon --yes"
    local result = exec_run(context, command)
    if result == nil or result.success ~= true then
        return nil, "nix bootstrap failed"
    end

    active_nix_binary = "$HOME/.nix-profile/bin/nix"
    return active_nix_binary, nil
end

local function ensure_nix(context)
    local existing = find_existing_nix_binary(context)
    if existing ~= nil then
        return existing, nil
    end

    return bootstrap_nix(context)
end

local function reset_nix_cache()
    active_nix_binary = nil
end

local function nix_command(context)
    local binary, error_message = ensure_nix(context)
    if binary == nil then
        return nil, error_message
    end
    return nix_invocation(binary), nil
end

local function join_shell_quoted(values)
    local parts = {}
    for _, value in ipairs(values or {}) do
        parts[#parts + 1] = shell_quote(value)
    end
    return table.concat(parts, " ")
end

local function strip_flake_prefix(value)
    return trim(value):gsub("^flake:", "")
end

local function is_nixpkgs_ref(value)
    return strip_flake_prefix(value) == NIXPKGS_REF
end

local function parse_store_basename(store_path)
    local name = basename(store_path)
    return name:gsub("^[a-z0-9]+%-", "")
end

local function strip_known_attr_prefix(attr_path)
    local value = trim(attr_path)
    if value == "" then
        return ""
    end

    value = value:gsub("^legacyPackages%.[^.]+%.", "")
    value = value:gsub("^packages%.[^.]+%.", "")
    return value
end

local function last_attr_segment(attr_path)
    local value = strip_known_attr_prefix(attr_path)
    return value:match("([^%.]+)$") or value
end

local function extract_ref_fragment(value)
    local ref = trim(value)
    if ref == "" then
        return ""
    end
    return trim(ref:match("#(.+)$") or "")
end

local function derive_name_from_ref(value)
    local ref = strip_flake_prefix(value)
    if ref == "" then
        return ""
    end

    local fragment = extract_ref_fragment(ref)
    if fragment ~= "" and fragment ~= "default" then
        return fragment:match("([^%.]+)$") or fragment
    end

    local path_part = ref:gsub("#.*$", "")
    path_part = path_part:gsub("^path:", "")
    path_part = path_part:gsub("^file://", "")
    path_part = path_part:gsub("^git%+file://", "")
    path_part = path_part:gsub("%?.*$", "")

    if path_part:match("^github:") then
        return trim(path_part:match("^github:[^/]+/([^/?#]+)"))
    end

    return basename(path_part)
end

local function derive_name_from_store_path(store_path)
    local value = parse_store_basename(store_path)
    local name = value:match("^(.-)%-%d[%w%.+%-]*$")
    return trim(name or value)
end

local function derive_version_from_store_path(store_path, package_name)
    local value = parse_store_basename(store_path)
    local name = trim(package_name)
    if name ~= "" and value:sub(1, #name + 1) == name .. "-" then
        return trim(value:sub(#name + 2))
    end

    return trim(value:match("^.-%-(%d[%w%.+%-]*)$") or "")
end

local function derive_entry_name(entry_name, element)
    local explicit_name = trim(entry_name)
    if explicit_name ~= "" then
        return explicit_name
    end

    local attr_name = last_attr_segment(element.attrPath)
    if attr_name ~= "" and attr_name ~= "default" then
        return attr_name
    end

    local ref_name = derive_name_from_ref(element.originalUrl or element.url or element.uri)
    if ref_name ~= "" then
        return ref_name
    end

    local store_paths = element.storePaths or {}
    if type(store_paths) == "table" and store_paths[1] ~= nil then
        return derive_name_from_store_path(store_paths[1])
    end

    return ""
end

local function build_installable(original_url, attr_path)
    local ref = strip_flake_prefix(original_url)
    local relative_attr = strip_known_attr_prefix(attr_path)

    if relative_attr ~= "" then
        if ref == "" or ref == NIXPKGS_REF then
            return NIXPKGS_REF .. "#" .. relative_attr
        end
        return ref .. "#" .. relative_attr
    end

    return ref
end

local function normalize_installable(name)
    local value = trim(name)
    if value == "" then
        return ""
    end

    if value:find("#", 1, true) ~= nil then
        return strip_flake_prefix(value)
    end

    if value:match("^[%./~]") or value:match("^%a+:") then
        return value
    end

    return NIXPKGS_REF .. "#" .. value
end

local function request_identifiers(package)
    local identifiers = {}
    local function add(value)
        local normalized = trim(value)
        if normalized ~= "" then
            identifiers[normalized] = true
        end
    end

    local raw_name = trim(package.name)
    local installable = normalize_installable(raw_name)
    local fragment = extract_ref_fragment(installable)

    add(raw_name)
    add(installable)
    add(fragment)
    add(fragment:match("([^%.]+)$") or fragment)
    add(strip_known_attr_prefix(fragment))

    return identifiers
end

local function entry_identifiers(entry)
    local identifiers = {}
    local function add(value)
        local normalized = trim(value)
        if normalized ~= "" then
            identifiers[normalized] = true
        end
    end

    add(entry.entryName)
    add(entry.name)
    add(entry.packageId)
    add(entry.attrPath)
    add(strip_known_attr_prefix(entry.attrPath))
    add(last_attr_segment(entry.attrPath))
    add(entry.originalUrl)
    add(entry.lockedUrl)
    add(derive_name_from_ref(entry.originalUrl))
    add(derive_name_from_ref(entry.lockedUrl))

    for _, store_path in ipairs(entry.storePaths or {}) do
        add(store_path)
        add(derive_name_from_store_path(store_path))
    end

    return identifiers
end

local function make_package_info(entry)
    local name = trim(entry.entryName or entry.name)
    if name == "" then
        name = trim(last_attr_segment(entry.attrPath))
    end
    if name == "" and entry.storePaths ~= nil and entry.storePaths[1] ~= nil then
        name = derive_name_from_store_path(entry.storePaths[1])
    end

    local installable = build_installable(entry.originalUrl, entry.attrPath)
    local version = ""
    if entry.storePaths ~= nil and entry.storePaths[1] ~= nil then
        version = derive_version_from_store_path(entry.storePaths[1], name)
    end

    local info = {
        name = name ~= "" and name or installable,
        packageId = installable ~= "" and installable or nil,
        version = version ~= "" and version or nil,
        installed = true,
        status = "installed",
        packageType = "flake",
        repository = first_non_empty(strip_flake_prefix(entry.originalUrl), strip_flake_prefix(entry.lockedUrl)),
        extraFields = copy_string_map({
            attrPath = entry.attrPath,
            originalUrl = strip_flake_prefix(entry.originalUrl),
            lockedUrl = strip_flake_prefix(entry.lockedUrl),
            storePath = entry.storePaths and entry.storePaths[1] or nil,
        }),
        storePaths = entry.storePaths,
        entryName = entry.entryName,
        attrPath = entry.attrPath,
        originalUrl = strip_flake_prefix(entry.originalUrl),
        lockedUrl = strip_flake_prefix(entry.lockedUrl),
    }

    if next(info.extraFields) == nil then
        info.extraFields = nil
    end

    return info
end

local function sort_package_infos(items)
    table.sort(items, function(left, right)
        local left_key = first_non_empty(left.packageId, left.name, left.version) or ""
        local right_key = first_non_empty(right.packageId, right.name, right.version) or ""
        return left_key < right_key
    end)
    return items
end

local function parse_profile_elements(stdout)
    local ok, decoded = try_json_decode(stdout)
    if not ok or type(decoded) ~= "table" then
        return nil, "failed to parse nix profile list output"
    end

    local elements = decoded.elements
    if type(elements) ~= "table" then
        return {}, nil
    end

    local result = {}
    if elements[1] ~= nil then
        for _, element in ipairs(elements) do
            if type(element) == "table" and element.active ~= false then
                result[#result + 1] = {
                    entryName = derive_entry_name(nil, element),
                    attrPath = trim(element.attrPath),
                    originalUrl = trim(element.originalUrl),
                    lockedUrl = trim(element.url or element.uri),
                    storePaths = element.storePaths or {},
                }
            end
        end
    else
        for _, key in ipairs(sorted_keys(elements)) do
            local element = elements[key]
            if type(element) == "table" and element.active ~= false then
                result[#result + 1] = {
                    entryName = derive_entry_name(key, element),
                    attrPath = trim(element.attrPath),
                    originalUrl = trim(element.originalUrl),
                    lockedUrl = trim(element.url or element.uri),
                    storePaths = element.storePaths or {},
                }
            end
        end
    end

    return result, nil
end

local function get_profile_entries(context)
    local nix, command_error = nix_command(context)
    if nix == nil then
        return nil, command_error
    end

    local result = exec_run(context, nix .. " profile list --json")
    if not result.success then
        return nil, "nix profile list failed"
    end

    return parse_profile_elements(result.stdout)
end

local function find_matching_entry(entries, package)
    local wanted = request_identifiers(package)

    for _, entry in ipairs(entries or {}) do
        local known = entry_identifiers(entry)
        for identifier in pairs(wanted) do
            if known[identifier] then
                return entry
            end
        end
    end

    return nil
end

local function parse_search_results(stdout)
    local ok, decoded = try_json_decode(stdout)
    if not ok or type(decoded) ~= "table" then
        return nil, "failed to parse nix search output"
    end

    local results = {}
    for _, attr_path in ipairs(sorted_keys(decoded)) do
        local value = decoded[attr_path]
        if type(value) == "table" then
            local relative_attr = strip_known_attr_prefix(attr_path)
            local meta = type(value.meta) == "table" and value.meta or {}
            local name = first_non_empty(value.pname, value.name, last_attr_segment(attr_path)) or attr_path
            local version = first_non_empty(value.version)
            local summary = first_non_empty(collapse_metadata_values(value.description), collapse_metadata_values(meta.description))
            local description = first_non_empty(collapse_metadata_values(value.longDescription), collapse_metadata_values(meta.longDescription), summary)
            local homepage = first_non_empty(collapse_metadata_values(value.homepage), collapse_metadata_values(meta.homepage))
            local documentation = first_non_empty(collapse_metadata_values(value.documentation), collapse_metadata_values(meta.documentation))
            local source_url = first_non_empty(collapse_metadata_values(value.sourceUrl), collapse_metadata_values(meta.sourceUrl))
            local license = first_non_empty(collapse_metadata_values(value.license), collapse_metadata_values(meta.license))
            local maintainers = first_non_empty(collapse_metadata_values(value.maintainers), collapse_metadata_values(meta.maintainers))
            local platforms = first_non_empty(collapse_metadata_values(value.platforms), collapse_metadata_values(meta.platforms))
            local position = first_non_empty(collapse_metadata_values(value.position), collapse_metadata_values(meta.position))
            local system = first_non_empty(collapse_metadata_values(value.system), collapse_metadata_values(meta.system))

            local item = {
                name = name,
                packageId = NIXPKGS_REF .. "#" .. relative_attr,
                version = version,
                summary = summary,
                description = description,
                homepage = homepage,
                documentation = documentation,
                sourceUrl = source_url,
                license = license,
                architecture = system,
                packageType = "flake",
                repository = NIXPKGS_REF,
                extraFields = copy_string_map({
                    attrPath = attr_path,
                    maintainers = maintainers,
                    platforms = platforms,
                    position = position,
                }),
                attrPath = attr_path,
                relativeAttr = relative_attr,
            }

            if next(item.extraFields) == nil then
                item.extraFields = nil
            end

            results[#results + 1] = item
        end
    end

    return sort_package_infos(results), nil
end

local function regex_escape(value)
    return tostring(value or ""):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

local function split_installable(installable)
    local normalized = strip_flake_prefix(normalize_installable(installable))
    local source_ref, fragment = normalized:match("^(.-)#(.+)$")
    if source_ref ~= nil then
        return trim(source_ref), strip_known_attr_prefix(fragment), normalized
    end
    return trim(normalized), "", normalized
end

local function extract_search_term(prompt)
    local source_ref, fragment = split_installable(prompt)
    if fragment ~= "" then
        return source_ref, fragment
    end
    return NIXPKGS_REF, trim(prompt)
end

local function search_installable(context, source_ref, prompt)
    local search_term = trim(prompt)
    local ref = strip_flake_prefix(source_ref)
    if search_term == "" then
        return {}, nil
    end

    if ref == "" then
        return {}, nil
    end

    local nix, command_error = nix_command(context)
    if nix == nil then
        return nil, command_error
    end

    local command = nix .. " search --json " .. shell_quote(ref) .. " " .. shell_quote(search_term)
    local result = exec_run(context, command)
    if not result.success then
        return nil, "nix search failed"
    end

    return parse_search_results(result.stdout)
end

local function search_nixpkgs(context, prompt)
    return search_installable(context, NIXPKGS_REF, prompt)
end

local function exact_or_first_search_result(context, package_name)
    local source_ref, search_term = extract_search_term(package_name)
    if search_term == "" then
        return nil
    end

    local exact_pattern = "^" .. regex_escape(search_term) .. "$"
    local exact_results, exact_error = search_installable(context, source_ref, exact_pattern)
    if exact_results ~= nil then
        for _, item in ipairs(exact_results) do
            if item.name == search_term or item.relativeAttr == search_term then
                return item
            end
        end
        if #exact_results == 1 then
            return exact_results[1]
        end
    end

    if exact_error ~= nil then
        return nil
    end

    local fallback_results = search_installable(context, source_ref, search_term)
    if fallback_results == nil then
        return nil
    end

    for _, item in ipairs(fallback_results) do
        if item.name == search_term or item.relativeAttr == search_term then
            return item
        end
    end

    return fallback_results[1]
end

local function find_latest_search_result_for_entry(context, entry)
    if context == nil or not is_nixpkgs_ref(entry.originalUrl) then
        return nil
    end

    local installable = build_installable(entry.originalUrl, entry.attrPath)
    if trim(installable) == "" then
        return nil
    end

    return exact_or_first_search_result(context, installable)
end

local function build_outdated_package_info(context, entry)
    local installed = make_package_info(entry)
    if trim(installed.version) == "" then
        return nil
    end

    local latest = find_latest_search_result_for_entry(context, entry)
    if latest == nil or trim(latest.version) == "" or latest.version == installed.version then
        return nil
    end

    installed.latestVersion = latest.version
    installed.status = "outdated"
    installed.summary = first_non_empty(latest.summary, installed.summary)
    installed.description = first_non_empty(latest.description, latest.summary, installed.description)
    installed.homepage = first_non_empty(latest.homepage, installed.homepage)
    installed.documentation = first_non_empty(latest.documentation, installed.documentation)
    installed.sourceUrl = first_non_empty(latest.sourceUrl, installed.sourceUrl)
    installed.license = first_non_empty(latest.license, installed.license)
    installed.extraFields = merge_string_maps(installed.extraFields, latest.extraFields)
    return installed
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
    return { "System", "Package Manager", "Nix" }
end

function plugin.getMissingPackages(packages)
    reset_nix_cache()

    if packages == nil or #packages == 0 then
        return {}
    end

    local binary = find_existing_nix_binary(nil)
    if binary == nil then
        return packages
    end

    local result = exec_run(nil, nix_invocation(binary) .. " profile list --json")
    if not result.success then
        return packages
    end

    local entries = parse_profile_elements(result.stdout)
    if entries == nil then
        return packages
    end

    local missing = {}
    for _, package in ipairs(packages) do
        local action = trim(package.action)
        local entry = find_matching_entry(entries, package)
        local installed = entry ~= nil

        if action == "remove" then
            if installed then
                missing[#missing + 1] = package
            end
        elseif action == "update" then
            if entry ~= nil and build_outdated_package_info(nil, entry) ~= nil then
                missing[#missing + 1] = package
            end
        elseif not installed then
            missing[#missing + 1] = package
        end
    end

    return missing
end

function plugin.install(context, packages)
    reset_nix_cache()

    if packages == nil or #packages == 0 then
        return true
    end

    local installables = {}
    for _, package in ipairs(packages) do
        local installable = normalize_installable(package.name)
        if installable ~= "" then
            installables[#installables + 1] = installable
        end
    end

    if #installables == 0 then
        return true
    end

    local nix, command_error = nix_command(context)
    if nix == nil then
        tx_failed(context, command_error)
        return false
    end

    begin_step(context, "install nix packages")
    local command = nix .. " profile install " .. join_shell_quoted(installables)
    local result = exec_run(context, command)
    if not result.success then
        tx_failed(context, "nix install failed")
        return false
    end

    emit_event(context, "installed", packages)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    reset_nix_cache()

    local installable = trim(path)
    if installable == "" then
        tx_failed(context, "nix local install path missing")
        return false
    end

    local nix, command_error = nix_command(context)
    if nix == nil then
        tx_failed(context, command_error)
        return false
    end

    begin_step(context, "install local nix target")
    local command = nix .. " profile install " .. shell_quote(installable)
    local result = exec_run(context, command)
    if not result.success then
        tx_failed(context, "nix local install failed")
        return false
    end

    emit_event(context, "installed", { path = installable, localTarget = true })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    reset_nix_cache()

    if packages == nil or #packages == 0 then
        return true
    end

    local entries, error_message = get_profile_entries(context)
    if entries == nil then
        tx_failed(context, error_message)
        return false
    end

    local targets = {}
    local removed = {}
    for _, package in ipairs(packages) do
        local entry = find_matching_entry(entries, package)
        if entry ~= nil then
            targets[#targets + 1] = entry.entryName ~= "" and entry.entryName or entry.storePaths[1]
            removed[#removed + 1] = package
        end
    end

    if #targets == 0 then
        tx_success(context)
        return true
    end

    local nix, command_error = nix_command(context)
    if nix == nil then
        tx_failed(context, command_error)
        return false
    end

    begin_step(context, "remove nix packages")
    local command = nix .. " profile remove " .. join_shell_quoted(targets)
    local result = exec_run(context, command)
    if not result.success then
        tx_failed(context, "nix remove failed")
        return false
    end

    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    reset_nix_cache()

    if packages == nil or #packages == 0 then
        return true
    end

    local entries, error_message = get_profile_entries(context)
    if entries == nil then
        tx_failed(context, error_message)
        return false
    end

    local targets = {}
    local updated = {}
    for _, package in ipairs(packages) do
        local entry = find_matching_entry(entries, package)
        if entry ~= nil and build_outdated_package_info(context, entry) ~= nil then
            targets[#targets + 1] = entry.entryName
            updated[#updated + 1] = package
        end
    end

    if #targets == 0 then
        tx_success(context)
        return true
    end

    local nix, command_error = nix_command(context)
    if nix == nil then
        tx_failed(context, command_error)
        return false
    end

    begin_step(context, "update nix packages")
    local command = nix .. " profile upgrade " .. join_shell_quoted(targets)
    local result = exec_run(context, command)
    if not result.success then
        tx_failed(context, "nix update failed")
        return false
    end

    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    reset_nix_cache()

    local entries, error_message = get_profile_entries(context)
    if entries == nil then
        emit_event(context, "listed", {})
        if context ~= nil and context.log ~= nil and type(context.log.warn) == "function" then
            context.log.warn(error_message)
        end
        return {}
    end

    local items = {}
    for _, entry in ipairs(entries) do
        items[#items + 1] = make_package_info(entry)
    end

    sort_package_infos(items)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    reset_nix_cache()

    local entries, error_message = get_profile_entries(context)
    if entries == nil then
        emit_event(context, "outdated", {})
        if context ~= nil and context.log ~= nil and type(context.log.warn) == "function" then
            context.log.warn(error_message)
        end
        return {}
    end

    local items = {}
    for _, entry in ipairs(entries) do
        local item = build_outdated_package_info(context, entry)
        if item ~= nil then
            items[#items + 1] = item
        end
    end

    sort_package_infos(items)
    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    reset_nix_cache()

    local source_ref, search_term = extract_search_term(prompt)
    if trim(search_term) == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local items, error_message = search_installable(context, source_ref, search_term)
    if items == nil then
        emit_event(context, "searched", {})
        if context ~= nil and context.log ~= nil and type(context.log.warn) == "function" then
            context.log.warn(error_message)
        end
        return {}
    end

    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    reset_nix_cache()

    local item = exact_or_first_search_result(context, name)
    if item == nil then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    reset_nix_cache()

    if package == nil or trim(package.name) == "" then
        return nil
    end

    local source_ref, attr_fragment, normalized = split_installable(package.name)
    local item = exact_or_first_search_result(context, package.name)
    if item == nil then
        local installable = normalized ~= "" and normalized or normalize_installable(package.name)
        if installable == "" then
            return nil
        end

        return {
            name = first_non_empty(attr_fragment:match("([^%.]+)$"), derive_name_from_ref(installable), trim(package.name)),
            packageId = installable,
            version = trim(package.version) ~= "" and trim(package.version) or nil,
            extraFields = copy_string_map({
                sourceRef = source_ref,
                requestedAttr = attr_fragment,
            }),
        }
    end

    return {
        name = item.name,
        packageId = item.packageId,
        version = item.version,
        homepage = item.homepage,
        sourceUrl = item.sourceUrl,
        license = item.license,
        extraFields = merge_string_maps(item.extraFields, copy_string_map({
            sourceRef = source_ref,
            requestedAttr = attr_fragment,
            resolvedFrom = normalized,
        })),
    }
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "nix" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".nix-profile" },
            { kind = "user-home-subpath", value = ".nix-defexpr" },
            { kind = "user-home-subpath", value = ".nix-channels" },
            { kind = "user-home-subpath", value = ".local/state/nix" },
            { kind = "filesystem", value = "/nix" },
        },
        networkScopes = { "nixos.org", "github.com", "cache.nixos.org" },
        privilegeLevel = "user",
        osvEcosystem = "NixOS",
        purlType = "nix",
    }
end

function plugin.init()
    active_nix_binary = nil
    return true
end

function plugin.shutdown()
    return true
end

return plugin
