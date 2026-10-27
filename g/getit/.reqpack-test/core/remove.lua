return {
  name = "getit remove package",
  request = {
    action = "remove",
    system = "getit",
    packages = {
      { name = "VirtualTreeview_by_JamSoftware-13-8.3" },
    },
  },
  fakeExec = {
    {
      match = "command -v 'GetItCmd.exe' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "'GetItCmd.exe' -u=VirtualTreeview_by_JamSoftware-13-8.3",
      exitCode = 0,
      stdout = "Removed VirtualTreeview_by_JamSoftware-13-8.3\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
