return {
  name = "stack search Hackage packages",
  request = {
    action = "search",
    system = "stack",
    prompt = "warp",
    flags = { "cache-root=${fixtureRoot}/fixtures/cache-root", "limit=2" },
  },
  fixtureDirs = {
    "fixtures/cache-root",
  },
  fakeExec = {
    {
      match = "command -v 'curl' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL -H 'Accept: application/json' 'https://hackage.haskell.org/packages/search?terms=warp'",
      exitCode = 0,
      stdout = [=[[{"name":"warp"},{"name":"warp-tls"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL -H 'Accept: application/json' 'https://hackage.haskell.org/package/warp'",
      exitCode = 0,
      stdout = [[{"3.4.9":"normal"}]],
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://hackage.haskell.org/package/warp-3.4.9/warp.cabal'",
      exitCode = 0,
      stdout = "name: warp\nversion: 3.4.9\nsynopsis: Warp web server\nlicense: MIT\nhomepage: https://example.com/warp\n",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL -H 'Accept: application/json' 'https://hackage.haskell.org/package/warp-tls'",
      exitCode = 0,
      stdout = [[{"3.4.0":"normal"}]],
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://hackage.haskell.org/package/warp-tls-3.4.0/warp-tls.cabal'",
      exitCode = 0,
      stdout = "name: warp-tls\nversion: 3.4.0\nsynopsis: Warp TLS support\nlicense: MIT\nhomepage: https://example.com/warp-tls\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "warp",
    resultVersion = "3.4.9",
    events = { "searched" },
  },
}
