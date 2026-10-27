return {
  name = "bundler list from Gemfile.lock",
  request = {
    action = "list",
    system = "bundler",
    flags = { "dir=./.reqpack-test/fixtures/project" },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "rack",
    resultVersion = "3.1.7",
  },
}
