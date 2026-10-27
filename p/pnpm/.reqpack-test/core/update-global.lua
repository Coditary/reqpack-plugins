return {
  name = "pnpm update global package latest",
  request = {
    action = "update",
    system = "pnpm",
    flags = { "global", "latest" },
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
      match = "pnpm update --global --latest 'cowsay'",
      exitCode = 0,
      stdout = "updated global cowsay\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "pnpm update --global --latest 'cowsay'" },
    stdout = { "updated global cowsay\n" },
  },
}
