return {
  name = "leiningen list local repo artifacts",
  request = {
    action = "list",
    system = "leiningen",
    flags = {
      "repo-root=/tmp/opencode/leiningen-list/repository",
      "cache-root=/tmp/opencode/leiningen-list/cache",
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/leiningen-list/cache/state/installed.tsv'",
      exitCode = 1,
      stdout = "",
      stderr = "missing",
      success = false,
    },
    {
      match = "find '/tmp/opencode/leiningen-list/repository' -type f \\( -name '*.pom' -o -name '*.jar' \\)",
      exitCode = 0,
      stdout = "/tmp/opencode/leiningen-list/repository/ring/ring-json/0.5.1/ring-json-0.5.1.pom\n/tmp/opencode/leiningen-list/repository/ring/ring-json/0.5.1/ring-json-0.5.1.jar\n",
      stderr = "",
      success = true,
    },
    {
      match = "test -e '/tmp/opencode/leiningen-list/repository/ring/ring-json/0.5.1/ring-json-0.5.1.pom'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -e '/tmp/opencode/leiningen-list/repository/ring/ring-json/0.5.1/ring-json-0.5.1.jar'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = [[mkdir -p '/tmp/opencode/leiningen-list/cache/state' && printf %s 'ring/ring-json	ring	0.5.1	/tmp/opencode/leiningen-list/repository	true	true
' > '/tmp/opencode/leiningen-list/cache/state/installed.tsv']],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "ring/ring-json",
    resultVersion = "0.5.1",
    events = { "listed" },
  },
}
