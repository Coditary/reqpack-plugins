return {
  name = "foundry remove dependency",
  request = {
    action = "remove",
    system = "foundry",
    packages = {
      { name = "foundry-rs/forge-std" },
    },
  },
  fakeExec = {
    {
      match = "command -v 'forge' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "forge remove --root . foundry-rs/forge-std",
      exitCode = 0,
      stdout = "removed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'forge' >/dev/null 2>&1",
      "forge remove --root . foundry-rs/forge-std",
    },
    events = { "deleted", "success" },
  },
}
