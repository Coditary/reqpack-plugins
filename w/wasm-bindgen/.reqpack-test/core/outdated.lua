return {
  name = "wasm-bindgen outdated",
  request = {
    action = "outdated",
    system = "wasm-bindgen",
  },
  fakeExec = {},
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  }
}
