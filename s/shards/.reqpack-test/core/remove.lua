return {
  name = "shards remove dependency",
  request = {
    action = "remove",
    system = "shards",
    flags = { "dir=${fixtureRoot}/project" },
    packages = {
      { name = "kemal" }
    },
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
  radix:
    github: luislavena/radix
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
      match = "cd '${fixtureRoot}/project' && SHARDS_CACHE_PATH='/home/test/.cache/reqpack/shards/shards-cache' SHARDS_INSTALL_PATH='${fixtureRoot}/project/lib' shards install --no-color",
      exitCode = 0,
      stdout = "Resolving dependencies\n",
      stderr = "",
      success = true,
    },
    {
      match = "cd '${fixtureRoot}/project' && SHARDS_CACHE_PATH='/home/test/.cache/reqpack/shards/shards-cache' SHARDS_INSTALL_PATH='${fixtureRoot}/project/lib' shards prune --no-color",
      exitCode = 0,
      stdout = "Pruning lib\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
