return {
  name = "mise update outdated tool",
  request = {
    action = "update",
    system = "mise",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
    packages = {
      { action = "update", name = "node" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'mise' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C MISE_DATA_DIR='${fixtureRoot}/.reqpack-data/mise/data' MISE_CACHE_DIR='${fixtureRoot}/.reqpack-cache/mise/cache' MISE_CONFIG_DIR='${fixtureRoot}/.reqpack-config/mise/config' MISE_STATE_DIR='${fixtureRoot}/.reqpack-data/mise/state' MISE_GLOBAL_CONFIG_FILE='${fixtureRoot}/.reqpack-config/mise/config/config.toml' mise outdated --json --inactive",
      exitCode = 0,
      stdout = [=[{"node":{"requested":"20","current":"20.18.0","latest":"20.19.0","source":{"type":"mise.toml","path":"/home/test/.config/reqpack/mise/config/config.toml"}}}]=],
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C MISE_DATA_DIR='${fixtureRoot}/.reqpack-data/mise/data' MISE_CACHE_DIR='${fixtureRoot}/.reqpack-cache/mise/cache' MISE_CONFIG_DIR='${fixtureRoot}/.reqpack-config/mise/config' MISE_STATE_DIR='${fixtureRoot}/.reqpack-data/mise/state' MISE_GLOBAL_CONFIG_FILE='${fixtureRoot}/.reqpack-config/mise/config/config.toml' mise install 'node@20.19.0'",
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
