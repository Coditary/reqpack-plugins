return {
  name = "scsh outdated empty without catalog",
  fixtureRoot = "/tmp/opencode/scsh-outdated-case",
  request = {
    action = "outdated",
    system = "scsh",
    flags = { "data-root=/tmp/opencode/scsh-outdated-case/.reqpack-data" },
  },
  fixtureDirs = {
    ".reqpack-data/scsh/state",
  },
  fixtureFiles = {
    { path = ".reqpack-data/scsh/state/installed.tsv", content = "foo\t1.0.0\t/tmp/opencode/scsh-outdated-case/.reqpack-data/scsh/home/packages/foo\tremote\tfoo\t2026-05-31T00:00:00Z\t\n" },
  },
  fakeExec = {
    { match = "cat '/tmp/opencode/scsh-outdated-case/.reqpack-data/scsh/state/installed.tsv'", exitCode = 0, stdout = "foo\t1.0.0\t/tmp/opencode/scsh-outdated-case/.reqpack-data/scsh/home/packages/foo\tremote\tfoo\t2026-05-31T00:00:00Z\t\n", stderr = "", success = true },
    { match = "test -f '/tmp/opencode/scsh-outdated-case/.reqpack-data/scsh/cache/catalog.tsv'", exitCode = 1, stdout = "", stderr = "", success = false },
  },
  expect = {
    success = true,
    resultCount = 0,
    events = { "outdated" },
  },
}
