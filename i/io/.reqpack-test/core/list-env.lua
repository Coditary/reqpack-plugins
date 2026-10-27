return {
  name = "io list packages from selected env",
  fixtureRoot = "/tmp/opencode/io-list-env-case",
  request = {
    action = "list",
    system = "io",
    flags = {
      "data-root=/tmp/opencode/io-list-env-case/.reqpack-data",
      "cache-root=/tmp/opencode/io-list-env-case/.reqpack-cache",
      "config-root=/tmp/opencode/io-list-env-case/.reqpack-config",
      "env=work",
    },
  },
  fixtureDirs = {
    ".reqpack-data/io/eerie/env/work/addons/Foo",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/io/eerie/config.json",
      content = [[{"activeEnv":"default","envs":{"default":{"name":"default","packages":[]},"work":{"name":"work","packages":[{"name":"Foo","uri":"https://github.com/example/Foo.git","path":"/tmp/opencode/io-list-env-case/.reqpack-data/io/eerie/env/work/addons/Foo"}]}}}]],
    },
    {
      path = ".reqpack-data/io/eerie/env/work/addons/Foo/package.json",
      content = [[{"name":"Foo","version":"2.0.0","description":"Work env package","website":"https://github.com/example/Foo"}]],
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/io-list-env-case/.reqpack-data/io/eerie/config.json'",
      exitCode = 0,
      stdout = [[{"activeEnv":"default","envs":{"default":{"name":"default","packages":[]},"work":{"name":"work","packages":[{"name":"Foo","uri":"https://github.com/example/Foo.git","path":"/tmp/opencode/io-list-env-case/.reqpack-data/io/eerie/env/work/addons/Foo"}]}}}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/io-list-env-case/.reqpack-data/io/eerie/env/work/addons/Foo/package.json'",
      exitCode = 0,
      stdout = [[{"name":"Foo","version":"2.0.0","description":"Work env package","website":"https://github.com/example/Foo"}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "Foo",
    resultVersion = "2.0.0",
  },
}
