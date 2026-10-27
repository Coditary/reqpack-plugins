return {
  name = "portage search packages",
  request = {
    action = "search",
    system = "portage",
    prompt = "firefox",
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C emerge --searchdesc 'firefox'",
      exitCode = 0,
      stdout = "*  www-client/firefox\n      Latest version available: 128.1\n      Latest version installed: [ 128.0 ]\n      Homepage:    https://www.mozilla.org/firefox\n      Description: Web browser\n      License:     MPL-2.0\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C emerge --searchdesc 'firefox'",
    },
    resultCount = 1,
    resultName = "www-client/firefox",
    resultVersion = "128.1",
    events = { "searched" },
  }
}
