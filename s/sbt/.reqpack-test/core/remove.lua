return {
  name = "sbt remove dependency",
  fixtureRoot = "/tmp/opencode/sbt-remove-case",
  request = {
    action = "remove",
    system = "sbt",
    flags = { "data-root=/tmp/opencode/sbt-remove-case/.reqpack-data" },
    packages = {
      { name = "org.typelevel:cats-core_2.13" }
    },
  },
  fixtureDirs = {
    ".reqpack-data",
    ".reqpack-data/sbt-project/project",
    ".reqpack-data/sbt-global",
    ".reqpack-data/sbt-boot",
    ".reqpack-data/ivy2",
    ".reqpack-data/coursier",
    ".reqpack-data/query/search",
    ".reqpack-data/query/info",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/deps.json",
      content = [[{
  "formatVersion": 1,
  "dependencies": [
    {
      "group": "org.typelevel",
      "artifact": "cats-core_2.13",
      "version": "2.12.0"
    }
  ]
}
]],
    },
  },
  fakeExec = {
    {
      match = "command -v sbt >/dev/null 2>&1",
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
