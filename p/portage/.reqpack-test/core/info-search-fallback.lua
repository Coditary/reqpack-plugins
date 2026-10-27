return {
  name = "portage info package via search fallback",
  request = {
    action = "info",
    system = "portage",
    prompt = "www-client/firefox",
  },
  fakeExec = {
    {
      match = "command -v 'emerge' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'equery' >/dev/null 2>&1",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C emerge --searchdesc 'www-client/firefox'",
      exitCode = 0,
      stdout = "*  www-client/firefox\n      Latest version available: 128.1\n      Latest version installed: [ Not Installed ]\n      Homepage:    https://www.mozilla.org/firefox\n      Description: Web browser\n      License:     MPL-2.0\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'equery' >/dev/null 2>&1",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C emerge --searchdesc 'www-client/firefox'",
    },
    resultCount = 1,
    resultName = "www-client/firefox",
    resultVersion = "128.1",
    events = { "informed" },
  }
}
