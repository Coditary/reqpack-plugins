return {
  name = "nix install",
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
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "nix --extra-experimental-features 'nix-command flakes' profile install 'nixpkgs#delta'",
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
      "nix --extra-experimental-features 'nix-command flakes' profile install 'nixpkgs#delta'"
    },
    events = { "installed", "success" },
  }
}
