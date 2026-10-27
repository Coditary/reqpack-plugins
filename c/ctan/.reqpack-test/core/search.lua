return {
  name = "ctan search remote packages",
  request = {
    action = "search",
    system = "ctan",
    prompt = "latex",
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
      match = "TEXMFHOME='${fixtureRoot}/.reqpack-data/texmf-home' TEXMFVAR='${fixtureRoot}/.reqpack-data/texmf-var' TEXMFCONFIG='${fixtureRoot}/.reqpack-data/texmf-config' TL_DOWNLOAD_DIRECTORY='${fixtureRoot}/.reqpack-data/downloads' LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' tlmgr '--usermode' '--usertree' '${fixtureRoot}/.reqpack-data/texmf-home' '--repository' 'ctan' 'search' '--global' '--json' 'latex'",
      exitCode = 0,
      stdout = [[{"packages":{"latexmk":"Latexmk runner","latexindent":"Indent LaTeX files"},"files":{"latexmk":["scripts/latexmk/latexmk.pl"]}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "latexindent",
    events = { "searched" },
  }
}
