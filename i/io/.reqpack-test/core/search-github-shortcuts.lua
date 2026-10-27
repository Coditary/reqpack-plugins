return {
  name = "io search github shortcut target",
  request = {
    action = "search",
    system = "io",
    prompt = "gh:IoLanguage/Range",
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "Range",
    eventPayloads = {
      searched = "{1=<lua-value>}",
    },
  },
}
