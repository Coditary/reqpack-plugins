return {
  name = "conan search remote recipes",
  request = {
    action = "search",
    system = "conan",
    prompt = "zlib/*",
  },
  fakeExec = {
    {
      match = "command -v 'conan' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "'conan' 'search' '--format=json' 'zlib/*'",
      exitCode = 0,
      stdout = [[{"conancenter":{"zlib/1.2.13":{},"zlib/1.3.1":{}}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'conan' >/dev/null 2>&1",
      "'conan' 'search' '--format=json' 'zlib/*'",
    },
    events = { "searched" },
    resultCount = 2,
    resultName = "zlib",
    resultVersion = "1.2.13",
  }
}
