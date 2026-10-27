return {
  name = "futhark update upgrades and syncs",
  request = {
    action = "update",
    system = "futhark",
  },
  fakeExec = {
    {
      match = "command -v 'futhark' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "futhark pkg upgrade",
      exitCode = 0,
      stdout = "Remember to run 'futhark pkg sync'.\n",
      stderr = "",
      success = true,
    },
    {
      match = "futhark pkg sync",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'futhark' >/dev/null 2>&1",
      "futhark pkg upgrade",
      "futhark pkg sync",
    },
    events = { "updated", "success" },
  },
}
