return {
  name = "clasp info script enriches metadata",
  request = {
    action = "info",
    system = "clasp",
    prompt = "script:AKfycbx1234567890",
  },
  fakeExec = {
    {
      match = "command -v 'clasp' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'clasp' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "clasp show-authorized-user --json",
      exitCode = 0,
      stdout = [[{"loggedIn":true,"email":"dev@example.com","clientId":"cid","clientType":"google-provided"}]],
      stderr = "",
      success = true,
    },
    {
      match = "clasp list-scripts --json",
      exitCode = 0,
      stdout = [=[[{"id":"AKfycbx1234567890","name":"Hello World"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "clasp list-deployments AKfycbx1234567890 --json",
      exitCode = 0,
      stdout = [=[[{"deploymentId":"dep-1","versionNumber":7,"description":"prod"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "clasp list-versions AKfycbx1234567890 --json",
      exitCode = 0,
      stdout = [=[[{"versionNumber":6,"description":"prev"},{"versionNumber":7,"description":"release"}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "Hello World",
    resultVersion = "7",
  }
}
