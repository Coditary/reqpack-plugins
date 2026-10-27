return {
  name = "vfp-pm search cached catalog",
  fixtureRoot = "/tmp/opencode/vfp-pm-search",
  request = {
    action = "search",
    system = "vfp-pm",
    prompt = "mail",
    flags = {
      "catalog=/tmp/opencode/vfp-pm-search/cache/catalog/packages.tsv",
      "project=/tmp/opencode/vfp-pm-search/project",
    },
  },
  fixtureDirs = {
    "cache/catalog",
    "project/Packages",
  },
  fixtureFiles = {
    {
      path = "cache/catalog/packages.tsv",
      content = "Name\tVersion\tDescription\tProjectURL\tInstallURL\tTags\tDependent\nSFMail\t2.1.0\tSMTP helper for VFP\thttps://example.com/sfmail\tC:/FoxGet/Installers/SFMailInstaller.prg\tmail, smtp\twwDotNetBridge\nErrorHandler\t1.0.0\tError handling for VFP\thttps://example.com/errorhandler\tC:/FoxGet/Installers/ErrorHandlerInstaller.prg\terror, logging\tSFMail\n",
    },
    {
      path = "project/Packages/packages.xml",
      content = "<VFPData><Packages><Name>SFMail</Name><Version>2.0.0</Version><Date>2026-05-01</Date><RefCount>1</RefCount></Packages></VFPData>",
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/vfp-pm-search/cache/catalog/packages.tsv'",
      exitCode = 0,
      stdout = "Name\tVersion\tDescription\tProjectURL\tInstallURL\tTags\tDependent\nSFMail\t2.1.0\tSMTP helper for VFP\thttps://example.com/sfmail\tC:/FoxGet/Installers/SFMailInstaller.prg\tmail, smtp\twwDotNetBridge\nErrorHandler\t1.0.0\tError handling for VFP\thttps://example.com/errorhandler\tC:/FoxGet/Installers/ErrorHandlerInstaller.prg\terror, logging\tSFMail\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/vfp-pm-search/project/Packages/packages.xml'",
      exitCode = 0,
      stdout = "<VFPData><Packages><Name>SFMail</Name><Version>2.0.0</Version><Date>2026-05-01</Date><RefCount>1</RefCount></Packages></VFPData>",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "SFMail",
    resultVersion = "2.0.0",
  },
}
