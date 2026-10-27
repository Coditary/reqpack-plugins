return {
  name = "ctan list outdated packages",
  request = {
    action = "outdated",
    system = "ctan",
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
      match = "TEXMFHOME='${fixtureRoot}/.reqpack-data/texmf-home' TEXMFVAR='${fixtureRoot}/.reqpack-data/texmf-var' TEXMFCONFIG='${fixtureRoot}/.reqpack-data/texmf-config' TL_DOWNLOAD_DIRECTORY='${fixtureRoot}/.reqpack-data/downloads' LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' tlmgr '--usermode' '--usertree' '${fixtureRoot}/.reqpack-data/texmf-home' '--repository' 'ctan' '--machine-readable' 'update' '--list'",
      exitCode = 0,
      stdout = "location-url\thttps://mirror.example/tlnet\ntotal-bytes\t42\nend-of-header\nlatexmk\tu\t72000\t72010\t100\t0\t100\tmain\t4.85\t4.86\ncollection-basic\ta\t0\t72020\t1\t0\t1\tmain\t-\t-\nend-of-updates\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "latexmk",
    resultVersion = "72000",
    events = { "outdated" },
  }
}
