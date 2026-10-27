return {
  name = "dotnet install local template nupkg",
  request = {
    action = "install",
    system = "dotnet",
    localPath = "/tmp/Microsoft.Quantum.ProjectTemplates.0.28.302812.nupkg",
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
      match = "LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NUGET_PACKAGES='${fixtureRoot}/cache/workspace/nuget-packages' 'dotnet' 'new' 'install' '/tmp/Microsoft.Quantum.ProjectTemplates.0.28.302812.nupkg'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
  }
}
