-- Materialize hook: ensure a usable nix CLI exists before the wrapper is used.
local NIX_INSTALLER_URL = "https://nixos.org/nix/install"

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

local installer_args = "--no-daemon --yes"
if exec_ok("test -d /nix/store") and not exec_ok("test -w /nix/store") then
    installer_args = "--yes"
end

return exec_ok("curl -L " .. shell_quote(NIX_INSTALLER_URL) .. " | sh -s -- " .. installer_args)
