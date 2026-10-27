return {
  name = "dotnet search qsharp tools and templates",
  request = {
    action = "search",
    system = "dotnet",
    prompt = "qsharp",
    flags = {
      "cache-root=${fixtureRoot}/cache"
    },
  },
  fakeExec = {
    {
      match = "command -v 'dotnet' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/cache/workspace' '${fixtureRoot}/cache/workspace/dotnet-home' '${fixtureRoot}/cache/workspace/nuget-packages' '${fixtureRoot}/cache/workspace/tool-path' '${fixtureRoot}/cache/workspace/tool-local/.config' '${fixtureRoot}/cache/workspace/qsharp-host' '${fixtureRoot}/cache/workspace/template-cache'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NUGET_PACKAGES='${fixtureRoot}/cache/workspace/nuget-packages' 'dotnet' 'tool' 'search' 'qsharp' '--take' '20'",
      exitCode = 0,
      stdout = "Package ID                              Latest Version      Authors        Downloads      Verified\n-----------------------------------------------------------------------------------------------\nMicrosoft.Quantum.IQSharp               0.28.302812         Microsoft      12345          True\n",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NUGET_PACKAGES='${fixtureRoot}/cache/workspace/nuget-packages' 'dotnet' 'new' 'search' 'qsharp'",
      exitCode = 0,
      stdout = "Template Name                            Short Name      Language  Package\n-------------------------------------------------------------------------------\nQ# Application                           qsharpapp       [Q#]      Microsoft.Quantum.ProjectTemplates\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "Microsoft.Quantum.IQSharp",
    resultVersion = "0.28.302812",
  }
}
