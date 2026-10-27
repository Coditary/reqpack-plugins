return {
  name = "odpkg install registry dependency",
  fixtureRoot = "/tmp/opencode/odpkg-install-registry",
  request = {
    action = "install",
    system = "odpkg",
    flags = {
      "cwd=/tmp/opencode/odpkg-install-registry/project",
      "cache-home=/tmp/opencode/odpkg-install-registry/cache",
    },
    packages = {
      {
        name = "tempo",
        flags = { "registry" },
      },
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/odpkg-install-registry",
  },
  fixtureFiles = {
    ["project/odpkg.toml"] = "[odpkg]\nname = \"demo\"\nversion = \"0.1.0\"\nvendor_dir = \"vendor\"\n\n[dependencies]\ntempo = { repo = \"kalsprite/tempo\", ref = \"main\" }\n",
    ["project/odpkg.lock"] = "[[deps]]\nname = \"tempo\"\nrepo = \"kalsprite/tempo\"\nref = \"main\"\ncommit = \"beef123\"\nhash = \"sha256:cafe\"\n",
  },
  fixtureDirs = {
    "project/vendor/tempo",
  },
  fakeExec = {
    { match = "command -v 'odpkg' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '/tmp/opencode/odpkg-install-registry/project/odpkg.toml'", exitCode = 0, stdout = "[odpkg]\nname = \"demo\"\nversion = \"0.1.0\"\nvendor_dir = \"vendor\"\n\n[dependencies]\ntempo = { repo = \"kalsprite/tempo\", ref = \"main\" }\n", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C XDG_CACHE_HOME='/tmp/opencode/odpkg-install-registry/cache' sh -lc \"cd '/tmp/opencode/odpkg-install-registry/project' && odpkg add --registry 'tempo'\"", exitCode = 0, stdout = "Added tempo\n", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C XDG_CACHE_HOME='/tmp/opencode/odpkg-install-registry/cache' sh -lc \"cd '/tmp/opencode/odpkg-install-registry/project' && odpkg install\"", exitCode = 0, stdout = "Installed: tempo\n", stderr = "", success = true },
    { match = "cat '/tmp/opencode/odpkg-install-registry/project/odpkg.toml'", exitCode = 0, stdout = "[odpkg]\nname = \"demo\"\nversion = \"0.1.0\"\nvendor_dir = \"vendor\"\n\n[dependencies]\ntempo = { repo = \"kalsprite/tempo\", ref = \"main\" }\n", stderr = "", success = true },
    { match = "cat '/tmp/opencode/odpkg-install-registry/project/odpkg.lock'", exitCode = 0, stdout = "[[deps]]\nname = \"tempo\"\nrepo = \"kalsprite/tempo\"\nref = \"main\"\ncommit = \"beef123\"\nhash = \"sha256:cafe\"\n", stderr = "", success = true },
    { match = "test -d '/tmp/opencode/odpkg-install-registry/project/vendor/tempo'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
