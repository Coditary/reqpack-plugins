return {
  name = "snow search repository cache",
  fixtureRoot = "/tmp/opencode/snow-search-case",
  request = {
    action = "search",
    system = "snow",
    flags = {
      "data-root=/tmp/opencode/snow-search-case/.reqpack-data",
      "cache-root=/tmp/opencode/snow-search-case/.reqpack-cache",
      "config-root=/tmp/opencode/snow-search-case/.reqpack-config",
    },
    prompt = "srfi",
  },
  fixtureDirs = {
    ".reqpack-cache/snow/repo",
  },
  fixtureFiles = {},
  fakeExec = {
    { match = "command -v 'snow' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/snow-search-case/.reqpack-data/snow/home'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/snow-search-case/.reqpack-cache/snow/repo'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/snow-search-case/.reqpack-cache/snow/repo-root'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/snow-search-case/.reqpack-config/snow'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C HOME='/tmp/opencode/snow-search-case/.reqpack-data/snow/home' 'snow' '--local-user-repository=/tmp/opencode/snow-search-case/.reqpack-cache/snow/repo' '--local-root-repository=/tmp/opencode/snow-search-case/.reqpack-cache/snow/repo-root' 'update'", exitCode = 0, stdout = "updated repo\n", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C HOME='/tmp/opencode/snow-search-case/.reqpack-data/snow/home' 'snow' '--local-user-repository=/tmp/opencode/snow-search-case/.reqpack-cache/snow/repo' '--local-root-repository=/tmp/opencode/snow-search-case/.reqpack-cache/snow/repo-root' '--update-strategy=never' 'search' 'srfi'", exitCode = 0, stdout = "(srfi 1)\t0.1.0\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "(srfi 1)",
    resultVersion = "0.1.0",
  },
}
