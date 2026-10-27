return {
  name = "gh search extension",
  request = {
    action = "search",
    system = "gh",
    prompt = "codeql",
  },
  fakeExec = {
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh extension search codeql --json fullName,description,url,stargazersCount --limit 30",
      exitCode = 0,
      stdout = '[{"description":"GitHub CLI extension for working with CodeQL","fullName":"github/gh-codeql","stargazersCount":38,"url":"https://github.com/github/gh-codeql"}]\n',
      stderr = "",
      success = true,
    },
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh skill search codeql --json description,namespace,path,repo,skillName,stars --limit 15",
      exitCode = 0,
      stdout = '[]\n',
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "github/gh-codeql",
  }
}
