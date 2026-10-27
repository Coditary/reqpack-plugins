return {
  name = "raco list installed packages",
  request = {
    action = "list",
    system = "raco",
  },
  fakeExec = {
    {
      match = "command -v 'raco' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "raco pkg show --all --long -d --scope user",
      exitCode = 0,
      stdout = [=[User-specific for installation 8.13:

Package[*=auto]       Checksum          Source                                  Directory
shell-completion      abcd1234ef56      (catalog shell-completion)              /home/test/.local/share/racket/8.13/pkgs/shell-completion
macro-debugger*       fedc4321ba65      (catalog macro-debugger)                /home/test/.local/share/racket/8.13/pkgs/macro-debugger
]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "shell-completion",
    resultVersion = "abcd1234ef56",
  }
}
