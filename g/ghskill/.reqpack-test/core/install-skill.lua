return {
  name = "ghskill install shorthand skill",
  request = {
    action = "install",
    system = "ghskill",
    packages = {
      { name = "github/awesome-copilot/documentation-writer" }
    },
  },
  fixtureRoot = "../fixtures-install-skill",
  fixtureDirs = {
    "home/.local/share/ghskill/reqpack",
    "home/.local/share/aicache/artifacts/ghskill/repo/github_awesome-copilot@2026-05-29T12_10_00Z",
    "home/.local/share/aicache/artifacts/ghskill/skill/github_awesome-copilot/documentation-writer@2026-05-29T12_10_00Z",
    "home/.local/share/aicache/views/by-source/ghskill/repo/github_awesome-copilot",
    "home/.local/share/aicache/views/by-source/ghskill/skill/github_awesome-copilot/documentation-writer",
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "gh skill --help", exitCode = 0, stdout = "help\n", stderr = "", success = true },
    { match = "gh --version", exitCode = 0, stdout = "gh version 2.90.0 (2026-05-01)\n", stderr = "", success = true },
    { match = "gh skill install 'github/awesome-copilot' 'documentation-writer'", exitCode = 0, stdout = "installed\n", stderr = "", success = true },
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-29T12:10:00Z\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
