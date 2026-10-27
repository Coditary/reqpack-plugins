return {
  name = "nix outdated",
  request = {
    action = "outdated",
    system = "nix",
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
      match = "nix --extra-experimental-features 'nix-command flakes' profile list --json",
      exitCode = 0,
      stdout = "{\"version\":3,\"elements\":{\"delta\":{\"active\":true,\"attrPath\":\"legacyPackages.x86_64-linux.delta\",\"originalUrl\":\"flake:nixpkgs\",\"storePaths\":[\"/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-delta-1.0.0\"],\"url\":\"github:NixOS/nixpkgs/123\"}}}\n",
      stderr = "",
      success = true,
    },
    {
      match = "nix --extra-experimental-features 'nix-command flakes' search --json 'nixpkgs' '^delta$'",
      exitCode = 0,
      stdout = "{\"legacyPackages.x86_64-linux.delta\":{\"pname\":\"delta\",\"version\":\"2.0.0\",\"description\":\"Delta package\",\"meta\":{\"homepage\":\"https://example.com/delta\"}}}\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    commands = {
      "command -v 'nix' >/dev/null 2>&1",
      "nix --extra-experimental-features 'nix-command flakes' profile list --json",
      "nix --extra-experimental-features 'nix-command flakes' search --json 'nixpkgs' '^delta$'"
    },
    events = { "outdated" },
    resultCount = 1,
    resultName = "delta",
    resultVersion = "1.0.0",
  }
}
