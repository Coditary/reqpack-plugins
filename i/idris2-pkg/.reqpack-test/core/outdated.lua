return {
  name = "idris2-pkg outdated empty by design",
  request = {
    action = "outdated",
    system = "idris2-pkg",
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  },
}
