return {
  name = "odpkg search registry packages",
  fixtureRoot = "/tmp/opencode/odpkg-search",
  request = {
    action = "search",
    system = "odpkg",
    prompt = "temp",
    flags = {
      "cache-home=/tmp/opencode/odpkg-search/cache",
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/odpkg-search",
  },
  fakeExec = {
    { match = "command -v 'odpkg' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C XDG_CACHE_HOME='/tmp/opencode/odpkg-search/cache' odpkg search 'temp'", exitCode = 0, stdout = "tempo | https://github.com/kalsprite/tempo | active\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "tempo",
  },
}
