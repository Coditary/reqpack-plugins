return {
  name = "clasp update push version deployment",
  fixtureRoot = "/tmp/opencode/clasp-update-case",
  request = {
    action = "update",
    system = "clasp",
    flags = { "pull", "force", "version-description=release 8", "deployment-description=prod", "deploymentId=dep-1", "versionNumber=8" },
    packages = {
      { name = "project:/tmp/opencode/clasp-update-case/project" }
    },
  },
  fixtureDirs = {
    "project",
  },
  fixtureFiles = {
    {
      path = "project/.clasp.json",
      content = [[{"scriptId":"AKfycbx1234567890","rootDir":"src"}]],
    },
  },
  fakeExec = {
    {
      match = "cd '/tmp/opencode/clasp-update-case/project' && clasp pull",
      exitCode = 0,
      stdout = "Pulled\n",
      stderr = "",
      success = true,
    },
    {
      match = "cd '/tmp/opencode/clasp-update-case/project' && clasp push",
      exitCode = 0,
      stdout = "Pushed\n",
      stderr = "",
      success = true,
    },
    {
      match = "cd '/tmp/opencode/clasp-update-case/project' && clasp create-version 'release 8'",
      exitCode = 0,
      stdout = "Created version 8\n",
      stderr = "",
      success = true,
    },
    {
      match = "cd '/tmp/opencode/clasp-update-case/project' && clasp create-deployment --versionNumber 8 --description prod --deploymentId dep-1",
      exitCode = 0,
      stdout = "Created deployment\n",
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
      stdout = [[{"loggedIn":true,"email":"dev@example.com"}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/clasp-update-case/project/.clasp.json'",
      exitCode = 0,
      stdout = [[{"scriptId":"AKfycbx1234567890","rootDir":"src"}]],
      stderr = "",
      success = true,
    },
    {
      match = "clasp list-deployments AKfycbx1234567890 --json",
      exitCode = 0,
      stdout = [=[[{"deploymentId":"dep-1","versionNumber":8,"description":"prod"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "clasp list-versions AKfycbx1234567890 --json",
      exitCode = 0,
      stdout = [=[[{"versionNumber":8,"description":"release 8"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "cd '/tmp/opencode/clasp-update-case/project' && clasp show-file-status --json",
      exitCode = 0,
      stdout = [[{"filesToPush":["src/Code.js"],"untrackedFiles":["README.md"]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
