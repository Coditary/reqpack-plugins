return {
  name = "idris2-pkg install library",
  request = {
    action = "install",
    system = "idris2-pkg",
    packages = {
      { name = "hedgehog", version = "1.0.0" }
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
      match = "HOME='/home/test/.cache/reqpack/idris2-pkg/home' XDG_CONFIG_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.config' XDG_CACHE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.cache' XDG_STATE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/state' XDG_DATA_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/share' PACK_USER_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.config/pack' PACK_CACHE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.cache/pack' PACK_STATE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.local/state/pack' PACK_BIN_DIR='/home/test/.cache/reqpack/idris2-pkg/home/bin' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' pack install 'hedgehog'",
      exitCode = 0,
      stdout = "installed\n",
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
      match = "HOME='/home/test/.cache/reqpack/idris2-pkg/home' XDG_CONFIG_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.config' XDG_CACHE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.cache' XDG_STATE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/state' XDG_DATA_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/share' PACK_USER_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.config/pack' PACK_CACHE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.cache/pack' PACK_STATE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.local/state/pack' PACK_BIN_DIR='/home/test/.cache/reqpack/idris2-pkg/home/bin' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' pack --long-desc query 'hedgehog'",
      exitCode = 0,
      stdout = "hedgehog\n  Brief        : Property based testing for Idris2\n  URL          : https://github.com/stefan-hoeck/idris2-hedgehog\n  Dependencies : base\n",
      stderr = "",
      success = true,
    },
    {
      match = [[mkdir -p '/home/test/.cache/reqpack/idris2-pkg' && printf %s 'hedgehog	1.0.0	1.0.0	hedgehog	https://github.com/stefan-hoeck/idris2-hedgehog	Property based testing for Idris2	false
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
      "HOME='/home/test/.cache/reqpack/idris2-pkg/home' XDG_CONFIG_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.config' XDG_CACHE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.cache' XDG_STATE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/state' XDG_DATA_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/share' PACK_USER_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.config/pack' PACK_CACHE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.cache/pack' PACK_STATE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.local/state/pack' PACK_BIN_DIR='/home/test/.cache/reqpack/idris2-pkg/home/bin' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' pack install 'hedgehog'",
      "cat '/home/test/.cache/reqpack/idris2-pkg/installed.tsv'",
      "HOME='/home/test/.cache/reqpack/idris2-pkg/home' XDG_CONFIG_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.config' XDG_CACHE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.cache' XDG_STATE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/state' XDG_DATA_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/share' PACK_USER_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.config/pack' PACK_CACHE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.cache/pack' PACK_STATE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.local/state/pack' PACK_BIN_DIR='/home/test/.cache/reqpack/idris2-pkg/home/bin' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' pack --long-desc query 'hedgehog'",
      [[mkdir -p '/home/test/.cache/reqpack/idris2-pkg' && printf %s 'hedgehog	1.0.0	1.0.0	hedgehog	https://github.com/stefan-hoeck/idris2-hedgehog	Property based testing for Idris2	false
' > '/home/test/.cache/reqpack/idris2-pkg/installed.tsv']],
    },
    events = { "installed", "success" },
  },
}
