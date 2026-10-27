return {
  name = "mmc search tracked libraries locally",
  request = {
    action = "search",
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
      "version": ""
    },
    "bar": {
      "name": "bar",
      "sourcePath": "${fixtureRoot}/src/bar",
      "installTarget": "libbar.install",
      "mainModule": "bar",
      "version": ""
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
      "version": ""
    },
    "bar": {
      "name": "bar",
      "sourcePath": "${fixtureRoot}/src/bar",
      "installTarget": "libbar.install",
      "mainModule": "bar",
      "version": ""
    }
  }
}
]],
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
    events = { "searched" },
    resultCount = 1,
    resultName = "foo",
  },
}
