return {
  name = "dub info with local dependency state",
  fixtureRoot = "../fixtures-info",
  request = {
    action = "info",
    system = "dub",
    prompt = "vibe-d",
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
      match = "curl -fsSL 'https://code.dlang.org/api/packages/infos?packages=%5B%22vibe-d%22%5D&include_dependencies=true&minimize=true'",
      exitCode = 0,
      stdout = [[{"vibe-d":{"name":"vibe-d","version":"0.9.6","description":"Async web framework","license":"MIT","homepage":"https://vibed.org"}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "vibe-d",
    resultVersion = "0.9.5",
    events = { "informed" },
  }
}
