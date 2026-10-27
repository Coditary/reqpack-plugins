return {
  name = "nuget remove reqpack-managed cache folder",
  request = {
    action = "remove",
    system = "nuget",
    flags = {
      "cache-root=${fixtureRoot}/cache"
    },
    packages = {
      { name = "Newtonsoft.Json", version = "13.0.3" }
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
      match = "LC_ALL=C LANG=C LANGUAGE=C NUGET_XMLDOC_MODE=skip 'nuget' 'list' 'Newtonsoft.Json' '-AllVersions' '-PreRelease' '-Source' '${fixtureRoot}/cache/packages' '-NonInteractive' '-ForceEnglishOutput'",
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
    events = { "deleted", "success" },
  }
}
