return {
  name = "texlive install package",
  request = {
    action = "install",
    system = "texlive",
    packages = {
      { action = "install", name = "latexmk", version = "72010" }
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
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "tlmgr 'install' 'latexmk'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'tlmgr' >/dev/null 2>&1",
      "tlmgr 'install' 'latexmk'"
    },
    stdout = { "installed\n" },
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
