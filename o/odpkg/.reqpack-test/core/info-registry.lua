return {
  name = "odpkg info registry slug from cache",
  fixtureRoot = "/tmp/opencode/odpkg-info-registry",
  request = {
    action = "info",
    system = "odpkg",
    prompt = "tempo",
    flags = {
      "cache-home=/tmp/opencode/odpkg-info-registry/cache",
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/odpkg-info-registry",
  },
  fixtureFiles = {
    ["cache/odpkg/packages.json"] = "[{\"id\":1,\"slug\":\"tempo\",\"display_name\":\"Tempo\",\"description\":\"Timing utilities for Odin\",\"type\":\"library\",\"status\":\"active\",\"repository_url\":\"https://github.com/kalsprite/tempo\",\"license\":\"MIT\"}]",
  },
  fakeExec = {
    { match = "cat './odpkg.toml'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "cat '/tmp/opencode/odpkg-info-registry/cache/odpkg/packages.json'", exitCode = 0, stdout = "[{\"id\":1,\"slug\":\"tempo\",\"display_name\":\"Tempo\",\"description\":\"Timing utilities for Odin\",\"type\":\"library\",\"status\":\"active\",\"repository_url\":\"https://github.com/kalsprite/tempo\",\"license\":\"MIT\"}]", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "tempo",
  },
}
