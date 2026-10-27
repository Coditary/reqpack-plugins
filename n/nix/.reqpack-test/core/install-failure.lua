return {
  name = "nix install failure",
  request = {
    action = "install",
    system = "nix",
    packages = {
      { name = "delta" }
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
      exitCode = 1,
      stdout = "",
      stderr = "boom\n",
      success = false,
    }
  },
  expect = {
    success = false,
    commands = {
      "command -v 'nix' >/dev/null 2>&1",
      "nix --extra-experimental-features 'nix-command flakes' profile install 'nixpkgs#delta'"
    },
    events = { "failed" },
    eventPayloads = {
      failed = "nix install failed",
    },
  }
}
