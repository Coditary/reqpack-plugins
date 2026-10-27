return {
  name = "metacello repository scoped search",
  fixtureRoot = "/tmp/opencode/metacello-search",
  fixtureDirs = {
    "/tmp/opencode/metacello-search/.reqpack-data/state",
  },
  fixtureFiles = {
    {
      path = "/tmp/opencode/metacello-search/Pharo.image",
      content = "image",
    },
  },
  request = {
    action = "search",
    system = "metacello",
    prompt = "launcher",
    flags = {
      "data-root=/tmp/opencode/metacello-search/.reqpack-data",
      "cache-root=/tmp/opencode/metacello-search/.reqpack-cache",
      "image-path=/tmp/opencode/metacello-search/Pharo.image",
      "repository=github://pharo-project/pharo-launcher:dev/src",
      "baseline",
    },
  },
  fakeExec = {
    {
      match = "XDG_CACHE_HOME='/tmp/opencode/metacello-search/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-search/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-search/Pharo.image' '/tmp/opencode/metacello-search/.reqpack-data/state/metacello-search.st'",
      exitCode = 0,
      stdout = "REQPACK_METACELLO_JSON:{\"ok\":true,\"items\":[{\"name\":\"PharoLauncher\",\"projectType\":\"baseline\",\"version\":\"stable\",\"latestVersion\":\"stable\",\"repositorySpec\":\"github://pharo-project/pharo-launcher:dev/src\"},{\"name\":\"OtherTool\",\"projectType\":\"baseline\",\"version\":\"stable\",\"repositorySpec\":\"github://pharo-project/pharo-launcher:dev/src\"}]}\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "XDG_CACHE_HOME='/tmp/opencode/metacello-search/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-search/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-search/Pharo.image' '/tmp/opencode/metacello-search/.reqpack-data/state/metacello-search.st'",
    },
    events = { "searched" },
    resultCount = 1,
    resultName = "PharoLauncher",
    resultVersion = "stable",
  },
}
