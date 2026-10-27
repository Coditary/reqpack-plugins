return {
  name = "snow install local artifact",
  fixtureRoot = "/tmp/opencode/snow-install-local-case",
  request = {
    action = "installLocal",
    system = "snow",
    flags = {
      "data-root=/tmp/opencode/snow-install-local-case/.reqpack-data",
      "cache-root=/tmp/opencode/snow-install-local-case/.reqpack-cache",
      "config-root=/tmp/opencode/snow-install-local-case/.reqpack-config",
    },
    localPath = "/tmp/opencode/pkg.tgz",
  },
  fakeExec = {
    { match = "command -v 'snow' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/snow-install-local-case/.reqpack-data/snow/home'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/snow-install-local-case/.reqpack-cache/snow/repo'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/snow-install-local-case/.reqpack-cache/snow/repo-root'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/snow-install-local-case/.reqpack-config/snow'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C HOME='/tmp/opencode/snow-install-local-case/.reqpack-data/snow/home' 'snow' '--local-user-repository=/tmp/opencode/snow-install-local-case/.reqpack-cache/snow/repo' '--local-root-repository=/tmp/opencode/snow-install-local-case/.reqpack-cache/snow/repo-root' '--update-strategy=never' 'install' '/tmp/opencode/pkg.tgz'", exitCode = 0, stdout = "installed\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
