return {
  name = "go search module exact",
  request = {
    action = "search",
    system = "go",
    prompt = "golang.org/x/text",
  },
  fakeExec = {
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
    events = { "searched" },
    resultCount = 1,
    resultName = "golang.org/x/text",
    resultVersion = "v0.25.0",
  }
}
