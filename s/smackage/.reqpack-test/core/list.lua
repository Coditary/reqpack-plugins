return {
  name = "smackage list installed packages",
  fixtureRoot = "/tmp/opencode/smackage-list-case",
  request = {
    action = "list",
    system = "smackage",
  },
  environment = {
    SMACKAGE_HOME = "${fixtureRoot}/.smackage",
  },
  fixtureDirs = {
    ".smackage",
  },
  fixtureFiles = {
    {
      path = ".smackage/packages.installed",
      content = "# generated\ncmlib v1\n",
    },
  },
  fakeExec = {
    { match = "command -v smackage >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "TERM=dumb PAGER=cat SMACKAGE_HOME='/home/Leodoras/.smackage' smackage list", exitCode = 0, stdout = "Package cmlib:\n   Version: 1.2.0\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "cmlib",
    resultVersion = "1.2.0",
  },
}
