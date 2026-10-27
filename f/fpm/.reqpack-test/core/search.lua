return {
  name = "fpm search registry index",
  fixtureRoot = "/tmp/opencode/fpm-search-case",
  request = {
    action = "search",
    system = "fpm",
    prompt = "standard",
    flags = { "project-root=/tmp/opencode/fpm-search-case" },
  },
  fixtureDirs = {
    ".reqpack-data/fpm-cache",
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/fpm-search-case/.reqpack-data/fpm-cache/registry-index.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "curl -fsSL https://github.com/fortran-lang/fpm-registry/raw/master/index.json -o /tmp/opencode/fpm-search-case/.reqpack-data/fpm-cache/registry-index.json",
      exitCode = 0,
      stdout = [[{"packages":{"stdlib":{"latest":{"name":"stdlib","version":"0.7.0","license":"MIT","description":"Fortran standard library","git":"https://github.com/fortran-lang/stdlib","namespace":"fortran-lang"}},"toml-f":{"latest":{"name":"toml-f","version":"0.4.2","license":"MIT","description":"TOML parser","git":"https://github.com/toml-f/toml-f.git","namespace":"toml-f"}}}}]],
      stderr = "",
      success = true,
    },
    {
      match = "command -v fpm >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/opencode/fpm-search-case/.reqpack-data/fpm-cache/registry-index.json'",
      "curl -fsSL https://github.com/fortran-lang/fpm-registry/raw/master/index.json -o /tmp/opencode/fpm-search-case/.reqpack-data/fpm-cache/registry-index.json"
    },
    events = { "searched" },
    resultCount = 1,
    resultName = "stdlib",
    resultVersion = "0.7.0",
  }
}
