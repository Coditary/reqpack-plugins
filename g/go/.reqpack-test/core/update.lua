return {
  name = "go module update",
  request = {
    action = "update",
    system = "go",
    packages = {
      { name = "golang.org/x/text", version = "v0.25.0", packageType = "module" }
    },
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
      match = "command -v go >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "GOBIN='/home/test/.cache/reqpack/go/bin' GOPATH='/home/test/.cache/reqpack/go/gopath' GOMODCACHE='/home/test/.cache/reqpack/go/gomodcache' GOCACHE='/home/test/.cache/reqpack/go/gocache' GO111MODULE='on' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' go mod download -json golang.org/x/text@v0.25.0",
      exitCode = 0,
      stdout = '{"Path":"golang.org/x/text","Version":"v0.25.0"}\n',
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v go >/dev/null 2>&1",
      "GOBIN='/home/test/.cache/reqpack/go/bin' GOPATH='/home/test/.cache/reqpack/go/gopath' GOMODCACHE='/home/test/.cache/reqpack/go/gomodcache' GOCACHE='/home/test/.cache/reqpack/go/gocache' GO111MODULE='on' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' go mod download -json golang.org/x/text@v0.25.0"
    },
    events = { "updated", "success" },
  }
}
