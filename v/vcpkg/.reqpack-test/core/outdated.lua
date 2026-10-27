return {
  name = "vcpkg outdated packages",
  request = {
    action = "outdated",
    system = "vcpkg",
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
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg update --classic",
      exitCode = 0,
      stdout = "Using local portfile versions. To update local portfiles, use `git pull`.\nThe following packages differ from their port versions:\n        zlib:x64-linux 1.3.0 -> 1.3.1\n",
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
      stdout = [[{"results":{"zlib":{"name":"zlib","version-string":"1.3.1","description":"A compression library","homepage":"https://zlib.net","dependencies":[]}}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "zlib",
    resultVersion = "1.3.0",
  }
}
