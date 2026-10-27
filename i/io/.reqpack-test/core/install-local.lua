return {
  name = "io install local package",
  fixtureRoot = "/tmp/opencode/io-install-local-case",
  request = {
    action = "installLocal",
    system = "io",
    localPath = "/tmp/opencode/io-install-local-case/pkg/Range",
    flags = {
      "data-root=/tmp/opencode/io-install-local-case/.reqpack-data",
      "cache-root=/tmp/opencode/io-install-local-case/.reqpack-cache",
      "config-root=/tmp/opencode/io-install-local-case/.reqpack-config",
    },
  },
  fixtureDirs = {
    "pkg",
    "pkg/Range",
  },
  fakeExec = {
    {
      match = "command -v 'eerie' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "/usr/local/bin/eerie\n",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C EERIEDIR='/tmp/opencode/io-install-local-case/.reqpack-data/io/eerie' eerie install '/tmp/opencode/io-install-local-case/pkg/Range'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
