return {
  name = "odpkg info local dependency",
  fixtureRoot = "/tmp/opencode/odpkg-info",
  request = {
    action = "info",
    system = "odpkg",
    prompt = "tempo",
    flags = {
      "cwd=/tmp/opencode/odpkg-info/project",
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/odpkg-info",
  },
  fixtureFiles = {
    ["project/odpkg.toml"] = "[odpkg]\nname = \"demo\"\nversion = \"0.1.0\"\nvendor_dir = \"vendor\"\n\n[dependencies]\ntempo = { repo = \"kalsprite/tempo\", ref = \"main\" }\n",
    ["project/odpkg.lock"] = "[[deps]]\nname = \"tempo\"\nrepo = \"kalsprite/tempo\"\nref = \"main\"\ncommit = \"def456\"\nhash = \"sha256:222\"\n",
  },
  fixtureDirs = {
    "project/vendor/tempo",
  },
  fakeExec = {
    { match = "cat '/tmp/opencode/odpkg-info/project/odpkg.toml'", exitCode = 0, stdout = "[odpkg]\nname = \"demo\"\nversion = \"0.1.0\"\nvendor_dir = \"vendor\"\n\n[dependencies]\ntempo = { repo = \"kalsprite/tempo\", ref = \"main\" }\n", stderr = "", success = true },
    { match = "cat '/tmp/opencode/odpkg-info/project/odpkg.lock'", exitCode = 0, stdout = "[[deps]]\nname = \"tempo\"\nrepo = \"kalsprite/tempo\"\nref = \"main\"\ncommit = \"def456\"\nhash = \"sha256:222\"\n", stderr = "", success = true },
    { match = "test -d '/tmp/opencode/odpkg-info/project/vendor/tempo'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "tempo",
    resultVersion = "def456",
  },
}
