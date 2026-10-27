return {
  name = "futhark install adds package and syncs",
  request = {
    action = "install",
    system = "futhark",
    packages = {
      { name = "github.com/diku-dk/array", version = "1.2.3" }
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
      match = "futhark pkg add 'github.com/diku-dk/array' '1.2.3'",
      exitCode = 0,
      stdout = "Added new required package github.com/diku-dk/array 1.2.3.\nRemember to run 'futhark pkg sync'.\n",
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
      "futhark pkg add 'github.com/diku-dk/array' '1.2.3'",
      "futhark pkg sync",
    },
    events = { "installed", "success" },
  },
}
