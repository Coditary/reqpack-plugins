return {
  name = "paket remove package from shared workspace",
  request = {
    action = "remove",
    system = "paket",
    flags = {
      "cache-root=${fixtureRoot}/cache"
    },
    packages = {
      { name = "Newtonsoft.Json" }
    },
  },
  fixtureDirs = {
    "cache/workspace",
    "cache/workspace/local-feed",
    "cache/workspace/local-cache",
    "cache/workspace/machine-cache",
    "cache/workspace/dotnet-home"
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
      match = "mkdir -p '${fixtureRoot}/cache/workspace' '${fixtureRoot}/cache/workspace/local-feed' '${fixtureRoot}/cache/workspace/local-cache' '${fixtureRoot}/cache/workspace/machine-cache' '${fixtureRoot}/cache/workspace/dotnet-home'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '${fixtureRoot}/cache/workspace' && LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NuGetCachePath='${fixtureRoot}/cache/workspace/machine-cache' 'dotnet' 'paket' '--help'",
      exitCode = 0,
      stdout = "paket help\n",
      stderr = "",
      success = true,
    },
    {
      match = "cd '${fixtureRoot}/cache/workspace' && LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NuGetCachePath='${fixtureRoot}/cache/workspace/machine-cache' 'dotnet' 'paket' 'remove' 'Newtonsoft.Json' '--no-install' '--silent'",
      exitCode = 0,
      stdout = "removed\n",
      stderr = "",
      success = true,
    },
    {
      match = "cd '${fixtureRoot}/cache/workspace' && LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NuGetCachePath='${fixtureRoot}/cache/workspace/machine-cache' 'dotnet' 'paket' 'install' '--silent'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
