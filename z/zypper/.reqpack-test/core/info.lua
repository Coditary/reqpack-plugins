return {
  name = "zypper info available package",
  request = {
    action = "info",
    system = "zypper",
    prompt = "curl",
  },
  fakeExec = {
    {
      match = "command -v 'zypper' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rpm -qi 'curl'",
      exitCode = 1,
      stdout = "",
      stderr = "package curl is not installed\n",
      success = false,
    },
    {
      match = "zypper --non-interactive info --type package 'curl'",
      exitCode = 0,
      stdout = "Information for package curl:\nRepository     : repo-oss\nName           : curl\nVersion        : 8.9.1-1.1\nArch           : x86_64\nVendor         : openSUSE\nInstalled      : No\nStatus         : not installed\nSource package : curl-8.9.1-1.1.src.rpm\nSummary        : Command line tool for transferring data\nDescription    :\n  curl is a command line tool for transferring data.\n  It supports many protocols.\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "curl",
    resultVersion = "8.9.1-1.1",
  }
}
