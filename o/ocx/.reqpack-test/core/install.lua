return {
  name = "ocx install component from ephemeral registry",
  request = {
    action = "install",
    system = "ocx",
    flags = {
      "cwd=${fixtureRoot}/project",
    },
    packages = {
      {
        name = "kdco/workspace",
        flags = {
          "from=https://registry.kdco.dev",
        },
      },
    },
  },
  fixtureRoot = "/tmp/opencode/ocx-install",
  fixtureDirs = {
    "project/.opencode",
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
    { match = "command -v 'ocx' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "ocx add --cwd '${fixtureRoot}/project' --json 'kdco/workspace' --from 'https://registry.kdco.dev'", exitCode = 0, stdout = "{\n  \"success\": true,\n  \"installed\": [\"kdco/workspace\"],\n  \"opencode\": false\n}\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/project/.ocx/receipt.jsonc'", exitCode = 0, stdout = "{\n  \"version\": 1,\n  \"installed\": {\n    \"https://registry.kdco.dev::kdco/workspace@sha256:abc123\": {\n      \"registryUrl\": \"https://registry.kdco.dev\",\n      \"registryName\": \"kdco\",\n      \"name\": \"workspace\",\n      \"revision\": \"sha256:abc123\",\n      \"hash\": \"abc123\",\n      \"files\": [],\n      \"installedAt\": \"2026-06-01T10:00:00Z\"\n    }\n  }\n}\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    resultCount = 0,
  },
}
