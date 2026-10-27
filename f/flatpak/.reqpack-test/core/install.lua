return {
  name = "flatpak install remote ref",
  request = {
    action = "install",
    system = "flatpak",
    packages = {
      { action = "install", name = "org.mozilla.firefox", version = "124.0" }
    },
  },
  fakeExec = {
    {
      match = "command -v flatpak >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "flatpak list --user --columns=application,ref",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "flatpak install --user --noninteractive --assumeyes --or-update 'org.mozilla.firefox'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "flatpak install --user --noninteractive --assumeyes --or-update 'org.mozilla.firefox'" },
    stdout = { "installed\n" },
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
