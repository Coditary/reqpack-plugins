return {
  name = "oobabooga update app",
  request = {
    action = "update",
    system = "oobabooga",
    packages = {
      {
        name = "app:oobabooga",
        version = "4.3.2",
        sourcePath = "file://${fixtureRoot}/assets/textgen-portable-4.3.2-linux-cpu"
      }
    },
  },
  fixtureRoot = "../fixtures-update-app",
  fixtureDirs = {
    "assets/textgen-portable-4.3.2-linux-cpu",
    "assets/textgen-portable-4.3.2-linux-cpu/user_data",
    "home/.local/share/oobabooga/text-generation-webui",
    "home/.local/share/oobabooga/user_data",
    "home/.local/share/oobabooga/reqpack",
  },
  fixtureFiles = {
    {
      path = "assets/textgen-portable-4.3.2-linux-cpu/server.py",
      content = "print('new')\n",
    },
    {
      path = "home/.local/share/oobabooga/reqpack/app.json",
      content = [[{"version":"4.2","asset_name":"textgen-portable-4.2-linux-cpu.tar.gz","install_root":"${fixtureRoot}/home/.local/share/oobabooga/text-generation-webui"}]],
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
      match = "rm -rf '",
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
    events = { "updated", "success" },
    eventPayloads = {
      updated = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
