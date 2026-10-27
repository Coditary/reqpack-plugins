return {
  name = "gt info installed version",
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
    action = "info",
    system = "gt",
    prompt = "gt@1.6.4",
    flags = {
      "data-root=${fixtureRoot}/data",
    },
  },
  fakeExec = {
    {
      match = "if [ -d '${fixtureRoot}/data/installs' ]; then ls -1 '${fixtureRoot}/data/installs'; fi",
      exitCode = 0,
      stdout = "1.6.4\n",
      stderr = "",
      success = true,
    },
    {
      match = "test -x '${fixtureRoot}/data/installs/1.6.4/bin/gt'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "gt",
    resultVersion = "1.6.4",
  }
}
