return {
  name = "corral install local bundle",
  request = {
    action = "install",
    system = "corral",
    localPath = "/tmp/pony-inspect",
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/corral/bundle",
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
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "corral --bundle_dir '/home/test/.cache/reqpack/corral/bundle' init",
      exitCode = 0,
      stdout = "initialized\n",
      stderr = "",
      success = true,
    },
    {
      match = "corral --bundle_dir '/home/test/.cache/reqpack/corral/bundle' add '/tmp/pony-inspect'",
      exitCode = 0,
      stdout = "added\n",
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
      "corral --bundle_dir '/home/test/.cache/reqpack/corral/bundle' init",
      "corral --bundle_dir '/home/test/.cache/reqpack/corral/bundle' add '/tmp/pony-inspect'",
      "corral --bundle_dir '/home/test/.cache/reqpack/corral/bundle' update"
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=/tmp/pony-inspect}",
    },
  },
}
