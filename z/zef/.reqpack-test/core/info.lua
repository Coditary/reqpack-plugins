return {
  name = "zef info package",
  request = {
    action = "info",
    system = "zef",
    prompt = "JSON::Fast",
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
      match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' RAKULIB='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_INSTALL_TO='inst#${fixtureRoot}/.reqpack-data/cur' ZEF_CONFIG_STOREDIR='${fixtureRoot}/.reqpack-cache/store' ZEF_CONFIG_TEMPDIR='${fixtureRoot}/.reqpack-cache/temp' 'zef' 'info' 'JSON::Fast' '-v'",
      exitCode = 0,
      stdout = "- Info for: JSON::Fast\n- Identity: JSON::Fast:ver<0.19>:auth<github:ugexe>\n- Recommended By: Zef::Repository::Ecosystems<fez>\n- Installed: No\nDescription: Fast JSON parser\nLicense: Artistic-2.0\nSource-url: https://example.invalid/JSON-Fast-0.19.tar.gz\nSupport:\n#   source: https://github.com/ugexe/JSON-Fast.git\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "JSON::Fast",
    resultVersion = "0.19",
  },
}
