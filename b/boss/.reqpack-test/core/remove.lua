return {
  name = "boss remove dependency",
  request = {
    action = "remove",
    system = "boss",
    flags = { "cache-root=./.reqpack-test/fixtures/cache-root" },
    packages = {
      { name = "github.com/HashLoad/horse" }
    },
  },
  fixtureFiles = {
    {
      path = "boss.json",
      content = [[{"name":"demo-app","version":"1.0.0","dependencies":{"github.com/HashLoad/horse":"^3.0.0"}}]],
    },
    {
      path = "boss-lock.json",
      content = [[{"hash":"abc","updated":"2026-05-30T12:00:00Z","installedModules":{"github.com/hashload/horse":{"name":"horse","version":"3.0.1","hash":"horsehash","artifacts":{}}}}]],
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
      match = "cat './boss.json'",
      exitCode = 0,
      stdout = [[{"name":"demo-app","version":"1.0.0","dependencies":{"github.com/HashLoad/horse":"^3.0.0"}}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat './boss-lock.json'",
      exitCode = 0,
      stdout = [[{"hash":"abc","updated":"2026-05-30T12:00:00Z","installedModules":{"github.com/hashload/horse":{"name":"horse","version":"3.0.1","hash":"horsehash","artifacts":{}}}}]],
      stderr = "",
      success = true,
    },
    {
      match = "ls -1A './.reqpack-test/fixtures/cache-root/home/cache/info'",
      exitCode = 1,
      stdout = "",
      stderr = "missing",
      success = false,
    },
    {
      match = "BOSS_HOME='./.reqpack-test/fixtures/cache-root/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' boss uninstall github.com/HashLoad/horse",
      exitCode = 0,
      stdout = "removed horse\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    commands = {
      "command -v 'boss' >/dev/null 2>&1",
      "cat './boss.json'",
      "cat './boss-lock.json'",
      "ls -1A './.reqpack-test/fixtures/cache-root/home/cache/info'",
      "BOSS_HOME='./.reqpack-test/fixtures/cache-root/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' boss uninstall github.com/HashLoad/horse"
    },
  },
}
