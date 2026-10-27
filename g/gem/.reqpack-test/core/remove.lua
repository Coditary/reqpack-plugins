return {
  name = "gem remove managed gem",
  request = {
    action = "remove",
    system = "gem",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    packages = {
      { name = "rake" }
    },
  },
  fakeExec = {
    {
      match = "command -v gem >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem uninstall rake --install-dir ${fixtureRoot}/.reqpack-data/gem-home --bindir ${fixtureRoot}/.reqpack-data/gem-bin --all --executables --ignore-dependencies --norc",
      exitCode = 0,
      stdout = "Successfully uninstalled rake-13.4.2\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v gem >/dev/null 2>&1",
      "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem uninstall rake --install-dir ${fixtureRoot}/.reqpack-data/gem-home --bindir ${fixtureRoot}/.reqpack-data/gem-bin --all --executables --ignore-dependencies --norc"
    },
    events = { "deleted", "success" },
  }
}
