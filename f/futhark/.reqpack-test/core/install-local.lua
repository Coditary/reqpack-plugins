return {
  name = "futhark install local unsupported",
  request = {
    action = "install",
    system = "futhark",
    localPath = "./local-project",
  },
  expect = {
    success = false,
    events = { "failed" },
  },
}
