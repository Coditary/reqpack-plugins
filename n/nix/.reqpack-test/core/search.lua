return {
  name = "nix search",
  request = {
    action = "search",
    system = "nix",
    prompt = "delta",
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
      match = "nix --extra-experimental-features 'nix-command flakes' search --json 'nixpkgs' 'delta'",
      exitCode = 0,
      stdout = "{\"legacyPackages.x86_64-linux.delta\":{\"pname\":\"delta\",\"version\":\"1.0.0\",\"description\":\"Delta package\"}}\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    commands = {
      "command -v 'nix' >/dev/null 2>&1",
      "nix --extra-experimental-features 'nix-command flakes' search --json 'nixpkgs' 'delta'"
    },
    events = { "searched" },
    resultCount = 1,
    resultName = "delta",
    resultVersion = "1.0.0",
  }
}
