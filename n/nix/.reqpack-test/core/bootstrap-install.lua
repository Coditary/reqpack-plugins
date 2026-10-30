return {
  name = "nix bootstrap install",
  request = {
    action = "install",
    system = "nix",
    packages = {
      { name = "delta", version = "1.0.0" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'nix' >/dev/null 2>&1",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "test -x \"$HOME/.nix-profile/bin/nix\"",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "test -x '/nix/var/nix/profiles/default/bin/nix'",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "test -x '/run/current-system/sw/bin/nix'",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "systemctl is-system-running >/dev/null 2>&1",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "nix-installer.sh",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
    {
      match = "test -x \"$HOME/.nix-profile/bin/nix\"",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "--version >/dev/null",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "\"$HOME/.nix-profile/bin/nix\" --extra-experimental-features 'nix-command flakes' profile install 'nixpkgs#delta'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
