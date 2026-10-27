return {
  name = "fan install local pod archive",
  request = {
    action = "install",
    system = "fan",
    localPath = "/tmp/opencode/fan-local/example.pod",
  },
  fixtureDirs = {
    "/tmp/opencode/fan-local",
  },
  fixtureFiles = {
    {
      path = "/tmp/opencode/fan-local/example.pod",
      content = "pod-binary-placeholder",
    },
  },
  fakeExec = {
    {
      match = "command -v 'fanr' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "fanr config",
      exitCode = 0,
      stdout = "Fantom Repository Manager\n\nenv.home:       /home/test/fantom\nenv.work:       /home/test/.fantom\nrepo:           https://fantom.org/fanr/\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/home/test/.fantom/lib/fan' && cp '/tmp/opencode/fan-local/example.pod' '/home/test/.fantom/lib/fan/'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'fanr' >/dev/null 2>&1",
      "fanr config",
      "mkdir -p '/home/test/.fantom/lib/fan' && cp '/tmp/opencode/fan-local/example.pod' '/home/test/.fantom/lib/fan/'",
    },
    events = { "installed", "success" },
  }
}
