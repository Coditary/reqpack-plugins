return {
  name = "red_cli install local config path",
  request = {
    action = "install",
    system = "red_cli",
    flags = {
      "data-root=${fixtureRoot}/cache"
    },
    localPath = "${fixtureRoot}/project/red.config.json",
  },
  fixtureDirs = {
    "${fixtureRoot}/cache",
    "${fixtureRoot}/project",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/project/red.config.json",
      content = [[{
  "name": "LocalMod",
  "version": "1.2.3",
  "game": "${fixtureRoot}/game",
  "scripts": {
    "cet": {
      "src": "mods",
      "output": "bin/x64/plugins/cyber_engine_tweaks/mods"
    }
  }
}]],
    },
  },
  fakeExec = {
    {
      match = "command -v 'red-cli' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/cache/tracked-projects.txt'",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C /bin/sh -lc 'cd \"${fixtureRoot}/project\" && red-cli install'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/project/red.config.json'",
      exitCode = 0,
      stdout = [[{
  "name": "LocalMod",
  "version": "1.2.3",
  "game": "${fixtureRoot}/game",
  "scripts": {
    "cet": {
      "src": "mods",
      "output": "bin/x64/plugins/cyber_engine_tweaks/mods"
    }
  }
}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = {},
  },
}
