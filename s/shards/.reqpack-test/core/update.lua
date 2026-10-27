return {
  name = "shards update dependency",
  request = {
    action = "update",
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
      match = "cd '${fixtureRoot}/project' && SHARDS_CACHE_PATH='/home/test/.cache/reqpack/shards/shards-cache' SHARDS_INSTALL_PATH='${fixtureRoot}/project/lib' shards update kemal --no-color",
      exitCode = 0,
      stdout = "Resolving dependencies\nInstalling kemal (1.11.0)\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  },
}
