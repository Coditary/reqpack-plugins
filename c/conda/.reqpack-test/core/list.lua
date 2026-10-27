return {
  name = "conda list installed packages",
  request = {
    action = "list",
    system = "conda",
  },
  fakeExec = {
    {
      match = "command -v 'conda' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "conda info --json",
      exitCode = 0,
      stdout = [[{"root_prefix":"/opt/conda"}]],
      stderr = "",
      success = true,
    },
    {
      match = "conda list --json --prefix '/opt/conda'",
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
