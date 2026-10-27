return {
  name = "scsh search cached catalog",
  fixtureRoot = "/tmp/opencode/scsh-search-case",
  request = {
    action = "search",
    system = "scsh",
    prompt = "fo",
    flags = { "data-root=/tmp/opencode/scsh-search-case/.reqpack-data" },
  },
  fixtureDirs = {
    ".reqpack-data/scsh/cache",
  },
  fixtureFiles = {
    { path = ".reqpack-data/scsh/cache/catalog.tsv", content = "foo\t2.0.0\tFoo package\thttps://example.test/foo\thttps://example.test/foo\tMIT\nbar\t1.0.0\tBar package\thttps://example.test/bar\thttps://example.test/bar\tMIT\n" },
  },
  fakeExec = {
    { match = "cat '/tmp/opencode/scsh-search-case/.reqpack-data/scsh/state/installed.tsv'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -f '/tmp/opencode/scsh-search-case/.reqpack-data/scsh/cache/catalog.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '/tmp/opencode/scsh-search-case/.reqpack-data/scsh/cache/catalog.tsv'", exitCode = 0, stdout = "foo\t2.0.0\tFoo package\thttps://example.test/foo\thttps://example.test/foo\tMIT\nbar\t1.0.0\tBar package\thttps://example.test/bar\thttps://example.test/bar\tMIT\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "foo",
    resultVersion = "2.0.0",
    events = { "searched" },
  },
}
