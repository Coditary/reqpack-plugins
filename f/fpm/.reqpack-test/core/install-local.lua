return {
  name = "fpm install local project",
  fixtureRoot = "/tmp/opencode/fpm-install-local-case",
  request = {
    action = "install",
    system = "fpm",
    localPath = "/tmp/opencode/fpm-install-local-case/local-project",
  },
  fixtureDirs = {
    "local-project",
  },
  fakeExec = {
    {
      match = "command -v fpm >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '/tmp/opencode/fpm-install-local-case/local-project' && fpm install --profile release",
      exitCode = 0,
      stdout = "install ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cd '/tmp/opencode/fpm-install-local-case/local-project' && fpm install --profile release"
    },
    events = { "installed", "success" },
  }
}
