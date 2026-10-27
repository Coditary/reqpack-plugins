return {
  name = "mojo update via modular",
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
      exitCode = 0,
      stdout = "updated mojo\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'modular' >/dev/null 2>&1",
      "MODULAR_HOME='/home/test/.modular' modular update mojo",
    },
    events = { "updated", "success" },
  },
}
