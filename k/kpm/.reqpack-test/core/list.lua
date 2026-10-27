return {
  name = "kpm list manifest and lock",
  request = {
    action = "list",
    system = "kpm",
    projectRoot = "./.reqpack-test/fixtures/list-case",
    flags = { "project-root=./.reqpack-test/fixtures/list-case" },
  },
  fixtureFiles = {
    {
      path = ".reqpack-test/fixtures/list-case/kpm.json",
      content = [[{"name":"demo-app","version":"1.0.0","main":"AppKt","dependencies":["org.jetbrains.kotlin:kotlin-stdlib:2.2.0"]}]],
    },
    {
      path = ".reqpack-test/fixtures/list-case/kpm-lock.json",
      content = [[{"version":"1.0","dependencies":{"org.jetbrains.kotlin:kotlin-stdlib:2.2.0":{"version":"2.2.0","hash":"abc","storePath":"/home/test/.kpm/store/abc/jar","transitiveDependencies":["org.example:dep:1.0.0"]}}}]],
    },
  },
  fixtureDirs = {
    ".reqpack-test/fixtures/list-case",
  },
  fakeExec = {
    {
      match = "cat './.reqpack-test/fixtures/list-case/kpm.json'",
      exitCode = 0,
      stdout = [[{"name":"demo-app","version":"1.0.0","main":"AppKt","dependencies":["org.jetbrains.kotlin:kotlin-stdlib:2.2.0"]}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat './.reqpack-test/fixtures/list-case/kpm-lock.json'",
      exitCode = 0,
      stdout = [[{"version":"1.0","dependencies":{"org.jetbrains.kotlin:kotlin-stdlib:2.2.0":{"version":"2.2.0","hash":"abc","storePath":"/home/test/.kpm/store/abc/jar","transitiveDependencies":["org.example:dep:1.0.0"]}}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat './.reqpack-test/fixtures/list-case/kpm.json'",
      "cat './.reqpack-test/fixtures/list-case/kpm-lock.json'",
    },
    events = { "listed" },
    resultCount = 1,
    resultName = "org.jetbrains.kotlin:kotlin-stdlib",
    resultVersion = "2.2.0",
  },
}
