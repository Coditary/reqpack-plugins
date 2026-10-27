return {
  name = "clasp list local and cached scripts",
  request = {
    action = "list",
    system = "clasp",
    flags = {},
  },
  fixtureDirs = {
    ".reqpack-data/cache/scripts/AKfycbx1234567890",
  },
  fixtureFiles = {
    {
      path = ".clasp.json",
      content = [[{"scriptId":"AKfycbx1234567890","rootDir":"src","projectId":"gcp-1"}]],
    },
    {
      path = ".reqpack-data/cache/scripts.json",
      content = [=[[{"id":"AKfycbx1234567890","name":"Hello World"},{"id":"AKfycbx999","name":"Ops Tool"}]]=],
    },
    {
      path = ".reqpack-data/cache/scripts/AKfycbx1234567890/deployments.json",
      content = [=[[{"deploymentId":"dep-1","versionNumber":7,"description":"prod"}]]=],
    },
    {
      path = ".reqpack-data/cache/scripts/AKfycbx1234567890/versions.json",
      content = [=[[{"versionNumber":7,"description":"release"}]]=],
    },
  },
  fakeExec = {
    {
      match = "test -f './.clasp.json'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat './.clasp.json'",
      exitCode = 0,
      stdout = [[{"scriptId":"AKfycbx1234567890","rootDir":"src","projectId":"gcp-1"}]],
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'clasp' >/dev/null 2>&1",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "cat '/home/Leodoras/Dev/Coditary/ReqPack/rqp-plugins/c/clasp/.reqpack-data/cache/auth.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing",
      success = false,
    },
    {
      match = "cat '/home/Leodoras/Dev/Coditary/ReqPack/rqp-plugins/c/clasp/.reqpack-data/cache/scripts.json'",
      exitCode = 0,
      stdout = [=[[{"id":"AKfycbx1234567890","name":"Hello World"},{"id":"AKfycbx999","name":"Ops Tool"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/Leodoras/Dev/Coditary/ReqPack/rqp-plugins/c/clasp/.reqpack-data/cache/scripts/AKfycbx1234567890/deployments.json'",
      exitCode = 0,
      stdout = [=[[{"deploymentId":"dep-1","versionNumber":7,"description":"prod"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/Leodoras/Dev/Coditary/ReqPack/rqp-plugins/c/clasp/.reqpack-data/cache/scripts/AKfycbx1234567890/versions.json'",
      exitCode = 0,
      stdout = [=[[{"versionNumber":7,"description":"release"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/Leodoras/Dev/Coditary/ReqPack/rqp-plugins/c/clasp/.reqpack-data/cache/scripts/AKfycbx999/deployments.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing",
      success = false,
    },
    {
      match = "cat '/home/Leodoras/Dev/Coditary/ReqPack/rqp-plugins/c/clasp/.reqpack-data/cache/scripts/AKfycbx999/versions.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing",
      success = false,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
  }
}
