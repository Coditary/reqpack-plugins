return {
  name = "spm list project skills",
  request = {
    action = "list",
    system = "spm",
  },
  fixtureRoot = "../fixtures-list",
  fixtureDirs = {
    "project",
    "home/.spm/skills/@github/polyglot-test-agent/1.0.0",
    "home/.spm/cache",
  },
  fixtureFiles = {
    {
      path = "project/skills.json",
      content = [[{"skills":{"@github/polyglot-test-agent":"^1.0.0"}}]],
    },
    {
      path = "project/skills-lock.json",
      content = [[{"lockfileVersion":1,"skills":{"@github/polyglot-test-agent":{"version":"1.0.0","integrity":"sha256-test"}}}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
    PWD = "${fixtureRoot}/project",
  },
  fakeExec = {
    {
      match = "command -v spm >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "spm list --json",
      exitCode = 0,
      stdout = [[{"skills":[{"name":"@github/polyglot-test-agent","range":"^1.0.0","version":"1.0.0"}],"total":1}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "@github/polyglot-test-agent",
    resultVersion = "1.0.0",
  }
}
