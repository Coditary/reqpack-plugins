return {
  name = "kpm search maven central",
  request = {
    action = "search",
    system = "kpm",
    prompt = "kotlin stdlib",
  },
  fakeExec = {
    {
      match = "mkdir -p '.reqpack-data/kpm/search'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL -H 'Accept: application/json' 'https://search.maven.org/solrsearch/select?rows=10&wt=json&q=kotlin+stdlib' -o '.reqpack-data/kpm/search/kotlin_stdlib.json'",
      exitCode = 0,
      stdout = [[{"response":{"docs":[{"g":"org.jetbrains.kotlin","a":"kotlin-stdlib","latestVersion":"2.2.1"}]}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "org.jetbrains.kotlin:kotlin-stdlib",
    resultVersion = "2.2.1",
  },
}
