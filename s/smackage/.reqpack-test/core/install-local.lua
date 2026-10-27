return {
  name = "smackage install local unsupported",
  request = {
    action = "install",
    system = "smackage",
    localPath = "/tmp/opencode/local-smackage-package",
  },
  expect = {
    success = false,
    events = { "failed" },
    eventPayloads = {
      failed = "smackage does not support local artifact installs",
    },
  },
}
