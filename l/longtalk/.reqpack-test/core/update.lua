return {
  name = "longtalk update specific pack",
  request = {
    action = "update",
    system = "longtalk",
    packages = {
      { action = "update", name = "talkshow::lflat" }
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
      match = "env LOGTALKPACKS=\"$HOME/logtalk_packs\" swilgt -q -g \"set_logtalk_flag(report,warnings),logtalk_load(packs(loader)),(packs::update(lflat,[])),halt\"",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  },
}
