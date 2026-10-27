return {
  name = "docker load local archive",
  request = {
    action = "install",
    system = "docker",
    localPath = "/tmp/nginx.tar",
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
      match = "docker load --input '/tmp/nginx.tar'",
      exitCode = 0,
      stdout = "Loaded image: nginx:latest\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v docker >/dev/null 2>&1",
      "docker load --input '/tmp/nginx.tar'"
    },
    stdout = { "Loaded image: nginx:latest\n" },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, name=nginx:latest, packageId=nginx:latest, path=/tmp/nginx.tar}",
      success = "ok",
    },
  }
}
