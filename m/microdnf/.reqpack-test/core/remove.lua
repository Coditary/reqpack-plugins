return {
  name = "microdnf remove",
  request = {
    action = "remove",
    system = "microdnf",
    packages = {
      { name = "curl" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'microdnf' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "microdnf -y remove 'curl'",
      exitCode = 0,
      stdout = "Complete!\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    commands = {
      "microdnf -y remove 'curl'"
    },
    events = { "deleted", "success" },
  }
}
