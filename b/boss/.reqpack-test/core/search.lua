return {
  name = "boss search from manifest and cache",
  request = {
    action = "search",
    system = "boss",
    prompt = "horse",
    flags = { "cache-root=./.reqpack-test/fixtures/cache-root" },
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
    {
      path = ".reqpack-test/fixtures/cache-root/home/cache/info/jhonson.json",
      content = [[{"key":"jhonsonhash","name":"github.com/HashLoad/jhonson","last_update":"2026-05-30T12:00:00Z","versions":["1.0.0"]}]],
    },
  },
  fakeExec = {
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
      exitCode = 0,
      stdout = "horse.json\njhonson.json\n",
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
    {
      match = "cat './.reqpack-test/fixtures/cache-root/home/cache/info/jhonson.json'",
      exitCode = 0,
      stdout = [[{"key":"jhonsonhash","name":"github.com/HashLoad/jhonson","last_update":"2026-05-30T12:00:00Z","versions":["1.0.0"]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "github.com/HashLoad/horse",
  },
}
