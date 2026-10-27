return {
  name = "stack outdated managed remote package",
  fixtureRoot = "/tmp/opencode/stack-outdated-case",
  request = {
    action = "outdated",
    system = "stack",
    flags = { "cache-root=/tmp/opencode/stack-outdated-case/fixtures/cache-root" },
  },
  fixtureDirs = {
    "fixtures/cache-root/state",
  },
  fixtureFiles = {
    {
      path = "fixtures/cache-root/state/installed.tsv",
      content = "tool\t0.1.0\tlocal\t/tmp/opencode/stack-outdated-case/fixtures/local-tool\ttool\tLocal tool\tMIT\thttps://example.com/tool\nwarp\t3.4.8\tremote\twarp\twarp\tWarp web server\tMIT\thttps://example.com/warp\n",
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/stack-outdated-case/fixtures/cache-root/state/installed.tsv'",
      exitCode = 0,
      stdout = "tool\t0.1.0\tlocal\t/tmp/opencode/stack-outdated-case/fixtures/local-tool\ttool\tLocal tool\tMIT\thttps://example.com/tool\nwarp\t3.4.8\tremote\twarp\twarp\tWarp web server\tMIT\thttps://example.com/warp\n",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'curl' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL -H 'Accept: application/json' 'https://hackage.haskell.org/package/warp'",
      exitCode = 0,
      stdout = [[{"3.4.8":"normal","3.4.9":"normal"}]],
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://hackage.haskell.org/package/warp-3.4.9/warp.cabal'",
      exitCode = 0,
      stdout = "name: warp\nversion: 3.4.9\nsynopsis: Warp web server\nlicense: MIT\nhomepage: https://example.com/warp\nexecutable warp\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/opencode/stack-outdated-case/fixtures/cache-root/state/installed.tsv'",
      "command -v 'curl' >/dev/null 2>&1",
      "cat '/tmp/opencode/stack-outdated-case/fixtures/cache-root/query/versions/warp.json'",
      "curl -fsSL -H 'Accept: application/json' 'https://hackage.haskell.org/package/warp'",
      "cat '/tmp/opencode/stack-outdated-case/fixtures/cache-root/query/cabal/warp-3.4.9.cabal'",
      "curl -fsSL 'https://hackage.haskell.org/package/warp-3.4.9/warp.cabal'"
    },
    resultCount = 1,
    resultName = "warp",
    resultVersion = "3.4.8",
    events = { "outdated" },
  },
}
