return {
  name = "trivy info",
  request = {
    action = "info",
    system = "trivy",
    prompt = "maven",
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "maven",
    resultVersion = "0.1.0",
  },
}
