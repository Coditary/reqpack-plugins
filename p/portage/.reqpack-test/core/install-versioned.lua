return {
  name = "portage install exact atom with doas",
  request = {
    action = "install",
    system = "portage",
    packages = {
      { name = "www-client/firefox", version = "128.0" }
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
      stdout = "1000\n",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'doas' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "doas -n emerge --info >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "doas -n emerge --quiet-build=y --color=n -- '=www-client/firefox-128.0'",
      exitCode = 0,
      stdout = "emerging (1 of 1) =www-client/firefox-128.0\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "id -u",
      "command -v 'doas' >/dev/null 2>&1",
      "doas -n emerge --info >/dev/null 2>&1",
      "doas -n emerge --quiet-build=y --color=n -- '=www-client/firefox-128.0'",
    },
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
