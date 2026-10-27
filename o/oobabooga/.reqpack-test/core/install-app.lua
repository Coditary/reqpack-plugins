return {
  name = "oobabooga install app",
  request = {
    action = "install",
    system = "oobabooga",
    packages = {
      {
        name = "app:oobabooga",
        version = "4.2",
        sourcePath = "file://${fixtureRoot}/assets/textgen-portable-4.2-linux-cpu"
      }
    },
  },
  fixtureRoot = "../fixtures-install-app",
  fixtureDirs = {
    "assets/textgen-portable-4.2-linux-cpu",
    "assets/textgen-portable-4.2-linux-cpu/user_data",
    "home/.local/share/oobabooga/reqpack",
    "home/.local/share/oobabooga/user_data/models",
  },
  fixtureFiles = {
    {
      path = "assets/textgen-portable-4.2-linux-cpu/server.py",
      content = "print('ok')\n",
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    {
      match = "mkdir -p '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -d '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -f '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cp -R '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
