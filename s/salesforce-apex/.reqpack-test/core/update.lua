return {
  name = "salesforce apex update package",
  request = {
    action = "update",
    system = "salesforce-apex",
    flags = {
      "target-org=dev-org",
      "target-dev-hub=devhub",
      "wait=10",
    },
    packages = {
      { name = "Dreamhouse" }
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
      match = "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package version list --json --verbose --target-dev-hub devhub --released",
      exitCode = 0,
      stdout = [[{"status":0,"result":[{"SubscriberPackageName":"Dreamhouse","SubscriberPackageVersionId":"04tNEW","Package2Id":"0HoPKG","MajorVersion":1,"MinorVersion":2,"PatchVersion":0,"BuildNumber":5,"IsReleased":true},{"SubscriberPackageName":"Dreamhouse","SubscriberPackageVersionId":"04tOLD","Package2Id":"0HoPKG","MajorVersion":1,"MinorVersion":1,"PatchVersion":0,"BuildNumber":1,"IsReleased":true}]}]],
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package install --json --no-prompt --target-org dev-org --package 04tNEW --wait 10",
      exitCode = 0,
      stdout = [[{"status":0,"result":{"Id":"0HfREQ","SubscriberPackageVersionId":"04tNEW"}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'sf' >/dev/null 2>&1",
      "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package version list --json --verbose --target-dev-hub devhub --released",
      "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package install --json --no-prompt --target-org dev-org --package 04tNEW --wait 10"
    },
    events = { "updated", "success" },
  },
}
