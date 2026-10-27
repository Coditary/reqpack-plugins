return {
  name = "red_cli info tracked project",
  request = {
    action = "info",
    system = "red_cli",
    prompt = "Awesome",
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
  "version": "9.9.9",
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
  "version": "9.9.9",
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
    events = { "informed" },
    resultName = "Awesome",
    resultVersion = "9.9.9",
  },
}
