return {
  name = "deft search catalog",
  request = {
    action = "search",
    system = "deft",
    prompt = "json",
  },
  fakeExec = {
    { match = "deft list --all", exitCode = 0, stdout = "     Inst.   Latest  Name      Description\n     -        1.0.0   json      JSON parsing and encoding\n     -        0.3.0   base64    Base64 encoding\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "searched" },
  },
}
