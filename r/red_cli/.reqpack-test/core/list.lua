return {
  name = "red_cli list tracked projects",
  request = {
    action = "list",
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
  "version": "0.1.0",
  "game": "${fixtureRoot}/game",
  "scripts": {
    "redscript": {
      "src": "scripts",
      "output": "r6/scripts"
    }
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
      "output": "r6/scripts"
    }
  }
}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "Awesome",
    resultVersion = "0.1.0",
  },
}
