return {
  name = "paket info merges installed and remote version data",
  request = {
    action = "info",
    system = "paket",
    flags = {
      "cache-root=${fixtureRoot}/cache"
    },
    prompt = "Newtonsoft.Json"
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
      match = "cd '${fixtureRoot}/cache/workspace' && LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NuGetCachePath='${fixtureRoot}/cache/workspace/machine-cache' 'dotnet' 'paket' 'show-installed-packages' '--all' '--silent'",
      exitCode = 0,
      stdout = "Main Newtonsoft.Json - 13.0.3\n",
      stderr = "",
      success = true,
    },
    {
      match = "cd '${fixtureRoot}/cache/workspace' && LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NuGetCachePath='${fixtureRoot}/cache/workspace/machine-cache' 'dotnet' 'paket' 'outdated' '--silent'",
      exitCode = 0,
      stdout = "Group: Main\n* Newtonsoft.Json 13.0.3 -> 13.0.4\n",
      stderr = "",
      success = true,
    },
    {
      match = "cd '${fixtureRoot}/cache/workspace' && LC_ALL=C LANG=C LANGUAGE=C DOTNET_CLI_UI_LANGUAGE=en DOTNET_CLI_HOME='${fixtureRoot}/cache/workspace/dotnet-home' NuGetCachePath='${fixtureRoot}/cache/workspace/machine-cache' 'dotnet' 'paket' 'find-package-versions' 'Newtonsoft.Json' '--max' '20' '--silent'",
      exitCode = 0,
      stdout = "13.0.4\n13.0.3\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "Newtonsoft.Json",
    resultVersion = "13.0.3",
  }
}
