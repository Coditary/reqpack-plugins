return {
  name = "mamba search channel scoped",
  request = {
    action = "search",
    system = "mamba",
    prompt = "channel:conda-forge zlib",
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
      match = "mamba search --json --prefix '/' --channel 'conda-forge' 'zlib'",
      exitCode = 0,
      stdout = [=[{"query":{"query":"zlib","type":"search"},"result":{"status":"OK","msg":"","pkgs":[{"name":"zlib","version":"1.3.2","channel":"conda-forge","build":"h25fd6f3_2","build_string":"h25fd6f3_2","build_number":2,"subdir":"linux-64","license":"Zlib","url":"https://conda.anaconda.org/conda-forge/linux-64/zlib-1.3.2-h25fd6f3_2.conda","depends":["libzlib"]},{"name":"zlib","version":"1.3.1","channel":"conda-forge","build":"hb9d3cd8_2","build_string":"hb9d3cd8_2","build_number":2,"subdir":"linux-64","license":"Zlib","url":"https://conda.anaconda.org/conda-forge/linux-64/zlib-1.3.1-hb9d3cd8_2.conda","depends":["libzlib"]}]}}]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'mamba' >/dev/null 2>&1",
      "mamba search --json --prefix '/' --channel 'conda-forge' 'zlib'"
    },
    events = { "searched" },
    resultCount = 1,
    resultName = "zlib",
    resultVersion = "1.3.2",
  }
}
