return {
  name = "lake update refreshes workspace dependencies",
  fixtureRoot = "/tmp/opencode/lake-update",
  request = {
    action = "update",
    system = "lake",
    flags = {
      "data-root=/tmp/opencode/lake-update/data",
      "cache-root=/tmp/opencode/lake-update/cache"
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
  fakeExec = {
    {
      match = "command -v 'lake' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/lake-update/data/lake' '/tmp/opencode/lake-update/cache/lake' '/tmp/opencode/lake-update/data/lake/workspace' '/tmp/opencode/lake-update/data/lake/elan' '/tmp/opencode/lake-update/cache/lake/lake-home' '/tmp/opencode/lake-update/cache/lake/query'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/lake-update/data/lake/workspace'",
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
      match = "cd '/tmp/opencode/lake-update/data/lake/workspace' && NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C ELAN_HOME='/tmp/opencode/lake-update/data/lake/elan' LAKE_HOME='/tmp/opencode/lake-update/cache/lake/lake-home' lake 'update'",
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
