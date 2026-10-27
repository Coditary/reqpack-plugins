return {
  name = "texlive search remote packages",
  request = {
    action = "search",
    system = "texlive",
    prompt = "latex",
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
      match = "tlmgr 'search' '--global' '--json' 'latex'",
      exitCode = 0,
      stdout = [=[{"packages":{"latex":"LaTeX macros","latexmk":"Smart LaTeX build"},"files":{"latex":["texmf-dist/tex/latex/base/latex.ltx"]}}]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "latex",
    events = { "searched" },
  }
}
