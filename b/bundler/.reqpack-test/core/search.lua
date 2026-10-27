return {
  name = "bundler search via rubygems",
  request = {
    action = "search",
    system = "bundler",
    prompt = "rack",
    flags = {
      "cache-root=./.reqpack-test/fixtures/home/.cache/reqpack/bundler",
    },
  },
  fakeExec = {
    {
      match = "command -v 'gem' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "BUNDLE_USER_HOME='./.reqpack-test/fixtures/home/.cache/reqpack/bundler' BUNDLE_USER_CACHE='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/cache' BUNDLE_USER_CONFIG='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/config' BUNDLE_USER_PLUGIN='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/plugin' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' GEM_SPEC_CACHE='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/rubygems/specs' GEMRC=/dev/null gem search --remote --details rack --norc",
      exitCode = 0,
      stdout = [[rack (3.1.8)
    Authors: Rack Core Team
    Homepage: https://github.com/rack/rack
    License: MIT

    Modular Ruby webserver interface.
]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "rack",
    resultVersion = "3.1.8",
  },
}
