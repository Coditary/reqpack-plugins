return {
  name = "pub install global package",
  request = {
    action = "install",
    system = "pub",
    packages = {
      { name = "melos", version = "6.3.2", flags = { "overwrite", "executable=melos" } },
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
      match = "PUB_CACHE='/home/test/.cache/reqpack/pub/pub-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' dart 'pub' 'global' 'activate' '--overwrite' '--executable=melos' 'melos' '6.3.2'",
      exitCode = 0,
      stdout = "Activated melos 6.3.2.\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'dart' >/dev/null 2>&1",
      "PUB_CACHE='/home/test/.cache/reqpack/pub/pub-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' dart 'pub' 'global' 'activate' '--overwrite' '--executable=melos' 'melos' '6.3.2'"
    },
    events = { "installed", "success" },
  },
}
