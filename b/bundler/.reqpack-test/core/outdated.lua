return {
  name = "bundler outdated parseable output",
  request = {
    action = "outdated",
    system = "bundler",
    flags = {
      "dir=./.reqpack-test/fixtures/project",
      "cache-root=./.reqpack-test/fixtures/home/.cache/reqpack/bundler",
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
      match = "BUNDLE_USER_HOME='./.reqpack-test/fixtures/home/.cache/reqpack/bundler' BUNDLE_USER_CACHE='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/cache' BUNDLE_USER_CONFIG='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/config' BUNDLE_USER_PLUGIN='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/plugin' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' BUNDLE_GEMFILE='./.reqpack-test/fixtures/project/Gemfile' bundle outdated --parseable",
      exitCode = 1,
      stdout = "rack (newest 3.1.8, installed 3.1.7, requested >= 0)\n",
      stderr = "",
      success = false,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "rack",
    resultVersion = "3.1.7",
  },
}
