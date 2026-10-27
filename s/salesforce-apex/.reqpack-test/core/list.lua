return {
  name = "salesforce apex list installed",
  request = {
    action = "list",
    system = "salesforce-apex",
    flags = {
      "target-org=dev-org",
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
      stdout = [[{"status":0,"result":[{"SubscriberPackageName":"Dreamhouse","SubscriberPackageVersionId":"04tINST","Package2Id":"0HoPKG","MajorVersion":1,"MinorVersion":1,"PatchVersion":0,"BuildNumber":1,"NamespacePrefix":"dream"}]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'sf' >/dev/null 2>&1",
      "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package installed list --json --target-org dev-org"
    },
    events = { "listed" },
    resultCount = 1,
    resultName = "Dreamhouse",
    resultVersion = "1.1.0.1",
  },
}
