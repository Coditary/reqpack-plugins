return {
  name = "idris2-pkg list manifest entries",
  request = {
    action = "list",
    system = "idris2-pkg",
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/idris2-pkg/installed.tsv",
      content = "demo-local\t\t\t/home/test/demo.ipkg\t/home/test/demo.ipkg\tLocal Idris2 project dependencies installed via pack\ttrue\nhedgehog\t1.0.0\t1.0.0\thedgehog\thttps://github.com/stefan-hoeck/idris2-hedgehog\tProperty based testing for Idris2\tfalse\n",
    },
  },
  fakeExec = {
    {
      match = "cat '/home/test/.cache/reqpack/idris2-pkg/installed.tsv'",
      exitCode = 0,
      stdout = "demo-local\t\t\t/home/test/demo.ipkg\t/home/test/demo.ipkg\tLocal Idris2 project dependencies installed via pack\ttrue\nhedgehog\t1.0.0\t1.0.0\thedgehog\thttps://github.com/stefan-hoeck/idris2-hedgehog\tProperty based testing for Idris2\tfalse\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "demo-local",
  },
}
