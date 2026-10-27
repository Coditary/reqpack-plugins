return {
  name = "ocx list installed components from receipt",
  request = {
    action = "list",
    system = "ocx",
    flags = {
      "cwd=${fixtureRoot}/project",
    },
  },
  fixtureRoot = "/tmp/opencode/ocx-list",
  fixtureDirs = {
    "project/.ocx",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/project/.ocx/receipt.jsonc",
      content = [=[{
  "version": 1,
  "installed": {
    "https://registry.kdco.dev::kdco/workspace@sha256:abc123": {
      "registryUrl": "https://registry.kdco.dev",
      "registryName": "kdco",
      "name": "workspace",
      "revision": "sha256:abc123",
      "hash": "abc123",
      "files": [],
      "installedAt": "2026-06-01T10:00:00Z"
    }
  }
}]=],
    },
  },
  fakeExec = {
    { match = "cat '${fixtureRoot}/project/.ocx/receipt.jsonc'", exitCode = 0, stdout = "{\n  \"version\": 1,\n  \"installed\": {\n    \"https://registry.kdco.dev::kdco/workspace@sha256:abc123\": {\n      \"registryUrl\": \"https://registry.kdco.dev\",\n      \"registryName\": \"kdco\",\n      \"name\": \"workspace\",\n      \"revision\": \"sha256:abc123\",\n      \"hash\": \"abc123\",\n      \"files\": [],\n      \"installedAt\": \"2026-06-01T10:00:00Z\"\n    }\n  }\n}\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "kdco/workspace",
    resultVersion = "sha256:abc123",
  },
}
