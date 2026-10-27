return {
  name = "fpm update tracked dependency",
  fixtureRoot = "/tmp/opencode/fpm-update-case",
  request = {
    action = "update",
    system = "fpm",
    flags = { "project-root=/tmp/opencode/fpm-update-case" },
    packages = {
      { name = "stdlib", version = "0.7.0", namespace = "fortran-lang", packageType = "library" }
    },
  },
  fixtureDirs = {
    ".reqpack-data/fpm-cache",
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/fpm-update-case/.reqpack-data/fpm-cache/fpm.toml'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "cat '/tmp/opencode/fpm-update-case/.reqpack-data/fpm-cache/registry-index.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "command -v fpm >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL https://github.com/fortran-lang/fpm-registry/raw/master/index.json -o /tmp/opencode/fpm-update-case/.reqpack-data/fpm-cache/registry-index.json",
      exitCode = 0,
      stdout = [[{"packages":{"stdlib":{"latest":{"name":"stdlib","version":"0.7.0","license":"MIT","description":"Fortran standard library","git":"https://github.com/fortran-lang/stdlib","namespace":"fortran-lang"}}}}]],
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/fpm-update-case/.reqpack-data/fpm-cache' && printf %s 'name = \"reqpack-fpm-cache\"\nversion = \"0.0.0\"\nlicense = \"MIT\"\n\n[dependencies]\nstdlib.namespace = \"fortran-lang\"\nstdlib.v = \"0.7.0\"\n' > '/tmp/opencode/fpm-update-case/.reqpack-data/fpm-cache/fpm.toml'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '/tmp/opencode/fpm-update-case/.reqpack-data/fpm-cache' && fpm update --fetch-only",
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/opencode/fpm-update-case/.reqpack-data/fpm-cache/fpm.toml'",
      "cat '/tmp/opencode/fpm-update-case/.reqpack-data/fpm-cache/registry-index.json'",
      "curl -fsSL https://github.com/fortran-lang/fpm-registry/raw/master/index.json -o /tmp/opencode/fpm-update-case/.reqpack-data/fpm-cache/registry-index.json",
      "mkdir -p '/tmp/opencode/fpm-update-case/.reqpack-data/fpm-cache' && printf %s 'name = \"reqpack-fpm-cache\"\nversion = \"0.0.0\"\nlicense = \"MIT\"\n\n[dependencies]\nstdlib.namespace = \"fortran-lang\"\nstdlib.v = \"0.7.0\"\n' > '/tmp/opencode/fpm-update-case/.reqpack-data/fpm-cache/fpm.toml'",
      "cd '/tmp/opencode/fpm-update-case/.reqpack-data/fpm-cache' && fpm update --fetch-only"
    },
    events = { "updated", "success" },
  }
}
