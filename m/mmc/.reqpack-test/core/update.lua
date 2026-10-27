return {
  name = "mmc update tracked library",
  request = {
    action = "update",
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
      match = "command -v 'mmc' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '${fixtureRoot}/src/foo' && mmc --make --install-prefix '${fixtureRoot}/cache/install-prefix' 'libfoo.install'",
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
    {
      match = "find '${fixtureRoot}/cache/install-prefix/lib/mercury' \\( -name 'libfoo.*' -o -name 'foo*' \\) -print -quit",
      exitCode = 0,
      stdout = "${fixtureRoot}/cache/install-prefix/lib/mercury/lib/libfoo.a\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
