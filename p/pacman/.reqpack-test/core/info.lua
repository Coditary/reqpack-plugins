return {
  name = "pacman info",
  request = {
    action = "info",
    system = "pacman",
    prompt = "curl",
  },
  fakeExec = {
    {
      match = "command -v pacman >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C pacman -Si curl",
      exitCode = 0,
      stdout = "Repository      : extra\nName            : curl\nVersion         : 8.8.0-1\nDescription     : command line tool and library for transferring data with URLs\nArchitecture    : x86_64\nURL             : https://curl.se\nLicenses        : curl\nDepends On      : brotli  zlib  openssl\nOptional Deps   : bash-completion: command completion\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "curl",
    resultVersion = "8.8.0-1",
  }
}
