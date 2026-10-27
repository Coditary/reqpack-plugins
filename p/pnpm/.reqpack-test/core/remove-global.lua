return {
  name = "pnpm remove global package",
  request = {
    action = "remove",
    system = "pnpm",
    flags = { "global" },
    packages = {
      { name = "cowsay" },
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
      match = "pnpm remove --global 'cowsay'",
      exitCode = 0,
      stdout = "removed global package\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "pnpm remove --global 'cowsay'" },
    stdout = { "removed global package\n" },
  },
}
