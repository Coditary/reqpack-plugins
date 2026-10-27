return {
  name = "composer outdated global packages",
  request = {
    action = "outdated",
    system = "composer",
    flags = { "cache-root=./.reqpack-test/fixtures/cache-root" },
  },
  fakeExec = {
    {
      match = "command -v 'composer' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "COMPOSER_HOME='./.reqpack-test/fixtures/cache-root/home' COMPOSER_CACHE_DIR='./.reqpack-test/fixtures/cache-root/cache' COMPOSER_NO_INTERACTION='1' COMPOSER_ALLOW_SUPERUSER='1' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' composer global outdated --format json",
      exitCode = 1,
      stdout = [[{"installed":[{"name":"monolog/monolog","version":"3.8.0","latest":"3.9.1","description":"Sends your logs"}]}]],
      stderr = "",
      success = false,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "monolog/monolog",
    resultVersion = "3.8.0",
  },
}
