-- Materialize hook: ensure a usable nix CLI exists before the wrapper is used.
local NIX_INSTALLER_URL = "https://nixos.org/nix/install"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function exec_ok(command)
    if type(reqpack) ~= "table" or type(reqpack.exec) ~= "table" or type(reqpack.exec.run) ~= "function" then
        return false
    end
    local result = reqpack.exec.run(command)
    return result ~= nil and result.success == true
end

local function detect_os_family()
    local uname = reqpack.exec.run("uname -s 2>/dev/null")
    if uname ~= nil and uname.success then
        local value = trim(uname.stdout):lower()
        if value == "darwin" then
            return "darwin"
        end
        if value == "linux" then
            return "linux"
        end
    end
    if exec_ok("cmd /c ver >/dev/null 2>&1") then
        return "windows"
    end
    return "linux"
end

local function nix_installer_command()
    local curl = "curl --proto '=https' --tlsv1.2 -L " .. shell_quote(NIX_INSTALLER_URL)
    if detect_os_family() == "darwin" then
        return curl .. " | sh"
    end
    return curl .. " | sh -s -- --daemon"
end

local function nix_on_path_works()
    if not exec_ok("command -v nix >/dev/null 2>&1") then
        return false
    end
    return exec_ok("nix --extra-experimental-features 'nix-command flakes' --version >/dev/null 2>&1")
end

if nix_on_path_works() then
    return true
end

if exec_ok("test -x \"$HOME/.nix-profile/bin/nix\"") then
    return exec_ok(
        "\"$HOME/.nix-profile/bin/nix\" --extra-experimental-features 'nix-command flakes' --version >/dev/null 2>&1"
    )
end

if exec_ok("test -x '/nix/var/nix/profiles/default/bin/nix'") then
    return exec_ok(
        "'/nix/var/nix/profiles/default/bin/nix' --extra-experimental-features 'nix-command flakes' --version >/dev/null 2>&1"
    )
end

if not exec_ok("command -v curl >/dev/null 2>&1") then
    return false
end

return exec_ok(nix_installer_command())
