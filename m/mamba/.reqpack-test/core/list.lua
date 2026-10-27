return {
  name = "mamba list installed packages",
  request = {
    action = "list",
    system = "mamba",
  },
  fakeExec = {
    {
      match = "command -v 'mamba' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mamba list --json --prefix '/'",
      exitCode = 0,
      stdout = [=[[{"name":"python","version":"3.12.9","channel":"conda-forge","build_string":"h123_0","build_number":0,"subdir":"linux-64"},{"name":"zlib","version":"1.3.1","channel":"conda-forge","build_string":"hb9d3cd8_2","build_number":2,"subdir":"linux-64"}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "python",
    resultVersion = "3.12.9",
  }
}
