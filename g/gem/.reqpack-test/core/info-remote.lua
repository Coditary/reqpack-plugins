return {
  name = "gem info remote fallback",
  request = {
    action = "info",
    system = "gem",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    prompt = "rake",
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
      match = "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem specification rake --local --yaml --norc",
      exitCode = 1,
      stdout = "",
      stderr = "ERROR:  No gem matching 'rake (>= 0)' found\n",
      success = false,
    },
    {
      match = "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem specification rake --remote --yaml --norc",
      exitCode = 0,
      stdout = [[--- !ruby/object:Gem::Specification
name: rake
version: !ruby/object:Gem::Version
  version: 13.4.2
platform: ruby
authors:
- Hiroshi SHIBATA
- Eric Hodel
dependencies: []
executables:
- rake
homepage: https://github.com/ruby/rake
licenses:
- MIT
metadata:
  source_code_uri: https://github.com/ruby/rake
summary: Rake is a Make-like program implemented in Ruby
description: Rake is a Make-like program implemented in Ruby.
]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v gem >/dev/null 2>&1",
      "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem specification rake --local --yaml --norc",
      "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem specification rake --remote --yaml --norc"
    },
    resultName = "rake",
    resultVersion = "13.4.2",
    events = { "informed" },
  }
}
