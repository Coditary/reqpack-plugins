return {
  name = "gh search skill",
  request = {
    action = "search",
    system = "gh",
    prompt = "documentation",
  },
  fakeExec = {
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh extension search documentation --json fullName,description,url,stargazersCount --limit 30",
      exitCode = 0,
      stdout = '[]\n',
      stderr = "",
      success = true,
    },
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh skill search documentation --json description,namespace,path,repo,skillName,stars --limit 15",
      exitCode = 0,
      stdout = '[{"description":"Write docs","namespace":"","path":"skills/documentation-writer/SKILL.md","repo":"github/awesome-copilot","skillName":"documentation-writer","stars":42}]\n',
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "github/awesome-copilot/documentation-writer",
  }
}
