return {
  name = "stack list managed packages",
  fixtureRoot = "/tmp/opencode/stack-list-case",
  request = {
    action = "list",
    system = "stack",
    flags = { "cache-root=/tmp/opencode/stack-list-case/fixtures/cache-root" },
  },
  fixtureDirs = {
    "fixtures/cache-root/state",
  },
  fixtureFiles = {
    {
      path = "fixtures/cache-root/state/installed.tsv",
      content = "tool\t0.1.0\tlocal\t/tmp/opencode/stack-list-case/fixtures/local-tool\ttool\tLocal tool\tMIT\thttps://example.com/tool\nwarp\t3.4.9\tremote\twarp\twarp\tWarp web server\tMIT\thttps://example.com/warp\n",
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/stack-list-case/fixtures/cache-root/state/installed.tsv'",
      exitCode = 0,
      stdout = "tool\t0.1.0\tlocal\t/tmp/opencode/stack-list-case/fixtures/local-tool\ttool\tLocal tool\tMIT\thttps://example.com/tool\nwarp\t3.4.9\tremote\twarp\twarp\tWarp web server\tMIT\thttps://example.com/warp\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/opencode/stack-list-case/fixtures/cache-root/state/installed.tsv'"
    },
    resultCount = 2,
    resultName = "tool",
    resultVersion = "0.1.0",
    events = { "listed" },
  },
}
