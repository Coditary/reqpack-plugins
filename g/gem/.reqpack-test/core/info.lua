return {
  name = "gem info local spec",
  request = {
    action = "info",
    system = "gem",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    prompt = "json",
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
      match = "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem specification json --local --yaml --norc",
      exitCode = 0,
      stdout = [[--- !ruby/object:Gem::Specification
name: json
version: !ruby/object:Gem::Version
  version: 2.19.5
platform: ruby
authors:
- Florian Frank
dependencies:
- !ruby/object:Gem::Dependency
  name: stringio
executables: []
homepage: https://github.com/ruby/json
licenses:
- Ruby
metadata:
  source_code_uri: https://github.com/ruby/json
required_ruby_version: !ruby/object:Gem::Requirement
  requirements:
  - - ">="
    - !ruby/object:Gem::Version
      version: '2.7'
summary: JSON Implementation for Ruby
description: This is a JSON implementation as a Ruby extension in C.
]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v gem >/dev/null 2>&1",
      "GEM_HOME=${fixtureRoot}/.reqpack-data/gem-home GEM_PATH=${fixtureRoot}/.reqpack-data/gem-home GEM_SPEC_CACHE=${fixtureRoot}/.reqpack-data/spec-cache GEMRC=/dev/null gem specification json --local --yaml --norc"
    },
    resultName = "json",
    resultVersion = "2.19.5",
    events = { "informed" },
  }
}
