return {
  name = "dpkg list",
  request = {
    action = "list",
    system = "dpkg",
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
      match = "dpkg-query -W -f='${Package}\\t${Version}\\t${Architecture}\\t${Status}\\n'",
      exitCode = 0,
      stdout = "alpha\t1.0.0\tamd64\tinstall ok installed\nbeta\t2.0.0\tall\tinstall ok installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "alpha",
    resultVersion = "1.0.0",
  }
}
