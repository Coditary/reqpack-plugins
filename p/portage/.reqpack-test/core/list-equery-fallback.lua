return {
  name = "portage list installed packages via equery fallback",
  request = {
    action = "list",
    system = "portage",
  },
  fakeExec = {
    {
      match = "command -v 'emerge' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'qlist' >/dev/null 2>&1",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "command -v 'equery' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C equery -q list '*'",
      exitCode = 0,
      stdout = "sys-apps/portage-3.0.67\nwww-client/firefox-128.0\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'qlist' >/dev/null 2>&1",
      "command -v 'equery' >/dev/null 2>&1",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C equery -q list '*'",
    },
    resultCount = 2,
    resultName = "sys-apps/portage",
    resultVersion = "3.0.67",
    events = { "listed" },
  }
}
