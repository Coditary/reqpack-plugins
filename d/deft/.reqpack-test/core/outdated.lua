return {
  name = "deft outdated package",
  request = {
    action = "outdated",
    system = "deft",
  },
  fakeExec = {
    { match = "command -v 'deft' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "deft list", exitCode = 0, stdout = "     Inst.   Latest  Name                   Description\n!    3.1.0    3.2.0   command-line-parser    Parse command line flags and subcommands\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "outdated" },
  },
}
