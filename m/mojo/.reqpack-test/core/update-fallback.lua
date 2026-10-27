return {
  name = "mojo update falls back to install",
  request = {
    action = "update",
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
      match = "MODULAR_HOME='/home/test/.modular' modular update mojo",
      exitCode = 2,
      stdout = "",
      stderr = "error: unknown command 'update'\n",
      success = false,
    },
    {
      match = "MODULAR_HOME='/home/test/.modular' modular install mojo",
      exitCode = 0,
      stdout = "installed mojo\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'modular' >/dev/null 2>&1",
      "MODULAR_HOME='/home/test/.modular' modular update mojo",
      "MODULAR_HOME='/home/test/.modular' modular install mojo",
    },
    events = { "updated", "success" },
  },
}
