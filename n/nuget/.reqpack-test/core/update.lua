return {
  name = "nuget update refreshes package through reinstall",
  request = {
    action = "update",
    system = "nuget",
    flags = {
      "cache-root=${fixtureRoot}/cache"
    },
    packages = {
      { name = "Newtonsoft.Json" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'nuget' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/cache/packages'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C NUGET_XMLDOC_MODE=skip 'nuget' 'install' 'Newtonsoft.Json' '-OutputDirectory' '${fixtureRoot}/cache/packages' '-NonInteractive' '-ForceEnglishOutput'",
      exitCode = 0,
      stdout = "Installed Newtonsoft.Json latest\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
