return {
  name = "gleam info installed manifest entry",
  request = {
    action = "info",
    system = "gleam",
    prompt = "lustre",
    flags = {
      "cwd=${fixtureRoot}/project"
    },
  },
  fixtureFiles = {
    ["project/gleam.toml"] = "name = \"demo\"\nversion = \"1.0.0\"\n",
    ["project/manifest.toml"] = [=[packages = [
  { name = "lustre", version = "4.5.1", build_tools = ["gleam"], requirements = ["gleam_stdlib"], otp_app = "lustre", source = "hex", outer_checksum = "def" }
]
]=],
  },
  fakeExec = {
    { match = "command -v 'gleam' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '${fixtureRoot}/project/gleam.toml'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/project/manifest.toml'", exitCode = 0, stdout = [=[packages = [
  { name = "lustre", version = "4.5.1", build_tools = ["gleam"], requirements = ["gleam_stdlib"], otp_app = "lustre", source = "hex", outer_checksum = "def" }
]
]=], stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "lustre",
    resultVersion = "4.5.1",
  },
}
