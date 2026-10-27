return {
  name = "smackage search packages",
  fixtureRoot = "/tmp/opencode/smackage-search-case",
  request = {
    action = "search",
    system = "smackage",
    prompt = "cmlib",
  },
  environment = {
    SMACKAGE_HOME = "${fixtureRoot}/.smackage",
  },
  fakeExec = {
    { match = "command -v smackage >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "TERM=dumb PAGER=cat SMACKAGE_HOME='/home/Leodoras/.smackage' smackage search 'cmlib'", exitCode = 0, stdout = "cmlib 1.3.0 (from github https://example.test/cmlib.git)\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "cmlib",
    resultVersion = "1.3.0",
  },
}
