return {
  name = "io list installed packages from eerie state",
  fixtureRoot = "/tmp/opencode/io-list-case",
  request = {
    action = "list",
    system = "io",
    flags = {
      "data-root=/tmp/opencode/io-list-case/.reqpack-data",
      "cache-root=/tmp/opencode/io-list-case/.reqpack-cache",
      "config-root=/tmp/opencode/io-list-case/.reqpack-config",
    },
  },
  fixtureDirs = {
    ".reqpack-data/io/eerie/env/default/addons/Range",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/io/eerie/config.json",
      content = [[{"activeEnv":"default","envs":{"_base":{"name":"_base","packages":[]},"_plugins":{"name":"_plugins","packages":[]},"default":{"name":"default","packages":[{"name":"Range","uri":"https://github.com/IoLanguage/Range.git","path":"/tmp/opencode/io-list-case/.reqpack-data/io/eerie/env/default/addons/Range"}]}}}]],
    },
    {
      path = ".reqpack-data/io/eerie/env/default/addons/Range/package.json",
      content = [[{"name":"Range","version":"0.1.0","description":"Range addon","website":"https://github.com/IoLanguage/Range"}]],
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/io-list-case/.reqpack-data/io/eerie/config.json'",
      exitCode = 0,
      stdout = [[{"activeEnv":"default","envs":{"_base":{"name":"_base","packages":[]},"_plugins":{"name":"_plugins","packages":[]},"default":{"name":"default","packages":[{"name":"Range","uri":"https://github.com/IoLanguage/Range.git","path":"/tmp/opencode/io-list-case/.reqpack-data/io/eerie/env/default/addons/Range"}]}}}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/io-list-case/.reqpack-data/io/eerie/env/default/addons/Range/package.json'",
      exitCode = 0,
      stdout = [[{"name":"Range","version":"0.1.0","description":"Range addon","website":"https://github.com/IoLanguage/Range"}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/opencode/io-list-case/.reqpack-data/io/eerie/config.json'",
      "cat '/tmp/opencode/io-list-case/.reqpack-data/io/eerie/env/default/addons/Range/package.json'",
    },
    events = { "listed" },
    resultCount = 1,
    resultName = "Range",
    resultVersion = "0.1.0",
  },
}
