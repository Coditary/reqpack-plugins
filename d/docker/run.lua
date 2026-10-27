plugin = {}

local PLUGIN_NAME = "Docker"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "docker"
local LIST_COMMAND = "docker image ls --digests --no-trunc --format json"
local SEARCH_FORMAT = "'{{json .}}'"
local SEARCH_LIMIT = 25

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

local function read_nested_field(value, ...)
    local current = value
    for index = 1, select("#", ...) do
        current = read_field(current, select(index, ...))
        if current == nil then
            return nil
        end
    end
    return current
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

local function run_global(command)
    if reqpack == nil or reqpack.exec == nil or type(reqpack.exec.run) ~= "function" then
        return {
            success = false,
            stdout = "",
            stderr = "reqpack.exec.run unavailable",
        }
    end
    return reqpack.exec.run(command)
end

local function make_exec_runner(context)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        return function(command)
            return context.exec.run(command)
        end
    end
    return run_global
end

local function command_exists()
    return run_global("command -v " .. REQUIRED_BINARY .. " >/dev/null 2>&1").success
end

local function is_image_id(value)
    local cleaned = trim(value)
    return cleaned:match("^sha256:[0-9a-fA-F]+$") ~= nil or cleaned:match("^[0-9a-fA-F]{12,}$") ~= nil
end

local function has_digest(value)
    return trim(value):match("@sha256:[0-9a-fA-F]+$") ~= nil
end

local function last_slash_index(value)
    local last = 0
    for index = 1, #value do
        if value:sub(index, index) == "/" then
            last = index
        end
    end
    return last
end

local function explicit_tag_index(value)
    local cleaned = trim(value)
    if cleaned == "" or has_digest(cleaned) or is_image_id(cleaned) then
        return nil
    end

    local last_slash = last_slash_index(cleaned)
    for index = #cleaned, 1, -1 do
        if cleaned:sub(index, index) == ":" then
            if index > last_slash then
                return index
            end
            return nil
        end
    end
    return nil
end

local function normalize_reference(value)
    local cleaned = trim(value)
    if cleaned == "" then
        return ""
    end
    if has_digest(cleaned) or is_image_id(cleaned) then
        return cleaned
    end
    if explicit_tag_index(cleaned) ~= nil then
        return cleaned
    end
    return cleaned .. ":latest"
end

local function parse_reference(value)
    local cleaned = trim(value)
    if cleaned == "" then
        return {
            original = "",
            normalized = "",
        }
    end

    if is_image_id(cleaned) then
        return {
            original = cleaned,
            normalized = cleaned,
            imageId = cleaned,
            version = cleaned,
        }
    end

    local digest = cleaned:match("@(sha256:[0-9a-fA-F]+)$")
    if digest ~= nil then
        local name = cleaned:gsub("@sha256:[0-9a-fA-F]+$", "")
        return {
            original = cleaned,
            normalized = cleaned,
            name = name,
            digest = digest,
            version = digest,
            repository = name,
        }
    end

    local normalized = normalize_reference(cleaned)
    local tag_index = explicit_tag_index(normalized)
    if tag_index == nil then
        return {
            original = cleaned,
            normalized = normalized,
            name = normalized,
            version = normalized,
            repository = normalized,
        }
    end

    local repository = normalized:sub(1, tag_index - 1)
    local tag = normalized:sub(tag_index + 1)
    return {
        original = cleaned,
        normalized = normalized,
        name = repository,
        tag = tag,
        version = tag,
        repository = repository,
    }
end

local function package_identifier(package)
    local name = trim(read_field(package, "name") or read_field(package, "packageId") or "")
    local version = trim(read_field(package, "version") or "")
    if name == "" then
        return ""
    end

    if version ~= "" and not has_digest(name) and explicit_tag_index(name) == nil and not is_image_id(name) then
        if version:match("^sha256:[0-9a-fA-F]+$") then
            return name .. "@" .. version
        end
        return name .. ":" .. version
    end
    return name
end

local function package_action(package)
    return lower(read_field(package, "action") or "")
end

local function package_platform(package)
    local flags = read_field(package, "flags")
    if flags == nil then
        return nil
    end

    local index = 1
    while true do
        local flag = read_field(flags, index) or (type(flags) == "table" and flags[index] or nil)
        if flag == nil then
            break
        end
        local value = trim(flag)
        local platform = value:match("^platform=(.+)$")
        if platform ~= nil and trim(platform) ~= "" then
            return trim(platform)
        end
        index = index + 1
    end
    return nil
end

local function maybe_set(target, key, value)
    if value ~= nil then
        target[key] = value
    end
end

local function build_extra_fields(base)
    if next(base) == nil then
        return nil
    end
    return base
end

local function digest_from_repo_digest(repo_digest)
    local cleaned = trim(repo_digest)
    return cleaned:match("@(sha256:[0-9a-fA-F]+)$")
end

local function first_repo_digest(repo_digests, repository)
    if type(repo_digests) ~= "table" then
        return nil
    end

    for _, item in ipairs(repo_digests) do
        local cleaned = trim(item)
        if repository ~= nil and cleaned:sub(1, #repository) == repository and cleaned:sub(#repository + 1, #repository + 1) == "@" then
            return cleaned
        end
    end

    for _, item in ipairs(repo_digests) do
        local cleaned = trim(item)
        if cleaned ~= "" then
            return cleaned
        end
    end
    return nil
end

local function local_list_entry_to_item(entry)
    local repository = non_empty(read_field(entry, "Repository"))
    local tag = non_empty(read_field(entry, "Tag"))
    local digest = non_empty(read_field(entry, "Digest"))
    local image_id = non_empty(read_field(entry, "ID"))

    if repository == "<none>" then
        repository = nil
    end
    if tag == "<none>" then
        tag = nil
    end
    if digest == "<none>" then
        digest = nil
    end

    local parsed = nil
    local name = nil
    if repository ~= nil and tag ~= nil then
        parsed = parse_reference(repository .. ":" .. tag)
        name = parsed.normalized
    elseif repository ~= nil and digest ~= nil then
        parsed = parse_reference(repository .. "@" .. digest)
        name = parsed.normalized
    else
        name = image_id
    end

    if name == nil then
        return nil
    end

    local extra = {}
    maybe_set(extra, "digest", digest)
    maybe_set(extra, "imageId", image_id)
    maybe_set(extra, "containers", non_empty(read_field(entry, "Containers")))
    maybe_set(extra, "createdAt", non_empty(read_field(entry, "CreatedAt")))
    maybe_set(extra, "createdSince", non_empty(read_field(entry, "CreatedSince")))
    maybe_set(extra, "size", non_empty(read_field(entry, "Size")))
    maybe_set(extra, "purl.name", repository)

    return {
        name = name,
        packageId = name,
        version = parsed ~= nil and parsed.version or digest or image_id,
        installed = true,
        type = "package",
        summary = name,
        repository = repository,
        size = non_empty(read_field(entry, "Size")),
        digest = digest,
        imageId = image_id,
        extraFields = build_extra_fields(extra),
    }
end

local function inspect_details_to_item(details, requested)
    local requested_ref = parse_reference(requested)
    local image_id = non_empty(read_field(details, "Id"))
    local repo_tags = read_field(details, "RepoTags")
    local repo_digests = read_field(details, "RepoDigests")

    local chosen_tag = nil
    if requested_ref.normalized ~= "" and requested_ref.imageId == nil then
        chosen_tag = requested_ref.normalized
    elseif type(repo_tags) == "table" then
        for _, item in ipairs(repo_tags) do
            local cleaned = trim(item)
            if cleaned ~= "" and cleaned ~= "<none>:<none>" then
                chosen_tag = normalize_reference(cleaned)
                break
            end
        end
    end

    local repository = requested_ref.repository
    if repository == nil and chosen_tag ~= nil then
        repository = parse_reference(chosen_tag).repository
    end

    local repo_digest = first_repo_digest(repo_digests, repository)
    local digest = digest_from_repo_digest(repo_digest)
    local name = chosen_tag or repo_digest or image_id
    local parsed = parse_reference(name or "")

    local extra = {}
    maybe_set(extra, "digest", digest)
    maybe_set(extra, "imageId", image_id)
    maybe_set(extra, "repoDigest", repo_digest)
    maybe_set(extra, "platform.os", non_empty(read_field(details, "Os")))
    maybe_set(extra, "platform.arch", non_empty(read_field(details, "Architecture")))
    maybe_set(extra, "platform.variant", non_empty(read_field(details, "Variant")))
    maybe_set(extra, "purl.name", repository)

    return {
        name = name,
        packageId = name,
        version = digest or parsed.version or image_id,
        installed = true,
        type = "package",
        summary = name,
        repository = repository,
        architecture = non_empty(read_field(details, "Architecture")),
        os = non_empty(read_field(details, "Os")),
        size = read_field(details, "Size"),
        digest = digest,
        imageId = image_id,
        extraFields = build_extra_fields(extra),
    }
end

local function search_entry_to_item(entry)
    local repository = non_empty(read_field(entry, "Name"))
    if repository == nil then
        return nil
    end

    local parsed = parse_reference(repository)
    local extra = {}
    maybe_set(extra, "official", read_field(entry, "IsOfficial"))
    maybe_set(extra, "automated", read_field(entry, "IsAutomated"))
    maybe_set(extra, "stars", read_field(entry, "StarCount"))
    maybe_set(extra, "purl.name", parsed.repository)

    return {
        name = parsed.normalized,
        packageId = parsed.normalized,
        version = parsed.version,
        installed = false,
        type = "package",
        summary = non_empty(read_field(entry, "Description")) or parsed.normalized,
        description = non_empty(read_field(entry, "Description")),
        repository = parsed.repository,
        extraFields = build_extra_fields(extra),
    }
end

local function normalize_platform(platform)
    if type(platform) ~= "table" then
        return nil
    end
    return {
        os = lower(read_field(platform, "os") or read_field(platform, "Os") or ""),
        architecture = lower(read_field(platform, "architecture") or read_field(platform, "Architecture") or ""),
        variant = lower(read_field(platform, "variant") or read_field(platform, "Variant") or ""),
    }
end

local function desired_platform_from_details(details)
    local platform = normalize_platform({
        os = read_field(details, "Os"),
        architecture = read_field(details, "Architecture"),
        variant = read_field(details, "Variant"),
    })

    if platform == nil then
        return nil
    end
    if platform.os == "" and platform.architecture == "" and platform.variant == "" then
        return nil
    end
    return platform
end

local function manifest_entries(data)
    if is_array(data) then
        return data
    end

    local manifests = read_field(data, "manifests")
    if type(manifests) == "table" and is_array(manifests) then
        return manifests
    end

    return { data }
end

local function manifest_entry_digest(entry)
    return non_empty(read_nested_field(entry, "Descriptor", "digest")) or non_empty(read_field(entry, "digest"))
end

local function manifest_entry_platform(entry)
    return normalize_platform(read_nested_field(entry, "Descriptor", "platform") or read_field(entry, "platform"))
end

local function manifest_entry_annotations(entry)
    return read_nested_field(entry, "OCIManifest", "annotations") or read_nested_field(entry, "SchemaV2Manifest", "annotations")
end

local function choose_manifest_entry(data, desired_platform)
    local entries = manifest_entries(data)
    local best = nil
    local best_score = -1

    for _, entry in ipairs(entries) do
        local digest = manifest_entry_digest(entry)
        if digest ~= nil then
            local platform = manifest_entry_platform(entry)
            local score = 1

            if platform ~= nil and platform.os ~= "unknown" then
                score = score + 1
            end
            if platform ~= nil and platform.architecture ~= "unknown" then
                score = score + 1
            end

            if desired_platform ~= nil then
                if platform == nil then
                    score = -1
                else
                    if desired_platform.os ~= "" and platform.os ~= "" and platform.os ~= desired_platform.os then
                        score = -1
                    end
                    if score >= 0 and desired_platform.architecture ~= "" and platform.architecture ~= "" and platform.architecture ~= desired_platform.architecture then
                        score = -1
                    end
                    if score >= 0 and desired_platform.os ~= "" and platform.os == desired_platform.os then
                        score = score + 4
                    end
                    if score >= 0 and desired_platform.architecture ~= "" and platform.architecture == desired_platform.architecture then
                        score = score + 4
                    end
                    if score >= 0 and desired_platform.variant ~= "" and platform.variant == desired_platform.variant then
                        score = score + 1
                    end
                end
            end

            if score > best_score then
                best = entry
                best_score = score
            end
        end
    end

    return best
end

local function remote_manifest_to_item(reference, data, desired_platform)
    local entry = choose_manifest_entry(data, desired_platform)
    if entry == nil then
        return nil
    end

    local parsed = parse_reference(reference)
    local platform = manifest_entry_platform(entry)
    local digest = manifest_entry_digest(entry)
    local annotations = manifest_entry_annotations(entry)
    local extra = {}
    maybe_set(extra, "digest", digest)
    maybe_set(extra, "platform.os", platform ~= nil and non_empty(platform.os) or nil)
    maybe_set(extra, "platform.arch", platform ~= nil and non_empty(platform.architecture) or nil)
    maybe_set(extra, "platform.variant", platform ~= nil and non_empty(platform.variant) or nil)
    maybe_set(extra, "remoteRef", non_empty(read_field(entry, "Ref")))
    maybe_set(extra, "purl.name", parsed.repository)

    local description = nil
    if type(annotations) == "table" then
        description = non_empty(read_field(annotations, "org.opencontainers.image.description"))
            or non_empty(read_field(annotations, "org.opencontainers.image.url"))
            or non_empty(read_field(annotations, "org.opencontainers.image.source"))
    end

    return {
        name = parsed.normalized,
        packageId = parsed.normalized,
        version = parsed.version or digest,
        latestVersion = digest,
        installed = false,
        type = "package",
        summary = parsed.normalized,
        description = description,
        repository = parsed.repository,
        architecture = platform ~= nil and non_empty(platform.architecture) or nil,
        os = platform ~= nil and non_empty(platform.os) or nil,
        digest = digest,
        extraFields = build_extra_fields(extra),
    }
end

local function parse_json_lines(stdout, mapper)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        local cleaned = trim(line)
        if cleaned ~= "" then
            local ok, decoded = try_json_decode(cleaned)
            if ok then
                local item = mapper(decoded)
                if item ~= nil then
                    items[#items + 1] = item
                end
            end
        end
    end
    return items
end

local function collect_local_items_with_runner(exec_runner)
    local result = exec_runner(LIST_COMMAND)
    if not result.success then
        return nil, result
    end
    return parse_json_lines(result.stdout, local_list_entry_to_item), result
end

local function collect_local_items(context)
    return collect_local_items_with_runner(make_exec_runner(context))
end

local function item_matches_identifier(item, identifier)
    if item == nil then
        return false
    end

    local cleaned = trim(identifier)
    if cleaned == "" then
        return false
    end

    if is_image_id(cleaned) then
        return cleaned == trim(item.imageId) or cleaned == trim(read_nested_field(item, "extraFields", "imageId"))
    end

    local normalized = normalize_reference(cleaned)
    if normalized == trim(item.packageId) or normalized == trim(item.name) then
        return true
    end

    local digest_ref = trim(read_nested_field(item, "extraFields", "digest") or "")
    local repository = trim(item.repository or "")
    if repository ~= "" and digest_ref ~= "" and repository .. "@" .. digest_ref == cleaned then
        return true
    end

    return false
end

local function find_local_item(items, identifier)
    for _, item in ipairs(items or {}) do
        if item_matches_identifier(item, identifier) then
            return item
        end
    end
    return nil
end

local function inspect_local_with_runner(exec_runner, identifier)
    local result = exec_runner("docker image inspect " .. shell_quote(identifier))
    if not result.success then
        return nil, result
    end

    local ok, decoded = try_json_decode(result.stdout)
    if not ok then
        return nil, result
    end

    if type(decoded) == "table" and is_array(decoded) and decoded[1] ~= nil then
        return decoded[1], result
    end
    if type(decoded) == "table" then
        return decoded, result
    end
    return nil, result
end

local function query_remote_manifest_with_runner(exec_runner, reference)
    local result = exec_runner("docker manifest inspect --verbose " .. shell_quote(reference))
    if not result.success then
        return nil, result
    end

    local ok, decoded = try_json_decode(result.stdout)
    if not ok then
        return nil, result
    end
    return decoded, result
end

local function ensure_docker_for_mutation(context)
    if command_exists() then
        return true
    end

    emit_event(context, "unavailable", { reason = "docker-not-installed" })
    tx_failed(context, "docker CLI not available")
    return false
end

local function build_resolved_package(original_package, item)
    if item == nil then
        return nil
    end

    local extra = shallow_copy(type(item.extraFields) == "table" and item.extraFields or {})
    local version = non_empty(item.latestVersion)
        or non_empty(read_field(extra, "digest"))
        or non_empty(item.version)
        or non_empty(item.imageId)

    if version == nil then
        return nil
    end

    local resolved = {
        action = read_field(original_package, "action"),
        system = read_field(original_package, "system"),
        name = non_empty(item.packageId) or non_empty(item.name),
        version = version,
    }

    if next(extra) ~= nil then
        resolved.extraFields = extra
    end

    if read_field(original_package, "flags") ~= nil then
        resolved.flags = read_field(original_package, "flags")
    end
    if read_field(original_package, "sourcePath") ~= nil then
        resolved.sourcePath = read_field(original_package, "sourcePath")
    end
    if read_field(original_package, "localTarget") == true then
        resolved.localTarget = true
    end

    return resolved
end

local function parse_loaded_image(stdout)
    for _, line in ipairs(split_lines(stdout)) do
        local image = trim(line:match("^Loaded image:%s*(.+)$") or "")
        if image ~= "" then
            return normalize_reference(image)
        end

        local image_id = trim(line:match("^Loaded image ID:%s*(.+)$") or "")
        if image_id ~= "" then
            return image_id
        end
    end
    return nil
end

local function run_mutation(context, label, packages, command_builder, event_name)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end
    if not ensure_docker_for_mutation(context) then
        return false
    end

    local exec_runner = make_exec_runner(context)
    for _, package in ipairs(requested) do
        local identifier = normalize_reference(package_identifier(package))
        if identifier == "" then
            emit_event(context, "unavailable", { reason = "missing-package-name" })
            tx_failed(context, "missing docker image reference")
            return false
        end

        local command = command_builder(identifier, package_platform(package))
        begin_step(context, label .. " " .. identifier)
        local result = exec_runner(command)
        if not result.success then
            tx_failed(context, "docker command failed for " .. identifier)
            return false
        end

        emit_event(context, event_name, {
            name = identifier,
            packageId = identifier,
        })
    end

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
    return { "Package Manager", "Docker", "Container" }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end

    local local_items = collect_local_items_with_runner(run_global)
    if local_items == nil then
        return packages
    end

    local missing = {}
    for _, package in ipairs(packages) do
        local action = package_action(package)
        local identifier = normalize_reference(package_identifier(package))
        local local_item = find_local_item(local_items, identifier)

        if action == "remove" then
            if local_item ~= nil then
                missing[#missing + 1] = package
            end
        elseif action == "update" then
            if local_item ~= nil then
                if has_digest(identifier) then
                else
                    local details = inspect_local_with_runner(run_global, local_item.packageId or identifier)
                    local desired_platform = desired_platform_from_details(details)
                    local manifest = query_remote_manifest_with_runner(run_global, identifier)
                    if manifest == nil then
                        missing[#missing + 1] = package
                    else
                        local remote_item = remote_manifest_to_item(identifier, manifest, desired_platform)
                        local local_digest = non_empty(local_item.digest) or non_empty(read_nested_field(local_item, "extraFields", "digest"))
                        local remote_digest = remote_item ~= nil and non_empty(remote_item.latestVersion) or nil
                        if local_digest == nil or remote_digest == nil or local_digest ~= remote_digest then
                            missing[#missing + 1] = package
                        end
                    end
                end
            end
        else
            if local_item == nil then
                missing[#missing + 1] = package
            end
        end
    end

    return missing
end

function plugin.install(context, packages)
    return run_mutation(
        context,
        "pull docker image",
        packages,
        function(identifier, platform)
            local command = "docker pull"
            if platform ~= nil then
                command = command .. " --platform " .. shell_quote(platform)
            end
            return command .. " " .. shell_quote(identifier)
        end,
        "installed"
    )
end

function plugin.installLocal(context, path)
    local cleaned_path = trim(path)
    if cleaned_path == "" then
        begin_step(context, "install local docker image")
        tx_failed(context, "missing local image archive path")
        return false
    end
    if not ensure_docker_for_mutation(context) then
        return false
    end

    begin_step(context, "install local docker image")
    local result = make_exec_runner(context)("docker load --input " .. shell_quote(cleaned_path))
    if not result.success then
        tx_failed(context, "docker load failed")
        return false
    end

    local loaded = parse_loaded_image(result.stdout)
    emit_event(context, "installed", {
        path = cleaned_path,
        name = loaded,
        packageId = loaded,
        localTarget = true,
    })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    return run_mutation(
        context,
        "remove docker image",
        packages,
        function(identifier)
            return "docker image rm " .. shell_quote(identifier)
        end,
        "deleted"
    )
end

function plugin.update(context, packages)
    local requested = packages or {}
    if #requested == 0 then
        return true
    end

    return run_mutation(
        context,
        "update docker image",
        requested,
        function(identifier, platform)
            local command = "docker pull"
            if platform ~= nil then
                command = command .. " --platform " .. shell_quote(platform)
            end
            return command .. " " .. shell_quote(identifier)
        end,
        "updated"
    )
end

function plugin.list(context)
    local items, result = collect_local_items(context)
    if items == nil then
        log_warn(context, "docker image ls failed")
        emit_event(context, "unavailable", { reason = result ~= nil and result.stderr or "docker-image-ls-failed" })
        items = {}
    end
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local items, result = collect_local_items(context)
    if items == nil then
        log_warn(context, "docker image ls failed")
        emit_event(context, "unavailable", { reason = result ~= nil and result.stderr or "docker-image-ls-failed" })
        emit_event(context, "outdated", {})
        return {}
    end

    local exec_runner = make_exec_runner(context)
    local outdated = {}
    for _, item in ipairs(items) do
        local parsed = parse_reference(item.packageId or item.name or "")
        if parsed.repository ~= nil and parsed.tag ~= nil and not has_digest(item.packageId or item.name or "") then
            local details = inspect_local_with_runner(exec_runner, item.packageId)
            local desired_platform = desired_platform_from_details(details)
            local manifest = query_remote_manifest_with_runner(exec_runner, item.packageId)
            if manifest ~= nil then
                local remote_item = remote_manifest_to_item(item.packageId, manifest, desired_platform)
                local local_digest = non_empty(item.digest) or non_empty(read_nested_field(item, "extraFields", "digest"))
                local remote_digest = remote_item ~= nil and non_empty(remote_item.latestVersion) or nil
                if local_digest ~= nil and remote_digest ~= nil and local_digest ~= remote_digest then
                    local enriched = shallow_copy(item)
                    enriched.latestVersion = remote_digest
                    enriched.architecture = enriched.architecture or (remote_item and remote_item.architecture)
                    enriched.os = enriched.os or (remote_item and remote_item.os)
                    outdated[#outdated + 1] = enriched
                end
            end
        end
    end

    emit_event(context, "outdated", outdated)
    return outdated
end

function plugin.search(context, prompt)
    if trim(prompt) == "" then
        emit_event(context, "searched", {})
        return {}
    end

    local command = "docker search --limit " .. tostring(SEARCH_LIMIT) .. " --no-trunc --format " .. SEARCH_FORMAT .. " " .. shell_quote(trim(prompt))
    local result = make_exec_runner(context)(command)
    if not result.success then
        log_warn(context, "docker search failed")
        emit_event(context, "unavailable", { reason = result.stderr or "docker-search-failed" })
        emit_event(context, "searched", {})
        return {}
    end

    local items = parse_json_lines(result.stdout, search_entry_to_item)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local identifier = normalize_reference(trim(name))
    if identifier == "" then
        emit_event(context, "informed", {})
        return {}
    end

    local exec_runner = make_exec_runner(context)
    local details = inspect_local_with_runner(exec_runner, identifier)
    if details ~= nil then
        local item = inspect_details_to_item(details, identifier)
        emit_event(context, "informed", item)
        return item
    end

    local manifest = query_remote_manifest_with_runner(exec_runner, identifier)
    if manifest ~= nil then
        local item = remote_manifest_to_item(identifier, manifest, nil)
        if item ~= nil then
            emit_event(context, "informed", item)
            return item
        end
    end

    emit_event(context, "informed", {})
    return {}
end

function plugin.resolvePackage(context, package)
    if package == nil or read_field(package, "localTarget") == true or read_field(package, "sourcePath") ~= nil then
        return nil
    end

    local identifier = normalize_reference(package_identifier(package))
    if identifier == "" then
        return nil
    end

    local exec_runner = make_exec_runner(context)
    local details = inspect_local_with_runner(exec_runner, identifier)
    if details ~= nil then
        return build_resolved_package(package, inspect_details_to_item(details, identifier))
    end

    local manifest = query_remote_manifest_with_runner(exec_runner, identifier)
    if manifest ~= nil then
        return build_resolved_package(package, remote_manifest_to_item(identifier, manifest, nil))
    end

    return nil
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
        ecosystemScopes = { "docker" },
        writeScopes = {
            { kind = "user-home-subpath", value = ".docker" },
        },
        networkScopes = {
            { host = "auth.docker.io", scheme = "https" },
            { host = "registry-1.docker.io", scheme = "https" },
            { host = "hub.docker.com", scheme = "https" },
        },
        privilegeLevel = "user",
        purlType = "docker",
        versionComparatorProfile = "lexicographic",
    }
end

return plugin
