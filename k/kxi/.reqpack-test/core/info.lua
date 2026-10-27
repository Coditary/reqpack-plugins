return {
  name = "kxi info installed package",
  fixtureRoot = "/tmp/opencode/kxi-info-case",
  request = {
    action = "info",
    system = "kxi",
    prompt = "pkg-a",
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
  },
  fakeExec = {
    { match = "command -v kxi >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C KX_PACKAGE_PATH='${fixtureRoot}/packages' KX_ARTIFACT_PATH='${fixtureRoot}/artifacts' KX_DEPLOYMENT_PATH='${fixtureRoot}/deployments' kxi package list", exitCode = 0, stdout = [[{"pkg-a":{"1.0.0":{}}}]], stderr = "", success = true },
    { match = "test -d '${fixtureRoot}/packages'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "ls -1 '${fixtureRoot}/packages'", exitCode = 0, stdout = "pkg-a\n", stderr = "", success = true },
    { match = "ls -1 '${fixtureRoot}/packages/pkg-a'", exitCode = 0, stdout = "1.0.0\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "pkg-a",
    resultVersion = "1.0.0",
  },
}
