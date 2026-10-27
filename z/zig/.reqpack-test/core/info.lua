return {
  name = "zig info managed record",
  request = {
    action = "info",
    system = "zig",
    prompt = "https://example.com/demo.tar.gz",
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/zig/records",
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/zig/records/https_example_com_demo_tar_gz.tsv",
      content = "id\thttps://example.com/demo.tar.gz\nname\tdemo\nsourceKind\turl\ntarget\thttps://example.com/demo.tar.gz\nhash\t1220deadbeef\ninstallMode\tfetch\nmirrorPath\t/home/test/.cache/reqpack/zig/sources/https_example_com_demo_tar_gz\nhomepage\thttps://example.com/demo.tar.gz\nflags\t\nupdatedAt\t1\n",
    },
  },
  fakeExec = {
    {
      match = "ls -1A '/home/test/.cache/reqpack/zig/records'",
      exitCode = 0,
      stdout = "https_example_com_demo_tar_gz.tsv\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/test/.cache/reqpack/zig/records/https_example_com_demo_tar_gz.tsv'",
      exitCode = 0,
      stdout = "id\thttps://example.com/demo.tar.gz\nname\tdemo\nsourceKind\turl\ntarget\thttps://example.com/demo.tar.gz\nhash\t1220deadbeef\ninstallMode\tfetch\nmirrorPath\t/home/test/.cache/reqpack/zig/sources/https_example_com_demo_tar_gz\nhomepage\thttps://example.com/demo.tar.gz\nflags\t\nupdatedAt\t1\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultName = "demo",
    resultVersion = "1220deadbeef",
    events = { "informed" },
  }
}
