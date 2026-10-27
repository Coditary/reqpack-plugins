return {
  name = "leiningen install local jar",
  request = {
    action = "install",
    system = "leiningen",
    localPath = "/tmp/demo-1.2.3.jar",
    flags = {
      "coord=com.example/demo",
      "version=1.2.3",
    },
    packages = {
      { name = "com.example/demo", version = "1.2.3" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'lein' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "lein help localrepo",
      exitCode = 0,
      stdout = "localrepo help\n",
      stderr = "",
      success = true,
    },
    {
      match = "lein localrepo install '/tmp/demo-1.2.3.jar' 'com.example/demo' '1.2.3'",
      exitCode = 0,
      stdout = "Installed demo\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'lein' >/dev/null 2>&1",
      "lein help localrepo",
      "lein localrepo install '/tmp/demo-1.2.3.jar' 'com.example/demo' '1.2.3'",
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, name=com.example/demo, path=/tmp/demo-1.2.3.jar, version=1.2.3}",
      success = "ok",
    },
  },
}
