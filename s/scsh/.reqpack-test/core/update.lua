return {
  name = "scsh update tracked package",
  fixtureRoot = "/tmp/opencode/scsh-update-case",
  request = {
    action = "update",
    system = "scsh",
    flags = { "data-root=/tmp/opencode/scsh-update-case/.reqpack-data" },
    packages = {
      { name = "foo" }
    },
  },
  fixtureDirs = {
    ".reqpack-data/scsh/state",
  },
  fixtureFiles = {
    { path = ".reqpack-data/scsh/state/installed.tsv", content = "foo\t1.0.0\t/tmp/opencode/scsh-update-case/.reqpack-data/scsh/home/packages/foo\tremote\tfoo\t2026-05-31T00:00:00Z\t\n" },
  },
  fakeExec = {
    { match = "cat '/tmp/opencode/scsh-update-case/.reqpack-data/scsh/state/installed.tsv'", exitCode = 0, stdout = "foo\t1.0.0\t/tmp/opencode/scsh-update-case/.reqpack-data/scsh/home/packages/foo\tremote\tfoo\t2026-05-31T00:00:00Z\t\n", stderr = "", success = true },
    { match = "command -v 'scsh-install-pkg' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "scsh-install-pkg --dest-dir '/tmp/opencode/scsh-update-case/.reqpack-data/scsh/home/packages/foo' 'foo'", exitCode = 0, stdout = "updated foo\n", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-31T00:00:00Z\n", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/scsh-update-case/.reqpack-data/scsh/state'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s 'foo\t1.0.0\t/tmp/opencode/scsh-update-case/.reqpack-data/scsh/home/packages/foo\tremote\tfoo\t2026-05-31T00:00:00Z\t\n' > '/tmp/opencode/scsh-update-case/.reqpack-data/scsh/state/installed.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    result = true,
    events = { "updated", "success" },
  },
}
