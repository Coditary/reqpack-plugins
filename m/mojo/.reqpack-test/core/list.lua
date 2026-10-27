return {
  name = "mojo list installed sdk",
  request = {
    action = "list",
    system = "mojo",
    flags = {
      "modular-home=/home/test/.modular",
    },
  },
  fixtureDirs = {
    "/home/test/.modular",
    "/home/test/.modular/pkg",
    "/home/test/.modular/pkg/packages.modular.com_mojo",
    "/home/test/.modular/pkg/packages.modular.com_mojo/bin",
  },
  fixtureFiles = {
    {
      path = "/home/test/.modular/pkg/packages.modular.com_mojo/bin/mojo",
      content = "#!/bin/sh\n",
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
      match = "MODULAR_HOME='/home/test/.modular' modular config-list",
      exitCode = 0,
      stdout = "mojo.driver_path = /home/test/.modular/pkg/packages.modular.com_mojo/bin/mojo\nmojo.python_lib = /usr/lib/libpython3.11.so\n",
      stderr = "",
      success = true,
    },
    {
      match = "'/home/test/.modular/pkg/packages.modular.com_mojo/bin/mojo' --version",
      exitCode = 0,
      stdout = "mojo 24.3.0 (abcdef12)\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'modular' >/dev/null 2>&1",
      "MODULAR_HOME='/home/test/.modular' modular config-list",
      "'/home/test/.modular/pkg/packages.modular.com_mojo/bin/mojo' --version",
    },
    resultCount = 1,
    resultName = "mojo",
    resultVersion = "24.3.0",
    events = { "listed" },
  },
}
