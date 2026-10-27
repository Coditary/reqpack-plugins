return {
  name = "smackage outdated explicit package",
  fixtureRoot = "/tmp/opencode/smackage-outdated-case",
  request = {
    action = "outdated",
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
      content = "cmlib v1\n",
    },
  },
  fakeExec = {
    { match = "command -v smackage >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "TERM=dumb PAGER=cat SMACKAGE_HOME='/home/Leodoras/.smackage' smackage refresh", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "TERM=dumb PAGER=cat SMACKAGE_HOME='/home/Leodoras/.smackage' smackage list", exitCode = 0, stdout = "Package cmlib:\n   Version: 1.2.0\n", stderr = "", success = true },
    { match = "TERM=dumb PAGER=cat SMACKAGE_HOME='/home/Leodoras/.smackage' smackage info 'cmlib'", exitCode = 0, stdout = "Candidates:\ncmlib 1.3.0\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed", "outdated" },
    resultCount = 1,
    resultName = "cmlib",
    resultVersion = "1.2.0",
  },
}
