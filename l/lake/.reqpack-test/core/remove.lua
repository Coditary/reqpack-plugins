return {
  name = "lake remove deletes dependency and updates workspace",
  fixtureRoot = "/tmp/opencode/lake-remove",
  request = {
    action = "remove",
    system = "lake",
    flags = {
      "data-root=/tmp/opencode/lake-remove/data",
      "cache-root=/tmp/opencode/lake-remove/cache"
    },
    packages = {
      { name = "mathlib" }
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
  },
  fakeExec = {
    {
      match = "command -v 'lake' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/lake-remove/data/lake' '/tmp/opencode/lake-remove/cache/lake' '/tmp/opencode/lake-remove/data/lake/workspace' '/tmp/opencode/lake-remove/data/lake/elan' '/tmp/opencode/lake-remove/cache/lake/lake-home' '/tmp/opencode/lake-remove/cache/lake/query'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/lake-remove/data/lake/workspace/lakefile.toml'",
      exitCode = 0,
      stdout = "name = \"reqpack-lake-workspace\"\nversion = \"0.1.0\"\npackagesDir = \".lake/packages\"\n\n[[lean_lib]]\nname = \"ReqpackLakeWorkspace\"\n\n[[require]]\nname = \"mathlib\"\nscope = \"leanprover-community\"\nversion = \"v4.30.0\"\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/lake-remove/data/lake/workspace'",
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
      match = "cd '/tmp/opencode/lake-remove/data/lake/workspace' && NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C ELAN_HOME='/tmp/opencode/lake-remove/data/lake/elan' LAKE_HOME='/tmp/opencode/lake-remove/cache/lake/lake-home' lake 'update'",
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
