return {
  name = "gradle update dependency",
  request = {
    action = "update",
    system = "gradle",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    packages = {
      { name = "org.junit.jupiter:junit-jupiter", version = "5.12.0" }
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
    {
      match = "gradle --console=plain --quiet --no-daemon --gradle-user-home ${fixtureRoot}/.reqpack-data/gradle-user-home --project-dir ${fixtureRoot}/.reqpack-data/gradle-project dependencies --configuration reqpack --refresh-dependencies",
      exitCode = 0,
      stdout = "updated resolution ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v gradle >/dev/null 2>&1",
      "gradle --console=plain --quiet --no-daemon --gradle-user-home ${fixtureRoot}/.reqpack-data/gradle-user-home --project-dir ${fixtureRoot}/.reqpack-data/gradle-project dependencies --configuration reqpack --refresh-dependencies"
    },
    events = { "updated", "success" },
    stdout = {
      "updated resolution ok\n"
    },
  }
}
