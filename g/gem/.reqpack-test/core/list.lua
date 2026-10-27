return {
  name = "gem list managed gems",
  request = {
    action = "list",
    system = "gem",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
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
      match = "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem list --local --details --norc",
      exitCode = 0,
      stdout = [[rake (13.4.2, 13.4.1)
    Authors: Hiroshi SHIBATA, Eric Hodel
    Homepage: https://github.com/ruby/rake
    License: MIT
    Installed at: ${fixtureRoot}/.reqpack-data/gem-home

    Rake is a Make-like program implemented in Ruby
]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v gem >/dev/null 2>&1",
      "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem list --local --details --norc"
    },
    resultCount = 1,
    resultName = "rake",
    resultVersion = "13.4.2",
    events = { "listed" },
  }
}
