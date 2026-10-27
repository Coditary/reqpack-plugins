return {
  name = "zef install package",
  request = {
    action = "install",
    system = "zef",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
    },
    packages = {
      { name = "JSON::Fast", version = "0.19" },
    },
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
      match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' RAKULIB='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_INSTALL_TO='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_CONFIG_STOREDIR='${fixtureRoot}/.reqpack-cache/store' ZEF_CONFIG_TEMPDIR='${fixtureRoot}/.reqpack-cache/temp' 'zef' 'install' 'JSON::Fast:ver<0.19>'",
      exitCode = 0,
      stdout = "===> Installing: JSON::Fast:ver<0.19>\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'zef' >/dev/null 2>&1",
      "mkdir -p '${fixtureRoot}/.reqpack-data/cur' '${fixtureRoot}/.reqpack-cache/store' '${fixtureRoot}/.reqpack-cache/temp'",
      "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' RAKULIB='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_INSTALL_TO='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_CONFIG_STOREDIR='${fixtureRoot}/.reqpack-cache/store' ZEF_CONFIG_TEMPDIR='${fixtureRoot}/.reqpack-cache/temp' 'zef' 'install' 'JSON::Fast:ver<0.19>'",
    },
    events = { "installed", "success" },
  },
}
