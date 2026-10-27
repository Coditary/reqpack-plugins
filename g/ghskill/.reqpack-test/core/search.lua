return {
  name = "ghskill search",
  request = {
    action = "search",
    system = "ghskill",
    prompt = "documentation",
  },
  fixtureRoot = "../fixtures-search",
  fixtureDirs = {
    "home",
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "gh skill --help", exitCode = 0, stdout = "help\n", stderr = "", success = true },
    { match = "gh --version", exitCode = 0, stdout = "gh version 2.90.0 (2026-05-01)\n", stderr = "", success = true },
    { match = "gh skill search 'documentation' --json description,namespace,path,repo,skillName,stars --limit 15", exitCode = 0, stdout = '[{"description":"Write docs","namespace":"","path":"skills/documentation-writer/SKILL.md","repo":"github/awesome-copilot","skillName":"documentation-writer","stars":42}]\n', stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "github/awesome-copilot/documentation-writer",
  }
}
