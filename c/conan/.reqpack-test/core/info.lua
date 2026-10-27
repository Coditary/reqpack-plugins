return {
  name = "conan info prefers local cache",
  request = {
    action = "info",
    system = "conan",
    prompt = "zlib/1.3.1",
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
      match = "'conan' 'list' '--format=json' '-c' 'zlib/1.3.1'",
      exitCode = 0,
      stdout = [[{"Local Cache":{"zlib/1.3.1":{"revisions":{"rrev123":{"timestamp":1780000001}}}}}]],
      stderr = "",
      success = true,
    },
    {
      match = "'conan' 'cache' 'path' '--format=json' 'zlib/1.3.1#rrev123'",
      exitCode = 0,
      stdout = [[{"cache_path":"/home/test/.conan2/p/zlibabc/e","folder":"exports","reference":"zlib/1.3.1#rrev123"}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'conan' >/dev/null 2>&1",
      "'conan' 'list' '--format=json' '-c' 'zlib/1.3.1'",
      "'conan' 'cache' 'path' '--format=json' 'zlib/1.3.1#rrev123'",
    },
    events = { "informed" },
    resultCount = 1,
    resultName = "zlib",
    resultVersion = "1.3.1",
  }
}
