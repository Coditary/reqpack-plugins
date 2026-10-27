return {
  name = "flix info github repository",
  fixtureRoot = "/tmp/opencode/flix-info-case",
  request = {
    action = "info",
    system = "flix",
    prompt = "flix/museum",
    flags = { "project-root=/tmp/opencode/flix-info-case" },
  },
  fixtureDirs = {
    ".reqpack-data/flix-cache",
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/flix-info-case/.reqpack-data/flix-cache/github/flix__museum.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/repos/flix/museum -o /tmp/opencode/flix-info-case/.reqpack-data/flix-cache/github/flix__museum.json",
      exitCode = 0,
      stdout = [[{"full_name":"flix/museum","name":"museum","description":"Museum package","html_url":"https://github.com/flix/museum","homepage":""}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/flix-info-case/.reqpack-data/flix-cache/github/flix__museum__releases.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/repos/flix/museum/releases -o /tmp/opencode/flix-info-case/.reqpack-data/flix-cache/github/flix__museum__releases.json",
      exitCode = 0,
      stdout = [=[[{"tag_name":"v1.5.0"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "command -v flix >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/opencode/flix-info-case/.reqpack-data/flix-cache/github/flix__museum.json'",
      "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/repos/flix/museum -o /tmp/opencode/flix-info-case/.reqpack-data/flix-cache/github/flix__museum.json",
      "cat '/tmp/opencode/flix-info-case/.reqpack-data/flix-cache/github/flix__museum__releases.json'",
      "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/repos/flix/museum/releases -o /tmp/opencode/flix-info-case/.reqpack-data/flix-cache/github/flix__museum__releases.json"
    },
    events = { "informed" },
    resultName = "museum",
    resultVersion = "1.5.0",
  }
}
