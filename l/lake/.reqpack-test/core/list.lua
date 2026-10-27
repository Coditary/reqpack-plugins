return {
  name = "lake list direct dependencies from workspace",
  fixtureRoot = "/tmp/opencode/lake-list",
  request = {
    action = "list",
    system = "lake",
    flags = {
      "data-root=/tmp/opencode/lake-list/data",
      "cache-root=/tmp/opencode/lake-list/cache"
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "${fixtureRoot}"
  },
  fixtureDirs = {
    "data/lake/workspace"
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
      match = "cat '/tmp/opencode/lake-list/data/lake/workspace/lakefile.toml'",
      exitCode = 0,
      stdout = "name = \"reqpack-lake-workspace\"\nversion = \"0.1.0\"\npackagesDir = \".lake/packages\"\n\n[[lean_lib]]\nname = \"ReqpackLakeWorkspace\"\n\n[[require]]\nname = \"mathlib\"\nscope = \"leanprover-community\"\nversion = \"v4.30.0\"\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/lake-list/data/lake/workspace/lake-manifest.json'",
      exitCode = 0,
      stdout = "{\"packages\":[{\"name\":\"mathlib\",\"scope\":\"leanprover-community\",\"type\":\"git\",\"url\":\"https://github.com/leanprover-community/mathlib4\",\"rev\":\"abcdef123456\"}]}",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "mathlib",
    resultVersion = "abcdef123456",
  }
}
