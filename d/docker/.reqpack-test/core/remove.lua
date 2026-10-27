return {
  name = "docker remove image",
  request = {
    action = "remove",
    system = "docker",
    packages = {
      { action = "remove", name = "nginx:latest" }
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
      match = "docker image rm 'nginx:latest'",
      exitCode = 0,
      stdout = "deleted\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v docker >/dev/null 2>&1",
      "docker image rm 'nginx:latest'"
    },
    stdout = { "deleted\n" },
    events = { "deleted", "success" },
    eventPayloads = {
      deleted = "{name=nginx:latest, packageId=nginx:latest}",
      success = "ok",
    },
  }
}
