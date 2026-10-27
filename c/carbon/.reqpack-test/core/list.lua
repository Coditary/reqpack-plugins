return {
  name = "carbon list installed packages",
  request = {
    action = "list",
    system = "carbon",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
  },
  fakeExec = {
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C HOME='${fixtureRoot}/.reqpack-config/carbon/home' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-config/carbon/xdg-config' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-cache/carbon/xdg-cache' XDG_DATA_HOME='${fixtureRoot}/.reqpack-data/carbon/xdg-data' carbon status",
      exitCode = 0,
      stdout = "NAMESPACE  NAME         VERSION  SOURCE\ndefault    api-service  1.2.3    registry.example.com/team/api:1.2.3\napps       web-ui       2.0.0    registry.example.com/team/web:2.0.0\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "api-service",
    resultVersion = "1.2.3",
    events = { "listed" },
  }
}
