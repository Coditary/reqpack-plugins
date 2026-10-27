return {
  name = "vfp-pm outdated compares catalog",
  fixtureRoot = "/tmp/opencode/vfp-pm-outdated",
  request = {
    action = "outdated",
    system = "vfp-pm",
    flags = {
      "catalog=/tmp/opencode/vfp-pm-outdated/cache/catalog/packages.tsv",
      "project=/tmp/opencode/vfp-pm-outdated/project",
    },
  },
  fixtureDirs = {
    "cache/catalog",
    "project/Packages/SFMail",
  },
  fixtureFiles = {
    {
      path = "cache/catalog/packages.tsv",
      content = "Name\tVersion\tDescription\tProjectURL\tInstallURL\tTags\tDependent\nSFMail\t2.1.0\tSMTP helper for VFP\thttps://example.com/sfmail\tC:/FoxGet/Installers/SFMailInstaller.prg\tmail\t\n",
    },
    {
      path = "project/Packages/packages.xml",
      content = "<VFPData><Packages><Name>SFMail</Name><Version>2.0.0</Version><Date>2026-05-01</Date><RefCount>1</RefCount></Packages></VFPData>",
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/vfp-pm-outdated/project/Packages/packages.xml'",
      exitCode = 0,
      stdout = "<VFPData><Packages><Name>SFMail</Name><Version>2.0.0</Version><Date>2026-05-01</Date><RefCount>1</RefCount></Packages></VFPData>",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/vfp-pm-outdated/cache/catalog/packages.tsv'",
      exitCode = 0,
      stdout = "Name\tVersion\tDescription\tProjectURL\tInstallURL\tTags\tDependent\nSFMail\t2.1.0\tSMTP helper for VFP\thttps://example.com/sfmail\tC:/FoxGet/Installers/SFMailInstaller.prg\tmail\t\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "SFMail",
    resultVersion = "2.0.0",
  },
}
