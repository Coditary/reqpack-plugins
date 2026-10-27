return {
  name = "gh info skill",
  request = {
    action = "info",
    system = "gh",
    prompt = "github/awesome-copilot/documentation-writer",
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
    {
      path = "/home/test/.cache/reqpack/gh/skills/managed/documentation-writer/SKILL.md",
      content = [=[---
name: documentation-writer
description: Write docs
homepage: https://github.com/github/awesome-copilot
metadata:
  github-repo: https://github.com/github/awesome-copilot
  github-ref: main
  github-tree-sha: abc123
---

Body.
]=],
    },
  },
  fakeExec = {
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh skill search documentation-writer --json description,namespace,path,repo,skillName,stars --limit 15",
      exitCode = 0,
      stdout = '[{"description":"Write docs","namespace":"","path":"skills/documentation-writer/SKILL.md","repo":"github/awesome-copilot","skillName":"documentation-writer","stars":42}]\n',
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "github/awesome-copilot/documentation-writer",
  }
}
