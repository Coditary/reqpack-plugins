return {
  name = "ghskill info cached skill",
  request = {
    action = "info",
    system = "ghskill",
    prompt = "github/awesome-copilot/documentation-writer",
  },
  fixtureRoot = "../fixtures-info-skill",
  fixtureDirs = {
    "home/.local/share/ghskill/reqpack",
    "home/.agents/skills/documentation-writer",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/ghskill/reqpack/projections.json",
      content = [[{"projections":[{"package_id":"github/awesome-copilot/documentation-writer","source":"github/awesome-copilot","source_url":"https://github.com/github/awesome-copilot","selector":"documentation-writer","skill_name":"documentation-writer","artifact_id":"ghskill/skill/github_awesome-copilot/documentation-writer@2026-05-29T12_10_00Z","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/ghskill/skill/github_awesome-copilot/documentation-writer@2026-05-29T12_10_00Z","scope":"project","agents":[],"target_paths":["${fixtureRoot}/home/.agents/skills/documentation-writer"],"installed_at":"2026-05-29T12:10:00Z","installed_revision":"2026-05-29T12:10:00Z"}]}]],
    },
    {
      path = "home/.agents/skills/documentation-writer/SKILL.md",
      content = [[---
name: documentation-writer
description: Writes high quality docs
metadata:
  github-repo: https://github.com/github/awesome-copilot
  github-ref: refs/heads/main
  github-tree-sha: tree123
  github-path: skills/documentation-writer
---
Body]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "test -f '", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "github/awesome-copilot/documentation-writer",
    resultVersion = "tree123",
  }
}
