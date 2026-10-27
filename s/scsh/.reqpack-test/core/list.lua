return {
  name = "scsh list tracked packages",
  fixtureRoot = "/tmp/opencode/scsh-list-case",
  request = {
    action = "list",
    system = "scsh",
    flags = { "data-root=/tmp/opencode/scsh-list-case/.reqpack-data" },
  },
  fixtureDirs = {
    ".reqpack-data/scsh/state",
  },
  fixtureFiles = {
    { path = ".reqpack-data/scsh/state/installed.tsv", content = "bar\t2.0.0\t/tmp/opencode/scsh-list-case/.reqpack-data/scsh/home/packages/bar\tremote\tbar\t2026-05-31T00:00:00Z\t\nfoo\t1.0.0\t/tmp/opencode/scsh-list-case/.reqpack-data/scsh/home/packages/foo\tremote\tfoo\t2026-05-31T00:00:00Z\t\n" },
  },
  fakeExec = {
    { match = "cat '/tmp/opencode/scsh-list-case/.reqpack-data/scsh/state/installed.tsv'", exitCode = 0, stdout = "bar\t2.0.0\t/tmp/opencode/scsh-list-case/.reqpack-data/scsh/home/packages/bar\tremote\tbar\t2026-05-31T00:00:00Z\t\nfoo\t1.0.0\t/tmp/opencode/scsh-list-case/.reqpack-data/scsh/home/packages/foo\tremote\tfoo\t2026-05-31T00:00:00Z\t\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "bar",
    resultVersion = "2.0.0",
    events = { "listed" },
  },
}
