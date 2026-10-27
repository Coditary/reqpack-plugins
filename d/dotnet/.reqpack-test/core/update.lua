return {
  name = "dotnet update qsharp package in shared host project",
  request = {
    action = "update",
    system = "dotnet",
    flags = {
      "cache-root=${fixtureRoot}/cache",
      "project=${fixtureRoot}/cache/workspace/qsharp-host/QSharpHost.csproj"
    },
    packages = {
      { name = "package:Microsoft.Quantum.Sdk", version = "0.28.302812" }
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
      match = "LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NUGET_PACKAGES='${fixtureRoot}/cache/workspace/nuget-packages' 'dotnet' 'package' 'add' 'Microsoft.Quantum.Sdk' '--project' '${fixtureRoot}/cache/workspace/qsharp-host/QSharpHost.csproj' '--version' '0.28.302812'",
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
