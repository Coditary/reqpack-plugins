return {
  name = "carbon install remote image",
  request = {
    action = "install",
    system = "carbon",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
      "namespace=apps",
      "minikube",
      "default-prune-white-list",
      "var=Cluster=dev",
      "var-file=/tmp/vars.yaml",
      "patch={\"op\":\"replace\"}",
      "patch-file=/tmp/patch.yaml",
    },
    packages = {
      { action = "install", name = "registry.example.com/team/api:1.2.3" }
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C HOME='${fixtureRoot}/.reqpack-config/carbon/home' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-config/carbon/xdg-config' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-cache/carbon/xdg-cache' XDG_DATA_HOME='${fixtureRoot}/.reqpack-data/carbon/xdg-data' carbon --minikube --namespace 'apps' --default-prune-white-list --var 'Cluster=dev' --var-file '/tmp/vars.yaml' --patch '{\"op\":\"replace\"}' --patch-file '/tmp/patch.yaml' install 'registry.example.com/team/api:1.2.3'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'carbon' >/dev/null 2>&1",
      "mkdir -p '${fixtureRoot}/.reqpack-config/carbon/home/.carbon'",
      "test -e '${fixtureRoot}/.reqpack-config/carbon/home/.carbon/carbon.vars' || printf %s '' > '${fixtureRoot}/.reqpack-config/carbon/home/.carbon/carbon.vars'",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C HOME='${fixtureRoot}/.reqpack-config/carbon/home' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-config/carbon/xdg-config' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-cache/carbon/xdg-cache' XDG_DATA_HOME='${fixtureRoot}/.reqpack-data/carbon/xdg-data' carbon --minikube --namespace 'apps' --default-prune-white-list --var 'Cluster=dev' --var-file '/tmp/vars.yaml' --patch '{\"op\":\"replace\"}' --patch-file '/tmp/patch.yaml' install 'registry.example.com/team/api:1.2.3'",
    },
    events = { "installed", "success" },
  }
}
