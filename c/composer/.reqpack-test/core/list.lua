return {
  name = "composer list global packages",
  request = {
    action = "list",
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
      match = "COMPOSER_HOME='./.reqpack-test/fixtures/cache-root/home' COMPOSER_CACHE_DIR='./.reqpack-test/fixtures/cache-root/cache' COMPOSER_NO_INTERACTION='1' COMPOSER_ALLOW_SUPERUSER='1' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' composer global show --format json",
      exitCode = 0,
      stdout = [[{"installed":[{"name":"monolog/monolog","version":"3.9.0","description":"Sends your logs","homepage":"https://github.com/Seldaek/monolog","latest":"3.9.1"}]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "monolog/monolog",
    resultVersion = "3.9.0",
  },
}
