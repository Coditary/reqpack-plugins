return {
  name = "nuget install package into shared cache",
  request = {
    action = "install",
    system = "nuget",
    flags = {
      "cache-root=${fixtureRoot}/cache"
    },
    packages = {
      { name = "Newtonsoft.Json", version = "13.0.3" }
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
      match = "LC_ALL=C LANG=C LANGUAGE=C NUGET_XMLDOC_MODE=skip 'nuget' 'install' 'Newtonsoft.Json' '-OutputDirectory' '${fixtureRoot}/cache/packages' '-Version' '13.0.3' '-NonInteractive' '-ForceEnglishOutput'",
      exitCode = 0,
      stdout = "Installed Newtonsoft.Json 13.0.3\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
