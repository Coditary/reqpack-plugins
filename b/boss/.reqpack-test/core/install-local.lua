return {
  name = "boss install local project dependencies",
  request = {
    action = "installLocal",
    system = "boss",
    localPath = "./fixtures/local-project",
    flags = { "cache-root=./.reqpack-test/fixtures/cache-root" },
  },
  fixtureFiles = {
    {
      path = "fixtures/local-project/boss.json",
      content = [[{"name":"local-lib","version":"0.2.0","dependencies":{"github.com/HashLoad/horse":"^3.0.0"}}]],
    },
    {
      path = "fixtures/local-project/boss-lock.json",
      content = [[{"hash":"def","updated":"2026-05-30T12:00:00Z","installedModules":{"github.com/hashload/horse":{"name":"horse","version":"3.0.1","hash":"horsehash","artifacts":{}}}}]],
    },
  },
  fakeExec = {
    {
      match = "command -v 'boss' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -e './fixtures/local-project/boss.json' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd './fixtures/local-project' && BOSS_HOME='./.reqpack-test/fixtures/cache-root/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' boss install",
      exitCode = 0,
      stdout = "restored local deps\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat './fixtures/local-project/boss.json'",
      exitCode = 0,
      stdout = [[{"name":"local-lib","version":"0.2.0","dependencies":{"github.com/HashLoad/horse":"^3.0.0"}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    commands = {
      "command -v 'boss' >/dev/null 2>&1",
      "test -e './fixtures/local-project/boss.json' >/dev/null 2>&1",
      "cd './fixtures/local-project' && BOSS_HOME='./.reqpack-test/fixtures/cache-root/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' boss install",
      "cat './fixtures/local-project/boss.json'"
    },
  },
}
