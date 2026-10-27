return {
  name = "microdnf info",
  request = {
    action = "info",
    system = "microdnf",
    prompt = "curl",
  },
  fakeExec = {
    {
      match = "command -v 'microdnf' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rpm -qi 'curl'",
      exitCode = 0,
      stdout = "Name        : curl\nVersion     : 8.9.1\nRelease     : 1.el9\nArchitecture: x86_64\nInstall Date: Fri 10 May 2026 10:00:00 UTC\nGroup       : Unspecified\nSize        : 123456\nLicense     : curl\nSignature   : RSA/SHA256\nSource RPM  : curl-8.9.1-1.el9.src.rpm\nBuild Date  : Thu 09 May 2026 10:00:00 UTC\nBuild Host  : builder\nPackager    : Example\nVendor      : Example\nURL         : https://curl.se/\nSummary     : Command line tool for transferring data\nDescription :\n curl is a command line tool for transferring data with URLs.\n It supports many protocols.\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "curl",
    resultVersion = "8.9.1-1.el9",
  }
}
