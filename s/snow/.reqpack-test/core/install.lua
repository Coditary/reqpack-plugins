return {
  name = "snow install package",
  fixtureRoot = "/tmp/opencode/snow-install-case",
  request = {
    action = "install",
    system = "snow",
    flags = {
      "data-root=/tmp/opencode/snow-install-case/.reqpack-data",
      "cache-root=/tmp/opencode/snow-install-case/.reqpack-cache",
      "config-root=/tmp/opencode/snow-install-case/.reqpack-config",
    },
    packages = {
      { name = "(srfi 1)" }
    },
  },
  fakeExec = {
    { match = "command -v 'snow' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/snow-install-case/.reqpack-data/snow/home'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/snow-install-case/.reqpack-cache/snow/repo'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/snow-install-case/.reqpack-cache/snow/repo-root'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/snow-install-case/.reqpack-config/snow'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C HOME='/tmp/opencode/snow-install-case/.reqpack-data/snow/home' 'snow' '--local-user-repository=/tmp/opencode/snow-install-case/.reqpack-cache/snow/repo' '--local-root-repository=/tmp/opencode/snow-install-case/.reqpack-cache/snow/repo-root' '--update-strategy=cache' 'install' '(srfi 1)'", exitCode = 0, stdout = "installed\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
