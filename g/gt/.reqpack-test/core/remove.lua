return {
  name = "gt remove managed version",
  fixtureDirs = {
    "data/installs/1.6.4/bin",
  },
  fixtureFiles = {
    {
      path = "data/installs/1.6.4/bin/gt",
      content = "binary",
    },
  },
  request = {
    action = "remove",
    system = "gt",
    packages = {
      {
        action = "remove",
        name = "gt",
        version = "1.6.4",
        flags = {
          "data-root=${fixtureRoot}/data",
        },
      },
    },
  },
  fakeExec = {
    {
      match = "test -x '${fixtureRoot}/data/installs/1.6.4/bin/gt'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '${fixtureRoot}/data/installs/1.6.4'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
