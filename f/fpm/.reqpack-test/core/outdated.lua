return {
  name = "fpm outdated pinned dependency",
  fixtureRoot = "/tmp/opencode/fpm-outdated-case",
  request = {
    action = "outdated",
    system = "fpm",
    flags = { "project-root=/tmp/opencode/fpm-outdated-case" },
  },
  fixtureDirs = {
    ".reqpack-data/fpm-cache",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/fpm-cache/fpm.toml",
      content = "name = \"reqpack-fpm-cache\"\nversion = \"0.0.0\"\nlicense = \"MIT\"\n\n[dependencies]\nstdlib.namespace = \"fortran-lang\"\nstdlib.v = \"0.1.0\"\n",
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/fpm-outdated-case/.reqpack-data/fpm-cache/registry-index.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "cat '/tmp/opencode/fpm-outdated-case/.reqpack-data/fpm-cache/fpm.toml'",
      exitCode = 0,
      stdout = "name = \"reqpack-fpm-cache\"\nversion = \"0.0.0\"\nlicense = \"MIT\"\n\n[dependencies]\nstdlib.namespace = \"fortran-lang\"\nstdlib.v = \"0.1.0\"\n",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL https://github.com/fortran-lang/fpm-registry/raw/master/index.json -o /tmp/opencode/fpm-outdated-case/.reqpack-data/fpm-cache/registry-index.json",
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
      "cat '/tmp/opencode/fpm-outdated-case/.reqpack-data/fpm-cache/registry-index.json'",
      "curl -fsSL https://github.com/fortran-lang/fpm-registry/raw/master/index.json -o /tmp/opencode/fpm-outdated-case/.reqpack-data/fpm-cache/registry-index.json",
      "cat '/tmp/opencode/fpm-outdated-case/.reqpack-data/fpm-cache/fpm.toml'"
    },
    events = { "outdated" },
    resultCount = 1,
    resultName = "stdlib",
    resultVersion = "0.1.0",
  }
}
