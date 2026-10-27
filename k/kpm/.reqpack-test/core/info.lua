return {
  name = "kpm info exact maven lookup",
  request = {
    action = "info",
    system = "kpm",
    prompt = "org.jetbrains.kotlin:kotlin-stdlib",
  },
  fakeExec = {
    {
      match = "mkdir -p '.reqpack-data/kpm/info'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL -H 'Accept: application/json' 'https://search.maven.org/solrsearch/select?rows=1&wt=json&q=g:%22org.jetbrains.kotlin%22%20AND%20a:%22kotlin-stdlib%22' -o '.reqpack-data/kpm/info/org.jetbrains.kotlin__kotlin-stdlib.json'",
      exitCode = 0,
      stdout = [[{"response":{"docs":[{"g":"org.jetbrains.kotlin","a":"kotlin-stdlib","latestVersion":"2.2.1"}]}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "org.jetbrains.kotlin:kotlin-stdlib",
    resultVersion = "2.2.1",
  },
}
