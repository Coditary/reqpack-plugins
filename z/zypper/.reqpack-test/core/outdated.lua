return {
  name = "zypper outdated packages",
  request = {
    action = "outdated",
    system = "zypper",
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
      match = "zypper --xmlout --non-interactive list-updates --type package",
      exitCode = 0,
      stdout = "<?xml version='1.0'?>\n<stream>\n  <update-status version='0.0'>\n    <update-list>\n      <update kind='package' name='curl' edition='8.9.1-1.1' oldedition='8.8.0-1.1' arch='x86_64' source='repo-update' source_alias='repo-update'/>\n    </update-list>\n  </update-status>\n</stream>\n",
      stderr = "",
      success = true,
    },
    {
      match = "rpm -q --queryformat '%{VERSION}-%{RELEASE}\\n' 'curl.x86_64'",
      exitCode = 0,
      stdout = "8.8.0-1.1\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "curl",
    resultVersion = "8.8.0-1.1",
  }
}
