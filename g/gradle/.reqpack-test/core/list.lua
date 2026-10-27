return {
  name = "gradle list tracked dependencies",
  request = {
    action = "list",
    system = "gradle",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
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
      match = "gradle --console=plain --quiet --no-daemon --gradle-user-home ${fixtureRoot}/.reqpack-data/gradle-user-home --project-dir ${fixtureRoot}/.reqpack-data/gradle-project dependencyInsight --dependency org.junit.jupiter:junit-jupiter --configuration reqpack",
      exitCode = 0,
      stdout = "org.junit.jupiter:junit-jupiter:5.11.4\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "org.junit.jupiter:junit-jupiter",
    resultVersion = "5.11.4",
  }
}
