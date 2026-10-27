return {
  name = "carbon remove installed package",
  request = {
    action = "remove",
    system = "carbon",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
      "namespace=apps",
    },
    packages = {
      { action = "remove", name = "api-service" }
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C HOME='${fixtureRoot}/.reqpack-config/carbon/home' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-config/carbon/xdg-config' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-cache/carbon/xdg-cache' XDG_DATA_HOME='${fixtureRoot}/.reqpack-data/carbon/xdg-data' carbon --namespace 'apps' uninstall 'api-service'",
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
