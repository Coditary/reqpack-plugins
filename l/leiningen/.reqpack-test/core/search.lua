return {
  name = "leiningen search parses results",
  request = {
    action = "search",
    system = "leiningen",
    prompt = "json",
    flags = { "cache-root=/tmp/opencode/leiningen-search/cache" },
  },
  fakeExec = {
    {
      match = "command -v 'lein' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/leiningen-search/cache/search/json.txt'",
      exitCode = 1,
      stdout = "",
      stderr = "missing",
      success = false,
    },
    {
      match = "lein search 'json'",
      exitCode = 0,
      stdout = "Searching central ...\n[com.jwebmp/json \"0.63.0.60\"]\nSearching clojars ...\n[ring/ring-json \"0.5.1\"]\n  Ring middleware for handling JSON\n",
      stderr = "",
      success = true,
    },
    {
      match = [[mkdir -p '/tmp/opencode/leiningen-search/cache/search' && printf %s 'Searching central ...
[com.jwebmp/json "0.63.0.60"]
Searching clojars ...
[ring/ring-json "0.5.1"]
  Ring middleware for handling JSON
' > '/tmp/opencode/leiningen-search/cache/search/json.txt']],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "com.jwebmp/json",
    resultVersion = "0.63.0.60",
    events = { "searched" },
  },
}
