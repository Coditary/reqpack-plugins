return {
  name = "salesforce apex uninstall package",
  request = {
    action = "remove",
    system = "salesforce-apex",
    flags = {
      "target-org=dev-org",
      "wait=20",
    },
    packages = {
      { name = "Dreamhouse", version = "04t999999999999AAA" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'sf' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package uninstall --json --target-org dev-org --package 04t999999999999AAA --wait 20",
      exitCode = 0,
      stdout = [[{"status":0,"result":{"Id":"06y999999999999AAA"}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'sf' >/dev/null 2>&1",
      "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package uninstall --json --target-org dev-org --package 04t999999999999AAA --wait 20"
    },
    events = { "deleted", "success" },
  },
}
