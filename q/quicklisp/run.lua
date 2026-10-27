plugin = {}

local PLUGIN_ID = "quicklisp"
local PLUGIN_NAME = "Quicklisp"
local PLUGIN_VERSION = "0.1.0"
local RUNNER_BINARY = "sbcl"
local BOOTSTRAP_BINARY = "curl"
local QUICKSTART_URL = "https://beta.quicklisp.org/quicklisp.lisp"

plugin.fileExtensions = { ".asd", ".lisp", ".cl", ".lsp" }

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
        local value = non_empty(select(index, ...))
        if value ~= nil then
            return value
        end
    end
    return nil
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

local function split_tsv(line)
    local fields = {}
    for field in (tostring(line or "") .. "\t"):gmatch("(.-)\t") do
        fields[#fields + 1] = field
    end
    return fields
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

local function reqpack_path(name)
    local paths = type(reqpack) == "table" and read_field(reqpack, "paths") or nil
    if type(paths) ~= "table" then
        return nil
    end
    return non_empty(read_field(paths, name))
end

local function read_proc_environ_value(name)
    if os ~= nil and type(os.getenv) == "function" then
        local value = os.getenv(tostring(name or ""))
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
        if entry:sub(1, #prefix) == prefix then
            return trim(entry:sub(#prefix + 1))
        end
    end
    return nil
end

local function fixture_root()
    return trim(read_proc_environ_value("REQPACK_TEST_FIXTURE_ROOT") or "")
end

local function expand_runtime_placeholders(value)
    local text = tostring(value or "")
    local root = fixture_root()
    if root ~= "" then
        text = text:gsub("%$%{fixtureRoot%}", root)
    end
    return text
end

local function object_flags(value)
    local raw = read_field(value, "flags")
    if type(raw) ~= "table" and type(raw) ~= "userdata" then
        return {}
    end

    local flags = {}
    local ok = pcall(function()
        for _, item in ipairs(raw) do
            local cleaned = trim(item)
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

local function flag_value_from_list(flags, key)
    local prefix = trim(key) .. "="
    for _, flag in ipairs(flags or {}) do
        if trim(flag):sub(1, #prefix) == prefix then
            return trim(flag:sub(#prefix + 1))
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

local function basename(path)
    local cleaned = trim(path)
    return cleaned:match("([^/]+)$") or cleaned
end

local function dirname(path)
    local cleaned = trim(path)
    local result = cleaned:match("^(.*)/[^/]+$")
    if result ~= nil and result ~= "" then
        return result
    end
    return "."
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

local function ensure_directory(path)
    local dir = expand_runtime_placeholders(path)
    if trim(dir) == "" or dir == "." then
        return true
    end

    if os ~= nil and type(os.execute) == "function" then
        local ok = os.execute("mkdir -p " .. shell_quote(dir))
        if ok == true or ok == 0 then
            return true
        end
    end

    local probe = io.open(join_path(dir, "."), "rb")
    if probe ~= nil then
        probe:close()
        return true
    end
    return false
end

local function path_exists(path)
    local cleaned = expand_runtime_placeholders(path)
    local file = io.open(cleaned, "rb")
    if file ~= nil then
        file:close()
        return true
    end
    local dir = io.open(join_path(cleaned, "."), "rb")
    if dir ~= nil then
        dir:close()
        return true
    end
    return false
end

local function file_exists_via_exec(context, path)
    local result = exec_run(context, "test -f " .. shell_quote(path))
    return result ~= nil and result.success == true
end

local function read_text_file(path)
    local handle = io.open(expand_runtime_placeholders(path), "rb")
    if handle == nil then
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_text_file(path, content)
    local cleaned = expand_runtime_placeholders(path)
    ensure_directory(dirname(cleaned))
    local handle, open_error = io.open(cleaned, "wb")
    if handle == nil then
        if os ~= nil and type(os.execute) == "function" then
            local marker = "__REQPACK_QUICKLISP_EOF__"
            local command = "mkdir -p " .. shell_quote(dirname(cleaned))
                .. " && cat > " .. shell_quote(cleaned) .. " <<'" .. marker .. "'\n"
                .. tostring(content or "") .. "\n" .. marker
            local ok = os.execute(command)
            if ok == true or ok == 0 then
                return true, nil
            end
        end
        return nil, open_error
    end
    local ok, write_error = handle:write(content)
    handle:close()
    if not ok then
        return nil, write_error
    end
    return true, nil
end

local function plugin_root(context, packages)
    local flags = shallow_copy(object_flags(context))
    local request = read_field(context, "request")
    for _, flag in ipairs(object_flags(request)) do
        flags[#flags + 1] = flag
    end
    for _, pkg in ipairs(packages or {}) do
        for _, flag in ipairs(object_flags(pkg)) do
            flags[#flags + 1] = flag
        end
    end

    local explicit = expand_runtime_placeholders(flag_value_from_list(flags, "data-root") or "")
    if explicit ~= "" then
        return join_path(explicit, PLUGIN_ID)
    end

    local root = fixture_root()
    if root ~= "" then
        return join_path(root, ".reqpack-data", PLUGIN_ID)
    end

    local reqpack_data_root = reqpack_path("dataRoot")
    if reqpack_data_root ~= nil then
        return join_path(reqpack_data_root, PLUGIN_ID)
    end

    return join_path(".", ".reqpack-data", PLUGIN_ID)
end

local function state_paths(context, packages)
    local root = plugin_root(context, packages)
    return {
        root = root,
        home = join_path(root, "home"),
        setup = join_path(root, "home", "setup.lisp"),
        bootstrap = join_path(root, "bootstrap"),
        bootstrap_lisp = join_path(root, "bootstrap", "quicklisp.lisp"),
        tmp = join_path(root, "tmp"),
        local_projects = join_path(root, "home", "local-projects"),
    }
end

local function lisp_escape(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\")
    text = text:gsub('"', '\\"')
    return text
end

local function lisp_string(value)
    return '"' .. lisp_escape(value) .. '"'
end

local function lisp_pathname(value)
    return "#P" .. lisp_string(value)
end

local function lisp_string_list(values)
    local items = {}
    for _, value in ipairs(values or {}) do
        items[#items + 1] = lisp_string(value)
    end
    return "(list " .. table.concat(items, " ") .. ")"
end

local function install_bootstrap_command(paths)
    return table.concat({
        RUNNER_BINARY,
        "--noinform",
        "--non-interactive",
        "--load", shell_quote(paths.bootstrap_lisp),
        "--eval", shell_quote("(quicklisp-quickstart:install :path " .. lisp_pathname(join_path(paths.home, "")) .. ")"),
    }, " ")
end

local function runner_eval_command(program)
    return table.concat({
        RUNNER_BINARY,
        "--noinform",
        "--non-interactive",
        "--eval", shell_quote(program),
    }, " ")
end

local function ensure_runner(context)
    if command_exists(context, RUNNER_BINARY) then
        return true, nil
    end
    return nil, RUNNER_BINARY .. " binary not available"
end

local function ensure_quicklisp(context, paths)
    ensure_directory(paths.root)
    ensure_directory(paths.bootstrap)
    ensure_directory(paths.tmp)
    ensure_directory(paths.local_projects)

    local ok, message = ensure_runner(context)
    if not ok then
        return nil, message
    end

    if path_exists(paths.setup) or file_exists_via_exec(context, paths.setup) then
        return true, nil
    end

    if not command_exists(context, BOOTSTRAP_BINARY) then
        return nil, BOOTSTRAP_BINARY .. " binary not available"
    end

    if not path_exists(paths.bootstrap_lisp) then
        local download = exec_run(
            context,
            BOOTSTRAP_BINARY .. " -fsSL " .. shell_quote(QUICKSTART_URL) .. " -o " .. shell_quote(paths.bootstrap_lisp)
        )
        if download == nil or not download.success then
            return nil, first_non_empty(download and download.stderr, download and download.stdout, "failed to download quicklisp bootstrap")
        end
    end

    local install = exec_run(context, install_bootstrap_command(paths))
    if install == nil or not install.success then
        return nil, first_non_empty(install and install.stderr, install and install.stdout, "failed to install quicklisp")
    end

    return true, nil
end

local function base_lisp_lines(paths)
    return {
        "(load " .. lisp_pathname(paths.setup) .. ")",
        "(ql:register-local-projects)",
        [=[(defun reqpack-field (value)
  (let ((text (cond
                ((null value) "")
                ((stringp value) value)
                ((pathnamep value) (namestring value))
                ((symbolp value) (string-downcase (symbol-name value)))
                ((listp value) (format nil "~{~A~^,~}" value))
                (t (princ-to-string value)))))
    (setf text (substitute #\Space #\Tab text))
    (setf text (substitute #\Space #\Newline text))
    (setf text (substitute #\Space #\Return text))
    text))]=],
        [=[(defun reqpack-row (&rest cols)
  (format t "REQPACK")
  (dolist (value (mapcar #'reqpack-field cols))
    (format t "~C~A" #\Tab value))
  (terpri))]=],
        [=[(defun reqpack-sorted-copy (items &key (key #'identity))
  (sort (copy-list items) #'string< :key key))]=],
        [=[(defun reqpack-local-system-p (name)
  (member name (ql:list-local-systems) :test #'string=))]=],
        [=[(defun reqpack-source-path (name)
  (let ((path (ignore-errors (ql:where-is-system name))))
    (if path (namestring path) "")))]=],
        [=[(defun reqpack-dependencies (system)
  (let ((deps (ignore-errors (ql-dist:required-systems system))))
    (if deps (format nil "~{~A~^,~}" deps) "")))]=],
        [=[(defun reqpack-release-name (system)
  (let ((release (ignore-errors (ql-dist:release system))))
    (if release (ql-dist:name release) "")))]=],
        [=[(defun reqpack-release-version (system)
  (let ((release (ignore-errors (ql-dist:release system))))
    (if release (ql-dist:prefix release) "")))]=],
        [=[(defun reqpack-dist-name (system)
  (let ((dist (ignore-errors (ql-dist:dist system))))
    (if dist (ql-dist:name dist) "")))]=],
        [=[(defun reqpack-dist-version (system)
  (let ((dist (ignore-errors (ql-dist:dist system))))
    (if dist (ql-dist:version dist) "")))]=],
        [=[(defun reqpack-emit-system (system &optional latest-version forced-status local-override)
  (let* ((name (ql-dist:name system))
         (version (reqpack-release-version system))
         (installed (if (ignore-errors (ql-dist:installedp system)) "true" "false"))
         (status (or forced-status (if (string= installed "true") "installed" "available")))
         (local (if (or local-override (reqpack-local-system-p name)) "true" "false")))
    (reqpack-row
     "ITEM"
     name
     version
     (or latest-version version)
     installed
     status
     "common-lisp-system"
     (reqpack-release-name system)
     (reqpack-source-path name)
     (reqpack-dependencies system)
     (reqpack-release-name system)
     (reqpack-dist-name system)
     (reqpack-dist-version system)
     local)))]=],
        [=[(defun reqpack-emit-local (name)
  (reqpack-row
   "ITEM"
   name
   "local"
   "local"
   "true"
   "installed"
   "common-lisp-system"
   "local project"
   (reqpack-source-path name)
   ""
   ""
   "local"
   ""
   "true"))]=],
    }
end

local function build_lisp_program(paths, body_lines)
    local lines = { "(progn" }
    for _, line in ipairs(base_lisp_lines(paths)) do
        lines[#lines + 1] = line
    end
    for _, line in ipairs(body_lines or {}) do
        lines[#lines + 1] = line
    end
    lines[#lines + 1] = "(quit))"
    return table.concat(lines, " ")
end

local function parse_item_rows(stdout)
    local items = {}
    for _, line in ipairs(split_lines(stdout)) do
        if line:sub(1, 8) == "REQPACK\t" then
            local fields = split_tsv(line)
            if fields[2] == "ITEM" then
                local item = {
                    name = fields[3],
                    packageId = fields[3],
                    version = non_empty(fields[4]),
                    latestVersion = non_empty(fields[5]),
                    installed = fields[6] == "true",
                    status = non_empty(fields[7]) or "available",
                    packageType = non_empty(fields[8]) or "common-lisp-system",
                    type = "package",
                    summary = non_empty(fields[9]),
                    sourcePath = non_empty(fields[10]),
                    extraFields = {
                        dependencies = non_empty(fields[11]),
                        releaseName = non_empty(fields[12]),
                        distName = non_empty(fields[13]),
                        distVersion = non_empty(fields[14]),
                        localProject = non_empty(fields[15]),
                    }
                }
                if next(item.extraFields) == nil then
                    item.extraFields = nil
                end
                items[#items + 1] = item
            end
        end
    end
    table.sort(items, function(left, right)
        return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "")
    end)
    return items
end

local function run_lisp_script(context, paths, script_name, body_lines)
    local _ = script_name
    local result = exec_run(context, runner_eval_command(build_lisp_program(paths, body_lines)))
    if result == nil or not result.success then
        return nil, first_non_empty(result and result.stderr, result and result.stdout, "lisp script failed")
    end
    return result.stdout or "", nil
end

local function query_list(context, paths)
    local stdout, error_message = run_lisp_script(context, paths, "list", {
        [=[(let ((seen (make-hash-table :test 'equal)))
  (dolist (name (reqpack-sorted-copy (ql:list-local-systems)))
    (setf (gethash name seen) t)
    (reqpack-emit-local name))
  (dolist (dist (reqpack-sorted-copy (ql-dist:enabled-dists) :key #'ql-dist:name))
    (dolist (system (reqpack-sorted-copy (ql-dist:installed-systems dist) :key #'ql-dist:name))
      (unless (gethash (ql-dist:name system) seen)
        (setf (gethash (ql-dist:name system) seen) t)
        (reqpack-emit-system system)))))]=],
    })
    if stdout == nil then
        return nil, error_message
    end
    return parse_item_rows(stdout), nil
end

local function query_search(context, paths, prompt)
    local stdout, error_message = run_lisp_script(context, paths, "search", {
        "(dolist (system (reqpack-sorted-copy (ql:system-apropos-list " .. lisp_string(prompt) .. ") :key #'ql-dist:name))",
        "  (reqpack-emit-system system))",
    })
    if stdout == nil then
        return nil, error_message
    end
    return parse_item_rows(stdout), nil
end

local function query_info(context, paths, name)
    local stdout, error_message = run_lisp_script(context, paths, "info", {
        "(let ((target " .. lisp_string(name) .. "))",
        "  (cond",
        "    ((reqpack-local-system-p target) (reqpack-emit-local target))",
        "    (t",
        "      (let ((system (ql-dist:find-system target)))",
        "        (when system",
        "          (reqpack-emit-system system))))))",
    })
    if stdout == nil then
        return nil, error_message
    end
    local items = parse_item_rows(stdout)
    return items[1] or {}, nil
end

local function query_outdated(context, paths)
    local stdout, error_message = run_lisp_script(context, paths, "outdated", {
        [=[(let* ((dist (ql-dist:find-dist "quicklisp"))
       (new (and dist (ql-dist:available-update dist))))
  (when (and dist new)
    (dolist (system (reqpack-sorted-copy (ql-dist:installed-systems dist) :key #'ql-dist:name))
      (reqpack-emit-system system (ql-dist:version new) "outdated"))))]=],
    })
    if stdout == nil then
        return nil, error_message
    end
    return parse_item_rows(stdout), nil
end

local function mutate_quickload(context, paths, script_name, names)
    local stdout, error_message = run_lisp_script(context, paths, script_name, {
        "(dolist (name " .. lisp_string_list(names) .. ")",
        "  (ql:quickload name :silent t :prompt nil))",
    })
    if stdout == nil then
        return nil, error_message
    end
    return stdout, nil
end

local function mutate_uninstall(context, paths, script_name, names)
    local stdout, error_message = run_lisp_script(context, paths, script_name, {
        "(dolist (name " .. lisp_string_list(names) .. ")",
        "  (ql:uninstall name))",
    })
    if stdout == nil then
        return nil, error_message
    end
    return stdout, nil
end

local function mutate_register_local(context, paths)
    local stdout, error_message = run_lisp_script(context, paths, "register-local", {
        "(ql:register-local-projects)",
    })
    if stdout == nil then
        return nil, error_message
    end
    return stdout, nil
end

local function remote_names(packages)
    local names = {}
    for _, pkg in ipairs(packages or {}) do
        local name = trim(read_field(pkg, "name") or read_field(pkg, "packageId"))
        if name ~= "" then
            local bare = name:match("^([^@]+)@") or name
            names[#names + 1] = bare
        end
    end
    return names
end

local function local_project_target(paths, source_path)
    return join_path(paths.local_projects, basename(source_path))
end

local function remove_path_command(path)
    return "rm -rf " .. shell_quote(path)
end

local function copy_local_project_command(paths, source_path)
    local target = local_project_target(paths, source_path)
    return "mkdir -p " .. shell_quote(paths.local_projects)
        .. " && rm -rf " .. shell_quote(target)
        .. " && cp -R " .. shell_quote(source_path)
        .. " " .. shell_quote(target)
end

local function is_directory(context, path)
    local result = exec_run(context, "test -d " .. shell_quote(path))
    return result ~= nil and result.success == true
end

local function public_error(context, message)
    tx_failed(context, message)
    return false
end

local function ensure_ready(context, paths)
    local ok, message = ensure_quicklisp(context, paths)
    if not ok then
        return nil, message
    end
    return true, nil
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
    return { "Common Lisp", "Package Manager" }
end

function plugin.getMissingPackages(packages)
    if packages == nil or #packages == 0 then
        return {}
    end

    local paths = state_paths(nil, packages)
    if not path_exists(paths.setup) or not command_exists(nil, RUNNER_BINARY) then
        return packages
    end

    local listed = query_list(nil, paths)
    if listed == nil then
        return packages
    end

    local installed = {}
    for _, item in ipairs(listed or {}) do
        installed[lower(item.packageId or item.name or "")] = item
    end

    local outdated_items = query_outdated(nil, paths) or {}
    local outdated = {}
    for _, item in ipairs(outdated_items) do
        outdated[lower(item.packageId or item.name or "")] = true
    end

    local filtered = {}
    for _, pkg in ipairs(packages) do
        local action = lower(read_field(pkg, "action") or "install")
        local name = lower((trim(read_field(pkg, "name") or read_field(pkg, "packageId"))):match("^([^@]+)@") or trim(read_field(pkg, "name") or read_field(pkg, "packageId")))
        local present = installed[name] ~= nil
        if action == "remove" then
            if present then
                filtered[#filtered + 1] = pkg
            end
        elseif action == "update" then
            if outdated[name] then
                filtered[#filtered + 1] = pkg
            end
        elseif not present then
            filtered[#filtered + 1] = pkg
        end
    end

    return filtered
end

function plugin.install(context, packages)
    local paths = state_paths(context, packages)
    local ready, message = ensure_ready(context, paths)
    if not ready then
        return public_error(context, message)
    end

    local names = remote_names(packages)
    if #names == 0 then
        tx_success(context)
        return true
    end

    begin_step(context, "install quicklisp systems")
    local _, error_message = mutate_quickload(context, paths, "install", names)
    if error_message ~= nil then
        return public_error(context, error_message)
    end

    emit_event(context, "installed", packages)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    local paths = state_paths(context, {})
    local ready, message = ensure_ready(context, paths)
    if not ready then
        return public_error(context, message)
    end

    local source_path = expand_runtime_placeholders(path)
    if trim(source_path) == "" then
        return public_error(context, "local Quicklisp project path missing")
    end
    if not is_directory(context, source_path) then
        return public_error(context, "local Quicklisp project directory not found: " .. source_path)
    end

    begin_step(context, "install local quicklisp project")
    local copy_result = exec_run(context, copy_local_project_command(paths, source_path))
    if copy_result == nil or not copy_result.success then
        return public_error(context, first_non_empty(copy_result and copy_result.stderr, copy_result and copy_result.stdout, "failed to copy local quicklisp project"))
    end

    local _, register_error = mutate_register_local(context, paths)
    if register_error ~= nil then
        return public_error(context, register_error)
    end

    emit_event(context, "installed", { path = source_path, localTarget = true, packageType = "common-lisp-system" })
    tx_success(context)
    return true
end

function plugin.remove(context, packages)
    local paths = state_paths(context, packages)
    local ready, message = ensure_ready(context, paths)
    if not ready then
        return public_error(context, message)
    end

    begin_step(context, "remove quicklisp systems")
    local remote = {}
    local local_removed = false

    for _, pkg in ipairs(packages or {}) do
        local name = (trim(read_field(pkg, "name") or read_field(pkg, "packageId"))):match("^([^@]+)@") or trim(read_field(pkg, "name") or read_field(pkg, "packageId"))
        if name ~= "" then
            local info, info_error = query_info(context, paths, name)
            if info_error ~= nil then
                return public_error(context, info_error)
            end
            local extra = type(info.extraFields) == "table" and info.extraFields or {}
            if info.installed and extra.localProject == "true" and non_empty(info.sourcePath) ~= nil then
                local remove_result = exec_run(context, remove_path_command(info.sourcePath))
                if remove_result == nil or not remove_result.success then
                    return public_error(context, first_non_empty(remove_result and remove_result.stderr, remove_result and remove_result.stdout, "failed to remove local quicklisp project"))
                end
                local_removed = true
            elseif info.installed then
                remote[#remote + 1] = name
            end
        end
    end

    if #remote > 0 then
        local _, remove_error = mutate_uninstall(context, paths, "remove", remote)
        if remove_error ~= nil then
            return public_error(context, remove_error)
        end
    end

    if local_removed then
        local _, register_error = mutate_register_local(context, paths)
        if register_error ~= nil then
            return public_error(context, register_error)
        end
    end

    emit_event(context, "deleted", packages)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local paths = state_paths(context, packages)
    local ready, message = ensure_ready(context, paths)
    if not ready then
        return public_error(context, message)
    end

    begin_step(context, "update quicklisp dist")
    local body = {
        "(ql:update-dist \"quicklisp\" :prompt nil)",
    }
    local names = remote_names(packages)
    if #names > 0 then
        body[#body + 1] = "(dolist (name " .. lisp_string_list(names) .. ")"
        body[#body + 1] = "  (ql:quickload name :silent t :prompt nil))"
    end

    local _, error_message = run_lisp_script(context, paths, "update", body)
    if error_message ~= nil then
        return public_error(context, error_message)
    end

    emit_event(context, "updated", packages or {})
    tx_success(context)
    return true
end

function plugin.list(context)
    local paths = state_paths(context, {})
    local ready, message = ensure_ready(context, paths)
    if not ready then
        log_warn(context, message)
        local empty = {}
        emit_event(context, "listed", empty)
        return empty
    end

    local items, error_message = query_list(context, paths)
    if items == nil then
        log_warn(context, error_message)
        items = {}
    end

    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local paths = state_paths(context, {})
    local ready, message = ensure_ready(context, paths)
    if not ready then
        log_warn(context, message)
        local empty = {}
        emit_event(context, "outdated", empty)
        return empty
    end

    local items, error_message = query_outdated(context, paths)
    if items == nil then
        log_warn(context, error_message)
        items = {}
    end

    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
    if query == "" then
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local paths = state_paths(context, {})
    local ready, message = ensure_ready(context, paths)
    if not ready then
        log_warn(context, message)
        local empty = {}
        emit_event(context, "searched", empty)
        return empty
    end

    local items, error_message = query_search(context, paths, query)
    if items == nil then
        log_warn(context, error_message)
        items = {}
    end

    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local target = trim(name or read_field(context, "prompt") or read_field(read_field(context, "request") or {}, "prompt") or "")
    if target == "" then
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    target = target:match("^([^@]+)@") or target
    local paths = state_paths(context, {})
    local ready, message = ensure_ready(context, paths)
    if not ready then
        log_warn(context, message)
        local empty = {}
        emit_event(context, "informed", empty)
        return empty
    end

    local item, error_message = query_info(context, paths, target)
    if item == nil then
        log_warn(context, error_message)
        item = {}
    end

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    if package == nil then
        return nil
    end

    local name = trim(read_field(package, "name") or read_field(package, "packageId"))
    if name == "" then
        return nil
    end

    local info = plugin.info(context, name)
    if type(info) == "table" and next(info) ~= nil then
        return info
    end

    local results = plugin.search(context, name)
    for _, item in ipairs(results or {}) do
        if lower(item.packageId or item.name or "") == lower(name:match("^([^@]+)@") or name) then
            return item
        end
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
        capabilities = { "exec", "network", "filesystem.write" },
        ecosystemScopes = { "quicklisp", "common-lisp" },
        writeScopes = {
            "plugin-data:q/quicklisp/.reqpack-data",
            {
                path = "ReqPack data root + /quicklisp",
                reason = "shared Quicklisp home, bootstrap files, local-projects cache, and generated batch scripts",
            },
        },
        networkScopes = { "beta.quicklisp.org" },
        privilegeLevel = "user",
        purlType = "generic",
        versionComparatorProfile = "lexicographic",
    }
end

return plugin
