return {
  name = "smackage remove unsupported",
  request = {
    action = "remove",
    system = "smackage",
    packages = {
      { action = "remove", name = "cmlib" }
    },
  },
  expect = {
    success = false,
    events = { "failed" },
    eventPayloads = {
      failed = "smackage does not support package removal",
    },
  },
}
