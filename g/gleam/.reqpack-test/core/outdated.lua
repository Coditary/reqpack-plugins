return {
  name = "gleam outdated dependencies",
  request = {
    action = "outdated",
    system = "gleam",
    flags = {
      "cwd=${fixtureRoot}/project"
    },
  },
  fixtureFiles = {
    ["project/gleam.toml"] = "name = \"demo\"\nversion = \"1.0.0\"\n",
  },
  fakeExec = {
    { match = "command -v 'gleam' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '${fixtureRoot}/project/gleam.toml'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "gleam deps outdated", exitCode = 0, stdout = "1 of 2 packages have newer versions available.\n\nPackage       Current  Latest\ngleam_stdlib  0.62.1   1.0.3\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "gleam_stdlib",
    resultVersion = "0.62.1",
  },
}
