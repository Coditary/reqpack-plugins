return {
  name = "foundry update dependency",
  request = {
    action = "update",
    system = "foundry",
    flags = { "recursive" },
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
      match = "forge update --root . --recursive foundry-rs/forge-std",
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'forge' >/dev/null 2>&1",
      "forge update --root . --recursive foundry-rs/forge-std",
    },
    events = { "updated", "success" },
  },
}
