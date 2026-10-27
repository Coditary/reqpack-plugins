return {
  name = "io remove installed package",
  fixtureRoot = "/tmp/opencode/io-remove-case",
  request = {
    action = "remove",
    system = "io",
    flags = {
      "data-root=/tmp/opencode/io-remove-case/.reqpack-data",
      "cache-root=/tmp/opencode/io-remove-case/.reqpack-cache",
      "config-root=/tmp/opencode/io-remove-case/.reqpack-config",
    },
    packages = {
      { name = "Range" },
    },
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C EERIEDIR='/tmp/opencode/io-remove-case/.reqpack-data/io/eerie' eerie remove 'Range'",
      exitCode = 0,
      stdout = "removed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
