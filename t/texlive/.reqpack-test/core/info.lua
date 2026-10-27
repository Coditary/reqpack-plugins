return {
  name = "texlive info exact package",
  request = {
    action = "info",
    system = "texlive",
    prompt = "latexmk",
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
      match = "tlmgr 'info' '--json' 'latexmk'",
      exitCode = 0,
      stdout = [=[[{"name":"latexmk","category":"Package","localrev":72000,"remoterev":72010,"shortdesc":"Latexmk runner","longdesc":"Run LaTeX right number of times","installed":true,"relocatable":true,"available":true,"depends":["latex-bin"],"rcataloguedata":{"version":"4.86","date":"2025-01-01","license":"gpl2"}}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "latexmk",
    resultVersion = "72000",
    events = { "informed" },
  }
}
