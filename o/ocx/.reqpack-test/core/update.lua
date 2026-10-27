return {
  name = "ocx update specific component",
  request = {
    action = "update",
    system = "ocx",
    flags = {
      "cwd=${fixtureRoot}/project",
    },
    packages = {
      { name = "kdco/workspace" },
    },
  },
  fixtureRoot = "/tmp/opencode/ocx-update",
  fixtureDirs = {
    "project/.ocx",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/project/.ocx/receipt.jsonc",
      content = [=[{
  "version": 1,
  "installed": {
    "https://registry.kdco.dev::kdco/workspace@sha256:def456": {
      "registryUrl": "https://registry.kdco.dev",
      "registryName": "kdco",
      "name": "workspace",
      "revision": "sha256:def456",
      "hash": "def456",
      "files": [],
      "installedAt": "2026-06-01T10:00:00Z",
      "updatedAt": "2026-06-01T12:00:00Z"
    }
  }
}]=],
    },
  },
  fakeExec = {
    { match = "command -v 'ocx' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "ocx update --cwd '${fixtureRoot}/project' --json 'kdco/workspace'", exitCode = 0, stdout = "{\n  \"success\": true,\n  \"updated\": [{\n    \"qualifiedName\": \"https://registry.kdco.dev::kdco/workspace@sha256:def456\",\n    \"oldVersion\": \"sha256:abc123\",\n    \"newVersion\": \"sha256:def456\",\n    \"status\": \"updated\"\n  }],\n  \"upToDate\": []\n}\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/project/.ocx/receipt.jsonc'", exitCode = 0, stdout = "{\n  \"version\": 1,\n  \"installed\": {\n    \"https://registry.kdco.dev::kdco/workspace@sha256:def456\": {\n      \"registryUrl\": \"https://registry.kdco.dev\",\n      \"registryName\": \"kdco\",\n      \"name\": \"workspace\",\n      \"revision\": \"sha256:def456\",\n      \"hash\": \"def456\",\n      \"files\": [],\n      \"installedAt\": \"2026-06-01T10:00:00Z\",\n      \"updatedAt\": \"2026-06-01T12:00:00Z\"\n    }\n  }\n}\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
    resultCount = 0,
  },
}
