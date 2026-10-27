return {
  name = "miktex info direct package lookup",
  request = {
    action = "info",
    system = "miktex",
    prompt = "amsfonts",
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/miktex-info-case",
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
      match = "/usr/bin/miktex packages info --template '{id}|@|{displayName}|@|{title}|@|{version}|@|{isInstalled}|@|{isObsolete}|@|{isRemovable}|@|{licenseType}|@|{ctanPath}|@|{requiredPackages}|@|{targetSystem}' amsfonts",
      exitCode = 0,
      stdout = "amsfonts|@|AMS Fonts|@|AMS Fonts package|@|3.04|@|true|@|false|@|true|@|Knuth|@|/pkg/amsfonts|@|amsmath|@|windows\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "amsfonts",
    resultVersion = "3.04",
  },
}
