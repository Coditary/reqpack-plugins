return {
  name = "idris2-pkg install local ipkg",
  request = {
    action = "installLocal",
    system = "idris2-pkg",
    localPath = "${fixtureRoot}/demo.ipkg",
    packages = {
      { name = "demo-local" }
    },
  },
  fixtureRoot = "../fixtures-core-install-local",
  fixtureFiles = {
    {
      path = "${fixtureRoot}/demo.ipkg",
      content = "package demo-local\n",
    },
  },
  fakeExec = {
    {
      match = "command -v 'pack' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/home/test/.cache/reqpack/idris2-pkg/home' XDG_CONFIG_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.config' XDG_CACHE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.cache' XDG_STATE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/state' XDG_DATA_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/share' PACK_USER_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.config/pack' PACK_CACHE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.cache/pack' PACK_STATE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.local/state/pack' PACK_BIN_DIR='/home/test/.cache/reqpack/idris2-pkg/home/bin' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' pack install-deps '${fixtureRoot}/demo.ipkg'",
      exitCode = 0,
      stdout = "deps installed\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/test/.cache/reqpack/idris2-pkg/installed.tsv'",
      exitCode = 1,
      stdout = "",
      stderr = "missing",
      success = false,
    },
    {
      match = [[mkdir -p '/home/test/.cache/reqpack/idris2-pkg' && printf %s 'demo			${fixtureRoot}/demo.ipkg	${fixtureRoot}/demo.ipkg	Local Idris2 project dependencies installed via pack	true
' > '/home/test/.cache/reqpack/idris2-pkg/installed.tsv']],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'pack' >/dev/null 2>&1",
      "HOME='/home/test/.cache/reqpack/idris2-pkg/home' XDG_CONFIG_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.config' XDG_CACHE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.cache' XDG_STATE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/state' XDG_DATA_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/share' PACK_USER_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.config/pack' PACK_CACHE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.cache/pack' PACK_STATE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.local/state/pack' PACK_BIN_DIR='/home/test/.cache/reqpack/idris2-pkg/home/bin' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' pack install-deps '${fixtureRoot}/demo.ipkg'",
      "cat '/home/test/.cache/reqpack/idris2-pkg/installed.tsv'",
      [[mkdir -p '/home/test/.cache/reqpack/idris2-pkg' && printf %s 'demo			${fixtureRoot}/demo.ipkg	${fixtureRoot}/demo.ipkg	Local Idris2 project dependencies installed via pack	true
' > '/home/test/.cache/reqpack/idris2-pkg/installed.tsv']],
    },
    events = { "installed", "success" },
  },
}
