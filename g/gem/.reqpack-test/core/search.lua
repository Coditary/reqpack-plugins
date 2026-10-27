return {
  name = "gem search remote details",
  request = {
    action = "search",
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
      match = "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem search --remote --details rake --norc",
      exitCode = 0,
      stdout = [[rake (13.4.2)
    Authors: Hiroshi SHIBATA, Eric Hodel
    Homepage: https://github.com/ruby/rake
    License: MIT

    Rake is a Make-like program implemented in Ruby

rake-compiler (1.3.1)
    Authors: Kouhei Sutou, Luis Lavena
    Homepage: https://github.com/rake-compiler/rake-compiler
    License: MIT

    Rake-based Ruby Extension task generator.
]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v gem >/dev/null 2>&1",
      "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem search --remote --details rake --norc"
    },
    resultCount = 2,
    resultName = "rake",
    resultVersion = "13.4.2",
    events = { "searched" },
  }
}
