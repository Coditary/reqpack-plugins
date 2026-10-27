return {
  name = "longtalk remove installed pack",
  request = {
    action = "remove",
    system = "longtalk",
    packages = {
      { action = "remove", name = "talkshow::lflat" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'swilgt' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "env LOGTALKPACKS=\"$HOME/logtalk_packs\" swilgt -q -g \"set_logtalk_flag(report,warnings),logtalk_load(packs(loader)),(packs::uninstall(lflat,[])),halt\"",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
