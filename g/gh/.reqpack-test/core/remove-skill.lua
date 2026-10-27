return {
  name = "gh remove skill",
  request = {
    action = "remove",
    system = "gh",
    packages = {
      { name = "github/awesome-copilot/documentation-writer" }
    },
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/gh/state",
    "/home/test/.cache/reqpack/gh/skills/managed/documentation-writer",
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/gh/state/skills-manifest.json",
      content = [[{"skills":[{"installedPath":"/home/test/.cache/reqpack/gh/skills/managed/documentation-writer","packageId":"github/awesome-copilot/documentation-writer","repo":"github/awesome-copilot","selector":"documentation-writer","selectorPath":"documentation-writer","skillName":"documentation-writer"}]}]],
    },
  },
  fakeExec = {
    {
      match = "test -e '/home/test/.cache/reqpack/gh/skills/managed/documentation-writer'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '/home/test/.cache/reqpack/gh/skills/managed/documentation-writer'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/home/test/.cache/reqpack/gh/state'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
