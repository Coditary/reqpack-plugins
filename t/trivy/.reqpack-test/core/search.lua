return {
  name = "trivy search",
  request = {
    action = "search",
    system = "trivy",
    prompt = "mav",
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "maven",
    resultVersion = "0.1.0",
  },
}
