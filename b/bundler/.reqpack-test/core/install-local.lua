return {
  name = "bundler install local gem project",
  request = {
    action = "installLocal",
    system = "bundler",
    localPath = "./.reqpack-test/fixtures/local-gem",
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
      match = "ls -1A './.reqpack-test/fixtures/local-gem' 2>/dev/null",
      exitCode = 0,
      stdout = "demo.gemspec\n",
      stderr = "",
      success = true,
    },
    {
      match = "BUNDLE_USER_HOME='./.reqpack-test/fixtures/home/.cache/reqpack/bundler' BUNDLE_USER_CACHE='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/cache' BUNDLE_USER_CONFIG='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/config' BUNDLE_USER_PLUGIN='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/plugin' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' BUNDLE_GEMFILE='./.reqpack-test/fixtures/project/Gemfile' bundle add --path ./.reqpack-test/fixtures/local-gem demo",
      exitCode = 0,
      stdout = "Using local path\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'bundle' >/dev/null 2>&1",
      "ls -1A './.reqpack-test/fixtures/local-gem' 2>/dev/null",
      "BUNDLE_USER_HOME='./.reqpack-test/fixtures/home/.cache/reqpack/bundler' BUNDLE_USER_CACHE='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/cache' BUNDLE_USER_CONFIG='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/config' BUNDLE_USER_PLUGIN='./.reqpack-test/fixtures/home/.cache/reqpack/bundler/plugin' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' BUNDLE_GEMFILE='./.reqpack-test/fixtures/project/Gemfile' bundle add --path ./.reqpack-test/fixtures/local-gem demo"
    },
    events = { "installed", "success" },
  },
}
