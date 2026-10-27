return {
  name = "portage install repo package",
  request = {
    action = "install",
    system = "portage",
    packages = {
      { name = "www-client/firefox" }
    },
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
      match = "id -u",
      exitCode = 0,
      stdout = "0\n",
      stderr = "",
      success = true,
    },
    {
      match = "emerge --quiet-build=y --color=n -- 'www-client/firefox'",
      exitCode = 0,
      stdout = "emerging (1 of 1) www-client/firefox\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "id -u",
      "emerge --quiet-build=y --color=n -- 'www-client/firefox'",
    },
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
