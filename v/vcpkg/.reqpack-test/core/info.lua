return {
  name = "vcpkg info package",
  request = {
    action = "info",
    system = "vcpkg",
    prompt = "zlib",
  },
  fixtureRoot = "../fixtures-info",
  fixtureFiles = {
    {
      path = "data/cppcache/views/by-source/vcpkg/zlib__x64-linux/current.json",
      content = [[{"artifact_id":"vcpkg/cpp-package/zlib__x64-linux@abi123","artifact_path":"${fixtureRoot}/data/cppcache/artifacts/vcpkg/cpp-package/zlib__x64-linux@abi123","prefix_path":"${fixtureRoot}/data/cppcache/prefixes/vcpkg/cpp-package/zlib__x64-linux@abi123","source_path":"${fixtureRoot}/root/installed"}]],
    },
  },
  environment = {
    XDG_DATA_HOME = "${fixtureRoot}/data",
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    {
      match = "command -v vcpkg 2>/dev/null",
      exitCode = 0,
      stdout = "/usr/local/bin/vcpkg\n",
      stderr = "",
      success = true,
    },
    {
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg x-package-info --x-json zlib",
      exitCode = 0,
      stdout = [[{"results":{"zlib":{"name":"zlib","version-string":"1.3.1","description":"A compression library","homepage":"https://zlib.net","dependencies":["vcpkg-cmake"],"abi":"abi123"}}}]],
      stderr = "",
      success = true,
    },
    {
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg list --classic --x-full-desc",
      exitCode = 0,
      stdout = "zlib:x64-linux 1.3.0 A compression library\n",
      stderr = "",
      success = true,
    },
    {
      match = "command -v vcpkg 2>/dev/null",
      exitCode = 0,
      stdout = "/usr/local/bin/vcpkg\n",
      stderr = "",
      success = true,
    },
    {
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg x-package-info --x-json zlib",
      exitCode = 0,
      stdout = [[{"results":{"zlib":{"name":"zlib","version-string":"1.3.1","description":"A compression library","homepage":"https://zlib.net","dependencies":["vcpkg-cmake"],"abi":"abi123"}}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "zlib",
    resultVersion = "1.3.0",
  }
}
