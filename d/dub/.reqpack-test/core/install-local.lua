return {
  name = "dub install local dependency path",
  fixtureRoot = "../fixtures-install-local",
  request = {
    action = "install",
    system = "dub",
    flags = { "cache-root=${fixtureRoot}/.reqpack-data" },
    localPath = "${fixtureRoot}/demo-local",
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "${fixtureRoot}",
  },
  fixtureDirs = {
    "${fixtureRoot}/demo-local",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/demo-local/dub.json",
      content = [[
{
  "name": "demo-local",
  "version": "0.1.0"
}
]],
    },
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/demo-local/dub.json'",
      exitCode = 0,
      stdout = "{\n  \"name\": \"demo-local\",\n  \"version\": \"0.1.0\"\n}\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/.reqpack-data/project/dub.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "command -v dub >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd ${fixtureRoot}/.reqpack-data/project && NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C DUB_HOME=${fixtureRoot}/.reqpack-data/dub-home dub describe --vquiet",
      exitCode = 0,
      stdout = "{}\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v dub >/dev/null 2>&1",
      "cat '${fixtureRoot}/demo-local/dub.json'",
      "cat '${fixtureRoot}/.reqpack-data/project/dub.json'",
      "cd ${fixtureRoot}/.reqpack-data/project && NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C DUB_HOME=${fixtureRoot}/.reqpack-data/dub-home dub describe --vquiet"
    },
    events = { "installed", "success" },
  }
}
