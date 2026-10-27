return {
  name = "pacman install local",
  request = {
    action = "install",
    system = "pacman",
    localPath = "/tmp/curl-8.8.0-1-x86_64.pkg.tar.zst",
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
      match = "LC_ALL=C pacman -U --noconfirm /tmp/curl-8.8.0-1-x86_64.pkg.tar.zst",
      exitCode = 0,
      stdout = "local install ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=/tmp/curl-8.8.0-1-x86_64.pkg.tar.zst}",
      success = "ok",
    },
  }
}
