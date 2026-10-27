return {
  name = "raco outdated via dry-run and catalog checksum",
  request = {
    action = "outdated",
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

Package       Checksum          Source                                  Directory
shell-completion      abcd1234ef56      (catalog shell-completion)      /home/test/.local/share/racket/8.13/pkgs/shell-completion
macro-debugger        same0000same      (catalog macro-debugger)        /home/test/.local/share/racket/8.13/pkgs/macro-debugger
]=],
      stderr = "",
      success = true,
    },
    {
      match = "raco pkg update --batch --scope user --deps search-auto --dry-run 'shell-completion'",
      exitCode = 0,
      stdout = "Would update shell-completion\n",
      stderr = "",
      success = true,
    },
    {
      match = "raco pkg catalog-show 'shell-completion'",
      exitCode = 0,
      stdout = [=[Package name: shell-completion
 Source: https://pkgs.racket-lang.org/package/shell-completion
 Checksum: deadbeef0001
 Description: Completion library for shells
]=],
      stderr = "",
      success = true,
    },
    {
      match = "raco pkg update --batch --scope user --deps search-auto --dry-run 'macro-debugger'",
      exitCode = 0,
      stdout = "Package is up-to-date\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "shell-completion",
    resultVersion = "abcd1234ef56",
  }
}
