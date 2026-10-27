return {
  name = "go install local",
  request = {
    action = "install",
    system = "go",
    path = "/tmp/local-tool",
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
      match = "GOBIN='/home/test/.cache/reqpack/go/bin' GOPATH='/home/test/.cache/reqpack/go/gopath' GOMODCACHE='/home/test/.cache/reqpack/go/gomodcache' GOCACHE='/home/test/.cache/reqpack/go/gocache' GO111MODULE='on' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' go install /tmp/local-tool",
      exitCode = 0,
      stdout = "local ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
  }
}
