return {
  name = "ghskill list",
  request = {
    action = "list",
    system = "ghskill",
  },
  fixtureRoot = "../fixtures-list",
  fixtureDirs = {
    "home/.local/share/ghskill/reqpack",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/ghskill/reqpack/app.json",
      content = [[{"version":"2.90.0","detected_at":"2026-05-29T12:00:00Z"}]],
    },
    {
      path = "home/.local/share/ghskill/reqpack/projections.json",
      content = [[{"projections":[{"package_id":"github/awesome-copilot/documentation-writer","source":"github/awesome-copilot","source_url":"https://github.com/github/awesome-copilot","selector":"documentation-writer","skill_name":"documentation-writer","artifact_id":"ghskill/skill/github_awesome-copilot/documentation-writer@2026-05-29T12_10_00Z","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/ghskill/skill/github_awesome-copilot/documentation-writer@2026-05-29T12_10_00Z","scope":"project","agents":[],"target_paths":[".agents/skills/documentation-writer"],"installed_at":"2026-05-29T12:10:00Z","installed_revision":"2026-05-29T12:10:00Z"}]}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "app:ghskill",
    resultVersion = "2.90.0",
  }
}
