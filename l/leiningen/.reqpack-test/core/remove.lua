return {
  name = "leiningen remove exact version",
  request = {
    action = "remove",
    system = "leiningen",
    flags = { "repo-root=/tmp/opencode/leiningen-repo" },
    packages = {
      { name = "com.example/demo", version = "1.2.3" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'lein' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '/tmp/opencode/leiningen-repo/com/example/demo/1.2.3'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'lein' >/dev/null 2>&1",
      "rm -rf '/tmp/opencode/leiningen-repo/com/example/demo/1.2.3'",
    },
    events = { "deleted", "success" },
  },
}
