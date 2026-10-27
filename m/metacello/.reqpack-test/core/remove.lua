return {
  name = "metacello remove tracked package",
  fixtureRoot = "/tmp/opencode/metacello-remove",
  fixtureDirs = {
    "/tmp/opencode/metacello-remove/.reqpack-data/state",
  },
  fixtureFiles = {
    {
      path = "/tmp/opencode/metacello-remove/Pharo.image",
      content = "image",
    },
    {
      path = "/tmp/opencode/metacello-remove/.reqpack-data/state/installed.json",
      content = "{\"packages\":{\"PharoLauncher\":{\"name\":\"PharoLauncher\",\"projectType\":\"baseline\",\"repositorySpec\":\"github://pharo-project/pharo-launcher:dev/src\",\"version\":\"stable\",\"installed\":true}}}",
    },
  },
  request = {
    action = "remove",
    system = "metacello",
    packages = {
      { name = "PharoLauncher", flags = { "data-root=/tmp/opencode/metacello-remove/.reqpack-data", "cache-root=/tmp/opencode/metacello-remove/.reqpack-cache", "image-path=/tmp/opencode/metacello-remove/Pharo.image", "repository=github://pharo-project/pharo-launcher:dev/src", "baseline" } },
    },
  },
  fakeExec = {
    {
      match = "XDG_CACHE_HOME='/tmp/opencode/metacello-remove/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-remove/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-remove/Pharo.image' '/tmp/opencode/metacello-remove/.reqpack-data/state/metacello-remove-PharoLauncher.st'",
      exitCode = 0,
      stdout = "REQPACK_METACELLO_JSON:{\"ok\":true,\"removed\":true,\"item\":{\"name\":\"PharoLauncher\"}}\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "XDG_CACHE_HOME='/tmp/opencode/metacello-remove/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-remove/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-remove/Pharo.image' '/tmp/opencode/metacello-remove/.reqpack-data/state/metacello-remove-PharoLauncher.st'",
    },
    events = { "deleted", "success" },
  },
}
