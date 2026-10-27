return {
  name = "leiningen info search fallback",
  request = {
    action = "info",
    system = "leiningen",
    prompt = "ring/ring-json",
    flags = { "repo-root=/tmp/opencode/leiningen-info-miss/repository" },
  },
  fakeExec = {
    {
      match = "ls -1 '/tmp/opencode/leiningen-info-miss/repository/ring/ring-json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing",
      success = false,
    },
    {
      match = "command -v 'lein' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/test/.cache/reqpack/leiningen/search/ring_ring-json.txt'",
      exitCode = 1,
      stdout = "",
      stderr = "missing",
      success = false,
    },
    {
      match = "lein search 'ring/ring-json'",
      exitCode = 0,
      stdout = "Searching clojars ...\n[ring/ring-json \"0.5.1\"]\n  Ring middleware for handling JSON\n",
      stderr = "",
      success = true,
    },
    {
      match = [[mkdir -p '/home/test/.cache/reqpack/leiningen/search' && printf %s 'Searching clojars ...
[ring/ring-json "0.5.1"]
  Ring middleware for handling JSON
' > '/home/test/.cache/reqpack/leiningen/search/ring_ring-json.txt']],
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
    events = { "searched", "informed" },
  },
}
