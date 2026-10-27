return {
  name = "portage install without privilege helper fails clearly",
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
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
  },
  expect = {
    success = false,
    commands = {
      "id -u",
      "command -v 'doas' >/dev/null 2>&1",
      "command -v 'sudo' >/dev/null 2>&1",
    },
    events = { "failed" },
    eventPayloads = {
      failed = "portage write action requires root, doas -n, or sudo -n",
    },
  }
}
