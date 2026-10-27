return {
  name = "metacello outdated tracked package",
  fixtureRoot = "/tmp/opencode/metacello-outdated",
  fixtureDirs = {
    "/tmp/opencode/metacello-outdated/.reqpack-data/state",
  },
  fixtureFiles = {
    {
      path = "/tmp/opencode/metacello-outdated/Pharo.image",
      content = "image",
    },
    {
      path = "/tmp/opencode/metacello-outdated/.reqpack-data/state/installed.json",
      content = "{\"packages\":{\"PharoLauncher\":{\"name\":\"PharoLauncher\",\"projectType\":\"baseline\",\"repositorySpec\":\"github://pharo-project/pharo-launcher:dev/src\",\"version\":\"stable\",\"installed\":true}}}",
    },
  },
  request = {
    action = "outdated",
    system = "metacello",
    flags = {
      "data-root=/tmp/opencode/metacello-outdated/.reqpack-data",
      "cache-root=/tmp/opencode/metacello-outdated/.reqpack-cache",
      "image-path=/tmp/opencode/metacello-outdated/Pharo.image",
    },
  },
  fakeExec = {
    {
      match = "XDG_CACHE_HOME='/tmp/opencode/metacello-outdated/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-outdated/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-outdated/Pharo.image' '/tmp/opencode/metacello-outdated/.reqpack-data/state/metacello-outdated-PharoLauncher.st'",
      exitCode = 0,
      stdout = "REQPACK_METACELLO_JSON:{\"ok\":true,\"item\":{\"name\":\"PharoLauncher\",\"projectType\":\"baseline\",\"version\":\"stable\",\"latestVersion\":\"v2.0.0\",\"repositorySpec\":\"github://pharo-project/pharo-launcher:dev/src\"}}\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "XDG_CACHE_HOME='/tmp/opencode/metacello-outdated/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-outdated/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-outdated/Pharo.image' '/tmp/opencode/metacello-outdated/.reqpack-data/state/metacello-outdated-PharoLauncher.st'",
    },
    events = { "outdated" },
    resultCount = 1,
    resultName = "PharoLauncher",
    resultVersion = "stable",
    resultLatestVersion = "v2.0.0",
  },
}
