return {
  name = "mcpm create local stdio server",
  request = {
    action = "install",
    system = "mcpm",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
      "name=custom",
      "type=stdio",
      "args=--debug",
      "env=API_KEY=test",
      "force",
    },
    localPath = "/tmp/server.py",
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C MCPM_NON_INTERACTIVE=true MCPM_FORCE=true MCPM_JSON_OUTPUT=true MCPM_CONFIG_DIR='${fixtureRoot}/.reqpack-config/mcpm/config' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-cache/mcpm/cache' XDG_DATA_HOME='${fixtureRoot}/.reqpack-data/mcpm/data' mcpm new 'custom' --type 'stdio' --command '/tmp/server.py' --args '--debug' --env 'API_KEY=test' --force",
      exitCode = 0,
      stdout = [=[{"name":"custom","status":"installed"}]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'mcpm' >/dev/null 2>&1",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C MCPM_NON_INTERACTIVE=true MCPM_FORCE=true MCPM_JSON_OUTPUT=true MCPM_CONFIG_DIR='${fixtureRoot}/.reqpack-config/mcpm/config' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-cache/mcpm/cache' XDG_DATA_HOME='${fixtureRoot}/.reqpack-data/mcpm/data' mcpm new 'custom' --type 'stdio' --command '/tmp/server.py' --args '--debug' --env 'API_KEY=test' --force",
    },
    events = { "installed", "success" },
  }
}
