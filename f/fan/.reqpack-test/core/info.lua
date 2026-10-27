return {
  name = "fan info remote pod",
  request = {
    action = "info",
    system = "fan",
    prompt = "web",
  },
  fakeExec = {
    {
      match = "fanr query -n 5 'web'",
      exitCode = 0,
      stdout = "web\n  Web APIs\n  1.0.80 (31-May-2026, 121KB)\n  1.0.79 (30-May-2026, 120KB)\n  1.0.78 (29-May-2026, 119KB)\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "fanr query -n 5 'web'",
    },
    events = { "informed" },
    resultName = "web",
    resultVersion = "1.0.80",
  }
}
