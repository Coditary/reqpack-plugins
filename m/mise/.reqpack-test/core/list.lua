return {
  name = "mise list installed tool versions",
  request = {
    action = "list",
    system = "mise",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
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
      stdout = [=[{"node":[{"version":"20.19.0","install_path":"${fixtureRoot}/.reqpack-data/mise/data/installs/node/20.19.0","requested_version":"20","installed":true,"active":true,"source":{"type":"mise.toml","path":"${fixtureRoot}/.reqpack-config/mise/config/config.toml"}}],"python":[{"version":"3.12.4","install_path":"${fixtureRoot}/.reqpack-data/mise/data/installs/python/3.12.4","requested_version":"3.12","installed":true,"active":false}]}]=],
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C MISE_DATA_DIR='${fixtureRoot}/.reqpack-data/mise/data' MISE_CACHE_DIR='${fixtureRoot}/.reqpack-cache/mise/cache' MISE_CONFIG_DIR='${fixtureRoot}/.reqpack-config/mise/config' MISE_STATE_DIR='${fixtureRoot}/.reqpack-data/mise/state' MISE_GLOBAL_CONFIG_FILE='${fixtureRoot}/.reqpack-config/mise/config/config.toml' mise registry --json",
      exitCode = 0,
      stdout = [=[[{"short":"node","backends":["core:node"],"description":"Node.js runtime"},{"short":"python","backends":["core:python"],"description":"Python runtime"}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "node",
    resultVersion = "20.19.0",
  }
}
