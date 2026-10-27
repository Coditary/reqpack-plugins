return {
  name = "nuget install local nupkg via staged feed",
  request = {
    action = "install",
    system = "nuget",
    flags = {
      "cache-root=${fixtureRoot}/cache"
    },
    localPath = "${fixtureRoot}/packages/Newtonsoft.Json.13.0.3.nupkg",
  },
  fixtureDirs = {
    "packages"
  },
  fixtureFiles = {
    {
      path = "packages/Newtonsoft.Json.13.0.3.nupkg",
      content = "fake nupkg\n",
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
      match = "mkdir -p '${fixtureRoot}/cache/local-feed/Newtonsoft.Json.13.0.3'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C NUGET_XMLDOC_MODE=skip 'nuget' 'add' '${fixtureRoot}/packages/Newtonsoft.Json.13.0.3.nupkg' '-Source' '${fixtureRoot}/cache/local-feed/Newtonsoft.Json.13.0.3' '-Expand' '-NonInteractive' '-ForceEnglishOutput'",
      exitCode = 0,
      stdout = "Added package\n",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C NUGET_XMLDOC_MODE=skip 'nuget' 'list' '-AllVersions' '-PreRelease' '-Source' '${fixtureRoot}/cache/local-feed/Newtonsoft.Json.13.0.3' '-NonInteractive' '-ForceEnglishOutput'",
      exitCode = 0,
      stdout = "Newtonsoft.Json 13.0.3\n",
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
      match = "LC_ALL=C LANG=C LANGUAGE=C NUGET_XMLDOC_MODE=skip 'nuget' 'install' 'Newtonsoft.Json' '-OutputDirectory' '${fixtureRoot}/cache/packages' '-Version' '13.0.3' '-Source' '${fixtureRoot}/cache/local-feed/Newtonsoft.Json.13.0.3' '-NonInteractive' '-ForceEnglishOutput'",
      exitCode = 0,
      stdout = "Installed local package\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
