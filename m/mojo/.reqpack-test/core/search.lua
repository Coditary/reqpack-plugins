return {
  name = "mojo search synthetic result",
  request = {
    action = "search",
    system = "mojo",
    flags = {
      "modular-home=/home/test/.modular",
    },
    prompt = "modular",
  },
  fakeExec = {},
  expect = {
    success = true,
    resultCount = 1,
    resultName = "mojo",
    events = { "searched" },
  },
}
