return {
  name = "pub update targeted package",
  request = {
    action = "update",
    system = "pub",
    packages = {
      { name = "melos", flags = { "overwrite" } },
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
      match = "PUB_CACHE='/home/test/.cache/reqpack/pub/pub-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' dart 'pub' 'global' 'activate' '--overwrite' 'melos'",
      exitCode = 0,
      stdout = "Activated melos 6.3.3.\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'dart' >/dev/null 2>&1",
      "PUB_CACHE='/home/test/.cache/reqpack/pub/pub-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' dart 'pub' 'global' 'activate' '--overwrite' 'melos'"
    },
    events = { "updated", "success" },
  },
}
