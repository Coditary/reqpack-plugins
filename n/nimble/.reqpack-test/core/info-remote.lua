return {
  name = "nimble info remote exact match",
  request = {
    action = "info",
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
      match = "nimble --noColor list -i",
      exitCode = 0,
      stdout = "chronos  [4.0.0]\n",
      stderr = "",
      success = true,
    },
    {
      match = "nimble --accept --noColor refresh",
      exitCode = 0,
      stdout = "Success Package list downloaded.\n",
      stderr = "",
      success = true,
    },
    {
      match = "nimble --noColor search 'jester'",
      exitCode = 0,
      stdout = "jest:\nurl:         https://example.com/jest\ndescription: Wrong package\n\njester:\nurl:         https://github.com/dom96/jester\ntags:        web, framework\ndescription: Fast and pragmatic web framework\nlicense:     MIT\nwebsite:     https://github.com/dom96/jester\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "nimble --noColor list -i",
      "nimble --accept --noColor refresh",
      "nimble --noColor search 'jester'"
    },
    events = { "informed" },
    resultCount = 1,
    resultName = "jester",
  }
}
