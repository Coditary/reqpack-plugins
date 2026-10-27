return {
  name = "metacello install local filetree",
  fixtureRoot = "/tmp/opencode/metacello-install-local",
  fixtureDirs = {
    "/tmp/opencode/metacello-install-local/.reqpack-data/state",
    "/tmp/opencode/metacello-install-local/local-repo",
  },
  fixtureFiles = {
    {
      path = "/tmp/opencode/metacello-install-local/Pharo.image",
      content = "image",
    },
  },
  request = {
    action = "install",
    system = "metacello",
    name = "LocalDemo",
    localPath = "/tmp/opencode/metacello-install-local/local-repo",
    flags = {
      "baseline",
      "data-root=/tmp/opencode/metacello-install-local/.reqpack-data",
      "cache-root=/tmp/opencode/metacello-install-local/.reqpack-cache",
      "image-path=/tmp/opencode/metacello-install-local/Pharo.image",
    },
    packages = {
      {
        name = "LocalDemo",
        flags = {
          "baseline",
          "data-root=/tmp/opencode/metacello-install-local/.reqpack-data",
          "cache-root=/tmp/opencode/metacello-install-local/.reqpack-cache",
          "image-path=/tmp/opencode/metacello-install-local/Pharo.image",
        },
      },
    },
  },
  fakeExec = {
    {
      match = "XDG_CACHE_HOME='/tmp/opencode/metacello-install-local/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-install-local/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-install-local/Pharo.image' '/tmp/opencode/metacello-install-local/.reqpack-data/state/metacello-install-local-local-repo.st'",
      exitCode = 0,
      stdout = "REQPACK_METACELLO_JSON:{\"ok\":true,\"item\":{\"name\":\"LocalDemo\",\"projectType\":\"baseline\",\"version\":\"\",\"repositorySpec\":\"filetree:///tmp/opencode/metacello-install-local/local-repo\",\"loaded\":true,\"registered\":true}}\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "XDG_CACHE_HOME='/tmp/opencode/metacello-install-local/.reqpack-cache' PHARO_CACHE_DIR='/tmp/opencode/metacello-install-local/.reqpack-cache/package-cache' pharo --headless '/tmp/opencode/metacello-install-local/Pharo.image' '/tmp/opencode/metacello-install-local/.reqpack-data/state/metacello-install-local-local-repo.st'",
    },
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  },
}
