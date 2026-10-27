return {
  name = "corral list cached dependencies",
  request = {
    action = "list",
    system = "corral",
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/corral/bundle",
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/corral/bundle/corral.json",
      content = [[{"info":{"name":"reqpack-corral-cache"},"packages":[],"deps":[{"locator":"github.com/ponylang/valbytes.git","version":">=0.6.0 <2.0.0"},{"locator":"../pony-inspect","version":""}]}]],
    },
    {
      path = "/home/test/.cache/reqpack/corral/bundle/lock.json",
      content = [[{"locks":[{"locator":"github.com/ponylang/valbytes.git","revision":"a1b2c3d4"},{"locator":"../pony-inspect","revision":""}]}]],
    },
  },
  fakeExec = {
    {
      match = "command -v 'corral' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/test/.cache/reqpack/corral/bundle/corral.json'",
      exitCode = 0,
      stdout = [[{"info":{"name":"reqpack-corral-cache"},"packages":[],"deps":[{"locator":"github.com/ponylang/valbytes.git","version":">=0.6.0 <2.0.0"},{"locator":"../pony-inspect","version":""}]}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/test/.cache/reqpack/corral/bundle/lock.json'",
      exitCode = 0,
      stdout = [[{"locks":[{"locator":"github.com/ponylang/valbytes.git","revision":"a1b2c3d4"},{"locator":"../pony-inspect","revision":""}]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "../pony-inspect",
    resultVersion = "",
  },
}
