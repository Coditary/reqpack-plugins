return {
  name = "kpm update rewrites manifest version",
  request = {
    action = "update",
    system = "kpm",
    projectRoot = "./.reqpack-test/fixtures/update-case",
    flags = { "project-root=./.reqpack-test/fixtures/update-case" },
    packages = {
      { name = "org.jetbrains.kotlin:kotlin-stdlib", version = "2.2.1" }
    },
  },
  fixtureFiles = {
    {
      path = ".reqpack-test/fixtures/update-case/kpm.json",
      content = [[{"name":"demo-app","version":"1.0.0","main":"AppKt","dependencies":["org.jetbrains.kotlin:kotlin-stdlib:2.2.0"]}]],
    },
  },
  fixtureDirs = {
    ".reqpack-test/fixtures/update-case",
  },
  fakeExec = {
    {
      match = "mkdir -p ./.reqpack-test/fixtures/update-case",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat './.reqpack-test/fixtures/update-case/kpm.json'",
      exitCode = 0,
      stdout = [[{"name":"demo-app","version":"1.0.0","main":"AppKt","dependencies":["org.jetbrains.kotlin:kotlin-stdlib:2.2.0"]}]],
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
      "cat './.reqpack-test/fixtures/update-case/kpm.json'",
      "mkdir -p ./.reqpack-test/fixtures/update-case",
      "command -v java >/dev/null 2>&1",
      "test -x \"$HOME/.local/share/reqpack/kpm/bin/kpm\"",
      "\"$HOME/.local/share/reqpack/kpm/bin/kpm\" install",
    },
    events = { "updated", "success" },
  },
}
