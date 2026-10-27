return {
  name = "shards install local dependency",
  request = {
    action = "install",
    system = "shards",
    flags = { "dir=${fixtureRoot}/project" },
    localPath = "${fixtureRoot}/localdep",
  },
  fixtureDirs = {
    "project",
    "localdep",
  },
  fixtureFiles = {
    {
      path = "project/shard.yml",
      content = [[
name: demo
version: 0.1.0
]],
    },
    {
      path = "localdep/shard.yml",
      content = [[
name: localdep
version: 0.1.0
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
      stdout = "Resolving dependencies\nInstalling localdep (0.1.0)\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
