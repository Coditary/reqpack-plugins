return {
  name = "mmc list tracked libraries",
  request = {
    action = "list",
    system = "mmc",
    flags = {
      "cache-root=${fixtureRoot}/cache"
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
      "version": "1.2.3"
    }
  }
}
]],
    },
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/cache/tracked.json'",
      exitCode = 0,
      stdout = [[{
  "tracked": {
    "foo": {
      "name": "foo",
      "sourcePath": "${fixtureRoot}/src/foo",
      "installTarget": "libfoo.install",
      "mainModule": "foo",
      "version": "1.2.3"
    }
  }
}
]],
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
    events = { "listed" },
    resultCount = 1,
    resultName = "foo",
    resultVersion = "1.2.3",
  },
}
