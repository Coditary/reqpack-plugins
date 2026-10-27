return {
  name = "luarocks install local invalid artifact",
  request = {
    action = "install",
    system = "luarocks",
    localPath = "/tmp/pkg/luasocket.zip",
  },
  expect = {
    success = false,
    events = { "failed" },
    eventPayloads = {
      failed = "unsupported local file extension; supported: .rockspec, .src.rock, .rock",
    },
  }
}
