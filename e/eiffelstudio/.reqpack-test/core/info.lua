return {
  name = "eiffelstudio info package",
  request = {
    action = "info",
    system = "eiffelstudio",
    prompt = "base",
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
      match = "iron info 'base'",
      exitCode = 0,
      stdout = "Name: base\nTitle: EiffelBase\nVersion: 24.05\nSummary: Eiffel base library\nDescription: Core Eiffel library set\nLicense: Eiffel Forum License v2\nRepository: https://iron.eiffel.com/24.05\nURI: https://iron.eiffel.com/24.05/com.eiffel/library/base\nInstalled: yes\n",
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
  },
  expect = {
    success = true,
    commands = {
      "command -v iron >/dev/null 2>&1",
      "iron info 'base'",
      "iron path 'base'",
    },
    events = { "informed" },
    resultName = "base",
    resultVersion = "24.05",
  }
}
