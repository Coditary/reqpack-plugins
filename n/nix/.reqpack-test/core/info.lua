return {
  name = "nix info",
  request = {
    action = "info",
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
      match = "nix --extra-experimental-features 'nix-command flakes' search --json 'nixpkgs' '^delta$'",
      exitCode = 0,
      stdout = "{\"legacyPackages.x86_64-linux.delta\":{\"pname\":\"delta\",\"version\":\"1.0.0\",\"description\":\"Delta package\",\"meta\":{\"homepage\":\"https://example.com/delta\",\"longDescription\":\"Delta package long description\",\"license\":{\"shortName\":\"MIT\"},\"maintainers\":[\"delta@example.com\"],\"platforms\":[\"x86_64-linux\"],\"position\":\"pkgs/tools/delta.nix:12\"}}}\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    commands = {
      "command -v 'nix' >/dev/null 2>&1",
      "nix --extra-experimental-features 'nix-command flakes' search --json 'nixpkgs' '^delta$'"
    },
    events = { "informed" },
    resultCount = 1,
    resultName = "delta",
    resultVersion = "1.0.0",
  }
}
