return {
  name = "miktex list installed from cached catalog",
  request = {
    action = "list",
    system = "miktex",
    flags = { "cache-root=/tmp/opencode/miktex-list-case/cache/reqpack" },
  },
  fixtureRoot = "/tmp/opencode/miktex-list-case",
  fixtureDirs = {
    "cache/reqpack/miktex",
  },
  fixtureFiles = {
    {
      path = "cache/reqpack/miktex/catalog.tsv",
      content = "amsfonts|@|AMS Fonts|@|AMS Fonts package|@|3.04|@|true|@|false|@|true|@|Knuth|@|/pkg/amsfonts|@|amsmath|@|windows\ncm-super|@|CM Super|@|Computer Modern Super fonts|@|2.0|@|false|@|false|@|true|@|GPL|@|/pkg/cm-super|@||@|windows\n",
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/miktex-list-case",
  },
  fakeExec = {
    {
      match = "command -v miktex 2>/dev/null",
      exitCode = 0,
      stdout = "/usr/bin/miktex\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/miktex-list-case/cache/reqpack/miktex/catalog.tsv'",
      exitCode = 0,
      stdout = "amsfonts|@|AMS Fonts|@|AMS Fonts package|@|3.04|@|true|@|false|@|true|@|Knuth|@|/pkg/amsfonts|@|amsmath|@|windows\ncm-super|@|CM Super|@|Computer Modern Super fonts|@|2.0|@|false|@|false|@|true|@|GPL|@|/pkg/cm-super|@||@|windows\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "amsfonts",
    resultVersion = "3.04",
  },
}
