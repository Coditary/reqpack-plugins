return {
  name = "corral update bundle",
  request = {
    action = "update",
    system = "corral",
    packages = {
      { name = "github.com/ponylang/valbytes.git", version = ">=0.7.0 <2.0.0" }
    },
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
      match = "test -e '/home/test/.cache/reqpack/corral/bundle/corral.json'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -e '/home/test/.cache/reqpack/corral/bundle/lock.json'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "corral --bundle_dir '/home/test/.cache/reqpack/corral/bundle' add --version '>=0.7.0 <2.0.0' 'github.com/ponylang/valbytes.git'",
      exitCode = 0,
      stdout = "added\n",
      stderr = "",
      success = true,
    },
    {
      match = "corral --bundle_dir '/home/test/.cache/reqpack/corral/bundle' clean",
      exitCode = 0,
      stdout = "cleaned\n",
      stderr = "",
      success = true,
    },
    {
      match = "corral --bundle_dir '/home/test/.cache/reqpack/corral/bundle' update",
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'corral' >/dev/null 2>&1",
      "test -e '/home/test/.cache/reqpack/corral/bundle/corral.json'",
      "test -e '/home/test/.cache/reqpack/corral/bundle/lock.json'",
      "corral --bundle_dir '/home/test/.cache/reqpack/corral/bundle' add --version '>=0.7.0 <2.0.0' 'github.com/ponylang/valbytes.git'",
      "corral --bundle_dir '/home/test/.cache/reqpack/corral/bundle' clean",
      "corral --bundle_dir '/home/test/.cache/reqpack/corral/bundle' update"
    },
    events = { "updated", "success" },
  },
}
