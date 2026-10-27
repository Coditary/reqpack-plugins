return {
  name = "texlive list installed packages",
  request = {
    action = "list",
    system = "texlive",
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
      stdout = [[latexmk,Package,72010,"Latexmk runner",1
biblatex,Package,70000,"Bibliographies",1
]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "biblatex",
    resultVersion = "70000",
    events = { "listed" },
  }
}
