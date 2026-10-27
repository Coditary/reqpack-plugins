return {
  name = "bundler remove gem from project",
  request = {
    action = "remove",
    system = "bundler",
    flags = {
      "dir=./.reqpack-test/fixtures/project",
      "cache-root=./.reqpack-test/fixtures/home/.cache/reqpack/bundler",
    },
    packages = {
      { name = "rack" },
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
      match = "BUNDLE_USER_HOME='./.reqpack-test/fixtures/home/.cache/reqpack/bundler' BUNDLE_USER_CACHE='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/cache' BUNDLE_USER_CONFIG='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/config' BUNDLE_USER_PLUGIN='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/plugin' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' BUNDLE_GEMFILE='./.reqpack-test/fixtures/project/Gemfile' bundle remove rack --install",
      exitCode = 0,
      stdout = "Removing rack\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
