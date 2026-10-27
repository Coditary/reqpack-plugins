return {
  name = "zef install local path",
  request = {
    action = "install",
    system = "zef",
    localPath = "${fixtureRoot}/Local-Demo",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
    },
  },
  fixtureDirs = {
    "Local-Demo",
  },
  fakeExec = {
    {
      match = "command -v 'zef' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/.reqpack-data/cur' '${fixtureRoot}/.reqpack-cache/store' '${fixtureRoot}/.reqpack-cache/temp'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' RAKULIB='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_INSTALL_TO='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_CONFIG_STOREDIR='${fixtureRoot}/.reqpack-cache/store' ZEF_CONFIG_TEMPDIR='${fixtureRoot}/.reqpack-cache/temp' 'zef' 'install' '${fixtureRoot}/Local-Demo'",
      exitCode = 0,
      stdout = "===> Installing: Local::Demo\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
