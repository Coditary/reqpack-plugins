return {
  name = "gradle remove dependency",
  request = {
    action = "remove",
    system = "gradle",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    packages = {
      { name = "org.junit.jupiter:junit-jupiter" }
    },
  },
  fixtureDirs = {
    ".reqpack-data",
    ".reqpack-data/gradle-project",
    ".reqpack-data/gradle-user-home",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/deps.json",
      content = [[{
  "formatVersion": 1,
  "dependencies": [
    {
      "group": "org.junit.jupiter",
      "artifact": "junit-jupiter",
      "version": "5.11.4"
    }
  ]
}
]],
    },
  },
  fakeExec = {
    {
      match = "command -v gradle >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
