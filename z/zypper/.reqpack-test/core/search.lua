return {
  name = "zypper search packages",
  request = {
    action = "search",
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
      match = "zypper --xmlout --non-interactive search --details --type package 'curl'",
      exitCode = 0,
      stdout = "<?xml version='1.0'?>\n<stream>\n  <search-result version='0.0'>\n    <solvable-list>\n      <solvable status='not-installed' name='curl' kind='package' edition='8.9.1-1.1' arch='x86_64' repository='repo-oss' summary='Transfer tool'/>\n      <solvable status='not-installed' name='curl-debuginfo' kind='package' edition='8.9.1-1.1' arch='x86_64' repository='repo-debug' summary='Debug symbols'/>\n    </solvable-list>\n  </search-result>\n</stream>\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "curl",
    resultVersion = "8.9.1-1.1",
  }
}
