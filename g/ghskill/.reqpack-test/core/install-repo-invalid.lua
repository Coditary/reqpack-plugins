return {
  name = "ghskill install repo rejected",
  request = {
    action = "install",
    system = "ghskill",
    packages = {
      { name = "github/awesome-copilot" }
    },
  },
  fixtureRoot = "../fixtures-install-repo-invalid",
  fixtureDirs = {
    "home/.local/share/ghskill/reqpack",
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = false,
    events = { "failed" },
    eventPayloads = {
      failed = "ghskill package must use owner/repo/skill or owner/repo/skills/...",
    },
  }
}
