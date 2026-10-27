return {
  name = "vfp-pm info merges installed state",
  fixtureRoot = "/tmp/opencode/vfp-pm-info",
  request = {
    action = "info",
    system = "vfp-pm",
    prompt = "ErrorHandler",
    flags = {
      "catalog=/tmp/opencode/vfp-pm-info/cache/catalog/packages.tsv",
      "project=/tmp/opencode/vfp-pm-info/project",
    },
  },
  fixtureDirs = {
    "cache/catalog",
    "project/Packages/ErrorHandler",
  },
  fixtureFiles = {
    {
      path = "cache/catalog/packages.tsv",
      content = "Name\tVersion\tDescription\tProjectURL\tInstallURL\tTags\tDependent\nErrorHandler\t1.1.0\tError handling for VFP\thttps://example.com/errorhandler\tC:/FoxGet/Installers/ErrorHandlerInstaller.prg\terror, logging\tSFMail\n",
    },
    {
      path = "project/Packages/packages.xml",
      content = "<VFPData><Packages><Name>ErrorHandler</Name><Version>1.0.0</Version><Date>2026-05-02</Date><RefCount>2</RefCount></Packages></VFPData>",
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/vfp-pm-info/cache/catalog/packages.tsv'",
      exitCode = 0,
      stdout = "Name\tVersion\tDescription\tProjectURL\tInstallURL\tTags\tDependent\nErrorHandler\t1.1.0\tError handling for VFP\thttps://example.com/errorhandler\tC:/FoxGet/Installers/ErrorHandlerInstaller.prg\terror, logging\tSFMail\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/vfp-pm-info/project/Packages/packages.xml'",
      exitCode = 0,
      stdout = "<VFPData><Packages><Name>ErrorHandler</Name><Version>1.0.0</Version><Date>2026-05-02</Date><RefCount>2</RefCount></Packages></VFPData>",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "ErrorHandler",
    resultVersion = "1.0.0",
  },
}
