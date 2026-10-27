return {
  name = "tcllib search releases",
  request = {
    action = "search",
    system = "tcllib",
    prompt = "1.2",
    flags = {
      "cache-root=/tmp/opencode/tcllib-cache",
    },
  },
  fixtureDirs = {
    "/tmp/opencode/tcllib-cache/state",
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/tcllib-cache/state/current.txt'",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "command -v 'curl' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://api.github.com/repos/tcltk/tcllib/tags?per_page=100'",
      exitCode = 0,
      stdout = "[{\"name\":\"tcllib-2-0\"},{\"name\":\"tcllib-1-21\"},{\"name\":\"tcllib-1-20\"}]",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/opencode/tcllib-cache/state/current.txt'",
      "command -v 'curl' >/dev/null 2>&1",
      "curl -fsSL 'https://api.github.com/repos/tcltk/tcllib/tags?per_page=100'",
    },
    events = { "searched" },
    resultCount = 2,
    resultName = "tcllib",
    resultVersion = "1.21",
  }
}
