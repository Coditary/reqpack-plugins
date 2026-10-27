return {
  name = "dotnet outdated templates and qsharp packages",
  request = {
    action = "outdated",
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
      match = "LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NUGET_PACKAGES='${fixtureRoot}/cache/workspace/nuget-packages' 'dotnet' 'new' 'uninstall'",
      exitCode = 0,
      stdout = "Currently installed items:\n",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NUGET_PACKAGES='${fixtureRoot}/cache/workspace/nuget-packages' 'dotnet' 'new' 'update' '--check-only'",
      exitCode = 0,
      stdout = "Currently installed items:\n   Microsoft.Quantum.ProjectTemplates\n      Version: 0.28.302812\n      Details:\n         Author: Microsoft\n      Uninstall Command:\n         dotnet new uninstall Microsoft.Quantum.ProjectTemplates\n",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NUGET_PACKAGES='${fixtureRoot}/cache/workspace/nuget-packages' 'dotnet' 'package' 'list' '--project' '${fixtureRoot}/cache/workspace/qsharp-host/QSharpHost.csproj' '--format' 'json' '--output-version' '1' '--outdated'",
      exitCode = 0,
      stdout = '{"projects":[{"path":"QSharpHost.csproj","frameworks":[{"framework":"net8.0","topLevelPackages":[{"id":"Microsoft.Quantum.Sdk","requestedVersion":"0.28.263081","resolvedVersion":"0.28.263081","latestVersion":"0.28.302812"}]}]}]}',
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 2,
    resultName = "Microsoft.Quantum.ProjectTemplates",
  }
}
