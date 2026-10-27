return {
  name = "quarks info merge installed and directory",
  fixtureRoot = "/tmp/opencode/quarks-info-case",
  request = {
    action = "info",
    system = "quarks",
    prompt = "MathLib",
    flags = { "data-root=/tmp/opencode/quarks-info-case/.reqpack-data" },
  },
  fixtureDirs = {
    ".reqpack-data/quarks/state",
    ".reqpack-data/quarks/cache",
  },
  fixtureFiles = {
    { path = ".reqpack-data/quarks/state/installed.tsv", content = "MathLib\t1.0.0\tMath library\thttps://github.com/supercollider-quarks/MathLib.git\tmain\t/tmp/opencode/quarks-info-case/.reqpack-data/quarks/home/.local/share/SuperCollider/downloaded-quarks/MathLib\tdirectory\ttrue\t2026-05-31T00:00:00Z\n" },
    { path = ".reqpack-data/quarks/cache/directory.tsv", content = "MathLib\thttps://github.com/supercollider-quarks/MathLib.git\tmain\n" },
  },
  fakeExec = {
    { match = "cat '/tmp/opencode/quarks-info-case/.reqpack-data/quarks/state/installed.tsv'", exitCode = 0, stdout = "MathLib\t1.0.0\tMath library\thttps://github.com/supercollider-quarks/MathLib.git\tmain\t/tmp/opencode/quarks-info-case/.reqpack-data/quarks/home/.local/share/SuperCollider/downloaded-quarks/MathLib\tdirectory\ttrue\t2026-05-31T00:00:00Z\n", stderr = "", success = true },
    { match = "cat '/tmp/opencode/quarks-info-case/.reqpack-data/quarks/cache/directory.tsv'", exitCode = 0, stdout = "MathLib\thttps://github.com/supercollider-quarks/MathLib.git\tmain\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    resultName = "MathLib",
    resultVersion = "1.0.0",
    events = { "informed" },
  },
}
