return {
  name = "salesforce apex search packages",
  request = {
    action = "search",
    system = "salesforce-apex",
    prompt = "dream",
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
      match = "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package list --json --verbose --target-dev-hub devhub",
      exitCode = 0,
      stdout = [[{"status":0,"result":[{"Name":"Dreamhouse","Package2Id":"0HoPKG","Description":"Apex sample package","NamespacePrefix":"dream"},{"Name":"OtherPkg","Package2Id":"0HoOTHER","Description":"Another package","NamespacePrefix":"other"}]}]],
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
      "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package list --json --verbose --target-dev-hub devhub",
      "NO_COLOR=1 CLICOLOR=0 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh sf package version list --json --verbose --target-dev-hub devhub --released"
    },
    events = { "searched" },
    resultCount = 1,
    resultName = "Dreamhouse",
    resultVersion = "1.2.0.5",
  },
}
