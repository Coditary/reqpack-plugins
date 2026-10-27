return {
  name = "mcpm update specific server",
  request = {
    action = "update",
    system = "mcpm",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
    packages = {
      { action = "update", name = "github", flags = { "rebase" } }
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C MCPM_NON_INTERACTIVE=true MCPM_FORCE=true MCPM_JSON_OUTPUT=true MCPM_CONFIG_DIR='${fixtureRoot}/.reqpack-config/mcpm/config' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-cache/mcpm/cache' XDG_DATA_HOME='${fixtureRoot}/.reqpack-data/mcpm/data' mcpm update --rebase 'github'",
      exitCode = 0,
      stdout = [=[{"name":"github","status":"updated"}]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
