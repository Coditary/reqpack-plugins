return {
  name = "gt install local source tree",
  fixtureDirs = {
    "local-src",
  },
  fixtureFiles = {
    {
      path = "local-src/VERSION",
      content = "1.6.5\n",
    },
  },
  request = {
    action = "install",
    system = "gt",
    localPath = "${fixtureRoot}/local-src",
    flags = {
      "data-root=${fixtureRoot}/data",
      "jobs=2",
      "cairo=no",
    },
  },
  fakeExec = {
    {
      match = "command -v 'tar' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'make' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -d '${fixtureRoot}/local-src'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "if [ -f '${fixtureRoot}/local-src/VERSION' ]; then cat '${fixtureRoot}/local-src/VERSION'; fi",
      exitCode = 0,
      stdout = "1.6.5\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/data' '${fixtureRoot}/data/downloads' '${fixtureRoot}/data/src' '${fixtureRoot}/data/installs'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '${fixtureRoot}/local-src' && make -j2 cairo=no",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '${fixtureRoot}/local-src' && make prefix='${fixtureRoot}/data/installs/1.6.5' cairo=no install",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
