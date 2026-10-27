return {
  name = "smackage install package",
  fixtureRoot = "/tmp/opencode/smackage-install-case",
  request = {
    action = "install",
    system = "smackage",
    packages = {
      { name = "cmlib", version = "v1" }
    },
  },
  environment = {
    SMACKAGE_HOME = "${fixtureRoot}/.smackage",
  },
  fakeExec = {
    { match = "command -v smackage >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "TERM=dumb PAGER=cat SMACKAGE_HOME='/home/Leodoras/.smackage' smackage get 'cmlib' 'v1'", exitCode = 0, stdout = "Package `cmlib 1.2.0' downloaded.\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{1=<lua-value>}",
      success = "ok",
    },
  },
}
