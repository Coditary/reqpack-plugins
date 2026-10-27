return {
  name = "miktex update package with admin flag",
  request = {
    action = "update",
    system = "miktex",
    flags = { "admin" },
    packages = {
      { name = "amsfonts" },
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/miktex-update-case",
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
      match = "/usr/bin/miktex --admin packages update-package-database",
      exitCode = 0,
      stdout = "database refreshed\n",
      stderr = "",
      success = true,
    },
    {
      match = "/usr/bin/miktex --admin packages info --template '{id}|@|{displayName}|@|{title}|@|{version}|@|{isInstalled}|@|{isObsolete}|@|{isRemovable}|@|{licenseType}|@|{ctanPath}|@|{requiredPackages}|@|{targetSystem}' amsfonts",
      exitCode = 0,
      stdout = "amsfonts|@|AMS Fonts|@|AMS Fonts package|@|3.04|@|true|@|false|@|true|@|Knuth|@|/pkg/amsfonts|@|amsmath|@|windows\n",
      stderr = "",
      success = true,
    },
    {
      match = "/usr/bin/miktex --admin packages update amsfonts",
      exitCode = 0,
      stdout = "updated amsfonts\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/miktex-update-case/cache/reqpack/miktex'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "printf %s 'amsfonts|@|AMS Fonts|@|AMS Fonts package|@|3.05|@|true|@|false|@|true|@|Knuth|@|/pkg/amsfonts|@|amsmath|@|windows\n' > '/tmp/opencode/miktex-update-case/cache/reqpack/miktex/catalog.tsv'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "/usr/bin/miktex --admin packages list --template '{id}|@|{displayName}|@|{title}|@|{version}|@|{isInstalled}|@|{isObsolete}|@|{isRemovable}|@|{licenseType}|@|{ctanPath}|@|{requiredPackages}|@|{targetSystem}'",
      exitCode = 0,
      stdout = "amsfonts|@|AMS Fonts|@|AMS Fonts package|@|3.05|@|true|@|false|@|true|@|Knuth|@|/pkg/amsfonts|@|amsmath|@|windows\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    result = true,
    events = { "updated", "success" },
  },
}
