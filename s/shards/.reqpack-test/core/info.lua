return {
  name = "shards info",
  request = {
    action = "info",
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
      match = "curl -fsSL 'https://shards.info/github/kemalcr/kemal'",
      exitCode = 0,
      stdout = [[<h1 class="mb-0">kemal <i class="page__subheading">v1.11.0</i></h1><div class="shard__intro"><span>Fast, Effective, Simple Web Framework</span></div><a href="https://github.com/kemalcr/kemal">Source code</a><div class="list__heading">License</div><p>MIT License</p><a href="/github/kemalcr/">kemalcr</a><div class="list__heading">Repository</div><p class="fw-bold">kemal</p>]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "kemal",
    resultVersion = "1.11.0",
    events = { "informed" },
  },
}
