return {
  name = "texlive update all packages",
  request = {
    action = "update",
    system = "texlive",
  },
  fakeExec = {
    {
      match = "command -v 'tlmgr' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "tlmgr 'update' '--all'",
      exitCode = 0,
      stdout = "updated all\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'tlmgr' >/dev/null 2>&1",
      "tlmgr 'update' '--all'"
    },
    stdout = { "updated all\n" },
    events = { "updated", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
