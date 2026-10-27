return {
  name = "nuget list reqpack-managed cache",
  request = {
    action = "list",
    system = "nuget",
    flags = {
      "cache-root=${fixtureRoot}/cache"
    },
  },
  fixtureDirs = {
    "cache/packages/Newtonsoft.Json.13.0.3"
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
      match = "LC_ALL=C LANG=C LANGUAGE=C NUGET_XMLDOC_MODE=skip 'nuget' 'list' '-AllVersions' '-PreRelease' '-Source' '${fixtureRoot}/cache/packages' '-NonInteractive' '-ForceEnglishOutput'",
      exitCode = 0,
      stdout = "Newtonsoft.Json 13.0.3\n",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C NUGET_XMLDOC_MODE=skip 'nuget' 'locals' 'all' '-List' '-NonInteractive' '-ForceEnglishOutput'",
      exitCode = 0,
      stdout = "global-packages: /home/test/.nuget/packages\nhttp-cache: /home/test/.local/share/NuGet/v3-cache\ntemp: /tmp/NuGetScratch\nplugins-cache: /home/test/.local/share/NuGet/plugins-cache\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "Newtonsoft.Json",
    resultVersion = "13.0.3",
  }
}
