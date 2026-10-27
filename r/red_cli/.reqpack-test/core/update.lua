return {
  name = "red_cli update all tracked projects",
  request = {
    action = "update",
    system = "red_cli",
    flags = {
      "data-root=${fixtureRoot}/cache"
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
  "version": "0.2.0",
  "game": "${fixtureRoot}/game",
  "scripts": {
    "redscript": {
      "src": "scripts"
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
      exitCode = 0,
      stdout = "${fixtureRoot}/project\n",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C /bin/sh -lc 'cd \"${fixtureRoot}/project\" && red-cli install'",
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/project/red.config.json'",
      exitCode = 0,
      stdout = [[{
  "name": "Awesome",
  "version": "0.2.0",
  "game": "${fixtureRoot}/game",
  "scripts": {
    "redscript": {
      "src": "scripts"
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
