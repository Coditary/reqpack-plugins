return {
  name = "flix outdated tracked dependency",
  fixtureRoot = "/tmp/opencode/flix-outdated-case",
  request = {
    action = "outdated",
    system = "flix",
    flags = { "project-root=/tmp/opencode/flix-outdated-case" },
  },
  fixtureDirs = {
    ".reqpack-data/flix-cache",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/flix-cache/flix.toml",
      content = "[package]\nname        = \"reqpack-flix-cache\"\ndescription = \"ReqPack managed Flix dependency cache\"\nversion     = \"0.0.0\"\nflix        = \"0.0.0\"\nlicense     = \"MIT\"\nauthors     = [\"ReqPack <reqpack@example.invalid>\"]\n\n[dependencies]\n\"github:flix/museum\" = \"1.4.0\"\n",
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/flix-outdated-case/.reqpack-data/flix-cache/flix.toml'",
      exitCode = 0,
      stdout = "[package]\nname        = \"reqpack-flix-cache\"\ndescription = \"ReqPack managed Flix dependency cache\"\nversion     = \"0.0.0\"\nflix        = \"0.0.0\"\nlicense     = \"MIT\"\nauthors     = [\"ReqPack <reqpack@example.invalid>\"]\n\n[dependencies]\n\"github:flix/museum\" = \"1.4.0\"\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/flix-outdated-case/.reqpack-data/flix-cache/github/flix__museum.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/repos/flix/museum -o /tmp/opencode/flix-outdated-case/.reqpack-data/flix-cache/github/flix__museum.json",
      exitCode = 0,
      stdout = [[{"full_name":"flix/museum","name":"museum","description":"Museum package","html_url":"https://github.com/flix/museum","homepage":""}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/flix-outdated-case/.reqpack-data/flix-cache/github/flix__museum__releases.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/repos/flix/museum/releases -o /tmp/opencode/flix-outdated-case/.reqpack-data/flix-cache/github/flix__museum__releases.json",
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
      "cat '/tmp/opencode/flix-outdated-case/.reqpack-data/flix-cache/flix.toml'",
      "cat '/tmp/opencode/flix-outdated-case/.reqpack-data/flix-cache/github/flix__museum.json'",
      "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/repos/flix/museum -o /tmp/opencode/flix-outdated-case/.reqpack-data/flix-cache/github/flix__museum.json",
      "cat '/tmp/opencode/flix-outdated-case/.reqpack-data/flix-cache/github/flix__museum__releases.json'",
      "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/repos/flix/museum/releases -o /tmp/opencode/flix-outdated-case/.reqpack-data/flix-cache/github/flix__museum__releases.json"
    },
    events = { "outdated" },
    resultCount = 1,
    resultName = "museum",
    resultVersion = "1.4.0",
  }
}
