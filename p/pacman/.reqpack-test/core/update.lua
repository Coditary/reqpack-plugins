return {
  name = "pacman update",
  request = {
    action = "update",
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
      match = "LC_ALL=C pacman -S --noconfirm curl",
      exitCode = 0,
      stdout = "update ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "LC_ALL=C pacman -S --noconfirm curl"
    },
    stdout = {
      "update ok\n"
    },
    events = { "updated", "success" },
  }
}
