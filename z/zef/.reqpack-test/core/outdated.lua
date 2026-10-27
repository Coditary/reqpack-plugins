return {
  name = "zef detect outdated packages",
  request = {
    action = "outdated",
    system = "zef",
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
      match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' RAKULIB='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_INSTALL_TO='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_CONFIG_STOREDIR='${fixtureRoot}/.reqpack-cache/store' ZEF_CONFIG_TEMPDIR='${fixtureRoot}/.reqpack-cache/temp' 'zef' '--installed' 'list'",
      exitCode = 0,
      stdout = "===> Found via ${fixtureRoot}/.reqpack-data/cur\nJSON::Fast:ver<0.18>\nText::CSV:ver<0.11>\n",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' RAKULIB='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_INSTALL_TO='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_CONFIG_STOREDIR='${fixtureRoot}/.reqpack-cache/store' ZEF_CONFIG_TEMPDIR='${fixtureRoot}/.reqpack-cache/temp' 'zef' 'info' 'JSON::Fast' '-v'",
      exitCode = 0,
      stdout = "- Info for: JSON::Fast\n- Identity: JSON::Fast:ver<0.19>\n- Recommended By: Zef::Repository::Ecosystems<fez>\n- Installed: No\nDescription: Fast JSON parser\nLicense: Artistic-2.0\nSource-url: https://example.invalid/JSON-Fast-0.19.tar.gz\n",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' RAKULIB='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_INSTALL_TO='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_CONFIG_STOREDIR='${fixtureRoot}/.reqpack-cache/store' ZEF_CONFIG_TEMPDIR='${fixtureRoot}/.reqpack-cache/temp' 'zef' 'info' 'Text::CSV' '-v'",
      exitCode = 0,
      stdout = "- Info for: Text::CSV\n- Identity: Text::CSV:ver<0.11>\n- Recommended By: Zef::Repository::Ecosystems<rea>\n- Installed: No\nDescription: CSV toolkit\nLicense: MIT\nSource-url: https://example.invalid/Text-CSV-0.11.tar.gz\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "JSON::Fast",
    resultVersion = "0.18",
  },
}
