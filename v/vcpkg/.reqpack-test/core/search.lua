return {
  name = "vcpkg search packages",
  request = {
    action = "search",
    system = "vcpkg",
    prompt = "zlib",
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
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg search --x-full-desc zlib",
      exitCode = 0,
      stdout = "miniz 3.0.2 Single C source file zlib-replacement library\nzlib 1.3.1 A compression library\n",
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
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg x-package-info --x-json miniz zlib",
      exitCode = 0,
      stdout = [[{"results":{"miniz":{"name":"miniz","version-string":"3.0.2","description":"Single C source file zlib-replacement library","homepage":"https://github.com/richgel999/miniz","dependencies":[]},"zlib":{"name":"zlib","version-string":"1.3.1","description":"A compression library","homepage":"https://zlib.net","dependencies":[]}}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "miniz",
    resultVersion = "3.0.2",
  }
}
