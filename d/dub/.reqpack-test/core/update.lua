return {
  name = "dub update dependency",
  fixtureRoot = "../fixtures-update",
  request = {
    action = "update",
    system = "dub",
    flags = { "cache-root=${fixtureRoot}/.reqpack-data" },
    packages = {
      { name = "vibe-d", version = "0.9.6", packageType = "dependency" }
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "${fixtureRoot}",
  },
  fixtureDirs = {
    "${fixtureRoot}/.reqpack-data/project",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/.reqpack-data/project/dub.json",
      content = [[
{
  "name": "reqpack-dub-cache",
  "version": "0.0.0",
  "description": "ReqPack synthetic DUB dependency cache project",
  "dependencies": {
    "vibe-d": "0.9.5"
  }
}
]],
    },
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/.reqpack-data/project/dub.json'",
      exitCode = 0,
      stdout = "{\n  \"name\": \"reqpack-dub-cache\",\n  \"version\": \"0.0.0\",\n  \"description\": \"ReqPack synthetic DUB dependency cache project\",\n  \"dependencies\": {\n    \"vibe-d\": \"0.9.5\"\n  }\n}\n",
      stderr = "",
      success = true,
    },
    {
      match = "command -v dub >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd ${fixtureRoot}/.reqpack-data/project && NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C DUB_HOME=${fixtureRoot}/.reqpack-data/dub-home dub upgrade vibe-d",
      exitCode = 0,
      stdout = "Upgraded vibe-d\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
