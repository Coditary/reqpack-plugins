return {
  name = "odpkg list project dependencies",
  fixtureRoot = "/tmp/opencode/odpkg-list",
  request = {
    action = "list",
    system = "odpkg",
    flags = {
      "cwd=/tmp/opencode/odpkg-list/project",
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/odpkg-list",
  },
  fixtureFiles = {
    ["project/odpkg.toml"] = "[odpkg]\nname = \"demo\"\nversion = \"0.1.0\"\nvendor_dir = \"vendor\"\n\n[dependencies]\nraylib = { repo = \"raysan5/raylib\", ref = \"v5.0\" }\ntempo = { repo = \"kalsprite/tempo\", ref = \"main\" }\n",
    ["project/odpkg.lock"] = "[[deps]]\nname = \"raylib\"\nrepo = \"raysan5/raylib\"\nref = \"v5.0\"\ncommit = \"abc123\"\nhash = \"sha256:111\"\n\n[[deps]]\nname = \"tempo\"\nrepo = \"kalsprite/tempo\"\nref = \"main\"\ncommit = \"def456\"\nhash = \"sha256:222\"\n",
  },
  fixtureDirs = {
    "project/vendor/raylib",
  },
  fakeExec = {
    { match = "cat '/tmp/opencode/odpkg-list/project/odpkg.toml'", exitCode = 0, stdout = "[odpkg]\nname = \"demo\"\nversion = \"0.1.0\"\nvendor_dir = \"vendor\"\n\n[dependencies]\nraylib = { repo = \"raysan5/raylib\", ref = \"v5.0\" }\ntempo = { repo = \"kalsprite/tempo\", ref = \"main\" }\n", stderr = "", success = true },
    { match = "cat '/tmp/opencode/odpkg-list/project/odpkg.lock'", exitCode = 0, stdout = "[[deps]]\nname = \"raylib\"\nrepo = \"raysan5/raylib\"\nref = \"v5.0\"\ncommit = \"abc123\"\nhash = \"sha256:111\"\n\n[[deps]]\nname = \"tempo\"\nrepo = \"kalsprite/tempo\"\nref = \"main\"\ncommit = \"def456\"\nhash = \"sha256:222\"\n", stderr = "", success = true },
    { match = "test -d '/tmp/opencode/odpkg-list/project/vendor/raylib'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -d '/tmp/opencode/odpkg-list/project/vendor/tempo'", exitCode = 1, stdout = "", stderr = "", success = false },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "raylib",
    resultVersion = "abc123",
  },
}
