return {
  name = "ocx search remote components",
  request = {
    action = "search",
    system = "ocx",
    flags = {
      "cwd=${fixtureRoot}/project",
    },
    prompt = "workspace",
  },
  fixtureRoot = "/tmp/opencode/ocx-search",
  fixtureDirs = {
    "project/.opencode",
  },
  fakeExec = {
    { match = "command -v 'ocx' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "ocx search --cwd '${fixtureRoot}/project' --json 'workspace' --limit '20'", exitCode = 0, stdout = "{\n  \"success\": true,\n  \"data\": {\n    \"components\": [\n      {\n        \"name\": \"kdco/workspace\",\n        \"description\": \"Workspace profile\",\n        \"type\": \"profile\",\n        \"registry\": \"kdco\"\n      }\n    ]\n  }\n}\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "kdco/workspace",
  },
}
