return {
  name = "kxi install local artifact",
  fixtureRoot = "/tmp/opencode/kxi-install-local-case",
  request = {
    action = "installLocal",
    system = "kxi",
    flags = {
      "path=${fixtureRoot}/packages",
      "artifacts=${fixtureRoot}/artifacts",
      "deployments=${fixtureRoot}/deployments",
    },
    localPath = "/tmp/opencode/kxi-install-local-case/artifacts/pkg-local-2.0.0.kxi",
  },
  environment = {
    KX_PACKAGE_PATH = "${fixtureRoot}/packages",
    KX_ARTIFACT_PATH = "${fixtureRoot}/artifacts",
    KX_DEPLOYMENT_PATH = "${fixtureRoot}/deployments",
  },
  fakeExec = {
    { match = "command -v kxi >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C KX_PACKAGE_PATH='${fixtureRoot}/packages' KX_ARTIFACT_PATH='${fixtureRoot}/artifacts' KX_DEPLOYMENT_PATH='${fixtureRoot}/deployments' kxi package install '/tmp/opencode/kxi-install-local-case/artifacts/pkg-local-2.0.0.kxi'", exitCode = 0, stdout = [[{"pkg-local":[{"version":"2.0.0","_status":"InstallationStatus.SUCCESS"}]}]], stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{1=<lua-value>}",
      success = "ok",
    },
  },
}
