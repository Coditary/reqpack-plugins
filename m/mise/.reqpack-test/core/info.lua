return {
  name = "mise info installed and registry-enriched tool",
  request = {
    action = "info",
    system = "mise",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
    prompt = "node@20.19.0",
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
      stdout = [=[{"node":[{"version":"20.19.0","install_path":"${fixtureRoot}/.reqpack-data/mise/data/installs/node/20.19.0","requested_version":"20","installed":true,"active":true,"source":{"type":"mise.toml","path":"${fixtureRoot}/.reqpack-config/mise/config/config.toml"}}]}]=],
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C MISE_DATA_DIR='${fixtureRoot}/.reqpack-data/mise/data' MISE_CACHE_DIR='${fixtureRoot}/.reqpack-cache/mise/cache' MISE_CONFIG_DIR='${fixtureRoot}/.reqpack-config/mise/config' MISE_STATE_DIR='${fixtureRoot}/.reqpack-data/mise/state' MISE_GLOBAL_CONFIG_FILE='${fixtureRoot}/.reqpack-config/mise/config/config.toml' mise registry --json",
      exitCode = 0,
      stdout = [=[[{"short":"node","backends":["core:node"],"description":"Node.js runtime"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C MISE_DATA_DIR='${fixtureRoot}/.reqpack-data/mise/data' MISE_CACHE_DIR='${fixtureRoot}/.reqpack-cache/mise/cache' MISE_CONFIG_DIR='${fixtureRoot}/.reqpack-config/mise/config' MISE_STATE_DIR='${fixtureRoot}/.reqpack-data/mise/state' MISE_GLOBAL_CONFIG_FILE='${fixtureRoot}/.reqpack-config/mise/config/config.toml' mise ls --installed --json",
      exitCode = 0,
      stdout = [=[{"node":[{"version":"20.19.0","install_path":"${fixtureRoot}/.reqpack-data/mise/data/installs/node/20.19.0","requested_version":"20","installed":true,"active":true,"source":{"type":"mise.toml","path":"${fixtureRoot}/.reqpack-config/mise/config/config.toml"}}]}]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed", "informed" },
    resultName = "node",
    resultVersion = "20.19.0",
  }
}
