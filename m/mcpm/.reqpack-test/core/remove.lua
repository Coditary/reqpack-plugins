return {
  name = "mcpm remove installed server",
  request = {
    action = "remove",
    system = "mcpm",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
    packages = {
      { action = "remove", name = "sqlite" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'mcpm' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C MCPM_NON_INTERACTIVE=true MCPM_FORCE=true MCPM_JSON_OUTPUT=true MCPM_CONFIG_DIR='${fixtureRoot}/.reqpack-config/mcpm/config' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-cache/mcpm/cache' XDG_DATA_HOME='${fixtureRoot}/.reqpack-data/mcpm/data' mcpm uninstall 'sqlite' --force",
      exitCode = 0,
      stdout = [=[{"name":"sqlite","status":"removed"}]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
