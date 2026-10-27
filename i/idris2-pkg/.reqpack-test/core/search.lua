return {
  name = "idris2-pkg search collection",
  request = {
    action = "search",
    system = "idris2-pkg",
    prompt = "hedgehog",
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
      match = "HOME='/home/test/.cache/reqpack/idris2-pkg/home' XDG_CONFIG_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.config' XDG_CACHE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.cache' XDG_STATE_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/state' XDG_DATA_HOME='/home/test/.cache/reqpack/idris2-pkg/home/.local/share' PACK_USER_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.config/pack' PACK_CACHE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.cache/pack' PACK_STATE_DIR='/home/test/.cache/reqpack/idris2-pkg/home/.local/state/pack' PACK_BIN_DIR='/home/test/.cache/reqpack/idris2-pkg/home/bin' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' SHELL='/bin/sh' pack --short-desc query 'hedgehog'",
      exitCode = 0,
      stdout = "hedgehog\n  Property based testing for Idris2\nhedgehog-extra\n  Extra helpers for hedgehog\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "hedgehog",
  },
}
