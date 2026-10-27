return {
  name = "oobabooga remove app",
  request = {
    action = "remove",
    system = "oobabooga",
    packages = {
      { name = "app:oobabooga" }
    },
  },
  fixtureRoot = "../fixtures-remove-app",
  fixtureDirs = {
    "home/.local/share/oobabooga/text-generation-webui",
    "home/.local/share/oobabooga/user_data",
    "home/.local/share/oobabooga/reqpack",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/oobabooga/reqpack/app.json",
      content = [[{"version":"4.2"}]],
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
      match = "test -e '",
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
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    eventPayloads = {
      deleted = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
