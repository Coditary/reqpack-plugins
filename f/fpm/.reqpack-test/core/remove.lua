return {
  name = "fpm remove tracked dependency",
  fixtureRoot = "/tmp/opencode/fpm-remove-case",
  request = {
    action = "remove",
    system = "fpm",
    flags = { "project-root=/tmp/opencode/fpm-remove-case" },
    packages = {
      { name = "stdlib", namespace = "fortran-lang", packageType = "library" }
    },
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
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "${fixtureRoot}",
  },
  fakeExec = {
    {
      match = "command -v fpm >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/fpm-remove-case/.reqpack-data/fpm-cache/fpm.toml'",
      exitCode = 0,
      stdout = "name = \"reqpack-fpm-cache\"\nversion = \"0.0.0\"\nlicense = \"MIT\"\n\n[dependencies]\nstdlib.namespace = \"fortran-lang\"\nstdlib.v = \"0.1.0\"\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/fpm-remove-case/.reqpack-data/fpm-cache' && printf %s 'name = \"reqpack-fpm-cache\"\nversion = \"0.0.0\"\nlicense = \"MIT\"\n\n[dependencies]\n' > '/tmp/opencode/fpm-remove-case/.reqpack-data/fpm-cache/fpm.toml'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/opencode/fpm-remove-case/.reqpack-data/fpm-cache/fpm.toml'",
      "mkdir -p '/tmp/opencode/fpm-remove-case/.reqpack-data/fpm-cache' && printf %s 'name = \"reqpack-fpm-cache\"\nversion = \"0.0.0\"\nlicense = \"MIT\"\n\n[dependencies]\n' > '/tmp/opencode/fpm-remove-case/.reqpack-data/fpm-cache/fpm.toml'"
    },
    events = { "deleted", "success" },
  }
}
