return {
  name = "ghskill list cache view",
  request = {
    action = "list",
    system = "ghskill",
  },
  fixtureRoot = "../fixtures-list-cache-view",
  fixtureDirs = {
    "home/.local/share/aicache/views/by-source/ghskill/repo/github_awesome-copilot",
    "home/.local/share/aicache/views/by-source/ghskill/skill/github_awesome-copilot/documentation-writer",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/aicache/views/by-source/ghskill/repo/github_awesome-copilot/current.json",
      content = [[{"artifact_id":"ghskill/repo/github_awesome-copilot@tree123","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/ghskill/repo/github_awesome-copilot@tree123","source":"github/awesome-copilot","source_url":"https://github.com/github/awesome-copilot","revision":"tree123","package_id":"github/awesome-copilot","kind":"repo"}]],
    },
    {
      path = "home/.local/share/aicache/views/by-source/ghskill/skill/github_awesome-copilot/documentation-writer/current.json",
      content = [[{"artifact_id":"ghskill/skill/github_awesome-copilot/documentation-writer@tree123","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/ghskill/skill/github_awesome-copilot/documentation-writer@tree123","source":"github/awesome-copilot","source_url":"https://github.com/github/awesome-copilot","revision":"tree123","package_id":"github/awesome-copilot/documentation-writer","kind":"skill","skill_name":"documentation-writer","selector":"documentation-writer"}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "gh skill --help", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -d '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "find '", exitCode = 0, stdout = "${fixtureRoot}/home/.local/share/aicache/views/by-source/ghskill/repo/github_awesome-copilot/current.json\n${fixtureRoot}/home/.local/share/aicache/views/by-source/ghskill/skill/github_awesome-copilot/documentation-writer/current.json\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "github/awesome-copilot",
    resultVersion = "tree123",
  }
}
