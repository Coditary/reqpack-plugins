return {
  name = "odpkg list registry packages",
  fixtureRoot = "/tmp/opencode/odpkg-list-registry",
  request = {
    action = "list",
    system = "odpkg",
    flags = {
      "registry",
      "cache-home=/tmp/opencode/odpkg-list-registry/cache",
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/odpkg-list-registry",
  },
  fakeExec = {
    { match = "command -v 'odpkg' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C XDG_CACHE_HOME='/tmp/opencode/odpkg-list-registry/cache' odpkg list --registry", exitCode = 0, stdout = "tempo | https://github.com/kalsprite/tempo | active\nraylib | https://github.com/raysan5/raylib | active\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "tempo",
  },
}
