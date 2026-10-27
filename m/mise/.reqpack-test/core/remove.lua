return {
  name = "mise remove all installed tool versions",
  request = {
    action = "remove",
    system = "mise",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
    packages = {
      { action = "remove", name = "node" }
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C MISE_DATA_DIR='${fixtureRoot}/.reqpack-data/mise/data' MISE_CACHE_DIR='${fixtureRoot}/.reqpack-cache/mise/cache' MISE_CONFIG_DIR='${fixtureRoot}/.reqpack-config/mise/config' MISE_STATE_DIR='${fixtureRoot}/.reqpack-data/mise/state' MISE_GLOBAL_CONFIG_FILE='${fixtureRoot}/.reqpack-config/mise/config/config.toml' mise ls --installed --json",
      exitCode = 0,
      stdout = [=[{"node":[{"version":"20.19.0","install_path":"${fixtureRoot}/.reqpack-data/mise/data/installs/node/20.19.0","installed":true,"active":true},{"version":"22.5.1","install_path":"${fixtureRoot}/.reqpack-data/mise/data/installs/node/22.5.1","installed":true,"active":false}]}]=],
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C MISE_DATA_DIR='${fixtureRoot}/.reqpack-data/mise/data' MISE_CACHE_DIR='${fixtureRoot}/.reqpack-cache/mise/cache' MISE_CONFIG_DIR='${fixtureRoot}/.reqpack-config/mise/config' MISE_STATE_DIR='${fixtureRoot}/.reqpack-data/mise/state' MISE_GLOBAL_CONFIG_FILE='${fixtureRoot}/.reqpack-config/mise/config/config.toml' mise uninstall 'node@20.19.0'",
      exitCode = 0,
      stdout = "removed\n",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C MISE_DATA_DIR='${fixtureRoot}/.reqpack-data/mise/data' MISE_CACHE_DIR='${fixtureRoot}/.reqpack-cache/mise/cache' MISE_CONFIG_DIR='${fixtureRoot}/.reqpack-config/mise/config' MISE_STATE_DIR='${fixtureRoot}/.reqpack-data/mise/state' MISE_GLOBAL_CONFIG_FILE='${fixtureRoot}/.reqpack-config/mise/config/config.toml' mise uninstall 'node@22.5.1'",
      exitCode = 0,
      stdout = "removed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
