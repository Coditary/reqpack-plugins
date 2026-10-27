return {
  name = "mamba outdated packages",
  request = {
    action = "outdated",
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
      stdout = [=[[{"name":"zlib","version":"1.3.1","channel":"conda-forge","build_string":"h4ab18f5_1","build_number":1,"subdir":"linux-64"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "mamba search --json --prefix '/' --channel 'conda-forge' 'zlib'",
      exitCode = 0,
      stdout = [=[{"query":{"query":"zlib","type":"search"},"result":{"status":"OK","msg":"","pkgs":[{"name":"zlib","version":"1.3.2","channel":"conda-forge","build":"h25fd6f3_2","build_string":"h25fd6f3_2","build_number":2,"subdir":"linux-64","license":"Zlib","url":"https://conda.anaconda.org/conda-forge/linux-64/zlib-1.3.2-h25fd6f3_2.conda","depends":["libzlib"]}]}}]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "zlib",
    resultVersion = "1.3.1",
  }
}
