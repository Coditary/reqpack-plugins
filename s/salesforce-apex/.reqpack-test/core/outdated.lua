return {
  name = "salesforce apex outdated",
  request = {
    action = "outdated",
    system = "salesforce-apex",
    flags = {
      "target-org=dev-org",
      "target-dev-hub=devhub",
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
      match = "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package installed list --json --target-org dev-org",
      exitCode = 0,
      stdout = [[{"status":0,"result":[{"SubscriberPackageName":"Dreamhouse","SubscriberPackageVersionId":"04tOLD","Package2Id":"0HoPKG","MajorVersion":1,"MinorVersion":1,"PatchVersion":0,"BuildNumber":1}]}]],
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package version list --json --verbose --target-dev-hub devhub --released",
      exitCode = 0,
      stdout = [[{"status":0,"result":[{"SubscriberPackageName":"Dreamhouse","SubscriberPackageVersionId":"04tNEW","Package2Id":"0HoPKG","MajorVersion":1,"MinorVersion":2,"PatchVersion":0,"BuildNumber":5,"IsReleased":true}]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'sf' >/dev/null 2>&1",
      "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package installed list --json --target-org dev-org",
      "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package version list --json --verbose --target-dev-hub devhub --released"
    },
    events = { "outdated" },
    resultCount = 1,
    resultName = "Dreamhouse",
    resultVersion = "1.1.0.1",
  },
}
