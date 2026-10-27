return {
  name = "nimble search",
  request = {
    action = "search",
    system = "nimble",
    prompt = "jester",
  },
  fakeExec = {
    {
      match = "command -v nimble >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "nimble --accept --noColor refresh",
      exitCode = 1,
      stdout = "",
      stderr = "network warning\n",
      success = false,
    },
    {
      match = "nimble --noColor search 'jester'",
      exitCode = 0,
      stdout = "jester:\nurl:         https://github.com/dom96/jester\ntags:        web, framework\ndescription: Fast and pragmatic web framework\nlicense:     MIT\nwebsite:     https://github.com/dom96/jester\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "nimble --accept --noColor refresh",
      "nimble --noColor search 'jester'"
    },
    events = { "searched" },
    resultCount = 1,
    resultName = "jester",
  }
}
