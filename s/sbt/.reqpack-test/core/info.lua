return {
  name = "sbt info Maven Central dependency",
  fixtureRoot = "/tmp/opencode/sbt-info-case",
  request = {
    action = "info",
    system = "sbt",
    prompt = "org.typelevel:cats-core_2.13",
    flags = { "data-root=/tmp/opencode/sbt-info-case/.reqpack-data" },
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
      match = "curl -fsSL -H 'Accept: application/json' 'https://search.maven.org/solrsearch/select?rows=1&wt=json&q=g%3A%22org.typelevel%22%20AND%20a%3A%22cats-core_2.13%22'",
      exitCode = 0,
      stdout = [[{"response":{"docs":[{"id":"org.typelevel:cats-core_2.13","g":"org.typelevel","a":"cats-core_2.13","latestVersion":"2.12.0","p":"jar","timestamp":1731000000000}]}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "org.typelevel:cats-core_2.13",
    resultVersion = "2.12.0",
  }
}
