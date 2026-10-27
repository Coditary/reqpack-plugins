return {
  name = "fan list installed pods",
  request = {
    action = "list",
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
  },
  expect = {
    success = true,
    commands = {
      "fanr env '*'",
    },
    events = { "listed" },
    resultCount = 2,
    resultName = "web",
    resultVersion = "1.0.79",
  }
}
