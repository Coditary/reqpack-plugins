return {
  name = "uv search packages",
  request = {
    action = "search",
    system = "uv",
    prompt = "ruff",
  },
  fakeExec = {
    {
      match = "curl -fsSL 'https://pypi.org/search/?q=ruff'",
      exitCode = 0,
      stdout = [[<a class="package-snippet" href="/project/ruff/"><span class="package-snippet__name">ruff</span><p class="package-snippet__description">An extremely fast Python linter</p></a>]],
      stderr = "",
      success = true,
    },
    {
      match = "ls -1A '/home/test/.cache/reqpack/uv/tools'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "ruff",
    events = { "searched" },
  }
}
