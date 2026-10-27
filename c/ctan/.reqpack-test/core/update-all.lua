return {
  name = "ctan update all packages",
  request = {
    action = "update",
    system = "ctan",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    packages = {},
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
      match = "mkdir -p '${fixtureRoot}/.reqpack-data' '${fixtureRoot}/.reqpack-data/texmf-home' '${fixtureRoot}/.reqpack-data/texmf-var' '${fixtureRoot}/.reqpack-data/texmf-config' '${fixtureRoot}/.reqpack-data/downloads'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "TEXMFHOME='${fixtureRoot}/.reqpack-data/texmf-home' TEXMFVAR='${fixtureRoot}/.reqpack-data/texmf-var' TEXMFCONFIG='${fixtureRoot}/.reqpack-data/texmf-config' TL_DOWNLOAD_DIRECTORY='${fixtureRoot}/.reqpack-data/downloads' LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' tlmgr '--usermode' '--usertree' '${fixtureRoot}/.reqpack-data/texmf-home' '--repository' 'ctan' 'init-usertree'",
      exitCode = 0,
      stdout = "initialized\n",
      stderr = "",
      success = true,
    },
    {
      match = "TEXMFHOME='${fixtureRoot}/.reqpack-data/texmf-home' TEXMFVAR='${fixtureRoot}/.reqpack-data/texmf-var' TEXMFCONFIG='${fixtureRoot}/.reqpack-data/texmf-config' TL_DOWNLOAD_DIRECTORY='${fixtureRoot}/.reqpack-data/downloads' LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' tlmgr '--usermode' '--usertree' '${fixtureRoot}/.reqpack-data/texmf-home' '--repository' 'ctan' 'update' '--all'",
      exitCode = 0,
      stdout = "updated all\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
