return {
  name = "shards install gitlab dependency",
  request = {
    action = "install",
    system = "shards",
    flags = { "dir=${fixtureRoot}/project" },
    packages = {
      { name = "athena", flags = { "gitlab=athena-framework/athena" } }
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
      stdout = "Resolving dependencies\nInstalling athena (0.1.0)\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'shards' >/dev/null 2>&1",
      "cd '${fixtureRoot}/project' && SHARDS_CACHE_PATH='/home/test/.cache/reqpack/shards/shards-cache' SHARDS_INSTALL_PATH='${fixtureRoot}/project/lib' shards install --no-color",
    },
    events = { "installed", "success" },
  },
}
