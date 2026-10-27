return {
  name = "idris2-pkg remove library",
  request = {
    action = "remove",
    system = "idris2-pkg",
    packages = {
      { name = "hedgehog" }
    },
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/idris2-pkg/installed.tsv",
      content = "hedgehog\t1.0.0\t1.0.0\thedgehog\thttps://github.com/stefan-hoeck/idris2-hedgehog\tProperty based testing for Idris2\tfalse\n",
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
      match = "HOME='/home/test/.cache/reqpack/idris2-pkg/home' XDG_CONFIG_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.config' XDG_CACHE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.cache' XDG_STATE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/state' XDG_DATA_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/share' PACK_USER_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.config/pack' PACK_CACHE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.cache/pack' PACK_STATE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.local/state/pack' PACK_BIN_DIR='/home/test/.cache/reqpack/idris2-pkg/home/bin' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' pack remove 'hedgehog'",
      exitCode = 0,
      stdout = "removed\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/test/.cache/reqpack/idris2-pkg/installed.tsv'",
      exitCode = 0,
      stdout = "hedgehog\t1.0.0\t1.0.0\thedgehog\thttps://github.com/stefan-hoeck/idris2-hedgehog\tProperty based testing for Idris2\tfalse\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/home/test/.cache/reqpack/idris2-pkg' && printf %s '' > '/home/test/.cache/reqpack/idris2-pkg/installed.tsv'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
