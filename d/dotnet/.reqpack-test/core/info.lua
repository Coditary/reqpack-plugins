return {
  name = "dotnet info for installed qsharp tool",
  request = {
    action = "info",
    system = "dotnet",
    prompt = "tool:Microsoft.Quantum.IQSharp",
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
      match = "LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NUGET_PACKAGES='${fixtureRoot}/cache/workspace/nuget-packages' 'dotnet' 'tool' 'list' '--global'",
      exitCode = 0,
      stdout = "Package Id      Version      Commands\n------------------------------------\nMicrosoft.Quantum.IQSharp 0.28.302812 iqsharp\n",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NUGET_PACKAGES='${fixtureRoot}/cache/workspace/nuget-packages' 'dotnet' 'tool' 'list' '--tool-path' '${fixtureRoot}/cache/workspace/tool-path'",
      exitCode = 0,
      stdout = "Package Id      Version      Commands\n------------------------------------\n",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NUGET_PACKAGES='${fixtureRoot}/cache/workspace/nuget-packages' 'dotnet' 'tool' 'list' '--local' '--tool-manifest' '${fixtureRoot}/cache/workspace/tool-local/.config/dotnet-tools.json'",
      exitCode = 0,
      stdout = "Package Id      Version      Commands      Manifest\n--------------------------------------------------------------------------\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "Microsoft.Quantum.IQSharp",
    resultVersion = "0.28.302812",
  }
}
