return {
  name = "spm search registry",
  request = {
    action = "search",
    system = "spm",
    prompt = "test",
  },
  fakeExec = {
    {
      match = "command -v spm >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "spm list --json",
      exitCode = 0,
      stdout = [[{"skills":[],"total":0}]],
      stderr = "",
      success = true,
    },
    {
      match = "spm search test --json",
      exitCode = 0,
      stdout = [[{"results":[{"name":"@github/polyglot-test-agent","version":"1.0.0","description":"Generates tests","author":{"username":"github","trust_tier":"verified"},"tags":["testing"],"license":"MIT"},{"name":"@github/scoutqa-test","version":"1.0.0","description":"Tests websites","author":{"username":"github","trust_tier":"verified"},"tags":["qa"],"license":"MIT"}],"total":2,"page":1,"per_page":2,"pages":1}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "@github/polyglot-test-agent",
    resultVersion = "1.0.0",
  }
}
