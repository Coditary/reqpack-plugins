return {
  name = "pnpm install local global package file",
  request = {
    action = "install",
    system = "pnpm",
    flags = { "global" },
    localPath = "/tmp/pkg/cowsay-1.6.0.tgz",
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
      match = "pnpm add --global '/tmp/pkg/cowsay-1.6.0.tgz'",
      exitCode = 0,
      stdout = "local global add ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "pnpm add --global '/tmp/pkg/cowsay-1.6.0.tgz'" },
    stdout = { "local global add ok\n" },
    events = { "installed", "success" },
  },
}
