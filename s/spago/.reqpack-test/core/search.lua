return {
  name = "spago registry search",
  request = {
    action = "search",
    system = "spago",
    prompt = "prel",
  },
  fakeExec = {
    {
      match = "command -v 'spago' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "spago registry search --json prel",
      exitCode = 0,
      stdout = [[{"prelude":{"version":"6.0.2","publishedTime":"2025-02-15T18:25:08.000Z"},"prelude-lenses":{"version":"8.0.0","publishedTime":"2024-01-05T10:00:00.000Z"}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "prelude",
    resultVersion = "6.0.2",
  }
}
