return {
  name = "nix bootstrap existing store",
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
      match = "command -v 'curl' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl --proto '=https' --tlsv1.2 -L 'https://nixos.org/nix/install' | sh -s -- --daemon",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
    {
      match = "test -x '/nix/var/nix/profiles/default/bin/nix'",
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
      match = "'/nix/var/nix/profiles/default/bin/nix' --extra-experimental-features 'nix-command flakes' profile install 'nixpkgs#delta'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    commands = {
      "command -v 'nix' >/dev/null 2>&1",
      "test -x \"$HOME/.nix-profile/bin/nix\"",
      "test -x '/nix/var/nix/profiles/default/bin/nix'",
      "test -x '/run/current-system/sw/bin/nix'",
      "command -v 'curl' >/dev/null 2>&1",
      "curl --proto '=https' --tlsv1.2 -L 'https://nixos.org/nix/install' | sh -s -- --daemon",
      "'/nix/var/nix/profiles/default/bin/nix' --extra-experimental-features 'nix-command flakes' --version >/dev/null 2>&1",
      "'/nix/var/nix/profiles/default/bin/nix' --extra-experimental-features 'nix-command flakes' profile install 'nixpkgs#delta'"
    },
    events = { "installed", "success" },
  }
}
