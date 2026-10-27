return {
  name = "pub remove global package",
  request = {
    action = "remove",
    system = "pub",
    packages = {
      { name = "melos" },
    },
  },
  fakeExec = {
    {
      match = "command -v 'dart' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "PUB_CACHE='/home/test/.cache/reqpack/pub/pub-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' dart 'pub' 'global' 'deactivate' 'melos'",
      exitCode = 0,
      stdout = "Deactivated melos.\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'dart' >/dev/null 2>&1",
      "PUB_CACHE='/home/test/.cache/reqpack/pub/pub-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' dart 'pub' 'global' 'deactivate' 'melos'"
    },
    events = { "deleted", "success" },
  },
}
