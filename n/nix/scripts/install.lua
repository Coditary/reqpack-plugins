-- Materialize hook: ensure a usable nix CLI exists before the wrapper is used.
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

if exec_ok("command -v nix >/dev/null 2>&1") then
    return exec_ok("nix --extra-experimental-features 'nix-command flakes' --version >/dev/null 2>&1")
end

if not exec_ok("command -v curl >/dev/null 2>&1") then
    return false
end

if exec_ok("test -d /nix/store") and not exec_ok("test -w /nix/store") then
    return false
end

return exec_ok(
    "curl -L "
        .. shell_quote("https://nixos.org/nix/install")
        .. " | sh -s -- --no-daemon --yes"
)
