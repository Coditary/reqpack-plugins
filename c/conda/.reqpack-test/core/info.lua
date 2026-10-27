return {
  name = "conda info merges installed and remote",
  request = {
    action = "info",
    system = "conda",
    prompt = "zlib",
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
      stdout = [=[[{"name":"zlib","version":"1.3.1","channel":"conda-forge","build_string":"h4ab18f5_1","build_number":1,"subdir":"linux-64"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "conda search --info --json --channel 'conda-forge' --subdir 'linux-64' 'zlib'",
      exitCode = 0,
      stdout = [=[{"zlib":[{"name":"zlib","version":"1.3.2","channel":"conda-forge","build":"h25fd6f3_2","build_string":"h25fd6f3_2","build_number":2,"subdir":"linux-64","license":"Zlib","url":"https://conda.anaconda.org/conda-forge/linux-64/zlib-1.3.2-h25fd6f3_2.conda","depends":["libzlib"],"summary":"Compression library","description":"Compression library"}]}]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed", "informed" },
    eventPayloads = {
      informed = "{dependencies=<lua-value>, description=Compression library, extraFields=<lua-value>, installed=true, latestVersion=1.3.2, license=Zlib, name=zlib, packageId=conda-forge/zlib, packageType=conda, repository=conda-forge, sourceUrl=https://conda.anaconda.org/conda-forge/linux-64/zlib-1.3.2-h25fd6f3_2.conda, status=outdated, summary=Compression library, type=package, version=1.3.1}",
    },
    resultCount = 1,
    resultName = "zlib",
    resultVersion = "1.3.1",
  }
}
