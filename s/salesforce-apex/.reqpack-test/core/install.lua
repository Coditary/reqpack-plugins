return {
  name = "salesforce apex install package",
  request = {
    action = "install",
    system = "salesforce-apex",
    flags = {
      "target-org=dev-org",
      "wait=15",
      "publish-wait=5",
      "security-type=AllUsers",
      "apex-compile=package",
      "upgrade-type=Mixed",
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
      match = "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package install --json --no-prompt --target-org dev-org --package 04t999999999999AAA --wait 15 --publish-wait 5 --apex-compile package --security-type AllUsers --upgrade-type Mixed",
      exitCode = 0,
      stdout = [[{"status":0,"result":{"Id":"0Hf999999999999AAA","SubscriberPackageVersionId":"04t999999999999AAA"}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'sf' >/dev/null 2>&1",
      "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package install --json --no-prompt --target-org dev-org --package 04t999999999999AAA --wait 15 --publish-wait 5 --apex-compile package --security-type AllUsers --upgrade-type Mixed"
    },
    events = { "installed", "success" },
  },
}
