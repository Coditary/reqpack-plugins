return {
  name = "lake search Reservoir packages",
  fixtureRoot = "/tmp/opencode/lake-search",
  request = {
    action = "search",
    system = "lake",
    prompt = "math",
    flags = {
      "data-root=/tmp/opencode/lake-search/data",
      "cache-root=/tmp/opencode/lake-search/cache"
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "${fixtureRoot}"
  },
  fixtureDirs = {
    "data/lake/workspace",
    "data/lake/elan",
    "cache/lake",
    "cache/lake/query",
    "cache/lake/lake-home"
  },
  fakeExec = {
    {
      match = "mkdir -p '/tmp/opencode/lake-search/data/lake' '/tmp/opencode/lake-search/cache/lake' '/tmp/opencode/lake-search/data/lake/workspace' '/tmp/opencode/lake-search/data/lake/elan' '/tmp/opencode/lake-search/cache/lake/lake-home' '/tmp/opencode/lake-search/cache/lake/query'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/lake-search/data/lake/workspace'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "printf %s 'name = \"reqpack-lake-workspace\"",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "printf %s '-- ReqPack-managed shared Lake workspace.",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://reservoir.lean-lang.org/packages?query=math'",
      exitCode = 0,
      stdout = "<html><body><a href=\"/@leanprover-community/mathlib\">mathlib</a><a href=\"/@leanprover/batteries\">batteries</a></body></html>",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://reservoir.lean-lang.org/@leanprover-community/mathlib'",
      exitCode = 0,
      stdout = "<html><head><meta name=\"description\" content=\"Lean mathematics library\"></head><body><title>mathlib | Reservoir</title><a href=\"https://github.com/leanprover-community/mathlib4\">repo</a>Last updated on May 30, 2026 at 12:00:00PM leanprover/lean4:v4.30.0</body></html>",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://reservoir.lean-lang.org/@leanprover/batteries'",
      exitCode = 0,
      stdout = "<html><head><meta name=\"description\" content=\"Utility Lean library\"></head><body><title>batteries | Reservoir</title><a href=\"https://github.com/leanprover/batteries\">repo</a>Last updated on May 30, 2026 at 12:00:00PM leanprover/lean4:v4.30.0</body></html>",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "mathlib",
    resultVersion = "v4.30.0",
  }
}
