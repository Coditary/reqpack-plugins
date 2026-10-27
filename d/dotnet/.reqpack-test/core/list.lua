return {
  name = "dotnet list tools templates and qsharp packages",
  request = {
    action = "list",
    system = "dotnet",
    flags = {
      "cache-root=${fixtureRoot}/cache",
      "project=${fixtureRoot}/cache/workspace/qsharp-host/QSharpHost.csproj"
    },
  },
  fixtureDirs = {
    "cache/workspace",
    "cache/workspace/dotnet-home",
    "cache/workspace/nuget-packages",
    "cache/workspace/tool-path",
    "cache/workspace/tool-local/.config",
    "cache/workspace/qsharp-host",
    "cache/workspace/template-cache"
  },
  fixtureFiles = {
    {
      path = "cache/workspace/qsharp-host/QSharpHost.csproj",
      content = [[<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>]],
    }
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
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NUGET_PACKAGES='${fixtureRoot}/cache/workspace/nuget-packages' 'dotnet' 'new' 'uninstall'",
      exitCode = 0,
      stdout = "Currently installed items:\n   Microsoft.Quantum.ProjectTemplates\n      Version: 0.28.302812\n      Details:\n         Author: Microsoft\n         NuGetSource: https://api.nuget.org/v3/index.json\n      Templates:\n         Q# Application (qsharpapp)\n      Uninstall Command:\n         dotnet new uninstall Microsoft.Quantum.ProjectTemplates\n",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NUGET_PACKAGES='${fixtureRoot}/cache/workspace/nuget-packages' 'dotnet' 'package' 'list' '--project' '${fixtureRoot}/cache/workspace/qsharp-host/QSharpHost.csproj' '--format' 'json' '--output-version' '1'",
      exitCode = 0,
      stdout = '{"projects":[{"path":"QSharpHost.csproj","frameworks":[{"framework":"net8.0","topLevelPackages":[{"id":"Microsoft.Quantum.Sdk","requestedVersion":"0.28.302812","resolvedVersion":"0.28.302812"}]}]}]}',
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 3,
    resultName = "Microsoft.Quantum.IQSharp",
    resultVersion = "0.28.302812",
  }
}
