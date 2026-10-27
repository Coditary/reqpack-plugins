return {
  name = "composer remove global package",
  request = {
    action = "remove",
    system = "composer",
    flags = { "cache-root=./.reqpack-test/fixtures/cache-root" },
    packages = {
      { name = "monolog/monolog" }
    },
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
      match = "COMPOSER_HOME='./.reqpack-test/fixtures/cache-root/home' COMPOSER_CACHE_DIR='./.reqpack-test/fixtures/cache-root/cache' COMPOSER_NO_INTERACTION='1' COMPOSER_ALLOW_SUPERUSER='1' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' composer global remove --no-progress --no-ansi 'monolog/monolog'",
      exitCode = 0,
      stdout = "removed monolog\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    commands = {
      "command -v 'composer' >/dev/null 2>&1",
      "COMPOSER_HOME='./.reqpack-test/fixtures/cache-root/home' COMPOSER_CACHE_DIR='./.reqpack-test/fixtures/cache-root/cache' COMPOSER_NO_INTERACTION='1' COMPOSER_ALLOW_SUPERUSER='1' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' composer global remove --no-progress --no-ansi 'monolog/monolog'"
    },
  },
}
