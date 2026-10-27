return {
  name = "miktex search cached catalog",
  request = {
    action = "search",
    system = "miktex",
    prompt = "font",
    flags = { "cache-root=/tmp/opencode/miktex-search-case/cache/reqpack" },
  },
  fixtureRoot = "/tmp/opencode/miktex-search-case",
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
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/miktex-search-case",
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
      match = "cat '/tmp/opencode/miktex-search-case/cache/reqpack/miktex/catalog.tsv'",
      exitCode = 0,
      stdout = "amsfonts|@|AMS Fonts|@|AMS Fonts package|@|3.04|@|true|@|false|@|true|@|Knuth|@|/pkg/amsfonts|@|amsmath|@|windows\ncm-super|@|CM Super|@|Computer Modern Super fonts|@|2.0|@|false|@|false|@|true|@|GPL|@|/pkg/cm-super|@||@|windows\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "amsfonts",
    resultVersion = "3.04",
  },
}
