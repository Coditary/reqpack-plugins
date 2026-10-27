return {
  name = "mmc info tracked library",
  request = {
    action = "info",
    system = "mmc",
    prompt = "foo",
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
      "version": "1.0.0"
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
      "version": "1.0.0"
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
    events = { "informed" },
    resultCount = 1,
    resultName = "foo",
    resultVersion = "1.0.0",
  },
}
