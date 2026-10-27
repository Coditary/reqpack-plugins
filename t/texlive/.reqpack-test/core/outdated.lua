return {
  name = "texlive list outdated packages",
  request = {
    action = "outdated",
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
      match = "tlmgr '--machine-readable' 'update' '--list'",
      exitCode = 0,
      stdout = "location-url\thttps://mirror.example/tlnet\nend-of-header\nlatexmk\tu\t72000\t72010\t100\t0\t100\tmain\t4.85\t4.86\ncollection-basic\ta\t0\t72020\t1\t0\t1\tmain\t-\t-\nend-of-updates\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "collection-basic",
    resultVersion = "0",
    events = { "outdated" },
  }
}
