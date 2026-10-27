return {
  name = "trivy list",
  request = {
    action = "list",
    system = "trivy",
  },
  expect = {
    success = true,
    resultCount = 4,
    resultName = "maven",
    resultVersion = "0.1.0",
  },
}
