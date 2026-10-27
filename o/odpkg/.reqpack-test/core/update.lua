return {
  name = "odpkg update whole project",
  fixtureRoot = "/tmp/opencode/odpkg-update",
  request = {
    action = "update",
    system = "odpkg",
    flags = {
      "cwd=/tmp/opencode/odpkg-update/project",
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/odpkg-update",
  },
  fixtureFiles = {
    ["project/odpkg.toml"] = "[odpkg]\nname = \"demo\"\nversion = \"0.1.0\"\nvendor_dir = \"vendor\"\n\n[dependencies]\ntempo = { repo = \"kalsprite/tempo\", ref = \"main\" }\n",
    ["project/odpkg.lock"] = "[[deps]]\nname = \"tempo\"\nrepo = \"kalsprite/tempo\"\nref = \"main\"\ncommit = \"feed456\"\nhash = \"sha256:babe\"\n",
  },
  fixtureDirs = {
    "project/vendor/tempo",
  },
  fakeExec = {
    { match = "command -v 'odpkg' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '/tmp/opencode/odpkg-update/project/odpkg.toml'", exitCode = 0, stdout = "[odpkg]\nname = \"demo\"\nversion = \"0.1.0\"\nvendor_dir = \"vendor\"\n\n[dependencies]\ntempo = { repo = \"kalsprite/tempo\", ref = \"main\" }\n", stderr = "", success = true },
    { match = "cat '/tmp/opencode/odpkg-update/project/odpkg.lock'", exitCode = 0, stdout = "[[deps]]\nname = \"tempo\"\nrepo = \"kalsprite/tempo\"\nref = \"main\"\ncommit = \"feed456\"\nhash = \"sha256:babe\"\n", stderr = "", success = true },
    { match = "test -d '/tmp/opencode/odpkg-update/project/vendor/tempo'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C sh -lc \"cd '/tmp/opencode/odpkg-update/project' && odpkg update\"", exitCode = 0, stdout = "Updated tempo\n", stderr = "", success = true },
    { match = "cat '/tmp/opencode/odpkg-update/project/odpkg.toml'", exitCode = 0, stdout = "[odpkg]\nname = \"demo\"\nversion = \"0.1.0\"\nvendor_dir = \"vendor\"\n\n[dependencies]\ntempo = { repo = \"kalsprite/tempo\", ref = \"main\" }\n", stderr = "", success = true },
    { match = "cat '/tmp/opencode/odpkg-update/project/odpkg.lock'", exitCode = 0, stdout = "[[deps]]\nname = \"tempo\"\nrepo = \"kalsprite/tempo\"\nref = \"main\"\ncommit = \"feed456\"\nhash = \"sha256:babe\"\n", stderr = "", success = true },
    { match = "test -d '/tmp/opencode/odpkg-update/project/vendor/tempo'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  },
}
