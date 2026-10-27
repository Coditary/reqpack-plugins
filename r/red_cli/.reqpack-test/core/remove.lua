return {
  name = "red_cli remove tracked project targets",
  request = {
    action = "remove",
    system = "red_cli",
    flags = {
      "data-root=${fixtureRoot}/cache"
    },
    packages = {
      { name = "Awesome" }
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/cache",
    "${fixtureRoot}/project",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/cache/tracked-projects.txt",
      content = "${fixtureRoot}/project\n",
    },
    {
      path = "${fixtureRoot}/project/red.config.json",
      content = [[{
  "name": "Awesome",
  "version": "0.1.0",
  "game": "${fixtureRoot}/game",
  "scripts": {
    "redscript": {
      "src": "scripts",
      "output": "r6/scripts",
      "storage": "storage"
    },
    "cet": {
      "src": "cet",
      "output": "bin/x64/plugins/cyber_engine_tweaks/mods"
    }
  },
  "plugin": {
    "debug": "build/Debug",
    "release": "build/Release"
  }
}]],
    },
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/cache/tracked-projects.txt'",
      exitCode = 0,
      stdout = "${fixtureRoot}/project\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/project/red.config.json'",
      exitCode = 0,
      stdout = [[{
  "name": "Awesome",
  "version": "0.1.0",
  "game": "${fixtureRoot}/game",
  "scripts": {
    "redscript": {
      "src": "scripts",
      "output": "r6/scripts",
      "storage": "storage"
    },
    "cet": {
      "src": "cet",
      "output": "bin/x64/plugins/cyber_engine_tweaks/mods"
    }
  },
  "plugin": {
    "debug": "build/Debug",
    "release": "build/Release"
  }
}]],
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '${fixtureRoot}/game/r6/scripts/Awesome'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '${fixtureRoot}/game/r6/storages/Awesome'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '${fixtureRoot}/game/bin/x64/plugins/cyber_engine_tweaks/mods/Awesome'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '${fixtureRoot}/game/red4ext/plugins/Awesome'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = {},
  },
}
