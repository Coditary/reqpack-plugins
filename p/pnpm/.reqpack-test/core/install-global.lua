return {
  name = "pnpm install global package",
  request = {
    action = "install",
    system = "pnpm",
    flags = { "global" },
    packages = {
      { name = "cowsay", version = "1.6.0" },
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
      match = "pnpm add --global 'cowsay@1.6.0'",
      exitCode = 0,
      stdout = "global add ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "pnpm add --global 'cowsay@1.6.0'" },
    stdout = { "global add ok\n" },
  },
}
