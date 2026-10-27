return {
  name = "portage install local invalid extension",
  request = {
    action = "install",
    system = "portage",
    localPath = "/tmp/firefox.ebuild",
  },
  fakeExec = {
    {
      match = "command -v 'emerge' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = false,
    commands = {},
    events = { "failed" },
    eventPayloads = {
      failed = "installLocal only supports .gpkg.tar, .tbz2, and .xpak",
    },
  }
}
