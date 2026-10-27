return {
  name = "foundry install local unsupported",
  request = {
    action = "installLocal",
    system = "foundry",
    localPath = "/tmp/opencode/foundry-local-case/pkg",
  },
  expect = {
    success = false,
    events = { "failed" },
  },
}
