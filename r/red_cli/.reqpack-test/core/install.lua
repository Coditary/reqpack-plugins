return {
  name = "red_cli install tracked project",
  request = {
    action = "install",
    system = "red_cli",
    flags = {
      "data-root=${fixtureRoot}/cache",
      "bundle"
    },
    packages = {
      { name = "${fixtureRoot}/project" }
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/cache",
    "${fixtureRoot}/project",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/project/red.config.json",
      content = [[{
  "name": "Awesome",
  "version": "0.1.0",
  "game": "${fixtureRoot}/game",
  "stage": "stage",
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C /bin/sh -lc 'cd \"${fixtureRoot}/project\" && red-cli install --bundle'",
      exitCode = 0,
      stdout = "installed\n",
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
  "stage": "stage",
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
    commands = {
      "command -v 'red-cli' >/dev/null 2>&1",
      "cat '${fixtureRoot}/cache/tracked-projects.txt'",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C /bin/sh -lc 'cd \"${fixtureRoot}/project\" && red-cli install --bundle'",
      "cat '${fixtureRoot}/project/red.config.json'",
    },
    events = {},
  },
}
