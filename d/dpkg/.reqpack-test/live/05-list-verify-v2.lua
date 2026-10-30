return {
  name = "live list verifies fixture v2",
  request = {
    action = "list",
    system = "dpkg",
  },
  expect = {
    success = true,
    containsName = "reqpack-live-fixture",
    versionEquals = "2.0",
  },
}
