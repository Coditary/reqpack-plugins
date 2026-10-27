return {
  name = "portage install local tbz2 with sudo fallback",
  request = {
    action = "install",
    system = "portage",
    localPath = "/tmp/firefox-128.0.tbz2",
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
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "command -v 'sudo' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "sudo -n emerge --info >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "sudo -n emerge --usepkg --quiet-build=y --color=n -- '/tmp/firefox-128.0.tbz2'",
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
      "command -v 'doas' >/dev/null 2>&1",
      "command -v 'sudo' >/dev/null 2>&1",
      "sudo -n emerge --info >/dev/null 2>&1",
      "sudo -n emerge --usepkg --quiet-build=y --color=n -- '/tmp/firefox-128.0.tbz2'",
    },
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
