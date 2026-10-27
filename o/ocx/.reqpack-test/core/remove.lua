return {
  name = "ocx remove installed component",
  request = {
    action = "remove",
    system = "ocx",
    flags = {
      "cwd=${fixtureRoot}/project",
    },
    packages = {
      { name = "kdco/workspace" },
    },
  },
  fixtureRoot = "/tmp/opencode/ocx-remove",
  fixtureDirs = {
    "project/.opencode",
    "project/.ocx",
  },
  fakeExec = {
    { match = "command -v 'ocx' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "ocx remove --cwd '${fixtureRoot}/project' --json 'kdco/workspace'", exitCode = 0, stdout = "{\n  \"success\": true,\n  \"removed\": [\"https://registry.kdco.dev::kdco/workspace@sha256:abc123\"],\n  \"notFound\": []\n}\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    resultCount = 0,
  },
}
