return {
  name = "kpm outdated against maven central",
  fixtureRoot = "/tmp/opencode/kpm-outdated-case",
  request = {
    action = "outdated",
    system = "kpm",
    projectRoot = "./.reqpack-test/fixtures/outdated-case",
    flags = { "project-root=./.reqpack-test/fixtures/outdated-case" },
  },
  fixtureFiles = {
    {
      path = ".reqpack-test/fixtures/outdated-case/kpm.json",
      content = [[{"name":"demo-app","version":"1.0.0","main":"AppKt","dependencies":["org.jetbrains.kotlin:kotlin-stdlib:2.2.0"]}]],
    },
    {
      path = ".reqpack-test/fixtures/outdated-case/kpm-lock.json",
      content = [[{"version":"1.0","dependencies":{"org.jetbrains.kotlin:kotlin-stdlib:2.2.0":{"version":"2.2.0","hash":"abc","storePath":"/home/test/.kpm/store/abc/jar","transitiveDependencies":[]}}}]],
    },
  },
  fixtureDirs = {
    ".reqpack-test/fixtures/outdated-case",
  },
  fakeExec = {
    {
      match = "cat './.reqpack-test/fixtures/outdated-case/kpm.json'",
      exitCode = 0,
      stdout = [[{"name":"demo-app","version":"1.0.0","main":"AppKt","dependencies":["org.jetbrains.kotlin:kotlin-stdlib:2.2.0"]}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat './.reqpack-test/fixtures/outdated-case/kpm-lock.json'",
      exitCode = 0,
      stdout = [[{"version":"1.0","dependencies":{"org.jetbrains.kotlin:kotlin-stdlib:2.2.0":{"version":"2.2.0","hash":"abc","storePath":"/home/test/.kpm/store/abc/jar","transitiveDependencies":[]}}}]],
      stderr = "",
      success = true,
    },
    {
      match = "test -f .reqpack-data/kpm/info/org.jetbrains.kotlin__kotlin-stdlib.json && stat -c %Y .reqpack-data/kpm/info/org.jetbrains.kotlin__kotlin-stdlib.json",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "mkdir -p .reqpack-data/kpm/info",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL -H 'Accept: application/json' 'https://search.maven.org/solrsearch/select?rows=1&wt=json&q=g:%22org.jetbrains.kotlin%22%20AND%20a:%22kotlin-stdlib%22' -o '.reqpack-data/kpm/info/org.jetbrains.kotlin__kotlin-stdlib.json'",
      exitCode = 0,
      stdout = [[{"response":{"docs":[{"g":"org.jetbrains.kotlin","a":"kotlin-stdlib","latestVersion":"2.2.1"}]}}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat .reqpack-data/kpm/info/org.jetbrains.kotlin__kotlin-stdlib.json",
      exitCode = 0,
      stdout = [[{"response":{"docs":[{"g":"org.jetbrains.kotlin","a":"kotlin-stdlib","latestVersion":"2.2.1"}]}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat './.reqpack-test/fixtures/outdated-case/kpm.json'",
      "cat './.reqpack-test/fixtures/outdated-case/kpm-lock.json'",
      "test -f .reqpack-data/kpm/info/org.jetbrains.kotlin__kotlin-stdlib.json && stat -c %Y .reqpack-data/kpm/info/org.jetbrains.kotlin__kotlin-stdlib.json",
      "mkdir -p .reqpack-data/kpm/info",
      "curl -fsSL -H 'Accept: application/json' 'https://search.maven.org/solrsearch/select?rows=1&wt=json&q=g:%22org.jetbrains.kotlin%22%20AND%20a:%22kotlin-stdlib%22' -o '.reqpack-data/kpm/info/org.jetbrains.kotlin__kotlin-stdlib.json'",
      "cat .reqpack-data/kpm/info/org.jetbrains.kotlin__kotlin-stdlib.json",
    },
    events = { "outdated" },
    resultCount = 1,
    resultName = "org.jetbrains.kotlin:kotlin-stdlib",
    resultVersion = "2.2.0",
  },
}
