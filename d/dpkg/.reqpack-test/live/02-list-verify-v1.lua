return {
  name = "live list verifies fixture v1",
  request = {
    action = "list",
    system = "dpkg",
  },
  expect = {
    success = true,
    minItems = 1,
    containsName = "reqpack-live-fixture",
    versionEquals = "1.0",
  },
}
