return {
  name = "snyk info",
  request = {
    action = "info",
    system = "snyk",
    prompt = "maven",
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "maven",
    resultVersion = "0.1.0",
  },
}
