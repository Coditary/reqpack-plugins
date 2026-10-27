return {
  name = "zef search packages",
  request = {
    action = "search",
    system = "zef",
    prompt = "JSON",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
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
      match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' RAKULIB='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_INSTALL_TO='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_CONFIG_STOREDIR='${fixtureRoot}/.reqpack-cache/store' ZEF_CONFIG_TEMPDIR='${fixtureRoot}/.reqpack-cache/temp' 'zef' 'search' 'JSON'",
      exitCode = 0,
      stdout = "===> Found 2 results\n-------------------------------------------------------------------------\nID|From                              |Package                    |Description\n-------------------------------------------------------------------------\n1 |Zef::Repository::Ecosystems<fez>  |JSON::Fast:ver<0.19>       |Fast JSON parser\n2 |Zef::Repository::Ecosystems<rea>  |JSON::Class:ver<0.0.19>    |JSON mapping helpers\n-------------------------------------------------------------------------\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "JSON::Class",
    resultVersion = "0.0.19",
  },
}
