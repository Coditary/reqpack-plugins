return {
  name = "microdnf outdated",
  request = {
    action = "outdated",
    system = "microdnf",
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
      match = "mkdir -p '/home/test/.cache/reqpack/microdnf'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "microdnf --setopt=cachedir='/home/test/.cache/reqpack/microdnf' makecache",
      exitCode = 0,
      stdout = "Metadata cache created.\n",
      stderr = "",
      success = true,
    },
    {
      match = "microdnf --setopt=cachedir='/home/test/.cache/reqpack/microdnf' repoquery --upgrades --queryformat '%{name}|%{version}-%{release}|%{arch}|%{reponame}|%{summary}\\n'",
      exitCode = 0,
      stdout = "curl|8.9.1-1.el9|x86_64|appstream|Command line tool for transferring data\n",
      stderr = "",
      success = true,
    },
    {
      match = "rpm -q --queryformat '%{VERSION}-%{RELEASE}\\n' 'curl'",
      exitCode = 0,
      stdout = "8.8.0-1.el9\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "curl",
    resultVersion = "8.8.0-1.el9",
  }
}
