return {
  name = "composer info merged installed and remote",
  request = {
    action = "info",
    system = "composer",
    prompt = "monolog/monolog",
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
      match = "COMPOSER_HOME='./.reqpack-test/fixtures/cache-root/home' COMPOSER_CACHE_DIR='./.reqpack-test/fixtures/cache-root/cache' COMPOSER_NO_INTERACTION='1' COMPOSER_ALLOW_SUPERUSER='1' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' composer global show --format json 'monolog/monolog'",
      exitCode = 0,
      stdout = [[{"name":"monolog/monolog","version":"3.8.0","description":"Installed Monolog","homepage":"https://github.com/Seldaek/monolog","versions":["3.8.0"]}]],
      stderr = "",
      success = true,
    },
    {
      match = "COMPOSER_HOME='./.reqpack-test/fixtures/cache-root/home' COMPOSER_CACHE_DIR='./.reqpack-test/fixtures/cache-root/cache' COMPOSER_NO_INTERACTION='1' COMPOSER_ALLOW_SUPERUSER='1' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' composer show --all --format json 'monolog/monolog'",
      exitCode = 0,
      stdout = [[{"name":"monolog/monolog","description":"Sends your logs to files, sockets, inboxes, databases and various web services","keywords":["log","logging"],"type":"library","homepage":"https://github.com/Seldaek/monolog","names":["monolog/monolog"],"versions":["3.9.1","3.9.0"],"license":["MIT"],"source":{"type":"git","url":"https://github.com/Seldaek/monolog.git","reference":"abc123"},"latest":"3.9.1"}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    commands = {
      "command -v 'composer' >/dev/null 2>&1",
      "COMPOSER_HOME='./.reqpack-test/fixtures/cache-root/home' COMPOSER_CACHE_DIR='./.reqpack-test/fixtures/cache-root/cache' COMPOSER_NO_INTERACTION='1' COMPOSER_ALLOW_SUPERUSER='1' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' composer global show --format json 'monolog/monolog'",
      "COMPOSER_HOME='./.reqpack-test/fixtures/cache-root/home' COMPOSER_CACHE_DIR='./.reqpack-test/fixtures/cache-root/cache' COMPOSER_NO_INTERACTION='1' COMPOSER_ALLOW_SUPERUSER='1' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' composer show --all --format json 'monolog/monolog'"
    },
    resultCount = 1,
    resultName = "monolog/monolog",
    resultVersion = "3.8.0",
  },
}
