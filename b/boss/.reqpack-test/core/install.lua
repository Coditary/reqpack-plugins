return {
  name = "boss install remote dependency",
  request = {
    action = "install",
    system = "boss",
    flags = { "cache-root=./.reqpack-test/fixtures/cache-root" },
    packages = {
      { name = "github.com/HashLoad/horse", version = "^3.0.0" }
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
    {
      path = ".reqpack-test/fixtures/cache-root/home/cache/info/horse.json",
      content = [[{"key":"horsehash","name":"github.com/HashLoad/horse","last_update":"2026-05-30T12:00:00Z","versions":["3.0.0","3.0.1","3.1.0"]}]],
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
      match = "BOSS_HOME='./.reqpack-test/fixtures/cache-root/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' boss install github.com/HashLoad/horse@^3.0.0",
      exitCode = 0,
      stdout = "installed horse\n",
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
      match = "ls -1A './.reqpack-test/fixtures/cache-root/home/cache/info'",
      exitCode = 0,
      stdout = "horse.json\n",
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
      match = "cat './.reqpack-test/fixtures/cache-root/home/cache/info/horse.json'",
      exitCode = 0,
      stdout = [[{"key":"horsehash","name":"github.com/HashLoad/horse","last_update":"2026-05-30T12:00:00Z","versions":["3.0.0","3.0.1","3.1.0"]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    commands = {
      "command -v 'boss' >/dev/null 2>&1",
      "BOSS_HOME='./.reqpack-test/fixtures/cache-root/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' boss install github.com/HashLoad/horse@^3.0.0",
      "cat './boss.json'",
      "cat './boss-lock.json'",
      "ls -1A './.reqpack-test/fixtures/cache-root/home/cache/info'",
      "cat './.reqpack-test/fixtures/cache-root/home/cache/info/horse.json'"
    },
  },
}
