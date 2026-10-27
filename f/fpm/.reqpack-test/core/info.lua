return {
  name = "fpm info registry package",
  fixtureRoot = "/tmp/opencode/fpm-info-case",
  request = {
    action = "info",
    system = "fpm",
    prompt = "stdlib",
    flags = { "project-root=/tmp/opencode/fpm-info-case" },
  },
  fixtureDirs = {
    ".reqpack-data/fpm-cache",
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/fpm-info-case/.reqpack-data/fpm-cache/registry-index.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "curl -fsSL https://github.com/fortran-lang/fpm-registry/raw/master/index.json -o /tmp/opencode/fpm-info-case/.reqpack-data/fpm-cache/registry-index.json",
      exitCode = 0,
      stdout = [[{"packages":{"stdlib":{"latest":{"name":"stdlib","version":"0.7.0","license":"MIT","description":"Fortran standard library","git":"https://github.com/fortran-lang/stdlib","namespace":"fortran-lang"}}}}]],
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
      "cat '/tmp/opencode/fpm-info-case/.reqpack-data/fpm-cache/registry-index.json'",
      "curl -fsSL https://github.com/fortran-lang/fpm-registry/raw/master/index.json -o /tmp/opencode/fpm-info-case/.reqpack-data/fpm-cache/registry-index.json"
    },
    events = { "informed" },
    resultName = "stdlib",
    resultVersion = "0.7.0",
  }
}
