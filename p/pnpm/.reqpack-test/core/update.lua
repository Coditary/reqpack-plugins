return {
  name = "pnpm update package latest",
  request = {
    action = "update",
    system = "pnpm",
    flags = { "latest" },
    packages = {
      { name = "chalk" },
    },
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
      match = "pnpm update --latest 'chalk'",
      exitCode = 0,
      stdout = "updated chalk\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "pnpm update --latest 'chalk'" },
    stdout = { "updated chalk\n" },
  },
}
