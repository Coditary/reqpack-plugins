return {
  name = "snap find packages",
  request = {
    action = "search",
    system = "snap",
    prompt = "vlc",
  },
  fakeExec = {
    {
      match = "command -v 'snap' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "snap find 'vlc'",
      exitCode = 0,
      stdout = "Name  Version  Publisher  Notes  Summary\nvlc   3.0.7    videolan*  -      The ultimate media player\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "vlc",
    resultVersion = "3.0.7",
  }
}
