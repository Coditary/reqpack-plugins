return {
  name = "nix bootstrap existing store",
  environment = {
    REQPACK_NIX_INSTALLER_URL = "file://${caseDir}/../fixtures/nix-installer-stub.sh",
    REQPACK_NIX_INSTALLER_PATH = "${fixtureRoot}/nix-installer.sh",
  },
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
      match = "sh '${fixtureRoot}/nix-installer.sh' --daemon",
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
      "sh '${fixtureRoot}/nix-installer.sh' --daemon",
      "'/nix/var/nix/profiles/default/bin/nix' --extra-experimental-features 'nix-command flakes' --version >/dev/null 2>&1",
      "'/nix/var/nix/profiles/default/bin/nix' --extra-experimental-features 'nix-command flakes' profile install 'nixpkgs#delta'"
    },
    events = { "installed", "success" },
  }
}
