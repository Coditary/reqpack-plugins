return {
  name = "texlive update package",
  request = {
    action = "update",
    system = "texlive",
    packages = {
      { action = "update", name = "latexmk" }
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
      stdout = [[latexmk,Package,72000,"Latexmk",1
]],
      stderr = "",
      success = true,
    },
    {
      match = "tlmgr '--machine-readable' 'update' '--list'",
      exitCode = 0,
      stdout = "location-url\thttps://mirror.example/tlnet\nend-of-header\nlatexmk\tu\t72000\t72010\t100\t0\t100\tmain\t4.85\t4.86\nend-of-updates\n",
      stderr = "",
      success = true,
    },
    {
      match = "tlmgr 'update' 'latexmk'",
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'tlmgr' >/dev/null 2>&1",
      "tlmgr 'update' 'latexmk'"
    },
    stdout = { "updated\n" },
    events = { "updated", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
