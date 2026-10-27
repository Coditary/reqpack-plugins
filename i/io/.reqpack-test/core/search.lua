return {
  name = "io search direct repo target",
  request = {
    action = "search",
    system = "io",
    prompt = "IoLanguage/Range",
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "Range",
  },
}
