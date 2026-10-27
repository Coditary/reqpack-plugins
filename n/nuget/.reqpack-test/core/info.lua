return {
  name = "nuget info prefers local cache and enriches remote",
  request = {
    action = "info",
    system = "nuget",
    prompt = "Newtonsoft.Json",
    flags = {
      "cache-root=${fixtureRoot}/cache",
      "source=https://api.nuget.org/v3/index.json",
      "prerelease"
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
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C NUGET_XMLDOC_MODE=skip 'nuget' 'list' 'Newtonsoft.Json' '-AllVersions' '-PreRelease' '-Source' 'https://api.nuget.org/v3/index.json' '-NonInteractive' '-ForceEnglishOutput'",
      exitCode = 0,
      stdout = "Newtonsoft.Json 12.0.3\nNewtonsoft.Json 13.0.3\n",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C NUGET_XMLDOC_MODE=skip 'nuget' 'search' 'Newtonsoft.Json' '-Take' '20' '-PreRelease' '-Source' 'https://api.nuget.org/v3/index.json' '-NonInteractive'",
      exitCode = 0,
      stdout = "Newtonsoft.Json 13.0.3 Json.NET is a popular high-performance JSON framework for .NET\n",
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
    events = { "informed" },
    resultCount = 1,
    resultName = "Newtonsoft.Json",
    resultVersion = "13.0.3",
  }
}
