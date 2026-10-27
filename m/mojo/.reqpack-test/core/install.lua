return {
  name = "mojo install via modular",
  request = {
    action = "install",
    system = "mojo",
    flags = {
      "modular-home=/home/test/.modular",
      "python-home=/opt/python",
      "python-lib=/opt/python/lib/libpython3.11.so",
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
      match = "MODULAR_HOME='/home/test/.modular' PYTHONHOME='/opt/python' MOJO_PYTHON_LIBRARY='/opt/python/lib/libpython3.11.so' modular install mojo",
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
      "MODULAR_HOME='/home/test/.modular' PYTHONHOME='/opt/python' MOJO_PYTHON_LIBRARY='/opt/python/lib/libpython3.11.so' modular install mojo",
    },
    events = { "installed", "success" },
  },
}
