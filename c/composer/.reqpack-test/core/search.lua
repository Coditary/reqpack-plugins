return {
  name = "composer search packages",
  request = {
    action = "search",
    system = "composer",
    prompt = "monolog",
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
      match = "COMPOSER_HOME='./.reqpack-test/fixtures/cache-root/home' COMPOSER_CACHE_DIR='./.reqpack-test/fixtures/cache-root/cache' COMPOSER_NO_INTERACTION='1' COMPOSER_ALLOW_SUPERUSER='1' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' composer search --format json 'monolog'",
      exitCode = 0,
      stdout = [=[[{"name":"monolog/monolog","description":"Sends your logs to files","url":"https://packagist.org/packages/monolog/monolog"}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "monolog/monolog",
  },
}
