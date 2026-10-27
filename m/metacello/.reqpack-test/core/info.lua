return {
  name = "metacello info tracked package",
  fixtureRoot = "/tmp/opencode/metacello-info",
  fixtureDirs = {
    "/tmp/opencode/metacello-info/.reqpack-data/state",
  },
  fixtureFiles = {
    {
      path = "/tmp/opencode/metacello-info/Pharo.image",
      content = "image",
    },
    {
      path = "/tmp/opencode/metacello-info/.reqpack-data/state/installed.json",
      content = "{\"packages\":{\"PharoLauncher\":{\"name\":\"PharoLauncher\",\"projectType\":\"baseline\",\"repositorySpec\":\"github://pharo-project/pharo-launcher:dev/src\",\"version\":\"stable\",\"installed\":true}}}",
    },
  },
  request = {
    action = "info",
    system = "metacello",
    prompt = "PharoLauncher",
    flags = {
      "data-root=/tmp/opencode/metacello-info/.reqpack-data",
      "cache-root=/tmp/opencode/metacello-info/.reqpack-cache",
      "image-path=/tmp/opencode/metacello-info/Pharo.image",
    },
  },
  fakeExec = {
    {
      match = "XDG_CACHE_HOME='/tmp/opencode/metacello-info/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-info/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-info/Pharo.image' '/tmp/opencode/metacello-info/.reqpack-data/state/metacello-info-PharoLauncher.st'",
      exitCode = 0,
      stdout = "REQPACK_METACELLO_JSON:{\"ok\":true,\"item\":{\"name\":\"PharoLauncher\",\"projectType\":\"baseline\",\"version\":\"stable\",\"latestVersion\":\"v2.0.0\",\"summary\":\"Pharo launcher\",\"repositorySpec\":\"github://pharo-project/pharo-launcher:dev/src\",\"loaded\":true,\"registered\":true}}\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "XDG_CACHE_HOME='/tmp/opencode/metacello-info/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-info/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-info/Pharo.image' '/tmp/opencode/metacello-info/.reqpack-data/state/metacello-info-PharoLauncher.st'",
    },
    events = { "informed" },
    resultCount = 1,
    resultName = "PharoLauncher",
    resultVersion = "stable",
    resultLatestVersion = "v2.0.0",
  },
}
