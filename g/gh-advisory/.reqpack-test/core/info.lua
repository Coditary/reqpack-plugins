return {
  name = "gh-advisory info",
  request = {
    action = "info",
    system = "gh-advisory",
    prompt = "github-advisories",
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "github-advisories",
    resultVersion = "0.1.0",
  },
}
