return {
  name = "shards outdated dependencies",
  request = {
    action = "outdated",
    system = "shards",
    flags = { "dir=${fixtureRoot}/project" },
  },
  fixtureDirs = {
    "project",
  },
  fixtureFiles = {
    {
      path = "project/shard.yml",
      content = [[
name: demo
version: 0.1.0

dependencies:
  kemal:
    github: kemalcr/kemal
]],
    },
  },
  fakeExec = {
    {
      match = "command -v 'shards' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '${fixtureRoot}/project' && SHARDS_CACHE_PATH='/home/test/.cache/reqpack/shards/shards-cache' SHARDS_INSTALL_PATH='${fixtureRoot}/project/lib' shards outdated --no-color",
      exitCode = 0,
      stdout = "W: Outdated dependencies:\n  * kemal (installed: 1.10.0, available: 1.11.0)\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "kemal",
    resultVersion = "1.10.0",
    events = { "outdated" },
  },
}
