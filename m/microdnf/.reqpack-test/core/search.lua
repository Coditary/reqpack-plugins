return {
  name = "microdnf search",
  request = {
    action = "search",
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
      match = "microdnf --setopt=cachedir='/home/test/.cache/reqpack/microdnf' repoquery --available --latest-limit 1 --queryformat '%{name}|%{version}-%{release}|%{arch}|%{reponame}|%{summary}\\n' '*curl*'",
      exitCode = 0,
      stdout = "curl|8.9.1-1.el9|x86_64|appstream|Command line tool for transferring data\ncurl-minimal|8.9.1-1.el9|x86_64|baseos|Minimal command line tool for transferring data\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "curl",
    resultVersion = "8.9.1-1.el9",
  }
}
