return {
  name = "nuget search packages",
  request = {
    action = "search",
    system = "nuget",
    prompt = "json",
    flags = {
      "source=https://api.nuget.org/v3/index.json",
      "prerelease"
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
      match = "LC_ALL=C LANG=C LANGUAGE=C NUGET_XMLDOC_MODE=skip 'nuget' 'search' 'json' '-Take' '20' '-PreRelease' '-Source' 'https://api.nuget.org/v3/index.json' '-NonInteractive'",
      exitCode = 0,
      stdout = "Newtonsoft.Json 13.0.3 Json.NET is a popular high-performance JSON framework for .NET\nnewtonsoft.json.bson 1.0.2 Json.NET BSON adds support for reading and writing BSON\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "Newtonsoft.Json",
    resultVersion = "13.0.3",
  }
}
