return {
  name = "dpkg info unavailable",
  request = {
    action = "info",
    system = "dpkg",
    prompt = "missing-pkg",
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
      match = "dpkg-query -W -f='${Status}\\t${Version}\\t${Architecture}\\n' 'missing-pkg'",
      exitCode = 1,
      stdout = "",
      stderr = "not installed\n",
      success = false,
    },
    {
      match = "apt-cache policy 'missing-pkg'",
      exitCode = 1,
      stdout = "",
      stderr = "not found\n",
      success = false,
    },
    {
      match = "apt-cache show 'missing-pkg'",
      exitCode = 1,
      stdout = "",
      stderr = "not found\n",
      success = false,
    },
  },
  expect = {
    success = false,
    events = { "unavailable" },
    eventPayloads = {
      unavailable = "{action=info, name=missing-pkg}",
    },
  }
}
