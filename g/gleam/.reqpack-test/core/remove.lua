return {
  name = "gleam remove dependency",
  request = {
    action = "remove",
    system = "gleam",
    flags = {
      "cwd=${fixtureRoot}/project"
    },
    packages = {
      { name = "lustre" }
    },
  },
  fixtureFiles = {
    ["project/gleam.toml"] = "name = \"demo\"\nversion = \"1.0.0\"\n",
  },
  fakeExec = {
    { match = "command -v 'gleam' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '${fixtureRoot}/project/gleam.toml'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "gleam remove", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
