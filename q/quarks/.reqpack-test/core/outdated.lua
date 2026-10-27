return {
  name = "quarks outdated git tracked package",
  fixtureRoot = "/tmp/opencode/quarks-outdated-case",
  request = {
    action = "outdated",
    system = "quarks",
    flags = { "data-root=/tmp/opencode/quarks-outdated-case/.reqpack-data" },
  },
  fixtureDirs = {
    ".reqpack-data/quarks/state",
  },
  fixtureFiles = {
    { path = ".reqpack-data/quarks/state/installed.tsv", content = "MathLib\t1.0.0\tMath library\thttps://github.com/supercollider-quarks/MathLib.git\tmain\t/tmp/opencode/quarks-outdated-case/.reqpack-data/quarks/home/.local/share/SuperCollider/downloaded-quarks/MathLib\tdirectory\ttrue\t2026-05-31T00:00:00Z\n" },
  },
  fakeExec = {
    { match = "cat '/tmp/opencode/quarks-outdated-case/.reqpack-data/quarks/state/installed.tsv'", exitCode = 0, stdout = "MathLib\t1.0.0\tMath library\thttps://github.com/supercollider-quarks/MathLib.git\tmain\t/tmp/opencode/quarks-outdated-case/.reqpack-data/quarks/home/.local/share/SuperCollider/downloaded-quarks/MathLib\tdirectory\ttrue\t2026-05-31T00:00:00Z\n", stderr = "", success = true },
    { match = "git -C '/tmp/opencode/quarks-outdated-case/.reqpack-data/quarks/home/.local/share/SuperCollider/downloaded-quarks/MathLib' fetch --tags --quiet", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "git -C '/tmp/opencode/quarks-outdated-case/.reqpack-data/quarks/home/.local/share/SuperCollider/downloaded-quarks/MathLib' rev-parse HEAD", exitCode = 0, stdout = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n", stderr = "", success = true },
    { match = "git -C '/tmp/opencode/quarks-outdated-case/.reqpack-data/quarks/home/.local/share/SuperCollider/downloaded-quarks/MathLib' rev-parse @{upstream}", exitCode = 0, stdout = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "MathLib",
    resultVersion = "1.0.0",
    events = { "outdated" },
  },
}
