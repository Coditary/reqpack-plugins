return {
  name = "tcllib list managed install",
  request = {
    action = "list",
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
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/opencode/tcllib-cache/state/current.txt'",
    },
    events = { "listed" },
    resultCount = 1,
    resultName = "tcllib",
    resultVersion = "1.21",
  }
}
