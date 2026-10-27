return {
  name = "pnpm install package",
  request = {
    action = "install",
    system = "pnpm",
    packages = {
      { name = "is-number", version = "7.0.0" },
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
      match = "pnpm add 'is-number@7.0.0'",
      exitCode = 0,
      stdout = "added 1 package\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "pnpm add 'is-number@7.0.0'" },
    stdout = { "added 1 package\n" },
  },
}
