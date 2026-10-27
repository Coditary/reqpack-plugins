return {
  name = "portage install local gpkg",
  request = {
    action = "install",
    system = "portage",
    localPath = "/tmp/firefox-128.0.gpkg.tar",
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
      match = "emerge --usepkg --quiet-build=y --color=n -- '/tmp/firefox-128.0.gpkg.tar'",
      exitCode = 0,
      stdout = "emerging binary package\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "id -u",
      "emerge --usepkg --quiet-build=y --color=n -- '/tmp/firefox-128.0.gpkg.tar'",
    },
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
