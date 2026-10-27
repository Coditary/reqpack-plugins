return {
  name = "dpkg info",
  request = {
    action = "info",
    system = "dpkg",
    prompt = "delta",
  },
  fakeExec = {
    {
      match = "command -v 'dpkg' >/dev/null 2>&1 && command -v 'dpkg-query' >/dev/null 2>&1 && command -v 'apt-cache' >/dev/null 2>&1 && command -v 'apt-get' >/dev/null 2>&1 && command -v 'apt' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "dpkg-query -W -f='${Status}\\t${Version}\\t${Architecture}\\n' 'delta'",
      exitCode = 0,
      stdout = "install ok installed\t1.0.0\tamd64\n",
      stderr = "",
      success = true,
    },
    {
      match = "apt-cache policy 'delta'",
      exitCode = 0,
      stdout = "delta:\n  Installed: 1.0.0\n  Candidate: 1.1.0\n  Version table:\n",
      stderr = "",
      success = true,
    },
    {
      match = "apt-cache show 'delta'",
      exitCode = 0,
      stdout = "Package: delta\nVersion: 1.1.0\nArchitecture: amd64\nSection: utils\nHomepage: https://example.invalid/delta\nDepends: libc6 (>= 2.34)\nRecommends: delta-doc\nDescription: Delta package\n more details\n\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "delta",
    resultVersion = "1.0.0",
  }
}
