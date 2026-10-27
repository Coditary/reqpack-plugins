return {
  name = "mojo remove via modular",
  request = {
    action = "remove",
    system = "mojo",
    flags = {
      "modular-home=/home/test/.modular",
    },
    packages = {
      { name = "mojo" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'modular' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "MODULAR_HOME='/home/test/.modular' modular uninstall mojo",
      exitCode = 0,
      stdout = "removed mojo\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'modular' >/dev/null 2>&1",
      "MODULAR_HOME='/home/test/.modular' modular uninstall mojo",
    },
    events = { "deleted", "success" },
  },
}
