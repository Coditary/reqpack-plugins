return {
  name = "shards search",
  request = {
    action = "search",
    system = "shards",
    prompt = "kemal",
  },
  fakeExec = {
    {
      match = "curl -fsSL 'https://shards.info/search?query=kemal'",
      exitCode = 0,
      stdout = [[<div class="shards__shard d-flex"><h2 class="shards__shard_name css-truncate"><a href="/github/kemalcr/kemal/">kemalcr/<span class='text-normal'>kemal</span></a></h2><p class="shards__shard_desc dont-break-out">Fast, Effective, Simple Web Framework</p></div>]],
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/home/test/.cache/reqpack/shards/search' && printf %s '<div class=\"shards__shard d-flex\"><h2 class=\"shards__shard_name css-truncate\"><a href=\"/github/kemalcr/kemal/\">kemalcr/<span class='\\''text-normal'\\''>kemal</span></a></h2><p class=\"shards__shard_desc dont-break-out\">Fast, Effective, Simple Web Framework</p></div>' > '/home/test/.cache/reqpack/shards/search/kemal.html'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/home/test/.cache/reqpack/shards/search' && printf %s '0' > '/home/test/.cache/reqpack/shards/search/kemal.ts'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "curl -fsSL 'https://shards.info/search?query=kemal'",
      "mkdir -p '/home/test/.cache/reqpack/shards/search' && printf %s '<div class=\"shards__shard d-flex\"><h2 class=\"shards__shard_name css-truncate\"><a href=\"/github/kemalcr/kemal/\">kemalcr/<span class='\\''text-normal'\\''>kemal</span></a></h2><p class=\"shards__shard_desc dont-break-out\">Fast, Effective, Simple Web Framework</p></div>' > '/home/test/.cache/reqpack/shards/search/kemal.html'",
      "mkdir -p '/home/test/.cache/reqpack/shards/search' && printf %s '0' > '/home/test/.cache/reqpack/shards/search/kemal.ts'",
    },
    resultCount = 1,
    resultName = "kemal",
    events = { "searched" },
  },
}
