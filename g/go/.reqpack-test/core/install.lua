return {
  name = "go tool install",
  request = {
    action = "install",
    system = "go",
    packages = {
      { name = "golang.org/x/tools/cmd/stringer", version = "v0.38.0", packageType = "tool" }
    },
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
      match = "GOBIN='/home/test/.cache/reqpack/go/bin' GOPATH='/home/test/.cache/reqpack/go/gopath' GOMODCACHE='/home/test/.cache/reqpack/go/gomodcache' GOCACHE='/home/test/.cache/reqpack/go/gocache' GO111MODULE='on' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' go install golang.org/x/tools/cmd/stringer@v0.38.0",
      exitCode = 0,
      stdout = "install ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v go >/dev/null 2>&1",
      "GOBIN='/home/test/.cache/reqpack/go/bin' GOPATH='/home/test/.cache/reqpack/go/gopath' GOMODCACHE='/home/test/.cache/reqpack/go/gomodcache' GOCACHE='/home/test/.cache/reqpack/go/gocache' GO111MODULE='on' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' go install golang.org/x/tools/cmd/stringer@v0.38.0"
    },
    events = { "installed", "success" },
  }
}
