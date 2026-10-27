return {
  name = "red_cli search tracked projects",
  request = {
    action = "search",
    system = "red_cli",
    prompt = "something",
    flags = {
      "data-root=${fixtureRoot}/cache"
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/cache",
    "${fixtureRoot}/project-a",
    "${fixtureRoot}/project-b",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/cache/tracked-projects.txt",
      content = "${fixtureRoot}/project-a\n${fixtureRoot}/project-b\n",
    },
    {
      path = "${fixtureRoot}/project-a/red.config.json",
      content = [[{
  "name": "Awesome",
  "version": "0.1.0",
  "scripts": {
    "redscript": {
      "src": "scripts"
    }
  }
}]],
    },
    {
      path = "${fixtureRoot}/project-b/red.config.json",
      content = [[{
  "name": "SomethingElse",
  "version": "0.4.0",
  "scripts": {
    "cet": {
      "src": "mods"
    }
  }
}]],
    },
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/cache/tracked-projects.txt'",
      exitCode = 0,
      stdout = "${fixtureRoot}/project-a\n${fixtureRoot}/project-b\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/project-a/red.config.json'",
      exitCode = 0,
      stdout = [[{
  "name": "Awesome",
  "version": "0.1.0",
  "scripts": {
    "redscript": {
      "src": "scripts"
    }
  }
}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/project-b/red.config.json'",
      exitCode = 0,
      stdout = [[{
  "name": "SomethingElse",
  "version": "0.4.0",
  "scripts": {
    "cet": {
      "src": "mods"
    }
  }
}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "SomethingElse",
  },
}
