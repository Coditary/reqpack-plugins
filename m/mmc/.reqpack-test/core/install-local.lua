return {
  name = "mmc installLocal tracked library",
  request = {
    action = "install",
    system = "mmc",
    localPath = "${fixtureRoot}/src/bar",
    name = "bar",
    flags = {
      "cache-root=${fixtureRoot}/cache"
    },
  },
  fixtureDirs = {
    "cache",
    "src/bar",
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
      match = "cd '${fixtureRoot}/src/bar' && mmc --make --install-prefix '${fixtureRoot}/cache/install-prefix' 'libbar.install'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
    {
      match = "find '${fixtureRoot}/cache/install-prefix/lib/mercury' \\( -name 'libbar.*' -o -name 'bar*' \\) -print -quit",
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
