return {
  name = "pub install local package",
  request = {
    action = "install",
    system = "pub",
    localPath = "./fixtures/tooling/demo_cli",
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
      match = "PUB_CACHE='/home/test/.cache/reqpack/pub/pub-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' dart 'pub' 'global' 'activate' '--source' 'path' './fixtures/tooling/demo_cli'",
      exitCode = 0,
      stdout = "Activated demo_cli from path.\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'dart' >/dev/null 2>&1",
      "PUB_CACHE='/home/test/.cache/reqpack/pub/pub-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' dart 'pub' 'global' 'activate' '--source' 'path' './fixtures/tooling/demo_cli'"
    },
    events = { "installed", "success" },
  },
}
