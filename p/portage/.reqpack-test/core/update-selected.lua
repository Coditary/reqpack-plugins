return {
  name = "portage update selected package",
  request = {
    action = "update",
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
      match = "emerge --update --quiet-build=y --color=n -- 'www-client/firefox'",
      exitCode = 0,
      stdout = "updating firefox\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "id -u",
      "emerge --update --quiet-build=y --color=n -- 'www-client/firefox'",
    },
    events = { "updated", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
