return {
  name = "stack update managed remote package",
  fixtureRoot = "/tmp/opencode/stack-update-case",
  request = {
    action = "update",
    system = "stack",
    flags = { "cache-root=/tmp/opencode/stack-update-case/fixtures/cache-root" },
    packages = {
      { name = "warp" }
    },
  },
  fixtureDirs = {
    "fixtures/cache-root/state",
  },
  fixtureFiles = {
    {
      path = "fixtures/cache-root/state/installed.tsv",
      content = "warp\t3.4.8\tremote\twarp\twarp\tWarp web server\tMIT\thttps://example.com/warp\n",
    },
  },
  fakeExec = {
    {
      match = "command -v 'stack' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/stack-update-case/fixtures/cache-root/state/installed.tsv'",
      exitCode = 0,
      stdout = "warp\t3.4.8\tremote\twarp\twarp\tWarp web server\tMIT\thttps://example.com/warp\n",
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
    {
      match = "STACK_ROOT='/tmp/opencode/stack-update-case/fixtures/cache-root/stack-root' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' stack --color never --local-bin-path /tmp/opencode/stack-update-case/fixtures/cache-root/bin install warp-3.4.9",
      exitCode = 0,
      stdout = "Installed warp\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/opencode/stack-update-case/fixtures/cache-root/state/installed.tsv'",
      "command -v 'stack' >/dev/null 2>&1",
      "command -v 'curl' >/dev/null 2>&1",
      "cat '/tmp/opencode/stack-update-case/fixtures/cache-root/query/versions/warp.json'",
      "curl -fsSL -H 'Accept: application/json' 'https://hackage.haskell.org/package/warp'",
      "cat '/tmp/opencode/stack-update-case/fixtures/cache-root/query/cabal/warp-3.4.9.cabal'",
      "curl -fsSL 'https://hackage.haskell.org/package/warp-3.4.9/warp.cabal'",
      "STACK_ROOT='/tmp/opencode/stack-update-case/fixtures/cache-root/stack-root' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' stack --color never --local-bin-path /tmp/opencode/stack-update-case/fixtures/cache-root/bin install warp-3.4.9"
    },
    events = { "updated", "success" },
  },
}
