return {
  name = "snyk search",
  request = {
    action = "search",
    system = "snyk",
    prompt = "mav",
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "maven",
    resultVersion = "0.1.0",
  },
}
