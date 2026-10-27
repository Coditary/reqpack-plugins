return {
  name = "raco info merges installed and catalog metadata",
  request = {
    action = "info",
    system = "raco",
    prompt = "shell-completion",
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
      match = "raco pkg show --all --long -d --scope user 'shell-completion'",
      exitCode = 0,
      stdout = [=[User-specific for installation 8.13:

Package       Checksum          Source                                  Directory
shell-completion      abcd1234ef56      (catalog shell-completion)      /home/test/.local/share/racket/8.13/pkgs/shell-completion
]=],
      stderr = "",
      success = true,
    },
    {
      match = "raco pkg catalog-show 'shell-completion'",
      exitCode = 0,
      stdout = [=[Package name: shell-completion
 Author: test
 Source: https://pkgs.racket-lang.org/package/shell-completion
 Checksum: deadbeef0001
 Tags: terminal, shell
 Description: Completion library for shells
 Ring: 1
 Dependencies:
  base
 Modules: 'shell/main 'shell/complete
]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "shell-completion",
    resultVersion = "abcd1234ef56",
  }
}
