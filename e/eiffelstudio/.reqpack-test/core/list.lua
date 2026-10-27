return {
  name = "eiffelstudio list installed packages",
  request = {
    action = "list",
    system = "eiffelstudio",
  },
  fakeExec = {
    {
      match = "command -v iron >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "iron list --installed",
      exitCode = 0,
      stdout = "base 24.05 - EiffelBase library\nxml_parser 24.05 - XML parser library\n",
      stderr = "",
      success = true,
    },
    {
      match = "iron path 'base'",
      exitCode = 0,
      stdout = "/home/test/.iron/packages/base\n",
      stderr = "",
      success = true,
    },
    {
      match = "iron path 'xml_parser'",
      exitCode = 0,
      stdout = "/home/test/.iron/packages/xml_parser\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v iron >/dev/null 2>&1",
      "iron list --installed",
      "iron path 'base'",
      "iron path 'xml_parser'",
    },
    events = { "listed" },
    resultCount = 2,
    resultName = "base",
    resultVersion = "24.05",
  }
}
