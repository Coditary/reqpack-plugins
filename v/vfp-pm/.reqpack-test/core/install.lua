return {
  name = "vfp-pm install via bridge",
  fixtureRoot = "/tmp/opencode/vfp-pm-install",
  request = {
    action = "install",
    system = "vfp-pm",
    packages = {
      { name = "SFMail" },
    },
    flags = {
      "cache-root=/tmp/opencode/vfp-pm-install/cache",
      "catalog=/tmp/opencode/vfp-pm-install/cache/catalog/packages.tsv",
      "project=/tmp/opencode/vfp-pm-install/project",
      "bridge=vfp-bridge",
    },
  },
  fixtureDirs = {
    "cache/catalog",
    "cache/bridge",
    "project/Packages/SFMail",
  },
  fixtureFiles = {
    {
      path = "cache/catalog/packages.tsv",
      content = "Name\tVersion\tDescription\tProjectURL\tInstallURL\tTags\tDependent\nSFMail\t2.1.0\tSMTP helper for VFP\thttps://example.com/sfmail\tC:/FoxGet/Installers/SFMailInstaller.prg\tmail\t\n",
    },
    {
      path = "cache/bridge/install-sfmail.json",
      content = [[{"success":true,"name":"SFMail","version":"2.1.0"}]],
    },
    {
      path = "cache/bridge/install-sfmail.prg",
      content = "* generated\n",
    },
    {
      path = "project/Packages/packages.xml",
      content = "<VFPData><Packages><Name>SFMail</Name><Version>2.1.0</Version><Date>2026-05-03</Date><RefCount>1</RefCount></Packages></VFPData>",
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/vfp-pm-install/cache/catalog/packages.tsv'",
      exitCode = 0,
      stdout = "Name\tVersion\tDescription\tProjectURL\tInstallURL\tTags\tDependent\nSFMail\t2.1.0\tSMTP helper for VFP\thttps://example.com/sfmail\tC:/FoxGet/Installers/SFMailInstaller.prg\tmail\t\n",
      stderr = "",
      success = true,
    },
    {
      match = "test -d '/tmp/opencode/vfp-pm-install/cache/bridge' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "vfp-bridge --script '/tmp/opencode/vfp-pm-install/cache/bridge/install-sfmail.prg' --result '/tmp/opencode/vfp-pm-install/cache/bridge/install-sfmail.json'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/vfp-pm-install/cache/bridge/install-sfmail.json'",
      exitCode = 0,
      stdout = [[{"success":true,"name":"SFMail","version":"2.1.0"}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/vfp-pm-install/project/Packages/packages.xml'",
      exitCode = 0,
      stdout = "<VFPData><Packages><Name>SFMail</Name><Version>2.1.0</Version><Date>2026-05-03</Date><RefCount>1</RefCount></Packages></VFPData>",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/opencode/vfp-pm-install/cache/catalog/packages.tsv'",
      "test -d '/tmp/opencode/vfp-pm-install/cache/bridge' >/dev/null 2>&1",
      "vfp-bridge --script '/tmp/opencode/vfp-pm-install/cache/bridge/install-sfmail.prg' --result '/tmp/opencode/vfp-pm-install/cache/bridge/install-sfmail.json'",
      "cat '/tmp/opencode/vfp-pm-install/cache/bridge/install-sfmail.json'",
      "cat '/tmp/opencode/vfp-pm-install/project/Packages/packages.xml'",
    },
    events = { "installed", "success" },
  },
}
