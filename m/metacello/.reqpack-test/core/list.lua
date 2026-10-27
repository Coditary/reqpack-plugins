return {
  name = "metacello list tracked projects",
  fixtureRoot = "/tmp/opencode/metacello-list",
  fixtureDirs = {
    "/tmp/opencode/metacello-list/.reqpack-data/state",
  },
  fixtureFiles = {
    {
      path = "/tmp/opencode/metacello-list/Pharo.image",
      content = "image",
    },
    {
      path = "/tmp/opencode/metacello-list/.reqpack-data/state/installed.json",
      content = "{\"packages\":{\"PharoLauncher\":{\"name\":\"PharoLauncher\",\"projectType\":\"baseline\",\"repositorySpec\":\"github://pharo-project/pharo-launcher:dev/src\",\"version\":\"stable\",\"installed\":true}}}",
    },
  },
  request = {
    action = "list",
    system = "metacello",
    flags = {
      "data-root=/tmp/opencode/metacello-list/.reqpack-data",
      "cache-root=/tmp/opencode/metacello-list/.reqpack-cache",
      "image-path=/tmp/opencode/metacello-list/Pharo.image",
    },
  },
  fakeExec = {
    {
      match = "XDG_CACHE_HOME='/tmp/opencode/metacello-list/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-list/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-list/Pharo.image' '/tmp/opencode/metacello-list/.reqpack-data/state/metacello-list.st'",
      exitCode = 0,
      stdout = "REQPACK_METACELLO_JSON:{\"ok\":true,\"items\":[{\"name\":\"PharoLauncher\",\"projectType\":\"baseline\",\"version\":\"stable\",\"latestVersion\":\"stable\",\"repositorySpec\":\"github://pharo-project/pharo-launcher:dev/src\",\"loaded\":true,\"registered\":true,\"locked\":false}]}\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "XDG_CACHE_HOME='/tmp/opencode/metacello-list/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-list/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-list/Pharo.image' '/tmp/opencode/metacello-list/.reqpack-data/state/metacello-list.st'",
    },
    events = { "listed" },
    resultCount = 1,
    resultName = "PharoLauncher",
    resultVersion = "stable",
  },
}
