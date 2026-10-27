return {
  name = "go tool remove",
  request = {
    action = "remove",
    system = "go",
    packages = {
      { name = "golang.org/x/tools/cmd/stringer", packageType = "tool" }
    },
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/go/bin",
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/go/bin/stringer",
      content = "binary",
    },
  },
  fakeExec = {
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
  },
  expect = {
    success = true,
    commands = {
      "ls -1A '/home/test/.cache/reqpack/go/bin'",
      "GOBIN='/home/test/.cache/reqpack/go/bin' GOPATH='/home/test/.cache/reqpack/go/gopath' GOMODCACHE='/home/test/.cache/reqpack/go/gomodcache' GOCACHE='/home/test/.cache/reqpack/go/gocache' GO111MODULE='on' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' go version -m /home/test/.cache/reqpack/go/bin/stringer"
    },
    events = { "deleted", "success" },
  }
}
