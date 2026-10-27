return {
  name = "dotnet install qsharp tool into global scope",
  request = {
    action = "install",
    system = "dotnet",
    flags = {
      "cache-root=${fixtureRoot}/cache"
    },
    packages = {
      { name = "tool:Microsoft.Quantum.IQSharp", version = "0.28.302812" }
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
      match = "LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NUGET_PACKAGES='${fixtureRoot}/cache/workspace/nuget-packages' 'dotnet' 'tool' 'install' 'Microsoft.Quantum.IQSharp' '--global' '--version' '0.28.302812'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
