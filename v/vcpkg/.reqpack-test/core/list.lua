return {
  name = "vcpkg list installed packages",
  request = {
    action = "list",
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
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg list --classic --x-full-desc",
      exitCode = 0,
      stdout = "zlib:x64-linux 1.3.1 A compression library\nfmt:x64-linux 10.2.1 Formatting library for C++\n",
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
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg x-package-info --x-json zlib fmt",
      exitCode = 0,
      stdout = [[{"results":{"zlib":{"name":"zlib","version-string":"1.3.1","description":"A compression library","homepage":"https://zlib.net","dependencies":[]},"fmt":{"name":"fmt","version-string":"10.2.1","description":"Formatting library for C++","homepage":"https://fmt.dev","dependencies":[]}}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "zlib",
    resultVersion = "1.3.1",
  }
}
