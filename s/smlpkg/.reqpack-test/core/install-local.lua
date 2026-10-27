return {
  name = "smlpkg install local unsupported",
  request = {
    action = "install",
    system = "smlpkg",
    localPath = "/tmp/opencode/example.smlpkg",
  },
  expect = {
    success = false,
    events = { "failed" },
    eventPayloads = {
      failed = "smlpkg does not support local artifact installs",
    },
  },
}
