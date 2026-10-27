return {
  name = "dub list merged state",
  fixtureRoot = "../fixtures-list",
  request = {
    action = "list",
    system = "dub",
    flags = { "cache-root=${fixtureRoot}/.reqpack-data" },
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
    "mir-core": "1.2.0"
  }
}
]],
    },
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/.reqpack-data/project/dub.json'",
      exitCode = 0,
      stdout = "{\n  \"name\": \"reqpack-dub-cache\",\n  \"version\": \"0.0.0\",\n  \"description\": \"ReqPack synthetic DUB dependency cache project\",\n  \"dependencies\": {\n    \"mir-core\": \"1.2.0\"\n  }\n}\n",
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C DUB_HOME=${fixtureRoot}/.reqpack-data/dub-home dub list",
      exitCode = 0,
      stdout = "vibe-d 0.9.5 /tmp/dub-home/packages/vibe-d-0.9.5/vibe-d/\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "vibe-d",
    events = { "listed" },
  }
}
