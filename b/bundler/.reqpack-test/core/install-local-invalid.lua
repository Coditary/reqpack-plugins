return {
  name = "bundler install local raw gem unsupported",
  request = {
    action = "installLocal",
    system = "bundler",
    localPath = "./.reqpack-test/fixtures/pkg/demo-0.1.0.gem",
    flags = {
      "dir=./.reqpack-test/fixtures/project",
    },
  },
  fakeExec = {
    {
      match = "command -v 'bundle' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = false,
    commands = {
      "command -v 'bundle' >/dev/null 2>&1",
    },
  },
}
