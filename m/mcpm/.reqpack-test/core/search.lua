return {
  name = "mcpm search registry servers",
  request = {
    action = "search",
    system = "mcpm",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
    prompt = "git",
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C MCPM_NON_INTERACTIVE=true MCPM_FORCE=true MCPM_JSON_OUTPUT=true MCPM_CONFIG_DIR='${fixtureRoot}/.reqpack-config/mcpm/config' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-cache/mcpm/cache' XDG_DATA_HOME='${fixtureRoot}/.reqpack-data/mcpm/data' mcpm search 'git'",
      exitCode = 0,
      stdout = [=[{"results":[{"name":"github","description":"GitHub MCP server"},{"name":"git","description":"Local Git MCP server"}]}]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "git",
  }
}
