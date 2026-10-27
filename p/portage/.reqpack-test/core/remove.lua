return {
  name = "portage remove package runs deselect then depclean",
  request = {
    action = "remove",
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
      match = "emerge --deselect --quiet-build=y --color=n -- 'www-client/firefox'",
      exitCode = 0,
      stdout = "deselecting firefox\n",
      stderr = "",
      success = true,
    },
    {
      match = "emerge --depclean --quiet-build=y --color=n",
      exitCode = 0,
      stdout = "depclean complete\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "id -u",
      "emerge --deselect --quiet-build=y --color=n -- 'www-client/firefox'",
      "emerge --depclean --quiet-build=y --color=n",
    },
    events = { "deleted", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
