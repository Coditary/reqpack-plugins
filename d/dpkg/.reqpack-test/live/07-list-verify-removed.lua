return {
  name = "live list after remove excludes fixture",
  request = {
    action = "list",
    system = "dpkg",
  },
  expect = {
    success = true,
    notContainsName = "reqpack-live-fixture",
  },
}
