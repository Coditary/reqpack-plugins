return {
  name = "docker install image",
  request = {
    action = "install",
    system = "docker",
    packages = {
      { action = "install", name = "nginx", flags = { "platform=linux/amd64" } }
    },
  },
  fakeExec = {
    {
      match = "command -v docker >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "docker pull --platform 'linux/amd64' 'nginx:latest'",
      exitCode = 0,
      stdout = "pulled\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v docker >/dev/null 2>&1",
      "docker pull --platform 'linux/amd64' 'nginx:latest'"
    },
    stdout = { "pulled\n" },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{name=nginx:latest, packageId=nginx:latest}",
      success = "ok",
    },
  }
}
