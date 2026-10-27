return {
  name = "pacman install",
  request = {
    action = "install",
    system = "pacman",
    packages = {
      { name = "curl", version = "8.8.0-1" }
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
      match = "LC_ALL=C pacman -S --needed --noconfirm curl",
      exitCode = 0,
      stdout = "install ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "LC_ALL=C pacman -S --needed --noconfirm curl"
    },
    stdout = {
      "install ok\n"
    },
    events = { "installed", "success" },
  }
}
