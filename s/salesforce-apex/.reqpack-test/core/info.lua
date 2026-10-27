return {
  name = "salesforce apex info package version",
  request = {
    action = "info",
    system = "salesforce-apex",
    prompt = "04tNEW",
    flags = {
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
      match = "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package version report --json --target-dev-hub devhub --package 04tNEW",
      exitCode = 0,
      stdout = [[{"status":0,"result":{"SubscriberPackageName":"Dreamhouse","SubscriberPackageVersionId":"04tNEW","Package2Id":"0HoPKG","MajorVersion":1,"MinorVersion":2,"PatchVersion":0,"BuildNumber":5,"NamespacePrefix":"dream","Description":"Apex sample package","IsReleased":true}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'sf' >/dev/null 2>&1",
      "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package version report --json --target-dev-hub devhub --package 04tNEW"
    },
    events = { "informed" },
    resultCount = 1,
    resultName = "Dreamhouse",
    resultVersion = "1.2.0.5",
  },
}
