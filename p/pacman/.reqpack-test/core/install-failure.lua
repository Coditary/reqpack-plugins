return {
  name = "pacman install failure",
  request = {
    action = "install",
    system = "pacman",
    packages = {
      { name = "missing-curl" }
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
      match = "LC_ALL=C pacman -S --needed --noconfirm missing-curl",
      exitCode = 1,
      stdout = "",
      stderr = "error: target not found: missing-curl\n",
      success = false,
    },
  },
  expect = {
    success = false,
    commands = { "LC_ALL=C pacman -S --needed --noconfirm missing-curl" },
    stderr = { "error: target not found: missing-curl\n" },
    events = { "failed" },
    eventPayloads = {
      failed = "pacman install failed",
    },
  }
}
