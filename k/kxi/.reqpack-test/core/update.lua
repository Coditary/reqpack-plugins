return {
  name = "kxi update package",
  fixtureRoot = "/tmp/opencode/kxi-update-case",
  request = {
    action = "update",
    system = "kxi",
    flags = {
      "path=${fixtureRoot}/packages",
      "artifacts=${fixtureRoot}/artifacts",
      "deployments=${fixtureRoot}/deployments",
    },
    packages = {
      {
        name = "pkg-a",
        version = "1.0.0",
        flags = {
          "path=${fixtureRoot}/packages",
          "artifacts=${fixtureRoot}/artifacts",
          "deployments=${fixtureRoot}/deployments",
        },
      }
    },
  },
  environment = {
    KX_PACKAGE_PATH = "${fixtureRoot}/packages",
    KX_ARTIFACT_PATH = "${fixtureRoot}/artifacts",
    KX_DEPLOYMENT_PATH = "${fixtureRoot}/deployments",
  },
  fakeExec = {
    { match = "command -v kxi >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C KX_PACKAGE_PATH='${fixtureRoot}/packages' KX_ARTIFACT_PATH='${fixtureRoot}/artifacts' KX_DEPLOYMENT_PATH='${fixtureRoot}/deployments' kxi package install --force 'pkg-a/1.0.0'", exitCode = 0, stdout = [[{"pkg-a":[{"version":"1.0.0","_status":"InstallationStatus.SUCCESS"}]}]], stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  },
}
