return {
  name = "go outdated module",
  request = {
    action = "outdated",
    system = "go",
  },
  fixtureDirs = {
    ".reqpack-data",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/modules.txt",
      content = "golang.org/x/text v0.24.0\n",
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "${fixtureRoot}",
  },
  fakeExec = {
    {
      match = "ls -1A '/home/test/.cache/reqpack/go/bin'",
      exitCode = 0,
      stdout = "",
      stderr = "ls: cannot access\n",
      success = false,
    },
    {
      match = "cat '${fixtureRoot}/.reqpack-data/modules.txt'",
      exitCode = 0,
      stdout = "golang.org/x/text v0.24.0\n",
      stderr = "",
      success = true,
    },
    {
      match = "GOBIN='/home/test/.cache/reqpack/go/bin' GOPATH='/home/test/.cache/reqpack/go/gopath' GOMODCACHE='/home/test/.cache/reqpack/go/gomodcache' GOCACHE='/home/test/.cache/reqpack/go/gocache' GO111MODULE='on' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' go list -m -json golang.org/x/text@latest",
      exitCode = 0,
      stdout = '{"Path":"golang.org/x/text","Version":"v0.25.0","Query":"latest"}\n',
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  }
}
