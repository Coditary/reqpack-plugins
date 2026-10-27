return {
  name = "texlive install local package file",
  request = {
    action = "install",
    system = "texlive",
    localPath = "/tmp/latexmk.tar.xz",
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
      match = "tlmgr 'install' '--file' '/tmp/latexmk.tar.xz'",
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
      "tlmgr 'install' '--file' '/tmp/latexmk.tar.xz'"
    },
    stdout = { "installed\n" },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=/tmp/latexmk.tar.xz}",
      success = "ok",
    },
  }
}
