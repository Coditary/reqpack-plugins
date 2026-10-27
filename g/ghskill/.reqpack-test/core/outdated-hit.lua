return {
  name = "ghskill outdated hit",
  request = {
    action = "outdated",
    system = "ghskill",
  },
  fixtureRoot = "../fixtures-outdated-hit",
  fixtureDirs = {
    "home/.local/share/ghskill/reqpack",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/ghskill/reqpack/projections.json",
      content = [[{"projections":[{"package_id":"github/awesome-copilot/documentation-writer","source":"github/awesome-copilot","source_url":"https://github.com/github/awesome-copilot","selector":"documentation-writer","skill_name":"documentation-writer","artifact_id":"ghskill/skill/github_awesome-copilot/documentation-writer@old","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/ghskill/skill/github_awesome-copilot/documentation-writer@old","scope":"project","agents":[],"target_paths":[".agents/skills/documentation-writer"],"installed_at":"2026-05-29T12:10:00Z","installed_revision":"old"}]}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "gh skill --help", exitCode = 0, stdout = "help\n", stderr = "", success = true },
    { match = "gh --version", exitCode = 0, stdout = "gh version 2.90.0 (2026-05-01)\n", stderr = "", success = true },
    { match = "gh skill update 'documentation-writer' --dry-run", exitCode = 0, stdout = "Update available for documentation-writer\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "github/awesome-copilot/documentation-writer",
  }
}
