return {
  name = "ocx outdated from dry-run update",
  request = {
    action = "outdated",
    system = "ocx",
    flags = {
      "cwd=${fixtureRoot}/project",
    },
  },
  fixtureRoot = "/tmp/opencode/ocx-outdated",
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
    { match = "command -v 'ocx' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "ocx update --cwd '${fixtureRoot}/project' --json 'kdco/workspace' --dry-run", exitCode = 0, stdout = "{\n  \"success\": true,\n  \"updated\": [{\n    \"qualifiedName\": \"https://registry.kdco.dev::kdco/workspace@sha256:abc123\",\n    \"oldVersion\": \"sha256:abc123\",\n    \"newVersion\": \"sha256:def456\",\n    \"status\": \"would-update\"\n  }],\n  \"upToDate\": []\n}\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "kdco/workspace",
    resultVersion = "sha256:abc123",
  },
}
