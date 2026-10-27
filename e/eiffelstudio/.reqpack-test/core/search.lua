return {
  name = "eiffelstudio search packages",
  request = {
    action = "search",
    system = "eiffelstudio",
    prompt = "xml",
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
      match = "iron search 'xml'",
      exitCode = 0,
      stdout = "xml_parser 24.05 - XML parser library\nxml_rpc 1.2.0 - XML RPC support\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v iron >/dev/null 2>&1",
      "iron search 'xml'",
    },
    events = { "searched" },
    resultCount = 2,
    resultName = "xml_parser",
    resultVersion = "24.05",
  }
}
