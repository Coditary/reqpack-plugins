return {
  name = "bundler info remote merged query",
  request = {
    action = "info",
    system = "bundler",
    prompt = "rack",
    flags = {
      "cache-root=./.reqpack-test/fixtures/cache-root",
    },
  },
  fakeExec = {
    {
      match = "command -v 'bundle' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'gem' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "BUNDLE_USER_HOME='./.reqpack-test/fixtures/cache-root' BUNDLE_USER_CACHE='./.reqpack-test/fixtures/cache-root/cache' BUNDLE_USER_CONFIG='./.reqpack-test/fixtures/cache-root/config' BUNDLE_USER_PLUGIN='./.reqpack-test/fixtures/cache-root/plugin' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' BUNDLE_GEMFILE='./.reqpack-test/fixtures/cache-root/query-project/Gemfile' BUNDLE_CACHE_PATH='./.reqpack-test/fixtures/cache-root/query-vendor-cache' bundle lock --print",
      exitCode = 0,
      stdout = [[GEM
  remote: https://rubygems.org/
  specs:
    rack (3.1.8)

DEPENDENCIES
  rack

PLATFORMS
  ruby

BUNDLED WITH
   2.5.10
]],
      stderr = "",
      success = true,
    },
    {
      match = "BUNDLE_USER_HOME='./.reqpack-test/fixtures/cache-root' BUNDLE_USER_CACHE='./.reqpack-test/fixtures/cache-root/cache' BUNDLE_USER_CONFIG='./.reqpack-test/fixtures/cache-root/config' BUNDLE_USER_PLUGIN='./.reqpack-test/fixtures/cache-root/plugin' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' GEM_SPEC_CACHE='./.reqpack-test/fixtures/cache-root/rubygems/specs' GEMRC=/dev/null gem specification rack --remote --yaml --norc",
      exitCode = 0,
      stdout = [[--- !ruby/object:Gem::Specification
name: rack
version: !ruby/object:Gem::Version
  version: 3.1.8
authors:
- Rack Core Team
homepage: https://github.com/rack/rack
licenses:
- MIT
summary: Rack interface.
description: Modular Ruby webserver interface.
dependencies: []
metadata:
  source_code_uri: https://github.com/rack/rack
]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "rack",
    resultVersion = "3.1.8",
  },
}
