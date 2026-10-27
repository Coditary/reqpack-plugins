return {
  name = "sbt search Maven Central",
  fixtureRoot = "/tmp/opencode/sbt-search-case",
  request = {
    action = "search",
    system = "sbt",
    prompt = "cats-core_2.13",
    flags = { "data-root=/tmp/opencode/sbt-search-case/.reqpack-data", "limit=2" },
  },
  fixtureDirs = {
    ".reqpack-data",
    ".reqpack-data/query/search",
    ".reqpack-data/query/info",
  },
  fakeExec = {
    {
      match = "command -v curl >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL -H 'Accept: application/json' 'https://search.maven.org/solrsearch/select?rows=2&wt=json&q=cats-core_2.13'",
      exitCode = 0,
      stdout = [[{"response":{"docs":[{"id":"org.typelevel:cats-core_2.13","g":"org.typelevel","a":"cats-core_2.13","latestVersion":"2.12.0","p":"jar"},{"id":"org.typelevel:cats-effect_2.13","g":"org.typelevel","a":"cats-effect_2.13","latestVersion":"3.5.7","p":"jar"}]}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "org.typelevel:cats-core_2.13",
    resultVersion = "2.12.0",
  }
}
