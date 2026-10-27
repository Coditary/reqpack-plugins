return {
  name = "conan list local cache",
  request = {
    action = "list",
    system = "conan",
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
      match = "'conan' 'list' '--format=json' '-c' '*'",
      exitCode = 0,
      stdout = [[{"Local Cache":{"fmt/10.2.1":{"revisions":{"fmtrev":{"timestamp":1780000000}}},"zlib/1.3.1":{"revisions":{"zrev":{"timestamp":1780000001,"packages":{"pkg123":{"revisions":{"prev456":{"timestamp":1780000002}},"info":{"settings":{"arch":"x86_64","os":"Linux"},"options":{"shared":"False"}}}}}}}}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'conan' >/dev/null 2>&1",
      "'conan' 'list' '--format=json' '-c' '*'"
    },
    events = { "listed" },
    resultCount = 3,
    resultName = "fmt",
    resultVersion = "10.2.1",
  }
}
