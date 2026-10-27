return {
  name = "stack info Hackage package",
  request = {
    action = "info",
    system = "stack",
    prompt = "warp",
    flags = { "cache-root=${fixtureRoot}/fixtures/cache-root" },
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
      match = "curl -fsSL -H 'Accept: application/json' 'https://hackage.haskell.org/package/warp'",
      exitCode = 0,
      stdout = [[{"3.4.9":"normal"}]],
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://hackage.haskell.org/package/warp-3.4.9/warp.cabal'",
      exitCode = 0,
      stdout = "name: warp\nversion: 3.4.9\nsynopsis: Warp web server\ndescription: Fast web server\nlicense: MIT\nhomepage: https://example.com/warp\nauthor: Example Author\nmaintainer: Example Maintainer\nsource-repository head\n  location: https://github.com/example/warp\nbuild-depends: base, wai\nexecutable warp\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "warp",
    resultVersion = "3.4.9",
    events = { "informed" },
  },
}
