return {
  name = "metacello update tracked package",
  fixtureRoot = "/tmp/opencode/metacello-update",
  fixtureDirs = {
    "/tmp/opencode/metacello-update/.reqpack-data/state",
  },
  fixtureFiles = {
    {
      path = "/tmp/opencode/metacello-update/Pharo.image",
      content = "image",
    },
    {
      path = "/tmp/opencode/metacello-update/.reqpack-data/state/installed.json",
      content = "{\"packages\":{\"PharoLauncher\":{\"name\":\"PharoLauncher\",\"projectType\":\"baseline\",\"repositorySpec\":\"github://pharo-project/pharo-launcher:dev/src\",\"version\":\"stable\",\"installed\":true}}}",
    },
  },
  request = {
    action = "update",
    system = "metacello",
    packages = {
      { name = "PharoLauncher", flags = { "data-root=/tmp/opencode/metacello-update/.reqpack-data", "cache-root=/tmp/opencode/metacello-update/.reqpack-cache", "image-path=/tmp/opencode/metacello-update/Pharo.image", "repository=github://pharo-project/pharo-launcher:dev/src", "baseline" } },
    },
  },
  fakeExec = {
    {
      match = "XDG_CACHE_HOME='/tmp/opencode/metacello-update/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-update/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-update/Pharo.image' '/tmp/opencode/metacello-update/.reqpack-data/state/metacello-update-PharoLauncher.st'",
      exitCode = 0,
      stdout = "REQPACK_METACELLO_JSON:{\"ok\":true,\"item\":{\"name\":\"PharoLauncher\",\"projectType\":\"baseline\",\"version\":\"stable\",\"latestVersion\":\"stable\",\"repositorySpec\":\"github://pharo-project/pharo-launcher:dev/src\",\"loaded\":true,\"registered\":true}}\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "XDG_CACHE_HOME='/tmp/opencode/metacello-update/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-update/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-update/Pharo.image' '/tmp/opencode/metacello-update/.reqpack-data/state/metacello-update-PharoLauncher.st'",
    },
    events = { "updated", "success" },
  },
}
