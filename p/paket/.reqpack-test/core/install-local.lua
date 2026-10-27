return {
  name = "paket install local nupkg into shared workspace",
  request = {
    action = "install",
    system = "paket",
    flags = {
      "cache-root=${fixtureRoot}/cache"
    },
    localPath = "${fixtureRoot}/pkg/Newtonsoft.Json.13.0.3.nupkg"
  },
  fixtureDirs = {
    "pkg",
    "cache/workspace",
    "cache/workspace/local-feed",
    "cache/workspace/local-cache",
    "cache/workspace/machine-cache",
    "cache/workspace/dotnet-home"
  },
  fixtureFiles = {
    {
      path = "pkg/Newtonsoft.Json.13.0.3.nupkg",
      content = "fake nupkg"
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
      match = "cd '${fixtureRoot}/cache/workspace' && LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NuGetCachePath='${fixtureRoot}/cache/workspace/machine-cache' 'dotnet' 'paket' '--help'",
      exitCode = 0,
      stdout = "paket help\n",
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
      match = "cd '${fixtureRoot}/cache/workspace' && LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NuGetCachePath='${fixtureRoot}/cache/workspace/machine-cache' 'dotnet' 'paket' 'add' 'Newtonsoft.Json' '--version' '13.0.3' '--no-install' '--silent'",
      exitCode = 0,
      stdout = "added\n",
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
    events = { "installed", "success" },
  }
}
