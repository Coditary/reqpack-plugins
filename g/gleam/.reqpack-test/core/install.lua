return {
  name = "gleam install dependency",
  request = {
    action = "install",
    system = "gleam",
    flags = {
      "cwd=${fixtureRoot}/project"
    },
    packages = {
      { name = "lustre", version = "4.2.0" }
    },
  },
  fixtureFiles = {
    ["project/gleam.toml"] = "name = \"demo\"\nversion = \"1.0.0\"\n",
  },
  fakeExec = {
    { match = "command -v 'gleam' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '${fixtureRoot}/project/gleam.toml'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "gleam add", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
