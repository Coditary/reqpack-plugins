return {
  name = "stack remove managed package",
  request = {
    action = "remove",
    system = "stack",
    flags = { "cache-root=${fixtureRoot}/fixtures/cache-root" },
    packages = {
      { name = "warp" }
    },
  },
  fixtureDirs = {
    "fixtures/cache-root/state",
    "fixtures/cache-root/bin",
  },
  fixtureFiles = {
    {
      path = "fixtures/cache-root/state/installed.tsv",
      content = "warp\t3.4.9\tremote\twarp\twarp\tWarp web server\tMIT\thttps://example.com/warp\n",
    },
    {
      path = "fixtures/cache-root/bin/warp",
      content = "binary\n",
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
