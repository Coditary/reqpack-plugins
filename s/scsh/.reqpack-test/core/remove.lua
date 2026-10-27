return {
  name = "scsh remove tracked package",
  fixtureRoot = "/tmp/opencode/scsh-remove-case",
  request = {
    action = "remove",
    system = "scsh",
    flags = { "data-root=/tmp/opencode/scsh-remove-case/.reqpack-data" },
    packages = {
      { name = "foo" }
    },
  },
  fixtureDirs = {
    ".reqpack-data/scsh/home/packages/foo",
    ".reqpack-data/scsh/state",
  },
  fixtureFiles = {
    { path = ".reqpack-data/scsh/state/installed.tsv", content = "foo\t1.0.0\t/tmp/opencode/scsh-remove-case/.reqpack-data/scsh/home/packages/foo\tremote\tfoo\t2026-05-31T00:00:00Z\t\n" },
  },
  fakeExec = {
    { match = "cat '/tmp/opencode/scsh-remove-case/.reqpack-data/scsh/state/installed.tsv'", exitCode = 0, stdout = "foo\t1.0.0\t/tmp/opencode/scsh-remove-case/.reqpack-data/scsh/home/packages/foo\tremote\tfoo\t2026-05-31T00:00:00Z\t\n", stderr = "", success = true },
    { match = "rm -rf '/tmp/opencode/scsh-remove-case/.reqpack-data/scsh/home/packages/foo'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/scsh-remove-case/.reqpack-data/scsh/state'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s '' > '/tmp/opencode/scsh-remove-case/.reqpack-data/scsh/state/installed.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    result = true,
    events = { "deleted", "success" },
  },
}
