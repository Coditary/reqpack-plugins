return {
  name = "docker update image",
  request = {
    action = "update",
    system = "docker",
    packages = {
      { action = "update", name = "nginx" }
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
      match = "docker pull 'nginx:latest'",
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v docker >/dev/null 2>&1",
      "docker pull 'nginx:latest'"
    },
    stdout = { "updated\n" },
    events = { "updated", "success" },
    eventPayloads = {
      updated = "{name=nginx:latest, packageId=nginx:latest}",
      success = "ok",
    },
  }
}
