return {
  name = "nix install local",
  request = {
    action = "install",
    system = "nix",
    localPath = "/tmp/delta-flake",
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
      match = "nix --extra-experimental-features 'nix-command flakes' profile install '/tmp/delta-flake'",
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
      "nix --extra-experimental-features 'nix-command flakes' profile install '/tmp/delta-flake'"
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=/tmp/delta-flake}",
    },
  }
}
