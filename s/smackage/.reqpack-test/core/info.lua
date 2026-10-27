return {
  name = "smackage info installed candidate",
  fixtureRoot = "/tmp/opencode/smackage-info-case",
  request = {
    action = "info",
    system = "smackage",
    prompt = "cmlib",
  },
  environment = {
    SMACKAGE_HOME = "${fixtureRoot}/.smackage",
  },
  fakeExec = {
    { match = "command -v smackage >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "TERM=dumb PAGER=cat SMACKAGE_HOME='/home/Leodoras/.smackage' smackage info 'cmlib'", exitCode = 0, stdout = "Candidates:\ncmlib 1.2.0 (installed)\ncmlib 1.3.0\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "cmlib",
    resultVersion = "1.2.0",
  },
}
