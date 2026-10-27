return {
  name = "kpm remove rewrites manifest and lock",
  request = {
    action = "remove",
    system = "kpm",
    projectRoot = "./.reqpack-test/fixtures/remove-case",
    flags = { "project-root=./.reqpack-test/fixtures/remove-case" },
    packages = {
      { name = "org.jetbrains.kotlin:kotlin-stdlib", version = "2.2.0" }
    },
  },
  fixtureFiles = {
    {
      path = ".reqpack-test/fixtures/remove-case/kpm.json",
      content = [[{"name":"demo-app","version":"1.0.0","main":"AppKt","dependencies":["org.jetbrains.kotlin:kotlin-stdlib:2.2.0","com.google.code.gson:gson:2.10.1"]}]],
    },
    {
      path = ".reqpack-test/fixtures/remove-case/kpm-lock.json",
      content = [[{"version":"1.0","dependencies":{"org.jetbrains.kotlin:kotlin-stdlib:2.2.0":{"version":"2.2.0","hash":"abc","storePath":"/home/test/.kpm/store/abc/jar","transitiveDependencies":[]},"com.google.code.gson:gson:2.10.1":{"version":"2.10.1","hash":"def","storePath":"/home/test/.kpm/store/def/jar","transitiveDependencies":[]}}}]],
    },
  },
  fixtureDirs = {
    ".reqpack-test/fixtures/remove-case",
  },
  fakeExec = {
    {
      match = "mkdir -p ./.reqpack-test/fixtures/remove-case",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat './.reqpack-test/fixtures/remove-case/kpm.json'",
      exitCode = 0,
      stdout = [[{"name":"demo-app","version":"1.0.0","main":"AppKt","dependencies":["org.jetbrains.kotlin:kotlin-stdlib:2.2.0","com.google.code.gson:gson:2.10.1"]}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat './.reqpack-test/fixtures/remove-case/kpm-lock.json'",
      exitCode = 0,
      stdout = [[{"version":"1.0","dependencies":{"org.jetbrains.kotlin:kotlin-stdlib:2.2.0":{"version":"2.2.0","hash":"abc","storePath":"/home/test/.kpm/store/abc/jar","transitiveDependencies":[]},"com.google.code.gson:gson:2.10.1":{"version":"2.10.1","hash":"def","storePath":"/home/test/.kpm/store/def/jar","transitiveDependencies":[]}}}]],
      stderr = "",
      success = true,
    },
    {
      match = "command -v java >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -x \"$HOME/.local/share/reqpack/kpm/bin/kpm\"",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "\"$HOME/.local/share/reqpack/kpm/bin/kpm\" install",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat './.reqpack-test/fixtures/remove-case/kpm.json'",
      "mkdir -p ./.reqpack-test/fixtures/remove-case",
      "cat './.reqpack-test/fixtures/remove-case/kpm-lock.json'",
      "mkdir -p ./.reqpack-test/fixtures/remove-case",
      "command -v java >/dev/null 2>&1",
      "test -x \"$HOME/.local/share/reqpack/kpm/bin/kpm\"",
      "\"$HOME/.local/share/reqpack/kpm/bin/kpm\" install",
    },
    events = { "deleted", "success" },
  },
}
