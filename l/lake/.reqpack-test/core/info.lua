return {
  name = "lake info merges installed dependency with Reservoir metadata",
  fixtureRoot = "/tmp/opencode/lake-info",
  request = {
    action = "info",
    system = "lake",
    prompt = "mathlib",
    flags = {
      "data-root=/tmp/opencode/lake-info/data",
      "cache-root=/tmp/opencode/lake-info/cache"
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
  fixtureFiles = {
    {
      path = "data/lake/workspace/lakefile.toml",
      content = "name = \"reqpack-lake-workspace\"\nversion = \"0.1.0\"\npackagesDir = \".lake/packages\"\n\n[[lean_lib]]\nname = \"ReqpackLakeWorkspace\"\n\n[[require]]\nname = \"mathlib\"\nscope = \"leanprover-community\"\nversion = \"v4.30.0\"\n",
    },
    {
      path = "data/lake/workspace/lake-manifest.json",
      content = "{\"packages\":[{\"name\":\"mathlib\",\"scope\":\"leanprover-community\",\"type\":\"git\",\"url\":\"https://github.com/leanprover-community/mathlib4\",\"rev\":\"abcdef123456\"}]}",
    },
  },
  fakeExec = {
    {
      match = "mkdir -p '/tmp/opencode/lake-info/data/lake' '/tmp/opencode/lake-info/cache/lake' '/tmp/opencode/lake-info/data/lake/workspace' '/tmp/opencode/lake-info/data/lake/elan' '/tmp/opencode/lake-info/cache/lake/lake-home' '/tmp/opencode/lake-info/cache/lake/query'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/lake-info/data/lake/workspace/lakefile.toml'",
      exitCode = 0,
      stdout = "name = \"reqpack-lake-workspace\"\nversion = \"0.1.0\"\npackagesDir = \".lake/packages\"\n\n[[lean_lib]]\nname = \"ReqpackLakeWorkspace\"\n\n[[require]]\nname = \"mathlib\"\nscope = \"leanprover-community\"\nversion = \"v4.30.0\"\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/lake-info/data/lake/workspace/lake-manifest.json'",
      exitCode = 0,
      stdout = "{\"packages\":[{\"name\":\"mathlib\",\"scope\":\"leanprover-community\",\"type\":\"git\",\"url\":\"https://github.com/leanprover-community/mathlib4\",\"rev\":\"abcdef123456\"}]}",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://reservoir.lean-lang.org/packages?query=mathlib'",
      exitCode = 0,
      stdout = "<html><body><a href=\"/@leanprover-community/mathlib\">mathlib</a></body></html>",
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
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "mathlib",
    resultVersion = "abcdef123456",
  }
}
