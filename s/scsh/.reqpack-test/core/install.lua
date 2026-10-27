return {
  name = "scsh install package",
  fixtureRoot = "/tmp/opencode/scsh-install-case",
  request = {
    action = "install",
    system = "scsh",
    flags = { "data-root=/tmp/opencode/scsh-install-case/.reqpack-data" },
    packages = {
      { name = "foo" }
    },
  },
  fakeExec = {
    { match = "command -v 'scsh-install-pkg' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/scsh-install-case/.reqpack-data/scsh'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '/tmp/opencode/scsh-install-case/.reqpack-data/scsh/state/installed.tsv'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "mkdir -p '/tmp/opencode/scsh-install-case/.reqpack-data/scsh/home/packages/foo'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "scsh-install-pkg --dest-dir '/tmp/opencode/scsh-install-case/.reqpack-data/scsh/home/packages/foo' 'foo'", exitCode = 0, stdout = "installed foo\n", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-31T00:00:00Z\n", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/scsh-install-case/.reqpack-data/scsh/state'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s 'foo\t\t/tmp/opencode/scsh-install-case/.reqpack-data/scsh/home/packages/foo\tremote\tfoo\t2026-05-31T00:00:00Z\t\n' > '/tmp/opencode/scsh-install-case/.reqpack-data/scsh/state/installed.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    result = true,
    events = { "installed", "success" },
  },
}
