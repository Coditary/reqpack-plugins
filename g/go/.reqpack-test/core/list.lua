return {
  name = "go list merged",
  request = {
    action = "list",
    system = "go",
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/go/bin",
    ".reqpack-data",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/modules.txt",
      content = "golang.org/x/text v0.24.0\n",
    },
    {
      path = "/home/test/.cache/reqpack/go/bin/stringer",
      content = "binary",
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "${fixtureRoot}",
  },
  fakeExec = {
    {
      match = "command -v go >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "ls -1A '/home/test/.cache/reqpack/go/bin'",
      exitCode = 0,
      stdout = "stringer\n",
      stderr = "",
      success = true,
    },
    {
      match = "GOBIN='/home/test/.cache/reqpack/go/bin' GOPATH='/home/test/.cache/reqpack/go/gopath' GOMODCACHE='/home/test/.cache/reqpack/go/gomodcache' GOCACHE='/home/test/.cache/reqpack/go/gocache' GO111MODULE='on' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' go version -m /home/test/.cache/reqpack/go/bin/stringer",
      exitCode = 0,
      stdout = "/home/test/.cache/reqpack/go/bin/stringer: go1.26.3\n\tpath\tgolang.org/x/tools/cmd/stringer\n\tmod\tgolang.org/x/tools\tv0.38.0\th1:abc\n",
      stderr = "",
      success = true,
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
    events = { "listed" },
    resultCount = 1,
    resultName = "golang.org/x/tools/cmd/stringer",
    resultVersion = "v0.38.0",
  }
}
