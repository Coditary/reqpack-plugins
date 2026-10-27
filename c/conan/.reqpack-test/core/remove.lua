return {
  name = "conan remove local recipe",
  request = {
    action = "remove",
    system = "conan",
    packages = {
      { name = "zlib/1.3.1" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'conan' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "'conan' 'remove' '--confirm' 'zlib/1.3.1'",
      exitCode = 0,
      stdout = "Removed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'conan' >/dev/null 2>&1",
      "'conan' 'remove' '--confirm' 'zlib/1.3.1'",
    },
    events = { "deleted", "success" },
    eventPayloads = {
      deleted = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
