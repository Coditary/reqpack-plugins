return {
  name = "shards list dependencies",
  request = {
    action = "list",
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
    {
      path = "project/shard.lock",
      content = [[
version: 2.0

shards:
  kemal:
    github: kemalcr/kemal
    version: 1.11.0
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
      match = "cd '${fixtureRoot}/project' && SHARDS_CACHE_PATH='/home/test/.cache/reqpack/shards/shards-cache' SHARDS_INSTALL_PATH='${fixtureRoot}/project/lib' shards list --no-color",
      exitCode = 0,
      stdout = "kemal (1.11.0)\nradix (0.4.1)\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "kemal",
    resultVersion = "1.11.0",
    events = { "listed" },
  },
}
