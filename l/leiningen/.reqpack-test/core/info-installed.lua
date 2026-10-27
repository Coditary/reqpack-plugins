return {
  name = "leiningen info installed artifact",
  request = {
    action = "info",
    system = "leiningen",
    prompt = "ring/ring-json",
    flags = { "repo-root=/tmp/opencode/leiningen-info/repository" },
  },
  fakeExec = {
    {
      match = "ls -1 '/tmp/opencode/leiningen-info/repository/ring/ring-json'",
      exitCode = 0,
      stdout = "0.5.1\n",
      stderr = "",
      success = true,
    },
    {
      match = "test -e '/tmp/opencode/leiningen-info/repository/ring/ring-json/0.5.1/ring-json-0.5.1.pom'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -e '/tmp/opencode/leiningen-info/repository/ring/ring-json/0.5.1/ring-json-0.5.1.jar'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "ring/ring-json",
    resultVersion = "0.5.1",
    events = { "informed" },
  },
}
