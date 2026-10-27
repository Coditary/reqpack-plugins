return {
  name = "mmc remove tracked library",
  request = {
    action = "remove",
    system = "mmc",
    flags = {
      "cache-root=${fixtureRoot}/cache"
    },
    packages = {
      { name = "foo" }
    },
  },
  fixtureDirs = {
    "cache",
    "cache/install-prefix/lib/mercury",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/cache/tracked.json",
      content = [[{
  "tracked": {
    "foo": {
      "name": "foo",
      "sourcePath": "${fixtureRoot}/src/foo",
      "installTarget": "libfoo.install",
      "mainModule": "foo",
      "version": ""
    }
  }
}
]],
    },
  },
  fakeExec = {
    {
      match = "find '${fixtureRoot}/cache/install-prefix/lib/mercury' \\( -name 'libfoo.*' -o -name 'foo*' \\) -exec rm -rf {} +",
      exitCode = 0,
      stdout = "",
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
    events = { "deleted", "success" },
  }
}
