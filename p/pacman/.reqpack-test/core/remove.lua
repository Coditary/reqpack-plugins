return {
  name = "pacman remove",
  request = {
    action = "remove",
    system = "pacman",
    packages = {
      { name = "curl" }
    },
  },
  fakeExec = {
    {
      match = "command -v pacman >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C pacman -R --noconfirm curl",
      exitCode = 0,
      stdout = "remove ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "LC_ALL=C pacman -R --noconfirm curl"
    },
    stdout = {
      "remove ok\n"
    },
    events = { "deleted", "success" },
  }
}
