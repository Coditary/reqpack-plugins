return {
  name = "mmc install tracked local library",
  request = {
    action = "install",
    system = "mmc",
    flags = {
      "cache-root=${fixtureRoot}/cache"
    },
    packages = {
      { name = "${fixtureRoot}/src/foo" }
    },
  },
  fixtureDirs = {
    "cache",
    "src/foo",
  },
  fakeExec = {
    {
      match = "command -v 'mmc' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '${fixtureRoot}/src/foo' && mmc --make --install-prefix '${fixtureRoot}/cache/install-prefix' 'libfoo.install'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
    {
      match = "find '${fixtureRoot}/cache/install-prefix/lib/mercury' \\( -name 'libfoo.*' -o -name 'foo*' \\) -print -quit",
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
