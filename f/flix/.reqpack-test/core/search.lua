return {
  name = "flix search github repositories",
  fixtureRoot = "/tmp/opencode/flix-search-case",
  request = {
    action = "search",
    system = "flix",
    prompt = "museum",
    flags = { "project-root=/tmp/opencode/flix-search-case" },
  },
  fixtureDirs = {
    ".reqpack-data/flix-cache",
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/flix-search-case/.reqpack-data/flix-cache/github/search-museum_topic_flix.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/search/repositories?q=museum+topic:flix -o /tmp/opencode/flix-search-case/.reqpack-data/flix-cache/github/search-museum_topic_flix.json",
      exitCode = 0,
      stdout = [[{"items":[{"full_name":"flix/museum","name":"museum","description":"Museum package","html_url":"https://github.com/flix/museum","homepage":""}]}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/flix-search-case/.reqpack-data/flix-cache/github/flix__museum__releases.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/repos/flix/museum/releases -o /tmp/opencode/flix-search-case/.reqpack-data/flix-cache/github/flix__museum__releases.json",
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
      "cat '/tmp/opencode/flix-search-case/.reqpack-data/flix-cache/github/search-museum_topic_flix.json'",
      "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/search/repositories?q=museum+topic:flix -o /tmp/opencode/flix-search-case/.reqpack-data/flix-cache/github/search-museum_topic_flix.json",
      "cat '/tmp/opencode/flix-search-case/.reqpack-data/flix-cache/github/flix__museum__releases.json'",
      "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/repos/flix/museum/releases -o /tmp/opencode/flix-search-case/.reqpack-data/flix-cache/github/flix__museum__releases.json"
    },
    events = { "searched" },
    resultCount = 1,
    resultName = "museum",
    resultVersion = "1.5.0",
  }
}
