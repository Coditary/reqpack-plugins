return {
  name = "gradle install dependency",
  request = {
    action = "install",
    system = "gradle",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    packages = {
      { name = "org.junit.jupiter:junit-jupiter", version = "5.11.4" }
    },
  },
  fixtureDirs = {
    ".reqpack-data",
    ".reqpack-data/gradle-project",
    ".reqpack-data/gradle-user-home",
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
      match = "gradle --console=plain --quiet --no-daemon --gradle-user-home ${fixtureRoot}/.reqpack-data/gradle-user-home --project-dir ${fixtureRoot}/.reqpack-data/gradle-project dependencies --configuration reqpack",
      exitCode = 0,
      stdout = "reqpack resolution ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v gradle >/dev/null 2>&1",
      "gradle --console=plain --quiet --no-daemon --gradle-user-home ${fixtureRoot}/.reqpack-data/gradle-user-home --project-dir ${fixtureRoot}/.reqpack-data/gradle-project dependencies --configuration reqpack"
    },
    events = { "installed", "success" },
    stdout = {
      "reqpack resolution ok\n"
    },
  }
}
