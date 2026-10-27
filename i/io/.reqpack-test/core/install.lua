return {
  name = "io install git package",
  fixtureRoot = "/tmp/opencode/io-install-case",
  request = {
    action = "install",
    system = "io",
    flags = {
      "data-root=/tmp/opencode/io-install-case/.reqpack-data",
      "cache-root=/tmp/opencode/io-install-case/.reqpack-cache",
      "config-root=/tmp/opencode/io-install-case/.reqpack-config",
    },
    packages = {
      {
        name = "Range",
        sourcePath = "https://github.com/IoLanguage/Range.git",
      },
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C EERIEDIR='/tmp/opencode/io-install-case/.reqpack-data/io/eerie' eerie install 'https://github.com/IoLanguage/Range.git'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'eerie' >/dev/null 2>&1",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C EERIEDIR='/tmp/opencode/io-install-case/.reqpack-data/io/eerie' eerie install 'https://github.com/IoLanguage/Range.git'",
    },
    events = { "installed", "success" },
  },
}
