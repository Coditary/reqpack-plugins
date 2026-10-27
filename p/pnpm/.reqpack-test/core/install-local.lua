return {
  name = "pnpm install local package file",
  request = {
    action = "install",
    system = "pnpm",
    localPath = "/tmp/pkg/is-number-7.0.0.tgz",
  },
  fakeExec = {
    {
      match = "command -v 'pnpm' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "pnpm add '/tmp/pkg/is-number-7.0.0.tgz'",
      exitCode = 0,
      stdout = "local add ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "pnpm add '/tmp/pkg/is-number-7.0.0.tgz'" },
    stdout = { "local add ok\n" },
    events = { "installed", "success" },
  },
}
