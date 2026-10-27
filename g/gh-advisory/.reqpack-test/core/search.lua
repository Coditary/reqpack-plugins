return {
  name = "gh-advisory search",
  request = {
    action = "search",
    system = "gh-advisory",
    prompt = "github",
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "github-advisories",
    resultVersion = "0.1.0",
  },
}
