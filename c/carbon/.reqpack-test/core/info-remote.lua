return {
  name = "carbon info remote image inspect",
  request = {
    action = "info",
    system = "carbon",
    prompt = "registry.example.com/team/api:1.2.3",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
  },
  fakeExec = {
    {
      match = "command -v 'carbon' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/.reqpack-config/carbon/home/.carbon'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -e '${fixtureRoot}/.reqpack-config/carbon/home/.carbon/carbon.vars' || printf %s '' > '${fixtureRoot}/.reqpack-config/carbon/home/.carbon/carbon.vars'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C HOME='${fixtureRoot}/.reqpack-config/carbon/home' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-config/carbon/xdg-config' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-cache/carbon/xdg-cache' XDG_DATA_HOME='${fixtureRoot}/.reqpack-data/carbon/xdg-data' carbon inspect 'registry.example.com/team/api:1.2.3'",
      exitCode = 0,
      stdout = "Name: api-service\nVersion: 1.2.3\nVariables:\n  NAME  DEFAULT  DESCRIPTION\n  Cluster  dev  Cluster name\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "api-service",
    resultVersion = "1.2.3",
    events = { "informed" },
  }
}
