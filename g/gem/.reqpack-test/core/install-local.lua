return {
  name = "gem install local artifact",
  request = {
    action = "install",
    system = "gem",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    localPath = "/tmp/pkg/rake-13.4.2.gem",
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
      match = "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem install --local /tmp/pkg/rake-13.4.2.gem --install-dir ${fixtureRoot}/.reqpack-data/gem-home --bindir ${fixtureRoot}/.reqpack-data/gem-bin --no-document --norc",
      exitCode = 0,
      stdout = "Successfully installed rake-13.4.2\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v gem >/dev/null 2>&1",
      "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem install --local /tmp/pkg/rake-13.4.2.gem --install-dir ${fixtureRoot}/.reqpack-data/gem-home --bindir ${fixtureRoot}/.reqpack-data/gem-bin --no-document --norc"
    },
    events = { "installed", "success" },
  }
}
