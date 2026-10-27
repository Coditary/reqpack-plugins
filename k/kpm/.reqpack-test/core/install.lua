return {
  name = "kpm install updates manifest and runs kpm",
  request = {
    action = "install",
    system = "kpm",
    projectRoot = "./.reqpack-test/fixtures/install-case",
    flags = { "project-root=./.reqpack-test/fixtures/install-case" },
    packages = {
      { name = "org.jetbrains.kotlin:kotlin-stdlib", version = "2.2.0" }
    },
  },
  fixtureFiles = {
    {
      path = ".reqpack-test/fixtures/install-case/kpm.json",
      content = [[{"name":"demo-app","version":"1.0.0","main":"AppKt","dependencies":[]}]],
    },
  },
  fixtureDirs = {
    ".reqpack-test/fixtures/install-case",
  },
  fakeExec = {
    {
      match = "mkdir -p ./.reqpack-test/fixtures/install-case",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat './.reqpack-test/fixtures/install-case/kpm.json'",
      exitCode = 0,
      stdout = [[{"name":"demo-app","version":"1.0.0","main":"AppKt","dependencies":[]}]],
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
      "cat './.reqpack-test/fixtures/install-case/kpm.json'",
      "mkdir -p ./.reqpack-test/fixtures/install-case",
      "command -v java >/dev/null 2>&1",
      "test -x \"$HOME/.local/share/reqpack/kpm/bin/kpm\"",
      "\"$HOME/.local/share/reqpack/kpm/bin/kpm\" install",
    },
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  },
}
