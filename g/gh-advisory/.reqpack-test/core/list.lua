return {
  name = "gh-advisory list",
  request = {
    action = "list",
    system = "gh-advisory",
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "github-advisories",
    resultVersion = "0.1.0",
  },
}
