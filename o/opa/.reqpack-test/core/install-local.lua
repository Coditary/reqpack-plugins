return {
  name = "opa install local directory target",
  request = {
    action = "installLocal",
    system = "opa",
    localPath = "${fixtureRoot}/workspace/project",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
    },
  },
  fixtureRoot = "/tmp/opencode/opa-install-local",
  fixtureDirs = {
    "workspace/project",
    ".reqpack-data/opa",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/workspace/project/project.opack",
      content = "main.opa\n",
    },
    {
      path = "${fixtureRoot}/workspace/project/a.exe",
      content = "binary\n",
    },
  },
  fakeExec = {
    { match = "command -v 'opa' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL=C LANG=C LANGUAGE=C opa --version", exitCode = 0, stdout = "Opa 1.0.7\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-data/opa/inventory.tsv'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/project'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "ls -1 '${fixtureRoot}/workspace/project'", exitCode = 0, stdout = "project.opack\na.exe\n", stderr = "", success = true },
    { match = "LC_ALL=C LANG=C LANGUAGE=C opa '${fixtureRoot}/workspace/project/project.opack'", exitCode = 0, stdout = "built\n", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/project/project.opx'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/project/_build'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/project/project.exe'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/project/project'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/opa'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s 'opa/${fixtureRoot}/workspace/project/project.opack\tproject\t${fixtureRoot}/workspace/project/project.opack\topack\tbuild\t\n' > '${fixtureRoot}/.reqpack-data/opa/inventory.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
