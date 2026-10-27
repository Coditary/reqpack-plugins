return {
  name = "scsh install local package",
  fixtureRoot = "/tmp/opencode/scsh-install-local-case",
  request = {
    action = "installLocal",
    system = "scsh",
    flags = { "data-root=/tmp/opencode/scsh-install-local-case/.reqpack-data" },
    localPath = "/tmp/opencode/scsh-install-local-case/local/demo-pkg",
  },
  fixtureDirs = {
    "local/demo-pkg",
  },
  fakeExec = {
    { match = "command -v 'scsh-install-pkg' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/scsh-install-local-case/.reqpack-data/scsh'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '/tmp/opencode/scsh-install-local-case/.reqpack-data/scsh/state/installed.tsv'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "mkdir -p '/tmp/opencode/scsh-install-local-case/.reqpack-data/scsh/home/packages/demo-pkg'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "scsh-install-pkg --dest-dir '/tmp/opencode/scsh-install-local-case/.reqpack-data/scsh/home/packages/demo-pkg' '/tmp/opencode/scsh-install-local-case/local/demo-pkg'", exitCode = 0, stdout = "installed local\n", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-31T00:00:00Z\n", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/scsh-install-local-case/.reqpack-data/scsh/state'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s 'demo-pkg\t\t/tmp/opencode/scsh-install-local-case/.reqpack-data/scsh/home/packages/demo-pkg\tlocal\t/tmp/opencode/scsh-install-local-case/local/demo-pkg\t2026-05-31T00:00:00Z\t\n' > '/tmp/opencode/scsh-install-local-case/.reqpack-data/scsh/state/installed.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    result = true,
    events = { "installed", "success" },
  },
}
