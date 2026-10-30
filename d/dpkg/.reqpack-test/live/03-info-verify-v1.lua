return {
  name = "live info verifies fixture v1",
  request = {
    action = "info",
    system = "dpkg",
    prompt = "reqpack-live-fixture",
  },
  expect = {
    success = true,
    containsName = "reqpack-live-fixture",
  },
}
