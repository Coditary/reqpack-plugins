return {
  name = "fan search remote pods",
  request = {
    action = "search",
    system = "fan",
    prompt = "web",
  },
  fakeExec = {
    {
      match = "fanr query -n 1 'web'",
      exitCode = 0,
      stdout = "web\n  Web APIs\n  1.0.80 (31-May-2026, 121KB)\n\nwebmod\n  Wisp web module\n  1.0.5 (30-May-2026, 80KB)\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "fanr query -n 1 'web'",
    },
    events = { "searched" },
    resultCount = 2,
    resultName = "web",
    resultVersion = "1.0.80",
  }
}
