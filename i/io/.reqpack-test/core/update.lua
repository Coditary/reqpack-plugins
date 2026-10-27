return {
  name = "io update installed package",
  fixtureRoot = "/tmp/opencode/io-update-case",
  request = {
    action = "update",
    system = "io",
    flags = {
      "data-root=/tmp/opencode/io-update-case/.reqpack-data",
      "cache-root=/tmp/opencode/io-update-case/.reqpack-cache",
      "config-root=/tmp/opencode/io-update-case/.reqpack-config",
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C EERIEDIR='/tmp/opencode/io-update-case/.reqpack-data/io/eerie' eerie update 'Range'",
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  },
}
