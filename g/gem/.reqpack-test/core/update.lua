return {
  name = "gem update managed gem",
  request = {
    action = "update",
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
      match = "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem update rake --install-dir ${fixtureRoot}/.reqpack-data/gem-home --bindir ${fixtureRoot}/.reqpack-data/gem-bin --no-document --norc",
      exitCode = 0,
      stdout = "Updating installed gems\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v gem >/dev/null 2>&1",
      "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem update rake --install-dir ${fixtureRoot}/.reqpack-data/gem-home --bindir ${fixtureRoot}/.reqpack-data/gem-bin --no-document --norc"
    },
    events = { "updated", "success" },
  }
}
