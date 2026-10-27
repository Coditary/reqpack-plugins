return {
  name = "snyk list",
  request = {
    action = "list",
    system = "snyk",
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "maven",
    resultVersion = "0.1.0",
  },
}
