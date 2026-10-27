return {
  name = "futhark remove package and syncs",
  request = {
    action = "remove",
    system = "futhark",
    packages = {
      { name = "github.com/diku-dk/array" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'futhark' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "futhark pkg remove 'github.com/diku-dk/array'",
      exitCode = 0,
      stdout = "Removed github.com/diku-dk/array 1.2.3.\n",
      stderr = "",
      success = true,
    },
    {
      match = "futhark pkg sync",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'futhark' >/dev/null 2>&1",
      "futhark pkg remove 'github.com/diku-dk/array'",
      "futhark pkg sync",
    },
    events = { "deleted", "success" },
  },
}
