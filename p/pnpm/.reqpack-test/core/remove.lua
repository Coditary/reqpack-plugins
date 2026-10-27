return {
  name = "pnpm remove package",
  request = {
    action = "remove",
    system = "pnpm",
    packages = {
      { name = "is-number" },
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
      match = "pnpm remove 'is-number'",
      exitCode = 0,
      stdout = "removed 1 package\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "pnpm remove 'is-number'" },
    stdout = { "removed 1 package\n" },
  },
}
