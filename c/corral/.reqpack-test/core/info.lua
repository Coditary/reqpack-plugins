return {
  name = "corral info cached dependency",
  request = {
    action = "info",
    system = "corral",
    prompt = "valbytes.git",
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/corral/bundle",
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/corral/bundle/corral.json",
      content = [[{"info":{"name":"reqpack-corral-cache"},"packages":[],"deps":[{"locator":"github.com/ponylang/valbytes.git","version":">=0.6.0 <2.0.0"}]}]],
    },
    {
      path = "/home/test/.cache/reqpack/corral/bundle/lock.json",
      content = [[{"locks":[{"locator":"github.com/ponylang/valbytes.git","revision":"a1b2c3d4"}]}]],
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
      stdout = [[{"info":{"name":"reqpack-corral-cache"},"packages":[],"deps":[{"locator":"github.com/ponylang/valbytes.git","version":">=0.6.0 <2.0.0"}]}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/test/.cache/reqpack/corral/bundle/lock.json'",
      exitCode = 0,
      stdout = [[{"locks":[{"locator":"github.com/ponylang/valbytes.git","revision":"a1b2c3d4"}]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "github.com/ponylang/valbytes.git",
    resultVersion = ">=0.6.0 <2.0.0",
  },
}
