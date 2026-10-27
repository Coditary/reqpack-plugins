return {
  name = "lake install writes workspace dependency and updates manifest",
  fixtureRoot = "/tmp/opencode/lake-install",
  request = {
    action = "install",
    system = "lake",
    flags = {
      "data-root=/tmp/opencode/lake-install/data",
      "cache-root=/tmp/opencode/lake-install/cache"
    },
    packages = {
      { name = "@leanprover-community/mathlib", version = "v4.30.0" }
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
      match = "command -v 'lake' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/lake-install/data/lake' '/tmp/opencode/lake-install/cache/lake' '/tmp/opencode/lake-install/data/lake/workspace' '/tmp/opencode/lake-install/data/lake/elan' '/tmp/opencode/lake-install/cache/lake/lake-home' '/tmp/opencode/lake-install/cache/lake/query'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/lake-install/data/lake/workspace'",
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
      match = "cd '/tmp/opencode/lake-install/data/lake/workspace' && NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C ELAN_HOME='/tmp/opencode/lake-install/data/lake/elan' LAKE_HOME='/tmp/opencode/lake-install/cache/lake/lake-home' lake 'update'",
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
