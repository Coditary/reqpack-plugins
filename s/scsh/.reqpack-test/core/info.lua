return {
  name = "scsh info merge installed and catalog",
  fixtureRoot = "/tmp/opencode/scsh-info-case",
  request = {
    action = "info",
    system = "scsh",
    prompt = "foo",
    flags = { "data-root=/tmp/opencode/scsh-info-case/.reqpack-data" },
  },
  fixtureDirs = {
    ".reqpack-data/scsh/state",
    ".reqpack-data/scsh/cache",
  },
  fixtureFiles = {
    { path = ".reqpack-data/scsh/state/installed.tsv", content = "foo\t1.0.0\t/tmp/opencode/scsh-info-case/.reqpack-data/scsh/home/packages/foo\tremote\tfoo\t2026-05-31T00:00:00Z\tcatalog-main\n" },
    { path = ".reqpack-data/scsh/cache/catalog.tsv", content = "foo\t2.0.0\tFoo package\thttps://example.test/foo\thttps://example.test/foo\tMIT\n" },
  },
  fakeExec = {
    { match = "cat '/tmp/opencode/scsh-info-case/.reqpack-data/scsh/state/installed.tsv'", exitCode = 0, stdout = "foo\t1.0.0\t/tmp/opencode/scsh-info-case/.reqpack-data/scsh/home/packages/foo\tremote\tfoo\t2026-05-31T00:00:00Z\tcatalog-main\n", stderr = "", success = true },
    { match = "test -f '/tmp/opencode/scsh-info-case/.reqpack-data/scsh/cache/catalog.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '/tmp/opencode/scsh-info-case/.reqpack-data/scsh/cache/catalog.tsv'", exitCode = 0, stdout = "foo\t2.0.0\tFoo package\thttps://example.test/foo\thttps://example.test/foo\tMIT\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    resultName = "foo",
    resultVersion = "1.0.0",
    events = { "informed" },
  },
}
