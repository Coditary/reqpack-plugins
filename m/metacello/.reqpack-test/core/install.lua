return {
  name = "metacello install baseline",
  fixtureRoot = "/tmp/opencode/metacello-install",
  fixtureDirs = {
    "/tmp/opencode/metacello-install/.reqpack-data/state",
  },
  fixtureFiles = {
    {
      path = "/tmp/opencode/metacello-install/Pharo.image",
      content = "image",
    },
  },
  request = {
    action = "install",
    system = "metacello",
    packages = {
      {
        name = "PharoLauncher",
        version = "stable",
        flags = {
          "baseline",
          "repository=github://pharo-project/pharo-launcher:dev/src",
          "on-conflict=use-incoming",
          "data-root=/tmp/opencode/metacello-install/.reqpack-data",
          "cache-root=/tmp/opencode/metacello-install/.reqpack-cache",
          "image-path=/tmp/opencode/metacello-install/Pharo.image",
        },
      },
    },
  },
  fakeExec = {
    {
      match = "XDG_CACHE_HOME='/tmp/opencode/metacello-install/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-install/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-install/Pharo.image' '/tmp/opencode/metacello-install/.reqpack-data/state/metacello-install-PharoLauncher.st'",
      exitCode = 0,
      stdout = "REQPACK_METACELLO_JSON:{\"ok\":true,\"item\":{\"name\":\"PharoLauncher\",\"projectType\":\"baseline\",\"version\":\"stable\",\"repositorySpec\":\"github://pharo-project/pharo-launcher:dev/src\",\"loaded\":true,\"registered\":true}}\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "XDG_CACHE_HOME='/tmp/opencode/metacello-install/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-install/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-install/Pharo.image' '/tmp/opencode/metacello-install/.reqpack-data/state/metacello-install-PharoLauncher.st'",
    },
    events = { "installed", "success" },
  },
}
