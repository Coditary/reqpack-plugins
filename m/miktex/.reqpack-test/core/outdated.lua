return {
  name = "miktex outdated update signal only",
  request = {
    action = "outdated",
    system = "miktex",
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/miktex-outdated-case",
  },
  fakeExec = {
    {
      match = "command -v miktex 2>/dev/null",
      exitCode = 0,
      stdout = "/usr/bin/miktex\n",
      stderr = "",
      success = true,
    },
    {
      match = "/usr/bin/miktex packages check-update",
      exitCode = 100,
      stdout = "updates available\n",
      stderr = "",
      success = false,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  },
}
