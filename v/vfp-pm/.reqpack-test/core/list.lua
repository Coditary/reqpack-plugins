return {
  name = "vfp-pm list project packages",
  fixtureRoot = "/tmp/opencode/vfp-pm-list",
  request = {
    action = "list",
    system = "vfp-pm",
    flags = {
      "catalog=/tmp/opencode/vfp-pm-list/cache/catalog/packages.tsv",
      "project=/tmp/opencode/vfp-pm-list/project",
    },
  },
  fixtureDirs = {
    "cache/catalog",
    "project/Packages/SFMail",
    "project/Packages/ErrorHandler",
  },
  fixtureFiles = {
    {
      path = "cache/catalog/packages.tsv",
      content = "Name\tVersion\tDescription\tProjectURL\tInstallURL\tTags\tDependent\nSFMail\t2.1.0\tSMTP helper for VFP\thttps://example.com/sfmail\tC:/FoxGet/Installers/SFMailInstaller.prg\tmail\t\nErrorHandler\t1.1.0\tError handling for VFP\thttps://example.com/errorhandler\tC:/FoxGet/Installers/ErrorHandlerInstaller.prg\terror\tSFMail\n",
    },
    {
      path = "project/Packages/packages.xml",
      content = "<VFPData><Packages><Name>SFMail</Name><Version>2.0.0</Version><Date>2026-05-01</Date><RefCount>1</RefCount></Packages><Packages><Name>ErrorHandler</Name><Version>1.0.0</Version><Date>2026-05-02</Date><RefCount>2</RefCount></Packages></VFPData>",
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/vfp-pm-list/project/Packages/packages.xml'",
      exitCode = 0,
      stdout = "<VFPData><Packages><Name>SFMail</Name><Version>2.0.0</Version><Date>2026-05-01</Date><RefCount>1</RefCount></Packages><Packages><Name>ErrorHandler</Name><Version>1.0.0</Version><Date>2026-05-02</Date><RefCount>2</RefCount></Packages></VFPData>",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/vfp-pm-list/cache/catalog/packages.tsv'",
      exitCode = 0,
      stdout = "Name\tVersion\tDescription\tProjectURL\tInstallURL\tTags\tDependent\nSFMail\t2.1.0\tSMTP helper for VFP\thttps://example.com/sfmail\tC:/FoxGet/Installers/SFMailInstaller.prg\tmail\t\nErrorHandler\t1.1.0\tError handling for VFP\thttps://example.com/errorhandler\tC:/FoxGet/Installers/ErrorHandlerInstaller.prg\terror\tSFMail\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "SFMail",
    resultVersion = "2.0.0",
  },
}
