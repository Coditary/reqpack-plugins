return {
  name = "odpkg remove dependency alias",
  fixtureRoot = "/tmp/opencode/odpkg-remove",
  request = {
    action = "remove",
    system = "odpkg",
    flags = {
      "cwd=/tmp/opencode/odpkg-remove/project",
    },
    packages = {
      { name = "tempo" },
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/odpkg-remove",
  },
  fixtureFiles = {
    ["project/odpkg.toml"] = "[odpkg]\nname = \"demo\"\nversion = \"0.1.0\"\nvendor_dir = \"vendor\"\n\n[dependencies]\ntempo = { repo = \"kalsprite/tempo\", ref = \"main\" }\n",
  },
  fakeExec = {
    { match = "command -v 'odpkg' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '/tmp/opencode/odpkg-remove/project/odpkg.toml'", exitCode = 0, stdout = "[odpkg]\nname = \"demo\"\nversion = \"0.1.0\"\nvendor_dir = \"vendor\"\n\n[dependencies]\ntempo = { repo = \"kalsprite/tempo\", ref = \"main\" }\n", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C sh -lc \"cd '/tmp/opencode/odpkg-remove/project' && odpkg remove 'tempo'\"", exitCode = 0, stdout = "Removed tempo\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
