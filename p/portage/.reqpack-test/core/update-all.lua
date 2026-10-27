return {
  name = "portage update all packages",
  request = {
    action = "update",
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
      match = "id -u",
      exitCode = 0,
      stdout = "0\n",
      stderr = "",
      success = true,
    },
    {
      match = "emerge --sync",
      exitCode = 0,
      stdout = "sync complete\n",
      stderr = "",
      success = true,
    },
    {
      match = "emerge --update --deep --newuse --quiet-build=y --color=n @world",
      exitCode = 0,
      stdout = "world updated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "id -u",
      "emerge --sync",
      "emerge --update --deep --newuse --quiet-build=y --color=n @world",
    },
    events = { "updated", "success" },
    eventPayloads = {
      updated = "{}",
      success = "ok",
    },
  }
}
