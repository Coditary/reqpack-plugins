return {
  name = "smackage update packages",
  fixtureRoot = "/tmp/opencode/smackage-update-case",
  request = {
    action = "update",
    system = "smackage",
  },
  environment = {
    SMACKAGE_HOME = "${fixtureRoot}/.smackage",
  },
  fakeExec = {
    { match = "command -v smackage >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "TERM=dumb PAGER=cat SMACKAGE_HOME='/home/Leodoras/.smackage' smackage update", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
    eventPayloads = {
      updated = "<lua-value>",
      success = "ok",
    },
  },
}
