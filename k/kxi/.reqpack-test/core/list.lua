return {
  name = "kxi list installed packages",
  fixtureRoot = "/tmp/opencode/kxi-list-case",
  request = {
    action = "list",
    system = "kxi",
    flags = {
      "path=${fixtureRoot}/packages",
      "artifacts=${fixtureRoot}/artifacts",
      "deployments=${fixtureRoot}/deployments",
    },
  },
  environment = {
    KX_PACKAGE_PATH = "${fixtureRoot}/packages",
    KX_ARTIFACT_PATH = "${fixtureRoot}/artifacts",
    KX_DEPLOYMENT_PATH = "${fixtureRoot}/deployments",
  },
  fixtureDirs = {
    "packages",
    "packages/pkg-a",
    "packages/pkg-a/1.0.0",
    "packages/pkg-b",
    "packages/pkg-b/1.2.0",
  },
  fakeExec = {
    { match = "command -v kxi >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C KX_PACKAGE_PATH='${fixtureRoot}/packages' KX_ARTIFACT_PATH='${fixtureRoot}/artifacts' KX_DEPLOYMENT_PATH='${fixtureRoot}/deployments' kxi package list", exitCode = 0, stdout = [[{"pkg-a":{"1.0.0":{}},"pkg-b":{"1.2.0":{}}}]], stderr = "", success = true },
    { match = "test -d '${fixtureRoot}/packages'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "ls -1 '${fixtureRoot}/packages'", exitCode = 0, stdout = "pkg-a\npkg-b\n", stderr = "", success = true },
    { match = "ls -1 '${fixtureRoot}/packages/pkg-a'", exitCode = 0, stdout = "1.0.0\n", stderr = "", success = true },
    { match = "ls -1 '${fixtureRoot}/packages/pkg-b'", exitCode = 0, stdout = "1.2.0\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "pkg-a",
    resultVersion = "1.0.0",
  },
}
