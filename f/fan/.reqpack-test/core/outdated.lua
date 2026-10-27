return {
  name = "fan outdated compares installed vs repo",
  request = {
    action = "outdated",
    system = "fan",
  },
  fakeExec = {
    {
      match = "fanr env '*'",
      exitCode = 0,
      stdout = "web\n  Web APIs\n  1.0.79 (30-May-2026, 120KB)\n\nutil\n  Utility APIs\n  1.0.82 (29-May-2026, 95KB)\n",
      stderr = "",
      success = true,
    },
    {
      match = "fanr query -n 1 'web'",
      exitCode = 0,
      stdout = "web\n  Web APIs\n  1.0.80 (31-May-2026, 121KB)\n",
      stderr = "",
      success = true,
    },
    {
      match = "fanr query -n 1 'util'",
      exitCode = 0,
      stdout = "util\n  Utility APIs\n  1.0.82 (29-May-2026, 95KB)\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "fanr env '*'",
      "fanr query -n 1 'web'",
      "fanr query -n 1 'util'",
    },
    events = { "outdated" },
    resultCount = 1,
    resultName = "web",
    resultVersion = "1.0.80",
  }
}
