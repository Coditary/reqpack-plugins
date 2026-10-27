return {
  name = "tcllib outdated compares installed release",
  request = {
    action = "outdated",
    system = "tcllib",
    flags = {
      "cache-root=/tmp/opencode/tcllib-cache",
    },
  },
  fixtureDirs = {
    "/tmp/opencode/tcllib-cache/state",
  },
  fixtureFiles = {
    {
      path = "/tmp/opencode/tcllib-cache/state/current.txt",
      content = "name=tcllib\nversion=1.21\ntag=tcllib-1-21\norigin=remote\nroot=/tmp/opencode/tcllib-cache\npkgPath=/tmp/opencode/tcllib-cache/current/lib/tcllib1.21\nexamplePath=/tmp/opencode/tcllib-cache/current/examples\nhtmlPath=/tmp/opencode/tcllib-cache/current/doc/html\nnroffPath=/tmp/opencode/tcllib-cache/current/man/mann\nsourcePath=/tmp/opencode/tcllib-cache/sources/tcllib-tcllib-1-21\n",
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/tcllib-cache/state/current.txt'",
      exitCode = 0,
      stdout = "name=tcllib\nversion=1.21\ntag=tcllib-1-21\norigin=remote\nroot=/tmp/opencode/tcllib-cache\npkgPath=/tmp/opencode/tcllib-cache/current/lib/tcllib1.21\nexamplePath=/tmp/opencode/tcllib-cache/current/examples\nhtmlPath=/tmp/opencode/tcllib-cache/current/doc/html\nnroffPath=/tmp/opencode/tcllib-cache/current/man/mann\nsourcePath=/tmp/opencode/tcllib-cache/sources/tcllib-tcllib-1-21\n",
      stderr = "",
      success = true,
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
      stdout = "[{\"name\":\"tcllib-2-0\"},{\"name\":\"tcllib-1-21\"}]",
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
    events = { "outdated" },
    resultCount = 1,
    resultName = "tcllib",
    resultVersion = "2.0",
  }
}
