return {
  name = "ghskill update skill",
  request = {
    action = "update",
    system = "ghskill",
    packages = {
      { name = "github/awesome-copilot/documentation-writer" }
    },
  },
  fixtureRoot = "../fixtures-update-skill",
  fixtureDirs = {
    "home/.local/share/ghskill/reqpack",
    "home/.local/share/aicache/artifacts/ghskill/repo/github_awesome-copilot@2026-05-29T12_30_00Z",
    "home/.local/share/aicache/artifacts/ghskill/skill/github_awesome-copilot/documentation-writer@2026-05-29T12_30_00Z",
    "home/.local/share/aicache/views/by-source/ghskill/repo/github_awesome-copilot",
    "home/.local/share/aicache/views/by-source/ghskill/skill/github_awesome-copilot/documentation-writer",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/ghskill/reqpack/projections.json",
      content = [[{"projections":[{"package_id":"github/awesome-copilot/documentation-writer","source":"github/awesome-copilot","source_url":"https://github.com/github/awesome-copilot","selector":"documentation-writer","skill_name":"documentation-writer","artifact_id":"ghskill/skill/github_awesome-copilot/documentation-writer@2026-05-29T12_10_00Z","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/ghskill/skill/github_awesome-copilot/documentation-writer@2026-05-29T12_10_00Z","scope":"project","agents":[],"target_paths":[".agents/skills/documentation-writer"],"installed_at":"2026-05-29T12:10:00Z","installed_revision":"2026-05-29T12:10:00Z"}]}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "gh skill --help", exitCode = 0, stdout = "help\n", stderr = "", success = true },
    { match = "gh --version", exitCode = 0, stdout = "gh version 2.90.0 (2026-05-01)\n", stderr = "", success = true },
    { match = "gh skill install 'github/awesome-copilot' 'documentation-writer'", exitCode = 0, stdout = "updated\n", stderr = "", success = true },
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-29T12:30:00Z\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
    eventPayloads = {
      updated = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
