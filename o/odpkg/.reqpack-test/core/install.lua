return {
  name = "odpkg install repo dependency",
  fixtureRoot = "/tmp/opencode/odpkg-install",
  request = {
    action = "install",
    system = "odpkg",
    flags = {
      "cwd=/tmp/opencode/odpkg-install/project",
    },
    packages = {
      {
        name = "demo/lib",
        version = "v1.2.3",
      },
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/odpkg-install",
  },
  fixtureFiles = {
    ["project/odpkg.toml"] = "[odpkg]\nname = \"demo\"\nversion = \"0.1.0\"\nvendor_dir = \"vendor\"\n\n[dependencies]\nlib = { repo = \"demo/lib\", ref = \"v1.2.3\" }\n",
    ["project/odpkg.lock"] = "[[deps]]\nname = \"lib\"\nrepo = \"demo/lib\"\nref = \"v1.2.3\"\ncommit = \"abc123\"\nhash = \"sha256:deadbeef\"\n",
  },
  fixtureDirs = {
    "project/vendor/lib",
  },
  fakeExec = {
    { match = "command -v 'odpkg' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '/tmp/opencode/odpkg-install/project/odpkg.toml'", exitCode = 0, stdout = "[odpkg]\nname = \"demo\"\nversion = \"0.1.0\"\nvendor_dir = \"vendor\"\n\n[dependencies]\nlib = { repo = \"demo/lib\", ref = \"v1.2.3\" }\n", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C sh -lc \"cd '/tmp/opencode/odpkg-install/project' && odpkg add 'demo/lib@v1.2.3' 'lib'\"", exitCode = 0, stdout = "Added lib\n", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C sh -lc \"cd '/tmp/opencode/odpkg-install/project' && odpkg install\"", exitCode = 0, stdout = "Installed: lib\n", stderr = "", success = true },
    { match = "cat '/tmp/opencode/odpkg-install/project/odpkg.toml'", exitCode = 0, stdout = "[odpkg]\nname = \"demo\"\nversion = \"0.1.0\"\nvendor_dir = \"vendor\"\n\n[dependencies]\nlib = { repo = \"demo/lib\", ref = \"v1.2.3\" }\n", stderr = "", success = true },
    { match = "cat '/tmp/opencode/odpkg-install/project/odpkg.lock'", exitCode = 0, stdout = "[[deps]]\nname = \"lib\"\nrepo = \"demo/lib\"\nref = \"v1.2.3\"\ncommit = \"abc123\"\nhash = \"sha256:deadbeef\"\n", stderr = "", success = true },
    { match = "test -d '/tmp/opencode/odpkg-install/project/vendor/lib'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
