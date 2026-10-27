return {
  name = "deft info package",
  request = {
    action = "info",
    system = "deft",
    prompt = "json",
  },
  fakeExec = {
    { match = "deft list --all", exitCode = 0, stdout = "     Inst.   Latest  Name      Description\n     -        1.0.0   json      JSON parsing and encoding\n", stderr = "", success = true },
    { match = "test -d '.local/state/dylan/_packages'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "ls -1A '.local/state/dylan/_packages'", exitCode = 1, stdout = "", stderr = "missing", success = false },
  },
  expect = {
    success = false,
    events = { "unavailable" },
  },
}
