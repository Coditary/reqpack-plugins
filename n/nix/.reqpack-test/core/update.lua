return {
  name = "nix update",
  request = {
    action = "update",
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
      match = "nix --extra-experimental-features 'nix-command flakes' profile list --json",
      exitCode = 0,
      stdout = "{\"version\":3,\"elements\":{\"delta\":{\"active\":true,\"attrPath\":\"legacyPackages.x86_64-linux.delta\",\"originalUrl\":\"flake:nixpkgs\",\"storePaths\":[\"/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-delta-1.0.0\"],\"url\":\"github:NixOS/nixpkgs/123\"}}}\n",
      stderr = "",
      success = true,
    },
    {
      match = "nix --extra-experimental-features 'nix-command flakes' search --json 'nixpkgs' '^delta$'",
      exitCode = 0,
      stdout = "{\"legacyPackages.x86_64-linux.delta\":{\"pname\":\"delta\",\"version\":\"2.0.0\",\"description\":\"Delta package\"}}\n",
      stderr = "",
      success = true,
    },
    {
      match = "nix --extra-experimental-features 'nix-command flakes' profile upgrade 'delta'",
      exitCode = 0,
      stdout = "upgraded\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    commands = {
      "command -v 'nix' >/dev/null 2>&1",
      "nix --extra-experimental-features 'nix-command flakes' profile list --json",
      "nix --extra-experimental-features 'nix-command flakes' search --json 'nixpkgs' '^delta$'",
      "nix --extra-experimental-features 'nix-command flakes' profile upgrade 'delta'"
    },
    events = { "updated", "success" },
  }
}
