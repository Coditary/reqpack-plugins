return {
  name = "ctan info exact package",
  request = {
    action = "info",
    system = "ctan",
    prompt = "latexmk",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
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
      match = "TEXMFHOME='${fixtureRoot}/.reqpack-data/texmf-home' TEXMFVAR='${fixtureRoot}/.reqpack-data/texmf-var' TEXMFCONFIG='${fixtureRoot}/.reqpack-data/texmf-config' TL_DOWNLOAD_DIRECTORY='${fixtureRoot}/.reqpack-data/downloads' LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' tlmgr '--usermode' '--usertree' '${fixtureRoot}/.reqpack-data/texmf-home' '--repository' 'ctan' 'info' '--json' 'latexmk'",
      exitCode = 0,
      stdout = [=[[{"name":"latexmk","category":"Package","localrev":72000,"remoterev":72010,"shortdesc":"Latexmk runner","longdesc":"Run LaTeX the right number of times","installed":true,"relocatable":true,"available":true,"depends":["latex-bin"],"rcataloguedata":{"version":"4.86","date":"2025-01-01","license":"gpl2"}}]]=],
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
