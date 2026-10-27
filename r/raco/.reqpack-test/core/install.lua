return {
  name = "raco install named package",
  request = {
    action = "install",
    system = "raco",
    packages = {
      { name = "shell-completion" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'raco' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "raco pkg install --batch --scope user --deps search-auto 'shell-completion'",
      exitCode = 0,
      stdout = "Resolving \"shell-completion\"\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'raco' >/dev/null 2>&1",
      "raco pkg install --batch --scope user --deps search-auto 'shell-completion'",
    },
    events = { "installed", "success" },
  }
}
