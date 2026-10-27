return {
  name = "miktex install packages",
  request = {
    action = "install",
    system = "miktex",
    packages = {
      { name = "amsfonts" },
      { name = "cm-super" },
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/miktex-install-case",
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
      match = "/usr/bin/miktex packages update-package-database",
      exitCode = 0,
      stdout = "database refreshed\n",
      stderr = "",
      success = true,
    },
    {
      match = "/usr/bin/miktex packages info --template '{id}|@|{displayName}|@|{title}|@|{version}|@|{isInstalled}|@|{isObsolete}|@|{isRemovable}|@|{licenseType}|@|{ctanPath}|@|{requiredPackages}|@|{targetSystem}' amsfonts",
      exitCode = 0,
      stdout = "amsfonts|@|AMS Fonts|@|AMS Fonts package|@|3.04|@|false|@|false|@|true|@|Knuth|@|/pkg/amsfonts|@|amsmath|@|windows\n",
      stderr = "",
      success = true,
    },
    {
      match = "/usr/bin/miktex packages info --template '{id}|@|{displayName}|@|{title}|@|{version}|@|{isInstalled}|@|{isObsolete}|@|{isRemovable}|@|{licenseType}|@|{ctanPath}|@|{requiredPackages}|@|{targetSystem}' cm-super",
      exitCode = 0,
      stdout = "cm-super|@|CM Super|@|Computer Modern Super fonts|@|2.0|@|false|@|false|@|true|@|GPL|@|/pkg/cm-super|@||@|windows\n",
      stderr = "",
      success = true,
    },
    {
      match = "/usr/bin/miktex packages install amsfonts cm-super",
      exitCode = 0,
      stdout = "installed 2 packages\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/miktex-install-case/cache/reqpack/miktex'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "printf %s 'amsfonts|@|AMS Fonts|@|AMS Fonts package|@|3.04|@|true|@|false|@|true|@|Knuth|@|/pkg/amsfonts|@|amsmath|@|windows\ncm-super|@|CM Super|@|Computer Modern Super fonts|@|2.0|@|true|@|false|@|true|@|GPL|@|/pkg/cm-super|@||@|windows\n' > '/tmp/opencode/miktex-install-case/cache/reqpack/miktex/catalog.tsv'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "/usr/bin/miktex packages list --template '{id}|@|{displayName}|@|{title}|@|{version}|@|{isInstalled}|@|{isObsolete}|@|{isRemovable}|@|{licenseType}|@|{ctanPath}|@|{requiredPackages}|@|{targetSystem}'",
      exitCode = 0,
      stdout = "amsfonts|@|AMS Fonts|@|AMS Fonts package|@|3.04|@|true|@|false|@|true|@|Knuth|@|/pkg/amsfonts|@|amsmath|@|windows\ncm-super|@|CM Super|@|Computer Modern Super fonts|@|2.0|@|true|@|false|@|true|@|GPL|@|/pkg/cm-super|@||@|windows\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    result = true,
    events = { "installed", "success" },
  },
}
