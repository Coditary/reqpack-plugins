return {
  name = "texlive remove package",
  request = {
    action = "remove",
    system = "texlive",
    packages = {
      { action = "remove", name = "latexmk" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'tlmgr' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "tlmgr 'info' '--only-installed' '--data' 'name,category,localrev,shortdesc,relocatable'",
      exitCode = 0,
      stdout = [[latexmk,Package,72010,"Latexmk",1
]],
      stderr = "",
      success = true,
    },
    {
      match = "tlmgr 'remove' 'latexmk'",
      exitCode = 0,
      stdout = "removed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'tlmgr' >/dev/null 2>&1",
      "tlmgr 'remove' 'latexmk'"
    },
    stdout = { "removed\n" },
    events = { "deleted", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
