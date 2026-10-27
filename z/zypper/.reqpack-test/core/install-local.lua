return {
  name = "zypper install local rpm",
  request = {
    action = "install",
    system = "zypper",
    localPath = "/tmp/curl.rpm",
  },
  fakeExec = {
    {
      match = "command -v 'zypper' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "zypper --non-interactive install '/tmp/curl.rpm'",
      exitCode = 0,
      stdout = "Installing: curl.rpm\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=/tmp/curl.rpm}",
      success = "ok",
    },
  }
}
